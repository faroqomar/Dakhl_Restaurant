# Isolated durable daily-to-cashbox transfer commands

Status: candidate created for Completion foundation slice, create-only. Advances the C4-16 foundation and F-07–F-09 evidence; it does not close operational UI or checklist rows. C4 UI and transfer edit/delete (C4-17) remain separate. The accepted conceptual financial policy is [ADR 0021](../decisions/0021-completion-financial-policy.md); the bounded foundation contract is [completion-durable-transfer-contract.md](../phases/completion-durable-transfer-contract.md).

## Ownership and setup

Dakhl_Restaurant owns `DailyToCashboxTransferCommand`, `RestaurantJournalTransferCommandCoordinator`, `RestaurantJournalTransferOutcome`, and their integration through `JournalCommandHost` and `PortableJournalState`. Madar owns exact arithmetic, immutable `BalancedJournal` values, `DurableCommandCoordinator`, and `LocalDocumentWorkspaceStore` (at revision `d316fd6076375daa3f412889f73eaebfeeb5d4d4`).

Initialize an isolated store using the portable codec and verified synthetic opening journal before using this candidate. Normal `AccountsRepository`/bootstrap still reads schema 11 and has no migration/activation path to these commands. The executor neither creates an account nor chooses live cutover data. It delegates read/recovery/CAS/write acknowledgements to Madar and rejects an injected coordinator bound to another store.

Capture `accountLineage` and `StorageFence` when forming an intent. The command requires an expected fence; executing without one fails with `missing_authority_fence` before any store read.

## Example using an already initialized synthetic store

```dart
final coordinator = RestaurantJournalTransferCommandCoordinator(store: fixtureStore);
final command = DailyToCashboxTransferCommand(
  operationId: callerOperationId,
  accountLineage: capturedLineage,
  expectedFence: capturedSnapshot.fence,
  transferId: callerTransferId,
  journalId: callerJournalId,
  date: DateOnly.parse('2026-01-15'),
  amount: BigInt.from(20000),
  recordedAt: callerTimestamp,
);
final result = await coordinator.execute(command);
```

The caller owns IDs and time. New intents need new operation identities; retry the same frozen command after an uncertain acknowledgement. Handle `DurableCommandSuccess`, `DurableCommandReplayed`, and `DurableCommandFailure`. Success/replay includes the stored outcome and snapshot; failure is not permission to issue a replacement operation ID blindly when acknowledgement is uncertain.

## Accounting invariants and business rules

1. **Approved Transfer Double-Entry Mapping**:
   - Debits cashbox asset (`asset:cash:cashbox`) and credits daily cash drawer asset (`asset:cash:daily`).
   - Strictly **no expense is recognized**.
   - One single-store atomic persistence updates the source transfer record in `account.transfers`, creates one balanced journal in `state.journals`, and attaches one durable receipt in `state.receipts` in exactly one revision increment.
2. **Remaining Snapshot Requirement & Availability**:
   - Requires an existing recorded daily remaining snapshot (`days[date].remaining != null`).
   - Available remaining cash is calculated via `DailyCashQueries.day(date).remaining`:
     $$\text{available} = \text{snapshot.amount} - (\text{dailySpent} - \text{snapshot.dailySpent}) - (\text{transferred} - \text{snapshot.transferred}) + (\text{netSales} - \text{snapshot.salesTotal})$$
   - Requires a positive, source-compatible bounded IQD integer amount (`amount > 0`).
   - Transfer of 20,000 from available 100,000 leaves 80,000 available remaining and adds 20,000 to cashbox safe deposits (`movements(clean)`).
   - Transfer-all reaches exactly zero remaining.
   - Excessive transfer (`amount > available`) is rejected with `excessive_transfer_amount`.
   - Zero or negative amounts reject with `zero_or_negative_amount`.
3. **Preserving Saved Overall Balance & Legacy Unset-Total Recovery**:
   - On older/manual days where total balance is unset (`days[date].balance == null`), the total balance is recovered before the transfer is applied:
     $$\text{recoveredBalance} = \text{totalSpent} + \text{available} + \text{priorTransferred}$$
     and saved to `days[date].balance`, matching frozen `model.js transferRemaining` parity.
   - The recovered balance remains preserved after the transfer is added.
   - If `days[date].balance` was already set (`days[date].balance != null`), it is preserved unchanged.
4. **Subsequent Dated Effects Accounted Once**:
   - Subsequent completed sales on the same date increase available remaining by net sales.
   - Subsequent daily expenses on the same date decrease available remaining by daily spent.
   - Subsequent customer refunds on the same date reduce available remaining.
   - Subsequent transfers decrease available remaining by transfer amount and increase cashbox.
   - All effects are accounted exactly once with zero double-counting or drift.
