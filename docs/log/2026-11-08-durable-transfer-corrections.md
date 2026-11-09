# Durable daily-to-cashbox transfer corrections (Edit & Delete) task log

Recorded UTC: 2026-11-08T04:15:00.000000+00:00 (Local: 2026-11-08T07:15:00+03:00).
Status: implementation complete; candidate independent review pending. Advances C4-17 foundation and F-07–F-09 evidence; does not close operational UI or checklist rows.

## Role and exclusive boundaries

- Implementation sub-agent for Dakhl_Restaurant.
- Exclusive ownership:
  - `lib/accounting/restaurant_journal_transfer_correction_commands.dart`
  - `lib/accounting/restaurant_journal_transfer_history.dart`
  - `test/accounting/restaurant_journal_transfer_correction_commands_test.dart`
  - `test/accounting/restaurant_journal_transfer_correction_safety_test.dart`
  - `test/accounting/restaurant_journal_transfer_correction_conformance_test.dart`
  - `docs/reference/durable-transfer-corrections.md`
  - `docs/log/2026-11-08-durable-transfer-corrections.md`
  - `outputs/completion-review/durable-transfer-corrections/`
- Narrow extension:
  - `lib/accounting/restaurant_journal_transfer_commands.dart`: extended `_replayMatchesSource` to validate linear correction lineage using `RestaurantJournalTransferHistory.validateTransferLineage` when transfers have subsequent corrections.
- Preserved concurrent work:
  - No edits to engine pin, `journal_command_host.dart`, mapper, codecs, runtime repository, bootstrap, schema, or UI/Penpot.
  - App pubspec.lock, package config, and engine pin remain UNCHANGED.
  - No Git commits, branch creation, staging, push, or phase status modifications.

## Mandatory preflight

1. Preflight check: verified absence of target files before creation.
2. Initial disk storage check: 110,151,156 KiB available (closeout: 109,808,172 KiB available).
3. Hindsight memory preflight: scoped recall performed separately for `daftar` (`project-daftar`) and `madar` (`project-madar`).
4. Authority and contracts reviewed:
   - Foundation contract: `docs/phases/completion-durable-transfer-correction-contract.md`.
   - Conceptual financial policy: `docs/decisions/0021-completion-financial-policy.md` 3A.
   - Frozen reference: `electron-reference/app/ui/model.js` `transferRemaining(editId)` and `renderer.js` confirm-delete handler.
   - Existing create-only transfer baseline: 38 focused tests / 233 root accounting tests preserved.
   - Madar engine consumed at revision `d316fd6076375daa3f412889f73eaebfeeb5d4d4`.

## Implementation details

1. Created `lib/accounting/restaurant_journal_transfer_history.dart`:
   - Dedicated helper providing `RestaurantJournalTransferHistory.validateTransferLineage(...)`.
   - Validates linear chain continuity across create -> edit* -> delete events.
   - Verifies target journal amounts, effective dates, timestamps, inverse entries, replacement entries, and projection against source records.
   - Canonical metadata serialization and identity hashing (`canonicalIdentity`, `freezeMetadata`).

2. Created `lib/accounting/restaurant_journal_transfer_correction_commands.dart`:
   - `EditDailyTransferCommand`:
     * Validates operationId, transferId, expectedActiveJournalId, inverseJournalId, replacementJournalId, positive newAmount, reason, and recordedAt.
     * Evaluates edit proposal against current state:
       - Checks cutoverDate gate (rejects pre-cutover operations).
       - Validates expectedActiveJournalId (must match transferId, totalUnits, reversesId == null).
       - Enforces available remaining capacity: $\text{maxAllowed} = \text{available} + \text{oldAmount}$.
       - Performs legacy unset-total recovery if `days[date].balance == null`, saving `recordedBalance = remaining + transferred + dailySpent - salesTotal`.
       - Updates source transfer amount in `account.transfers`.
       - Maps inverse proposal via `mapper.mapOriginalDateVoid` and replacement proposal via `mapper.mapReplacementProposal`.
       - Atomically commits updated source record, inverse journal, replacement journal, and receipt in 1 revision increment.
   - `DeleteDailyTransferCommand`:
     * Validates operationId, transferId, expectedActiveJournalId, inverseJournalId, non-empty reason, and recordedAt.
     * Evaluates delete proposal against current state:
       - Checks cutoverDate gate.
       - Validates expectedActiveJournalId and prevents double-reversals.
       - Preserves recovered `days[date].balance`.
       - Removes transfer from `account.transfers`.
       - Maps inverse proposal via `mapper.mapOriginalDateVoid`.
       - Atomically commits source deletion, inverse journal, and receipt in 1 revision increment.
   - `RestaurantJournalTransferCorrectionOutcome`:
     * Structured outcome containing `commandType` (`edit_daily_transfer` or `delete_daily_transfer`), `operationId`, `transferId`, `targetJournalId`, `inverseJournalId`, optional `replacementJournalId`, `effectiveDate`, `netAmount`, and `metadata`.
     * Full round-trip JSON serialization and equivalence.
   - `RestaurantJournalTransferCorrectionCommandCoordinator`:
     * Integrates with `JournalCommandHost` for single-store atomic persistence and idempotent replay.
     * Replay reconciliation validates source records and journal entries against the linear correction history.

3. Narrow extension to `lib/accounting/restaurant_journal_transfer_commands.dart`:
   - Extended `_replayMatchesSource` so that replaying an initial create transfer command after subsequent edits or deletes verifies the complete chain using `RestaurantJournalTransferHistory.validateTransferLineage` rather than expecting the initial journal to remain active.

## Verification & test results

All tests executed with `--no-pub`:
1. `test/accounting/restaurant_journal_transfer_correction_commands_test.dart` (16 unit tests): PASSED.
2. `test/accounting/restaurant_journal_transfer_correction_safety_test.dart` (6 differential parity & safety tests): PASSED.
   - Scenario 1: 20k -> 30k -> delete differential parity against frozen `model.js` and `renderer.js`.
   - Scenario 2: Repeated edits (20k -> 40k -> 25k -> 50k) parity and historical replay.
   - Scenario 3: Legacy unset-total recovery and delete balance preservation parity.
   - Scenario 4: Intervening sales, refunds, expenses between create, edit, delete.
   - Multi-date isolation: edits and deletes on Date A do not affect Date B.
   - Exact boundaries: edit of available + oldAmount succeeds, available + oldAmount + 1 rejects.
3. `test/accounting/restaurant_journal_transfer_correction_conformance_test.dart` (11 real-store conformance tests): PASSED.
   - Real-store atomic single-revision persistence for edit and delete.
   - Custom mapper profile support.
   - Real-store close and reopen from disk preserving full state.
   - Idempotent replay returning `DurableCommandReplayed` without revision increment.
   - Tampered commands and changed payload version rejection.
   - Lineage and storage fence enforcement with zero writes.
   - Real-store precommit rollback.
   - Real-store lost committed write acknowledgement recovery via `resolvePendingWrite`.
   - Read fault uncertainty resolution.
4. Total accounting suite: 271/271 tests PASSED (233 baseline + 38 transfer + 33 new correction tests).
5. Static analysis: `flutter analyze` passed with 0 issues.
6. Timing status: declared PENDING with declared fixture IDs `t-sc1` through `t-sc4`, `t-conf-1`.
