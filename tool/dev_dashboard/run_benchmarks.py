#!/usr/bin/env python3
"""App-owned profile build/cache and real scenario registry, over Madar host tooling."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import plistlib
import os
import stat
from contextlib import contextmanager
import re
import subprocess
import sys
import uuid
from urllib.parse import unquote, urljoin, urlsplit

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / 'tool/dev_dashboard/operations.json'
EXECUTABLE = ROOT / 'build/macos/Build/Products/Profile/Dakhl_Restaurant Dev.app/Contents/MacOS/Dakhl_Restaurant Dev'


def command(argv, cwd=ROOT):
    completed = subprocess.run(argv, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if completed.returncode:
        # Build/check diagnostics go to stderr, never become benchmark JSON.
        sys.stderr.write(completed.stdout[-12000:] + completed.stderr[-12000:])
        raise RuntimeError(f'command_failed:{Path(argv[0]).name}')
    return completed.stdout


def runtime_engine_identity():
    """Bind measured builds to the reviewed pin and actual consumed package bytes."""
    manifest_bytes = (ROOT / 'engine-dependency.json').read_bytes()
    pin = json.loads(manifest_bytes)
    expected = pin.get('git_commit')
    if not isinstance(expected, str) or not re.fullmatch(r'[0-9a-f]{40}', expected):
        raise RuntimeError('engine_manifest_invalid')
    engine = (ROOT.parent / 'Madar_Engine').resolve()
    actual = command(['git', 'rev-parse', 'HEAD'], engine).strip()
    if actual != expected:
        raise RuntimeError('engine_revision_mismatch')
    if command(['git', 'status', '--porcelain', '--', 'packages'], engine).strip():
        raise RuntimeError('engine_source_dirty')
    packages = pin.get('packages')
    if not isinstance(packages, dict) or not packages:
        raise RuntimeError('engine_manifest_invalid')
    paths = []
    versions = {}
    config_file = ROOT / '.dart_tool/package_config.json'
    config = json.loads(config_file.read_text())
    resolved = [entry for entry in config.get('packages', [])
                if isinstance(entry, dict) and str(entry.get('name', '')).startswith('madar_')]
    if config.get('configVersion') != 2 or len(resolved) != len(packages) or {entry.get('name') for entry in resolved} != set(packages):
        raise RuntimeError('engine_resolution_mismatch')

    def local_uri(value, base):
        if not isinstance(value, str):
            raise RuntimeError('engine_resolution_mismatch')
        uri = urlsplit(urljoin(base, value))
        if uri.scheme != 'file' or uri.netloc or uri.query or uri.fragment:
            raise RuntimeError('engine_resolution_mismatch')
        return Path(unquote(uri.path)).resolve()

    resolution = {}
    for name, package in sorted(packages.items()):
        if not isinstance(package, dict) or not isinstance(package.get('path'), str):
            raise RuntimeError('engine_manifest_invalid')
        directory = (ROOT / package['path']).resolve()
        if not directory.is_relative_to(engine) or not (directory / 'lib').is_dir():
            raise RuntimeError('engine_package_source_invalid')
        entry = next(entry for entry in resolved if entry['name'] == name)
        resolved_root = local_uri(entry.get('rootUri'), config_file.resolve().as_uri())
        resolved_lib = local_uri(entry.get('packageUri'), resolved_root.as_uri() + '/')
        if resolved_root != directory or resolved_lib != (directory / 'lib').resolve():
            raise RuntimeError('engine_resolution_mismatch')
        resolution[name] = dict(root=directory.relative_to(engine).as_posix(),
                                library=resolved_lib.relative_to(engine).as_posix())
        paths.append(directory.relative_to(engine).as_posix())
        versions[name] = package.get('version')
    tracked = command(['git', 'ls-files', '-z', '--', *paths], engine).split('\0')
    digest = hashlib.sha256()
    count = 0
    for relative in sorted(path for path in tracked if path):
        path = engine / relative
        if not path.resolve().is_relative_to(engine) or not path.is_file():
            raise RuntimeError('engine_package_source_invalid')
        digest.update(relative.encode() + b'\0' + path.read_bytes() + b'\0')
        count += 1
    if not count:
        raise RuntimeError('engine_package_source_invalid')
    return dict(gitCommit=actual, manifestFingerprint=hashlib.sha256(manifest_bytes).hexdigest(),
                sourceFingerprint=digest.hexdigest(), packageVersions=versions,
                resolutionFingerprint=hashlib.sha256(json.dumps(resolution, sort_keys=True).encode()).hexdigest())


def source_fingerprint(engine_identity=None):
    digest = hashlib.sha256()
    for root in ('lib', 'assets', 'macos'):
        for path in sorted((ROOT / root).rglob('*')):
            relative = path.relative_to(ROOT)
            if not path.is_file() or any(part in {'Pods', 'ephemeral', 'xcuserdata', '.symlinks'} for part in relative.parts):
                continue
            digest.update(str(relative).encode() + b'\0' + path.read_bytes() + b'\0')
    for name in ('pubspec.yaml', 'pubspec.lock'):
        digest.update(name.encode() + b'\0' + (ROOT / name).read_bytes())
    identity = engine_identity if engine_identity is not None else runtime_engine_identity()
    digest.update(b'runtime-engine\0' + json.dumps(identity, sort_keys=True).encode())
    return digest.hexdigest()


def binary_fingerprint():
    digest = hashlib.sha256()
    for path in (EXECUTABLE, EXECUTABLE.parent.parent / 'Frameworks/App.framework/App'):
        if path.is_file():
            digest.update(path.name.encode() + b'\0' + path.read_bytes())
    return digest.hexdigest()


def apple_toolchain_identity():
    identity = dict(xcode=command(['xcodebuild', '-version']).strip(),
                    macosSdkBuild=command(['xcrun', '--sdk', 'macosx', '--show-sdk-build-version']).strip())
    if not all(identity.values()):
        raise RuntimeError('apple_toolchain_identity_unavailable')
    return identity


REVIEWED_BUNDLE_ID = 'com.eros.dakhlrestaurant.phase00'
PHASE02_CASES = {'accounts.open', 'accounts.save', 'accounts.migrate_legacy',
                 'accounts.replace', 'accounts.recover_previous', 'workspace.save_restore'}
PHASE02_PROFILES = {'small': 10, 'medium': 1000, 'largest': 10000}


@contextmanager
def _manifest_directory(path, *, create=False):
    """Open every directory component without following filesystem redirects."""
    path = Path(path)
    if not path.is_absolute() or '..' in path.parts:
        raise RuntimeError('phase02_manifest_directory_invalid')
    descriptor = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY)
    try:
        for component in path.parts[1:]:
            if create:
                try:
                    os.mkdir(component, mode=0o700, dir_fd=descriptor)
                except FileExistsError:
                    pass
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                            dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        yield descriptor
    except OSError:
        raise RuntimeError('phase02_manifest_directory_redirected_or_unavailable') from None
    finally:
        os.close(descriptor)


def phase02_manifest_path(executable, case, fixture, run_id, *, home_directory=None):
    """Use only the reviewed app's existing sandbox temporary directory."""
    try:
        info = plistlib.loads((executable.parent.parent / 'Info.plist').read_bytes())
        config = (ROOT / 'macos/Runner/Configs/AppInfo.xcconfig').read_text()
        configured = re.search(r'^PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([A-Za-z0-9.-]+)\s*$', config, re.M)
    except (OSError, ValueError):
        raise RuntimeError('phase02_bundle_identity_invalid') from None
    if not isinstance(info, dict) or info.get('CFBundleIdentifier') != REVIEWED_BUNDLE_ID or configured is None or configured[1] != REVIEWED_BUNDLE_ID:
        raise RuntimeError('phase02_bundle_identity_invalid')
    if case not in PHASE02_CASES or fixture not in PHASE02_PROFILES or not re.fullmatch(r'[a-f0-9]{32}', run_id):
        raise RuntimeError('phase02_manifest_identity_invalid')
    temporary = (home_directory or Path.home()) / 'Library/Containers' / REVIEWED_BUNDLE_ID / 'Data/tmp'
    try:
        with _manifest_directory(temporary) as temporary_fd:
            directory_name = 'dakhl-phase02-benchmark-manifests'
            try:
                os.mkdir(directory_name, mode=0o700, dir_fd=temporary_fd)
            except FileExistsError:
                pass
            directory_fd = os.open(directory_name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                                   dir_fd=temporary_fd)
            try:
                name = case + '-' + fixture + '-' + run_id + '.json'
                try:
                    os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
                except FileNotFoundError:
                    return temporary / directory_name / name
                raise RuntimeError('phase02_manifest_already_exists')
            finally:
                os.close(directory_fd)
    except (OSError, RuntimeError):
        raise RuntimeError('phase02_sandbox_temp_unavailable_or_redirected') from None


