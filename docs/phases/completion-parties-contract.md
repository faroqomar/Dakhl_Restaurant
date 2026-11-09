# Completion supplier and material metadata contract

Status: implemented nonvisual slice; independent review, UI integration and phase completion remain pending.

## Ownership and source

`lib/parties/parties_view_model.dart` is restaurant composition over `AccountsRepository`, `AccountDocument`, and `LegacyAccountCodec`. Madar owns opaque storage fences and shared arithmetic. This slice adds no engine rule, posting, conversion, migration or UI. Existing reviewed dependency selection is controlled by the linked Completion integration work; this file does not claim revision approval.

Source: `electron-reference/app/ui/model.js` supplier and material normalization, current `lib/accounts/legacy_account_codec.dart` schema 11, and Phase 07 in `PLANS.md`. Supplier names, phone, note and category; material names, units and independent carton/piece default prices follow that codec. IDs are caller supplied and immutable after draft creation. Names/limits/duplicates/references and money bounds are checked by the codec before writes.

## API and use

Create `PartiesViewModel(repository)` after successfully opening an existing account. `suppliers` and `materials` return unmodifiable typed snapshots. `editSupplier(id)` and `editMaterial(id)` return mutable drafts or null for missing IDs. `newSupplier(id: ..., categoryId: ...)` and `newMaterial(id: ...)` require an existing account; attempting to create a draft without it raises a sanitized `StateError`.

Set draft fields, then await `saveSupplier(draft)` or `saveMaterial(draft)`. Results are `CapabilityResult<AccountDocument>`. Archiving uses the draft's `archived` flag; no delete command exists. A successful save requires a fresh draft for the next edit. A definite storage failure leaves the same draft retryable while its account authority remains current.

Supplier opening balance is read-only. A new supplier starts with zero opening balance and an empty legacy material list. Existing opening balances and nested legacy materials are preserved. The command cannot edit debt/payment fields. Material prices are defaults only and do not recalculate saved invoice lines or imply carton conversion. Saved invoices, payments and debt records retain IDs, dates, quantities, prices and allocations.

## Persistence and errors

Each draft captures the immutable account document and storage snapshot. A stale shared-repository draft fails with `conflict`; the underlying storage compare-and-swap rejects independent-writer conflicts. A controller admits one write at a time (`busy`). Unknown account or workspace writes block new catalog writes (`commit_unknown`) pending repository reconciliation. Validation errors expose only codec codes and a sanitized message. Disposal prevents new writes and notifications; an already submitted write can complete and must not be treated as cancelled.

No private payloads are logged. Tests use isolated synthetic fixtures only. Repository codecs validate the complete account before persistence; the command clones only its catalog collection/record and relies on existing record-preserving encoding.

## Verification and limits

Tests were written and run before implementation; initial failure was the missing PartiesViewModel API. Focused tests cover invoice/payment/debt snapshot preservation, archived identities, opening balance preservation, independent defaults, reopen persistence, invalid money and duplicate names, definite failure retry, stale shared authority, in-flight busy exclusion, independent-writer CAS rejection, unknown acknowledgement retry blocking, and disposal during a write. Exact executed totals and analyzer results are recorded in the Completion build evidence.

The fake implements the real Madar port and is exercised through the actual AccountsRepository; it is not native SQLite or device evidence. Durable posting, supplier debt settlement, opening-balance edits, historical document edits, search UI and Penpot integration remain outside this slice. No performance optimization was attempted; operation benchmark coverage is pending the parent Completion campaign. This slice does not satisfy the whole Phase 07 or establish release readiness.

## Integration checkpoint

The [restarted Step3 build record](../log/2026-11-07-completion-step3-restarted-build.md) records the historical integration checkpoint and its engine `7b1866fb8c9a40345c9d67b455c40053178fcb44`. The [current successor closeout](../log/2026-11-08-remaining-completion-closeout.md) and [engine dependency manifest](../../engine-dependency.json) own the later source-bound runtime and validation state. Current delivery consumes `8199a5a`, an import/lockfile-only successor of the runtime qualified at `c028f0466d63b4068b5696af1d0799f243eea6bb`. The independently reviewed [nonvisual baseline](completion-benchmarks.md) exercises real isolated storage for the relevant implemented commands; it does not establish UI, installed-device, financial posting or full phase acceptance.
