# Completion nonvisual sales ViewModel contract

Status: bounded implementation contract under the authorized Completion objective. UI design approval and runtime delivery remain separate.

## Ownership and authority

Dakhl_Restaurant owns observable presentation state and composition of its existing ticket workspace controller, account-scoped catalog and industry draft safeguards. Madar_Engine owns shared quote, exact values, stock and workspace contracts. Consume reviewed public packages at runtime pin `d316fd6076375daa3f412889f73eaebfeeb5d4d4`; engine implementation/API/Design N/A unless a concrete missing shared contract is demonstrated. Do not copy shared algorithms.

The current account repository remains schema11. The schema12 journal/sale command candidates are isolated and cannot become the live checkout persistence path in this slice. No financial posting, receipt allocation, migration, cutover selection, account reset, UI changes or new policy follows from this contract.

## Bounded result

Provide a nonvisual sales ViewModel composing the existing TicketWorkspaceController as the sole draft persistence owner. Expose immutable active and held ticket state, load/saving/error/unknown recovery state and safe asynchronous lifecycle notifications for later approved UI binding. Compose existing catalog and Madar quote/stock APIs as needed to represent the ticket; keep presentation choices free of UI widget dependencies.

Delegate load/save/hold/resume/swap/delete/reconcile transitions to the existing workspace controller rather than creating another store or persistence algorithm. Preserve all supported draft fields, first-add price snapshots, business date and order-type snapshot semantics. Do not silently normalize or delete unsupported workspace payloads. Caller identities, account scope and authority fences must remain explicit. Reject overlapping or stale actions and suppress callbacks after disposal or scope replacement. Unknown acknowledgement must retain the protected draft and use existing readback recovery.

This is a foundation for C2-01, C2-03, C2-11, C2-12, C2-15 and C2-18, not completion of their UI or native acceptance criteria. Full checkout, debounced UI wiring, product grid, compact preferences, receipts and financial commits remain downstream. Keep source-only and owner-approval design holds intact.

## Meaningful verification

Use project-local Flutter testing guidance and test observable behavior. Start with retained specification/regression tests at the ViewModel boundary; use exact public controller/contracts and realistic isolated workspace fixtures. Cover fields and captured prices across save/hold/resume/swap/reopen,40-held boundary, failure/unknown readback with no duplicate transition, overlap protection, account/fence replacement and disposed late callbacks. Verify draft operations leave the account document, stock, money and saved sales unchanged. Reuse existing controller/engine tests for unchanged algorithms; do not duplicate their implementation in expected values. Test quote composition through public Madar calculations where included, with invalid source cases and captured-price behavior.

Run focused tests and analyzer, then the affected sales/controller regression suites. Report source-only/native limits, exact inputs and genuine failures. Independent review follows implementation. No formal checklist closure, design approval, engine pin change, commit/push/merge or release is authorized.

## Evidence

Record attempts, measured timings where available and storage baseline/closeout in a dedicated task log and compact manifest. Preserve concurrent source and canonical evidence. Parent owns aggregate tracker updates and independent disposition.
