import importlib.util
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location('audit_firmware', Path(__file__).resolve().parents[1] / 'tools/audit_firmware.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def fixture():
    data = bytearray(256)
    data[:7] = b'\x7fELF\x01\x01\x01'
    # Three sections: NULL, string table, symbol table. No actual ARM code.
    struct.pack_into('<HHIIIIIHHHHHH', data, 16, 2, 40, 1, 0x101, 0, 52, 0,
                     52, 0, 0, 40, 3, 1)
    struct.pack_into('<IIIIIIIIII', data, 92, 0, 3, 0, 0, 172, 7, 0, 0, 1, 0)
    data[172:179] = b'\0entry\0'
    struct.pack_into('<IIIIIIIIII', data, 132, 0, 2, 0, 0, 180, 32, 1, 0, 4, 16)
    struct.pack_into('<IIIBBH', data, 196, 1, 0x101, 4, 0, 0, 0xfff1)
    return data


def loadable_fixture():
    data = bytearray(320)
    data[:7] = b'\x7fELF\x01\x01\x01'
    struct.pack_into('<HHIIIIIHHHHHH', data, 16, 2, 40, 1, 0x101, 52, 84, 0,
                     52, 32, 1, 40, 4, 2)
    struct.pack_into('<IIIIIIII', data, 52, 1, 256, 0, 0, 8, 8, 5, 4)
    struct.pack_into('<IIIIIIIIII', data, 124, 0, 1, 2, 0, 256, 8, 0, 0, 4, 0)
    struct.pack_into('<IIIIIIIIII', data, 164, 0, 3, 0, 0, 264, 7, 0, 0, 1, 0)
    struct.pack_into('<IIIIIIIIII', data, 204, 0, 2, 0, 0, 272, 32, 2, 0, 4, 16)
    struct.pack_into('<II', data, 256, 0x20004000, 0x101)
    data[264:271] = b'\0entry\0'
    struct.pack_into('<IIIBBH', data, 288, 1, 0x101, 4, 0, 0, 1)
    return data


def record(kind, payload=b'', address=0):
    data = bytes((len(payload), address >> 8, address & 255, kind)) + payload
    return ':' + (data + bytes((-sum(data) & 255,))).hex().upper()


def padded_fixture():
    data = bytearray(384)
    data[:7] = b'\x7fELF\x01\x01\x01'
    struct.pack_into('<HHIIIIIHHHHHH', data, 16, 2, 40, 1, 0x101, 52, 84, 0,
                     52, 32, 1, 40, 5, 3)
    struct.pack_into('<IIIIIIII', data, 52, 1, 320, 0, 0, 16, 16, 5, 4)
    struct.pack_into('<IIIIIIIIII', data, 124, 0, 1, 2, 0, 320, 8, 0, 0, 4, 0)
    struct.pack_into('<IIIIIIIIII', data, 164, 0, 1, 2, 12, 332, 4, 0, 0, 4, 0)
    struct.pack_into('<IIIIIIIIII', data, 204, 0, 3, 0, 0, 336, 7, 0, 0, 1, 0)
    struct.pack_into('<IIIIIIIIII', data, 244, 0, 2, 0, 0, 344, 32, 3, 0, 4, 16)
    struct.pack_into('<II', data, 320, 0x20004000, 0x101)
    data[332:336] = b'DATA'
    data[336:343] = b'\0entry\0'
    struct.pack_into('<IIIBBH', data, 360, 1, 0x101, 4, 0, 0, 1)
    return data


def hex_fixture(payload=None):
    if payload is None:
        payload = bytes(loadable_fixture()[256:264])
    return record(0, payload) + '\n' + record(1) + '\n'


class FirmwareAuditTests(unittest.TestCase):
    def test_inspects_without_executing_arm(self):
        report = audit.inspect_elf(fixture())
        self.assertEqual(report['machine'], 'ARM')
        self.assertEqual(report['entry_point'], 0x101)
        self.assertIsNone(report['environment_primary_stack'])
        self.assertFalse(report['vector_matches_stack_end'])
        self.assertIsNone(report['vector_initial_sp'])
        self.assertNotIn('symbols', report)

    def test_symbols_are_optional_and_stdlib_only(self):
        report = audit.inspect_elf(fixture(), include_symbols=True)
        self.assertEqual(report['symbols']['entry']['address'], 0x101)

    def test_vectors_read_only_allocated_sections(self):
        data = loadable_fixture()
        report = audit.inspect_elf(data)
        self.assertEqual(report['vector_initial_sp'], 0x20004000)
        self.assertTrue(report['vector_matches_entry'])
        # Same bytes at address zero in a nonallocated section are not vectors.
        struct.pack_into('<I', data, 124 + 8, 0)
        self.assertIsNone(audit.inspect_elf(data)['vector_initial_sp'])

    def test_rejects_non_elf(self):
        with self.assertRaises(ValueError):
            audit.inspect_elf(b'not firmware')

    def test_rejects_host_executable(self):
        data = fixture()
        struct.pack_into('<H', data, 18, 62)
        with self.assertRaisesRegex(ValueError, 'ARM executable'):
            audit.inspect_elf(data)

    def test_rejects_truncated_section_table(self):
        with self.assertRaises(ValueError):
            audit.inspect_elf(fixture()[:150])

    def test_rejects_invalid_string_offset(self):
        data = fixture()
        struct.pack_into('<I', data, 196, 99)
        with self.assertRaises(ValueError):
            audit.inspect_elf(data)

    def test_marks_dynamic_frames_unknown(self):
        rows = audit.stack_entries('sample.adb:4:2:Read\t80\tdynamic\nother.adb:1:1:Go\t16\tstatic\n')
        self.assertFalse(rows[0]['frame_is_static'])
        self.assertEqual(rows[0]['reported_frame_bytes'], 80)
        self.assertTrue(rows[1]['frame_is_static'])

    def test_rejects_bad_stack_usage(self):
        with self.assertRaises(ValueError):
            audit.stack_entries('frame\tunknown\tdynamic\n')

    def test_hex_matches_physical_elf_load_bytes(self):
        report = audit.compare_hex_elf(hex_fixture(), loadable_fixture())
        self.assertTrue(report['checksums_valid'])
        self.assertTrue(report['matches_elf_load_bytes'])
        self.assertEqual(report['data_bytes'], 8)

    def test_hex_covers_ram_initializer_by_physical_not_virtual_address(self):
        data = loadable_fixture()
        struct.pack_into('<I', data, 52 + 8, 0x20000000)
        struct.pack_into('<I', data, 124 + 12, 0x20000000)
        self.assertTrue(audit.compare_hex_elf(hex_fixture(), data)['matches_elf_load_bytes'])

    def test_omitted_alignment_padding_is_reported_separately(self):
        data = padded_fixture()
        text = (record(0, data[320:328]) + '\n' + record(0, data[332:336], 12)
                + '\n' + record(1))
        report = audit.compare_hex_elf(text, data)
        self.assertTrue(report['matches_elf_load_bytes'])
        self.assertEqual(report['elf_load_bytes'], 12)
        self.assertEqual(report['elf_segment_file_bytes'], 16)
        self.assertEqual(report['padding_bytes_missing_from_hex'], 4)
        self.assertEqual(report['missing_bytes'], 0)

    def test_missing_allocated_byte_is_not_excused_as_alignment_padding(self):
        data = padded_fixture()
        text = (record(0, data[320:328]) + '\n' + record(0, data[332:335], 12)
                + '\n' + record(1))
        report = audit.compare_hex_elf(text, data)
        self.assertFalse(report['matches_elf_load_bytes'])
        self.assertEqual(report['missing_bytes'], 1)
        self.assertEqual(report['padding_bytes_missing_from_hex'], 4)

    def test_explicit_padding_must_match_segment_bytes(self):
        data = padded_fixture()
        report = audit.compare_hex_elf(hex_fixture(data[320:336]), data)
        self.assertTrue(report['matches_elf_load_bytes'])
        self.assertEqual(report['padding_bytes_present_in_hex'], 4)
        bad = bytearray(data[320:336]); bad[8] = 255
        report = audit.compare_hex_elf(hex_fixture(bad), data)
        self.assertFalse(report['matches_elf_load_bytes'])
        self.assertEqual(report['different_padding_bytes'], 1)

    def test_allocated_section_outside_load_mapping_rejected(self):
        data = loadable_fixture()
        struct.pack_into('<I', data, 124 + 12, 0x20000000)
        with self.assertRaisesRegex(ValueError, 'unique PT_LOAD'):
            audit.elf_load_image(data)

    def test_hex_rejects_wrong_checksum(self):
        text = hex_fixture()
        with self.assertRaisesRegex(ValueError, 'checksum'):
            audit.hex_image(text[:9] + ('1' if text[9] == '0' else '0') + text[10:])

    def test_hex_requires_eof(self):
        with self.assertRaisesRegex(ValueError, 'EOF'):
            audit.hex_image(record(0, b'\x01'))

    def test_hex_rejects_data_after_eof(self):
        with self.assertRaisesRegex(ValueError, 'after EOF'):
            audit.hex_image(hex_fixture() + record(0, b'\x01'))

    def test_hex_rejects_conflicting_overlap(self):
        with self.assertRaisesRegex(ValueError, 'overlapping'):
            audit.hex_image(record(0, b'\x01') + '\n' + record(0, b'\x02') + '\n' + record(1))

    def test_hex_extended_address_modes(self):
        for kind, expected in ((2, 0x12340), (4, 0x12340000)):
            image, _ = audit.hex_image(record(kind, b'\x12\x34') + '\n'
                                      + record(0, b'\xAB', 5) + '\n' + record(1))
            self.assertEqual(image, {expected + 5: 0xAB})

    def test_hex_start_records_are_not_load_data(self):
        for kind in (3, 5):
            image, _ = audit.hex_image(record(kind, b'\x00\x00\x01\x01') + '\n' + hex_fixture())
            self.assertEqual(len(image), 8)

    def test_hex_rejects_bad_record_length_and_type(self):
        for text in (':0100000000', record(6), record(4, b'\x01'),
                     record(1, b'\x01'), record(0, b'\x01\x02', 65535) + '\n' + record(1)):
            with self.assertRaises(ValueError):
                audit.hex_image(text)

    def test_hex_detects_missing_extra_and_changed_bytes(self):
        payload = bytes(loadable_fixture()[256:264])
        missing = audit.compare_hex_elf(hex_fixture(payload[:-1]), loadable_fixture())
        self.assertFalse(missing['matches_elf_load_bytes'])
        self.assertEqual(missing['missing_bytes'], 1)
        extra = audit.compare_hex_elf(hex_fixture(payload + b'\x00'), loadable_fixture())
        self.assertEqual(extra['extra_bytes'], 1)
        changed = audit.compare_hex_elf(hex_fixture(b'\x01' + payload[1:]), loadable_fixture())
        self.assertEqual(changed['different_bytes'], 1)

    def test_elf_rejects_bad_load_segment(self):
        data = loadable_fixture()
        struct.pack_into('<I', data, 52 + 20, 7)
        with self.assertRaisesRegex(ValueError, 'load segment'):
            audit.elf_load_image(data)

    def test_elf_rejects_missing_program_headers(self):
        with self.assertRaisesRegex(ValueError, 'program headers'):
            audit.elf_load_image(fixture())


if __name__ == '__main__':
    unittest.main()
