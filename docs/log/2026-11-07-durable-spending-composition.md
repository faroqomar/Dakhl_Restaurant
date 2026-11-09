# Isolated Durable Spending Composition Record

Date: 2026-11-07.  
Author: Implementation Sub-Agent.  
Status: Worker-reported candidate conformance; independent review pending. Candidate command and host layer under ADR 0021 and `docs/phases/completion-durable-spending-contract.md`.

## Context & Scope

This work implements the bounded isolated durable spending composition in `Dakhl_Restaurant` under ADR 0021 and `docs/phases/completion-durable-spending-contract.md`.
It provides single-store atomic persistence for:
1. Operating Expenses (`CreateOperatingExpenseCommand`)
2. Purchase Invoices with optional atomic immediate payment and inline materials (`CreatePurchaseInvoiceCommand`)
3. Separate Supplier Payments (`CreateSupplierPaymentCommand`)

All operations atomically update source candidate records (`AccountDocument` within `PortableJournalState`), record immutable double-entry restaurant journals (`PortableJournalEntry` in `journals`), and persist durable command receipts/outcomes via Madar's `DurableCommandCoordinator` through a common application host (`JournalCommandHost`).

### Ownership Boundaries

As instructed, this sub-agent owned **strictly and only**:
- `lib/accounting/journal_command_host.dart` (NEW)
- `lib/accounting/restaurant_journal_spending_commands.dart` (NEW)
- `test/accounting/journal_command_host_test.dart` (NEW)
- `test/accounting/restaurant_journal_spending_commands_test.dart` (NEW)
- `test/accounting/restaurant_journal_spending_conformance_test.dart` (NEW)
- `docs/reference/durable-spending-commands.md` (NEW)
- `docs/log/2026-11-07-durable-spending-composition.md` (NEW)
- Minimal refactoring of `lib/accounting/restaurant_journal_sale_commands.dart` to adopt the shared host/snapshot/identity utilities while preserving all 41 existing sales tests and their public API.

All existing dirty and untracked work across the repository was strictly preserved untouched. Existing domain proposals (`PurchaseProposals`, `SaleProposals`, `ReturnProposals`), mapper, codecs, state models, UI, and repositories were reused through their public APIs without modification.

No commits, branches, PRs, worktrees, or build exports were initiated.

## Storage & Environment Measurements

| Metric | Baseline | Post-Implementation | Delta / Limit Status |
| --- | --- | --- | --- |
| Available Disk Space | 115,198,424 KiB | 112,754,376 KiB | > 10 GiB free guard strictly maintained |
| App Project Size | 26,751,464 KiB | 27,049,752 KiB | +298,288 KiB (well within < 2 GiB limit) |
| App Git Size (`.git`) | 18,419,640 KiB | 18,420,364 KiB | +724 KiB (stable) |
| Engine Size | 1,243,656 KiB | 1,244,104 KiB | +448 KiB (untouched) |
| Engine Git Size (`../Madar_Engine/.git`) | 36,612 KiB | 36,876 KiB | +264 KiB (untouched) |
| Own Leaked Temp Stores | 0 | 0 | 0 leaked (clean test tearDown) |
| Engine Git Commit | `d316fd6076375daa3f412889f73eaebfeeb5d4d4` | `d316fd6076375daa3f412889f73eaebfeeb5d4d4` | verified identical |
| App Git HEAD | `cc91fae` | `cc91fae` | verified identical |

## Implementation Architecture

### 1. Common Application Host (`JournalCommandHost`)
- Shared execution host eliminating duplicated CAS/recovery/identity logic between sales and spending command coordinators.
- Enforces authority fence verification (`expectedFence`) before performing any store reads or I/O (`missing_authority_fence`).
- Verifies that any injected `DurableCommandCoordinator` is bound to the exact same store instance (`identical(store, coordinator.store)`), rejecting foreign coordinator bindings with an `ArgumentError`.
- Employs `LineageScopedJournalCodec`, which runs outcome validation (`validateReplayOutcome`) **before** receipt lookup, and validates that the account lineage matches before and after store reads/writes.
- Guarantees that `replayedOutcomeMapper` cannot reject replayed proposals.

### 2. Snapshot & Canonical Identity Utilities
- `CommandSnapshot.freezeMap` and `freezeList` deep-freeze caller maps and lists recursively upon construction into `Map.unmodifiable` and `List.unmodifiable`.
- Input validation safeguards:
  - Recursion depth capped at 100 levels.
  - Cycle detection using identity sets.
  - Rejection of integers exceeding JavaScript `maximumSafeAggregate` (`9,007,199,254,740,991`).
  - Rejection of non-finite floating point numbers (`NaN`, `Infinity`).
- Canonical identity produces deterministic, lexicographically sorted JSON representations, making it sensitive to any financial or intent modification.

