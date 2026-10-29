#!/usr/bin/env python3
"""App-owned profile build/cache and real scenario registry, over Madar host tooling."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
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


def build_profile(fingerprint, sdk, engine_identity=None, apple_toolchain=None):
    stamp = ROOT / 'build/dev_dashboard/profile-cache.json'
    identity = engine_identity if engine_identity is not None else runtime_engine_identity()
    toolchain = apple_toolchain if apple_toolchain is not None else apple_toolchain_identity()
    key = dict(sourceFingerprint=fingerprint, sdk=sdk, mode='profile', target='lib/platform/performance_main.dart',
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
    executable = build_profile(fingerprint, sdk, engine_identity, toolchain)
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
        spec = dict(operationId=case, label=entry['label'], argv=[str(executable), '--case', case, '--iterations', str(1 if entry['measurementKind'] == 'startup' else count), '--run-id', uuid.uuid4().hex], cwd=str(ROOT), iterations=count, appVersion=version, sourceCommit=source_commit, sourceDirty=source_dirty, sourceFingerprint=fingerprint, engineCommit=engine_commit, targetId='macos-host', buildMode='profile', measurementKind=entry['measurementKind'], scenarioVersion=entry['scenarioVersion'], timeoutSeconds=45, sampleIntervalMs=20, fixtureFingerprint=hashlib.sha256((ROOT / 'lib/platform/performance_scenarios.dart').read_bytes() + (case + ':' + entry['scenarioVersion']).encode()).hexdigest())
        result = module.run_benchmark(spec)
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
