<!-- hindsight:ignore -->

> Historical 19-phase plan, superseded by the [current 12-phase plan](../../README.md) on 2026-10-27. Do not use these phase numbers for new work.

# Frozen screenshot reference pack

Status: captured and catalogued 2026-10-27. 179 images; 0 capture errors in the final run.

## Provenance

The harness loads the current app/ui/index.html with the original preload and an isolated profile at dist/flutter-reference-profile. Its IPC handlers supply only fabricated in-memory restaurant records. It never creates Storage against the installed app directory or reads real accounts. Sample supplier names, receipts, debt and balances are illustrative; menu images and synthetic expanded catalog do not authorize real product additions.

The manifest records the current UI file hashes, logical viewport and physical PNG dimensions. A capture can have 2× physical pixels on Retina despite its logical layout size. Compare matching logical size and scale, not image width alone. The final capture uses desktop 1440×1000 and narrow 390×844; report HTML uses 794×1123, and the extracted design board uses 1440×1200.

## Naming

- desktop-*: entire app content viewport at its original layout; dialogs include background and all visible controls.
- phone-*: entire narrow Electron viewport. These are references for responsive fitting, not screenshots from iOS/Android devices.
- full-*: Chromium full natural document capture without CSS changes. Internal independently scrollable regions are not magically expanded; use paired bottom/scroll references.
- *-bottom: same viewport after scrolling the document or form to its lower content; a duplicate can be intentional when content already fits.
- empty-*: actual current screen rendered from an empty synthetic account.
- report-*: rendered current report HTML, including full-document copies. These do not assert PDF rendering or print pagination fidelity.
- design-system: board assembled from extracted current tokens/components; not a screen shipped in the app.
- desktop-validation and desktop-save-error: deliberately presented failure/validation states for visual reference. The save-error capture is a simulated presentation, not a claim that a disk failure occurred.

## Regeneration

Do not regenerate the baseline merely because implementation differs. When the owner changes a design, archive the existing manifest/images first, then capture a new revision and record the change.

From the project root, run the local Electron capture harness, then the Python planning-pack builder:

```sh
./node_modules/.bin/electron scripts/capture-flutter-reference.cjs
python3 scripts/build-flutter-plan.py
```

The design board and frozen assets are already present. Review differences against sourceHashes; update reference-assets only for an intentional new baseline. Capture profiles, generated report HTML and logs under dist/ are disposable, whereas docs/planning/flutter-rebuild is the durable handoff pack.

## What remains for implementation

Capture actual native Flutter screenshots, soft-keyboard/safe-area states, native import/share/print dialogs, crash recovery and fault-injection behavior on the requested devices. Add middle scroll positions for unusually long lists/forms where neither endpoint shows all fields. Phase acceptance requires these tests; the planning screenshots alone do not establish them.
