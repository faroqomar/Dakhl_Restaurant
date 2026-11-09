#!/usr/bin/env python3
"""Fail closed before installing a prebuilt, isolated Dakhl Android fixture APK.

This app safeguard never invokes Flutter's installer, uninstall, clear-data or a
reset. It supports only monolithic APKs, one signer, an explicitly selected
emulator/AVD, and the phase02.verify namespace. Existing fixture updates require
an owned marker plus a hash-bound preservation archive receipt. Archive coverage
and source-to-binary provenance remain caller attestations, not guard guarantees.
"""
import argparse
from dataclasses import dataclass, replace
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile

DIGEST = re.compile(r'[0-9a-f]{64}')
REVISION = re.compile(r'[0-9a-f]{40}')
PACKAGE = re.compile(r'com\.eros\.dakhlrestaurant\.phase02\.verify\.[a-z][a-z0-9_]{7,63}')
SERIAL = re.compile(r'emulator-[0-9]{4,5}')
FIXTURE_ID = re.compile(r'[0-9a-f]{16,64}')
AVD_NAME = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,127}')
INSTALLED_PATH = re.compile(r'/data/app/[A-Za-z0-9_~+/=.-]+/base\.apk')
FILE_LIMIT = 512 * 1024 * 1024
OUTPUT_LIMIT = 64 * 1024


class GuardError(Exception):
    """Only a fixed safe failure code may cross the command-line boundary."""
    def __init__(self, code):
        self.code = code
        super().__init__(code)


@dataclass(frozen=True)
class Config:
    apk: Path
    sha256: str
    package: str
    signer_sha256: str
    serial: str
    avd_name: str
    mode: str
    fixture_id: str
    source_revision: str
    runtime_revision: str
    fixture_only: bool
    execute: bool = False
    adb: str = 'adb'
    aapt2: str = 'aapt2'
    apksigner: str = 'apksigner'
    preservation_receipt: Path | None = None


def _read_file(path, limit=FILE_LIMIT):
    """Do not follow final symlinks or consume pipes/devices/unbounded files."""
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(descriptor, 'rb') as source:
            before = os.fstat(source.fileno())
            if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1 or before.st_size > limit:
                raise GuardError('unsafe-file')
            data = source.read(limit + 1)
            after = os.fstat(source.fileno())
            if (len(data) > limit or before.st_size != len(data)
                    or (before.st_size, before.st_mtime_ns, before.st_ctime_ns)
                    != (after.st_size, after.st_mtime_ns, after.st_ctime_ns)):
                raise GuardError('unsafe-file')
            return data
    except (OSError, ValueError):
        raise GuardError('unsafe-file') from None


def _hash(path):
    return hashlib.sha256(_read_file(path)).hexdigest()


def run_tool(args, timeout):
    return subprocess.run(args, capture_output=True, text=True, encoding='utf-8',
                          errors='strict', timeout=timeout, check=False)


def _tool(run, args, timeout=30, failure='tool-failed'):
    try:
        result = run(args, timeout=timeout)
        if result.returncode != 0:
            raise GuardError(failure)
        if not isinstance(result.stdout, str) or len(result.stdout.encode('utf-8')) > OUTPUT_LIMIT:
            raise GuardError('tool-output-invalid')
        return result.stdout
    except (OSError, UnicodeError, subprocess.SubprocessError):
        raise GuardError('tool-failed') from None


def _validate(config):
    checks = [DIGEST.fullmatch(config.sha256), DIGEST.fullmatch(config.signer_sha256),
              PACKAGE.fullmatch(config.package), SERIAL.fullmatch(config.serial),
              AVD_NAME.fullmatch(config.avd_name), FIXTURE_ID.fullmatch(config.fixture_id),
              REVISION.fullmatch(config.source_revision), REVISION.fullmatch(config.runtime_revision),
              config.fixture_only, config.mode in ('new-isolated-fixture', 'existing-fixture')]
    if not all(checks):
        raise GuardError('invalid-authorization')
    if config.mode == 'existing-fixture' and config.preservation_receipt is None:
        raise GuardError('preservation-required')


def _adb(config, *args):
    return [config.adb, '-s', config.serial, *args]


def _target(config, run):
    text = _tool(run, [config.adb, 'devices', '-l'], timeout=15)
    lines = text.strip().splitlines()
    if not lines or lines[0] != 'List of devices attached':
        raise GuardError('target-mismatch')
    matches = [line.split() for line in lines[1:] if line.split() and line.split()[0] == config.serial]
    if len(matches) != 1 or len(matches[0]) < 2 or matches[0][1] != 'device':
        raise GuardError('target-mismatch')
    avd = _tool(run, _adb(config, 'emu', 'avd', 'name'), timeout=15).strip().splitlines()
    if avd != [config.avd_name, 'OK']:
        raise GuardError('target-mismatch')
    users = _tool(run, _adb(config, 'shell', 'pm', 'list', 'users'), timeout=15)
    ids = re.findall(r'UserInfo\{([0-9]+):[^\n]+\}', users)
    if not users.lstrip().startswith('Users:') or ids != ['0']:
        raise GuardError('target-users-unknown')


