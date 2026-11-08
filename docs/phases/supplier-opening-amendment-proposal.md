# Supplier opening amendment policy proposal

Date:2026-11-08. Status: owner-approved on2026-11-08; implementation/verification in progress. Scope: remaining C5-03 supplier opening-debt creation/editing. Current [ADR0021](../decisions/0021-completion-financial-policy.md) says, “No backfill/opening adjustment … follows.” Its accepted history policy also leaves opening counterparts for verification/acceptance. Broad UI/source approval did not choose these accounting semantics.

## Exact proposed policy

1. Keep the original verified cutover opening journal and verification snapshot immutable. A supplier opening revision appends a linked, balanced amendment for the difference between prior and new opening debt. Retain supplier identity, before/after amounts, reason, operation identity, recording timestamp and durable receipt.
2. Make the amendment effective on the already established cutover date. Use the explicitly accepted opening-equity counterpart. The caller must supply/accept that mapping; do not infer a chart default, actual cutover date or account value. The amendment changes supplier liability/opening equity, with no cash movement or paid-spending/expense entry.
3. Recognized supplier capacity becomes the verified original opening plus proven opening amendments plus validated additional debt/purchases less retained settlements. Reject decreases that would underfund any retained settlement date, including future reservations. Missing/mismatched source, journal or receipt evidence fails closed.
4. Commit new-supplier metadata and nonzero opening in one atomic complete-envelope command. Existing supplier opening edits use the same durable contract with reason, exact retry/replay, stale-fence/unknown-write protection and retained history. No source-only metadata bypass or reversal of the aggregate opening.

The two policy selections are the effective cutover date and opening-equity counterpart classification. Approval selects these symbolic semantics, not actual account/date/amount values.

## Implementation and verification after approval

Dakhl owns the atomic commands, amendment proof/history, recognized-liability integration and existing approved supplier forms/ledger. Existing Madar balanced journal/durable coordinator at reviewedf30827d suffice; engine API implementation is N/A for this workflow.

Tests cover increase/decrease/zero, archived/new suppliers, prior/future settlements, atomic creation failure, stale fences, lost acknowledgement/replay/reopen/import, malformed amendment proofs and rejected metadata bypass. Preserve pre-cutover source history and paid-spending/cash totals. Add one isolated native operation benchmark, then focused independent review and recheck.

## Boundaries and alternative

This approves development of the contract and source-approved UI only. Actual verified opening values, live migration/cutover, publication, exact merge revision and release remain separate. If this policy is not selected, keep opening writes disabled and read-only; additional dated debt continues under its existing independently reviewed contract.
