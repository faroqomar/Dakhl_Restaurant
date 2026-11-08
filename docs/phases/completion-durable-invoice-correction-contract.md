# Isolated durable purchase-invoice corrections

Date: 2026-11-08. Status: build candidate under accepted ADR0021 1A-P/3A/4A and the accepted correction examples. Three focused smoke cases passed; full fault/restart/conformance tests, benchmarks and independent review remain deferred. No live posting activation or release.

Dakhl owns saved invoice projection, source snapshots and correction-family reconciliation. Madar continues to own balanced journals, storage, compare-and-swap and durable receipts. Engine/API/pin changes: N/A. No codec change or copied engine implementation.

## Intent and atomic outcome

`EditPurchaseInvoiceCommand` captures operation/version, account lineage, storage fence, invoice ID, complete expected canonical source/version, expected active journal ID, inverse/replacement IDs, supplier, number, date, captured `PurchaseLine` values, note, reason/recorded timestamp and mapper profile/policy context. `DeletePurchaseInvoiceCommand` captures the same source/authority/inverse context without replacement values. Intent freezes and bounds source/lines through existing app command helpers. Capture a real acknowledged fence before submitting; a missing fence fails closed.

`RestaurantJournalInvoiceCorrectionCoordinator` uses the existing single-store `JournalCommandHost`. It requires a unique, recognized receipt-backed post-cutover invoice family and exact current source/active posting. It reuses `PurchaseProposals.invoice(editing: true)` or `removeInvoice`; no alternate invoice arithmetic or deletion policy is introduced. Original invoice ID/creation timestamp remain stable. Supplier changes, duplicate numbers, invalid quantities/prices, payment date inconsistencies and totals below saved allocations fail existing source validation. Deletion refuses an invoice with payments. No missing-posting exception, historical backfill or opening adjustment is inferred.

Edit appends an inverse effective on the active original posting date, then a replacement purchase-expense/supplier-liability posting on the edited invoice date. Delete appends only the active original-date inverse. The complete source candidate, new journals, before/after snapshots, correction links, reason, outcome and command receipt commit together. Payments remain separate liability settlements; invoice correction creates no paid-spending row or extra cash movement. Inline material behavior follows the existing invoice proposal; removing an invoice does not purge material history.

## History and compatibility

`RestaurantJournalInvoiceHistory` reconstructs the create intent and each edit/delete from committed receipts, compares retained source snapshots and deterministic journal/outcome values, validates a linear single-inverse chain and preserves receipt sequence ordering across storage fences. It rejects extra family entries/receipts and source/posting tampering. Historical replay reads retained intent instead of reallocating old payments against current state. `activePosting(state, id, mapper)` returns a validated current posting or null after deletion/invalid history.

Narrow hooks in `restaurant_journal_spending_commands.dart` preserve original create replay after correction/deletion and recognize a corrected active invoice for subsequent supplier payments. Uncorrected paths retain their existing checks. Root-create verification reuses the existing source/mapper/outcome matcher against the retained original invoice snapshot, so a later valid payment does not force historical source reconstruction against today's paid total.

## Consumer API

`PartiesOperationsViewModel` exposes `activeInvoicePosting`, `editInvoiceIntent`, `deleteInvoiceIntent`, `previewInvoiceCorrection`, `submitInvoiceCorrection` and retry of the original captured uncertain command. `PurchaseOperationsController.editInvoice`/`deleteInvoice` delegate to it. Existing shared-session pending-write exclusion and acknowledged snapshot publication remain in force. `RestaurantJournalInvoiceCorrectionOutcome` provides invoice/inverse/replacement IDs and a frozen JSON outcome.

UI caller example:

```dart
final active = parties.activeInvoicePosting(invoiceId);
if (active == null) {
  // Keep the form and explain that the original posting is unavailable.
  return;
}
final intent = parties.editInvoiceIntent(
  operationId: operationId,
  invoiceId: invoiceId,
  expectedSource: capturedSavedInvoice,
  expectedActiveJournalId: active.journal.id,
  inverseJournalId: inverseId,
  replacementJournalId: replacementId,
  supplierId: supplierId,
  invoiceNumber: number,
  date: date,
  lines: lines,
  note: note,
  reason: userEnteredReason,
  recordedAt: recordedAt,
);
final result = await parties.submitInvoiceCorrection(intent);
// On uncertainty, retain this exact intent and use parties.retry().
```

The selected invoice-edit UI is separately approved; sales_build owns its adapter/form. A user-entered nonblank reason is required. No invented default correction reason is used. Normal schema11 account editing/portable bootstrap activation remains outside this API.

## Errors, limits and evidence

Stable rejection examples: `missing_authority_fence`, `account_lineage_mismatch`, `cutover_gated`, `invoice_context_mismatch`, `invoice_not_found_or_ambiguous`, `invoice_source_changed`, `pre_cutover_operation_rejected`, `invoice_history_mismatch`, `invoice_source_version_changed`, `duplicate_journal_id`, plus existing source proposal/mapper errors and generic `invalid_invoice_correction`. Generic coordinator identity-conflict, stale-authority and unknown-write results remain unchanged. Source intent/journal payloads inherit existing account capacity and 200-line limits. Standard zero-amount policy remains explicit; no negative purchase amount is accepted.

Focused evidence: `test/accounting/restaurant_journal_invoice_correction_commands_test.dart` passed 3 cases covering edit/create replay/corrected payment/repeated edit, deletion and replay after a new ViewModel owner, and changed-source/missing-original refusal. These use the existing in-memory store fixture, not real native/SQLite fault acceptance. Immediate-payment-root variants, restored-fence campaigns, exhaustive tampering/concurrency, native UI acceptance and complete source differential coverage remain pending. No independent approval or row closure follows from these smoke checks.
