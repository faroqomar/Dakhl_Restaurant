#!/usr/bin/env python3
"""Task-owned fixture APK stage runner. Default is plan; --execute is explicit.

No Flutter install/test/drive/discovery, uninstall, clear-data or target reset.
Root must serialize this with other native builds in this checkout. Real native
picker actions belong to Root. Receipts describe actual results, never recovery
of the earlier Android installation. The helper never directly inspects/copies
signing keys; ordinary Gradle debug signing uses its configured key. No real
account data is read.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import queue
import re
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import time
import urllib.parse
import uuid

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
ENGINE = ROOT.parent / 'Madar_Engine'
SDK = Path('/Users/eros/Library/Android/sdk')
ADB = SDK / 'platform-tools/adb'
DART = Path('/Users/eros/Dev/flutter/bin/dart')
JAVA = Path('/Library/Java/JavaVirtualMachines/jdk-24.jdk/Contents/Home')
GUARD = Path('/Users/eros/.codex/worktrees/phase02-publish-app/Dakhl_Restaurant/scripts/android_install_guard.py')
GUARD_SHA = 'f4c9a44a8efeec88c6d107dfabd7e0327bb191133230b43e51be16e45cbd219b'
SOURCE = '5a11c66dbf665972b17b545c105eac74c17bfeeb'
RUNTIME = 'a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294'
ACTIVITY = 'com.eros.dakhlrestaurant.phase00.MainActivity'
NATIVE = ('write', 'read', 'wrong-nonce', 'read-again', 'recover', 'read-recovered')
PICKER = ('cancel-open', 'cancel-save', 'import-file')
LOG_LIMIT = 16 * 1024 * 1024
URL = re.compile(r'(?:https?|wss?)://[^\s\x1b<>]+')


def now():
    return datetime.now(timezone.utc).isoformat()


def clean(text):
    return URL.sub('<redacted-url>', text)


class Failure(Exception):
    pass


def require(condition, code):
    if not condition:
        raise Failure(code)


def digest(path):
    h = hashlib.sha256()
    require(path.is_file() and not path.is_symlink(), 'unsafe-file')
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def write_json(path, value):
    with path.open('x') as destination:
        json.dump(value, destination, indent=2)
        destination.write('\n')


def call(args, timeout=30, binary=False, env=None, cwd=ROOT):
    result = subprocess.run([str(x) for x in args], cwd=cwd, env=env,
                            capture_output=True, text=not binary, timeout=timeout)
    require(result.returncode == 0, 'command-failed:' + Path(str(args[0])).name)
    return result.stdout


def adb(identity, *args, **kwargs):
    return call([ADB, '-s', identity['serial'], *args], **kwargs)


def stop_group(process):
    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=10)


def stream(args, log, timeout, env=None, cwd=ROOT):
    """Stream redacted output; retain the original exit code and bounded cleanup."""
    start = time.monotonic()
    process = subprocess.Popen([str(x) for x in args], cwd=cwd, env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, encoding='utf-8', errors='replace',
                               start_new_session=True, bufsize=1)
    messages = queue.Queue(maxsize=256)
    overflow = threading.Event()

    def read():
        for line in process.stdout:
            if len(line) > 65536:
                overflow.set()
                break
            try:
                messages.put(clean(line), timeout=1)
            except queue.Full:
                overflow.set()
                break
        try:
            messages.put(None, timeout=1)
        except queue.Full:
            overflow.set()

    threading.Thread(target=read, daemon=True).start()
    size = 0
    timed_out = False
    try:
        with log.open('x') as destination:
            while True:
                if overflow.is_set() or size > LOG_LIMIT:
                    raise Failure('command-log-overflow')
                if time.monotonic() - start > timeout:
                    timed_out = True
                    break
                try:
                    line = messages.get(timeout=.2)
                except queue.Empty:
                    continue
                if line is None:
                    break
                size += len(line.encode())
                destination.write(line)
                destination.flush()
                print(line, end='', flush=True)
            if timed_out:
                raise Failure('command-timeout')
        return process.wait(timeout=10)
    finally:
        stop_group(process)
        process.stdout.close()


def source_check():
    require(call(['git', 'rev-parse', 'HEAD']).strip() == SOURCE, 'app-source-changed')
    require(call(['git', '-C', ENGINE, 'rev-parse', 'HEAD']).strip() == RUNTIME, 'engine-source-changed')
    paths = ['lib', 'test', 'integration_test', 'android', 'pubspec.yaml', 'pubspec.lock', 'engine-dependency.json']
    require(not call(['git', 'status', '--porcelain', '--', *paths]).strip(), 'dirty-runtime-source')
    require(digest(GUARD) == GUARD_SHA, 'reviewed-guard-changed')
    require(json.loads((ROOT / 'engine-dependency.json').read_text())['git_commit'] == RUNTIME,
            'runtime-pin-changed')
    checker_env = os.environ.copy()
    checker_env['PATH'] = str(DART.parent) + os.pathsep + checker_env.get('PATH', '')
    call([sys.executable, ROOT / 'scripts/check-engine.py'], timeout=60, env=checker_env)


def load_identity(execute):
    identity = json.loads((BASE / 'android-identity.json').read_text())
    require(identity.get('taskCreated') is True and identity.get('avdCreated') is True,
            'unowned-target')
    require(identity.get('sourceRevision') == SOURCE and identity.get('runtimeRevision') == RUNTIME,
            'identity-source-mismatch')
    require(bool(re.fullmatch(r'[0-9a-f]{32}', identity.get('fixtureId', ''))), 'invalid-fixture-id')
    require(bool(re.fullmatch(r'com\.eros\.dakhlrestaurant\.phase02\.verify\.[a-z][a-z0-9_]{7,63}',
                              identity.get('package', ''))), 'invalid-package')
    require(bool(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,127}', identity.get('avdName', ''))),
            'invalid-avd')
    if execute:
        require(bool(re.fullmatch(r'emulator-[0-9]{4,5}', identity.get('serial', ''))), 'serial-required')
        require(identity.get('booted') is True, 'target-not-recorded-booted')
    return identity


def tools():
    versions = []
    for path in (SDK / 'build-tools').iterdir():
        if re.fullmatch(r'\d+\.\d+\.\d+', path.name):
            version = tuple(map(int, path.name.split('.')))
            if version[0] >= 36 and all((path / name).is_file() for name in ('aapt2', 'apksigner')):
                versions.append((version, path))
    require(bool(versions), 'android-build-tools-unavailable')
    selected = max(versions)[1]
    return selected / 'aapt2', selected / 'apksigner'


def reviewed_guard_module():
    require(digest(GUARD) == GUARD_SHA, 'reviewed-guard-changed')
    spec = importlib.util.spec_from_file_location('phase02_reviewed_android_guard', GUARD)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def package_info(apk, aapt2, apksigner, expected):
    text = call([aapt2, 'dump', 'badging', apk])
    rows = [line for line in text.splitlines() if line.startswith('package:')]
    require(len(rows) == 1 and f"name='{expected}'" in rows[0] and " split='" not in rows[0],
            'built-package-mismatch')
    version = re.search(r"versionCode='([0-9]+)'", rows[0])
    require(version is not None, 'built-version-unknown')
    text = call([apksigner, 'verify', '--verbose', '--print-certs', apk])
    guard = reviewed_guard_module()
    try:
        signer = guard.parse_signer_report(text)
    except guard.GuardError:
        raise Failure('built-signer-unknown') from None
    return {'package': expected, 'versionCode': int(version[1]), 'signerSha256': signer,
            'apkSha256': digest(apk)}


def guard_args(identity, apk, info, aapt2, apksigner, mode, preservation=None):
    argv = [sys.executable, GUARD, '--apk', apk, '--sha256', info['apkSha256'],
            '--package', identity['package'], '--signer-sha256', info['signerSha256'],
            '--serial', identity['serial'], '--avd-name', identity['avdName'],
            '--mode', mode, '--fixture-id', identity['fixtureId'], '--fixture-only',
            '--source-revision', SOURCE, '--runtime-revision', RUNTIME,
            '--adb', ADB, '--aapt2', aapt2, '--apksigner', apksigner]
    if preservation:
        argv.extend(['--preservation-receipt', preservation])
    return [str(x) for x in argv]


def run_guard(argv, receipt):
    result = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True, timeout=300)
    try:
        data = json.loads(result.stdout)
    except ValueError:
        raise Failure('guard-output-invalid') from None
    write_json(receipt, {'exitCode': result.returncode, 'result': data})
    return result.returncode, data


def fixture_marker(identity):
    return adb(identity, 'exec-out', 'run-as', identity['package'], 'cat',
               'files/dakhl_phase02_fixture_id').strip()


def force_stop(identity):
    adb(identity, 'shell', 'am', 'force-stop', identity['package'])
    result = subprocess.run([str(ADB), '-s', identity['serial'], 'shell', 'pidof', identity['package']],
                            capture_output=True, text=True, timeout=15)
    require(result.returncode == 1 and not result.stdout.strip(), 'owned-process-did-not-stop')


def preserve(identity, directory):
    require(fixture_marker(identity) == identity['fixtureId'], 'fixture-marker-mismatch')
    force_stop(identity)
    paths = adb(identity, 'shell', 'pm', 'path', '--user', '0', identity['package']).strip().splitlines()
    require(len(paths) == 1 and bool(re.fullmatch(r'package:/data/app/[A-Za-z0-9_~+/=.-]+/base\.apk', paths[0])),
            'existing-apk-ambiguous')
    installed = directory / 'installed-before.apk'
    adb(identity, 'pull', paths[0][8:], installed, timeout=90)
    archive = directory / 'synthetic-files-before.tar'
    with archive.open('xb') as output:
        result = subprocess.run([str(ADB), '-s', identity['serial'], 'exec-out', 'run-as',
                                 identity['package'], 'tar', '-cf', '-', 'files'],
                                stdout=output, stderr=subprocess.PIPE, timeout=90)
    require(result.returncode == 0 and archive.stat().st_size > 0, 'fixture-archive-failed')
    receipt = directory / 'preservation.json'
    write_json(receipt, {'schema': 1, 'serial': identity['serial'], 'package': identity['package'],
                         'fixture_id': identity['fixtureId'], 'installed_apk_sha256': digest(installed),
                         'backup_path': str(archive), 'backup_sha256': digest(archive)})
    return receipt


def install(identity, apk, info, directory, aapt2, apksigner, record):
    probe = guard_args(identity, apk, info, aapt2, apksigner, 'new-isolated-fixture')
    code, state = run_guard(probe, directory / 'guard-absence-probe.json')
    preservation = None
    if code == 0 and state.get('status') == 'preflight-passed':
        mode = 'new-isolated-fixture'
        record['targetPreflightVerified'] = True
    elif code == 2 and state == {'status': 'refused', 'code': 'unexpected-installed-package'}:
        mode = 'existing-fixture'
        record['targetPreflightVerified'] = True
        preservation = preserve(identity, directory)
    else:
        raise Failure('guard-target-or-candidate-refused')
    argv = guard_args(identity, apk, info, aapt2, apksigner, mode, preservation)
    code, state = run_guard(argv, directory / 'guard-preflight.json')
    require(code == 0 and state.get('status') == 'preflight-passed', 'guard-preflight-refused')
    record['installAttempted'] = True
    code, state = run_guard(argv + ['--execute'], directory / 'guard-install.json')
    require(code == 0 and state.get('status') == 'installed', 'guard-install-refused')
    if mode == 'new-isolated-fixture':
        # The guard proved this namespace was absent immediately before install.
        # Create only its task marker; never overwrite an existing marker.
        script = ('mkdir -p files && test ! -e files/dakhl_phase02_fixture_id && '
                  "(set -C; printf '%s\\n' " + shlex.quote(identity['fixtureId'])
                  + ' > files/dakhl_phase02_fixture_id)')
        adb(identity, 'shell', 'run-as ' + identity['package'] + ' sh -c ' + shlex.quote(script))
    require(fixture_marker(identity) == identity['fixtureId'], 'installed-fixture-marker-mismatch')
    return mode


def native_reports(text):
    results = []
    for line in text.splitlines():
        match = re.search(r'PHASE02_HOST_DRIVER_RESULT (\{.*\})', line)
        if match:
            results.append(json.loads(match[1]))
    return results


def vm_endpoint(uri, forwarded_port):
    parsed = urllib.parse.urlsplit(uri)
    require(parsed.scheme == 'http' and parsed.hostname in ('127.0.0.1', 'localhost')
            and parsed.port is not None and not parsed.query and not parsed.fragment
            and bool(re.fullmatch(r'/[A-Za-z0-9_=-]*/?', parsed.path)), 'vm-uri-invalid')
    return urllib.parse.urlunsplit(('http', f'127.0.0.1:{forwarded_port}', parsed.path, '', ''))


def launch_owned(identity):
    # Match the pinned Flutter SDK launch protocol: nonwaiting Activity command,
    # then separate PID/VM-service/driver readiness. A first-frame wait here can
    # block attaching the very host that is meant to observe the test outcome.
    output = adb(identity, 'shell', 'am', 'start', '-a', 'android.intent.action.MAIN',
                 '-c', 'android.intent.category.LAUNCHER', '-f', '0x20000000',
                 '-n', identity['package'] + '/' + ACTIVITY,
                 '--ez', 'enable-dart-profiling', 'true',
                 '--ez', 'enable-checked-mode', 'true',
                 '--ez', 'verify-entry-points', 'true', timeout=45)
    # Android's activity command can exit zero while reporting launch failure.
    require(not re.search(r'(Error:|Error type|Security\s?exception)', output, re.I),
            'activity-launch-refused')


def run_fixture(identity, kind, label, stage, nonce, directory, record):
    """VM-service auth URI exists only in this process and host-driver environment."""
    force_stop(identity)
    record['prelaunchOwnedProcessAbsent'] = True
    logcat = None
    forwarded = None
    owned_pid = None
    thread_done = threading.Event()
    errors = []
    vm = queue.Queue(maxsize=1)
    log_path = directory / 'native-runtime.log'
    try:
        launch_owned(identity)
        record['activityLaunchProtocol'] = 'nonwaiting am start; bounded PID/VM/driver checks; actual frame/test assertions retained'
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            result = subprocess.run([str(ADB), '-s', identity['serial'], 'shell', 'pidof', identity['package']],
                                    capture_output=True, text=True, timeout=10)
            values = result.stdout.strip().split()
            if result.returncode == 0 and len(values) == 1 and values[0].isdigit():
                owned_pid = int(values[0])
                break
            time.sleep(.2)
        require(owned_pid is not None, 'owned-process-not-ready')
        record['ownedPid'] = owned_pid
        logcat = subprocess.Popen([str(ADB), '-s', identity['serial'], 'logcat', '--pid=' + str(owned_pid),
                                   '-v', 'brief'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True, encoding='utf-8', errors='replace', start_new_session=True)

        def log_reader():
            size = 0
            try:
                with log_path.open('x') as destination:
                    for raw in logcat.stdout:
                        if len(raw) > 65536 or size > LOG_LIMIT:
                            errors.append('native-log-overflow')
                            break
                        for match in URL.finditer(raw):
                            uri = match[0].rstrip('.,;)')
                            if 'Dart VM service is listening on' in raw:
                                try:
                                    vm.put_nowait(uri)
                                except queue.Full:
                                    pass
                        line = clean(raw)
                        size += len(line.encode())
                        destination.write(line)
                        destination.flush()
                        print(line, end='', flush=True)
            except Exception:
                errors.append('native-log-reader-failed')
            finally:
                thread_done.set()

        threading.Thread(target=log_reader, daemon=True).start()
        try:
            uri = vm.get(timeout=60)
        except queue.Empty:
            raise Failure('vm-service-not-observed') from None
        parsed = urllib.parse.urlsplit(uri)
        vm_endpoint(uri, 1)  # Validate before using a remote port in adb arguments.
        forwarded = adb(identity, 'forward', 'tcp:0', 'tcp:' + str(parsed.port), timeout=15).strip()
        require(forwarded.isdigit() and 0 < int(forwarded) < 65536, 'owned-forward-unverified')
        record['ownedForwardPort'] = int(forwarded)
        env = os.environ.copy()
        env['VM_SERVICE_URL'] = vm_endpoint(uri, forwarded)
        uri = None
        print('PHASE02_ANDROID_DRIVER_READY ' + json.dumps({'kind': kind, 'label': label,
                                                              'pid': owned_pid, 'nonce': nonce}), flush=True)
        try:
            code = stream([DART, 'run', BASE / 'integration_driver.dart'],
                          directory / 'host-driver.log', timeout=450 if kind == 'picker' else 330, env=env)
        finally:
            env.pop('VM_SERVICE_URL', None)
        text = (directory / 'host-driver.log').read_text()
        reports = native_reports(text)
        runtime_text = log_path.read_text() if log_path.exists() else ''
        record.update({'driverExitCode': code, 'hostReports': reports})
        if label == 'wrong-nonce':
            expected = expected_wrong_nonce(code, text, reports)
        else:
            expected = code == 0 and 'All tests passed.' in text and len(reports) == 1
            if expected:
                report = reports[0]
                expected = (report.get('stage') == stage and report.get('runNonce') == nonce
                            and report.get('pid') == owned_pid)
                if kind == 'native':
                    expected = expected and all(report.get(name) for name in ('storeId', 'generation'))
                    expected = expected and type(report.get('documentRevision')) is int
                    expected = expected and report.get('held') == (0 if stage in ('recover', 'read-recovered') else 40)
                else:
                    expected = expected and report.get('sourceUnchanged') is True
                    expected = expected and report.get('replacementAndRecovery') == (stage == 'import-file')
                    expected = expected and f'PHASE02_PICKER_COMPLETE {stage} {nonce}' in runtime_text
        require(not errors, errors[0] if errors else 'native-log-error')
        record['expectedOutcomeVerified'] = bool(expected)
        require(expected, 'stage-outcome-unverified')
    finally:
        cleanup = cleanup_runtime(identity, logcat, thread_done, forwarded)
        record['cleanup'] = cleanup
        require(all(cleanup.values()), 'owned-cleanup-unverified')


def cleanup_runtime(identity, logcat, thread_done, forwarded):
    """Attempt each owned resource independently, even after another failure.

    Remove forwarding and stop the app before closing the pipe. If its reader
    does not finish, do not block indefinitely closing a TextIOWrapper held by
    that thread; record its unclosed state as a cleanup failure instead.
    """
    cleanup = {}
    if logcat is not None:
        try:
            stop_group(logcat)
            cleanup['logcatStopped'] = logcat.poll() is not None
        except Exception:
            cleanup['logcatStopped'] = False
    if forwarded is not None and forwarded.isdigit():
        try:
            adb(identity, 'forward', '--remove', 'tcp:' + forwarded, timeout=15)
            cleanup['ownedForwardRemoved'] = True
        except Exception:
            cleanup['ownedForwardRemoved'] = False
    try:
        force_stop(identity)
        cleanup['ownedAppStopped'] = True
    except Exception:
        cleanup['ownedAppStopped'] = False
    if logcat is not None:
        try:
            cleanup['logcatReaderFinished'] = bool(thread_done.wait(timeout=5))
        except Exception:
            cleanup['logcatReaderFinished'] = False
        cleanup['logcatPipeClosed'] = False
        if cleanup['logcatReaderFinished']:
            try:
                logcat.stdout.close()
                cleanup['logcatPipeClosed'] = True
            except Exception:
                pass
    return cleanup


def expected_wrong_nonce(code, driver_text, reports):
    """Accept only the connected integration driver's specific negative response."""
    return (code == 1 and 'Failure Details:' in driver_text
            and 'run_nonce_mismatch' in driver_text and not reports)


