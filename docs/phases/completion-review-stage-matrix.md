# Completion implementation and acceptance matrix

Date: 2026-11-08. The owner authorized implementation, independent review, fixes/rechecks, native tests, benchmarks and evidence updates across the retained Completion plan. The current source implements the previously identified workflow gaps, including supplier-opening amendments and sales catalog counts. **Whole Completion remains gated; no phase DONE, live cutover, merge or release follows.**

Current evidence root: `outputs/completion-review/remaining-completion-001/`. [Successor closeout](../log/2026-11-08-remaining-completion-closeout.md) records exact source, receipts and remaining checks. [Earlier local validation](../log/2026-11-08-review-validation-closeout.md) remains dated evidence for its older source and measurements.

| Retained scope | Current implementation | Verified scope and remaining gate |
| --- | --- | --- |
| 00–02 baseline, shell, accounts/workspace | Foundations, complete-envelope host/recovery, dirty-input and unknown-write guards implemented | Three-target synthetic native replacement passes. macOS baseline normal quit/relaunch retains acknowledged bytes and active/held drafts. Target-specific update/rollback, physical and delivery proofs remain separate. |
| 03 catalog/stock | CRUD/photos/archive, dated stock/reversal/history and saved sale/return links implemented | Existing focused checks and native route smoke retained. New visible catalog fixture passes; current macOS measurements pass. |
| 04 sales/workspace | Durable checkout, draft/held lifecycle, source-defined full-catalog group counts and untracked in-cart quantities implemented | New counts use an immutable readonly ViewModel projection and pass 32 sales/visible checks. Checkout passes the current three-target native scenario. Visible order/cart measurements pass within recorded workloads. |
| 05 history/refund/void | Commands, receipts, previews, saved snapshots and replay implemented | Bundled en-US/ar runtime now passes 1,506 comparisons and 20 edge checks on macOS ARM64, iOS ARM64 Simulator and Android ARM64 Emulator. This closes the earlier mobile-runtime absence for those exact targets; visual/physical qualification remains separate. |
| 06 categories/daily/cash | Expense/register/chicken/date/cash/transfer workflows, exact payment navigation and history-safe undo implemented | Financial invariants and focused/reconciliation checks retained. Explicit counterpart mappings, missing original postings and actual live values remain safeguarded. |
| 07 suppliers/materials/debt | Metadata, dated ledger actions, additional debt/correction/restoration/undo and approved opening amendments implemented | Opening contract passes 16 new and 68 affected checks, including the committed-opening quick-undo barrier; independent financial recheck reported clear. Isolated opening-write measurement passes. Actual openings/cutover remain unselected. |
| 08 purchases/payments | Supplier filters, grouped saved line details, unit-specific summaries/price history and durable invoice/payment workflows implemented | Prior completeness findings have source implementations and affected checks. Form usability and platform dialog qualification retain their own scope. |
| 09 settings/files | Full-envelope export/import, source-record counts, previous-copy recovery, authority reopen and dirty/unknown guards implemented | Actual macOS baseline save/cancel/retry/import/recovery checks retain exact-byte receipts. Cross-target provider, update and rollback proofs remain distinct. |
| 10 statements/reports | Seven composers, exact-byte save/share/print, explicit open entry points and reviewed raster/page viewer implemented | Current three-target first-page PNG checks pass. macOS baseline native Save and print-to-PDF pass. The current candidate exposed the native share picker; root cancelled without transmission. No physical-printer delivery claim. |
| 11 acceptance/delivery | Source review, fixes, broad tests, native conformance and registered benchmark fixtures executed | Current full Flutter suite passes 1,432 checks; analysis/format/boundaries pass. 65operation measurements, final normal builds, storage receipts and independent aggregate review are recorded in the successor closeout. Visual/physical/current CI/signing/owner delivery/merge/release gates remain open. |

## Ownership and activation boundary

