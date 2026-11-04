"""Consumer source/pin conformance, without native input or installation."""
import hashlib
import io
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

MODULE = Path(__file__).resolve().parents[1] / 'phase_workflow.py'


class ConsumerWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        binaries = Path(self.tmp.name) / 'bin'
        binaries.mkdir()
        (binaries / 'git').symlink_to(shutil.which('git', path=os.defpath))
        environment = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
        environment.update(PATH=str(binaries) + os.pathsep + os.environ['PATH'],
                           GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                           GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='core.hooksPath',
                           GIT_CONFIG_VALUE_0=os.devnull)
        patch = mock.patch.dict(os.environ, environment, clear=True)
        patch.start()
        self.addCleanup(patch.stop)
        self.root = Path(self.tmp.name) / 'consumer'
        self.tools = Path(self.tmp.name) / 'engine'
        for root in (self.root, self.tools):
            root.mkdir()
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
        self.write('engine-dependency.json', json.dumps({'git_commit': 'a' * 40}))
        self.write('lib/app.dart', 'preserved runtime')
        self.write('integration_test/support/native_picker_wait.dart', 'fixed timer')
        self.write('integration_test/support/native_app_readiness.dart', 'fixed readiness')
        self.write('scripts/android_install_guard.py', 'guard')
        self.write('scripts/phase_preflight.py', 'preflight')
        self.write('scripts/phase_workflow.py', MODULE.read_text())
        self.commit(self.root)
        source = self.tools / 'tool/dev_workflow/workflow.py'
        source.parent.mkdir(parents=True)
        source.write_text('API_VERSION = 1\ndef validate_plan(plan):\n    return None\n')
        revision = self.commit(self.tools)
        self.write('dev-tooling-dependency.json', json.dumps({
            'git_commit': revision,
            'workflow_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        }))
        self.spec = {'campaignId': 'save-proof', 'targetId': 'host-test',
                     'fixtureId': 'synthetic-01', 'stages': [
                         {'id': 'preflight', 'kind': 'preflight'},
                         {'id': 'save-pilot', 'kind': 'pilot'},
                         {'id': 'save-matrix', 'kind': 'case'}]}
        module_spec = importlib.util.spec_from_file_location('phase_workflow', MODULE)
        output_patch = mock.patch('sys.stdout', new_callable=io.StringIO)
        self.captured_output = output_patch.start()
        self.addCleanup(output_patch.stop)
        self.module = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(self.module)

    def write(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    @staticmethod
    def commit(root):
        subprocess.run(['git', '-C', str(root), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(root), '-c', 'user.name=Fixture', '-c',
                        'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True)
        return subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()

    def test_prepare_binds_runtime_tool_target_and_tracked_sources(self):
        plan = self.module.prepare_plan(self.root, self.tools, self.spec)
        self.assertEqual(plan['consumerId'], 'Dakhl_Restaurant')
        self.assertEqual(plan['engineRevision'], 'a' * 40)
        self.assertEqual(plan['targetId'], 'host-test')
        self.assertIn('lib/app.dart', plan['inputs'])
        self.assertIn('scripts/android_install_guard.py', plan['inputs'])
        self.assertIn('integration_test/support/native_picker_wait.dart', plan['inputs'])

    def test_dirty_runtime_bytes_change_fingerprint(self):
        before = self.module.prepare_plan(self.root, self.tools, self.spec)
        self.write('lib/app.dart', 'changed runtime')
        after = self.module.prepare_plan(self.root, self.tools, self.spec)
        self.assertNotEqual(before['inputs'], after['inputs'])

    def test_untracked_runtime_is_also_bound(self):
        self.write('lib/new.dart', 'new source')
        plan = self.module.prepare_plan(self.root, self.tools, self.spec)
        self.assertIn('lib/new.dart', plan['inputs'])

    def test_tampered_engine_tool_refused(self):
        (self.tools / 'tool/dev_workflow/workflow.py').write_text('raise RuntimeError("private")')
        with self.assertRaisesRegex(self.module.WorkflowError, 'tool-source-mismatch'):
            self.module.prepare_plan(self.root, self.tools, self.spec)

    def test_uncommitted_tool_cannot_fake_reviewed_commit(self):
        source = self.tools / 'tool/dev_workflow/workflow.py'
        source.write_text('def validate_plan(plan):\n    return True\n')
        pin = json.loads((self.root / 'dev-tooling-dependency.json').read_text())
        pin['workflow_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
        self.write('dev-tooling-dependency.json', json.dumps(pin))
        with self.assertRaisesRegex(self.module.WorkflowError, 'tool-source-mismatch'):
            self.module.prepare_plan(self.root, self.tools, self.spec)

    def test_ignored_generated_files_do_not_invalidate_source(self):
        self.write('.gitignore', 'android/.gradle/\n')
        before = self.module.prepare_plan(self.root, self.tools, self.spec)
        self.write('android/.gradle/temporary.properties', 'generated')
        after = self.module.prepare_plan(self.root, self.tools, self.spec)
        self.assertEqual(before['inputs'], after['inputs'])

    def test_interrupted_exclusive_write_leaves_no_partial_artifact(self):
        target = self.root / 'outputs' / 'interrupted.json'
        with mock.patch.object(self.module.os, 'fsync', side_effect=OSError('disk unavailable')):
            with self.assertRaises(OSError):
                self.module.write_json(target, {'synthetic': True}, exclusive=True)
        self.assertFalse(target.exists())
        self.assertEqual(list(target.parent.iterdir()), [])

    def test_source_symlink_refused(self):
        target = self.root / 'lib/app.dart'
        target.unlink()
        target.symlink_to(self.root / 'engine-dependency.json')
        with self.assertRaisesRegex(self.module.WorkflowError, 'unsafe-input'):
            self.module.prepare_plan(self.root, self.tools, self.spec)

    def test_missing_required_safeguard_refused(self):
        (self.root / 'scripts/android_install_guard.py').unlink()
        with self.assertRaisesRegex(self.module.WorkflowError, 'missing-required-input'):
            self.module.prepare_plan(self.root, self.tools, self.spec)

    def test_resume_rejects_source_revision_and_runtime_changes(self):
        plan = self.module.prepare_plan(self.root, self.tools, self.spec)
        changed = dict(plan, sourceRevision='f' * 40)
        with self.assertRaisesRegex(self.module.WorkflowError, 'consumer-context-mismatch'):
            self.module.validate_consumer_plan(self.root, self.tools, changed)
        self.write('engine-dependency.json', json.dumps({'git_commit': 'b' * 40}))
        with self.assertRaisesRegex(self.module.WorkflowError, 'consumer-context-mismatch'):
            self.module.validate_consumer_plan(self.root, self.tools, plan)


    def install_real_tools(self):
        original = Path(os.environ.get('MADAR_WORKFLOW_TOOLS_ROOT',
                            str(MODULE.parents[1].parent / 'Madar_Engine')))
        source = self.tools / 'tool/dev_workflow/workflow.py'
        source.write_bytes((original / 'tool/dev_workflow/workflow.py').read_bytes())
        revision = self.commit(self.tools)
        self.write('dev-tooling-dependency.json', json.dumps({
            'git_commit': revision,
            'workflow_sha256': hashlib.sha256(source.read_bytes()).hexdigest()}))
        return self.module.load_tools(self.root, self.tools)[0]

    def receipt(self, state, stage, status='passed', cleanup=True):
        artifact = self.root / 'outputs' / (stage + '-' + status + '.json')
        artifact.parent.mkdir(exist_ok=True)
        artifact.write_text(json.dumps({'stage': stage, 'synthetic': True, 'status': status}))
        return {'stageId': stage, 'status': status, 'cleanupConfirmed': cleanup,
                'identity': state['identity'], 'evidence': [{
                    'path': artifact.relative_to(self.root).as_posix(),
                    'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest()}]}

    def test_real_engine_pilot_gate_and_exact_resume(self):
        engine = self.install_real_tools()
        plan = self.module.prepare_plan(self.root, self.tools, self.spec)
        state = engine.create_campaign(plan, self.root)
        with self.assertRaisesRegex(engine.WorkflowError, 'stage-order'):
            engine.record_attempt(state, plan, self.root, self.receipt(state, 'save-matrix'))
        state = engine.record_attempt(state, plan, self.root, self.receipt(state, 'preflight'))
        state = engine.record_attempt(state, plan, self.root, self.receipt(state, 'save-pilot'))
        self.assertEqual(engine.next_stage(state, plan, self.root)['id'], 'save-matrix')
        self.assertEqual(engine.summarize(state, plan, self.root)['passedStages'], 2)
        self.write('lib/app.dart', 'later source')
        with self.assertRaisesRegex(self.module.WorkflowError, 'consumer-context-mismatch'):
            self.module.validate_consumer_plan(self.root, self.tools, plan)

    def test_real_engine_failed_cleanup_and_target_change_refuse(self):
        engine = self.install_real_tools()
        plan = self.module.prepare_plan(self.root, self.tools, self.spec)
        state = engine.create_campaign(plan, self.root)
        state = engine.record_attempt(state, plan, self.root,
                                      self.receipt(state, 'preflight', cleanup=False))
        with self.assertRaisesRegex(engine.WorkflowError, 'stage-blocked'):
            engine.next_stage(state, plan, self.root)
        self.assertEqual(engine.summarize(state, plan, self.root)['failedAttempts'], ['attempt-1'])
        changed = dict(plan, targetId='different-device')
        with self.assertRaisesRegex(engine.WorkflowError, 'campaign-mismatch'):
            engine.summarize(state, changed, self.root)

    def test_actual_preflight_and_engine_cli_composition(self):
        # Exercise normal imports even when the outer runner disables pyc writes.
        bytecode = mock.patch('sys.dont_write_bytecode', False)
        bytecode.start()
        self.addCleanup(bytecode.stop)
        self.install_real_tools()
        for name in ('android_install_guard.py', 'phase_preflight.py'):
            (self.root / 'scripts' / name).write_bytes((MODULE.parent / name).read_bytes())
        fixture = Path(self.tmp.name) / 'synthetic'
        fixture.mkdir()
        (fixture / '.dakhl-synthetic-fixture').write_text('dakhl-phase-preflight-v1\n')
        payload = fixture / 'fixture.json'
        payload.write_text('{}')
        digest = hashlib.sha256(payload.read_bytes()).hexdigest()
        self.spec['fixtureId'] = digest
        self.spec['platform'] = 'host'
        self.write('outputs/campaign-spec.json', json.dumps(self.spec))
        plan_path, state_path = self.root / 'outputs/plan.json', self.root / 'outputs/state.json'
        common = ['--root', str(self.root), '--engine-tools-root', str(self.tools),
                  '--plan', str(plan_path), '--state', str(state_path)]
        self.assertEqual(self.module.main(['init', *common, '--spec',
                                          str(self.root / 'outputs/campaign-spec.json')]), 0)
        plan = json.loads(plan_path.read_text())
        spec = {'schema': 1, 'appRevision': plan['sourceRevision'],
                'runtimeRevision': plan['engineRevision'], 'platform': 'host',
                'targetId': plan['targetId'], 'fixtureId': digest,
                'inputs': {key: plan['inputs'][key] for key in ('lib/app.dart', 'engine-dependency.json')},
                'fixture': {'root': str(fixture), 'path': str(payload), 'sha256': digest}}
        self.write('outputs/preflight-spec.json', json.dumps(spec))
        args = ['preflight', *common, '--spec', str(self.root / 'outputs/preflight-spec.json'),
                '--evidence-output', str(self.root / 'outputs/preflight-proof.json')]
        marker = fixture / '.dakhl-synthetic-fixture'
        marker.unlink()
        self.assertEqual(self.module.main(args), 1, self.captured_output.getvalue())
        failed = json.loads(state_path.read_text())
        self.assertEqual(failed['attempts'][0]['receipt']['status'], 'failed')
        marker.write_text('dakhl-phase-preflight-v1\n')
        # Missing retry justification refuses before dispatch or a new artifact.
        retry_args = args[:-1] + [str(self.root / 'outputs/preflight-retry-proof.json')]
        self.assertEqual(self.module.main(retry_args), 2)
        self.assertFalse((self.root / 'outputs/preflight-retry-proof.json').exists())
        change = self.root / 'outputs/marker-restored.json'
        change.write_text('{"markerRestored":true}')
        retry = {'priorAttemptId': 'attempt-1', 'hypothesis': 'synthetic-marker-restored',
                 'changeEvidence': [{'path': 'outputs/marker-restored.json',
                                     'sha256': hashlib.sha256(change.read_bytes()).hexdigest()}]}
        self.write('outputs/retry.json', json.dumps(retry))
        self.assertEqual(self.module.main(retry_args + ['--retry', str(self.root / 'outputs/retry.json')]), 0)
        state = json.loads(state_path.read_text())
        self.assertEqual(len(state['attempts']), 2)
        self.assertEqual(state['attempts'][0], failed['attempts'][0])
        self.assertEqual(state['attempts'][1]['receipt']['status'], 'passed')
        self.assertEqual(self.module.main(['next', *common]), 0)
        # A direct preflight receipt cannot bypass the composed safeguard.
        self.write('outputs/direct.json', json.dumps(self.receipt(state, 'preflight')))
        self.assertEqual(self.module.main(['record', *common, '--receipt',
                                          str(self.root / 'outputs/direct.json')]), 2)


if __name__ == '__main__':
    unittest.main()