def _package_metadata(config, run, apk):
    text = _tool(run, [config.aapt2, 'dump', 'badging', str(apk)])
    rows = [line for line in text.splitlines() if line.startswith('package:')]
    if len(rows) != 1:
        raise GuardError('ambiguous-package')
    row = rows[0]
    name = re.search(r"(?:^|\s)name='([^']+)'", row)
    version = re.search(r"(?:^|\s)versionCode='([0-9]+)'", row)
    if not name or name[1] != config.package:
        raise GuardError('package-mismatch')
    if not version or len(version[1]) > 12 or " split='" in row or " splitName='" in row:
        raise GuardError('unsupported-apk')
    return int(version[1])


def parse_signer_report(text):
    """Parse only one legacy Signer #1 or counted SDK37 V2 Signer report.

    The caller must also require successful apksigner verification. Certificate
    hashes and public-key hashes are different fields. Mixed schemes, multiple
    or duplicate certificate digests, unknown signer labels and rotation/lineage
    reports remain unsupported instead of guessing compatibility.
    """
    if not isinstance(text, str):
        raise GuardError('ambiguous-signers')
    lines = text.splitlines()
    if re.search(r'\b(?:rotation|lineage)\b', text, re.I):
        raise GuardError('ambiguous-signers')
    profiles = []
    for line in lines:
        if not re.search(r'\bSigner\b', line, re.I):
            continue
        legacy = re.match(r'^Signer #(\d+) ', line)
        if legacy and legacy[1] == '1':
            profiles.append('legacy')
        elif line.startswith('V2 Signer: '):
            profiles.append('v2')
        else:
            raise GuardError('ambiguous-signers')
    if not profiles or len(set(profiles)) != 1:
        raise GuardError('ambiguous-signers')
    profile = profiles[0]
    counts = [line for line in lines if re.match(r'^Number of signers:', line, re.I)]
    if counts and counts != ['Number of signers: 1']:
        raise GuardError('ambiguous-signers')
    if profile == 'v2' and counts != ['Number of signers: 1']:
        raise GuardError('ambiguous-signers')
    certificate_lines = [line for line in lines if re.search(r'certificate SHA-256 digest:', line, re.I)]
    prefix = 'Signer #1' if profile == 'legacy' else 'V2 Signer:'
    pattern = re.escape(prefix) + r' certificate SHA-256 digest: ([0-9a-fA-F]{64})'
    if len(certificate_lines) != 1:
        raise GuardError('ambiguous-signers')
    match = re.fullmatch(pattern, certificate_lines[0])
    if not match:
        raise GuardError('ambiguous-signers')
    return match[1].lower()


def _signer(config, run, apk):
    text = _tool(run, [config.apksigner, 'verify', '--verbose', '--print-certs', str(apk)],
                 failure='apk-signature-invalid')
    return parse_signer_report(text)


def _unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate-key')
        result[key] = value
    return result


def _installed(config, run, directory):
    # Retained data after uninstall -k is a prior fixture, never a fresh target.
    text = _tool(run, _adb(config, 'shell', 'pm', 'list', 'packages', '-u', '--user', '0', config.package))
    rows = text.strip().splitlines()
    if any(not re.fullmatch(r'package:[A-Za-z0-9_.]+', row) for row in rows):
        raise GuardError('installed-state-unknown')
    exists = 'package:' + config.package in rows
    if config.mode == 'new-isolated-fixture':
        if exists:
            raise GuardError('unexpected-installed-package')
        return None
    if not exists:
        raise GuardError('missing-installed-package')
    paths = _tool(run, _adb(config, 'shell', 'pm', 'path', '--user', '0', config.package)).strip().splitlines()
    if len(paths) != 1 or not paths[0].startswith('package:'):
        raise GuardError('unsupported-installed-apks')
    path = paths[0][8:]
    if not INSTALLED_PATH.fullmatch(path) or any(part in ('.', '..') for part in path.split('/')):
        raise GuardError('unsupported-installed-apks')
    installed = directory / 'installed-before.apk'
    if installed.exists():
        installed.unlink()
    _tool(run, _adb(config, 'pull', path, str(installed)), timeout=60)
    installed_hash = _hash(installed)
    version = _package_metadata(config, run, installed)
    if _signer(config, run, installed) != config.signer_sha256:
        raise GuardError('installed-signer-mismatch')
    marker = _tool(run, _adb(config, 'exec-out', 'run-as', config.package, 'cat',
                             'files/dakhl_phase02_fixture_id')).strip()
    if marker != config.fixture_id:
        raise GuardError('fixture-identity-mismatch')
    try:
        receipt = json.loads(_read_file(config.preservation_receipt, 8192), object_pairs_hook=_unique_keys)
    except (ValueError, UnicodeError, RecursionError):
        raise GuardError('preservation-mismatch') from None
    keys = {'schema', 'serial', 'package', 'fixture_id', 'installed_apk_sha256',
            'backup_path', 'backup_sha256'}
    if (not isinstance(receipt, dict) or set(receipt) != keys
            or type(receipt['schema']) is not int or receipt['schema'] != 1
            or receipt['serial'] != config.serial or receipt['package'] != config.package
            or receipt['fixture_id'] != config.fixture_id
            or receipt['installed_apk_sha256'] != installed_hash
            or not isinstance(receipt['backup_path'], str)
            or not Path(receipt['backup_path']).is_absolute()
            or not isinstance(receipt['backup_sha256'], str)
            or not DIGEST.fullmatch(receipt['backup_sha256'])):
        raise GuardError('preservation-mismatch')
    if _hash(Path(receipt['backup_path'])) != receipt['backup_sha256']:
        raise GuardError('backup-mismatch')
    return installed_hash, version


