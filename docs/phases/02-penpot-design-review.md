# Phase 02 — Penpot design and wireframe review

Date: 2026-10-29. Status: READY FOR OWNER DESIGN APPROVAL — all12final native exports independently reviewed; no design approval inferred. Owner invoked Step 1.5 only. [Scope](02-scope-readiness.md), execution audit (local-only artifact `docs/log/phase-02-execution.md`, SHA-256 `d490433a2ead39ecf2f36721364cd1003b550152426fa7b98b90c3bb069c639c`).

## Scope and authority

Bounded persistence/recovery presentation, using the existing approved Phase 00/01 shell and three supplied references: desktop-save-error, desktop-settings-data and empty-sales (1440×1000 logical, synthetic Electron captures). References were viewed/hash-verified in Step 1 and reused unchanged. New state designs do not implement or authorize later sales, catalog or full settings workflows. Existing Penpot boards remain preserved.

Canonical destination: [Dakhl_Restaurant phase designs and wireframes](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455). Live Chrome plugin reconnected; file/page IDs confirmed. Lead alone controls native edits. Read-only UX phase02_ux supplies copy/coverage; independent review will use final exports.

Engine/API/runtime/package/logger changes and engine Design: N/A. Storage/backend/recovery contracts remain unresolved Step 2 work; current6d4ae39 engine runtime pin is unchanged. Restaurant UI/copy/composition/safeguards belong to the app. No financial policy, authentication, sync, deployment or publication is selected.

## Review set

Six design/wireframe pairs proposed, with native editable controls and Arabic text over preserved layered reference context. Desktop app viewport remains1440×1000; a separate400px review band follows it. Narrow app viewport remains390×844 with a400px review band. Large-text320px-wide study uses a1000px scrollable logical viewport plus320px review notes. Review-band text is English documentation outside the application viewport.

| Pair | App/state context | Coverage |
| --- | --- | --- |
| A | Sales reference context with retained synthetic input | Persistent failed save/retry, loading, saving, confirmed saved and uncertain outcome |
| B | Settings/data reference with file-error modal | Unreadable, unsupported, invalid, oversized20MiB boundary and full-disk/write failure |
| C | Settings/data reference with replacement confirmation | Safe cancellation, previous-copy recovery, restoring, known failure and confirmed success |
| D | 390×844 narrow reference context | Stacked retry/cancel and file reselection; same state/error meanings |
| E | 390×844 narrow recovery | Safe initial focus/cancel and keyboard-aware reachable actions; inset illustration not device evidence |
| F | 320px wide/200 percent text study | Wrapped32px body/actions,40px heading, visible focus, large targets and scroll continuation |

## Intentional differences and conditions

The source screenshots establish style/composition, not an implemented recovery guarantee. New boards are proposals, not pixel-identical reproductions. Approved Phase 01 reference context includes a populated synthetic ticket; Phase 02 does not enable those operations. A replaces any inherited recovered-draft assertion with a persistent error/retry presentation. No toast says the invoice is durably saved as a draft. Core copy: “Save failed. Your changes are still displayed.” Arabic executable design copy remains Arabic.

Confirmed-saved/replacement-success states are conditional on actual confirmed storage outcomes. Known failure preserves current accounts/input; old account drafts clear only after successful replacement. Backup availability/preservation and unknown-commit retry eligibility require the later storage contract. Native file selection is reused; no new import-preview feature is added. A160px keyboard inset is illustrative, not a promised OS keyboard size.

## Accessibility, responsiveness and verification limits

Persistent critical text supplements color/toasts. Keyboard traversal follows visible order; modal focus stays inside, Escape/back cancels safely and focus returns to invoker. Replacement initially favors Cancel; buttons meet proposed44px minimum targets. Arabic RTL, financial numerals, wrapping and status semantics are specified. Medium1024×768/wide1920×1080 reuse existing shell evidence with adaptation constraints, not fresh native execution.

The owner's2026-10-29 app-wide live TalkBack/screen-reader exclusion supersedes the earlier Step1 note limiting the exclusion to Phase01. It remains excluded, never passed. Preserve keyboard/focus/semantics. Static boards do not verify native accessibility, real keyboard insets, persistence correctness or restart. New per-feature p50/p95/RAM/CPU obligations apply to future implementation; static design runtime benchmarks N/A. Candidate0.0.0+1 remains unreleased; no version bump or delivery implied.

