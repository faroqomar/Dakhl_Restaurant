# Completion phase — scope, references and readiness

Date: 2026-11-05. Status: **Step 1 assessed; implementation blocked pending design and plan gates.** Owner direction: finish all remaining Dakhl_Restaurant phases as one phase. This changes execution grouping, not feature scope or recorded verification.

## One phase, preserved requirements

The active execution phase is **Completion**. Original IDs 00–11 remain traceable work-package IDs, not separately initiated future phases. Preserve Phase 01's approved-preview DONE record; include only its integration/regression obligations. Carry unfinished 00/02 evidence forward without rebuilding verified foundations by default. Packages 03–11 retain every work item and acceptance check in the [original detailed scopes](../planning/flutter-rebuild/README.md), [accounting parity](../planning/flutter-rebuild/accounting-parity.md), [feature coverage](../planning/flutter-rebuild/feature-coverage.md) and [MVP acceptance](../planning/flutter-rebuild/mvp-acceptance.md). Completion requires all applicable requirements, rather than a shorter substitute checklist.

The Lead may sequence dependent packages within this one phase. Consolidation does not authorize implementation now or require duplicate verification of unchanged evidence. UI design approval, plan approval, independent review, exact-revision merge approval and release/deployment authorization remain distinct.

## Current evidence and revisions