Dakhl owns restaurant UI/ViewModels, workflow composition, app financial mapping/history proofs and account safeguards. The app consumes reviewed local Madar `c028f0466d63b4068b5696af1d0799f243eea6bb`: application dev.6, native adapters dev.3 and optional ICU dev.2. Shared durable storage, balanced journals, PDF capability/native adapters and ICU remain in Madar; no engine implementation or conformance corpus was copied into this app. Further engine implementation is N/A for this evidence reconciliation.

Normal `lib/main.dart` still opens the existing account composition. Durable financial workflows run through an explicitly initialized complete-envelope host. The approved opening policy selects symbolic amendment semantics, not actual restaurant values, a live migration or activation date. This normal-entrypoint financial activation remains a retained gate, not an implemented live rollout.

## Current verification

The source-bound native campaign uses app HEAD `cc91fae438101fce7ff4729e12bf3c2b64dacd70` plus its recorded dirty-source input manifest, runtime `c028f046…eea6bb` and reviewed development tool `f7f68988561d25cc93eb28c0ec989847526b2df9`. The common native input fingerprint is `315cc233069f51c3dee7c6b6c2731fca615de1089d2d5eb1e7fe03135a72a1e6`; a HEAD alone does not identify this candidate.

- `flutter-tests-final-001.log`: 1,432/1,432 pass in 2m18s. `analysis-final-002.log`: no issues. `format-final-002.log`: 321 files, zero changes. `engine-check-final.log`: pin/resolution and source boundaries pass.
- `reference-tests.log`: 140/140 pass; `script-tests.log`: 134/134 pass; `profile-cache-retry-green.log`:44/44pass.
- `benchmark-integration-flutter-001.log`: 49 review/visible fixture checks pass. `sales-catalog-parity-green-001.log`: 32 sales/model/session/visible checks pass. These are correctness tests, not feature timings.
- `native-campaign-002/macos-pilot-attempt-001.log` and `ios-native-context-001/ios-pilot-attempt-001.log`: both combined native tests pass on each target. Android's guarded isolated-package `native-driver-001.log` preserves the merged corpus and operations result. Each target requires 1,506 comparisons, 20 edge checks, two distinct profiles, checkout, 12 routes, PDF raster and fenced replacement.
- All four stages in `native-campaign-002/state.json` pass; target-specific iOS and Android ledgers retain their own guards, failures and successful results. macOS foreground activation still reports a failure, so in-process native success does not prove foreground visual acceptance.

## Benchmark and delivery boundaries

The registry now contains 65 ready cases, including four visible workflows and `review.suppliers.opening_write`. Independent successor source review reported no findings. Ready means implemented fixture/producer source. Current `benchmark-matrix-004.json` passes65operations ×20samples =1,300samples. CSV/aggregate receipts preserve p50/p95, RAM/CPU and exact workload/source identities; independent aggregate review is clear. The engine separately measures its current public ICU API in50release-AOT batches (1millioncomparisons); see the successor closeout for scope and values.

The earlier 60-case/1,200-sample macOS matrix remains historical at its recorded source. It does not measure the new visible or opening cases. Visible timing excludes typing/input dispatch and checkout confirmation; broad RAM/CPU windows include setup/verification between samples. No speedup, capacity budget, mobile performance or OS-dialog latency follows from fixture tests.

The historical 213-row ledger and its 33-closed snapshot are dated evidence, not current implementation coverage. Source implementation, automated correctness, native execution, per-form visual qualification, policy approval and release acceptance remain separate. Physical-phone checks are unavailable per owner, not passed or waived. Live screen-reader verification remains owner-excluded, not passed.

The successor closeout links final normal-entrypoint artifact inspection, observed/cancelled macOS share picker, synthetic update/bounded rollback, storage cleanup and separate app/engine memory-delivery receipts. These local checks are complete within their recorded scope. Current remote CI, owner delivery/merge and distribution/signing gates remain explicit.
