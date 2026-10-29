import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('release_version', Path(__file__).parents[1] / 'release_version.py')
version = importlib.util.module_from_spec(spec)
spec.loader.exec_module(version)

class VersionTests(unittest.TestCase):
    def test_requires_monotonic_build_and_no_version_downgrade(self):
        for candidate in ['1.2.2+10', '1.2.3+9', '1.2.3+10']:
            with self.assertRaises(ValueError):
                version.validate(candidate, '1.2.3+10')
        self.assertEqual(version.validate('1.2.4+11', '1.2.3+10'), (1, 2, 4, 11))
        self.assertEqual(version.validate('1.2.3+11', '1.2.3+10'), (1, 2, 3, 11))

    def test_prepare_changes_only_explicit_version_and_preserves_other_text(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'pubspec.yaml'
            original = 'name: example\nversion: 0.0.0+1 # candidate\nflutter:\n  assets: [assets/]\n'
            path.write_text(original)
            version.prepare(path, '0.1.0+2')
            self.assertEqual(path.read_text(), original.replace('0.0.0+1', '0.1.0+2'))
            before = path.read_text()
            with self.assertRaises(ValueError):
                version.prepare(path, '0.0.1+3')
            self.assertEqual(path.read_text(), before)

    def test_rejects_non_release_versions_and_missing_build(self):
        for candidate in ['1.2.3', 'v1.2.3+4', '1.2.3-beta+4', '01.2.3+4', '1.2.3+0', '1.2.3+4\nmalicious']:
            with self.assertRaises(ValueError):
                version.validate(candidate)
