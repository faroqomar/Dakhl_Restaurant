> Source-retirement update, 2026-11-12: this is a frozen requirements/reference pack. Current implementation status belongs to [PHASES.md](../../../PHASES.md). The owner removed the Electron source and obsolete planning/capture generators; retain screenshots/manifests and historical phase definitions. Source citations below refer to Git revision `2c0eccd79ad3999b3b82779d9722bffbfb94f694`; [decision 0022](../../decisions/0022-retire-electron-reference.md) records recovery. Historical “not started” labels describe the original plan, not current execution.

> Execution update, 2026-11-05: the owner grouped all remaining work into one **Completion phase**. Original IDs below remain requirement/work-package references. Preserve prior DONE evidence and unfinished checks. [Current scope and readiness](../../phases/completion-scope-readiness.md) · [Current planning view](../../phases/completion-scope-readiness.md). This historical pack does not grant implementation approval.

# Dakhl_Restaurant — Flutter/Dart rebuild to a complete MVP

Status: revised 12-phase planning baseline, superseding the original 19-phase sequence; Flutter implementation has not started. Date: 27 October 2026 (Asia/Baghdad). Owner: restaurant/project owner. Reference: current working tree, Electron 1.12.0, account schema 11.

## Confirmed scope

- One restaurant; Arabic RTL and IQD. Rebuild in Flutter and Dart for **macOS, Android and iPhone**.
- Fully offline, one device’s local account at a time. Each installation holds its own data. Backups/import provide deliberate manual handoff; no merge or automatic device synchronization.
- Reproduce the **same current features and design**. The owner will decide any edits when the relevant phase begins. Until then, exact current-design reproduction is the baseline.
- PDF export/share and normal system printing. Thermal-printer integration is outside this MVP.
- Preserve existing finalized records, schema migrations, financial meanings, IDs, history and backup recovery. Retired worker data survives import/export; its removed screen stays removed.
- This task delivers the plan and reference pack. It does not install a replacement application, migrate real records or publish to stores.

## Start here