def self_checks():
    """Pure review regressions; never run a build, device command or real driver."""
    import io
    import unittest
    from unittest.mock import Mock, patch
    module = sys.modules[__name__]

    class SafetyRegressions(unittest.TestCase):
        def test_activity_launch_does_not_block_pid_and_vm_driver_startup(self):
            events = []
            identity = {'serial': 'emulator-5582',
                        'package': 'com.eros.dakhlrestaurant.phase02.verify.fixture1234'}
            record = {}

            def fake_adb(*args, **kwargs):
                events.append('activity-command')
                self.assertNotIn('-W', args)
                self.assertEqual(kwargs['timeout'], 45)
                return 'Starting: Intent { cmp=synthetic }'

            def fake_pid(*args, **kwargs):
                events.append('bounded-pid')
                self.assertEqual(kwargs['timeout'], 10)
                return subprocess.CompletedProcess([], 0, '12345', '')

            def fake_logcat(*args, **kwargs):
                events.append('logcat-before-driver')
                raise Failure('synthetic-stop-before-vm')

            def fake_cleanup(*args, **kwargs):
                events.append('cleanup')
                return {'ownedAppStopped': True}

            with patch.object(module, 'force_stop'), patch.object(module, 'adb', side_effect=fake_adb), \
                    patch.object(module.subprocess, 'run', side_effect=fake_pid), \
                    patch.object(module.subprocess, 'Popen', side_effect=fake_logcat), \
                    patch.object(module, 'cleanup_runtime', side_effect=fake_cleanup):
                with self.assertRaises(Failure) as caught:
                    module.run_fixture(identity, 'native', 'write', 'write', 'synthetic',
                                       Path('/synthetic-not-created'), record)
            self.assertEqual(str(caught.exception), 'synthetic-stop-before-vm')
            self.assertEqual(events, ['activity-command', 'bounded-pid', 'logcat-before-driver', 'cleanup'])
            self.assertEqual(record['ownedPid'], 12345)
            self.assertNotEqual(record.get('expectedOutcomeVerified'), True)

        def test_activity_zero_exit_with_error_stdout_is_refused(self):
            with patch.object(module, 'adb', return_value='Error type 3: Activity does not exist'):
                with self.assertRaises(Failure) as caught:
                    module.launch_owned({'package': 'synthetic'})
            self.assertEqual(str(caught.exception), 'activity-launch-refused')

        def test_package_signer_report_uses_one_reviewed_parser(self):
            fake_guard = Mock()
            fake_guard.GuardError = type('SyntheticGuardError', (Exception,), {})
            fake_guard.parse_signer_report.return_value = 'a' * 64
            package = 'com.eros.dakhlrestaurant.phase02.verify.fixture1234'
            report = 'Number of signers: 1\nV2 Signer: certificate SHA-256 digest: ' + 'a' * 64
            output = ["package: name='" + package + "' versionCode='1'", report]
            with patch.object(module, 'call', side_effect=output), \
                    patch.object(module, 'reviewed_guard_module', return_value=fake_guard), \
                    patch.object(module, 'digest', return_value='c' * 64):
                result = module.package_info(Path('/synthetic.apk'), 'aapt2', 'apksigner', package)
            fake_guard.parse_signer_report.assert_called_once_with(report)
            self.assertEqual(result['signerSha256'], 'a' * 64)
            fake_guard.parse_signer_report.side_effect = fake_guard.GuardError('ambiguous-signers')
            with patch.object(module, 'call', side_effect=output), \
                    patch.object(module, 'reviewed_guard_module', return_value=fake_guard):
                with self.assertRaises(Failure) as caught:
                    module.package_info(Path('/synthetic.apk'), 'aapt2', 'apksigner', package)
            self.assertEqual(str(caught.exception), 'built-signer-unknown')

        def test_cleanup_errors_do_not_skip_remaining_owned_cleanup(self):
            process = Mock()
            process.stdout.close.side_effect = OSError('synthetic pipe-close error')
            done = Mock()
            done.wait.return_value = True
            with patch.object(module, 'stop_group', side_effect=OSError('synthetic logcat stop error')), \
                    patch.object(module, 'adb') as remove, patch.object(module, 'force_stop') as stop:
                result = module.cleanup_runtime({'serial': 'emulator-5582'}, process, done, '45678')
            remove.assert_called_once_with({'serial': 'emulator-5582'}, 'forward', '--remove', 'tcp:45678', timeout=15)
            stop.assert_called_once()
            self.assertFalse(result['logcatStopped'])
            self.assertFalse(result['logcatPipeClosed'])
            self.assertTrue(result['logcatReaderFinished'])
            self.assertTrue(result['ownedForwardRemoved'])
            self.assertTrue(result['ownedAppStopped'])

        def test_unfinished_log_reader_is_bounded_and_truthfully_failed(self):
            process = Mock()
            process.poll.return_value = 0
            done = Mock()
            done.wait.return_value = False
            with patch.object(module, 'stop_group'), patch.object(module, 'adb') as remove, \
                    patch.object(module, 'force_stop') as stop:
                result = module.cleanup_runtime({'serial': 'emulator-5582'}, process, done, '45678')
            remove.assert_called_once()
            stop.assert_called_once()
            done.wait.assert_called_once_with(timeout=5)
            process.stdout.close.assert_not_called()
            self.assertFalse(result['logcatReaderFinished'])
            self.assertFalse(result['logcatPipeClosed'])

        def test_forward_failure_still_attempts_app_stop(self):
            with patch.object(module, 'adb', side_effect=OSError('synthetic forward error')), \
                    patch.object(module, 'force_stop') as stop:
                result = module.cleanup_runtime({'serial': 'emulator-5582'}, None, None, '45678')
            stop.assert_called_once()
            self.assertFalse(result['ownedForwardRemoved'])
            self.assertTrue(result['ownedAppStopped'])

        def test_sigkill_process_exit_race_is_harmless(self):
            process = Mock()
            process.pid = 12345
            process.poll.return_value = None
            process.wait.side_effect = [subprocess.TimeoutExpired('synthetic', 10), 0]
            with patch.object(module.os, 'killpg', side_effect=[None, ProcessLookupError()]):
                module.stop_group(process)
            self.assertEqual(process.wait.call_count, 2)

        def test_existing_engine_checker_refusal_is_enforced(self):
            for reason in ('dirty-engine-source', 'redirected-package-resolution'):
                seen = []

                def fake_call(args, **kwargs):
                    seen.append([str(value) for value in args])
                    if any(str(value).endswith('scripts/check-engine.py') for value in args):
                        raise Failure(reason)
                    if args[:3] == ['git', 'rev-parse', 'HEAD']:
                        return SOURCE
                    if args[:2] == ['git', '-C']:
                        return RUNTIME
                    return ''

                with self.subTest(reason=reason), patch.object(module, 'call', side_effect=fake_call), \
                        patch.object(module, 'digest', return_value=GUARD_SHA):
                    with self.assertRaises(Failure) as caught:
                        module.source_check()
                    self.assertEqual(str(caught.exception), reason)
                    self.assertTrue(any(row[-1].endswith('scripts/check-engine.py') for row in seen))

        def test_only_connected_driver_negative_response_is_accepted(self):
            negative = 'Failure Details:\nrun_nonce_mismatch: never accept stale evidence.'
            self.assertTrue(module.expected_wrong_nonce(1, negative, []))
            for code, text, reports in [(1, 'driver import or connection failed', []),
                                        (2, negative, []), (0, negative, []),
                                        (1, 'Failure Details: another test error', []),
                                        (1, negative, [{'stage': 'read'}])]:
                with self.subTest(code=code, text=text):
                    self.assertFalse(module.expected_wrong_nonce(code, text, reports))
            # Runtime-only mismatch deliberately is not a predicate input.
            self.assertFalse(module.expected_wrong_nonce(1, 'driver could not connect', []))

    result = unittest.TextTestRunner(stream=sys.stdout, verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(SafetyRegressions))
    return 0 if result.wasSuccessful() else 1


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    if argv == ['--self-check']:
        return self_checks()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=['native', 'picker'])
    parser.add_argument('label', choices=list(NATIVE + PICKER))
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args(argv)
    require(args.label in (NATIVE if args.kind == 'native' else PICKER), 'invalid-stage')
    identity = load_identity(args.execute)
    stage = 'read' if args.label in ('wrong-nonce', 'read-again') else args.label
    entry = ROOT / 'integration_test' / ('phase02_accounts_native_test.dart' if args.kind == 'native'
                                       else 'phase02_file_picker_test.dart')
    init = BASE / 'android-fixture.init.gradle'
    require(identity['package'] in init.read_text(), 'fixture-init-mismatch')
    aapt2, apksigner = tools()
    plan = {'kind': args.kind, 'label': args.label, 'stage': stage, 'entry': str(entry),
            'package': identity['package'], 'avdName': identity['avdName'],
            'serial': identity.get('serial', '<root-must-record-booted-serial>'),
            'buildTool': 'android/gradlew assembleDebug with task-owned applicationId init script',
            'installation': 'reviewed guard; direct verified APK adb install-r only',
            'driver': 'Dart integrationDriver, VM_SERVICE_URL held only in memory/environment',
            'nativeUI': 'Root operates real native picker within existing120-second test deadline',
            'source': SOURCE, 'runtime': RUNTIME, 'guardSha256': GUARD_SHA,
            'aapt2': str(aapt2), 'apksigner': str(apksigner), 'execute': args.execute}
    if not args.execute:
        print(json.dumps(plan, indent=2))
        return 0
    source_check()
    require((JAVA / 'bin/java').is_file(), 'java24-unavailable')
    directory = BASE / 'android-stages' / (args.kind + '-' + args.label)
    directory.parent.mkdir(exist_ok=True)
    directory.mkdir()  # Every attempted stage remains evidence; never overwrite.
    lock = BASE / 'android-stage.lock'
    lock_descriptor = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(lock_descriptor, json.dumps({'pid': os.getpid(), 'stage': str(directory), 'startedAt': now()}).encode())
    os.close(lock_descriptor)
    record = {**plan, 'startedAt': now(), 'expectedOutcomeVerified': False,
              'dataScope': 'new task-owned verification namespace; marked synthetic fixtures only',
              'entrySha256': digest(entry), 'initSha256': digest(init),
              'driverSha256': digest(BASE / 'integration_driver.dart')}
    started = time.monotonic()
    try:
        nonce_path = BASE / 'android-native-nonce.json'
        if args.kind == 'native' and args.label == 'write':
            write_json(nonce_path, {'nonce': str(uuid.uuid4())})
        nonce = (str(uuid.uuid4()) if args.kind == 'picker' or args.label == 'wrong-nonce'
                 else json.loads(nonce_path.read_text())['nonce'])
        require(str(uuid.UUID(nonce)) == nonce, 'invalid-stage-nonce')
        record['nonce'] = nonce
        flag = 'PHASE02_RESTART_STAGE' if args.kind == 'native' else 'PHASE02_PICKER_STAGE'
        defines = ','.join(base64.b64encode(value.encode()).decode()
                           for value in (flag + '=' + stage, 'PHASE02_RUN_NONCE=' + nonce))
        gradle = [ROOT / 'android/gradlew', '--no-daemon', '--console=plain', '--init-script', init,
                  '-Ptarget=' + str(entry), '-Ptarget-platform=android-arm64', '-Pdart-defines=' + defines,
                  '-Pdart-obfuscation=false', '-Ptrack-widget-creation=true', '-Ptree-shake-icons=false',
                  'assembleDebug']
        record['buildArgv'] = [str(x) for x in gradle]
        env = os.environ.copy()
        env['JAVA_HOME'] = str(JAVA)
        build_start_ns = time.time_ns()
        code = stream(gradle, directory / 'build.log', timeout=1200, env=env, cwd=ROOT / 'android')
        record['buildExitCode'] = code
        require(code == 0, 'gradle-build-failed')
        source_check()
        built = ROOT / 'build/app/outputs/apk/debug/app-debug.apk'
        require(built.is_file() and not built.is_symlink() and built.stat().st_mtime_ns >= build_start_ns,
                'fresh-apk-unverified')
        apk = directory / 'fixture.apk'
        with built.open('rb') as source, apk.open('xb') as destination:
            shutil.copyfileobj(source, destination)
        info = package_info(apk, aapt2, apksigner, identity['package'])
        record['apk'] = {**info, 'path': str(apk), 'sourceProvenance': 'recorded build command + unchanged scoped sources'}
        record['installationMode'] = install(identity, apk, info, directory, aapt2, apksigner, record)
        run_fixture(identity, args.kind, args.label, stage, nonce, directory, record)
    except BaseException as error:
        record['error'] = clean(str(error))[:500]
        record['errorType'] = type(error).__name__
        record['expectedOutcomeVerified'] = False
    finally:
        if record.get('targetPreflightVerified') and record.get('installAttempted'):
            try:
                force_stop(identity)
                record['finalOwnedAppStopped'] = True
            except Exception:
                record['finalOwnedAppStopped'] = False
                record['expectedOutcomeVerified'] = False
        record['finishedAt'] = now()
        record['elapsedSeconds'] = time.monotonic() - started
        write_json(directory / 'result.json', record)
        lock.unlink()  # Only the lock created exclusively by this process.
    print('PHASE02_ANDROID_STAGE_RESULT ' + json.dumps({key: record.get(key)
          for key in ('kind', 'label', 'expectedOutcomeVerified', 'driverExitCode', 'error', 'elapsedSeconds')}), flush=True)
    return 0 if record['expectedOutcomeVerified'] else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (Failure, OSError, ValueError, KeyError) as error:
        print(json.dumps({'status': 'refused', 'code': clean(str(error))[:300], 'errorType': type(error).__name__}), flush=True)
        raise SystemExit(2)