| Item | Verified current source / limits |
| --- | --- |
| App baseline | Original checkout HEAD `cde0a4cc34fbcabd90db91de5f6b2b8bf21f6f92`; clean tracked tree at intake. Ordinary documentation branch `codex/completion-scope`. No new worktree. |
| Engine consumption | `engine-dependency.json` pins `f7f68988561d25cc93eb28c0ec989847526b2df9`. Application `0.1.0-dev.3`, data `0.1.0-dev.2`, domain and Flutter adapters `0.1.0-dev.1`. Actual `python3 scripts/check-engine.py` passed this turn. No pin/package changes. |
| Runtime provenance | [November 4 consolidation](../log/2026-11-04-worktree-consolidation.md) records runtime package objects equal reviewed `899678fa0b85807850e626db69b3291b8a7b7b64`, with reviewed tooling consolidated into original checkouts. It retains native/retention limits. |
| Phase 01 | Tracker records approved development-preview integration DONE. This does not certify the remaining product. |
| Phase 02 publication | Live GitHub read confirms [PR #9](https://github.com/faroqomar/Dakhl_Restaurant/pull/9) MERGED at `2026-11-01T05:46:08Z`, merge `269118a8348c2d59075d50185a40e4dc613f11ac`, head `df90087ac2c1b635d15b83e7882a10a67c5d6673`. All six reported head checks succeeded. [Read-only receipt](../../outputs/completion-scope/app-pr9.json). These historical checks do not certify this documentation branch or later runtime changes. |
| Residual completion | Original tracker still records 00 closeout and 02 VERIFYING. Reconcile dated native/source evidence before closing these packages. Historical fixture retention/restoration remains unverified; accepted bounded-preview residual is not a restoration pass. No product release or joint DONE inferred. |

Earlier “PR #9 open/unmerged” statements are dated history, superseded for publication state by this live receipt. Older frozen plan statements about Figma, extra worktrees, JSON-only/no-engine assumptions and “implementation not started” do not override current rules and later approved contracts. Use Penpot, original checkouts/ordinary branches, and the actual reviewed engine pin. The original capture provenance and historical text remain intact.

## Ownership and dependencies

Madar owns reusable exact values, business invariants, public operation/query contracts and optional adapters. Dakhl_Restaurant owns Views/ViewModels, restaurant workflows, schema/legacy compatibility, document composition and app safeguards. Shared implementation must appear once in Madar; apps consume reviewed packages. [Engine counterpart](../../../Madar_Engine/docs/reference/consumer-completion-scope.md). New contract names below describe required outcomes, not selected APIs or implemented capabilities.

| Package / retained scope | Madar responsibility | App responsibility | Prerequisites |
| --- | --- | --- | --- |
| [00 residual](../planning/flutter-rebuild/phases/00.md) | CAP-00 evidence reconciliation; runtime change N/A unless a proven gap requires it | Baseline completion evidence, supported target/distribution inventory | Existing technical evidence |
| [02 residual](../planning/flutter-rebuild/phases/02.md) | Reuse reviewed document/workspace storage and exact-value contracts; assess proven gaps | Current native acceptance, compatibility and preservation limits, closeout | 00 technical prerequisite, approved 01 |
| [03 catalog/inventory](../planning/flutter-rebuild/phases/03.md) | Quantities, dated movements, reversal/history invariants | Product forms/images/filtering, availability and stock workflows | 01, 02 |
| [04 sales/drafts](../planning/flutter-rebuild/phases/04.md) | Exact sale calculation, atomic identity/commit and reusable workspace contracts | Ticket, hold/resume/swap, receipt, account/device scope | 01–03 |
| [05 history/returns/voids](../planning/flutter-rebuild/phases/05.md) | Eligibility, cumulative discount allocation/refunds, dated reversal | History/search/filtering and correction workflows | 02–04 |
| [06 daily accounting](../planning/flutter-rebuild/phases/06.md) | Funding splits, correction/inverse effects, balance/transfer invariants | Categories, daily records, chicken counts, cashbox, date correction/undo | 01, 02, 05 |
| [07 suppliers/materials](../planning/flutter-rebuild/phases/07.md) | Shared parties, liabilities and reference/snapshot contracts | Supplier/debt/material forms, defaults, chronological presentation | 01, 02, 06 |
| [08 purchasing/payments](../planning/flutter-rebuild/phases/08.md) | Invoice/payment allocation, atomic save and one source effect | Invoice/analysis/payment UI, independent carton/piece entry | 02, 06, 07 |
| [09 settings/recovery](../planning/flutter-rebuild/phases/09.md) | Reuse storage/file contracts; extend only for demonstrated reusable gaps | Identity/workflow settings, validated schema export/replacement preview, safeguards | 01, 02, 04, 06, 08 |
| [10 statements/reports](../planning/flutter-rebuild/phases/10.md) | Reusable financial queries and native file/share/print handoffs | Day review, statement filters, seven Arabic PDF compositions | 03–09 |
| [11 delivery/verification](../planning/flutter-rebuild/phases/11.md) | Independent shared-capability and consumer/conformance evidence | Complete offline restaurant day, migration, signed installed builds, update/rollback/manuals | All included requirements |

Dependency order remains real even within one phase: 00/02 residual readiness → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 11. Independent design/planning can overlap; implementation cannot bypass an unresolved dependency. Reuse approved 01 and unaffected engine/native evidence under its recorded identity and limits.

## Behavior and scope boundaries

- Preserve one restaurant, offline operation, Arabic RTL, IQD exact arithmetic, supported schema 1–11 history and non-destructive recovery. Preserve legacy retired worker/savings compatibility records without restoring their operational UI.
- Checkout confirms exact net receipt; no tendered-cash input, tax engine, automatic delivery fee or credit customer scope. Durable identity prevents duplicate sale, stock and cash effects. Failed save keeps the ticket. Device/account-scoped active/held drafts stay outside portable account backups; retain the source limit of 40 held orders.
- Refunds use original price/discount snapshots, cumulative rounding and optional restock; all full successive refunds equal original net. Apply refund effects on return date; eligible voids reverse original date. Protect historical nonnegative stock and posted history.
- Supplier invoices create liabilities, not paid expenses. Allocate payments to the selected invoice then eligible debt, without spilling into another invoice or future debt. Invoice plus immediate payment saves atomically; source cash changes once. Independent carton/piece defaults do not imply conversion or purchase-to-sellable stock.
- Preserve expense/shared-funding, correction/undo, date-shift collision protection, remaining snapshots and cash transfers. Chicken counts are nonfinancial. Cashbox, remaining cash and balances are not profit.
- Import replaces after validation, preview, confirmation and pre-import backup. Rejected/canceled/failed replacement preserves current records and prevents stale workspace resurrection.
- Seven report kinds remain daily expenses, supplier invoice, sale receipt, period sales/refunds, account statement, cashbox and supplier-payment receipt. Day review is informational; it does not introduce locking/closing or profit calculation.
- This app request does not add cloud/authentication, multitenancy, Windows, grocery UI, recipes/kitchen/tables, camera scanning, thermal hardware, payroll, tax/costing/profit policy or store publication. Madar's wider grocery/restaurant supported-release G/MR gates remain its own obligations; this consumer phase cannot claim to satisfy them all.

## Supplied references and design readiness

[Reference gallery](../planning/flutter-rebuild/gallery.html) shows the original supplied screenshots; [full frozen gallery](../planning/flutter-rebuild/gallery.html) and [capture manifest](../planning/flutter-rebuild/screenshot-manifest.json) retain provenance. Read-only UX assessment verified **179/179 current image hashes**, zero missing/mismatched. Capture date `2026-10-27T17:08:06.592Z`; Electron 1.12.0/schema 11, synthetic in-memory records. Original 03–11 references contain 176 unique images; including 02 gives 177. Counts overlap between packages and do not mean missing library files.

Desktop viewport PNGs represent 1440×1000 logical layouts at 2×; narrow viewport PNGs represent 390×844 at 2×. Full-document captures have variable heights; report HTML pages use 794×1123 logical dimensions. Consult the manifest for each image. Narrow references came from Electron on macOS; report images came from HTML. They do not prove Android/iPhone UI or actual PDF/printing behavior. Frozen source, images and assets remain unchanged.

Design is **required for remaining app feature UI (03–10)**. Use the existing [canonical Penpot page](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455). Preserve approved Phase 00 reproductions, Phase 01's 11 pairs, and Phase 02's six presented recovery/status pairs. [Step3 authorization](02-step3-build.md) and [plan](02-implementation-plan.md) supersede older pending watermarks only for that bounded Phase 02 set. They do not approve remaining product screens. No new Penpot boards or UI implementation occurred in Step 1.

Prepare one completion-phase design/wireframe package that covers remaining screens/forms/dialogs, populated/empty/loading/validation/save-failure/uncertain/retry/cancel/confirmation states, desktop and narrow layouts, large text, keyboard/focus, safe areas and keyboard visibility. Retain context-specific token corrections from the approved Phase 01 review. Show discrepancies for owner approval. Engine API/adapters and evidence-only 00/02/11 work: **Design N/A**; reassess if UI changes enter scope. Live TalkBack/screen-reader verification stays **owner-excluded, not tested**; keyboard/focus/semantics requirements remain.

## Readiness ledger

| ID | Blocker / decision | Owner and closure evidence |
| --- | --- | --- |
| B1 | Remaining feature designs/wireframes lack owner approval | UX prepares completion package in canonical Penpot space; owner approves exact presented scope. No redesign implied. |
| B2 | Implementation plan/public contracts not approved | Lead/Planner define bounded capability APIs, app integration, failure semantics, compatibility and meaningful tests; owner approves Step 2. Reuse existing packages before proposing more. |
| B3 | Immutable engine postings versus legacy editable/deletable expenses/payments/invoices need an explicit parity contract | Lead and engine/app planners map legacy actions to validated corrections/inverse history. Do not silently change UI behavior, recalculate history or bypass FIN-02. Identify only affected MD/OPEN decisions and resolve with examples before dependent code. |
| B4 | 00/02 closeout and native evidence contain stale/missing records | Lead reconciles live merge/check evidence with dated source/tool/target receipts. Keep unavailable current iOS checks, unknown historical retention and missing raw companions explicit. Do not rerun unchanged valid evidence merely to fill a log. |
| B5 | Final supported platforms, signing/distribution, physical targets and actual system printing need release evidence | Lead inventories access in Step 2; native campaign owner uses reviewed preflight/pilot/receipts before matrices. Package 11 needs physical installed-update persistence, native service checks, migration and rollback. No device actions in Step 1. |
| B6 | Per-feature capacity/budgets and measurement conditions remain to be planned | Lead registers realistic isolated p50/p95 elapsed/RAM/CPU scenarios with exact source/engine/tool/target/fixture identity. Existing 18 persistence cases are historical baselines, not measurements of future workflows. |

No unresolved optional cloud/hardware policy blocks unrelated local consumer planning. No financial/security/recovery policy is silently selected by consolidation.

## Owners, review and completion criteria

Lead owns the joint scope, dependency/evidence ledger and integration. Read-only Planner `completion_scope` assessed scope/contracts; read-only UX `completion_references` assessed references/design coverage. Independent Reviewer checks this documentation packet. No implementation Workers are assigned for Step 1. Future workers require non-overlapping ownership; campaign ownership avoids per-stage approval pauses within already authorized work.

Future implementation requires meaningful test-first independent engine suites plus app parity/consumer conformance, targeted existing CI, three-target UI/native evidence and per-major-feature benchmarks. Include retry/restart/stale writer, fractional refunds, backdating, shared funding, invoice/payment atomicity, failed import/recovery and update preservation. Deliver public API/setup/examples/errors/limits/compatibility, safe structured diagnostics and upgrade/rollback documents with each affected capability. Do not add unused packages or telemetry.

Completion requires all retained work-package acceptance, independent review and re-verification, configured exact-head checks, explicit merge approval, compatible engine-first integration and applicable signed delivery/rollback evidence. Release/deployment and any live cutover require their own authorization. Step 1 runs no application tests/builds/native campaign and claims no new runtime result. Local documentation/source/reference checks and separate-bank memory status appear in the [task digest](../log/2026-11-05-completion-scope.md) and [ignored execution journal](../log/phase-completion-execution.md).

Independent Step 1 documentation review completed on 2026-11-05 with no blocking findings after the viewport-dimension clarification. Original requirements/capture mappings remain intact and new links resolve. This is documentation readiness only; no implementation/design/release approval.
