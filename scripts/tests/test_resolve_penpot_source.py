"""Import preflight rejects stale artwork even when its own hash is valid."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "resolve-penpot-source.py"


class SourceResolutionTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("resolve_penpot_source", SCRIPT)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.old = self.root / "old.svg"
        self.old.write_text('<svg><image x="1058" /></svg>')
        self.corrected = self.root / "corrected.svg"
        self.corrected.write_text('<svg><image x="1054" /></svg>')
        self.entry = {
            "kind": "design", "svgPath": str(self.corrected),
            "sha256": self.module.sha256(self.corrected),
        }
        self.data = {
            "coverage": [{"referenceId": "held", "sourceSceneId": "state-held",
                          "svgFiles": [dict(self.entry)]}],
            "overrides": [dict(self.entry, sourceSceneId="state-held", referenceId="held")],
        }
        self.manifest = self.root / "manifest.json"

    def resolve(self, **kwargs):
        self.manifest.write_text(json.dumps(self.data))
        return self.module.resolve_source(self.root, self.manifest, "state-held", "design", **kwargs)

    def fails(self, code, **kwargs):
        with self.assertRaises(self.module.SourceResolutionError) as caught:
            self.resolve(**kwargs)
        self.assertEqual(caught.exception.code, code)

    def test_selects_corrected_source_and_records_manifest_identity(self):
        result = self.resolve()
        self.assertEqual(result["path"], str(self.corrected))
        self.assertEqual(result["sha256"], self.module.sha256(self.corrected))
        self.assertEqual(result["manifestSha256"], self.module.sha256(self.manifest))
        self.assertEqual(result["sourceSceneId"], "state-held")

    def test_rejects_old_source_despite_valid_old_file(self):
        self.fails("superseded_source", candidate=self.old)

    def test_accepts_exact_canonical_candidate(self):
        self.assertEqual(self.resolve(candidate=self.corrected)["path"], str(self.corrected))

    def test_tampered_canonical_file_fails(self):
        self.corrected.write_text("tampered")
        self.fails("source_hash_mismatch")

    def test_missing_scene_fails(self):
        self.data["coverage"] = []
        self.fails("scene_missing")

    def test_ambiguous_scene_fails(self):
        self.data["coverage"] *= 2
        self.fails("scene_ambiguous")

    def test_missing_or_ambiguous_kind_fails(self):
        self.data["coverage"][0]["svgFiles"] = []
        self.fails("kind_missing")
        self.data["coverage"][0]["svgFiles"] = [self.entry, self.entry]
        self.fails("kind_ambiguous")

    def test_override_disagreement_fails(self):
        self.data["overrides"][0]["svgPath"] = str(self.old)
        self.fails("manifest_inconsistent")

    def test_unchanged_coverage_without_override_supported(self):
        self.data["overrides"] = []
        self.data["coverage"][0]["svgFiles"][0]["unchanged"] = True
        self.assertEqual(self.resolve()["path"], str(self.corrected))

    def test_reference_id_alias_resolves_same_scene(self):
        self.manifest.write_text(json.dumps(self.data))
        result = self.module.resolve_source(self.root, self.manifest, "held", "design")
        self.assertEqual(result["sourceSceneId"], "state-held")

    def test_symlink_outside_checkout_fails(self):
        with tempfile.TemporaryDirectory() as other:
            outside = Path(other) / "outside.svg"
            outside.write_text("external")
            self.corrected.unlink()
            self.corrected.symlink_to(outside)
            self.fails("path_outside_checkout")

    def test_relative_source_path_is_checkout_relative(self):
        self.entry["svgPath"] = "corrected.svg"
        self.data["coverage"][0]["svgFiles"] = [dict(self.entry)]
        self.data["overrides"][0]["svgPath"] = "corrected.svg"
        self.assertEqual(self.resolve()["path"], str(self.corrected))

    def test_changed_coverage_cannot_silently_lose_override(self):
        self.data["overrides"] = []
        self.fails("manifest_inconsistent")

    def test_missing_source_fails(self):
        self.corrected.unlink()
        self.fails("source_unavailable")

    def test_duplicate_override_fails(self):
        self.data["overrides"] *= 2
        self.fails("manifest_inconsistent")

    def test_malformed_path_has_structured_error(self):
        self.data["coverage"][0]["svgFiles"][0]["svgPath"] = "bad\x00path"
        self.fails("invalid_path")

    def test_invalid_manifest_shape_fails(self):
        self.data["coverage"] = {}
        self.fails("invalid_manifest")


if __name__ == "__main__":
    unittest.main()