def _validate_phase02_manifest(manifest, profile):
    common = {'profile', 'synthetic', 'sourceSchema', 'legacySourceSchema', 'recordKind',
              'recordCount', 'canonicalBytes', 'legacyInputBytes', 'replacementBytes',
              'accountLimitBytes', 'workspaceBytes', 'heldDrafts', 'activeDrafts',
              'largestMarginPolicyBytes'}
    expected = common | ({'noteCharactersPerRecord'} if profile == 'largest' else {'notePattern'})
    maximum = 20 * 1024 * 1024
    fixed = {'sourceSchema': 11, 'legacySourceSchema': 1, 'recordCount': PHASE02_PROFILES[profile],
             'accountLimitBytes': maximum, 'heldDrafts': 40, 'activeDrafts': 1,
             'largestMarginPolicyBytes': 65536}
    if not isinstance(manifest, dict) or set(manifest) != expected or manifest['profile'] != profile or manifest['synthetic'] is not True or manifest['recordKind'] != 'cash transactions; no operating commands':
        raise RuntimeError('phase02_fixture_manifest_invalid')
    if any(type(manifest[key]) is not int or manifest[key] != value for key, value in fixed.items()):
        raise RuntimeError('phase02_fixture_manifest_invalid')
    for key in ('canonicalBytes', 'legacyInputBytes', 'replacementBytes'):
        value = manifest[key]
        if type(value) is not int or not 3 * fixed['recordCount'] <= value <= maximum:
            raise RuntimeError('phase02_fixture_manifest_invalid')
        if profile == 'largest' and value <= 19 * 1024 * 1024:
            raise RuntimeError('phase02_fixture_manifest_invalid')
    workspace = manifest['workspaceBytes']
    if type(workspace) is not int or not 3 * 41 <= workspace <= maximum:
        raise RuntimeError('phase02_fixture_manifest_invalid')
    if profile == 'largest':
        if type(manifest['noteCharactersPerRecord']) is not int or not 1 <= manifest['noteCharactersPerRecord'] <= 2000:
            raise RuntimeError('phase02_fixture_manifest_invalid')
    elif manifest['notePattern'] != 'synthetic-{index}':
        raise RuntimeError('phase02_fixture_manifest_invalid')


