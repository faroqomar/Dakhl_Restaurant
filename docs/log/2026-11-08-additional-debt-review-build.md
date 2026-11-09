# Additional supplier debt completion build

Date: 2026-11-08. Owner-authorized plan completeness work after independent audit C5-12. This is a consumer restaurant workflow over the unchanged reviewed Madar store/coordinator/journal contracts. Engine implementation change: N/A. No openingBalance changes, account bootstrap, default counteraccount, live cutover or real restaurant data.

## Delivered contract

`AdditionalDebtController` owns `capture`, `submit`, exact `retry`, acknowledged `snapshot`/`account`, `busy`, `needsReadback`, `errorCode`, and `acceptedCounterAccountId`. `capture` accepts create/edit/delete, an operation ID/debt ID, source fields, timestamp and reason; corrections capture the current exact source and validated active posting.

`AdditionalDebtCommand` preserves immutable canonical identity, mapper profile/policy, caller-accepted mapping, source snapshot and active posting expectation. `AdditionalDebtCoordinator` reuses `JournalCommandHost` and Madar durable coordination. A null/empty accepted mapping returns `unmapped_financial_gap` before persisting even a rejection receipt. Missing original receipt/posting, stale source/fence, pre-cutover date, duplicate IDs, overpayment and invalid source projection remain refused.

The history validator reconstructs each committed receipt and exact expected original/inverse/replacement entries, validates family ordering, source terminal state and unowned graph edges. Edits append the inverse at the original date and replacement at the new date; deletes append an inverse. Old receipts remain replayable after edit/delete and reopening.

`RestaurantOperationsSession.additionalDebts` participates in reciprocal pending/busy exclusion, acknowledged reader synchronization and disposal. `PortableRestaurantHost.acceptedDebtCounterAccountId` forwards only explicit caller policy and includes pending debt in transfer exclusion. Root injects the controller into the separately owned Parties UI.

Payment capacity now includes only post-cutover additional debts whose entire source/receipt/active-journal family validates under the active mapper and whose date is no later than the payment. Verified opening capacity and reservations for all recorded post-cutover debt settlements remain. Imported source-only debts grant no liability posting authority.

`AdditionalDebtSessionUndoAdapter` supports create-to-delete and edit-to-edit compensation with source equality checks. Deleted-debt undo explicitly refuses `undo_deleted_debt_requires_restoration`; it never inverts an inverse or erases journals. Root retains this unsupported restoration boundary visibly.

## Verification

`flutter test test/parties/additional_debt_controller_test.dart test/app/restaurant_operations_session_test.dart test/app/portable_restaurant_host_test.dart`: 21 passed (debt6, session6, host9). Debt cases prove complete correction/replay chain, missing mapping with zero writes, imported original-posting refusal, lost acknowledgement exact retry, validated debt settlement/overpayment and deletion protection, plus source-only debt payment refusal. A seventh adapter compensation regression was added afterward for root final aggregate execution; it is prepared, not reported passed here.

Targeted `dart analyze` for three debt sources, debt test, spending commands, session and host: no issues. Scope compiler released to purchase UI owner. Earlier portable controller/surface/host31-case pass and authority refresh fixes are documented in `2026-11-08-portable-recovery-review-fix.md`.

## Attempts and boundaries

Two bounded search attempts named nonexistent old filenames; current source paths corrected them. One scripted test insertion searched pre-format text, failed before writing the test file; a source-directed insertion succeeded. Existing debt API source reached clean analysis before UI worker consumption. New Dart files initially had eight brace lint infos; scoped dart fix resolved them. No shared engine code copied; source allocation, balanced journal arithmetic and durable persistence use existing engine capabilities.

Broad tests, independent recheck, native app behavior and benchmarks belong to root's successor campaign. No phase DONE, release, merge, financial classification or verified opening approval inferred.

## Storage

Final sample: free93,912,864KiB; `.git`18,440,772KiB, `build`2,184,144KiB, `outputs`7,398,996KiB. No Git temporary object directories. Canonical source/tests/log only in this lane; no native builds, exports or duplicate account fixtures. Zero disposable artifact bytes remain. Shared campaign movement is not attributed to this worker; root owns aggregate delta/threshold diagnosis. Root owns final tracker and separate-bank memory delivery.

