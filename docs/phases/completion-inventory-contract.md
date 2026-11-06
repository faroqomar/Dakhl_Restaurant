# Completion inventory command contract

Status: local implementation; independent review, consumer release and remote CI remain pending. Scope: nonvisual Completion C1 commands. Design: N/A for this command layer.

## Ownership and dependencies

Dakhl_Restaurant owns `InventoryCommands`, immutable schema-11 account composition, product forms' source-defined semantics and repository integration. Madar owns `StockEntries`, stock history/query arithmetic and the fenced document storage adapter. The command layer consumes the paired local Madar candidate through the root dependency configuration; the lead records its reviewed revision before delivery. See [engine contract](../../../Madar_Engine/docs/reference/completion-stock-contract.md) and [completion plan](completion-implementation-plan.md).

Source behavior comes from frozen `electron-reference/app/ui/commerce.js` product and stock commands and `electron-reference/app/ui/model.js` validation. No posting, purchase-to-stock conversion, UI or migration policy enters this scope.

## API and usage

Construct `InventoryCommands(repository)` after opening an existing or initialized account. Each method requires the caller's acknowledged `DocumentSnapshot` as `expected` and returns `Future<CapabilityResult<AccountDocument>>`.

- `createProduct(product, expected: snapshot, opening: optionalMovement)` saves the product and optional opening in one document transaction. A supplied opening must be nonzero, positive, tracked, and identify that product. Omit opening when there is no initial quantity.
- `editProduct(product, expected: snapshot)` accepts a complete product record. Stock or sale history locks its existing unit and tracking flag, including voided sale history. Changes to the current price leave saved line snapshots untouched. Untracked products have zero minimum stock.
- `setArchived(productId, archived, expected: snapshot)` changes the flag without deleting history.
- `postMovement(movement, expected: snapshot)` supports opening, restock and signed adjustment entries. Madar plus the account codec validate identity, quantity, product references and chronological availability.
- `reverseMovement(entryId, newId: ..., reason: ..., createdAt: ..., expected: snapshot)` appends a full opposite adjustment on the original effective date. It preserves the original entry, links it once and rejects reversing a reversal. Historical stock must remain valid.

`InventoryMovement` carries explicit ID, product ID, `BigInt quantityUnits` in thousandths, `DateOnly effectiveDate`, `StockEntryKind`, timestamp string and note. Callers supply identity and time; commands do not consult a clock. Record quantities retain the existing maximum of 1,000,000,000 (1,000,000,000,000 thousandths). Dates and timestamps follow the existing codec contract. Serialization converts exact scaled units only at the existing JSON schema boundary; Madar performs arithmetic.

## Failure and recovery

Commands compare expected account fence, revision, write token and payload before any asynchronous work. A stale caller receives `stale_revision`; an uninitialized account receives `not_initialized`. An overlapping call on the same command object receives `busy`. Shared-store compare-and-swap still checks competing controllers and external writers.

Unknown account or workspace publication blocks commands with `commit_unknown`. Reconcile through the existing repository before deciding whether a retry is needed; do not replay blindly. Validation and definite write failures preserve the acknowledged in-memory document and existing durable data. Error messages omit IDs, names and record payloads. Repository/storage failures retain their existing codes. Commands expose `busy` for caller composition, without UI state or notifications.

## Verification and remaining limits

The tests preceded implementation and first failed because the command API did not exist. Seven synthetic command tests cover atomic opening creation, overlap rejection, duplicate preservation, product locks, saved sale price snapshots, archiving, historical negative-stock rejection, full/duplicate reversal, invalid movement boundaries, untracked stock rejection, definite write failure, stale shared-repository authority, unknown acknowledgement and reconciliation. A real temporary PowerSync adapter test closes and reopens fractional opening/reversal records. Test teardown deletes only that temporary fixture directory.

Targeted commands: `flutter test test/inventory/inventory_commands_test.dart` and `dart analyze lib/inventory/inventory_commands.dart test/inventory/inventory_commands_test.dart`. The lead records final suite/CI evidence separately. These tests do not establish device/UI acceptance, throughput, release readiness or merge approval.

No optimization was attempted. Per-operation benchmark campaigns remain part of the aggregate Completion evidence; this contract makes no performance claim. Recovery uses existing repository reconciliation and adapter durability behavior; no new backup/import migration exists here.

Stock reversal reasons use Madar `LegacyText.trimJavaScript`, including BOM as whitespace and preserving NEL, for command normalization and codec nonblank validation. Regression coverage exercises both the command and direct codec boundary. Other historical codec `trim()` call sites retain their earlier Dart behavior; broader Unicode parity is outside this narrow fix and remains a compatibility limitation.

## Integration checkpoint

The [restarted Step3 build record](../log/2026-11-07-completion-step3-restarted-build.md) supersedes earlier pending integration statements with exact current evidence. The app adopts reviewed engine7b1866fb8c9a40345c9d67b455c40053178fcb44. The independently reviewed [nonvisual baseline](completion-benchmarks.md) exercises real isolated storage for the relevant implemented commands; it does not establish UI, installed-device, financial posting or full phase acceptance.
