import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('embed_icu', Path(__file__).parents[1] / 'embed_icu_macos.py')
embed = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(embed)


class EmbedIcuTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dakhl-icu-layout-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        identities = {}
        for relative in embed.FILES:
            target = self.source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            data = relative.encode()
            target.write_bytes(data)
            identities[relative] = {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
        for relative, target in embed.LINKS.items():
            (self.source / relative).symlink_to(target)
        self.manifest = {'formatVersion': 1, 'platform': 'macos-arm64', 'entryLibrary': embed.ENTRY,
                         'files': identities, 'symlinks': embed.LINKS, 'runtimeBytes': sum(v['bytes'] for v in identities.values())}
        (self.source / 'manifest.json').write_text(json.dumps(self.manifest))
        self.addCleanup(patch.stopall)
        patch.object(embed, 'BRIDGE', identities[embed.ENTRY]['sha256']).start()
        patch.dict(os.environ, {'MADAR_ICU_RUNTIME_DIR': str(self.source), 'TARGET_BUILD_DIR': str(self.root),
                              'FRAMEWORKS_FOLDER_PATH': 'Candidate.app/Contents/Frameworks',
                              'UNLOCALIZED_RESOURCES_FOLDER_PATH': 'Candidate.app/Contents/Resources',
                              'MADAR_REQUIRE_ICU_RUNTIME': '1'}).start()
        self.code = self.root / 'Candidate.app/Contents/Frameworks/MadarIcu'
        self.resources = self.root / 'Candidate.app/Contents/Resources/MadarIcu'

    def run_embed(self):
        with contextlib.redirect_stdout(io.StringIO()) as stream:
            embed.main()
        return json.loads(stream.getvalue())

    def test_code_and_resources_separate_without_altering_native_bytes(self):
        self.assertEqual(self.run_embed()['code'], 'embedded')
        self.assertFalse((self.code / 'LICENSE').exists())
        self.assertFalse((self.code / 'manifest.json').exists())
        self.assertEqual((self.resources / 'LICENSE').read_bytes(), (self.source / 'LICENSE').read_bytes())
        self.assertEqual((self.resources / 'manifest.json').read_bytes(), (self.source / 'manifest.json').read_bytes())
        for relative in embed.FILES - {'LICENSE'}:
            self.assertEqual((self.code / relative).read_bytes(), (self.source / relative).read_bytes())
        for relative, target in embed.LINKS.items():
            self.assertEqual(os.readlink(self.code / relative), target)
        inode = (self.code / embed.ENTRY).stat().st_ino
        self.assertEqual(self.run_embed()['code'], 'reused')
        self.assertEqual((self.code / embed.ENTRY).stat().st_ino, inode)

    def test_verified_old_generated_layout_migrates(self):
        shutil.copytree(self.source, self.code, symlinks=True)
        self.assertEqual(self.run_embed()['code'], 'embedded')
        embed.verify(self.code, self.manifest, self.resources)
        self.assertFalse((self.code / 'LICENSE').exists())

    def test_interrupted_split_publication_recovers_exact_code_only_copy(self):
        replace = Path.replace
        def fail_resources(path, target):
            if Path(target) == self.resources:
                raise OSError('injected publication interruption')
            return replace(path, target)
        with patch.object(Path, 'replace', fail_resources):
            with self.assertRaises(OSError):
                self.run_embed()
        self.assertTrue(self.code.exists())
        self.assertFalse(self.resources.exists())
        self.assertEqual(self.run_embed()['code'], 'embedded')
        embed.verify(self.code, self.manifest, self.resources)

    def test_partial_changed_code_is_preserved(self):
        shutil.copytree(self.source, self.code, symlinks=True)
        (self.code / 'LICENSE').unlink()
        (self.code / 'manifest.json').unlink()
        (self.code / embed.ENTRY).write_bytes(b'unknown bytes')
        with self.assertRaises(ValueError): self.run_embed()
        self.assertEqual((self.code / embed.ENTRY).read_bytes(), b'unknown bytes')

    def test_interrupted_cleanup_recovers_exact_resources_only_copy(self):
        self.run_embed()
        # A semantically identical manifest formatting change requires rebuild.
        (self.resources / 'manifest.json').write_text(json.dumps(self.manifest, indent=2))
        remove = shutil.rmtree
        def fail_after_code(path, *args, **kwargs):
            result = remove(path, *args, **kwargs)
            if Path(path) == self.code: raise OSError('injected cleanup interruption')
            return result
        with patch.object(embed.shutil, 'rmtree', fail_after_code):
            with self.assertRaises(OSError): self.run_embed()
        self.assertFalse(self.code.exists())
        self.assertTrue(self.resources.exists())
        self.assertEqual(self.run_embed()['code'], 'embedded')
        embed.verify(self.code, self.manifest, self.resources)

    def test_partial_changed_resources_are_preserved(self):
        self.run_embed()
        shutil.rmtree(self.code)
        (self.resources / 'LICENSE').write_bytes(b'unknown license')
        with self.assertRaises(ValueError): self.run_embed()
        self.assertEqual((self.resources / 'LICENSE').read_bytes(), b'unknown license')

    def test_unknown_generated_file_is_not_removed(self):
        self.run_embed()
        unknown = self.code / 'unique-recovery'
        unknown.write_text('preserve')
        with self.assertRaises(ValueError):
            self.run_embed()
        self.assertEqual(unknown.read_text(), 'preserve')

    def test_changed_old_copy_is_preserved_and_refused(self):
        shutil.copytree(self.source, self.code, symlinks=True)
        (self.code / 'LICENSE').write_text('unexpected retained file')
        with self.assertRaises(ValueError):
            self.run_embed()
        self.assertEqual((self.code / 'LICENSE').read_text(), 'unexpected retained file')
        self.assertFalse(self.resources.exists())


if __name__ == '__main__':
    unittest.main()
