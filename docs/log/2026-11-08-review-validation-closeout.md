# Completion local validation closeout

Date: 2026-11-08. **The authorized local review, fixes/rechecks, tests, native smoke runs, builds and registered-operation measurements are complete within the scopes below. Whole Completion remains gated.** This is an unreleased development candidate, not owner acceptance, publication, merge or live cutover.

## Candidate and ownership

App HEAD remains `cc91fae438101fce7ff4729e12bf3c2b64dacd70` with preserved uncommitted work. Final workflow input fingerprint is `1fc96b07c5f24e75de520bcada106033644520d3142b2dafc2b9da848f9dcf37`; [source identity](../../outputs/completion-review/review-stage-001/final-source-identity.json) records exact deltas and earlier native identities. Version remains unreleased `0.0.0+1`.

Dakhl owns restaurant UI/ViewModels, composition and account safeguards. The app consumes independently reviewed local Madar `f30827df9fe3c4d2ef6d7d31b53bb0125eea82ec`, application dev.6/native adapters dev.2. Shared PDF raster contract/adapter stays in Madar; app page presentation stays here. [Engine receipt](../../../Madar_Engine/docs/log/2026-11-08-pdf-raster-candidate.md). Further engine implementation/API changes are N/A for the consumer validation and packaging fixes. Engine packages match the consumed revision. No app-side engine fork, push, merge, release or real restaurant account mutation occurred.

## Actual verification

All receipts below live in `outputs/completion-review/review-stage-001/`.

| Check | Result | Receipt and scope |
| --- | --- | --- |
| Full Flutter suite | 1,397/1,397 passed; 110 seconds reported | `flutter-test-frozen-successor.log`; recorded snapshot, with later scoped successors below |
| Final whole analysis and format | No issues; 310 files, zero format changes | `analyze-final-successor.log`, `format-final-successor.log` |
| Engine pin/resolution/pure boundaries | Passed | `engine-boundary-final-candidate.log` |
| Frozen Electron reference | 140/140 passed | `reference-tests.log`; reference evidence, not Flutter acceptance |
| Consumer Python scripts | 134/134 passed | `python-final-checks.log` |
| Final benchmark runner contracts | 37/37 passed | `benchmark-runner-final-successor.log`; two stale expectations repaired |
| Review benchmark fixtures | 39/39 passed across 35 cases | `final-three-benchmark-tests.log`; real-adapter/reopen and negative receipt proof |
| Final PDF viewer successor | 1/1 passed | `pdf-viewer-final-successor.log`; braces-only guard change |
| macOS native pilot | Passed | `native-campaign-006/macos-pilot-attempt-001.log`; checkout, route smoke, first-page PNG, fenced import replacement, real bundled ICU |
| iOS Simulator native pilot | Passed; 7 test seconds | `ios-native-attempt-001.log`, `ios-native-context-001/state.json`; mobile ICU absent |
| Android Emulator native pilot | Passed; 9 test seconds | `android-native-driver-001.log`, `android-native-context-001/state.json`; guarded isolated package, PID-bound driver, mobile ICU absent |
| Final normal-entrypoint builds | macOS, iOS Simulator and Android ARM64 debug passed | `normal-builds-final.json`; `lib/main.dart`, no normal app launch or distribution claim |
| Final macOS artifact seal | Deep/strict verification passed after wrapper-only development reseal | `macos-codesign-successor.log`; four ICU file hashes unchanged |
| Registered native profile matrix | 60/60 passed, 1,200 samples, 20 per case | `benchmark-matrix-001.json`; cleanup complete, no diagnostics |

[Financial, lifecycle, UI and plan fixes](../phases/completion-review-stage-matrix.md), [independent benchmark aggregate review](2026-11-08-benchmark-aggregate-review.md) and [independent final campaign review](2026-11-08-final-campaign-evidence-review.md) retain their exact scopes. The last reviewer reconstructed prior bytes and cleared the braces-only viewer change and Python expectation updates. The measured producer/scenarios/registry did not change afterward; preserve the original measurement fingerprint without retiming unrelated presentation style.

Native smoke proves checkout, model route navigation with settled rendering, first-page PDF raster and fenced import replacement. It does not prove each form's usability, OS file-provider/share/print dialogs, previous-copy recovery or process-update retention. macOS foreground activation returned 1, so automated in-process success is not foreground visual acceptance. The macOS006 pilot passed while its separate `native-matrix` ledger stage remains pending; do not call that entire ledger complete. Later target ledgers and final evidence remain separate.

