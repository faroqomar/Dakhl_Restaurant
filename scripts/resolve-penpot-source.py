#!/usr/bin/env python3
"""Resolve one artwork source from an explicitly selected audited manifest.

Read-only: no imports, captures, artwork updates or automatic manifest discovery.
The caller still owns reviewed-manifest selection and native/design approval.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


class SourceResolutionError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _path(root, value):
    if not isinstance(value, (str, Path)) or not str(value):
        raise SourceResolutionError("invalid_manifest", "Missing source path.")
    try:
        path = Path(value)
        resolved = (path if path.is_absolute() else root / path).resolve()
    except (OSError, RuntimeError, ValueError) as error:
        raise SourceResolutionError("invalid_path", "Cannot resolve source path.") from error
    try:
        resolved.relative_to(root)
    except ValueError:
        raise SourceResolutionError("path_outside_checkout", "Source path escapes the checkout.")
    return resolved


def _list(value):
    if not isinstance(value, list) or any(not isinstance(row, dict) for row in value):
        raise SourceResolutionError("invalid_manifest", "Expected a list of manifest records.")
    return value


def _single(rows, noun):
    if not rows:
        raise SourceResolutionError(noun + "_missing", "No matching " + noun + ".")
    if len(rows) != 1:
        raise SourceResolutionError(noun + "_ambiguous", "Multiple matching " + noun + " records.")
    return rows[0]


def _identity(root, entry):
    expected = entry.get("sha256")
    if not isinstance(expected, str) or re.fullmatch(r"[0-9a-f]{64}", expected) is None:
        raise SourceResolutionError("invalid_manifest", "Expected an exact SHA-256 digest.")
    return _path(root, entry.get("svgPath")), expected


def resolve_source(root, manifest, scene, kind, candidate=None):
    """Return the exact coverage source; reject contradictory or stale choices."""
    root = Path(root).resolve()
    manifest = _path(root, manifest)
    try:
        manifest_bytes = manifest.read_bytes()
        data = json.loads(manifest_bytes)
    except (OSError, ValueError) as error:
        raise SourceResolutionError("invalid_manifest", "Cannot read a valid JSON manifest.") from error
    if not isinstance(data, dict) or kind not in ("design", "wireframe"):
        raise SourceResolutionError("invalid_manifest", "Invalid manifest or source kind.")
    coverage = _list(data.get("coverage"))
    row = _single([r for r in coverage if scene in (r.get("sourceSceneId"), r.get("referenceId"))], "scene")
    scene_id = row.get("sourceSceneId")
    if not isinstance(scene_id, str) or not scene_id:
        raise SourceResolutionError("invalid_manifest", "Missing source scene identity.")
    entry = _single([r for r in _list(row.get("svgFiles")) if r.get("kind") == kind], "kind")
    canonical, expected = _identity(root, entry)
    overrides = [r for r in _list(data.get("overrides"))
                 if r.get("sourceSceneId") == scene_id and r.get("kind") == kind]
    if len(overrides) > 1:
        raise SourceResolutionError("manifest_inconsistent", "Duplicate source overrides.")
    if overrides and _identity(root, overrides[0]) != (canonical, expected):
        raise SourceResolutionError("manifest_inconsistent", "Coverage disagrees with its override.")
    if not overrides and not entry.get("unchanged"):
        raise SourceResolutionError("manifest_inconsistent", "Changed source has no matching override.")
    try:
        actual = sha256(canonical)
    except OSError as error:
        raise SourceResolutionError("source_unavailable", "Canonical source is unavailable.") from error
    if actual != expected:
        raise SourceResolutionError("source_hash_mismatch", "Canonical source differs from its manifest.")
    if candidate is not None and _path(root, candidate) != canonical:
        raise SourceResolutionError("superseded_source", "Candidate is not the selected canonical source.")
    return {
        "status": "resolved", "sourceSceneId": scene_id,
        "referenceId": row.get("referenceId"), "kind": kind,
        "path": str(canonical), "sha256": actual,
        "manifest": str(manifest),
        "manifestSha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "limits": "Source selection only; native export, review and owner approval remain separate.",
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--scene", required=True)
    parser.add_argument("--kind", required=True, choices=("design", "wireframe"))
    parser.add_argument("--candidate", type=Path)
    args = parser.parse_args(argv)
    try:
        result = resolve_source(args.repo, args.manifest, args.scene, args.kind, args.candidate)
    except SourceResolutionError as error:
        print(json.dumps({"status": "rejected", "code": error.code, "message": str(error)}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
