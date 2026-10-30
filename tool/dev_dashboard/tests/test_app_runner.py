import importlib.util
import json
import plistlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).parents[1] / 'run_benchmarks.py'
spec = importlib.util.spec_from_file_location('app_benchmark_runner', MODULE)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class AppRunnerTests(unittest.TestCase):
    def setUp(self):
        toolchain = patch.object(runner, 'apple_toolchain_identity', return_value={'xcode': 'fixture', 'macosSdkBuild': 'fixture'}, create=True)
        toolchain.start()
        self.addCleanup(toolchain.stop)

    def test_phase02_manifest_uses_existing_sandbox_tmp_and_keeps_evidence_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = root / 'Fixture.app/Contents/MacOS/Fixture'
            executable.parent.mkdir(parents=True)
            executable.write_text('fixture')
            (executable.parent.parent / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.eros.dakhlrestaurant.phase00'}))
            temporary = root / 'home/Library/Containers/com.eros.dakhlrestaurant.phase00/Data/tmp'
            temporary.mkdir(parents=True)
            path = runner.phase02_manifest_path(executable, 'accounts.open', 'small', 'a' * 32, home_directory=root / 'home')
            self.assertTrue(path.is_relative_to(temporary.resolve()))
            self.assertNotEqual(path.parent, root / 'outputs')
            payload = json.dumps(dict(profile='small', synthetic=True, sourceSchema=11, legacySourceSchema=1, recordKind='cash transactions; no operating commands', recordCount=10, canonicalBytes=1234, legacyInputBytes=1200, replacementBytes=1250, notePattern='synthetic-{index}', accountLimitBytes=20*1024*1024, workspaceBytes=4096, heldDrafts=40, activeDrafts=1, largestMarginPolicyBytes=65536)).encode()
            path.write_bytes(payload)
            evidence = root / 'evidence'
            manifest, digest = runner.collect_phase02_manifest(path, 'small', evidence)
            self.assertEqual(manifest['canonicalBytes'], 1234)
            self.assertEqual((evidence / path.name).read_bytes(), payload)
            self.assertEqual(len(digest), 64)
            self.assertEqual(path.read_bytes(), payload)

    def test_phase02_invalid_or_oversize_manifest_never_creates_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            source = root / ('accounts.open-small-' + 'a' * 32 + '.json')
            evidence = root / 'evidence'
            source.write_text(json.dumps({'profile': 'medium', 'synthetic': True}))
            with self.assertRaisesRegex(RuntimeError, 'manifest_invalid'):
                runner.collect_phase02_manifest(source, 'small', evidence)
            self.assertFalse(evidence.exists())
            source.write_bytes(b' ' * (16 * 1024 + 1))
            with self.assertRaisesRegex(RuntimeError, 'manifest_too_large'):
                runner.collect_phase02_manifest(source, 'small', evidence)
            self.assertFalse(evidence.exists())

    def test_phase02_manifest_refuses_uninitialized_container_or_unsafe_bundle_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = root / 'Fixture.app/Contents/MacOS/Fixture'
            executable.parent.mkdir(parents=True)
            executable.write_text('fixture')
            info = executable.parent.parent / 'Info.plist'
            info.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.eros.dakhlrestaurant.phase00'}))
            with self.assertRaisesRegex(RuntimeError, 'sandbox_temp_unavailable'):
                runner.phase02_manifest_path(executable, 'accounts.open', 'small', 'a' * 32, home_directory=root / 'home')
            self.assertFalse((root / 'home').exists())
            info.write_bytes(plistlib.dumps({'CFBundleIdentifier': '../unrelated'}))
            with self.assertRaisesRegex(RuntimeError, 'bundle_identity_invalid'):
                runner.phase02_manifest_path(executable, 'accounts.open', 'small', 'a' * 32, home_directory=root / 'home')

    def test_phase02_routes_to_separate_entrypoint_and_cache_target(self):
        self.assertEqual(runner.operation_target({'phase': '02'}), 'lib/platform/phase02_performance_main.dart')
        self.assertEqual(runner.operation_target({'phase': '01'}), 'lib/platform/performance_main.dart')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = root / 'app'
            executable.write_text('fixture')
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'EXECUTABLE', executable), patch.object(runner, 'runtime_engine_identity', return_value={'gitCommit': 'a' * 40}), patch.object(runner, 'command') as build:
                runner.build_profile('same', {}, target='lib/platform/performance_main.dart')
                runner.build_profile('same', {}, target='lib/platform/phase02_performance_main.dart')
                self.assertEqual(build.call_count, 2)
                self.assertEqual(build.call_args[0][0][-1], 'lib/platform/phase02_performance_main.dart')

    def test_native_toolchain_upgrade_invalidates_identical_app_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = root / 'app'
            executable.write_text('fixture')
            toolchain = {'xcode': 'Xcode old\nBuild old', 'macosSdkBuild': 'sdk-old'}
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'EXECUTABLE', executable), patch.object(runner, 'runtime_engine_identity', return_value={'gitCommit': 'a' * 40}), patch.object(runner, 'apple_toolchain_identity', side_effect=lambda: dict(toolchain)), patch.object(runner, 'command') as build:
                runner.build_profile('same-source', {'flutter': 'same'})
                runner.build_profile('same-source', {'flutter': 'same'})
                self.assertEqual(build.call_count, 1)
                toolchain['xcode'] = 'Xcode new\nBuild new'
                runner.build_profile('same-source', {'flutter': 'same'})
                self.assertEqual(build.call_count, 2)
                toolchain['macosSdkBuild'] = 'sdk-new'
                runner.build_profile('same-source', {'flutter': 'same'})
                self.assertEqual(build.call_count, 3)
                key = json.loads((root / 'build/dev_dashboard/profile-cache.json').read_text())['key']
                self.assertEqual(key['appleToolchainIdentity'], toolchain)

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
        self.assertEqual({key for key, value in entries.items() if value['status'] == 'ready'}, {'app.startup', 'navigation.switch_route', 'shortcuts.save', 'accounts.open', 'accounts.save', 'accounts.migrate_legacy', 'accounts.replace', 'accounts.recover_previous', 'workspace.save_restore'})

    def test_profile_cache_invalidates_source_sdk_and_missing_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
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
            root = Path(directory).resolve()
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