def collect_phase02_manifest(path, profile, evidence_directory):
    """Bind bounded metadata to its exclusive case/profile/run source filename."""
    match = re.fullmatch(r'([a-z._]+)-(small|medium|largest)-([a-f0-9]{32})\.json', path.name)
    if profile not in PHASE02_PROFILES or match is None or match[1] not in PHASE02_CASES or match[2] != profile:
        raise RuntimeError('phase02_fixture_manifest_attempt_invalid')
    try:
        with _manifest_directory(path.parent) as directory_fd:
            descriptor = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory_fd)
            with os.fdopen(descriptor, 'rb') as source:
                if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                    raise RuntimeError('phase02_fixture_manifest_source_invalid')
                content = source.read(16 * 1024 + 1)
    except OSError:
        raise RuntimeError('phase02_fixture_manifest_source_invalid') from None
    if len(content) > 16 * 1024:
        raise RuntimeError('phase02_fixture_manifest_too_large')
    manifest = json.loads(content)
    _validate_phase02_manifest(manifest, profile)
    with _manifest_directory(evidence_directory, create=True) as directory_fd:
        descriptor = os.open(path.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=directory_fd)
        with os.fdopen(descriptor, 'wb') as output:
            output.write(content)
    return manifest, hashlib.sha256(content).hexdigest()


