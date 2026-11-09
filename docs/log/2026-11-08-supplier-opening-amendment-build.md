# Supplier opening amendments: implementation receipt

Date:2026-11-08. Owner-approved contract: [supplier-opening proposal](../phases/supplier-opening-amendment-proposal.md) and [ADR0021 supplement](../decisions/0021-completion-financial-policy.md). Implementation source and focused verification are complete. Independent review, native operation measurement and final paired-candidate adoption remain with the parent campaign.

## Ownership and contract

Dakhl owns the source mapping, supplier form/history, command/proof/controller, capacity rules and portable feature marker. Madar implementation/API changes are N/A for this financial workflow: existing BalancedJournal and durable coordinator suffice. No engine code was copied, and this worker changed no dependency pin, Git state, real account, migration or live cutover. Tests ran against the concurrently prepared, frozen ICU working candidate; this is not a clean-pin/source-checker claim.

`SupplierOpeningController` borrows the existing store. Its API includes explicit acceptedOpeningEquityAccountId, busy/needsReadback/canWrite, capture/submit/retry/acceptSnapshot and readable amendments. Capture accepts supplierId, openingBalance, reason, operationId, recordedAt and bounded supplier metadata changes. New supplier metadata plus nonzero opening commits in one envelope. Metadata-only/zero-opening supplier creation keeps the existing strict metadata path.

Commands preserve the original verified opening journal/hash and verification snapshot, append balanced liability/equity differences on the established cutover date and retain before/after values, reason, operation identity and receipt. The explicitly accepted counterpart must match the mapper's opening-equity account. No opening adjustment creates a cash movement or paid-spending entry. Payment, payment-correction and additional-debt correction capacity now recognize only the original opening plus proven amendments and validated dated debt. Retained future settlements and safe aggregate bounds remain protected. A shared app payment-proof wrapper avoids duplicating posting validation.

The approved supplier form supports a reasoned opening revision and readable before/after history. A local transparent Material fixes the new ExpansionTile's ink ancestor assertion under existing panels. Root's quick-undo observer uses a committed-opening barrier; the form explains that opening balances use documented revisions rather than quick undo. This does not add supplier-deletion/tombstone policy.

## Portable compatibility

Amended envelopes add `requiredFeatures: ["supplierOpeningAmendments-v1"]`. Empty features are omitted, preserving existing canonical envelope bytes. Copy/write/import paths retain the marker. Unknown/duplicate features fail early; stripping the marker from committed amendment data fails. Rejected opaque intents do not activate the feature. The marker changes no schema11 account structure or envelope version number; older strict v12 readers reject the new root field before they can operate on amended balances.

An actual isolated old-reader execution verified that refusal. The reconstructed pre-feature state source SHA256 `ae1a0181e21b5fcb1b110f47c02bc98ab78f37d81a8099ce24f19633d6fefcb0` matches the retained native006 manifest; three pure app forwarding dependencies also match. The exact old reader accepts the baseline and rejects the feature marker with `unsupported_fields`. Evidence: `opening-old-reader-result.json` and `opening-old-reader-probe.log` under `outputs/completion-review/remaining-completion-001/`. One 28 KB canonical old-source/probe fixture remains for reproducibility; its owned temporary location was removed. This is an app compatibility fixture, not an engine fork or a copied full app.

## Verification and retained failures

- `opening-tests-006.log`:16/16 pass, covering immutable base/cash/paid-spending preservation; increase/decrease/zero; atomic new/archived supplier and rejected metadata; future reservations; proven debt capacity; lost acknowledgement/exact replay; peer/stale-fence/source guards; features/reopen/import; missing proof; metadata preservation; safe aggregate overflow; and three form/history/mapping widgets.
- `opening-regressions-001.log`:68/68 pass across existing additional debt, payment corrections, spending commands, portable metadata/integrity and parties UI. Includes root's assembled supplier-opening quick-undo-boundary test.
- `opening-analysis-007.log`: no issues, including root's session, host and app composition files.
- `opening-old-reader-result.json`: actual old-reader baseline acceptance and required-feature rejection pass.

Earlier attempts remain preserved. Test001 failed before any test ran because the shared ICU native asset lacked install-name header padding; no retry occurred before the engine owner froze its repair. Analysis001 found23 style issues, corrected within owned files. Test002 exposed the ListTile/DecoratedBox assertion; test003 passed14cases after the Material fix. Test004 exposed a test-only missing result cast. Test005's two new edge cases expected persisted rejection receipts, but the existing shared contract defaults recordRejection to false; corrected tests now assert zero-write refusal and separately exercise retained rejected receipt compatibility. Safe aggregate and marker fixes remain in source; no failed attempt is relabelled passed.

The parent owns the separately registered opening-write benchmark: fresh real adapter, synthetic accepted equity, capture outside elapsed, submit through durable acknowledgement, exact source/journal/receipt/feature validation and reopen outside elapsed,20samples with p50/p95 and sampled resources. No numeric result is claimed here.

## Composition and remaining boundaries

Root wired reciprocal pending-write guards, snapshot synchronization, lifecycle disposal, dirty-import exclusion and the explicit accepted mapping through session/host/app. Unknown outcomes retain exact intent; retries do not repost. Actual verified opening values, live migration/cutover, physical-device acceptance, exact release signing, publication, merge and release remain separate. The parent should include this compact receipt in its final app memory sync/check; no completed final-memory claim is made by this worker.

Storage checkpoint and cleanup are recorded in `opening-storage-final.json`. Shared concurrent root/engine activity prevents attributing global disk changes to this lane. Retain unique compatibility source/evidence and current uncommitted source. No Git temporary objects or real account files were removed.