1. Browse the [visual reference gallery](gallery.html) — **179 captured images** with desktop, narrow, dialog, full-document, empty-state, design-system and report references.
2. Follow the [12 phase files](#phase-sequence), in dependency order. Every phase names a working feature/outcome, implementation checklist, screenshots and testable exit criteria.
3. Keep the [design contract](design-system.md), [accounting parity contract](accounting-parity.md), [feature/source inventory](feature-coverage.md) and [MVP acceptance checklist](mvp-acceptance.md) beside the work.
4. At the start of a phase, ask for any edits to that feature. Record accepted changes and replace only the affected reference baseline; retain the previous one. Do not pause unrelated agreed work waiting for speculative changes.
5. Finish each phase with working code, tests and Flutter captures. A visual mockup or a passing build alone does not finish a feature.

Read the adopted [AGENTS.md](../../../AGENTS.md), [PLANS.md](../../../PLANS.md) and [PHASES.md](../../../PHASES.md) before execution. PHASES.md is authoritative for status and evidence; all phases are initially TODO. The published table below is a scope overview and does not waive the workflow gates.

## Phase sequence

| Phase | Feature | Dependencies | Execution state |
| --- | --- | --- | --- |
| 00 | [Baseline and delivery setup](phases/00.md) | None | Not started |
| 01 | [Design system, navigation and interaction shell](phases/01.md) | 00 | Not started |
| 02 | [Local accounts, validation and safe persistence](phases/02.md) | 00, 01 | Not started |
| 03 | [Sellable products and inventory](phases/03.md) | 01, 02 | Not started |
| 04 | [Cash sales, saved receipt, drafts and held orders](phases/04.md) | 01, 02, 03 | Not started |
| 05 | [Sales history, returns and voids](phases/05.md) | 02, 03, 04 | Not started |
| 06 | [Daily accounting, expense categories and cashbox](phases/06.md) | 01, 02, 05 | Not started |
| 07 | [Suppliers, debts, materials and prices](phases/07.md) | 01, 02, 06 | Not started |
| 08 | [Purchase invoices, analysis and supplier payments](phases/08.md) | 02, 06, 07 | Not started |
| 09 | [Settings, backups, import and recovery](phases/09.md) | 01, 02, 04, 06, 08 | Not started |
| 10 | [Statements, day review, PDF reports and printing](phases/10.md) | 03, 04, 05, 06, 07, 08, 09 | Not started |
| 11 | [Complete MVP verification, migration rehearsal and release](phases/11.md) | 00–10 | Not started |

Phases 00–02 establish the runnable foundation; 03–05 deliver inventory and the complete sales lifecycle; 06–08 deliver accounting and purchasing; 09–11 finish settings/data portability, reporting and verified delivery. Some domain infrastructure is shared, but no screen is declared complete until its full workflow and failure cases work.

## Consolidation from 19 to 12 phases

The owner requested fewer, more coherent phases. The revision combines design with navigation, sales with draft/held-ticket recovery, daily accounting with categories and cashbox, suppliers with materials, invoices with settlement, and statements/day review with reports/printing. Storage safety, inventory, return accounting and final release remain distinct gates.

All original work items, feature-specific acceptance checks and 179 screenshot files are retained. Dependencies and screenshot filters use the new numbering. The [phase map](phase-map.md) records every old-to-new assignment and why it was merged; the [historical 19-phase version](archive/v1-19-phases/README.md) remains available for comparison and is superseded. A merged phase includes several workstreams and is complete only when all of them pass.

## Proposed implementation boundaries

These are implementation recommendations to validate in phase 00/02, not additional owner-approved product features:

- The Flutter application uses this project root. The owner retired the old `electron-reference/` source folder on 2026-11-12; plans, screenshots and source provenance remain. Use isolated synthetic data for development. [Retirement decision](../../decisions/0022-retire-electron-reference.md).
- Flutter views and view models render/coordinate; pure Dart domain code validates and computes; repositories are the single write boundary; platform services provide files, storage, sharing, print and lifecycle. Widgets do not calculate money or write account files.
- Begin with compatible, versioned local JSON and a reliable single-writer, validated atomic save/backup service. It matches the current offline product and minimizes migration risk. A database is not required by this request; any storage change needs a separate documented decision and proof of lossless compatibility.
- Keep finalized account data, recoverable ticket workspace and device-only preferences separate. Use stable operation identity and durable validation for duplicate prevention; no server is required.
- Choose and pin state-management, file, font, PDF and print packages after three-platform capability checks. No AlDakhl/Madar/PowerSync/Supabase dependency is implied.

These boundaries follow the separation of views, view models, repositories and services described in the [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide). They remain tailored to this local single-restaurant app.

## What “follow exactly” means

Use the frozen screenshots for Arabic wording, composition, alignment, density, colors, pictures, spacing, controls and visible state. Compare equivalent synthetic data at the same logical size. Preserve desktop full-width alignment and catalog/bill placement. Preserve function while fitting phone safe areas and keyboards.

The current narrow screenshots were rendered by Electron on macOS, **not** by Android or iOS. They cannot establish native fonts, safe areas, keyboard behavior, file dialogs or printing. Phase 01 must capture actual Flutter phone references and record unavoidable platform differences; no silent redesign is permitted. Cross-platform glyph/pixel identity is not promised before the font decision.

## Completion rule for every phase

All behavior tests and screenshot comparisons relevant to that phase pass; macOS/Android/iPhone paths are exercised; failed save/cancel/restart behavior is covered; no real restaurant records were used as test fixtures; the owner’s accepted edits are documented; actual evidence is linked. Each implementation phase has dedicated Git isolation, a read-only plan, meaningful tests before behavior changes, independent review/re-verification, applicable numeric benchmarks and required CI. UI work requires its suitable reference validated in Figma and user design approval before implementation; non-UI work records Design: N/A. Existing screenshot intent does not establish that new Figma gate as passed.

Only PHASES.md records execution completion. DONE requires all applicable requirements, user approval, merged PR and applicable release/rollback validation. Never merge without user approval and never automatically start the next phase. Missing dependency, design, signing/device or access evidence remains pending/blocked and cannot be relabelled passed.

## Decisions to resolve when needed

| Decision | Resolve by | Default until then |
| --- | --- | --- |
| Screen/behavior edits | Start of each feature phase | Exact current source and design |
| Arabic font and asset licensing | 00–01 | Current macOS look is reference; no unlicensed font redistribution |
| Minimum OS/device matrix; macOS architectures | 00 | All three requested platforms remain required |
| iPhone delivery and Apple signing; Android signing; Mac installation route | 00, proved in 11 | Private/test delivery first; no automatic store publishing |
| JSON implementation and platform packages | 00–02 | Preserve compatibility and validate capability before adopting |
| Physical test devices/system printer access | 00 and 10 | Record unavailable hardware honestly; simulator-only checks do not finish native paths |

No additional product questions are required to start this plan. Login, multi-restaurant/multiuser support, cloud sync, recipes, kitchen tickets, tables, modifiers, tax engine, loyalty, camera scanning, thermal hardware, campaign publishing and profit reporting are not silently added. A held-order label such as “table 3” is not a table-management feature.

## Evidence and reference maintenance

The capture harness uses only synthetic in-memory accounts and an isolated Electron profile. [Manifest](screenshot-manifest.json) records capture metadata, image dimensions/checksums and current UI source hashes. Its phase labels are the original capture numbers; [phase-map.json](phase-map.json) translates them for the current plan without altering the capture record. [Capture guide](capture-guide.md) explains regeneration and limits. The existing JavaScript baseline passed **140/140 tests** when the original pack was created; this revision changes documentation only and claims no new app or Flutter test/build/run.

Authoritative behavior is documented in [accounting rules](../../reference/accounting-rules.md), [application reference](../../reference/application.md), [scope](../../reference/project-scope.md) and decisions 0002–0010. [Decision 0011](../../decisions/0011-flutter-rebuild-baseline.md) records the rebuild boundary; [decision 0012](../../decisions/0012-merge-flutter-rebuild-phases.md) records this phase consolidation. Changes to this plan require evidence and an updated log, not a rewritten history.
