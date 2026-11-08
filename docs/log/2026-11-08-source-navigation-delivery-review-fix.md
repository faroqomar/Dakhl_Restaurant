# Exact payment navigation and saved PDF open actions

Date:2026-11-08. Scope: C4-15 and C8-18 retained-plan integration, resumed after the T3 restart cancelled the original worker. The resumed worker verified no Flutter runner remained before executing the pending checks. Existing source edits survived; no duplicate implementation or source rewrite was needed.

## Delivered source

Daily/cash derived supplier-payment rows validate and forward the exact saved payment ID through `DailyCashSurface.onOpenPayment`. The generic Payments callback remains compatible. `PartiesSurface.initialPaymentId` resolves exactly one saved source, opens its editor/details once, acknowledges the intent, and exposes missing/ambiguous/busy cases visibly. Root owns the fence-bound app navigation composition.

Invoice/payment, saved-sale history and paid-sale receipt actions now expose Open PDF through `openSavedReportPdf` using the same immutable generated report bytes retained for save/share/print retry. Paid receipts also expose share. Native raster stays in Madar; the app owns viewer presentation. No financial command or account write occurs for opening the document.

## Executed checks

Targeted analyzer on the four surfaces and three affected suites: no issues. `flutter test --no-pub test/parties/parties_surface_test.dart test/sales/sales_history_surface_test.dart test/accounting/daily_cash_surface_test.dart`:17/17passed. This includes saved payment identity/once/missing handling, daily/cash ID forwarding, PDF action presence, and retained archived/repeated-material regressions. These widget checks do not establish native raster, system dialogs or physical-device acceptance.

Canonical outputs: `outputs/completion-review/review-stage-001/navigation-analyze-resumed.log` and `navigation-tests-resumed.log`. Source frozen; compiler released to root. No engine source/pin/Git/account changes by this worker. Engine change N/A: existing reviewed raster capability consumed without copying its implementation. Root owns aggregate tracker and separate project-memory delivery.

## Storage

Resume baseline: free93,631,332KiB; Git18,441,904KiB/build2,183,840KiB/outputs7,399,536KiB. This lane created only the compact analyzer/test logs and this receipt, with no retained fixture roots, screenshots, exports or copied builds. Final sample: free93,580,656KiB; Git18,441,904KiB/build2,215,836KiB/outputs7,399,540KiB. Git unchanged, build+31,996KiB and outputs+4KiB from the serialized compiler/log batch; globalfree−50,676KiB. shared directory/global movement cannot be assigned to this lane. Zero cleanup: no obsolete task-owned artifact remains.
