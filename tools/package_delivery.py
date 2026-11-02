#!/usr/bin/env python3
"""Package the verified PDFs and an Overleaf source archive, without hardware."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile
from check_project import REPO, document_hashes
from sync_report_sources import sources


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', default='kodekontroll-2026-11-02')
    args = parser.parse_args()
    if not args.tag or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_' for c in args.tag):
        raise SystemExit('Use a plain filename tag')
    verification = REPO / 'build/readiness-review/verification.json'
    checked = json.loads(verification.read_text())
    required = {'ada-tests', 'python-tests', 'mutations', 'proof', 'main-build',
                'sensor-v2-build', 'gpio-v3-build', 'lamp-build', 'report-build', 'slides-build'}
    if not checked['passed'] or not required.issubset(
            c['name'] for c in checked['checks'] if c['exit_code'] == 0):
        raise SystemExit('Run python3 tools/check_project.py --full first')
    if checked['source_sha256'] != {n: sha(d) for n, d in sources().items()}:
        raise SystemExit('Code changed since verification')
    if checked.get('document_sha256') != document_hashes():
        raise SystemExit('Document sources changed since verification')
    subprocess.run(['python3', 'tools/sync_report_sources.py', '--check'], cwd=REPO, check=True)
    out = REPO / 'build/deliverables'
    out.mkdir(parents=True, exist_ok=True)
    artifacts = []
    for label, src in [('rapport', 'build/report-ready/main.pdf'),
                       ('presentasjon', 'build/slides-ready/presentation.pdf')]:
        source = REPO / src
        dest = out / f'ADAptive-{label}-{args.tag}.pdf'
        shutil.copyfile(source, dest)
        info = subprocess.check_output(['pdfinfo', str(dest)], text=True)
        pages = int(next(line.split(':', 1)[1].strip() for line in info.splitlines()
                         if line.startswith('Pages:')))
        artifacts.append({'path': dest.relative_to(REPO).as_posix(), 'pages': pages,
                          'bytes': dest.stat().st_size, 'sha256': sha(dest.read_bytes())})
    allowed = {'.tex', '.bib', '.md', '.csv', '.json', '.log', '.txt', '.patch',
               '.ads', '.adb', '.gpr', '.toml', '.png', '.jpg', '.jpeg', '.docx'}
    files = {p.relative_to(REPO / 'docs').as_posix(): p.read_bytes()
             for p in sorted((REPO / 'docs').rglob('*')) if p.is_file()
             and p.suffix.lower() in allowed and 'vendor' not in p.relative_to(REPO / 'docs').parts}
    files['DELIVERY-SHA256.json'] = (json.dumps({n: sha(d) for n, d in files.items()},
                                             indent=2, sort_keys=True) + '\n').encode()
    archive = out / f'ADAptive-Overleaf-{args.tag}.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        for name, data in sorted(files.items()):
            zf.writestr(name, data)
    with zipfile.ZipFile(archive) as zf:
        if zf.testzip() is not None or any(zf.read(n) != d for n, d in files.items()):
            raise SystemExit('Archive integrity failure')
    artifacts.append({'path': archive.relative_to(REPO).as_posix(), 'entries': len(files),
                      'bytes': archive.stat().st_size, 'sha256': sha(archive.read_bytes())})
    manifest = {'verification': checked, 'artifacts': artifacts, 'archive_integrity': 'CRC and every entry checked'}
    (out / f'delivery-{args.tag}.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(artifacts, indent=2))


if __name__ == '__main__':
    main()