def operation_target(entry):
    return ('lib/platform/phase02_performance_main.dart' if entry.get('phase') == '02'
            else 'lib/platform/performance_main.dart')


def build_profile(fingerprint, sdk, engine_identity=None, apple_toolchain=None,
                  target='lib/platform/performance_main.dart'):
    stamp = ROOT / 'build/dev_dashboard/profile-cache.json'
    identity = engine_identity if engine_identity is not None else runtime_engine_identity()
    toolchain = apple_toolchain if apple_toolchain is not None else apple_toolchain_identity()
    key = dict(sourceFingerprint=fingerprint, sdk=sdk, mode='profile', target=target,
               runtimeEngineIdentity=identity, appleToolchainIdentity=toolchain)
    try:
        cached = json.loads(stamp.read_text())
    except (OSError, ValueError):
        cached = None
    if not EXECUTABLE.is_file() or cached != dict(key=key, binaryFingerprint=binary_fingerprint()):
        sys.stderr.write('Preparing macOS profile benchmark build…\n')
        command(['flutter', 'build', 'macos', '--profile', '--no-pub', '-t', key['target']])
        stamp.parent.mkdir(parents=True, exist_ok=True)
        stamp.write_text(json.dumps(dict(key=key, binaryFingerprint=binary_fingerprint()), sort_keys=True))
    return EXECUTABLE


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine-tools-root', type=Path, required=True)
    parser.add_argument('--case', action='append', default=[])
    parser.add_argument('--iterations', type=int, help='1–100, defaults to the operation registry')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--fixture', choices=['small', 'medium', 'largest'], default='small',
                        help='Synthetic Phase02 workload profile; Phase01 cases ignore this option')
    args = parser.parse_args()
    if platform.system() != 'Darwin':
        parser.error('These app cases require macOS profile mode.')
    if args.iterations is not None and not 1 <= args.iterations <= 100:
        parser.error('--iterations must be 1–100')
    operations = {entry['id']: entry for entry in json.loads(REGISTRY.read_text())['operations']}
    cases = args.case or [key for key, value in operations.items() if value['status'] == 'ready']
    if cases == ['all-ready']:
        cases = [key for key, value in operations.items() if value['status'] == 'ready']
    if len(set(cases)) != len(cases) or any(key not in operations or operations[key]['status'] != 'ready' for key in cases):
        parser.error('Select unique ready operation IDs; planned operations cannot run.')
    tooling_root = args.engine_tools_root.resolve()
    module_path = tooling_root / 'tool/dev_benchmarks/benchmark.py'
    module_spec = importlib.util.spec_from_file_location('madar_dev_benchmark', module_path)
    if module_spec is None or module_spec.loader is None:
        parser.error('Madar benchmark tooling is missing.')
    runner_fingerprint = hashlib.sha256(Path(__file__).read_bytes() + REGISTRY.read_bytes()).hexdigest()
    tooling_fingerprint = hashlib.sha256(module_path.read_bytes()).hexdigest()
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    # Verify actual dependency source before executing app or measuring anything.
    command(['flutter', 'pub', 'get', '--enforce-lockfile'])
    command(['python3', 'scripts/check-engine.py'])
    sdk = json.loads(command(['flutter', '--version', '--machine']))
    engine_identity = runtime_engine_identity()
    toolchain = apple_toolchain_identity()
    fingerprint = source_fingerprint(engine_identity)
    if source_fingerprint() != fingerprint or apple_toolchain_identity() != toolchain:
        raise RuntimeError('source_changed_during_profile_build')
    version = re.search(r'^version:\s*(\S+)', (ROOT / 'pubspec.yaml').read_text(), re.M).group(1)
    engine_commit = engine_identity['gitCommit']
    source_commit = command(['git', 'rev-parse', 'HEAD']).strip()
    source_dirty = bool(command(['git', 'status', '--porcelain']))
    results = []
    for case in cases:
        entry = operations[case]
        count = args.iterations or entry['defaultIterations']
        executable = build_profile(fingerprint, sdk, engine_identity, toolchain,
                                   target=operation_target(entry))
        if source_fingerprint() != fingerprint or apple_toolchain_identity() != toolchain:
            raise RuntimeError('source_changed_during_profile_build')
        phase02 = entry.get('phase') == '02'
        run_id = uuid.uuid4().hex
        manifest_path = None
        argv = [str(executable), '--case', case, '--iterations',
                str(1 if entry['measurementKind'] == 'startup' else count), '--run-id', run_id]
        if phase02:
            manifest_path = phase02_manifest_path(executable, case, args.fixture, run_id)
            argv += ['--fixture', args.fixture, '--fixture-manifest', str(manifest_path)]
        fixture_source = ROOT / ('lib/platform/phase02_performance_scenarios.dart' if phase02
                                 else 'lib/platform/performance_scenarios.dart')
        fixture_identity = case + ':' + entry['scenarioVersion'] + (':' + args.fixture if phase02 else '')
        spec = dict(operationId=case, label=entry['label'], argv=argv, cwd=str(ROOT), iterations=count, appVersion=version, sourceCommit=source_commit, sourceDirty=source_dirty, sourceFingerprint=fingerprint, engineCommit=engine_commit, targetId='macos-host', buildMode='profile', measurementKind=entry['measurementKind'], scenarioVersion=entry['scenarioVersion'], timeoutSeconds=900 if phase02 else 45, sampleIntervalMs=20, fixtureFingerprint=hashlib.sha256(fixture_source.read_bytes() + fixture_identity.encode()).hexdigest())
        result = module.run_benchmark(spec)
        if phase02:
            result['fixtureProfile'] = args.fixture
            if result['status'] == 'passed':
                if manifest_path is None or not manifest_path.is_file():
                    raise RuntimeError('phase02_fixture_manifest_missing')
                manifest, manifest_fingerprint = collect_phase02_manifest(
                    manifest_path, args.fixture, ROOT / 'outputs/phase02/performance-manifests')
                result['fixtureManifest'] = manifest
                result['fixtureManifestFingerprint'] = manifest_fingerprint
                result['fixtureManifestArtifact'] = 'outputs/phase02/performance-manifests/' + manifest_path.name
            result['resourceWindowScope'] = ('One host start/end window: operation samples plus '
                'inter-iteration fixture reset, teardown and rendering setup. Elapsed samples exclude '
                'fixture reset and end at actual raster completion. RAM/CPU are not per-sample isolated.')
        result['runtimeEngineIdentity'] = engine_identity
        result['environment']['flutterVersion'] = sdk['frameworkVersion']
        result['environment']['dartVersion'] = sdk['dartSdkVersion']
        result['environment']['appleToolchain'] = toolchain
        result['environment']['appBenchmarkRunnerFingerprint'] = runner_fingerprint
        result['environment']['benchmarkToolsCommit'] = command(['git', 'rev-parse', 'HEAD'], tooling_root).strip()
        result['environment']['benchmarkToolsFingerprint'] = tooling_fingerprint
        result['scope'] = entry['scope']
        # Environment additions affect comparability and must be recomputed.
        result['comparabilityKey'] = module.comparability_key(result)
        module.validate_result(result)
        results.append(result)
    if source_fingerprint() != fingerprint or hashlib.sha256(module_path.read_bytes()).hexdigest() != tooling_fingerprint or apple_toolchain_identity() != toolchain:
        raise RuntimeError('benchmark_source_changed_during_measurement')
    output = results[0] if len(results) == 1 else dict(schemaVersion=1, results=results)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_name(args.output.name + '.tmp-' + uuid.uuid4().hex)
    temporary.write_text(json.dumps(output, indent=2, allow_nan=False) + '\n')
    temporary.replace(args.output)
    print(json.dumps(output, allow_nan=False))
    return 0 if all(value['status'] == 'passed' for value in results) else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError) as error:
        sys.stderr.write(f'Benchmark failed: {error}\n')
        sys.exit(1)
