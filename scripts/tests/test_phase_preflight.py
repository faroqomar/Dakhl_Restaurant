import datetime as dt
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

MODULE_PATH = Path(__file__).resolve().parents[1] / 'phase_preflight.py'
SPEC = importlib.util.spec_from_file_location('phase_preflight', MODULE_PATH)
phase = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = phase
SPEC.loader.exec_module(phase)


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.now = dt.datetime(2026, 11, 4, 12, 0, tzinfo=dt.timezone.utc)
        (self.root / 'lib').mkdir()
        (self.root / 'lib/main.dart').write_text('synthetic source')
        (self.root / 'engine-dependency.json').write_text(json.dumps({'git_commit': 'b' * 40}))
        self.fixture = self.root / 'fixtures'
        self.fixture.mkdir()
        (self.fixture / '.dakhl-synthetic-fixture').write_text('dakhl-phase-preflight-v1\n')
        (self.fixture / 'input.json').write_text('{}')
        self.spec = {'schema': 1, 'targetId': 'host-synthetic', 'fixtureId': self.hash(self.fixture / 'input.json'), 'appRevision': 'a' * 40, 'runtimeRevision': 'b' * 40,
                     'inputs': {x: self.hash(self.root / x) for x in ['lib/main.dart', 'engine-dependency.json']},
                     'fixture': {'root': str(self.fixture), 'path': str(self.fixture / 'input.json'),
                                 'sha256': self.hash(self.fixture / 'input.json')}}
        self.commands = []
        self.scopes = 'repo, workflow'
        self.push = True

    def hash(self, path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def tool_run(self, args, **kwargs):
        self.commands.append(args)
        if args[:3] == ['git', 'rev-parse', 'HEAD']:
            out = 'a' * 40 + '\n'
        elif args[:2] == ['git', 'ls-files']:
            out = 'lib/main.dart\0engine-dependency.json\0'
        elif args == ['gh', 'api', '--include', 'user']:
            out = 'HTTP/2.0 200 OK\nX-OAuth-Scopes: ' + self.scopes + '\n\n{"login":"private-name"}'
        elif args == ['gh', 'api', 'repos/example/project']:
            out = json.dumps({'permissions': {'push': self.push}})
        else:
            raise AssertionError(args)
        return subprocess.CompletedProcess(args, 0, out, '')

    def check(self):
        return phase.run_preflight(self.spec, self.root, run=self.tool_run, now=self.now)

    def add_device(self):
        image = self.fixture / 'screen.png'
        image.write_bytes(b'synthetic image')
        self.observation = {'schema': 1, 'tool': 'device_open', 'hostId': 'local',
                            'deviceId': 'device1', 'sessionId': 'session1',
                            'observedAt': self.now.isoformat(), 'controlReady': True,
                            'fixtureReady': True, 'evidence': [{'path': str(image), 'sha256': self.hash(image)}]}
        self.write_observation()

    def write_observation(self):
        p = self.fixture / 'device.json'
        p.write_text(json.dumps(self.observation))
        self.spec['device'] = {'hostId': 'local', 'id': 'device1', 'sessionId': 'session1',
                               'maxAgeSeconds': 120, 'observation': {'path': str(p), 'sha256': self.hash(p)}}

    def assert_refuses(self, code):
        with self.assertRaises(phase.PreflightError) as caught:
            self.check()
        self.assertEqual(caught.exception.code, code)

    def test_exact_tracked_source_and_fixture(self):
        r = self.check()
        self.assertEqual(r['status'], 'preflight-passed')
        self.assertEqual(r['runtimeRevision'], 'b' * 40)
        self.assertEqual(r['fixture']['sha256'], self.spec['fixture']['sha256'])
        self.assertNotIn('install', json.dumps(self.commands))

    def test_changed_input_refuses(self):
        (self.root / 'lib/main.dart').write_text('changed')
        self.assert_refuses('source-hash-mismatch')

    def test_untracked_input_refuses(self):
        (self.root / 'extra').write_text('x')
        self.spec['inputs']['extra'] = self.hash(self.root / 'extra')
        self.assert_refuses('untracked-input')

    def test_source_path_escape_refuses(self):
        self.spec['inputs']['../private'] = 'f' * 64
        self.assert_refuses('invalid-source-path')

    def test_runtime_pin_mismatch_refuses(self):
        self.spec['runtimeRevision'] = 'c' * 40
        self.assert_refuses('runtime-pin-mismatch')

    def test_synthetic_marker_required(self):
        (self.fixture / '.dakhl-synthetic-fixture').unlink()
        self.assert_refuses('unsafe-file')

    def test_fixture_symlink_refuses(self):
        (self.fixture / 'link').symlink_to(self.fixture / 'input.json')
        self.spec['fixture']['path'] = str(self.fixture / 'link')
        self.assert_refuses('unsafe-file')

    def test_fresh_device_observation_binds_session_and_artifacts(self):
        self.add_device()
        r = self.check()
        self.assertEqual(r['device']['proof'], 'operator-observation')
        self.assertFalse(r['device']['liveStateProven'])

    def test_stale_device_observation_refuses(self):
        self.add_device()
        self.observation['observedAt'] = (self.now - dt.timedelta(seconds=121)).isoformat()
        self.write_observation()
        self.assert_refuses('device-observation-stale')

    def test_future_observation_refuses(self):
        self.add_device()
        self.observation['observedAt'] = (self.now + dt.timedelta(seconds=30)).isoformat()
        self.write_observation()
        self.assert_refuses('device-observation-stale')

    def test_wrong_device_refuses(self):
        self.add_device()
        self.spec['device']['id'] = 'other'
        self.assert_refuses('device-context-mismatch')

    def test_changed_device_evidence_refuses(self):
        self.add_device()
        (self.fixture / 'screen.png').write_bytes(b'changed')
        self.assert_refuses('artifact-hash-mismatch')

    def test_delivery_observation_does_not_claim_proven_push(self):
        self.spec['delivery'] = {'repository': 'example/project', 'workflowChanges': True}
        r = self.check()['delivery']
        self.assertEqual(r['status'], 'permissions-observed')
        self.assertFalse(r['writePermissionProven'])
        self.assertNotIn('private-name', json.dumps(r))

    def test_missing_workflow_scope_blocks_before_delivery(self):
        self.spec['delivery'] = {'repository': 'example/project', 'workflowChanges': True}
        self.scopes = 'repo'
        self.assert_refuses('workflow-scope-unverified')

    def test_unknown_token_scopes_refuses_required_workflow(self):
        self.spec['delivery'] = {'repository': 'example/project', 'workflowChanges': True}
        self.scopes = ''
        self.assert_refuses('workflow-scope-unverified')

    def test_no_repository_push_permission_refuses(self):
        self.spec['delivery'] = {'repository': 'example/project', 'workflowChanges': False}
        self.push = False
        self.assert_refuses('repository-write-unverified')

    def test_delivery_failure_redacts_raw_tool_error(self):
        self.spec['delivery'] = {'repository': 'example/project', 'workflowChanges': True}
        def fail(args, **kwargs):
            if args[0] == 'gh':
                return subprocess.CompletedProcess(args, 1, '', 'TOKEN=secret')
            return self.tool_run(args, **kwargs)
        with self.assertRaises(phase.PreflightError) as caught:
            phase.run_preflight(self.spec, self.root, run=fail, now=self.now)
        self.assertEqual(str(caught.exception), 'delivery-unavailable')

    def test_android_calls_existing_guard_without_install(self):
        self.add_device()
        self.observation['deviceId'] = 'emulator-5554'
        self.write_observation()
        self.spec['device']['id'] = 'emulator-5554'
        self.spec['platform'] = 'android'
        self.spec['targetId'] = 'emulator-5554'
        self.spec['android'] = {'apk': str(self.fixture / 'input.json'), 'sha256': self.spec['fixture']['sha256'],
                                'package': 'com.eros.dakhlrestaurant.phase02.verify.abcdefgh',
                                'signer_sha256': 'd' * 64, 'serial': 'emulator-5554', 'avd_name': 'Owned_AVD',
                                'mode': 'new-fixture', 'fixture_id': 'e' * 16,
                                'source_revision': 'a' * 40, 'runtime_revision': 'b' * 40, 'fixture_only': True}
        def reject(config, **kwargs):
            self.assertFalse(config.execute)
            raise phase.android_guard.GuardError('signer-mismatch')
        with mock.patch.object(phase.android_guard, 'guard_install', reject):
            self.assert_refuses('android-signer-mismatch')
        self.assertFalse(any('install' in x for x in self.commands))

    def test_android_source_context_mismatch_refuses_before_guard(self):
        self.add_device()
        self.spec['platform'] = 'android'
        self.spec['targetId'] = 'device1'
        self.spec['android'] = {'source_revision': 'c' * 40}
        with mock.patch.object(phase.android_guard, 'guard_install') as guard:
            self.assert_refuses('android-context-mismatch')
            guard.assert_not_called()

    def test_mobile_requires_device_observation(self):
        for platform in ['ios', 'android']:
            with self.subTest(platform=platform):
                self.spec['platform'] = platform
                self.assert_refuses('device-evidence-required')

    def test_android_requires_guard_even_with_ready_device(self):
        self.add_device()
        self.spec['platform'] = 'android'
        self.assert_refuses('android-guard-required')

    def test_device_evidence_cannot_escape_marked_fixture(self):
        self.add_device()
        other = self.root / 'private-data'
        other.write_text('not synthetic evidence')
        self.observation['evidence'] = [{'path': str(other), 'sha256': self.hash(other)}]
        self.write_observation()
        self.assert_refuses('unsafe-file')

    def test_atomic_receipt_refuses_existing_destination(self):
        p = self.fixture / 'receipt.json'
        phase.write_receipt(p, {'status': 'first'})
        with self.assertRaises(phase.PreflightError):
            phase.write_receipt(p, {'status': 'second'})
        self.assertEqual(json.loads(p.read_text()), {'status': 'first'})

    def test_fixture_identity_must_match_bytes(self):
        self.spec['fixtureId'] = 'f' * 64
        self.assert_refuses('fixture-identity-mismatch')

    def test_mobile_target_must_match_device(self):
        self.add_device()
        self.spec['platform'] = 'ios'
        self.assert_refuses('device-context-mismatch')

    def test_duplicate_json_keys_refuse(self):
        with self.assertRaises(phase.PreflightError) as caught:
            phase._json(b'{"schema":1,"schema":1}')
        self.assertEqual(caught.exception.code, 'invalid-json')

    def test_cli_invalid_arguments_do_not_echo_secrets(self):
        out = io.StringIO()
        with mock.patch('sys.stdout', out):
            code = phase.main(['--unknown', 'TOKEN=secret'])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out.getvalue()), {'status': 'refused', 'code': 'invalid-arguments'})

    def test_malformed_mobile_context_is_safe_refusal(self):
        self.spec['platform'] = 'ios'
        self.spec['device'] = 'bad'
        self.assert_refuses('device-context-mismatch')

    def test_cli_invalid_json_has_fixed_error(self):
        path = self.fixture / 'bad.json'
        path.write_text('TOKEN=secret')
        out = io.StringIO()
        with mock.patch('sys.stdout', out):
            code = phase.main(['--spec', str(path), '--root', str(self.root), '--output', str(self.fixture / 'result.json')])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out.getvalue()), {'status': 'refused', 'code': 'invalid-json'})
        self.assertNotIn('secret', out.getvalue())


if __name__ == '__main__':
    unittest.main()
