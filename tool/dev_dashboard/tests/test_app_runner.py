import importlib.util
import hashlib
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

    def _empty_icu_framework(self, root):
        framework = root / 'build/macos/Build/Products/Profile/native_assets/madar_icu_collation.framework'
        (framework / 'Versions/A/Resources').mkdir(parents=True)
        (framework / 'Versions/Current').symlink_to('A')
        (framework / 'Resources').symlink_to('Versions/Current/Resources')
        return framework

    def test_profile_build_retries_once_only_after_classified_empty_shell_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = root / 'app'
            executable.write_bytes(b'fixture')
            attempts = []
            def build(argv, cwd=None):
                attempts.append(argv)
                if len(attempts) == 1:
                    self._empty_icu_framework(root)
                    raise runner.EmptyProfileFrameworkError('command_failed:flutter')
                self.assertFalse((root / 'build/macos/Build/Products/Profile/native_assets/madar_icu_collation.framework').exists())
                return ''
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'EXECUTABLE', executable), patch.object(runner, 'command', side_effect=build):
                runner.build_profile('fixture', {}, engine_identity={'gitCommit': 'a' * 40})
            self.assertEqual(len(attempts), 2)

    def test_profile_build_does_not_retry_unrelated_failure_with_empty_shell(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            executable = root / 'app'
            executable.write_bytes(b'fixture')
            def build(argv, cwd=None):
                self._empty_icu_framework(root)
                raise RuntimeError('command_failed:flutter')
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'EXECUTABLE', executable), patch.object(runner, 'command', side_effect=build) as command:
                with self.assertRaisesRegex(RuntimeError, 'command_failed:flutter'):
                    runner.build_profile('fixture', {}, engine_identity={'gitCommit': 'a' * 40})
                self.assertEqual(command.call_count, 1)

    def test_profile_switch_removes_only_known_empty_framework_shell(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            framework = self._empty_icu_framework(root)
            with patch.object(runner, 'ROOT', root):
                runner.discard_empty_profile_icu_frameworks()
            self.assertFalse(framework.exists())

    def test_profile_switch_preserves_framework_with_any_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            framework = self._empty_icu_framework(root)
            payload = framework / 'Versions/A/madar_icu_collation'
            payload.write_bytes(b'unique payload')
            with patch.object(runner, 'ROOT', root):
                runner.discard_empty_profile_icu_frameworks()
            self.assertEqual(payload.read_bytes(), b'unique payload')

    def test_profile_switch_refuses_redirected_empty_framework(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            framework = self._empty_icu_framework(root)
            (framework / 'Resources').unlink()
            (framework / 'Resources').symlink_to('/tmp')
            with patch.object(runner, 'ROOT', root), self.assertRaisesRegex(RuntimeError, 'framework_redirected'):
                runner.discard_empty_profile_icu_frameworks()
            self.assertTrue(framework.exists())

    def test_reused_output_refreshes_failed_diagnostics_to_empty_on_success(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory).resolve() / 'latest.json'
            failure = dict(operationId='accounts.open', runId='a' * 32, captureStatus='captured')
            old_receipt = Path(directory).resolve() / 'old.capture.json'
            old_receipt.write_text('retained immutable failure evidence')
            runner.publish_results(output, {'status': 'failed'}, [failure])
            runner.publish_results(output, {'status': 'passed'}, [])
            index = json.loads(output.with_name('latest.json.diagnostics.json').read_text())
            self.assertEqual(index['failedMeasurements'], [])
            self.assertEqual(index['resultSha256'], hashlib.sha256(output.read_bytes()).hexdigest())
            self.assertEqual(json.loads(output.read_text()), {'status': 'passed'})
            self.assertEqual(old_receipt.read_text(), 'retained immutable failure evidence')

    def test_reused_output_failure_index_contains_only_new_attempt(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory).resolve() / 'latest.json'
            old = dict(runId='a' * 32, captureStatus='captured')
            new = dict(runId='b' * 32, captureStatus='missing')
            result = {'status': 'failed', 'diagnostics': ['child_reported_error']}
            runner.publish_results(output, result, [old])
            runner.publish_results(output, result, [new])
            index = json.loads(output.with_name('latest.json.diagnostics.json').read_text())
            self.assertEqual(index['failedMeasurements'], [new])
            self.assertEqual(result, {'status': 'failed', 'diagnostics': ['child_reported_error']})

    def test_symlink_diagnostic_index_preserves_existing_output_and_foreign_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            output = root / 'latest.json'; output.write_text('previous result')
            foreign = root / 'unrelated.json'; foreign.write_text('preserve')
            (root / 'latest.json.diagnostics.json').symlink_to(foreign)
            with self.assertRaises(RuntimeError):
                runner.publish_results(output, {'status': 'passed'}, [])
            self.assertEqual(output.read_text(), 'previous result')
            self.assertEqual(foreign.read_text(), 'preserve')

    def test_index_publication_error_does_not_replace_old_result_or_leave_temporaries(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory).resolve() / 'latest.json'; output.write_text('previous result')
            with patch.object(runner.os, 'replace', side_effect=OSError('fixture failure')):
                with self.assertRaises(RuntimeError):
                    runner.publish_results(output, {'status': 'passed'}, [])
            self.assertEqual(output.read_text(), 'previous result')
            self.assertEqual([p.name for p in output.parent.iterdir()], ['latest.json'])

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

    def test_completion_routes_and_fingerprints_nonvisual_fixture(self):
        entry = {'phase': 'Completion', 'harness': 'completion-nonvisual'}
        self.assertEqual(runner.operation_target(entry), 'lib/platform/completion_performance_main.dart')
        self.assertEqual(runner.operation_fixture_source(entry), 'lib/platform/completion_performance_scenarios.dart')
        self.assertEqual(runner.operation_fixture_source({'phase': '02'}), 'lib/platform/phase02_performance_scenarios.dart')
        self.assertEqual(runner.operation_fixture_source({'phase': '01'}), 'lib/platform/performance_scenarios.dart')

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

    def test_major_visible_features_require_actual_surface_harness(self):
        registry = json.loads(runner.REGISTRY.read_text())
        entries = {value['id']: value for value in registry['operations']}
        self.assertEqual(len(entries), len(registry['operations']))
        for case in ('orders.process', 'catalog.add_item', 'sales.add_item', 'visible.suppliers.ledger'):
            self.assertEqual(entries[case]['status'], 'ready')
            self.assertEqual(entries[case]['harness'], 'visible-operations')
            self.assertEqual(entries[case]['fixtureProfile'], 'visible-operations-v1')
            self.assertIn('800x600', entries[case]['scope'])
            self.assertIn('native raster', entries[case]['scope'])
            self.assertIn('not a performance result', entries[case]['verification'])
        self.assertEqual({key for key, value in entries.items() if value['status'] == 'ready'}, {'c1.product.edit', 'review.register.remaining', 'review.suppliers.ledger_query', 'c1.stock.post', 'review.spending.expense', 'review.reports.invoice.short', 'workspace.save_restore', 'app.startup', 'c1.stock.reverse', 'workspace.hold', 'review.reports.sale.short', 'review.reports.cash.multi', 'workspace.resume', 'review.reports.payment.short', 'review.reports.statement.multi', 'review.days.shift', 'review.reports.sales.multi', 'parties.save_material', 'review.portable.recover', 'review.reports.generate', 'review.reports.cash.short', 'shortcuts.save', 'c1.catalog.lookup', 'c1.product.create', 'accounts.migrate_legacy', 'review.portable.export', 'review.cash.transfer', 'review.purchases.payment', 'accounts.open', 'accounts.recover_previous', 'inventory.post_movement', 'review.reports.sale.multi', 'review.purchases.invoice', 'review.reports.sales.short', 'accounts.save', 'review.sales.checkout', 'review.reports.daily.multi', 'parties.save_supplier', 'review.reports.statement.short', 'review.sales.void', 'review.reports.daily.short', 'review.undo.expense', 'navigation.switch_route', 'review.reports.payment.max', 'review.portable.import', 'catalog.lookup', 'c1.catalog.filter', 'review.purchases.analysis', 'review.sales.refund', 'review.reports.invoice.multi', 'review.spending.correct', 'accounts.replace', 'c1.stock.history', 'c1.catalog.page', 'review.purchases.invoice_inline', 'c1.product.photo_select_save', 'settings.save', 'review.suppliers.additional_debt', 'review.cash.external_deposit', 'review.categories.save'} | {'orders.process', 'catalog.add_item', 'sales.add_item', 'visible.suppliers.ledger', 'review.suppliers.opening_write'})

    def test_completion_registry_describes_command_scope_without_ui_claims(self):
        entries = json.loads(runner.REGISTRY.read_text())['operations']
        cases = [entry for entry in entries if entry.get('harness') == 'completion-nonvisual']
        self.assertEqual(len(cases), 7)
        for entry in cases:
            self.assertEqual(entry['measurementKind'], 'workflow')
            self.assertEqual(entry['fixtureProfile'], 'completion-v1')
            self.assertIn('No UI', entry['scope'])
            self.assertIn('not a performance result', entry['verification'])
            self.assertEqual(entry['status'], 'ready')

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


class Phase02FailureDiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.case, self.profile, self.run = 'accounts.migrate_legacy', 'medium', 'a' * 32
        self.manifest = self.root / (self.case + '-' + self.profile + '-' + self.run + '.json')
        self.manifest.write_text('preserve original manifest')
        self.sidecar = self.manifest.with_name(self.manifest.name + '.failure.json')
        self.evidence = self.root / 'evidence'
        self.measurement = dict(status='failed', iterations=0, samplesMs=[], timing=None,
                                resources=None, diagnostics=['child_reported_error'])

    def context(self):
        return dict(schemaVersion=1, operationId=self.case, profile=self.profile,
                    runId=self.run, requestedIterations=20, attemptedIteration=3,
                    completedSampleCount=2, stage='finalRender', errorKind='timeout',
                    state='saved', failureCode=None)

    def capture(self):
        before = json.dumps(self.measurement, sort_keys=True)
        receipt = runner.capture_phase02_failure(self.measurement, self.manifest, self.case,
                                                  self.profile, self.run, 20, self.evidence)
        self.assertEqual(json.dumps(self.measurement, sort_keys=True), before)
        self.assertEqual(self.manifest.read_text(), 'preserve original manifest')
        return receipt

    def test_missing_context_is_reported_without_masking_failed_result(self):
        result = self.capture()
        self.assertEqual(result['status'], 'missing')
        self.assertEqual(self.measurement['diagnostics'], ['child_reported_error'])

    def test_valid_context_captured_separately_from_generic_measurement(self):
        self.sidecar.write_text(json.dumps(self.context()))
        result = self.capture()
        self.assertEqual(result['status'], 'captured')
        self.assertEqual(result['context'], self.context())
        self.assertEqual((self.evidence / self.sidecar.name).read_bytes(), self.sidecar.read_bytes())
        self.assertNotIn('context', self.measurement)

    def test_private_extra_invalid_bounds_and_unknown_values_are_rejected(self):
        mutations = [dict(self.context(), privatePayload='secret?auth=token'),
                     dict(self.context(), attemptedIteration=True),
                     dict(self.context(), attemptedIteration=21),
                     dict(self.context(), completedSampleCount=4),
                     dict(self.context(), completedSampleCount=0),
                     dict(self.context(), requestedIterations=19),
                     dict(self.context(), stage='/private/secret'),
                     dict(self.context(), errorKind='raw exception'),
                     dict(self.context(), state='secret'),
                     dict(self.context(), failureCode='secret')]
        for index, context in enumerate(mutations):
            with self.subTest(index=index):
                self.evidence = self.root / ('evidence-' + str(index))
                self.sidecar.write_text(json.dumps(context))
                result = self.capture()
                self.assertEqual(result['status'], 'rejected')
                self.assertNotIn('secret', json.dumps(result))
                self.assertFalse((self.evidence / self.sidecar.name).exists())

    def test_foreign_case_profile_run_and_filename_are_rejected(self):
        for index, fields in enumerate([dict(operationId='accounts.open'), dict(profile='small'),
                                        dict(runId='b' * 32)]):
            self.evidence = self.root / ('foreign-' + str(index))
            self.sidecar.write_text(json.dumps(dict(self.context(), **fields)))
            self.assertEqual(self.capture()['status'], 'rejected')
        self.manifest = self.root / ('accounts.open-medium-' + self.run + '.json')
        self.manifest.write_text('preserve original manifest')
        self.sidecar = self.manifest.with_name(self.manifest.name + '.failure.json')
        self.sidecar.write_text(json.dumps(self.context()))
        self.evidence = self.root / 'foreign-file'
        self.assertEqual(self.capture()['status'], 'rejected')

    def test_source_symlink_and_oversized_context_are_rejected(self):
        original = self.root / 'private.json'
        original.write_text(json.dumps(self.context()))
        self.sidecar.symlink_to(original)
        self.assertEqual(self.capture()['status'], 'rejected')
        self.assertEqual(json.loads(original.read_text()), self.context())
        self.sidecar.unlink()
        self.sidecar.write_bytes(b'x' * 4097)
        self.evidence = self.root / 'oversized'
        self.assertEqual(self.capture()['status'], 'rejected')

    def test_redirected_evidence_and_existing_artifacts_are_preserved(self):
        self.sidecar.write_text(json.dumps(self.context()))
        original = self.root / 'preserved'
        original.mkdir()
        marker = original / 'keep'; marker.write_text('keep')
        self.evidence.symlink_to(original, target_is_directory=True)
        self.assertEqual(self.capture()['status'], 'unavailable')
        self.assertEqual(marker.read_text(), 'keep')
        self.evidence.unlink(); self.evidence.mkdir()
        (self.evidence / self.sidecar.name).write_text('keep existing diagnostic')
        self.assertEqual(self.capture()['status'], 'rejected')
        self.assertEqual((self.evidence / self.sidecar.name).read_text(), 'keep existing diagnostic')
        capture_path = self.evidence / (self.manifest.name + '.capture.json')
        before = capture_path.read_bytes()
        self.assertEqual(self.capture()['status'], 'unavailable')
        self.assertEqual(capture_path.read_bytes(), before)

    def test_duplicate_keys_cannot_hide_private_raw_text_in_copied_artifact(self):
        raw = json.dumps(self.context()).replace('"failureCode": null',
              '"failureCode": "secret?auth=token", "failureCode": null')
        self.sidecar.write_text(raw)
        result = self.capture()
        self.assertEqual(result['status'], 'rejected')
        self.assertNotIn('secret', json.dumps(result))
        self.assertFalse((self.evidence / self.sidecar.name).exists())

    def test_successful_measurement_does_not_collect_failure_context(self):
        self.measurement['status'] = 'passed'
        self.assertIsNone(self.capture())
        self.assertFalse(self.evidence.exists())

if __name__ == '__main__':
    unittest.main()
