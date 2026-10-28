"""Exercise the consumer pin gate against isolated Git/package resolutions."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).resolve().parents[1] / 'check-engine.py'
PACKAGES = {'madar_application': 'application',
            'madar_flutter_adapters': 'flutter_adapters'}


class EnginePinCheckTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.addCleanup(self.cleanup_fixture)
        # Bypass user Git wrappers/hooks that can launch asynchronous writers
        # inside .git after a command finishes. Every child uses this same Git.
        system_git = shutil.which('git', path=os.defpath)
        self.assertIsNotNone(system_git, 'A system Git executable is required for fixture tests.')
        binaries = self.root / 'bin'
        binaries.mkdir()
        (binaries / 'git').symlink_to(system_git)
        self.environment = {key: value for key, value in os.environ.items()
                            if not key.startswith('GIT_')}
        self.environment.update(PATH=str(binaries) + os.pathsep + os.environ['PATH'],
                                GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                                GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='core.hooksPath',
                                GIT_CONFIG_VALUE_0=os.devnull)
        self.app = self.root / 'Dakhl_Restaurant'
        self.engine = self.root / 'Madar_Engine'
        (self.app / 'scripts').mkdir(parents=True)
        (self.app / '.dart_tool').mkdir()
        shutil.copyfile(CHECKER, self.app / 'scripts/check-engine.py')
        for name, directory in PACKAGES.items():
            package = self.engine / 'packages' / directory
            (package / 'lib').mkdir(parents=True)
            (package / 'pubspec.yaml').write_text(
                f'name: {name}\nversion: 0.1.0-dev.1\n')
            (package / 'lib/source.dart').write_text('// committed source\n')
        (self.engine / 'tool').mkdir()
        (self.engine / 'tool/verify_boundaries.dart').write_text('// fixture\n')
        self.git('init', '-q')
        self.git('config', 'core.fsmonitor', 'false')
        self.git('config', 'maintenance.auto', 'false')
        self.git('config', 'gc.auto', '0')
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-qm', 'fixture source')
        commit = self.git('rev-parse', 'HEAD').strip()
        self.pin = {'git_commit': commit, 'packages': {
            name: {'path': f'../Madar_Engine/packages/{directory}',
                   'version': '0.1.0-dev.1'}
            for name, directory in PACKAGES.items()}}
        self.write_pin()
        self.paths = {name: package['path'] for name, package in self.pin['packages'].items()}
        self.write_manifests()
        self.config = {'configVersion': 2, 'packages': [
            {'name': name, 'rootUri': '../' + path, 'packageUri': 'lib/'}
            for name, path in self.paths.items()]}
        self.write_config()
        dart = binaries / 'dart'
        dart.write_text('#!/bin/sh\nexit 0\n')
        dart.chmod(0o755)

    def cleanup_fixture(self):
        self.temporary.cleanup()
        self.assertFalse(self.root.exists(), 'Fixture cleanup must remove its entire tree.')

    def git(self, *arguments):
        return subprocess.check_output(['git', '-C', str(self.engine), *arguments],
                                       text=True, env=self.environment)

    def write_pin(self):
        (self.app / 'engine-dependency.json').write_text(json.dumps(self.pin))

    def write_config(self):
        (self.app / '.dart_tool/package_config.json').write_text(json.dumps(self.config))

    def write_manifests(self):
        (self.app / 'pubspec.yaml').write_text('name: dakhl_restaurant\ndependencies:\n' + ''.join(
            f'  {name}:\n    path: {path}\n' for name, path in self.paths.items()))
        (self.app / 'pubspec.lock').write_text('packages:\n' + ''.join(
            f'  {name}:\n    dependency: "direct main"\n    description:\n'
            f'      path: "{path}"\n      relative: true\n    source: path\n'
            '    version: "0.1.0-dev.1"\n' for name, path in self.paths.items()))

    def check(self):
        return subprocess.run([sys.executable, str(self.app / 'scripts/check-engine.py')],
                              text=True, capture_output=True, env=self.environment)

    def assert_rejected(self, message):
        result = self.check()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stderr)

    def test_current_canonical_resolution_passes(self):
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_symlink_to_same_committed_source_passes(self):
        (self.root / 'engine-link').symlink_to(self.engine, target_is_directory=True)
        self.paths = {name: f'../engine-link/packages/{directory}'
                      for name, directory in PACKAGES.items()}
        self.write_manifests()
        for package in self.config['packages']:
            package['rootUri'] = '../' + self.paths[package['name']]
        self.write_config()
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_redirected_resolved_package_is_rejected(self):
        redirected = self.root / 'unreviewed'
        shutil.copytree(self.engine / 'packages/application', redirected)
        self.config['packages'][0]['rootUri'] = redirected.as_uri()
        self.write_config()
        self.assert_rejected('madar_application')

    def test_missing_resolution_is_rejected(self):
        (self.app / '.dart_tool/package_config.json').unlink()
        self.assert_rejected('flutter pub get')

    def test_missing_resolved_package_is_rejected(self):
        self.config['packages'].pop()
        self.write_config()
        self.assert_rejected('Madar packages')

    def test_empty_package_pins_cannot_disable_source_check(self):
        self.pin['packages'] = {}
        self.write_pin()
        self.assert_rejected('explicit engine package pin')

    def test_development_dependency_cannot_hide_conflicting_source(self):
        with (self.app / 'pubspec.yaml').open('a') as manifest:
            manifest.write('dev_dependencies:\n  madar_application:\n    path: ../unreviewed\n')
        self.assert_rejected('madar_application')

    def test_duplicate_resolved_package_is_rejected(self):
        self.config['packages'].append(dict(self.config['packages'][0]))
        self.write_config()
        self.assert_rejected('madar_application')

    def test_changed_import_directory_is_rejected(self):
        self.config['packages'][0]['packageUri'] = '../../../unreviewed/'
        self.write_config()
        self.assert_rejected('packageUri')

    def test_remote_root_uri_is_rejected(self):
        self.config['packages'][0]['rootUri'] = 'https://example.invalid/application'
        self.write_config()
        self.assert_rejected('rootUri')

    def test_stale_pubspec_resolution_is_rejected(self):
        self.paths['madar_application'] = '../unreviewed'
        self.write_manifests()
        self.assert_rejected('madar_application')

    def test_stale_dependency_override_is_rejected(self):
        with (self.app / 'pubspec.yaml').open('a') as manifest:
            manifest.write('dependency_overrides:\n  madar_application:\n    path: ../unreviewed\n')
        self.assert_rejected('madar_application')

    def test_quoted_top_level_override_cannot_hide_redirect(self):
        for filename in ['pubspec.yaml', 'pubspec_overrides.yaml']:
            for key in ['"dependency_overrides"', "'dependency_overrides'"]:
                with self.subTest(filename=filename, key=key):
                    self.write_manifests()
                    with (self.app / filename).open('a') as manifest:
                        manifest.write(f'{key}:\n  madar_application:\n    path: ../unreviewed\n')
                    self.assert_rejected('madar_application')
                    (self.app / 'pubspec_overrides.yaml').unlink(missing_ok=True)

    def test_quoted_canonical_dependency_sections_pass(self):
        manifest = self.app / 'pubspec.yaml'
        manifest.write_text(manifest.read_text().replace('dependencies:', '"dependencies":') +
                            "'dependency_overrides':\n  madar_application:\n"
                            '    path: ../Madar_Engine/packages/application\n')
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unsupported_top_level_override_syntax_fails_closed(self):
        for content in ['? dependency_overrides\n:\n  madar_application:\n    path: ../unreviewed\n',
                        '  dependency_overrides:\n    madar_application:\n      path: ../unreviewed\n']:
            with self.subTest(content=content):
                (self.app / 'pubspec_overrides.yaml').write_text(content)
                self.assert_rejected('top-level YAML')

    def test_stale_overrides_file_is_rejected(self):
        (self.app / 'pubspec_overrides.yaml').write_text(
            'dependency_overrides:\n  madar_application:\n    path: ../unreviewed\n')
        self.assert_rejected('madar_application')

    def test_unrelated_overrides_file_does_not_hide_manifest_override(self):
        with (self.app / 'pubspec.yaml').open('a') as manifest:
            manifest.write('dependency_overrides:\n  madar_application:\n    path: ../unreviewed\n')
        (self.app / 'pubspec_overrides.yaml').write_text('resolution: workspace\n')
        self.assert_rejected('madar_application')

    def test_overrides_file_replaces_manifest_override(self):
        with (self.app / 'pubspec.yaml').open('a') as manifest:
            manifest.write('dependency_overrides:\n  madar_application:\n    path: ../unreviewed\n')
        (self.app / 'pubspec_overrides.yaml').write_text(
            'dependency_overrides:\n  madar_application:\n'
            '    path: ../Madar_Engine/packages/application\n')
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_encoded_absolute_source_uri_passes(self):
        link = self.root / 'engine with spaces'
        link.symlink_to(self.engine, target_is_directory=True)
        self.config['packages'][0]['rootUri'] = (link / 'packages/application').as_uri()
        self.write_config()
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unsupported_override_yaml_fails_closed(self):
        (self.app / 'pubspec_overrides.yaml').write_text(
            'dependency_overrides: {madar_application: {path: ../unreviewed}}\n')
        self.assert_rejected('block mapping')

    def test_optimized_python_does_not_disable_checks(self):
        self.config['packages'][0]['rootUri'] = (self.root / 'unreviewed').as_uri()
        self.write_config()
        self.environment['PYTHONOPTIMIZE'] = '1'
        self.assert_rejected('madar_application')

    def test_stale_lockfile_is_rejected(self):
        lock = self.app / 'pubspec.lock'
        lock.write_text(lock.read_text().replace('../Madar_Engine/packages/application', '../unreviewed'))
        self.assert_rejected('madar_application')

    def test_pin_cannot_name_package_outside_checked_engine(self):
        shutil.copytree(self.engine / 'packages/application', self.root / 'unreviewed')
        self.pin['packages']['madar_application']['path'] = '../unreviewed'
        self.write_pin()
        self.assert_rejected('madar_application')

    def test_uncommitted_engine_source_is_rejected(self):
        (self.engine / 'packages/application/lib/source.dart').write_text('// changed\n')
        self.assert_rejected('Engine source differs')


if __name__ == '__main__':
    unittest.main()