class Phase02TransportGuardsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.bundle = 'com.eros.dakhlrestaurant.phase00'
        self.executable = self.root / 'Fixture.app/Contents/MacOS/Fixture'
        self.executable.parent.mkdir(parents=True)
        self.executable.write_text('fixture')
        self.info = self.executable.parent.parent / 'Info.plist'
        self.info.write_bytes(plistlib.dumps({'CFBundleIdentifier': self.bundle}))
        self.home = self.root / 'home'
        self.sandbox = self.home / 'Library/Containers' / self.bundle / 'Data/tmp'
        self.sandbox.mkdir(parents=True)
        self.source = self.root / ('accounts.open-small-' + 'a' * 32 + '.json')
        self.source.write_text(json.dumps(self.valid_manifest()))

    def valid_manifest(self):
        return dict(profile='small', synthetic=True, sourceSchema=11,
                    legacySourceSchema=1, recordKind='cash transactions; no operating commands',
                    recordCount=10, canonicalBytes=3456, legacyInputBytes=3400,
                    replacementBytes=3460, notePattern='synthetic-{index}',
                    accountLimitBytes=20 * 1024 * 1024, workspaceBytes=4096,
                    heldDrafts=40, activeDrafts=1, largestMarginPolicyBytes=65536)

    def test_unrelated_valid_bundle_is_rejected_without_touching_its_container(self):
        self.info.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.example.unrelated'}))
        foreign = self.home / 'Library/Containers/com.example.unrelated/Data/tmp'
        foreign.mkdir(parents=True)
        marker = foreign / 'preserve.txt'
        marker.write_text('keep')
        with self.assertRaises(RuntimeError):
            runner.phase02_manifest_path(self.executable, 'accounts.open', 'small', 'a' * 32, home_directory=self.home)
        self.assertEqual(marker.read_text(), 'keep')
        self.assertFalse((foreign / 'dakhl-phase02-benchmark-manifests').exists())

    def test_redirected_sandbox_tmp_is_rejected(self):
        moved = self.sandbox.with_name('preserved-tmp')
        self.sandbox.rename(moved)
        self.sandbox.symlink_to(moved, target_is_directory=True)
        with self.assertRaises(RuntimeError):
            runner.phase02_manifest_path(self.executable, 'accounts.open', 'small', 'a' * 32, home_directory=self.home)
        self.assertFalse((moved / 'dakhl-phase02-benchmark-manifests').exists())

    def test_redirected_sandbox_ancestor_is_rejected(self):
        library = self.home / 'Library'
        moved = self.home / 'preserved-library'
        library.rename(moved)
        library.symlink_to(moved, target_is_directory=True)
        with self.assertRaises(RuntimeError):
            runner.phase02_manifest_path(self.executable, 'accounts.open', 'small', 'a' * 32, home_directory=self.home)

    def test_source_symlink_is_rejected_without_creating_evidence(self):
        directory = self.root / 'alias'
        directory.mkdir()
        link = directory / self.source.name
        link.symlink_to(self.source)
        evidence = self.root / 'evidence'
        with self.assertRaises(RuntimeError):
            runner.collect_phase02_manifest(link, 'small', evidence)
        self.assertFalse(evidence.exists())

    def test_redirected_evidence_ancestor_is_rejected_without_writing(self):
        original = self.root / 'preserved-output'
        original.mkdir()
        marker = original / 'preserve.txt'
        marker.write_text('keep')
        link = self.root / 'output-link'
        link.symlink_to(original, target_is_directory=True)
        with self.assertRaises(RuntimeError):
            runner.collect_phase02_manifest(self.source, 'small', link / 'evidence')
        self.assertEqual(marker.read_text(), 'keep')
        self.assertFalse((original / 'evidence').exists())

    def test_missing_invalid_or_extra_payload_metadata_is_rejected(self):
        mutations = [
            {'profile': 'small', 'synthetic': True},
            dict(self.valid_manifest(), recordCount=True),
            dict(self.valid_manifest(), canonicalBytes=-1),
            dict(self.valid_manifest(), canonicalBytes=20 * 1024 * 1024 + 1),
            dict(self.valid_manifest(), heldDrafts=39),
            dict(self.valid_manifest(), accountPayload={'unrelated': 'do not collect'}),
        ]
        for index, manifest in enumerate(mutations):
            with self.subTest(index=index):
                self.source.write_text(json.dumps(manifest))
                evidence = self.root / ('evidence-' + str(index))
                with self.assertRaises(RuntimeError):
                    runner.collect_phase02_manifest(self.source, 'small', evidence)
                self.assertFalse(evidence.exists())

    def test_foreign_or_stale_attempt_filename_is_rejected(self):
        for name in ['foreign-small-' + 'a' * 32 + '.json',
                     'accounts.open-medium-' + 'a' * 32 + '.json',
                     'accounts.open-small-stale.json']:
            source = self.root / name
            source.write_text(json.dumps(self.valid_manifest()))
            with self.subTest(name=name), self.assertRaises(RuntimeError):
                runner.collect_phase02_manifest(source, 'small', self.root / name.replace('.json', '-evidence'))


if __name__ == '__main__':
    unittest.main()
