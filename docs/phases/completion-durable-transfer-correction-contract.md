# Isolated durable transfer correction candidate

Status: next bounded implementation slice within authorized Completion scope, after reviewed create-only transfer foundation. Advances C4-17 and bounded F-04/F-07–F-09 evidence; no operational UI or checklist closure. Design: N/A for nonvisual composition.

## Ownership and accepted semantics

Dakhl_Restaurant owns same-date post-cutover transfer edit/delete composition and historical replay reconciliation. Reuse Madar balanced journals, complete-state coordinator and one-store contracts at d316fd6076375daa3f412889f73eaebfeeb5d4d4; new engine implementation/API N/A unless a concrete missing shared capability is shown first. No copied engine implementation. Keep runtime schema11 and isolated schema12 separate; source pin guard stays enforced despite separate uncommitted collation candidate.

ADR0021 3A supplies original-date inverse/replacement semantics. Frozen model.js transferRemaining(editId) and renderer.js transfer-delete handler supply source behavior. No new account/counteraccount or cash sufficiency policy is selected.

## Required behavior

Target one uniquely recognized unreversed post-cutover transfer posting. Capture caller-owned operation/inverse/replacement IDs, expected active journal, lineage/fence, date/time, reason and new amount when applicable in bounded immutable intent. Reject legacy/unposted/cross-cutover or stale targets, duplicate corrections, malformed lineage and changed intent without writes.

Edit preserves source transfer ID/date/original createdAt, removes its old row and appends the updated row as the frozen source does. Require a remaining snapshot and positive bounded new amount no greater than current remaining plus old amount. Preserve saved balance; recover an unset total before changing the source transfer, matching actual source. In one durable commit append the original-date inverse and replacement journal, update the source row and attach one receipt.

Delete removes the active source row and appends its original-date inverse atomically, preserving saved total and remaining snapshot. Do not add a cashbox-sufficiency rule absent from the source. Reasons/provenance belong in app journal metadata without inventing new source fields.

Original journals and receipts remain immutable. New entries carry correction links and exact immutable before/after source snapshots. Make create/edit/delete replay chain-aware: validate original posting/outcome, each correction and current projection. Replaying old commands after later valid corrections returns historical outcomes without restoring old source rows or changing revision. Reject tampered snapshots, missing/cyclic/double correction links or altered policy/metadata. Do not weaken the reviewed create-transfer mapper/profile/policy validation.

## Verification and limits

Meaningful tests precede behavior. Compare20k→30k→delete, repeated edits/delete, snapshots before/after original transfer, intervening sales/refunds/spending and unset-total behavior against actual frozen functions with retained generator/source/runtime identities. Test stale expected target, duplicate/cross-cutover corrections, insufficient remaining, source/journal/history tampering and all historical replays. Real-store precommit rollback and actual-write-success-before-lost-ack/reopen must prove no partial source/journal/receipt state. Reuse genuine earlier fault tools; a read fault is not lost committed-write acknowledgement.

Run affected accounting tests/analysis/boundaries, obtain fresh independent review of both new correction code and the narrow create-replay extension, and retain immutable prior manifests. Transfer operation performance remains a separately tracked pending campaign with exact fixture identity; no unrelated timing is reused.

## Protected scope

No UI/route/Penpot, runtime repository/bootstrap, codec/schema/mapper/shared host, financial opening/date/amount/counteraccount policy, engine source/version/pin, Git mutation or live account changes. No transfer date shift, worker-advance revival or arbitrary legacy correction. Keep source and evidence paths checked before writing; use fresh successor names and preserve old artifacts. Root owns trackers/prevention/audit and final acceptance.
