#!/usr/bin/env python3
"""Read-only Dakhl fixture/source/device/delivery preflight; never installs or drives UI."""
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile

_GUARD_PATH = Path(__file__).with_name('android_install_guard.py')
_GUARD_SPEC = importlib.util.spec_from_file_location('_dakhl_preflight_android_guard', _GUARD_PATH)
android_guard = importlib.util.module_from_spec(_GUARD_SPEC)
sys.modules[_GUARD_SPEC.name] = android_guard
_GUARD_SPEC.loader.exec_module(android_guard)
SHA = re.compile(r'[a-f0-9]{64}')
REV = re.compile(r'[a-f0-9]{40}')
ID = re.compile(r'[A-Za-z0-9_.:-]{1,160}')
REPO = re.compile(r'[A-Za-z0-9_.-]{1,100}/[A-Za-z0-9_.-]{1,100}')
LIMIT = 2 * 1024 * 1024


class PreflightError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def require(value, code):
    if not value:
        raise PreflightError(code)


def _read(path, limit=LIMIT):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, 'rb') as stream:
            before = os.fstat(stream.fileno())
            require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1 and before.st_size <= limit, 'unsafe-file')
            data = stream.read(limit + 1)
            after = os.fstat(stream.fileno())
            require(len(data) == before.st_size and len(data) <= limit and
                    (before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
                    (after.st_size, after.st_mtime_ns, after.st_ctime_ns), 'unsafe-file')
            return data
    except (OSError, ValueError) as exc:
        if isinstance(exc, PreflightError):
            raise
        raise PreflightError('unsafe-file') from None


def _unique(pairs):
    value = {}
    for key, item in pairs:
        require(key not in value, 'invalid-json')
        value[key] = item
    return value


def _json(data):
    try:
        return json.loads(data, object_pairs_hook=_unique)
    except (ValueError, UnicodeError, RecursionError):
        raise PreflightError('invalid-json') from None


def _hash(data):
    return hashlib.sha256(data).hexdigest()


def _beneath(path, root):
    path = Path(path)
    require(path.is_absolute(), 'unsafe-file')
    # Normalize only OS temporary-root aliases, never caller-controlled descendants.
    for alias in (Path('/tmp'), Path('/var')):
        if path.is_relative_to(alias):
            path = alias.resolve() / path.relative_to(alias)
            break
    try:
        relative = path.relative_to(root)
    except ValueError:
        raise PreflightError('unsafe-file') from None
    require(relative.parts and all(x not in ('.', '..') for x in relative.parts), 'unsafe-file')
    cursor = root
    for part in relative.parts:
        cursor = cursor / part
        require(not cursor.is_symlink(), 'unsafe-file')
    return path


def _artifact(value, root=None, limit=LIMIT):
    require(isinstance(value, dict) and set(value) == {'path', 'sha256'} and
            isinstance(value['path'], str) and isinstance(value['sha256'], str) and
            SHA.fullmatch(value['sha256']), 'invalid-artifact')
    path = Path(value['path'])
    if root is not None:
        path = _beneath(path, root)
    data = _read(path, limit)
    require(_hash(data) == value['sha256'], 'artifact-hash-mismatch')
    return data


def _command(run, args, root, code):
    try:
        result = run(args, cwd=root, capture_output=True, text=True, timeout=15, check=False)
        require(result.returncode == 0 and isinstance(result.stdout, str) and
                len(result.stdout.encode()) <= LIMIT, code)
        return result.stdout
    except (OSError, subprocess.SubprocessError, UnicodeError):
        raise PreflightError(code) from None


def _source(spec, root, run):
    require(isinstance(spec.get('appRevision'), str) and REV.fullmatch(spec['appRevision']) and
            isinstance(spec.get('runtimeRevision'), str) and REV.fullmatch(spec['runtimeRevision']), 'invalid-source')
    require(_command(run, ['git', 'rev-parse', 'HEAD'], root, 'source-unavailable').strip() == spec['appRevision'],
            'app-revision-mismatch')
    tracked = set(_command(run, ['git', 'ls-files', '-z'], root, 'source-unavailable').split('\0'))
    inputs = spec.get('inputs')
    require(isinstance(inputs, dict) and 1 <= len(inputs) <= 1024 and 'engine-dependency.json' in inputs, 'invalid-source')
    for name, digest in inputs.items():
        require(isinstance(name, str) and not Path(name).is_absolute() and
                all(x not in ('', '.', '..') for x in name.split('/')), 'invalid-source-path')
        require(name in tracked, 'untracked-input')
        require(isinstance(digest, str) and SHA.fullmatch(digest), 'invalid-source')
        path = _beneath(root / name, root)
        require(_hash(_read(path, 8 * LIMIT)) == digest, 'source-hash-mismatch')
    pin = _json(_read(root / 'engine-dependency.json'))
    require(isinstance(pin, dict) and pin.get('git_commit') == spec['runtimeRevision'], 'runtime-pin-mismatch')
    return _hash(json.dumps(inputs, sort_keys=True, separators=(',', ':')).encode())


def _fixture(value, root):
    require(isinstance(value, dict) and set(value) == {'root', 'path', 'sha256'} and
            isinstance(value['root'], str), 'invalid-fixture')
    directory = Path(value['root'])
    require(directory.is_absolute() and not directory.is_symlink(), 'unsafe-file')
    directory = directory.resolve()
    allowed = [Path('/tmp').resolve(), Path(tempfile.gettempdir()).resolve(), root / 'outputs/preflight-fixtures']
    require(any(directory != base and directory.is_relative_to(base) for base in allowed), 'fixture-root-not-isolated')
    require(_read(directory / '.dakhl-synthetic-fixture', 128) == b'dakhl-phase-preflight-v1\n', 'fixture-marker-mismatch')
    _artifact({'path': value['path'], 'sha256': value['sha256']}, directory)
    return directory


def _device(value, fixture_root, now):
    require(isinstance(value, dict) and set(value) == {'hostId', 'id', 'sessionId', 'maxAgeSeconds', 'observation'},
            'invalid-device')
    require(all(isinstance(value[x], str) and ID.fullmatch(value[x]) for x in ['hostId', 'id', 'sessionId']) and
            type(value['maxAgeSeconds']) is int and 1 <= value['maxAgeSeconds'] <= 300, 'invalid-device')
    observation = _json(_artifact(value['observation'], fixture_root))
    expected = {'schema', 'tool', 'hostId', 'deviceId', 'sessionId', 'observedAt', 'controlReady', 'fixtureReady', 'evidence'}
    require(isinstance(observation, dict) and set(observation) == expected and type(observation['schema']) is int and
            observation['schema'] == 1 and observation['tool'] == 'device_open', 'invalid-device-observation')
    require(observation['hostId'] == value['hostId'] and observation['deviceId'] == value['id'] and
            observation['sessionId'] == value['sessionId'], 'device-context-mismatch')
    require(observation['controlReady'] is True and observation['fixtureReady'] is True, 'device-not-ready')
    try:
        at = dt.datetime.fromisoformat(observation['observedAt'].replace('Z', '+00:00'))
        require(at.tzinfo is not None, 'invalid-device-observation')
        age = (now - at).total_seconds()
    except (TypeError, ValueError, AttributeError):
        raise PreflightError('invalid-device-observation') from None
    require(0 <= age <= value['maxAgeSeconds'], 'device-observation-stale')
    require(isinstance(observation['evidence'], list) and 1 <= len(observation['evidence']) <= 8, 'device-evidence-missing')
    for evidence in observation['evidence']:
        _artifact(evidence, fixture_root, limit=8 * LIMIT)
    return {'hostId': value['hostId'], 'deviceId': value['id'], 'sessionId': value['sessionId'],
            'observedAt': observation['observedAt'], 'observationSha256': value['observation']['sha256'],
            'proof': 'operator-observation', 'liveStateProven': False}


def _android(value, spec, fixture_root, guard_run):
    require(isinstance(value, dict) and value.get('source_revision') == spec['appRevision'] and
            value.get('runtime_revision') == spec['runtimeRevision'] and value.get('fixture_only') is True and
            value.get('execute', False) is False, 'android-context-mismatch')
    require('device' in spec and value.get('serial') == spec['device']['id'], 'android-device-mismatch')
    try:
        config = dict(value)
        config['apk'] = _beneath(Path(config['apk']), fixture_root)
        if config.get('preservation_receipt') is not None:
            config['preservation_receipt'] = _beneath(Path(config['preservation_receipt']), fixture_root)
        config['execute'] = False
        config = android_guard.Config(**config)
        result = android_guard.guard_install(config, **({'run': guard_run} if guard_run else {}))
    except android_guard.GuardError as exc:
        raise PreflightError('android-' + exc.code) from None
    except (KeyError, TypeError, ValueError):
        raise PreflightError('invalid-android-config') from None
    require(isinstance(result, dict) and result.get('status') == 'preflight-passed' and
            all(result.get(k) == getattr(config, v) for k, v in [('package', 'package'), ('serial', 'serial'),
                ('avd_name', 'avd_name'), ('apk_sha256', 'sha256'), ('signer_sha256', 'signer_sha256'),
                ('fixture_id', 'fixture_id'), ('mode', 'mode'), ('app_source_revision', 'source_revision'),
                ('runtime_revision', 'runtime_revision')]) and result.get('source_provenance') == 'caller-attested' and
            type(result.get('backup_hash_verified')) is bool, 'invalid-android-guard-result')
    return result


def _delivery(value, root, run):
    require(isinstance(value, dict) and set(value) == {'repository', 'workflowChanges'} and
            isinstance(value['repository'], str) and REPO.fullmatch(value['repository']) and
            type(value['workflowChanges']) is bool, 'invalid-delivery')
    user = _command(run, ['gh', 'api', '--include', 'user'], root, 'delivery-unavailable')
    headers = user.replace('\r\n', '\n').split('\n\n', 1)[0]
    require(re.search(r'^HTTP/[^ ]+ 200(?: |$)', headers), 'delivery-unavailable')
    matches = re.findall(r'^x-oauth-scopes:\s*([^\n]*)$', headers, re.I | re.M)
    scopes = {x.strip() for x in matches[0].split(',')} if len(matches) == 1 else set()
    repo = _json(_command(run, ['gh', 'api', 'repos/' + value['repository']], root, 'delivery-unavailable'))
    require(isinstance(repo, dict) and isinstance(repo.get('permissions'), dict) and
            repo['permissions'].get('push') is True, 'repository-write-unverified')
    if value['workflowChanges']:
        require('workflow' in scopes, 'workflow-scope-unverified')
    return {'repository': value['repository'], 'status': 'permissions-observed',
            'workflowScopeObserved': 'workflow' in scopes, 'writePermissionProven': False,
            'limits': 'Read-only API observations do not prove a push will pass repository rules.'}


def run_preflight(spec, root, *, run=subprocess.run, guard_run=None, now=None):
    require(isinstance(spec, dict) and type(spec.get('schema')) is int and spec['schema'] == 1 and
            set(spec) <= {'schema', 'platform', 'targetId', 'fixtureId', 'appRevision', 'runtimeRevision', 'inputs', 'fixture', 'device', 'android', 'delivery'},
            'invalid-spec')
    root = Path(root).resolve()
    platform = spec.get('platform', 'host')
    require(platform in ('host', 'android', 'ios', 'macos'), 'invalid-platform')
    require(isinstance(spec.get('targetId'), str) and ID.fullmatch(spec['targetId']), 'invalid-target')
    require(isinstance(spec.get('fixtureId'), str) and SHA.fullmatch(spec['fixtureId']) and
            isinstance(spec.get('fixture'), dict) and spec['fixtureId'] == spec['fixture'].get('sha256'), 'fixture-identity-mismatch')
    require(platform not in ('android', 'ios') or 'device' in spec, 'device-evidence-required')
    require(platform != 'android' or 'android' in spec, 'android-guard-required')
    require('android' not in spec or platform == 'android', 'android-platform-required')
    require(platform not in ('android', 'ios') or
            (isinstance(spec['device'], dict) and spec['device'].get('id') == spec['targetId']), 'device-context-mismatch')
    now = now or dt.datetime.now(dt.timezone.utc)
    fingerprint = _source(spec, root, run)
    directory = _fixture(spec.get('fixture'), root)
    result = {'schema': 1, 'status': 'preflight-passed', 'platform': platform,
              'observedAt': now.isoformat(), 'appRevision': spec['appRevision'],
              'runtimeRevision': spec['runtimeRevision'], 'sourceFingerprint': fingerprint,
              'targetId': spec['targetId'], 'fixtureId': spec['fixtureId'],
              'sourceCoverage': 'explicit-caller-selected-tracked-inputs',
              'fixture': {'sha256': spec['fixture']['sha256'], 'scope': 'marked-isolated-synthetic'},
              'preflightToolSha256': _hash(_read(Path(__file__))),
              'guardToolSha256': _hash(_read(_GUARD_PATH))}
    if 'device' in spec:
        result['device'] = _device(spec['device'], directory, now)
    if 'android' in spec:
        result['android'] = _android(spec['android'], spec, directory, guard_run)
    if 'delivery' in spec:
        result['delivery'] = _delivery(spec['delivery'], root, run)
    return result


def write_receipt(path, result):
    path = Path(path)
    require(path.is_absolute() and not path.exists() and not path.is_symlink(), 'output-already-exists')
    data = json.dumps(result, sort_keys=True, indent=2).encode() + b'\n'
    try:
        fd, name = tempfile.mkstemp(prefix='.preflight-', dir=path.parent)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.link(name, path)
        finally:
            os.unlink(name)
    except OSError:
        raise PreflightError('output-unavailable') from None


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        raise PreflightError('invalid-arguments')


def main(argv=None):
    parser = SafeParser(description=__doc__)
    parser.add_argument('--spec', type=Path, required=True)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    try:
        args = parser.parse_args(argv)
        result = run_preflight(_json(_read(args.spec)), args.root)
        write_receipt(args.output, result)
        print(json.dumps({'status': result['status'], 'receiptSha256': _hash(_read(args.output))}, sort_keys=True))
        return 0
    except PreflightError as exc:
        print(json.dumps({'status': 'refused', 'code': exc.code}, sort_keys=True))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
