# Phase 02 — Step 1 scope, references and readiness

Date: 2026-10-29. Status: Step 1 assessed; ready for bounded design/planning, not implementation. Owner authorized scope/references/tracking only. No design, implementation-plan, publication, merge or release approval is inferred.

## Source and dependency state

App branch `codex/phase02-scope`, base `2e4bbbfef5baba9122748ea16f25addabe13663f`; engine counterpart branch `codex/phase02-scope`, base `b1b4d6ec128e79d6dccb4849e5f9c561c219843c`. These bases include local completion/audit documentation beyond merged source. Earlier dirty worktrees are preserved. Remote main checked in this task: app `00b5bbae8be5ebb1bd2f98471b006dec8778f258`, engine `06e69f2da330bcce2250e22e743391fbdabb39bf`; both are ancestors of their assessment bases. No fetch, push or merge occurred.

- Phase 00: technical prerequisite verified; overall historical evidence integration remains VERIFYING. Do not mark it DONE here. [Dependency closure](../log/2026-10-29-phase01-step3-preflight.md), [native acceptance](00-ios-native-acceptance.md).
- Phase 01/CAP-01: approved development-preview source integrated and recorded DONE. [Exact approvals, merges and limits](01-step6-completion.md). Existing TalkBack exclusion belongs to that scope; it is not a general waiver for Phase 02.
- Current consumed runtime stays `6d4ae39f35b005dfa1123a82c6df316901e1e1e4`, application `0.1.0-dev.2`, data/native adapters `0.1.0-dev.1`. [Pin](../../engine-dependency.json). Assessment worktrees contain newer documentation/tooling; they are not substituted for that runtime checkout. No Phase 02 reviewed package revision exists.
- [Detailed Phase 02 scope](../planning/flutter-rebuild/phases/02.md), [Madar assessment](https://github.com/faroqomar/Madar_Engine/blob/a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294/docs/log/2026-10-29-phase02-scope-readiness.md), execution audit (local-only artifact `docs/log/phase-02-execution.md`, SHA-256 `d490433a2ead39ecf2f36721364cd1003b550152426fa7b98b90c3bb069c639c`).

## Bounded outcome and ownership

Accounts must save, reopen and recover offline without losing supported legacy records, relationships or historical meaning. One restaurant, Arabic RTL, whole IQD, isolated fixtures and no cloud/auth/multitenancy expansion remain hard boundaries.

| Responsibility | Owner | Phase 02 boundary |
| --- | --- | --- |
| Exact values, date/identifier primitives and shared validation/error contracts | Madar | Pure Dart, explicit ranges/rounding and generic tests; do not implement unrelated financial posting modules |
| Reusable storage/repository/recovery mechanism and optional adapter | Madar | Contract and backend choice require Step 2 reconciliation; one implementation consumed by apps |
| Restaurant schema codecs and legacy migrations | App | Supported schema 1–11 records, IDs, references, settings, correction history and historical workers/savingsEntries; no worker UI |
| Durable active/held workspace | Shared mechanism Madar; payload/lifecycle app | Foundations only; Phase 04 owns operating order/hold/resume workflows |
| Device/account settings separation | App composition over engine contracts | Preserve Phase 01 route/six-slot persistence; define backup/account versus device-only ownership before writes |
| Save/import/recovery presentation and safeguards | App | Arabic state copy, retained forms, confirmations and retry/cancel; engine returns stable errors, no UI |

Public contract is a proposal, not an API commitment: validated complete account read/write, explicit format/revision compatibility, one coordinated writer, old-or-complete-new recovery, preserved previous/unreadable/future state, typed failures and uncertain outcomes, successful replacement before draft cleanup. App-owned migrations supply restaurant semantics; adapter-owned atomicity/recovery stays in Madar. An approved backend ADR and meaningful generic plus consumer tests are required before depending on this contract.

## Compatibility and later-phase boundaries

Current frozen source accepts schema 1–11 and normalizes to 11. Preserve all supported entities, including later-feature records, without implementing their operating workflows. Do not promise arbitrary unknown-key retention. Model limits include integer IQD magnitude up to 10^12, quantities up to 10^9 with at most three decimals, Arabic/Persian digit normalization and legacy safe-intermediate/rounding rejection semantics. Preserve source limits through synthetic parity fixtures rather than silently extending them with Dart arithmetic.

`electron-reference/app/storage.cjs` validates before save, uses temporary write/fsync/rename and previous-copy backup, prevents ordinary save after unreadable load, and bounds save/import at 20 MiB. Legacy main-process single-instance locking is reference behavior, not proof of a Flutter account-writer policy. No real account files were read.

Phases 03–08 retain catalog/sales/accounting/supplier operating workflows. Phase 09 retains complete settings, manual backup management and import/recovery product integration; Phase 02 establishes necessary persistence/recovery foundations and their bounded user-visible states. Source/UI samples do not add recipes, costing, financial policy or cloud scope.

## Supplied references shown back to the owner

Original synthetic Electron captures: 1440×1000 logical / 2880×2000 pixels. All three hashes matched the frozen manifest in the read-only UX assessment; originals were also viewed by Lead and are presented in the chat. [Capture conditions](../planning/flutter-rebuild/capture-guide.md). These are reference pixels, not Flutter/native or fault-injection results.

| Reference | Actual state and allowed use | SHA-256 |
| --- | --- | --- |
| [desktop-save-error](../planning/flutter-rebuild/screenshots/desktop-save-error.png) | Persistent save error and bottom toast claiming current invoice retained as draft; simulated presentation, not disk-failure proof | 5f359aea97247edf579354441b61e28a9126cb67104fad16b746fac6d42746ce |
| [desktop-settings-data](../planning/flutter-rebuild/screenshots/desktop-settings-data.png) | Backup status/export/import/previous-copy restore/location composition; full settings workflow remains Phase 09 | 78bbbe0b0a642209995b6b4d0f9e3854e367f7904689fe0733022f8c06443daf |
| [empty-sales](../planning/flutter-rebuild/screenshots/empty-sales.png) | Empty-account context; Add product and sales operations are later-phase context | bc8a0e4093599b98c26e48b78ca62b57456ebc3e143709b048b14843893cdcd8 |

Mismatches: the published save-error caption said “New sale — ready for orders” and obscured the error; corrected in Markdown here. Existing Figma wording in this phase is superseded by current Penpot rules and corrected. Existing blanket tracker Design N/A is superseded for the full app scope. Previous Phase 00/01 approvals do not approve new recovery interactions. Historical frozen pixels remain unchanged; generated HTML mirrors are not regenerated by this assessment.

## Design applicability and implementation blockers

App Design: **required, pending**. Engine Design: **N/A**, no product UI. Step 1.5 must reuse the [canonical Penpot page](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455), preserving prior boards and shell/components. This task creates no Penpot boards.

Bound the design/wireframes to loading/saving/saved; unreadable/invalid/unsupported file; failed save with input retained; retry/cancel; previous-copy recovery and replacement confirmation. A simulated toast must not promise durable draft recovery before that storage behavior exists. Validate Arabic RTL, relevant desktop/phone/large-text layouts, reachable actions, keyboard/back/Escape and focus return, status announcements, contrast and targets. Actual native/accessibility checks remain future evidence.

| Gate | Current condition | Required before affected implementation |
| --- | --- | --- |
| Account backend/architecture | App proposes versioned JSON; Madar ST-07 selects SQLite/PowerSync. Neither alternative selected by Step 1 | Explicit bounded ADR/contract reconciling storage, migration and ownership; no copied app backend |
| Existing preferences adapter | CAP-01 supports opaque payloads up to 16 KiB and excludes accounts/tickets | Separate appropriate account/workspace contract; no limit increase or repurpose inferred |
| Recovery/concurrency | Account single writer, backup/replacement order and uncertain outcomes not yet contracted | Bounded recovery/compatibility decisions; relevant OPEN-06/MD-08 gates; no silent retention/encryption/cloud commitments |
| Preferences overlap | Route/six shortcuts already durable; account backup and device-only meanings differ | Reconcile schema/location and replacement behavior without overwriting Phase 01 settings |
| UI approval | Persistence/recovery interactions incomplete in supplied screenshots | Phase-scoped Penpot designs/wireframes and explicit owner approval |
| Plan and delivery | Step 2 plan, new engine revision, tests/CI/review are not delivered | Approved bounded plan, reviewed compatible engine source and all applicable gates |

## Verification and next boundary

Read-only Planner `phase02_planner` and UX `phase02_ux` supplied the findings above. Future acceptance: schema-by-schema supported-record parity/round trips; unknown-version preservation; 20 MiB boundary; fault injection at every write boundary; stale/overlapping writers; real-adapter fresh-process reopen; backup recovery; lifecycle interruptions; failed replacement preserving drafts and successful replacement ordering; independent engine plus consumer conformance on macOS/Android/iPhone. Tests must precede behavior changes. These are requirements, not executed results.

Runtime tests/builds/native checks/CI/benchmarks and release rollback execution: N/A to this documentation-only step. No optimization target exists, so numeric optimization benchmarks are N/A. Future real save/reopen/migration measurements need explicit fixtures/conditions before claiming performance. Required phase checks remain pending. Documentation links, owned diff, independent documentation review and separate memory receipts are recorded in the dated task logs.

Step 1 closes only the assessment. Step 1.5 and Step 2 remain separate owner-directed work. No implementation, phase completion, publication, merge or deployment occurred.
