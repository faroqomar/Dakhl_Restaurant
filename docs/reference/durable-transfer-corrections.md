# Isolated durable daily-to-cashbox transfer correction commands (Edit & Delete)

Status: repaired candidate; fresh independent review pending. Completion foundation slice, nonvisual same-date post-cutover transfer edit/delete. Advances the C4-17 foundation and F-07–F-09 evidence; it does not close operational UI or checklist rows. Live UI, schema migrations, and real-account activations remain separate. The accepted conceptual financial policy is [ADR 0021](../decisions/0021-completion-financial-policy.md) 3A; the bounded foundation contract is [completion-durable-transfer-correction-contract.md](../phases/completion-durable-transfer-correction-contract.md).

## Ownership and setup

Dakhl_Restaurant owns:
- `EditDailyTransferCommand`
- `DeleteDailyTransferCommand`
- `RestaurantJournalTransferCorrectionOutcome`
- `RestaurantJournalTransferCorrectionCommandCoordinator`
- `RestaurantJournalTransferHistory`
and their integration through `JournalCommandHost` and `PortableJournalState`.

Madar owns exact arithmetic, immutable `BalancedJournal` values, `DurableCommandCoordinator`, and `LocalDocumentWorkspaceStore` (at revision `d316fd6076375daa3f412889f73eaebfeeb5d4d4`).

Initialize an isolated store using the portable codec and verified synthetic opening journal before using this candidate. Capture `accountLineage` and `StorageFence` when forming an intent. The command requires an expected fence; executing without one fails with `missing_authority_fence` before any store read.

## Examples using an already initialized store

### 1. Edit an Existing Transfer

```dart
final coordinator = RestaurantJournalTransferCorrectionCommandCoordinator(store: fixtureStore);
final editCommand = EditDailyTransferCommand(
  operationId: callerOperationId,
  accountLineage: capturedLineage,
  expectedFence: capturedSnapshot.fence,
  transferId: 't1',
  expectedActiveJournalId: 'j1',
  inverseJournalId: 'j-inv-1',
  replacementJournalId: 'j-repl-1',
  newAmount: BigInt.from(30000),
  reason: 'Adjust transfer amount to 30k',
  recordedAt: callerTimestamp,
);
final result = await coordinator.executeEdit(editCommand);
```

### 2. Delete an Existing Transfer

```dart
final coordinator = RestaurantJournalTransferCorrectionCommandCoordinator(store: fixtureStore);
final deleteCommand = DeleteDailyTransferCommand(
  operationId: callerOperationId,
  accountLineage: capturedLineage,
  expectedFence: capturedSnapshot.fence,
  transferId: 't1',
  expectedActiveJournalId: 'j-repl-1',
  inverseJournalId: 'j-del-inv-1',
  reason: 'Return cash from cashbox to drawer',
  recordedAt: callerTimestamp,
);
final result = await coordinator.executeDelete(deleteCommand);
```

The caller owns IDs, reasons, and timestamps. Handle `DurableCommandSuccess`, `DurableCommandReplayed`, and `DurableCommandFailure`.

## Accounting invariants and business rules

1. **Same-Date Original-Date Reversal and Replacement Mapping**:
   - For **Edit**:
     * Creates an inverse journal (`mapOriginalDateVoid`) reversing the target active journal on the original effective date.
     * Creates a replacement journal (`mapReplacementProposal`) with `correctedFromJournalId` linking to the original journal.
     * Updates source transfer amount in `account.transfers` in place, preserving `id`, `date`, and `createdAt`.
     * Single-store atomic persistence updates the source record, appends both journals, and attaches one durable receipt in exactly one revision increment.
   - For **Delete**:
     * Creates an inverse journal reversing the target active journal on the original effective date.
     * Removes the source transfer from `account.transfers`.
     * Single-store atomic persistence removes the source transfer, appends the inverse journal, and attaches one durable receipt in exactly one revision increment.
2. **Transfer Edit Capacity & Boundary Checks**:
   - Editing an existing transfer releases its previous transferred amount back to available drawer capacity:
     $$\text{maxAllowed} = \text{availableRemaining} + \text{existingTransferAmount}$$
   - Requesting `newAmount > maxAllowed` rejects with `excessive_transfer_amount`.
   - Minimum transfer amount is 1 IQD (positive non-zero integer). Zero or negative amount rejects.
3. **Preserving Saved Overall Balance & Legacy Unset-Total Recovery**:
   - In legacy accounts where `days[date].balance` is null/unset, `EditDailyTransferCommand` calculates and recovers:
     $$\text{recordedBalance} = \text{total} + \text{remaining} + \text{transferred}$$
     Here `total` honors the source manual total override, otherwise daily spending. The remaining snapshot already accounts for sales changes.
     and saves it to `days[date].balance`, matching frozen `model.js transferRemaining` parity.
   - `DeleteDailyTransferCommand` preserves the recovered balance upon removing the transfer, matching exact frozen `renderer.js` confirm-delete handler parity.
