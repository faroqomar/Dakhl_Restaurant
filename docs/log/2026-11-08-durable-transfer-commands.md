# Durable daily-to-cashbox transfer foundation task log

Recorded UTC: 2026-11-08T03:05:00.000000+00:00 (Local: 2026-11-08T06:05:00+03:00).
Status: implementation complete; candidate independent review pending. Advances C4-16 foundation and F-07–F-09 evidence; does not close operational UI or checklist rows.

## Role and exclusive boundaries

- Implementation sub-agent for Dakhl_Restaurant.
- Exclusive ownership:
  - `lib/accounting/restaurant_journal_transfer_commands.dart`
  - `test/accounting/restaurant_journal_transfer_commands_test.dart`
  - `test/accounting/restaurant_journal_transfer_conformance_test.dart`
  - `test/accounting/restaurant_journal_transfer_safety_test.dart`
  - `docs/reference/durable-transfer-commands.md`
  - `docs/log/2026-11-08-durable-transfer-commands.md`
  - `outputs/completion-review/durable-transfer/`
- Preserved concurrent work: no edits to engine, pins, existing shared host (`journal_command_host.dart`), sales commands, spending commands, mapper, codecs, runtime repository, bootstrap, schema, or UI/Penpot.
- No Git commits, branch creation, staging, push, package edits, or phase status modifications.

## Mandatory preflight

1. Confirmed absence of owned files before creation.
2. Initial disk storage check: 110,521,052 KiB available.
3. Hindsight memory preflight: scoped recall performed separately for `daftar` (`project-daftar`) and `madar` (`project-madar`) per `t3-hindsight-required/SKILL.md`. Verified existing observations, financial policies, and boundaries.
4. Authority and contracts reviewed:
   - Foundation contract: [completion-durable-transfer-contract.md](../phases/completion-durable-transfer-contract.md).
   - Conceptual financial policy: [ADR 0021](../decisions/0021-completion-financial-policy.md).
   - Frozen reference: [model.js](../../electron-reference/app/ui/model.js) `transferRemaining`, `remaining`, `balanceFromRemaining`, `movements`, `cash`.
   - Madar engine contracts consumed at revision `d316fd6076375daa3f412889f73eaebfeeb5d4d4`.
   - Engine status: whole-source engine guard currently fails on separately reviewed uncommitted collation candidate in `../Madar_Engine`; preserved and disclosed, not bypassed.

## Implementation details

Created `lib/accounting/restaurant_journal_transfer_commands.dart` implementing:
1. `DailyToCashboxTransferCommand`:
   - Caller-owned immutable IDs (`operationId`, `transferId`, `journalId`), date, positive integer IQD amount (scale 0), recorded timestamp, lineage, and expected storage fence.
   - Pre-I/O validation: rejects whitespace/empty IDs, non-positive payload version, non-positive or excessive amount.
   - Canonical payload identity: deterministic sorted JSON containing captured fields.
2. `RestaurantJournalTransferOutcome`:
   - Sealed, structured outcome containing `commandType` (`daily_to_cashbox_transfer`), `operationId`, `transferId`, `journalId`, `effectiveDate`, `netAmount`, and detached `metadata`.
   - Redacted `toString()` representation.
   - Symmetric JSON/payload serialization and equivalence.
3. `RestaurantJournalTransferCommandCoordinator`:
   - Connects to `JournalCommandHost` enforcing single-store ownership, lineage checks, pre-I/O fence verification (`missing_authority_fence`), and proposal evaluation.
   - Single-store atomic persistence: updates `state.account['transfers']`, appends `state.journals` entry, and records `state.receipts` in one atomic revision increment.
   - Invariants enforced:
     - Cutover date gate: operations dated before cutover date fail with `pre_cutover_operation_rejected`.
     - Cutover active state: gated cutover fails with `cutover_gated`.
     - Duplicate prevention: rejects duplicate `transferId` in source or `journalId` in journals.
     - Remaining snapshot requirement: rejects dates without recorded remaining snapshot with `missing_remaining_snapshot`.
     - Available remaining check: rejects amounts exceeding available remaining with `excessive_transfer_amount`.
     - Double-entry mapping: debits cashbox asset (`asset:cash:cashbox`), credits daily drawer asset (`asset:cash:daily`), strictly zero expense.
     - Legacy unset-total recovery: if `days[date].balance == null`, recovers `total + available + prior_transferred` and sets `days[date].balance` before applying transfer, preserved thereafter.
     - Preserves already set `days[date].balance` unchanged.
   - Replay reconciliation: validates stored receipt outcome against current source transfer record, journal entry, debit/credit sides, amounts, and metadata before replaying as `DurableCommandReplayed`.

