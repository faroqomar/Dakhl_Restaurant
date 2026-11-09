# C1 nine-case macOS profile API baseline

2026-11-08T07:05:37.023810+00:00 — Root granted the serialized compiler/CPU window after the iOS QA worker released it. All nine cases completed once with 50 accepted latency samples each. Ten workflow stages passed and the campaign is ready for independent review. Numeric performance-budget acceptance remains pending.

## Ownership and identity

Dakhl_Restaurant composes actual CatalogViewModel/query/product-photo operations against isolated real storage. Madar provides the consumed domain/storage rules, reviewed process sampler and immutable workflow ledger. Madar implementation/API changes are N/A. Runtime remains `bb00ccdad8f6710ca1778260d42ed5584f26a86c`; workflow pin is `f7f68988561d25cc93eb28c0ec989847526b2df9`. App HEAD is `cc91fae438101fce7ff4729e12bf3c2b64dacd70` and sourceDirty=true. The 326-input plan and final hash readback match. Two pre-existing QA fixture/test changes distinguish this broad plan from the earlier n=1 pilot; benchmark business/producer/registry sources are unchanged.

The runner reused its exact source/SDK/toolchain/runtime-bound canonical macOS profile build for all nine cases. No build ran in this campaign. Both executable/framework hashes match the earlier n=1 pilot; no binary copy/archive was created. The earlier n=1 receipt is immutable and remains a separate cohort.

## Measured operations

Each case used its own fresh process and result. The fixed workload contains 1,000 products, ten groups, 1,200 stock rows including 201 target-history rows, and 50-row pages. Before its start marker, the producer completed one real warm-up operation, full verification, fresh-owner reopen and cleanup. Each of the 50 measured iterations used a fresh real adapter/ViewModel/store. The producer verified the complete expected canonical document, revisions/fences/workspace and operation-specific counts/values, then reopened with a fresh store owner and cleaned its directory before accepting a sample. The fixed descriptors preserve exact outcomes for lookup, filtering, pagination, product/stock mutations and photo bytes.

| Operation | p50 ms | p95 ms | RSS MB | CPU avg % | OS samples | Resource s |
|---|---:|---:|---:|---:|---:|---:|
| `c1.product.create` | 183.8590 | 192.6420 | 257.556 | 114.70 | 944 | 21.0387 |
| `c1.product.edit` | 185.2080 | 195.2950 | 257.622 | 114.96 | 948 | 21.2255 |
| `c1.product.photo_select_save` | 184.1855 | 197.7940 | 255.033 | 115.05 | 945 | 21.1144 |
| `c1.stock.post` | 186.2460 | 199.4160 | 173.687 | 115.54 | 957 | 21.3150 |
| `c1.stock.reverse` | 188.9020 | 211.3820 | 259.359 | 114.77 | 977 | 21.7796 |
| `c1.stock.history` | 0.6605 | 0.7510 | 163.086 | 118.55 | 533 | 12.0642 |
| `c1.catalog.lookup` | 49.0980 | 49.9380 | 242.745 | 113.80 | 646 | 14.3408 |
| `c1.catalog.filter` | 45.2240 | 46.4480 | 164.364 | 115.12 | 639 | 14.3102 |
| `c1.catalog.page` | 48.2170 | 49.6050 | 200.032 | 114.30 | 647 | 14.4076 |

The nine canonical result files retain all 450 elapsed values in chronological order. Median averages sorted values 25/26; p95 uses nearest-rank value 48. Generic result validation and an independent recomputation of these statistics passed before each workflow stage advanced. No latency sample was pooled across cases or with the historical pilot.

## Resource and timing limits

Elapsed samples bracket the actual ViewModel query or durable save acknowledgement. Setup, exact state checks, reopen and cleanup sit outside each latency sample. Photo selection/save includes the 58,554-byte bundled asset read and excludes image decoding. Stock history measures the uncached target query on a fresh ViewModel.

Each CPU/RAM result covers one broader host marker-receipt window containing the measured operations and inter-iteration setup/verification/reopen/cleanup. RAM is absolute sampled direct-child RSS in decimal MB, not incremental heap. CPU normalizes one logical core to 100%; the native process can exceed 100% and values are not divided by eight cores. The host retains aggregate observation count, cumulative CPU seconds, interval-derived peak and window duration, but not each periodic OS observation. Requested 20 ms intervals can miss short peaks. Warm-up does not prove thermal or OS-cache steady state. Other owned compiler/Device work stayed paused during the authorized window; shared OS/background/cache conditions remain uncontrolled.

No artificial wait or loop padded a measured window. The existing producer's 100 ms post-end lifetime remains outside the windows. Every result had valid OS sampling and cleanupComplete=true. These are standalone macOS ARM64 profile API baselines, with no GUI/frame/raster/native-input/mobile or performance-budget pass.

## Execution, complications and cleanup

Preflight passed with a freshly marked synthetic descriptor. Product-create ran as the representative 50-sample pilot; eight case stages followed sequentially, each recorded before advancing. No measurement failed or retried. The first workflow-record call refused absolute evidence paths before mutating state; repository-relative evidence references fixed the bookkeeping, and the same measured result was recorded. The refusal remains in `case-01-workflow-record-refused.json`.

The first timer invocation encountered closed stdin and ended interrupted. A PTY resumed the reviewed persistent timer without overwriting that attempt. Initial intake/timer gap and final documentation tail do not establish active-effort/token/cost figures. One intake key probe used `command` instead of the descriptor's `proposedArgv`, and an unused module-path lookup failed; bounded current-source reads corrected both. Initial memory/prevention excerpts exceeded output budgets; subsequent reads were bounded. No source change or extra test/build/measurement resulted.

Observed case-runner wall sum: 198.337 seconds. Resumed timer observed wall: 354.081 seconds, status stopped; active effort/cost remains unknown. Root received the compiler/CPU release after final source and cleanup readback.

All nine host cleanup flags passed. Both known synthetic-store roots contain no new `dakhl-c1-bench-*` directories. The marked preflight fixture was removed only after checking its exact two filenames, marker bytes and descriptor hash. Successful duplicate CLI stdout was removed only after semantic equality with the canonical result; execution receipts retain its original byte count/hash. Failed bookkeeping evidence and historical manifests remain. No accounts, unrelated caches, recovery objects, Git state or binaries were deleted.

Fresh whole-project baseline: app 28,999,836 KiB, engine 1,419,552 KiB, free 95,120,200 KiB. Execution closeout: app 29000300 KiB (+464 KiB), engine unchanged, free 97178680 KiB; both Git directories/build/dart caches unchanged and zero temporary Git object stores. Task evidence accounted for +364 KiB at this checkpoint. Other shared-volume changes have no verified producer. Compact final docs/manifest/memory bookkeeping receives a final storage receipt before handback. Canonical raw results/diagnostics, source/workflow/cleanup receipts and existing binary references are retained for independent review. No substantial task-owned disposable output remains.

## Remaining obligations

Independent aggregate review, numeric performance budgets and GUI/frame/mobile measurements remain separate. No tracker closure, app/engine source/pin changes, Git mutation, telemetry or release approval occurred. Parent owns integration and approval. Project-scoped memory synchronization/check follows this sanitized log; pending ingestion must remain explicit.

Closeout metadata correction: memory check can emit queued-sync JSON records before its final check JSON. A single json.loads call refused Extra data; parse the bounded JSON stream and select the final project check record. This affected metadata only, after window release; no measurement or source changed.