4. **Active Target Validation & Double-Reversal Prevention**:
   - Target transfer must exist in `account.transfers` and belong to one complete receipt-backed create/edit history. Unjournaled legacy records remain ineligible.
   - `expectedActiveJournalId` must exist in `state.journals`, must belong to `transferId`, must not have `reversesId != null`, and its `totalUnits` must match the target transfer's recorded amount.
   - If the target journal has already been reversed, delete rejects with `transfer_already_reversed`.
   - Mismatched journal amount or ID rejects with `stale_target_journal`. Full mapper accounts, policy, source classification, timestamps, metadata and prior receipts must reconcile with captured canonical intent; otherwise correction rejects with `tampered_correction_chain`.
5. **Idempotent Historical Replay & Lineage Reconstruction**:
   - Replaying any historical edit or delete command against the store returns `DurableCommandReplayed` without incrementing store revision.
   - Replaying with tampered parameters or changed `payloadVersion` rejects with `changed_payload_rejected`.
   - `RestaurantJournalTransferHistory.validateTransferLineage` requires the current mapper and reconstructs the initial posting and each inverse/replacement from its committed receipt's canonical command intent. It checks complete entry values, exact before/after snapshots, historical outcome amount/date/metadata, receipt sequence, journal encounter order and current source projection. Missing receipts, disconnected transfer-linked branches and changed mapper profiles fail closed.
   - Current proposal evaluation requires receipts for prior committed steps. Its new receipt attaches only after proposal acceptance through Madar's coordinator.
   - Command identity uses the shared app `CommandSnapshot` guards (20 MiB, depth/cycle/scalar/Unicode checks). Submitted reason whitespace remains part of the identity; journal reasons use trimmed text.
   - This is consistency validation, not cryptographic authentication of an attacker rewriting every unanchored historical fact.

## Failures and error codes

| Condition | Error Code |
| --- | --- |
| Missing captured fence | `missing_authority_fence` before I/O |
| Replaced generation/fence | `stale_authority_fence` |
| Wrong account lineage | `account_lineage_mismatch` before replay |
| Changed payload/version under an existing operation | `changed_payload_rejected` |
| Business date before cutover | `pre_cutover_operation_rejected` |
| Target transfer ID not found in source records | `transfer_not_found` |
| Expected active journal not found, mismatched, or amount drifted | `stale_target_journal` |
| Target journal already reversed | `transfer_already_reversed` |
| Missing daily cash remaining snapshot | `missing_remaining_snapshot` |
| New transfer amount exceeds available remaining + existing amount | `excessive_transfer_amount` |
| Zero or negative transfer amount | Constructor `FormatException`; defensive `zero_or_negative_amount` |
| Inverse or replacement journal ID already exists | `duplicate_journal_id` |
| Matching inverse and replacement journal IDs | Constructor `FormatException` |
| Empty reason or whitespace fields | Constructor `FormatException` |
| Oversized / malformed Unicode intent | Constructor `FormatException` (`command_payload_too_large` / `invalid_command_payload`) |
| Corrupt prior transfer history during proposal | `tampered_correction_chain` |
| Corrupt matching receipt or historical outcome during replay | `corrupt_state` before writes |

## Performance tracking

Transfer correction operation performance is declared as PENDING until a reviewed preflight/workflow campaign measures p50/p95 on declared fixtures (`t-sc1`–`t-sc4`, `t-conf-1`). No fabricated timings are claimed.


## Repair verification (2026-11-08)

The original 33 correction tests and 38 create tests remain. An additional 26 integrity tests cover altered target/replacement accounts and policy, missing predecessor receipts, forks, jointly forged provenance, delete amount/date corruption, changed mapper and command policy, submitted-reason identity, payload bounds and malformed Unicode. Two of these tests inject exceptions at the real PowerSync `transaction.before_commit` checkpoint for edit/delete, compare complete payload/revision after rollback and reopen, then retry/replay exactly once. These are deterministic checkpoint exceptions, not process-kill or power-loss evidence.

The successor oracle executes the actual frozen renderer confirm-delete handler body in a synthetic environment with commit/close callbacks, alongside actual model functions. It records model, renderer, extracted handler and generator hashes plus Electron runtime identity. The previous oracle manually mirrored the transfer filter and remains historical; its artifacts are unchanged.

Current result: 297 accounting tests pass with `--no-pub`, targeted analysis reports no issues and architecture boundaries pass. Operation benchmarks, UI/native acceptance and live schema activation remain pending. See [repair log](../log/2026-11-08-durable-transfer-correction-integrity-repair.md) and `outputs/completion-review/durable-transfer-corrections/repaired-1/` for exact evidence.
