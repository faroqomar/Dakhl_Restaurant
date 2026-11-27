# HTML retained after repository cleanup

Date: 2026-11-12. Scope: generated artifacts and historical presentation only. Markdown plans/contracts and PHASES.md retain authority. This changes no Flutter UI, engine API/pin, account data, design approval or release status.

## Keep

The keep/delete manifest records exact paths, hashes, reasons and retained capture/geometry counterparts at `outputs/storage-cleanup/2026-11-12-html/retention-manifest.json`.

Seven tracked HTML files remain:

- [Screenshot gallery](../planning/flutter-rebuild/gallery.html): one filterable index for the 179 canonical captures.
- Approved C1 packet: exact owner-approved presentation; preserve its byte/hash identity.
- C2 review, category hold/proposal review and positive-return proposal review: distinct current review packets; retaining them does not grant approval.
- Current promotional menu and current dine-in menu: current editable/print outputs. Their generators still depend on earlier JSON/font folders; those assets remain.

Fourteen existing local-only Penpot HTML sources/review helpers remain under the current ignore rules. They include three hand-authored annotation inputs, six current C3 source captures, the unique held-name source, and four current review/comparison helpers. They retain their original hashes and locations. This cleanup does not publish those local artifacts or qualify new design evidence. Canonical native archives, source SVGs, geometry JSON, screenshots, manifests and approved crops remain in place.

## Remove and recover

Remove the other 1,050 HTML files: duplicate planning/phase/contract pages, the duplicate Completion screenshot index, superseded Figma transfers and dashboard copies, superseded menu versions, old report previews and generated Penpot capture/diagnostic wrappers. Keep the Markdown counterparts, current packets and their independent source/capture evidence. Retire five launch/capture helpers that require the removed HTML or retired Electron source.

Tracked historical HTML remains available at Git revision `433ee33f1b2811687cc8b23af2c5c9014786de5d`. For example:

```sh
git show 433ee33f1b2811687cc8b23af2c5c9014786de5d:docs/planning/flutter-rebuild/plan.html
```

Untracked generated snapshots do not exist in Git. The manifest records their hashes and retained counterpart provenance; their captured geometry, PNG/SVG/native sources remain. Do not claim an HTML copy can be recovered from its hash. Current review packets and unique editable inputs were excluded from deletion before cleanup.

## Avoid reintroducing duplicate output

Use Markdown for plans/contracts and the single screenshot gallery for image browsing. Keep generated source-state HTML only while a current capture/source manifest needs it; retain one current review packet per distinct unresolved review. Compare proposed output with this manifest before regenerating a whole batch. Historical paths in frozen receipts describe their dated state and do not require restoring every browser snapshot.