def guard_install(config, run=run_tool):
    """Verify all preconditions on each call. Execute only when explicitly selected."""
    _validate(config)
    data = _read_file(config.apk)
    if hashlib.sha256(data).hexdigest() != config.sha256:
        raise GuardError('apk-hash-mismatch')
    with tempfile.TemporaryDirectory(prefix='dakhl-android-install-') as temporary:
        directory = Path(temporary)
        apk = directory / 'candidate.apk'
        apk.write_bytes(data)
        apk.chmod(0o600)
        del data
        version = _package_metadata(config, run, apk)
        if _signer(config, run, apk) != config.signer_sha256:
            raise GuardError('signer-mismatch')
        if _hash(apk) != config.sha256:
            raise GuardError('apk-changed')
        _target(config, run)
        prior = _installed(config, run, directory)
        if prior is not None and version < prior[1]:
            raise GuardError('version-downgrade')
        result = {'status': 'preflight-passed', 'package': config.package,
                  'serial': config.serial, 'avd_name': config.avd_name,
                  'apk_sha256': config.sha256, 'signer_sha256': config.signer_sha256,
                  'fixture_id': config.fixture_id, 'mode': config.mode,
                  'app_source_revision': config.source_revision,
                  'runtime_revision': config.runtime_revision,
                  'source_provenance': 'caller-attested',
                  'backup_hash_verified': prior is not None}
        if not config.execute:
            return result
        # Revalidate the exact device, installed baseline and private bytes just
        # before the one allowed mutation. adb -r has no uninstall fallback here.
        _target(config, run)
        if _installed(config, run, directory) != prior:
            raise GuardError('installed-state-changed')
        if _hash(apk) != config.sha256:
            raise GuardError('apk-changed')
        output = _tool(run, _adb(config, 'install', '-r', str(apk)), timeout=180, failure='install-failed')
        install_lines = output.strip().splitlines()
        if not install_lines or install_lines[-1] != 'Success' or any('Failure' in line for line in install_lines):
            raise GuardError('install-unconfirmed')
        paths = _tool(run, _adb(config, 'shell', 'pm', 'path', '--user', '0', config.package)).strip().splitlines()
        if (len(paths) != 1 or not paths[0].startswith('package:')
                or not INSTALLED_PATH.fullmatch(paths[0][8:])
                or any(part in ('.', '..') for part in paths[0][8:].split('/'))):
            raise GuardError('postinstall-unverified')
        installed = directory / 'installed-after.apk'
        _tool(run, _adb(config, 'pull', paths[0][8:], str(installed)), timeout=60)
        if _hash(installed) != config.sha256:
            raise GuardError('postinstall-unverified')
        if prior is not None:
            marker = _tool(run, _adb(config, 'exec-out', 'run-as', config.package, 'cat',
                                     'files/dakhl_phase02_fixture_id')).strip()
            if marker != config.fixture_id:
                raise GuardError('postinstall-preservation-unverified')
        result['status'] = 'installed'
        return result


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        raise GuardError('invalid-arguments')


def main(argv=None):
    parser = SafeParser(description=__doc__)
    for name in ['apk', 'sha256', 'package', 'signer-sha256', 'serial', 'avd-name',
                 'mode', 'fixture-id', 'source-revision', 'runtime-revision']:
        parser.add_argument('--' + name, required=True, type=Path if name == 'apk' else str)
    parser.add_argument('--fixture-only', action='store_true')
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--preservation-receipt', type=Path)
    for name in ['adb', 'aapt2', 'apksigner']:
        parser.add_argument('--' + name, default=name)
    try:
        config = Config(**vars(parser.parse_args(argv)))
        print(json.dumps(guard_install(config), sort_keys=True))
        return 0
    except GuardError as error:
        print(json.dumps({'status': 'refused', 'code': error.code}, sort_keys=True))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
