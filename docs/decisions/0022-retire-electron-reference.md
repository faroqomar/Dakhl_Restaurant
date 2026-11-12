# 0022 — Retire the Electron reference application

Date: 2026-11-12. Status: owner-approved maintenance, implemented locally. Supersedes [0013](0013-electron-reference-folder.md) for source-folder retention. Design, financial activation and delivery gates remain separate.

## Decision and reason

The owner requested removal of temporary references and repository cleanup, then explicitly included the preserved `electron-reference/` application. Remove that folder, its package/lockfile, legacy npm CI job, executable oracle generators, capture/export tools and obsolete planning-pack generator. Keep the root Flutter application and its reviewed Madar packages.

Retain the frozen 179 screenshots, 21 reference assets, source manifests, historical documents, Penpot evidence and existing synthetic JSON oracles. Replace live JavaScript comparisons with fixed source-derived synthetic expectations under `test/fixtures/legacy/`; provenance records capture runtime, source revision/hash and fixture hashes. These finite cases preserve existing regression coverage without retaining a runnable legacy app. They do not establish universal parser parity or new migration acceptance.

## Historical source recovery

The last source-containing checkout is Git revision `2c0eccd79ad3999b3b82779d9722bffbfb94f694`. Inspect a historical source without restoring an application copy:

```sh
git show 2c0eccd79ad3999b3b82779d9722bffbfb94f694:electron-reference/app/ui/model.js
```

Historical `electron-reference/` citations and npm commands in dated evidence describe that revision. They no longer name live checkout paths. [Capture history](../planning/flutter-rebuild/capture-guide.md) retains the old procedure; current verification checks screenshot/asset hashes and Flutter fixtures. Do not regenerate approved images to accommodate an implementation difference.

## Ownership and safeguards

App responsibility: repository layout, documentation, tests and CI. Engine work/API/revision: N/A; this removes consumer reference tooling and changes no shared capability, dependency pin, public contract, financial behavior or app data location. `engine-dependency.json` stays authoritative. No new runtime dependency, copied engine source or Electron implementation is introduced.

Before deletion, verify the 74 tracked entries are unchanged, no private account files or active handles need preservation, and directory symlinks only unlink their links. Preserve parent `docs`, `outputs`, `dist` and `design` directories. Git history and unique recovery objects remain intact. Existing uncommitted portfolio edits remain in place.

## Verification and limits

[Maintenance evidence](../log/2026-11-12-reference-cleanup.md) records exact checks, failures/recovery, independent review, source-removal guards and storage closeout. The affected suite passed 960 tests with the source absent; the final non-golden suite passed 1,430 tests. Analysis and formatting pass; 179 screenshot and 21 asset hashes match. The compatibility tests now compare captured historical expectations, not a live JavaScript execution.

No runtime feature, account migration, new phase, push, merge, release, deployment or design approval follows from this maintenance.
