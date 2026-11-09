# Control crop diagnosis and source-selection preflight

Date: 2026-11-08. Status: implemented and locally tested; independent review pending.

The `state-held-orders-empty` select appeared as a check because its source crop
omitted the left arm of the V. This defect exists before Penpot import.

## Evidence and cause

`outputs/penpot/completion/source/package-prep/capture-delta-held-checkout-v2.cjs:189`
uses a fixed `owner.x + 7` offset. Source owner `n478`, `#sale-order-type`, has
bounds `1051,599.625,350,34`. The resulting crop is `1058,613.125,11,7` logical
pixels. Its 22×14 PNG exactly equals the frozen scene crop at physical
`2116,1226`; the pixels already show the truncated V. `build-artwork.py:193`
embeds that payload and geometry unchanged.

The complete source V requires logical `1054,613,11,7`, physical
`2108,1226,22,14`. Existing marker-completeness evidence records 16 glyph pixels
missing from the original crop. Scene/control-scoped asset filenames and the
exact source-pixel match provide no evidence for filename collision or an
importer-induced shape change. CSS `appearance:auto` does not expose native
glyph geometry; its padding is not proof of the indicator position.

The same scene already has corrected design and wireframe entries in
`outputs/penpot/completion/source/package-prep/global-marker-paint-complete-v1-overrides-manifest.json`.
The corrected marker ID is `ua-paint-state-held-orders-empty-control-raster-11`.
The repeated repair came from selecting the original delta SVG instead of this
existing corrected source. The compact [receipt](../../outputs/completion-review/control-source-selection/diagnosis-and-preflight.json)
binds the source, old/corrected assets, manifest, tool and tests by SHA-256.

## Change and usage

Bounded inspection found existing corrected-artwork builders and auditors, but
no import-time source resolver in the app's scripts/tool/test paths. The Lead
authorized the proposed small resolver after receiving the diagnosis and scope.

`scripts/resolve-penpot-source.py` selects exactly one scene/kind from an explicit
manifest's coverage, checks consistency with its override, confines canonical
paths to the checkout, and verifies the selected file's SHA-256. It rejects an
old candidate with `superseded_source` rather than silently substituting artwork.
It only reads files and emits compact JSON; exit 0 means resolved, exit 1 rejected.

```sh
python3 scripts/resolve-penpot-source.py \
  --manifest outputs/penpot/completion/source/package-prep/global-marker-paint-complete-v1-overrides-manifest.json \
  --scene state-held-orders-empty --kind design
```

Pass `--candidate path/to/artwork.svg` to verify a proposed import path. The
caller must select the reviewed manifest explicitly and preserve the returned
manifest/file hashes through import. This is not automatic discovery of the
latest authority, native qualification, owner approval, or a race-free guarantee
for later reads. Do not rely on it as an operational gate before independent review.

For future capture generation, reuse the existing bounded owner-clipped
glyph-completeness measurement and align saved bounds to physical crop pixels.
Do not globally change `+7` to `+3`: one measured select does not establish every
native control's offset. No capture script, source artwork or manifest changed.

## Verification and limits

- Seventeen stdlib unit tests pass: corrected selection, stale candidate rejection,
  exact candidate acceptance, source tampering, missing/ambiguous scene or kind,
  inconsistent/duplicate/missing overrides, unchanged entries, alias resolution,
  relative paths, missing source, malformed paths/schema, and symlink escape rejection.
- Real retained manifest probes resolved corrected design and wireframe plus one
  unchanged scene. The original delta design was rejected with `superseded_source`.
- Initial tests failed because the implementation was absent. Four subsequent
  fixture assertions exposed macOS `/var` to `/private/var` canonicalization;
  resolving the fixture root fixed these without weakening path checks.
- Earlier diagnosis intake produced excessive/truncated output. Bounded numeric,
  path/hash and pixel reads supplied the decisive evidence. PIL was unavailable;
  a read-only stdlib PNG decoder verified pixels without installing dependencies.
- Engine implementation/API/package work: N/A. This is consumer source-reference
  tooling. Runtime, financial, engine, browser and native design state are untouched.
- No Git mutation or new design/phase approval occurred. Root tracker/prevention
  integration, independent review and aggregate memory sync/check belong to the Lead.

Storage baseline and final closeout, retained artifact sizes, temporary-store
counts and uncertainty are recorded in the receipt. Existing design evidence is
retained; no captures, exports, libraries or duplicate artwork were created.
