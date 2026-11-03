"""Local-only prerequisites for diagnostic tools; importing this opens no device.

Hashes detect accidental file changes, not an authenticated provenance claim.
The two complete backup reads must agree before programming is allowed. This
module never creates a backup and never restores one.
"""
import hashlib
from pathlib import Path
import re


def image_hash(image, expected):
    if not expected or not re.fullmatch(r'[0-9a-fA-F]{64}', expected):
        raise ValueError('Explicit --image-sha256 must contain 64 hexadecimal characters')
    actual = hashlib.sha256(Path(image).read_bytes()).hexdigest()
    if actual != expected.lower():
        raise ValueError('Diagnostic SHA-256 differs from --image-sha256; device access refused')
    return actual


def verify_backup(directory, expected_probe):
    if directory is None:
        raise ValueError('--flash requires --backup with matching full-flash and UICR reads')
    directory = Path(directory)
    if (directory / 'probe-id.txt').read_text().strip() != expected_probe:
        raise ValueError('Backup probe ID differs from --probe-id; programming refused')
    checksums = {}
    for line in (directory / 'SHA256SUMS.txt').read_text().splitlines():
        match = re.fullmatch(r'([0-9a-fA-F]{64}) [ *](.+)', line)
        if match:
            name = match[2]
            if name in checksums:
                raise ValueError('Duplicate backup checksum entry')
            checksums[name] = match[1].lower()
    verified = {}
    for kind, size in (('flash', 0x80000), ('uicr', 0x1000)):
        copies = []
        for suffix in ('before', 'check'):
            name = f'{kind}-{suffix}.bin'
            data = (directory / name).read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            if len(data) != size or checksums.get(name) != digest:
                raise ValueError(f'Backup size or SHA-256 invalid for {name}; programming refused')
            verified[name] = digest
            copies.append(data)
        if copies[0] != copies[1]:
            raise ValueError(f'Independent {kind} backup reads disagree; programming refused')
    return verified


def preflight(image, expected_sha, expected_probe, *, flash=False, backup=None):
    if not expected_probe or not expected_probe.strip() or expected_probe != expected_probe.strip():
        raise ValueError('Explicit nonempty --probe-id required before active diagnostic actions')
    result = {'image_sha256': image_hash(image, expected_sha)}
    if flash:
        result['backup_sha256'] = verify_backup(backup, expected_probe)
    return result


def verify_probe(session, expected_probe):
    # Check the selected probe before entering/opening its session. Never rely
    # solely on a library's selection filter when a different device is returned.
    if session is None or session.probe.unique_id != expected_probe:
        raise ValueError('Selected probe ID differs from --probe-id; session refused')
