# Approved supplier, material and purchase UI candidate

Date: 2026-11-08. Status: selected C5/C6 implementation with small checks; full tests, benchmarks, independent review and native acceptance deferred under the current build-first instruction.

## Approval and boundaries

Consumed the exact [remaining qualified UI approval](../phases/remaining-ui-owner-approval.md). Viewed selected native supplier, invoice-create and payment-edit references in place. Main payment-create, expanded invoice-cartons and excluded phone frames remain held. No Penpot/browser work, new export, archive or source image copy.

App owns `lib/parties/parties_surface.dart`, `parties_surface_controller.dart` and their two new focused test files. Existing app metadata, portable operations, shared arithmetic and native report capabilities supply the implementation. Madar implementation/API changes: N/A. No engine pin, normal runtime schema activation, opening values/date, production account, app route or release change occurred in this worker task. Root owns `app.dart`; the settings worker owns the new durable invoice-correction command/history and its narrow operations APIs.

## Implemented integration

`PartiesSurface` accepts routeId, saved account, metadata ViewModel, optional portable operations/purchase controller, reviewed comparator, optional invoice-correction override, pending-input callback and navigation callback.

- Supplier selection/profile, metadata create/edit/archive, preserved opening values, shared materials tab, invoice/debt/ledger views and cross-route navigation.
- Material create/edit/archive with independent carton/piece default prices. Default price changes preserve saved invoice names, units and prices.
- Real invoice/payment lists with filtering and pagination, saved totals/paid/remaining amounts and PDF actions through the existing report delivery controller. Chronological ledger and documents fail closed if they require an unavailable comparator; no lexical sorting fallback.
- Selected invoice-create/editor forms with material choice/free names, captured piece quantities/prices, saved carton values retained read-only, supplier/date/number/note and immediate source-funded payment. Expanded carton editing remains excluded. Schema-11 mounting can inspect the form, but its financial save stays disabled.
- Optional portable composition creates invoices/payment atomically through existing commands. Invoice editing now calls the separate worker's `activeInvoicePosting`, `editInvoiceIntent` and `submitInvoiceCorrection`; an override hook remains available. The captured submission includes original source, stable invoice identity, new fields and a user-entered reason. Payment editing uses the existing verified active-history and correction coordinator, with source-compatible reallocation from `PurchaseProposals.payment(editing:true)`.
- Unknown metadata save retains the form and confirms matching source after repository readback. Unknown financial submissions retry the exact command through the operations owner. Dirty dialogs protect dismissal/navigation; definite failure retains input. A separate page readback action can resolve a pre-existing unknown operation. No demo success represents a save.

Root explicitly approved the required `سبب التصحيح` field using existing reason-input/dialog styling for invoice/payment edits, because ADR0021 corrections require nonblank user intent. This differs from the frozen edit screenshots and remains disclosed for later visual acceptance; no default reason or broader correction option was added.

## Exact backend dependency and hook

The original API inspection found no durable invoice edit. This worker initially exposed `SaveInvoiceCorrection(InvoiceEditorSubmission)` and unavailable save; it did not write the pure source proposal. The settings worker then implemented the missing app-owned correction capability under accepted original-date inverse/replacement semantics. UI now consumes that concrete API.

`InvoiceEditorSubmission` captures id, supplierId, number, date, note, reason, immutable PurchaseLine values, optional immediate payment and the immutable original saved source for edits. `PurchaseProposals.invoice(editing:true)` supplies preview input/output only; it is never persisted through the metadata repository. Missing eligible original postings remain fail-closed. No invoice delete UI was added to the selected build scope.

## Actual small checks

- Three widgets passed: supplier creation with zero new opening and retained invoice history; material default-price edit without invoice rewrite; schema-11 invoice editor showing real saved data and disabled financial save.
- One controller smoke passed: portable invoice creation, immutable invoice correction, payment posting and immutable payment correction preserve one invoice/payment source row and produce the expected remaining liability.
- Targeted Dart analysis including root-owned `app.dart` passed. Later small additions include PDF action layout, generic pending readback and archived-supplier creation gating; their final bounded source check is separate from the earlier four scenario passes.
- First widget invocation exposed a real Flutter assertion from CheckboxListTile ink under a decorated panel. Replaced only the filter tile with a bounded checkbox/label row; corrected the test's own fixture write-count assumption from more-than-one to exactly one. Rerun passed all three widgets. Both failures remain recorded rather than called product-data failures.
- Initial analyzer fixes: generic CapabilityFailure<AccountDocument> narrowing and exact-file braces/style corrections. Early source lookup guessed `purchasing.js`; current source is `suppliers.js`. Metadata/input filters were then bound to the source Unicode case contract and accepted date range; archived/current references remain inspectable without enabling new archived selections.

No full suite, native build, benchmark, independent review or production write ran. Compiler handoffs were coordinated with root/settings; small test batches reported roughly 5–8 seconds, bounded analysis roughly 3–8 seconds. Total active effort/tokens/cost are unknown.

## Remaining gates

Positive C3 refunds and main C6 payment creation remain outside the approved UI scope. New financial posting/editing remains unavailable in normal schema-11 runtime until separately authorized portable activation and verified cutover/openings. Actual native report cancellation/denied/printer/retry, complete responsive/visual parity and lifecycle faults need the later verification stage. This candidate does not close whole C5/C6 workflows or phase/release obligations.

## Storage review

Baseline available disk: 96,279,900 KiB; final measured 96,301,740 KiB (21,840 KiB more free). Parties folder 64 to 128 KiB. Shared build directory 2,201,928 to 2,124,220 KiB; Git objects 4,639,260 to 4,640,292 KiB. Concurrent work prevents attributing shared changes to this task. Four new canonical UI/controller/test files total 70,556 bytes. Retain source/tests/log; no task-owned temporary stores, screenshots, archives, exports or duplicate assets exist. Cleanup reclaimed 0 bytes; shared active compiler caches remain for current workers. No low-space or unexplained multi-GiB growth condition occurred.

Parent coordinates phase-journal reconciliation and sanitized project-scoped memory delivery. This log does not claim memory synchronization completion.

Final bounded source check after PDF/readback/archive-selection additions: targeted Dart analysis over both new source/test files and root `app.dart` passed with no issues. The earlier four scenarios remain runtime evidence; root can include the widget file in its next small integration run for the final action-layout additions.
