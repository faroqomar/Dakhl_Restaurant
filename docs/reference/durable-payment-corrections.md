# Durable standalone supplier-payment corrections

Status: isolated candidate;23new and107affected host tests pass, targeted analysis is clean, independent review pending. Runtime remains schema11. This API does not activate schema12 or open UI routes. [Contract](../phases/completion-durable-payment-correction-contract.md) and [owner-accepted B/F examples](../phases/completion-remaining-correction-approval.md) govern.

## Ownership and setup

Madar supplies exact allocation and balanced journals, coordinator/CAS/receipts and single-store persistence at reviewed ac8b4edc2c915ed22c0991685c33967b3360e7fa. Dakhl_Restaurant supplies source payment projection, captured allocation intent and correction history. No new engine API or dependency is required.

Create `RestaurantJournalPaymentCorrectionCoordinator(store: existingOwner)` against the same initialized store/PortableJournalState as other command families. Injecting a host/coordinator with another owner fails. Capture the current storage fence, complete current source payment map and active journal ID before constructing an edit/delete. A missing authority fence fails before I/O through JournalCommandHost. Capture all eight chart-profile fields and mapper default policy when using custom mapper context.

```dart
final correction = RestaurantJournalPaymentCorrectionCoordinator(store: store);
final edit = EditSupplierPaymentCommand(
  operationId: operationId,
  accountLineage: state.accountLineage,
  expectedFence: snapshot.fence,
  paymentId: paymentId,
  expectedSource: currentPayment,
  expectedActiveJournalId: activeJournalId,
  inverseJournalId: inverseId,
  replacementJournalId: replacementId,
  supplierId: supplierId,
  invoiceId: invoiceId,
  categoryId: categoryId,
  date: effectiveDate,
  amount: BigInt.from(18000),
  invoiceAmount: BigInt.from(12500),
  debtAmount: BigInt.from(5500),
  fundingSource: FundingSource.shared,
  dailyAmount: BigInt.from(13000),
  cashAmount: BigInt.from(5000),
  note: note,
  reason: reason,
  recordedAt: recordedAt,
);
final result = await correction.execute(edit);
```

The caller supplies opaque unique operation/journal IDs and exact synthetic/validated values. The example variables come from the captured account state and the caller's form; it is not a complete application program. For delete use `DeleteSupplierPaymentCommand` with the same captured source/active posting, a fresh inverse ID, reason and recording timestamp; omit replacement fields.

## Behavior and reconciliation

An edit first validates the original standalone root and its linear correction history. It validates recognized invoice/opening capacity through the established pure create-payment evaluator against other payments, then applies `PurchaseProposals.payment(editing: true)` and checks the resulting invoice/debt amounts against captured intent. Saved future payments reserve capacity. The temporary eligibility proposal is never persisted. Source ID/createdAt survive; category/note/date/funding follow frozen supplier edit behavior.

One host commit contains source replacement/removal, an inverse on the old effective date, a replacement posting where applicable, exact before/after snapshots, immutable links and one receipt. Payment debits supplier liability and credits its daily/cashbox shares; it does not recognize a second purchase expense. Delete increases eligible source invoice/debt availability and restores paid cash effects while retaining original journals/receipts. The complete source candidate must remain valid; there is no blanket ban merely because later payments exist.

`RestaurantJournalPaymentHistory.validate` reconstructs standalone creation from its canonical receipt and retained source snapshot, then checks each correction intent, mapper/policy context, source version, journal value and outcome. It checks the current terminal row or its absence after deletion. Receipt sequence orders operations across restored storage fences; the portable model validates revisions within each fence. Old create/edit/delete operations replay historical outcomes after later corrections without rewriting them or recalculating old allocations from current state. Existing standalone create canonical payloads are unchanged.

## Failures and limits

| Code or condition | Result |
| --- | --- |
| `missing_authority_fence`, `stale_authority_fence` | Reject absent/stale captured authority; no proposal write. |
| `account_lineage_mismatch` | Reject foreign account state, including replay. |
| `payment_source_changed` | Captured full source differs from current source. |
| `payment_history_mismatch` | Missing, reversed, ambiguous, forged or unsupported root/history. Invoice-immediate roots remain unsupported. |
| `payment_allocation_intent_mismatch` | Valid source allocator disagrees with caller's captured invoice/debt split. |
| `pre_cutover_operation_rejected`, `cutover_gated` | Reject unavailable posting basis; section E remains blocked. |
| Existing payment eligibility errors | Reject foreign/missing/reversed invoice, uncovered opening liability, excess amount or invalid source proposal. |
| `changed_payload_rejected` | Same operation ID with changed captured intent/version; no write. |
| Invalid current family replay data | The scoped codec fails closed before engine receipt lookup. |

Inputs and snapshots use the existing bounded immutable command helper: JSON-safe exact integers, Unicode validation, cycle/depth checks and20MiB payload capacity. Financial metadata uses decimal strings. Outcome strings redact details. No diagnostics include source payloads/reasons.

Only standalone roots created through `CreateSupplierPaymentCommand` are supported. Invoice-immediate-payment roots need parent invoice replay integration and remain blocked. Invoice corrections, generic undo/range date shifts, imported missing-posting corrections, UI, live cutover and migration are separate work. Actual operation benchmarks remain pending; test duration is not a performance baseline.