### 3. Operating Expense (`CreateOperatingExpenseCommand`)
- Validates category existence against `account.categories`.
- Supports funding split between daily cash and cashbox cash (`FundingSource.daily`, `FundingSource.cashbox`, `FundingSource.shared`).
- Emits balanced double-entry journal entry: debit `expense:category:<categoryId>`, credit `asset:cash:<source>`.
- Atomically records expense record in `AccountDocument.days[date].expenses`.
- Preserves source-permitted negative daily cash.

### 4. Purchase Invoice (`CreatePurchaseInvoiceCommand`)
- Supports optional atomic immediate payment and inline materials creation.
- Computes carton and piece quantities independently: `quantityCartons * priceCarton + quantityPieces * pricePiece`.
- Enforces approved 1A-P internal invoice mapping:
  - Invoice journal debits `expense:purchases` and credits `liability:supplier:<supplierId>` at the invoice date.
  - Immediate payment journal debits `liability:supplier:<supplierId>` and credits `asset:cash:<source>`.
  - **No second expense is recognized on payment**.
  - Exactly **one** durable receipt covers the entire atomic composite command.
- **Paid Spending Visibility Invariant**:
  - Cash register queries (`DailyCashQueries.statement()`) reflect only actual payment money outflows.
  - Unpaid invoices recognize internal expense and supplier liability, but create zero cash register rows and zero visible paid spending until actual payment is made.

### 5. Separate Supplier Payment (`CreateSupplierPaymentCommand`)
- Settles post-cutover invoice liability or verified historical debt.
- Debit `liability:supplier:<supplierId>`, credit `asset:cash:<source>`.
- Reconciles payment date against target invoice date (payment cannot precede invoice date).
- Cross-cutover gate: target invoice must possess an eligible post-cutover journal.
- **Historical Debt Invariant**:
  - Requires either eligible post-cutover invoice liability or explicitly verified opening liability in the cutover opening journal (`openingJournalId`).
  - Rejects payments against unverified historical debt (`unverified_historical_debt`).
  - Rejects payments exceeding available verified debt (`payment_exceeds_liability`).

### 6. Tamper, Replay, and Fence Resistance
- Any change to financial amounts, supplier, category, date, or `payloadVersion` under an existing `operationId` rejects with `changed_payload_rejected` without modifying store revision or payload.
- Stale storage fence generations reject with `stale_authority_fence`.
- Pre-cutover business dates reject with `pre_cutover_operation_rejected`.
- Gated cutover state rejects with `cutover_gated`.

## Verification & Conformance Evidence

1. **Host Unit Tests (`test/accounting/journal_command_host_test.dart`)**:
   - 12 unit tests verifying: deep recursive freezing, list length bounding, cycle detection, depth-100 recursion guard, integer bounds check, non-finite float rejection, deterministic key sorting, identity modification sensitivity, lineage-scoped decode/extract checks, foreign coordinator rejection, and fence pre-I/O check.
   - Result: 12/12 passed (100%).

2. **Spending Commands Unit Tests (`test/accounting/restaurant_journal_spending_commands_test.dart`)**:
   - 17 unit tests verifying: operating expense parameter freezing, funding validation, pre-cutover date rejection, non-existent category rejection, duplicate record ID rejection, zero-amount policy requirement, expense candidate updates and journal recording, purchase invoice independent carton/piece arithmetic, unpaid invoice internal expense vs zero paid spending invariant, invoice with atomic immediate payment (2 journals, 1 receipt, no second expense), overpay rejection, supplier payment settling post-cutover invoice, cross-cutover gate rejection, unverified historical debt rejection, verified opening debt payment bounds, and outcome payload roundtripping and validation.
   - Result: 17/17 passed (100%).

3. **Spending Store Conformance Tests (`test/accounting/restaurant_journal_spending_conformance_test.dart`)**:
   - 13 real-store integration tests using `PowerSyncLocalDocumentWorkspaceStore` and `DurableCommandCoordinator`:
     - Atomic persistence of operating expense (source, journal, receipt).
     - Atomic persistence of purchase invoice with atomic immediate payment (source, 2 journals, 1 receipt, visible cash = payment only).
     - Atomic persistence of unpaid purchase invoice (1 journal, 0 cash entries).
     - Atomic persistence of separate supplier payment (liability debit, cash credit, register reconciled).
     - Idempotent replay without revision increment.
     - Tampered command replay rejection (`changed_payload_rejected`) without writes.
     - Changed payload version replay rejection without writes.
     - Lineage mismatch checked before replay and rejected without executing.
     - Stale storage fence rejection (`stale_authority_fence`).
     - Rejection paths (gated cutover) leaving revision and payload untouched.
     - Real-store close and reopen from disk preserving complete state, journals, and receipts, supporting clean replay.
     - Uncertain acknowledgement resolution via `UnknownAckStore` with `resolvePendingWrite()`.
     - Full mixed sales and spending execution on the same store: interleaved `CompleteSaleCommand`, `CreateOperatingExpenseCommand`, `CreatePurchaseInvoiceCommand` (with immediate payment), and `CreateSupplierPaymentCommand` verifying monotonic receipt sequence (1, 2, 3, 4), 6 reconcilable journals, and mutual isolation.
   - Result: 13/13 passed (100%).