## Independent recheck P2 and verified successor

The independent recheck found that a legacy source-only debt could mask reducing/deleting a new posted debt below the recognized liability already settled. The codec accepted the total source balance although posted liability became negative. The initial source-codec-only correction guard was insufficient.

The successor checks each affected old/new supplier at every retained post-cutover debt-settlement date. Recognized capacity comprises the verified opening net liability, only validated receipt/source/active-journal debt families, and the proposed mapped replacement. It excludes unposted imported debt. Earlier and future recorded settlements remain reserved; moving a debt after an earlier payment or to another supplier cannot remove that payment's recognized backing. Net liability uses actual journal credit-minus-debit lines rather than source amount.

Known capacity violations return `debt_correction_exceeds_recognized_liability` in a read-only coordinator preflight, before a rejection receipt/write. Existing command identities skip preflight for historical replay. The atomic host proposal repeats the guard against races. Other retained durable-rejection semantics remain unchanged.

`flutter test --no-pub test/parties/additional_debt_controller_test.dart`: 8 passed, including the previously prepared undo adapter regression. The mixed fixture retains imported unposted1000 and new posted1000, pays700 on November8 and200 on November10, then proves zero-write refusal of deletion, reduction below paid capacity, moving beyond the first payment date, supplier transfer and reduction below the future reserved payment. Reducing to900 at the first payment date succeeds. Targeted analysis for debt commands, spending commands and debt test: no issues.

Final scoped storage sample: free94,085,448KiB; Git18,441,260/build2,183,484/outputs7,399,056KiB; no tmp_objdir. Source/test/log only, zero cleanup bytes. Compiler released directly to PDF contract worker as root directed. New source is frozen for independent successor review and root aggregate/native campaign. One formatted-text test insertion failed before writing; source-directed insertion corrected it. No runtime package/pin changes or real-data access.

## Deleted-family restoration successor

Root subsequently authorized completing source undo for deleted additional debt. The earlier explicit deleted-debt undo refusal above is historical and is superseded for retained current-family deletions.

Delete capture now records the original source position and sibling identities in an optional source-order intent (omitted fields preserve prior command identities). Delete execution verifies that captured ordering matches the retained source. Restore capture requires a fully validated deleted family, binds the exact terminal deletion identity, original active posting, original mapping, complete saved source and captured source order. Source-only missing-original debt remains refused.

Restore appends one new mapped liability posting linked to the retained original posting and deletion identity. It never reverses the deletion inverse. The validator reconstructs create/edit/delete/restore families and validates old receipt replay after later restoration and corrections. Subsequent edits/deletes target the restored posting. Restore retains original debt ID, date, amount, note, createdAt and source position. Changed sibling identity or changed terminal deletion refuses instead of restoring an unrelated family. The recognized settlement-capacity guard remains active.

`AdditionalDebtSessionUndoAdapter` now handles delete through this bounded restore command. Unknown restore acknowledgement keeps the exact command and retries by receipt readback with no second write. `flutter test --no-pub test/parties/additional_debt_controller_test.dart`: 9 passed. New scenario proves delete-to-undo, lost acknowledgement/replay with identical write count, exact saved source/order, one appended non-inverse posting, old receipt replay, subsequent edit/delete and replay of all earlier commands. Four-path targeted analysis: no issues. Root's whole analyzer also reports no issues at its separately recorded source boundary.

Compiler released and debt source frozen for fresh independent source recheck plus final aggregate/native campaign. No session/UI/engine change in this restoration slice; root separately reports a newly reviewed raster engine pin, which this worker did not modify. Storage sample is appended to the execution journal after measurement. No generated native/export artifacts or disposable account files created by this slice.

Restoration step storage closeout: 2026-11-08T17:32:48.378632+00:00. Free94,007,036KiB vs prior94,085,448KiB (decrease78,412KiB across concurrent root work); Git18,441,260KiB unchanged/build2,183,512KiB(+28KiB)/outputs7,399,156KiB(+100KiB). Global residual is unattributed, below2GiB. No tmp_objdir; zero cleanup bytes because lane artifacts are canonical source/tests/compact evidence. No generated native artifacts, exports or scratch account files.
