# Isolated durable sales commands

Status: candidate repaired after review; independent recheck pending. These APIs do not activate the version 12 envelope in the running app. They are not permission to migrate real accounts or select opening values/date. The accepted business policy is [ADR 0021](../decisions/0021-completion-financial-policy.md); the bounded scope is [the composition contract](../phases/completion-durable-sales-contract.md).

## Ownership and setup

Dakhl_Restaurant owns CompleteSaleCommand, SaleReturnCommand, SaleVoidCommand, their source/journal mapping, PortableJournalState and the lineage-scoped codec wrapper. Madar owns exact arithmetic, immutable BalancedJournal values, DurableCommandCoordinator and the one LocalDocumentWorkspaceStore owner. Consume runtime d316fd6076375daa3f412889f73eaebfeeb5d4d4; no additional package is required.

Initialize an isolated store using the portable codec and verified synthetic opening journal before using this candidate. Normal AccountsRepository/bootstrap still reads schema 11 and has no migration/activation path to these commands. The executor neither creates an account nor chooses cutover data. It delegates read/recovery/CAS/write acknowledgements to Madar and rejects an injected coordinator bound to another store.

Capture accountLineage and StorageFence when forming an intent. The command values allow an omitted fence for pure proposal evaluation; executing one fails with missing_authority_fence before any store read. Do not acquire a fresh fence to retarget an old form after replacement. The codec checks lineage before receipt replay and on every subsequent decode/extract/attach/encode.

## Example using an already initialized synthetic store

```dart
final owner = RestaurantJournalSaleCommandCoordinator(store: fixtureStore);
final command = CompleteSaleCommand(
  operationId: callerOperationId,
  accountLineage: capturedLineage,
  expectedFence: capturedSnapshot.fence,
  saleId: callerSaleId,
  journalId: callerJournalId,
  recordedAt: callerTimestamp,
  draft: {
    'date': '2026-11-07',
    'discount': 0,
    'lines': [
      {'productId': fixtureProductId, 'quantity': 1},
    ],
  },
);
final result = await owner.executeSale(command);
```

The caller owns IDs and time. New intents need new operation identities; retry the same frozen command after an uncertain acknowledgement. Handle DurableCommandSuccess, DurableCommandReplayed and DurableCommandFailure. Success/replay includes the stored outcome and snapshot; failure is not permission to issue a replacement operation ID blindly when acknowledgement is uncertain.

SaleReturnCommand also requires returnId, returnDate, today, reason and ReturnLineRequest values. It reuses cumulative source refund calculations and records the separate refund account on the return date. SaleVoidCommand requires reversalJournalId, reason and voidedAt; it preserves the original posting, creates a linked inverse on the original date and refuses a sale with any return. Both require an eligible reconciled post-cutover source posting. Source-permitted negative cash remains legal.

## Identity, outcomes and limits

Payload version defaults to 1. Identity contains deterministic sorted JSON of the captured command fields, including lineage, expected fence, IDs, time, policy and the exact submitted reason text. It contains private source data and must not be logged. Changing submitted intent or version under an existing operation ID fails changed_payload_rejected. Source reason trimming remains a separate frozen-source behavior.

Drafts and return iterables snapshot once. Payload traversal rejects cycles, nesting at depth 100, unsupported scalar types, malformed Unicode, unsafe integer values and UTF-8 identities above the 20 MiB store limit. Return materialization stops at 200 lines, matching canonical source sales. Finite decimal source quantities keep the existing exact scale-3 validation; IQD values remain integer scale 0. An explicit RestaurantJournalPolicies.allowZero policy supports codec-valid zero outcomes. Ordinary posting profiles cannot adopt the larger opening-balance limits.

Mapper BigInt metadata snapshots use explicit decimal strings in the portable envelope. Returned outcomes detach nested metadata and compare/hash its full canonical content. Their string representation redacts financial details. Matching committed receipt outcomes must reconcile with the saved source and journal before replay. A later valid void does not destroy the earlier sale outcome.

## Failures and evidence limits

| Condition | Result |
| --- | --- |
| Missing captured fence | missing_authority_fence before I/O |
| Replaced generation/fence | stale_authority_fence |
| Wrong account lineage | account_lineage_mismatch before replay |
| Changed payload/version under an existing operation | changed_payload_rejected |
| Gated/incomplete cutover | cutover_gated |
| Business date before cutover | pre_cutover_operation_rejected |
| Historical source lacks an eligible posting | cross_cutover_source_has_no_post_cutover_journal |
| Source/posting receipt, date or amount mismatch | receipt_number_mismatch or sale_posting_mismatch |
| Reversed original / returned sale cannot be voided | already_reversed or void_ineligible_sale_has_returns |
| Malformed receipt/source outcome | structured corrupt_state failure; no new write |
| Read cancellation / pending acknowledgement | Madar structured unavailable/recovery outcome |

Invalid constructor input raises a bounded FormatException; a mismatched injected store owner raises ArgumentError. Proposal validation/mapping failures return their structured rejection codes without committing source/journal changes. Capacity failures retain history and never prune receipts.

The real-store tests cover close/reopen, replay and an acknowledgement lost after a completed durable write. They do not prove every OS crash, WAL/fsync, disk-full or physical-device condition. Global source/ledger reconciliation, expense/purchase posting, live migration/rollback, UI, native acceptance, per-feature measurements, CI and release remain separate obligations. [Repair evidence](../log/2026-11-07-durable-sales-composition.md) records exact input hashes and executed tests.