4. **Preserved Sales Test Suites**:
   - `test/accounting/restaurant_journal_sale_commands_test.dart`: 19/19 passed.
   - `test/accounting/restaurant_journal_sale_conformance_test.dart`: 10/10 passed.
   - `test/accounting/restaurant_journal_sale_safety_test.dart`: 12/12 passed.
   - All 41 sales tests remain green without any weakening of claims.

5. **Static Analysis**:
   - `dart analyze lib/accounting/ test/accounting/`: **0 issues found** (clean).


## Root intake and store-owner regression repair — 2026-11-07T18:52:19.941603+00:00

Root ran all accounting tests:136passed before new tests, then added two cross-store host-injection regressions. Both failed because the new optional JournalCommandHost could target a different store while the coordinator advertised the caller store. Root added identical-owner checks in both sale and spending constructors. All138accountingtests now pass; affected analysis reports no issues. All41previous sales test files retain the hashes recorded in durable-sales-recheck-inputs.json; source changed only for shared-host adoption, formatting and the new binding safeguard. The three original sales test suites were not edited.

Root formatted the six changed/new implementation and test files. Remaining review concerns include post-cutover raw debt counted without a matching liability journal, opening-liability versus historical-payment reconciliation, eligible invoice uniqueness/reversal/source matching, complete replayed source/journal/outcome reconciliation and the unused lexical comparator injected into ledger queries. These concerns are not closed by current passing tests; independent adversarial review owns their verification. No runtime activation, live amount/date or full-row completion claim.


## Independent review649e2f81 repairs

Confirmed defects: unposted raw manual debt enlarged eligibility, pre-cutover settlements reduced an already verified opening a second time, invoice posting uniqueness/reversal/value matching was missing, and replay accepted changed source fields and incomplete outcomes. Root now uses the existing PurchaseProposals/shared allocation result, bounds its debt portion by remaining verified opening, and validates relevant prior settlement postings. The approved selected-invoice-first excess-to-eligible-debt behavior remains. Reviewer suggestions to forbid that excess or ignore saved future payments are not adopted: current source debtAvailable reserves all recorded payments and the regression verifies that ignoring a future payment would over-settle the liability.

Each new command records a canonical source snapshot string in entry/receipt metadata. Replay checks complete source fields, invoice lines, funding/allocations, timestamps, original material/category resolution, all outcome links and exact journal policy/value against that evidence and captured intent. Invoice outcomes use the saved normalized number. Zero optional immediate payments no longer imply nonexistent payment/journal links. Earlier isolated candidate receipts without snapshots fail closed; runtime schema11 remains untouched.

The new persistent safety suite has37cases, including real-store tampering without writes, unchanged replay after later settlements and metadata edits, and a real committed invoice-with-payment write whose acknowledgement is lost before recovery/reopen.175accountingtests pass. Targeted analysis passes after five brace diagnostics were fixed. An initial edit script failed an anchor assertion after writing brace-only source changes; its shell incorrectly continued into tests, which exposed one changed error-code regression (165pass/1fail). Root switched dependent command batches to fail-fast set-e and preserved DomainValidationException payment_exceeds_liability mapping. The nine additional tests then compiled and all175accountingtests passed. Full app verification follows separately; no native/crash/power-loss/release claim.


## Final repair verification — 2026-11-07T19:48:40.253119+00:00

A further real-store regression proved that the constructor rejected equal raw invoice/payment IDs even though source namespaces are separate. Root removed that restriction; both records and paired journals now commit/replay under one receipt without ambiguity. The safety suite now has38cases. The source-bound full Flutter suite passes939tests, and full analysis reports no issues. Earlier938pass and175accountingpass counts remain intermediate evidence before this additional namespace repair. Original sales tests, shared host, portable codec/state and mapper hashes remain unchanged from the current shared-host review baseline; only the spending module and new safety tests changed in this repair.

The final scripts/check-engine.py run failed at the source-pin guard because the separate engine pilot added uncommitted tool/collation_pilot sources. Runtime packages remain clean at d316fd6. Root preserves the guard and records this delivery block; local test success is not source-pin/CI/release approval. No further full test rerun is needed unless source changes after the new repair manifest.
