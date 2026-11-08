# Portable recovery and authority refresh review fixes

Date: 2026-11-08. Scope: approved source-reference portable data UI and reviewer P2 authority-refresh defect. Engine changes: N/A; this consumer uses the existing reviewed `readPrevious` / `recoverPrevious` / pending-write contracts at the unchanged runtime pin. No legacy projection writes, cutover, Git mutation or real-account access.

## Implemented

- The portable data surface can inspect the store-owned previous copy, validate the complete Version 12 envelope and display a confirmation candidate. Selection retains the engine opaque previous identity. Cancel does not write.
- Explicit confirmation preserves original plaintext source bytes, validates current authority (or permits the engine's known corrupt-primary recovery route), and delegates recovery to the existing engine store. The engine verifies the selected copy and publishes fresh authority. Unsupported/future or legacy payloads remain refused.
- Recovery retains complete account/journals/receipts/lineage/cutover. Lost publication acknowledgement uses the existing exact token/payload readback gate and does not republish on retry.
- Import/recovery previews include version and counts for days, categories, products, stock, sales/returns, suppliers/materials/invoices/payments/debts, cash/transfers and retired worker/advance records.
- Successful reload of a changed acknowledged snapshot invokes the existing host authority callback. The host recreates the operational session using that snapshot, fixing stale sales/reports after an external same-generation revision or generation replacement. Busy/unknown/dirty-settings guards remain active. Unchanged reload does not recreate the session.
- A replacement acknowledgement must carry a fresh fence as well as the expected token and payload; an inconsistent acknowledgement remains uncertain.

## Verification

`flutter test test/accounts/portable_account_transfer_controller_test.dart test/accounts/portable_accounts_surface_test.dart test/app/portable_restaurant_host_test.dart`: 31 passed. Includes complete-envelope previous recovery/fresh authority, legacy refusal, dirty blocking, exact unknown-publication readback, no-write preview/cancel, import counts and two assembled reload regressions (same fence/new revision and fresh fence). Existing import/export, 320px/200% text-scale and lifecycle cases also passed.

Targeted `dart analyze` for the transfer controller and accounts surface, plus all three test files: no issues. The change also includes `portable_restaurant_host.dart`; this sentence does not claim that host was in that original scoped analyzer invocation. The later [successor closeout](../log/2026-11-08-remaining-completion-closeout.md) records whole-project analysis and affected rechecks. The last two source-only safety refinements (fresh-fence acknowledgement and avoiding unchanged reload recreation) landed after the scoped test run and are assigned to the root final aggregate recheck. No native/device/release claim.

## Storage and execution

Read-only storage closeout sample: free 93,186,556 KiB; `.git` 18,440,428 KiB; `build` 2,214,048 KiB; `outputs` 7,398,896 KiB. Earlier parent baseline free 96,829,424 KiB, Git 18,440,260 KiB/build 2,181,600 KiB/outputs 7,398,572 KiB. Shared concurrent campaign activity prevents attributing global movement to this lane; root owns threshold diagnosis. No exported/build copies or scratch account artifacts created by this worker; source/tests and this compact evidence are canonical. Zero cleanup bytes. The temporary rules-read file contained public project rules only and was removed.

Scoped compiler window completed and released to root for financial fixes. Total wall time/cost unknown. One initial search named a nonexistent legacy repository path; corrected using current AccountsRepository source. Native package API/implementation unchanged. Root owns aggregate trackers, independent recheck and separate-bank memory delivery.
