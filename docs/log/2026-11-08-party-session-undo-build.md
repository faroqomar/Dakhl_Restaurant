# Party session undo build — 2026-11-08

Status: party successor7/7 focused checks and invoice/payment13/13 regression checks pass; targeted analysis clean. Earlier party/date-cash20-pass receipt remains dated below. Root owns observer integration and overall Completion status.

## Contract and ownership

App-owned restaurant source mapping reuses Madar balanced journals, exact values, durable host/coordinator/store/CAS contracts. Engine changes/revision: N/A. No copied engine algorithms, new financial policy, live migration/cutover, real-account access, Git mutation, publication or release.

`PartiesSessionUndoAdapter(parties:, identity:)` supports original user command types purchase_invoice, edit_purchase_invoice, delete_purchase_invoice, supplier_payment, edit_supplier_payment and delete_supplier_payment. It validates committed original receipt, affected source and active family, previews complete expected current-source compensation, then retains one immutable command across uncertain outcomes. It preserves current unrelated fields and historical journals/receipts. Existing linked liability, funding/allocation, missing-posting and cutover checks remain active.

`RestoreDeletedPartyCommand` / `DeletedPartyRestorationCoordinator` retain source IDs, createdAt, exact source/order, predecessor delete identity/context/fence and original posting policy. A restore appends one new replacement linked to the deleted active posting. The original posting and deletion inverse remain immutable; no inverse-of-inverse. Invoice/payment history validators traverse the validated restore edge and later corrections and support old create/delete replay.

`PartySessionCompensationCommand` / `PartySessionCompensationCoordinator` compensate invoice creation plus its optional immediate payment and inline material source in one host revision with one real parent receipt. Read-only validated child views describe existing payment/invoice correction intents/outcomes/entries. The coordinator validates final family histories and mapper proof; the view validator checks structural/source/identity/revision/entry bindings without recursively calling families. Day-date receipt proof stays separate and child IDs reserve across both parent types. No synthetic child receipts are persisted.

Existing inline-payment roots required a narrow repair: their original receipt is purchase_invoice, not a standalone supplier_payment command. Payment history now binds to that exact parent original invoice/payment snapshot. Historical invoice create validation uses its retained immediate-payment snapshot rather than mutable current payment source, allowing later corrections/deletions without inventing a child receipt or recursive history validation.

Optional SourceRecordOrder on invoice/payment edit restores captured source order in the same candidate; omission preserves prior canonical identities. Sales owns the shared helper's later applyRows addition for spending. Optional SourceMaterialRestoration on invoice edit applies captured inline-material metadata deltas through the existing source-only metadata patch plan. Current unrelated catalogue state survives; reference validation protects used/changed materials. These fields do not alter ordinary edit behavior when omitted.

## Evidence and attempts

First baseline3passed. A fixture twice guessed a stored aggregate invoice field (amount then total); the source stores captured lines instead. Corrected the observer to inspect actual saved line price. No product fix addressed those failed assertions.

Deleted invoice/payment restore cases passed on first execution. Initial aggregate cases refused before writes because a formatted insertion missed the newly declared late-final compensation coordinator assignment. Added the constructor assignment; successor5/5passed. Prevent this by inspecting declarations and constructor assignments after text-based source edits, not assuming a replacement matched. Initial analyzer yielded brace infos only; code-scoped/file-scoped fixes preserved pubspec and dependencies.

`flutter test --no-pub test/parties/parties_session_undo_adapter_test.dart test/accounting/restaurant_journal_invoice_correction_commands_test.dart test/accounting/restaurant_journal_payment_correction_commands_test.dart test/accounting/day_date_cash_composition_test.dart` → 20passed. Includes exact unknown retry, retained restoration IDs/history, subsequent corrections, old replay, one-revision/one-receipt inline invoice+payment+material compensation, no partial source update on uncertain fixture failure and date/cash parent compatibility. Targeted9file analyzer clean at that candidate.

Affected-source/order successor adds two checks for older invoice/payment position restoration, inline material reversal and unrelated current metadata preservation. Broad tests, benchmarks and independent review remain deferred by owner direction. Root will synchronize this compact log with project memory.

## Successor completion and storage

`flutter test --no-pub test/parties/parties_session_undo_adapter_test.dart` → 7/7passed. New cases confirm source ordering for older invoices/payments, edit-added inline-material removal, and preservation of current unrelated archived-product metadata plus a new unrelated material. Existing13invoice/payment correction cases pass at the successor. Targeted7file analysis reports no issues. Root/sales own the SourceRecordOrder helper's nonbreaking applyRows extension; no duplicate implementation was added.

The first successor run passed6/7. Its pure expected compound projection removed the invoice before its payment; canonical source validation refused the resulting orphan-payment intermediate before any write. Corrected projection order to payment then invoice, retaining one final atomic candidate. Successor7/7passed. Final coordinator operation still writes once, not sequential child deletes. Additional integrity binding makes an invoice's current inline-payment family validate through a nonrecursive retained root anchor, so original parent replay does not omit child correction validation.

Adapter source validation now compares affected rows and active lineage, then previews an expected current-source projection patched only for those records/order/material deltas. Current unrelated history and metadata survive older undo entries. The original global account equality check would have rejected unrelated retained archival stock state and was removed for that reason.

Storage: last prior step baseline available96,116,132KiB; final96,057,552KiB, a58,580KiB global delta across concurrent workers, not an exclusive task attribution. .git18,439,356KiB and outputs7,398,508KiB remain unchanged. build2,122,008KiB, lower than prior2,142,684KiB. No tmp_objdir directories observed. New canonical party source modules/helper/adapter/test total88KiB and remain required integration/regression evidence. No owned duplicate exports, scratch backups or obsolete artifacts; reclaimed0bytes. Thresholds not approached.

Compiler released to root's normal metadata two-step widget, then settings sparse/local checks. Full tests/benchmarks/independent review/visual qualification remain deferred. No phase DONE or release claim. Root coordinates sanitized Markdown sync/check; this child does not claim memory delivery complete.
