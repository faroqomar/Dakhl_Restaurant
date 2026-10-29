import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).parents[1] / 'run_benchmarks.py'
spec = importlib.util.spec_from_file_location('app_benchmark_runner', MODULE)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class AppRunnerTests(unittest.TestCase):
    def engine_fixture(self, directory):
        root = Path(directory) / 'app'
        engine = Path(directory) / 'Madar_Engine'
        root.mkdir()
        package = engine / 'packages/application'
        (package / 'lib').mkdir(parents=True)
        (package / 'pubspec.yaml').write_text('name: madar_application\nversion: 1.0.0\n')
        (package / 'lib/application.dart').write_text('const engineVersion = 1;')
        pin = dict(git_commit='a' * 40, packages=dict(madar_application=dict(
            path='../Madar_Engine/packages/application', version='1.0.0')))
        (root / 'engine-dependency.json').write_text(json.dumps(pin))
        (root / '.dart_tool').mkdir()
        (root / '.dart_tool/package_config.json').write_text(json.dumps(dict(configVersion=2,
            packages=[dict(name='madar_application', rootUri=package.resolve().as_uri(), packageUri='lib/')])) )
        return root, engine, pin

    def test_major_future_features_cannot_masquerade_as_measured(self):
        registry = json.loads(runner.REGISTRY.read_text())
        entries = {value['id']: value for value in registry['operations']}
        self.assertEqual(len(entries), len(registry['operations']))
        for case in ('orders.process', 'catalog.add_item', 'sales.add_item'):
            self.assertEqual(entries[case]['status'], 'planned')
            self.assertIn('not implemented', entries[case]['reason'])
        self.assertEqual({key for key, value in entries.items() if value['status'] == 'ready'}, {'app.startup', 'navigation.switch_route', 'shortcuts.save'})

    def test_profile_cache_invalidates_source_sdk_and_missing_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / 'app'
            executable.write_text('fixture')
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'EXECUTABLE', executable), patch.object(runner, 'runtime_engine_identity', return_value=dict(gitCommit='a' * 40)), patch.object(runner, 'command') as build:
                runner.build_profile('source-a', {'version': '1'})
                runner.build_profile('source-a', {'version': '1'})
                self.assertEqual(build.call_count, 1)
                runner.build_profile('source-b', {'version': '1'})
                runner.build_profile('source-b', {'version': '2'})
                executable.write_text('a different entrypoint')
                runner.build_profile('source-b', {'version': '2'})
                executable.unlink()
                runner.build_profile('source-b', {'version': '2'})
                self.assertEqual(build.call_count, 5)
                for call in build.call_args_list:
                    self.assertIn('--profile', call.args[0])

    def test_source_fingerprint_tracks_lock_assets_and_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('lib', 'assets', 'macos/Flutter/ephemeral'):
                (root / name).mkdir(parents=True)
            for name in ('lib/main.dart', 'assets/font.ttf', 'pubspec.yaml', 'pubspec.lock'):
                (root / name).write_text('fixture')
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'runtime_engine_identity', return_value=dict(gitCommit='a' * 40)):
                before = runner.source_fingerprint()
                (root / 'macos/Flutter/ephemeral/generated').write_text('temporary')
                self.assertEqual(runner.source_fingerprint(), before)
                (root / 'pubspec.lock').write_text('changed')
                self.assertNotEqual(runner.source_fingerprint(), before)

    def test_reviewed_runtime_engine_upgrade_invalidates_cached_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            root, engine, pin = self.engine_fixture(directory)
            for name in ('lib', 'assets', 'macos'):
                (root / name).mkdir()
            for name in ('pubspec.yaml', 'pubspec.lock'):
                (root / name).write_text('fixture')
            executable = root / 'app-binary'
            executable.write_text('fixture')
            head = ['a' * 40]
            builds = []
            def command(argv, cwd=None):
                if argv[:3] == ['git', 'rev-parse', 'HEAD']:
                    self.assertEqual(cwd, engine.resolve())
                    return head[0] + '\n'
                if argv[:2] == ['git', 'status']:
                    return ''
                if argv[:2] == ['git', 'ls-files']:
                    return 'packages/application/lib/application.dart\0packages/application/pubspec.yaml\0'
                if argv[:3] == ['flutter', 'build', 'macos']:
                    builds.append(argv)
                    return ''
                self.fail('Unexpected command')
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'EXECUTABLE', executable), patch.object(runner, 'command', side_effect=command):
                old_identity = runner.runtime_engine_identity()
                old_fingerprint = runner.source_fingerprint()
                runner.build_profile(old_fingerprint, {'version': 'sdk'}, old_identity)
                runner.build_profile(old_fingerprint, {'version': 'sdk'}, old_identity)
                self.assertEqual(len(builds), 1)
                # The app and SDK remain identical while its approved path
                # dependency moves to a new reviewed commit/source version.
                head[0] = 'b' * 40
                pin['git_commit'] = head[0]
                (root / 'engine-dependency.json').write_text(json.dumps(pin))
                (engine / 'packages/application/lib/application.dart').write_text('const engineVersion = 2;')
                new_identity = runner.runtime_engine_identity()
                self.assertNotEqual(new_identity['sourceFingerprint'], old_identity['sourceFingerprint'])
                self.assertNotEqual(runner.source_fingerprint(), old_fingerprint)
                runner.build_profile(runner.source_fingerprint(), {'version': 'sdk'}, new_identity)
                self.assertEqual(len(builds), 2)
                cache = json.loads((root / 'build/dev_dashboard/profile-cache.json').read_text())
                self.assertEqual(cache['key']['runtimeEngineIdentity'], new_identity)
                self.assertEqual(new_identity['gitCommit'], head[0])
                # Manifest metadata alone also belongs to the build identity.
                before = runner.source_fingerprint()
                pin['status'] = 'review metadata updated'
                (root / 'engine-dependency.json').write_text(json.dumps(pin))
                self.assertNotEqual(runner.source_fingerprint(), before)

    def test_runtime_engine_identity_rejects_head_mismatch_and_dirty_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root, _, _ = self.engine_fixture(directory)
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'command', return_value='b' * 40):
                with self.assertRaisesRegex(RuntimeError, 'engine_revision_mismatch'):
                    runner.runtime_engine_identity()
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'command', side_effect=['a' * 40, ' M packages/application/lib/application.dart']):
                with self.assertRaisesRegex(RuntimeError, 'engine_source_dirty'):
                    runner.runtime_engine_identity()

    def test_runtime_engine_identity_rejects_redirected_package_resolution(self):
        with tempfile.TemporaryDirectory() as directory:
            root, _, _ = self.engine_fixture(directory)
            config_file = root / '.dart_tool/package_config.json'
            config = json.loads(config_file.read_text())
            config['packages'][0]['packageUri'] = 'different-lib/'
            config_file.write_text(json.dumps(config))
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'command', side_effect=['a' * 40, '']):
                with self.assertRaisesRegex(RuntimeError, 'engine_resolution_mismatch'):
                    runner.runtime_engine_identity()


if __name__ == '__main__':
    unittest.main()
