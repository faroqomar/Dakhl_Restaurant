<!-- hindsight:ignore -->

> Historical 19-phase plan, superseded by the [current 12-phase plan](../../README.md) on 2026-10-27. Do not use these phase numbers for new work.

# Daftar — Flutter/Dart rebuild to a complete MVP

Status: executable planning baseline; Flutter implementation has not started. Date: 27 October 2026 (Asia/Baghdad). Owner: restaurant/project owner. Reference: current working tree, Electron 1.12.0, account schema 11.

## Confirmed scope

- One restaurant; Arabic RTL and IQD. Rebuild in Flutter and Dart for **macOS, Android and iPhone**.
- Fully offline, one device’s local account at a time. Each installation holds its own data. Backups/import provide deliberate manual handoff; no merge or automatic device synchronization.
- Reproduce the **same current features and design**. The owner will decide any edits when the relevant phase begins. Until then, exact current-design reproduction is the baseline.
- PDF export/share and normal system printing. Thermal-printer integration is outside this MVP.
- Preserve existing finalized records, schema migrations, financial meanings, IDs, history and backup recovery. Retired worker data survives import/export; its removed screen stays removed.
- This task delivers the plan and reference pack. It does not install a replacement application, migrate real records or publish to stores.

## Start here

1. Browse the [visual reference gallery](gallery.html) — **179 captured images** with desktop, narrow, dialog, full-document, empty-state, design-system and report references.
2. Follow the [19 phase files](#phase-sequence), in dependency order. Every phase names a working feature/outcome, implementation checklist, screenshots and testable exit criteria.
3. Keep the [design contract](design-system.md), [accounting parity contract](accounting-parity.md), [feature/source inventory](feature-coverage.md) and [MVP acceptance checklist](mvp-acceptance.md) beside the work.
4. At the start of a phase, ask for any edits to that feature. Record accepted changes and replace only the affected reference baseline; retain the previous one. Do not pause unrelated agreed work waiting for speculative changes.
5. Finish each phase with working code, tests and Flutter captures. A visual mockup or a passing build alone does not finish a feature.

## Phase sequence

| Phase | Feature | Dependencies | Execution state |
| --- | --- | --- | --- |
| 00 | [Baseline and delivery setup](phases/00.md) | None | Not started |
| 01 | [Design system and responsive components](phases/01.md) | 00 | Not started |
| 02 | [Local accounts, validation and safe persistence](phases/02.md) | 00, 01 | Not started |
| 03 | [Navigation, shortcuts and interaction shell](phases/03.md) | 01, 02 | Not started |
| 04 | [Expense categories](phases/04.md) | 02, 03 | Not started |
| 05 | [Sellable products and inventory](phases/05.md) | 02, 03 | Not started |
| 06 | [Cash sale and saved receipt](phases/06.md) | 02, 03, 05 | Not started |
| 07 | [Active draft and held orders](phases/07.md) | 02, 06 | Not started |
| 08 | [Sales history, returns and voids](phases/08.md) | 02, 05, 06 | Not started |
| 09 | [Daily expenses, remaining cash and chicken counts](phases/09.md) | 02, 04, 08 | Not started |
| 10 | [Account statement and day review](phases/10.md) | 03, 09 | Not started |
| 11 | [Suppliers, opening balances and debts](phases/11.md) | 02, 03, 04, 09 | Not started |
| 12 | [Shared supplier materials and default prices](phases/12.md) | 02, 03, 11 | Not started |
| 13 | [Purchase invoices and purchase analysis](phases/13.md) | 02, 11, 12 | Not started |
| 14 | [Supplier payments and allocation](phases/14.md) | 02, 09, 11, 13 | Not started |
| 15 | [Cashbox and daily transfers](phases/15.md) | 02, 09, 14 | Not started |
| 16 | [Settings, backups, import and recovery](phases/16.md) | 02, 03, 06, 07, 14, 15 | Not started |
| 17 | [Arabic PDF reports, sharing and system printing](phases/17.md) | 06, 08, 10, 13, 14, 15, 16 | Not started |
| 18 | [Complete MVP verification, migration rehearsal and release](phases/18.md) | 00–17 | Not started |

Phases 00–03 establish the runnable foundation; 04–08 deliver sales and inventory; 09–15 deliver the complete accounting/purchase workflows; 16–18 finish portable data, reporting and verified delivery. Some domain infrastructure is shared, but no screen is declared complete until its full workflow and failure cases work.

## Proposed implementation boundaries

These are implementation recommendations to validate in phase 00/02, not additional owner-approved product features:

- A separate `flutter/` app inside this repository keeps the Electron reference available throughout the rebuild. Do not overwrite existing source or use the production storage path during development.
- Flutter views and view models render/coordinate; pure Dart domain code validates and computes; repositories are the single write boundary; platform services provide files, storage, sharing, print and lifecycle. Widgets do not calculate money or write account files.
- Begin with compatible, versioned local JSON and a reliable single-writer, validated atomic save/backup service. It matches the current offline product and minimizes migration risk. A database is not required by this request; any storage change needs a separate documented decision and proof of lossless compatibility.
- Keep finalized account data, recoverable ticket workspace and device-only preferences separate. Use stable operation identity and durable validation for duplicate prevention; no server is required.
- Choose and pin state-management, file, font, PDF and print packages after three-platform capability checks. No AlDakhl/Madar/PowerSync/Supabase dependency is implied.

These boundaries follow the separation of views, view models, repositories and services described in the [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide). They remain tailored to this local single-restaurant app.

## What “follow exactly” means

Use the frozen screenshots for Arabic wording, composition, alignment, density, colors, pictures, spacing, controls and visible state. Compare equivalent synthetic data at the same logical size. Preserve desktop full-width alignment and catalog/bill placement. Preserve function while fitting phone safe areas and keyboards.

The current narrow screenshots were rendered by Electron on macOS, **not** by Android or iOS. They cannot establish native fonts, safe areas, keyboard behavior, file dialogs or printing. Phase 01 must capture actual Flutter phone references and record unavoidable platform differences; no silent redesign is permitted. Cross-platform glyph/pixel identity is not promised before the font decision.

## Completion rule for every phase

All behavior tests and screenshot comparisons relevant to that phase pass; macOS/Android/iPhone paths are exercised; failed save/cancel/restart behavior is covered; no real restaurant records were used as test fixtures; the owner’s accepted edits are documented; actual evidence is linked. A dependency or signing/device limitation remains an open item and cannot be relabelled passed.

## Decisions to resolve when needed

| Decision | Resolve by | Default until then |
| --- | --- | --- |
| Screen/behavior edits | Start of each feature phase | Exact current source and design |
| Arabic font and asset licensing | 00–01 | Current macOS look is reference; no unlicensed font redistribution |
| Minimum OS/device matrix; macOS architectures | 00 | All three requested platforms remain required |
| iPhone delivery and Apple signing; Android signing; Mac installation route | 00, proved in 18 | Private/test delivery first; no automatic store publishing |
| JSON implementation and platform packages | 00–02 | Preserve compatibility and validate capability before adopting |
| Physical test devices/system printer access | 00 and 17 | Record unavailable hardware honestly; simulator-only checks do not finish native paths |

No additional product questions are required to start this plan. Login, multi-restaurant/multiuser support, cloud sync, recipes, kitchen tickets, tables, modifiers, tax engine, loyalty, camera scanning, thermal hardware, campaign publishing and profit reporting are not silently added. A held-order label such as “table 3” is not a table-management feature.

## Evidence and reference maintenance

The capture harness uses only synthetic in-memory accounts and an isolated Electron profile. [Manifest](screenshot-manifest.json) records capture metadata, image dimensions/checksums and current UI source hashes. [Capture guide](capture-guide.md) explains regeneration and limits. The existing JavaScript baseline passed **140/140 tests** during this task; no Flutter test/build/run is claimed.

Authoritative behavior is documented in [accounting rules](../../../../reference/accounting-rules.md), [application reference](../../../../reference/application.md), [scope](../../../../reference/project-scope.md) and decisions 0002–0010. [Decision 0011](../../../../decisions/0011-flutter-rebuild-baseline.md) records the newly confirmed rebuild boundary. Changes to this plan require evidence and an updated log, not a rewritten history.