5. **Cross-Cutover & Authority Safeguards**:
   - Operations dated before established cutover date fail with `pre_cutover_operation_rejected`.
   - Gated cutover state fails with `cutover_gated`.
   - Missing expected fence fails before I/O with `missing_authority_fence`.
   - Stale expected fence fails with `stale_authority_fence`.
   - Account lineage mismatch fails with `account_lineage_mismatch` before replay and execution.
   - Duplicate transfer ID in source records fails with `duplicate_transfer_id`.
   - Duplicate journal ID fails with `duplicate_journal_id`.

## Identity, outcomes and limits

Payload version defaults to 1. Identity contains deterministic sorted JSON of captured command fields (`accountLineage`, `amount`, `commandType`, `date`, `expectedFence`, `journalId`, `operationId`, `payloadVersion`, `policy`, `recordedAt`, `transferId`). It contains private source data and must not be logged. Changing submitted intent or version under an existing operation ID fails `changed_payload_rejected` without store writes.

Transfers use integer IQD scale 0. Inputs snapshot deeply with recursive immutability. Recursion depth is capped at 100 levels; cyclical structures are detected and rejected. Integers exceeding JavaScript `maximumSafeAggregate` (`9,007,199,254,740,991`) are rejected.

Returned outcomes detach nested metadata and compare/hash their full canonical content. Their `toString()` representation redacts private financial payloads. Committed receipt outcomes reconcile against saved source transfers and journals before replay.

## Failures and evidence limits

| Condition | Result |
| --- | --- |
| Missing captured fence | `missing_authority_fence` before I/O |
| Replaced generation/fence | `stale_authority_fence` |
| Wrong account lineage | `account_lineage_mismatch` before replay |
| Changed payload/version under an existing operation | `changed_payload_rejected` |
| Gated/incomplete cutover | `cutover_gated` |
| Business date before cutover | `pre_cutover_operation_rejected` |
| Missing remaining snapshot | `missing_remaining_snapshot` |
| Transfer amount exceeds available remaining | `excessive_transfer_amount` |
| Zero or negative transfer amount | Constructor `FormatException`; defensive proposal code `zero_or_negative_amount` |
| Duplicate transfer ID | `duplicate_transfer_id` |
| Duplicate journal ID | `duplicate_journal_id` |
| Malformed receipt/source outcome | structured corrupt state failure; no new write |
| Read cancellation / pending acknowledgement | Madar structured unavailable/recovery outcome |

Invalid constructor inputs raise a bounded `FormatException`; a mismatched injected store owner raises `ArgumentError`. Proposal validation and mapping failures return structured rejection codes without committing source or journal changes.

The real-store conformance tests cover real-store reopen, replay, tampered payloads, changed versions, stale fences, lost acknowledgement recovery via `resolvePendingWrite()`, and mixed history (transfer -> sale -> expense -> refund -> transfer2). They do not prove every OS crash, WAL/fsync, disk-full, or physical-device condition. Live migration, UI, and release remain separate obligations.

## Performance tracking

Transfer operation performance is registered as pending until a reviewed preflight/workflow campaign measures p50/p95, sampled RAM/CPU on declared fixtures. Other feature timings are not transfer performance.


## Reviewed replay repairs (2026-11-08T03:23:13.424755+00:00)

Replay reconstruction uses the supplied mapper and command policy. It compares the complete expected journal entry, policy, lines, provenance and metadata, then the immutable source transfer and outcome. This supports valid custom account profiles and rejects jointly altered receipt/entry metadata or policy.

The successor tests include separate pending-read recovery and a real-store write that commits successfully before its wrapper returns `commit_unknown`. The latter resolves, closes/reopens and proves exactly one source transfer, linked journal and receipt with no revision change on replay. This is bounded lost acknowledgement simulation, not an OS crash proof.

Four differential scenarios consume `outputs/completion-review/durable-transfer/oracle-repaired-1.json`, generated by adjacent `oracle.cjs` from the actual frozen `model.js` under recorded Electron/Node versions. Each compares the full canonical seed and final account as well as cash queries. The other two safety cases cover dated isolation and amount boundaries. Reproduce from the app root with:

```sh
ELECTRON_RUN_AS_NODE=1 electron-reference/node_modules/.bin/electron outputs/completion-review/durable-transfer/oracle.cjs
flutter test test/accounting/restaurant_journal_transfer_safety_test.dart
```

The original `oracle.json` and initial manifest remain historical. Its engine label was literal text, not runtime attestation; the successor fixture records actual `process.versions`, source hash and generator hash. Performance remains pending.