## Implemented gaps and remaining gates

The earlier plan-audit gaps now have source implementations: additional dated debt create/edit/delete/restoration, recognized-liability capacity safeguards, purchase unit analysis/price history, supplier invoice filters and grouped details, dated ledger actions, full-envelope previous-copy recovery/import counts, exact saved-payment navigation and report open entry points. [Stage matrix](../phases/completion-review-stage-matrix.md) maps retained phases 00–11. The old 213-row closure counts remain historical, not a live implementation percentage.

**C5-03 supplier opening-debt writes still need a verified-opening contract/policy.** Zero opening balance at creation and read-only opening information do not satisfy that write requirement. No metadata bypass, inferred opening/counteraccount, live schema11-to12 migration or cutover was enabled. Missing original postings/mappings remain explicit financial safeguards.

Other retained gates are mobile ICU availability/parity; Penpot/native visual qualification; physical-device evidence; actual chooser/share/print acceptance; target-specific update/retention/rollback proofs; remote CI, owner acceptance and distribution/merge/release. Live screen-reader verification remains owner-excluded, not passed. Current local results do not close these gates.

[Benchmark results and 60-row CSV](2026-11-08-native-benchmark-results.md) record p50/p95, sampled RAM/CPU, hardware, source and tooling. The baseline uses macOS profile mode and bounded synthetic workloads; Phase02 accounts use the small ten-record profile. Resource windows include between-sample preparation/verification; command elapsed excludes that work. Three visible order/catalog/cart-to-raster series, ledger rendering, native dialog latency, mobile performance and capacity budgets remain unmeasured. No speedup or budget pass is claimed.

## Failures, artifact identity and storage

Failed attempts remain canonical. Android's initial SQLite hook stalled; a bounded resume obtained the exact 1,849,568-byte sqlite3 3.8.0 asset and matched the installed package hash before cache reuse. The next build passed in 54 seconds. Native harness directory/type/generation mistakes, preflight ordering exceptions, registry expectations and format lint are recorded in the [execution journal](phase-completion-execution.md) and [prevention record](../how-to/repeated-problems.md).

Final normal builds from the frozen successor took 23.673 seconds macOS, 28.596 seconds iOS and 14.256 seconds Android. The macOS incremental build retained an older outer seal after updating two individually valid nested frameworks. Root refreshed only the generated app's ad-hoc outer seal; deep/strict verification passed. This does not fix upstream incremental scheduling or sign a release. [Final artifact hashes](../../outputs/completion-review/review-stage-001/normal-artifact-identities-final.json) include bundle trees, APK and unchanged canonical ICU bytes.

[Storage review](../../outputs/completion-review/review-stage-001/storage-final-review.json): free 87,096,428 → 87,220,520 KiB across cleanup. Root removed one hash-identical task-created APK duplicate, 110,225,675 logical bytes, while retaining the canonical Flutter APK. The stopped hook's partial file had also been removed. Exact physical reclamation is unknown because APFS sharing and concurrent host changes prevent attribution. App Git remained 18,442,132 KiB; no temporary Git object directories. Final build cache was 3,588,036 KiB, outputs 7,509,176 KiB and `.dart_tool` 2,452,700 KiB. Build growth is consistent with three-target artifacts; `.dart_tool` lacks an initial comparable baseline, so no exact growth attribution is made. Both task-booted devices are off; known idle task-owned Gradle workers stopped. Preserve canonical artifacts/caches, unique native-test APK/preflight evidence, inherited Git/design/recovery data and uncommitted source.

## Evidence, tracking and memory delivery

PHASES.md and the paired engine tracker link current evidence without marking formal Completion DONE. Final project-scoped Markdown delivery uses separate app/engine sync and check. Authoritative raw receipts are `memory-check-app-final.json` and `memory-check-engine-final.json` in the evidence root; only empty pending/failed results establish delivery. The earlier milestone receipts do not substitute for these final checks. Raw-session retention and account-data indexing settings remain unchanged.

Time/token/cost data not captured by receipts remains unknown. Avoidable overhead came from late freeze checks, omitted registry expectations, native-fixture assumptions and ledger ordering; network waiting and incremental signing also consumed time. Prioritized automation: one freeze command covering format/analysis/registry tests; a typed, pre-created native fixture helper; a source-bound result record before mutation; a hash-verified bounded native-download cache; and an outer-seal verification step that refuses invalid nested code. Acceptance checks are the retained regressions and failed/successor receipts, not a claim these automations already exist.
