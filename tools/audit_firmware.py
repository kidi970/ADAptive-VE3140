#!/usr/bin/env python3
"""Inspect local ARM ELF, compiler stack files and binder text; never run firmware.

This is a partial static inventory, not a stack high-water measurement or a
whole-program upper bound. It uses only ordinary files and the Python library.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

REPO = Path(__file__).resolve().parents[1]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect_elf(data, include_symbols=False):
    """Read the ELF32 little-endian ARM symbol table without executing its code."""
    def block(offset, size):
        if offset < 0 or size < 0 or offset + size > len(data):
            raise ValueError('truncated ELF structure')
        return data[offset:offset + size]

    if block(0, 16)[:7] != b'\x7fELF\x01\x01\x01':
        raise ValueError('expected ELF32 little-endian version 1')
    header = struct.unpack('<HHIIIIIHHHHHH', block(16, 36))
    elf_type, machine, version, entry, _, shoff = header[:6]
    shentsize, shnum, shstrndx = header[10:13]
    if elf_type != 2 or machine != 40 or version != 1:
        raise ValueError('expected an ARM executable, not a host executable')
    if shentsize != 40 or shnum == 0 or shstrndx >= shnum:
        raise ValueError('unsupported or invalid ELF section table')
    sections = [struct.unpack('<IIIIIIIIII', block(shoff + i * 40, 40))
                for i in range(shnum)]

    def contents(section):
        return block(section[4], section[5])

    def string(table, index):
        if index >= len(table):
            raise ValueError('invalid ELF string offset')
        end = table.find(b'\0', index)
        if end < 0:
            raise ValueError('unterminated ELF string')
        return table[index:end].decode('utf-8', errors='replace')

    symbols = {}
    for section in sections:
        if section[1] != 2:  # SHT_SYMTAB
            continue
        if section[9] != 16 or section[5] % 16 or section[6] >= shnum:
            raise ValueError('invalid ELF symbol table')
        table = contents(sections[section[6]])
        entries = contents(section)
        for offset in range(0, len(entries), 16):
            name, value, size, _, _, index = struct.unpack('<IIIBBH', entries[offset:offset + 16])
            if not name or not index:
                continue
            label = string(table, name)
            symbols[label] = {'address': value, 'size': size}
    if not symbols:
        raise ValueError('ELF has no usable symbol table')

    def word_at(address):
        for section in sections:
            if section[1] == 8 or not section[2] & 2:  # only file-backed SHF_ALLOC
                continue
            if section[3] <= address and address + 4 <= section[3] + section[5]:
                return struct.unpack('<I', block(section[4] + address - section[3], 4))[0]
        return None

    def address(name):
        return symbols.get(name, {}).get('address')

    def span(start_name, end_name):
        start, end = address(start_name), address(end_name)
        if start is None or end is None or end < start:
            return None
        return {'start': start, 'end': end, 'reserved_bytes': end - start}

    secondary = symbols.get('system__parameters__runtime_default_sec_stack_size')
    vector_sp, vector_pc = word_at(0), word_at(4)
    stack = span('__stack_start', '__stack_end')
    result = {
        'machine': 'ARM', 'format': 'ELF32 little-endian', 'entry_point': entry,
        'vector_initial_sp': vector_sp, 'vector_reset_pc': vector_pc,
        'vector_matches_stack_end': stack is not None and vector_sp == stack['end'],
        'vector_matches_entry': vector_pc == entry,
        'environment_primary_stack': stack,
        'interrupt_stack': span('__interrupt_stack_start', '__interrupt_stack_end'),
        'secondary_stack_default_bytes': word_at(secondary['address']) if secondary else None,
        'secondary_pool_reserved_bytes': symbols.get('ada_main__sec_default_sized_stacks', {}).get('size'),
        'static_ram_end': address('__stack_end'),
        'symbol_count': len(symbols),
    }
    if include_symbols:
        result['symbols'] = symbols
    return result


def stack_entries(text):
    entries = []
    for line in text.splitlines():
        parts = line.rsplit('\t', 2)
        if len(parts) != 3 or not parts[1].isdigit():
            raise ValueError(f'invalid compiler stack-usage line: {line!r}')
        location, size, qualifier = parts
        entries.append({'location': location.replace(str(REPO) + '/', ''),
                        'reported_frame_bytes': int(size), 'qualifier': qualifier,
                        'frame_is_static': qualifier == 'static'})
    return entries


def hex_image(text):
    """Validate Intel HEX checksums/address records and return its load bytes."""
    image, base, eof, records = {}, 0, False, 0
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if eof:
            raise ValueError('HEX data after EOF')
        if not re.fullmatch(r':[0-9a-fA-F]+', line):
            raise ValueError(f'invalid HEX syntax on line {number}')
        try:
            record = bytes.fromhex(line[1:])
        except ValueError as error:
            raise ValueError(f'invalid HEX encoding on line {number}') from error
        if len(record) < 5 or len(record) != record[0] + 5:
            raise ValueError(f'invalid HEX length on line {number}')
        if sum(record) % 256:
            raise ValueError(f'invalid HEX checksum on line {number}')
        count, address, kind = record[0], int.from_bytes(record[1:3], 'big'), record[3]
        payload = record[4:-1]
        records += 1
        if kind == 0:
            if address + count > 0x10000 or base + address + count > 0x100000000:
                raise ValueError('HEX address overflow')
            for offset, value in enumerate(payload):
                target = base + address + offset
                if target in image and image[target] != value:
                    raise ValueError('conflicting overlapping HEX bytes')
                image[target] = value
        elif kind == 1:
            if count or address:
                raise ValueError('invalid HEX EOF record')
            eof = True
        elif kind in (2, 4):
            if count != 2 or address:
                raise ValueError('invalid HEX extended address record')
            base = int.from_bytes(payload, 'big') << (4 if kind == 2 else 16)
        elif kind in (3, 5):
            if count != 4 or address:
                raise ValueError('invalid HEX start address record')
        else:
            raise ValueError(f'unsupported HEX record type {kind}')
    if not eof or not image:
        raise ValueError('HEX requires data and an EOF record')
    return image, records


def elf_images(data):
    """Allocated section load bytes and segment bytes, kept distinct for padding.

    objcopy emits file-backed SHF_ALLOC sections, not alignment holes between
    them. PT_LOAD maps section virtual addresses to physical load addresses,
    so initialized RAM .data is still compared at its flash LMA.
    """
    if len(data) < 52 or data[:7] != b'\x7fELF\x01\x01\x01':
        raise ValueError('expected ELF32 little-endian version 1')
    header = struct.unpack_from('<HHIIIIIHHHHHH', data, 16)
    if header[:3] != (2, 40, 1):
        raise ValueError('expected an ARM executable')
    phoff, phsize, phnum = header[4], header[8], header[9]
    if not phnum or phsize != 32 or phoff + phsize * phnum > len(data):
        raise ValueError('invalid or missing ELF program headers')
    segment_image, segments = {}, []
    for index in range(phnum):
        kind, offset, virtual, physical, size, memory_size, _, _ = struct.unpack_from(
            '<IIIIIIII', data, phoff + index * phsize)
        if kind != 1 or not size:
            continue
        if size > memory_size or offset + size > len(data) or physical + size > 0x100000000:
            raise ValueError('invalid ELF load segment')
        segments.append((offset, physical, size, virtual))
        for position, value in enumerate(data[offset:offset + size], physical):
            if position in segment_image and segment_image[position] != value:
                raise ValueError('conflicting ELF load segments')
            segment_image[position] = value
    if not segment_image:
        raise ValueError('ELF has no file-backed load bytes')
    shoff, shsize, shnum = header[5], header[10], header[11]
    if not shnum or shsize != 40 or shoff + shsize * shnum > len(data):
        raise ValueError('invalid ELF section headers')
    allocated_image = {}
    for index in range(shnum):
        section = struct.unpack_from('<IIIIIIIIII', data, shoff + index * shsize)
        _, kind, flags, virtual, offset, size, _, _, _, _ = section
        if not flags & 2 or kind == 8 or not size:
            continue
        if offset + size > len(data) or virtual + size > 0x100000000:
            raise ValueError('invalid allocated ELF section')
        mappings = {physical + virtual - base_virtual
                    for base_offset, physical, segment_size, base_virtual in segments
                    if base_virtual <= virtual and virtual + size <= base_virtual + segment_size
                    and base_offset <= offset and offset + size <= base_offset + segment_size
                    and virtual - base_virtual == offset - base_offset}
        if len(mappings) != 1:
            raise ValueError('allocated ELF section has no unique PT_LOAD mapping')
        physical = mappings.pop()
        for position, value in enumerate(data[offset:offset + size], physical):
            if position in allocated_image and allocated_image[position] != value:
                raise ValueError('conflicting allocated ELF sections')
            allocated_image[position] = value
    if not allocated_image:
        raise ValueError('ELF has no file-backed allocated load bytes')
    return allocated_image, segment_image


def elf_load_image(data):
    """Bytes required in HEX: file-backed allocated sections at physical LMA."""
    return elf_images(data)[0]


def compare_hex_elf(hex_text, elf_data):
    actual, records = hex_image(hex_text)
    expected, segments = elf_images(elf_data)
    padding = {address: value for address, value in segments.items() if address not in expected}
    missing = sum(address not in actual for address in expected)
    extra = sum(address not in segments for address in actual)
    different = sum(actual.get(address) != value
                    for address, value in expected.items() if address in actual)
    different_padding = sum(actual[address] != value for address, value in padding.items()
                            if address in actual)
    return {'checksums_valid': True, 'records': records, 'data_bytes': len(actual),
            'lowest_address': min(actual), 'highest_address': max(actual),
            'elf_load_bytes': len(expected), 'elf_segment_file_bytes': len(segments),
            'elf_segment_padding_bytes': len(padding),
            'padding_bytes_present_in_hex': sum(address in actual for address in padding),
            'padding_bytes_missing_from_hex': sum(address not in actual for address in padding),
            'different_padding_bytes': different_padding, 'missing_bytes': missing,
            'extra_bytes': extra, 'different_bytes': different,
            'matches_elf_load_bytes': missing == extra == different == different_padding == 0,
            'scope': 'allocated section bytes at PT_LOAD physical addresses; omitted segment padding permitted; no device readback'}


def audit(elf, object_dir, binder, hex_file=None):
    elf_bytes = elf.read_bytes()
    result = {'scope': 'static-file inventory; no device access or firmware execution',
              'hardware_access': False,
              'elf_sha256': hashlib.sha256(elf_bytes).hexdigest(), 'elf': inspect_elf(elf_bytes),
              'stack_files': [], 'binder': None,
              'hex': None,
              'stack_and_binder_provenance_matches_elf': None,
              'whole_program_stack_upper_bound_bytes': None,
              'measured_stack_high_water_bytes': None,
              'limitations': [
                  'Individual .su frames cannot be summed into a call-chain bound.',
                  'Dynamic frames, dispatch calls, compiler helpers and runtime frames require further analysis.',
                  'Compiler stack files may be cached: their identity is recorded, not their freshness certified.',
                  'Binder and .su hashes identify files but do not prove they belong to this ELF build.',
                  'Primary, secondary, interrupt and per-task stacks are distinct budgets.',
                  'Reserved stack bytes are not evidence of adequate measured margin.',
                  'Binder elaboration runs before the application main exception handler.',
              ]}
    for source in sorted(object_dir.glob('*.su')):
        content = source.read_bytes()
        result['stack_files'].append({'file': source.name,
                                      'sha256': hashlib.sha256(content).hexdigest(),
                                      'entries': stack_entries(content.decode())})
    entries = [e for item in result['stack_files'] for e in item['entries']]
    result['largest_reported_individual_frame_bytes'] = max(
        (e['reported_frame_bytes'] for e in entries), default=None)
    result['dynamic_frame_count'] = sum(not e['frame_is_static'] for e in entries)
    if binder.exists():
        content = binder.read_bytes()
        text = content.decode()
        result['binder'] = {
            'file': binder.name, 'sha256': hashlib.sha256(content).hexdigest(),
            'elaboration_calls': re.findall(r"\b([A-Za-z][A-Za-z0-9_.]*)'Elab_(?:Body|Spec)", text, re.I),
        }
    if hex_file is not None:
        content = hex_file.read_bytes()
        result['hex'] = {'file': hex_file.name, 'sha256': hashlib.sha256(content).hexdigest(),
                         **compare_hex_elf(content.decode(), elf_bytes)}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--elf', type=Path, default=REPO / 'build/main.elf')
    parser.add_argument('--object-dir', type=Path, default=REPO / 'build/obj/Code/obj')
    parser.add_argument('--binder', type=Path, default=REPO / 'build/obj/Code/obj/b__main.adb')
    parser.add_argument('--hex', type=Path, help='Validate HEX and compare all physical PT_LOAD bytes')
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    hex_file = args.hex
    if hex_file is None and args.elf.with_suffix('.hex').exists():
        hex_file = args.elf.with_suffix('.hex')
    report = audit(args.elf, args.object_dir, args.binder, hex_file)
    output = json.dumps(report, indent=2) + '\n'
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output)
    else:
        print(output, end='')
    if report['hex'] is not None and not report['hex']['matches_elf_load_bytes']:
        raise SystemExit('HEX does not match ELF load bytes')


if __name__ == '__main__':
    main()