## Evidence and approval

Native pilot/export verification, final IDs/hashes, saved page screenshot, structural/native editability audit, independent review and separate project-memory delivery will be completed below. Owner design approval remains pending; stop after presenting concrete previews. No UI implementation or automatic Step2 advancement.

## Native structure and review evidence

The12newboards form6design/wireframe pairs; all30prior boards matched the full pre-edit fingerprint. Native audit found no full-frame raster image substitutes. New controls/copy are native editable rectangles/text; older reference lettering includes inherited outline paths. Phone source t175's unverified saved-draft toast is hidden only in the4newD/E clones; original reference boards and frozen files are unchanged. Geometry/text/current revision are recorded in outputs/penpot/phase02/native-audit.json.

Relevant new-control contrast ratios: ink/paper12.67:1, muted/paper6.70:1, paper/green7.84:1, paper/error6.12:1, error/soft5.32:1, focus/paper7.05:1. This calculation covers new palette combinations, not every inherited reference element or runtime accessibility. Large-text specimens use32px body/actions and40px heading; native geometry and final-image review are separate checks.

Penpot UI confirmed Saved at revision90 after native edits. A-design export initially retained the old pilot hash despite current API text and corrected live canvas. Export after confirmed Saved produced the new copy/hash. Saved-state gating and final native image/hash review are required; source/geometry alone cannot pass the design. The standard Penpot file-backup API attempt failed with “No matching clause”; no successful .penpot archive is claimed. Native PNG exports, source/correction scripts, metadata and saved cloud page remain the delivered evidence.

Initial native PNGs exposed copy/annotation/inherited-toast defects; independent review required scoped correction and re-export. Superseded pilot/initial files retain provenance and are not approval artifacts. Final approval artifacts are exclusively the12files and hashes in outputs/penpot/phase02/native-exports.json after final review closes. Full-file archive export is a recorded limitation, not permission to reload unsaved work or claim a backup.

| Pair | Design board ID | Wireframe board ID |
| --- | --- | --- |
| A-status | `6038a601-8820-8088-8008-dd95cd39041c` | `6038a601-8820-8088-8008-dd96fb7babe3` |
| B-file-errors | `6038a601-8820-8088-8008-dd9713096e9f` | `6038a601-8820-8088-8008-dd97493bbf5c` |
| C-recovery | `6038a601-8820-8088-8008-dd9762aa3b02` | `6038a601-8820-8088-8008-dd977b64868a` |
| D-narrow-status | `6038a601-8820-8088-8008-dd979596f451` | `6038a601-8820-8088-8008-dd97a4b1654c` |
| E-narrow-recovery | `6038a601-8820-8088-8008-dd97b4c21f02` | `6038a601-8820-8088-8008-dd97c8ee7ea3` |
| F-large-text | `6038a601-8820-8088-8008-dd97dbb49c9e` | `6038a601-8820-8088-8008-dd97e8631697` |

Final independent review, link/whitespace checks and separate memory receipts are recorded in the Step1.5 task log. No design approval, implementation, backend policy, PR/push/merge or deployment is inferred.

## Final Step 1.5 verdict

Independent Reviewer phase02_docs_review visually reviewed all6final design/wireframe pairs and verified all12PNG hashes against the final manifest. Developer copy, inherited saved-draft toast and clipped English review annotations are closed. No remaining actionable design-review findings. Review span20:19:47–20:31:49UTC includes export/repair waits; active effort/tokens/cost unknown. Prior30boards unchanged; no full-frame raster substitutes. No runtime acceptance or design approval is inferred.

[Full-size final approval gallery](../../outputs/penpot/phase02/review-gallery.md), [design overview](../../outputs/penpot/phase02/design-overview.png), [wireframe overview](../../outputs/penpot/phase02/wireframe-overview.png), [exact final PNG manifest](../../outputs/penpot/phase02/native-exports.json), native audit (local-only artifact `outputs/penpot/phase02/native-audit.json`, SHA-256 `ea905fd2b9f1ce88a5f52b3a262eb73b71acb5b75456ad51a31d7bcbbb6a705f`). Penpot page proof is outputs/penpot/phase02/penpot-page-proof.jpg. Read-only source/native export metadata and correction artifacts remain beside these files.

Owner approval is the next gate. Step2 planning/backend decisions and any UI implementation require their separate authorization. No push/PR/merge/tag/release/deployment or new phase is started.