## Verification & test results

Implemented 3 dedicated test suites:
1. `test/accounting/restaurant_journal_transfer_commands_test.dart` (17 unit tests):
   - Valid command construction, canonical payload identity.
   - Validation failure rejections: empty/whitespace IDs, version <= 0, zero/negative amount, excessive amount.
   - Outcome serialization round-trip, equality, hash code, redacted string, invalid JSON rejection.
   - Proposal evaluation rejections: pre-cutover, missing snapshot, excessive amount, duplicate transfer ID, duplicate journal ID.
   - Ordinary transfer (20k from 100k -> 80k remaining, 20k transferred, 20k cashbox movement).
   - Transfer-all (100k from 100k -> 0 remaining, 100k transferred).
   - Legacy unset-total recovery (null balance -> recovered to 125k and preserved).
2. `test/accounting/restaurant_journal_transfer_conformance_test.dart` (10 real-store tests using `PowerSyncLocalDocumentWorkspaceStore`):
   - Atomic persistence: 1 store revision increment for source transfer, journal, and receipt.
   - Store close and reopen from disk preserves all records and allows replay.
   - Idempotent replay returns `DurableCommandReplayed` without revision increment.
   - Tampered command (changed financial amount) on replay rejects with `changed_payload_rejected` without writes.
   - Replaying with changed payload version rejects with `changed_payload_rejected`.
   - Account lineage mismatch checked before replay and rejects without writes.
   - Stale expected storage fence rejects with `stale_authority_fence`.
   - Rejection paths leave store revision and payload completely unchanged.
   - Lost acknowledgement recovery via `resolvePendingWrite()`.
   - Mixed history: transfer -> sale -> expense -> return -> transfer2 preserves all invariants; replaying earlier transfer against evolved store succeeds.
3. `test/accounting/restaurant_journal_transfer_safety_test.dart` (6 safety tests):
   - Parity against frozen JavaScript `model.js`:
     - Scenario 1 (ordinary): remaining 80,000, transferred 20,000, balance 100,000, cash 20,000.
     - Scenario 2 (transfer-all): remaining 0, transferred 100,000, balance 100,000, cash 100,000.
     - Scenario 3 (legacy unset total): remaining 70,000, transferred 35,000, balance 125,000, cash 35,000.
     - Scenario 4 (subsequent dated effects): remaining 60,000, transferred 35,000, balance 100,000, cash 35,000, dailySpent 25,000, salesTotal 0.
   - Multi-date isolation: date A transfers do not leak into date B available remaining.
   - Exact boundary: minimal 1 IQD succeeds; available + 1 IQD rejects with `excessive_transfer_amount`.

Overall test execution:
- 33 transfer tests executed: 33 passed, 0 failed (ran in 3.1s).
- Full accounting test suite: 228 tests executed: 228 passed, 0 failed (ran in 6.2s).
- Flutter analyze: No issues found!

## Performance tracking declaration

Transfer operation performance is declared **pending** with declared fixture identity (`t-conf-1`, `t-replay-1`, `t-sc1`–`t-sc4`). No invented N/A or unrelated timings are substituted; full campaign remains separate until parent authorizes reviewed measurement stages.

## Storage closeout

- Before: 110,521,052 KiB available.
- After: measured at closeout.
- No dangling temporary files or test stores retained; all `PowerSyncLocalDocumentWorkspaceStore` instances closed and test temp directories removed in `tearDown`.
