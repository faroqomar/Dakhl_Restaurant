# Completion nonvisual operation benchmarks

Date: 2026-11-07. Status: independently reviewed Step3 native baseline at the recorded source fingerprint. Step4 compatibility fixes are later source and are not certified by those historical measurements. No optimization, UI completion, phase completion or performance pass is claimed.

## Ownership and timing

Madar's existing reviewed `tool/dev_benchmarks/benchmark.py` owns process execution, protocol validation, elapsed p50/p95 and sampled RAM/CPU aggregation. No engine implementation was copied or changed. Dakhl owns the separate opt-in `lib/platform/completion_performance_main.dart` entrypoint, synthetic workload and consumer commands. The app runner selects it only for registry entries tagged `completion-nonvisual`; existing Phase01/02 entrypoints, raster timing and fixture manifests retain their behavior.

Each case uses the fixed `completion-v1` workload:1000 products,1000 opening stock entries,100 suppliers,100 materials, one active draft plus39 held drafts, four lines per populated draft. This is a representative bounded fixture, not the maximum accepted account size. All values are synthetic. Before measured iterations, each process runs one actual unmeasured warm-up command, verifies durable close/reopen state and cleans up its separate fixture. A warm-up failure exits with an error before ready/start/sample markers. Each measured iteration creates a fresh real Madar document/workspace adapter below `Directory.systemTemp` with prefix `dakhl-completion-bench-<runId>-<pid>-`. It never opens normal app storage. Cleanup closes adapters and deletes only that allocated directory. Forced termination may leave that isolated directory; broad deletion is forbidden.

| Case | Elapsed interval |
| --- | --- |
| `catalog.lookup` | Query/filter/page a prepared immutable1000-product catalog by code and group through consumed matching IDs. Excludes model construction, codec validation, stock projection and storage reads. |
| `inventory.post_movement` | Consumer restock command through validation, stock safeguards and durable account acknowledgement. |
| `workspace.hold` | Hold four-line active draft at39held entries through atomic40held workspace acknowledgement. |
| `workspace.resume` | Resume one held draft, swap the populated active draft into its slot and acknowledge one workspace write. |
| `settings.save` | Save prepared restaurant-name edit through settings controller validation and durable acknowledgement. |
| `parties.save_supplier` | Save prepared supplier-note edit through metadata safeguards and durable acknowledgement. |
| `parties.save_material` | Save prepared material unit-price edit through metadata safeguards and durable acknowledgement. |

Dart monotonic timestamps bracket the command, including its acknowledgement checks. Setup and draft editing occur before timing. After timing, the producer checks operation postconditions, closes the adapter, reopens it and compares the entire account and workspace payloads to the acknowledged state. Only then does it emit a sample. Failure emits an error and exits nonzero; it cannot produce a passing measurement from partial samples.

These are nonvisual command timings. They include no UI, raster completion or native input dispatch. The process resource window starts after the warm-up has completed and after first measured-fixture preparation, then ends after last measured-fixture cleanup. Warm-up uses a separate fresh adapter directory; no warmed mutable fixture state enters measured samples. Warm-up elapsed and resource activity are outside the reported marker window; process code and OS caches may remain warm. It includes verification, cleanup and subsequent fixture preparation; RAM/CPU are not isolated per sample. One-sample CPU can have coarse resolution and20ms RAM sampling can miss short peaks. No arbitrary timing floor, delay or synthetic loop hides these limits.

## Current verification

- Python routing test failed before new target/source routing: `/tmp/completion-bench-python-red.log`.
- Dart tests failed with missing scenario module before implementation: `/tmp/completion-bench-dart-red.log`.
- Registry tests failed before adding new measurable entries: `/tmp/completion-bench-registry-red.log`.
- Nine Dart tests passed, covering invalid arguments, all seven real-adapter command/reopen paths and lookup result/no-write behavior: `/tmp/completion-bench-dart-first.log`.
- All32 app-runner Python tests passed: `/tmp/completion-bench-python-final.log`. The mocked build test prints a preparation message; it does not execute a native build.
- Initial analysis found one brace-style info; corrected. Final focused analyzer reported no issues: `/tmp/completion-bench-analysis-final.log`.

The Lead records exact engine pin and aggregate verification. Engine candidate reported by the Lead: `7b1866fb8c9a40345c9d67b455c40053178fcb44`, domain `0.1.0-dev.2`. Benchmark execution must verify the actual resolved package sources through the existing checker; this document does not replace that check. No profile build or measurement ran in this worker lane.

## Campaign handoff

After independent scenario review and the Lead's existing reviewed workflow preflight/pilot authorization, run a one-iteration pilot first. Use the explicit Python3.13 interpreter below: the Lead observed that the default micromamba Python3.9 could not import the campaign scripts. Passing app-runner unit tests under the default interpreter did not establish campaign-import compatibility. The runner enforces lockfile resolution, checks engine source, builds the selected macOS profile entrypoint and records app/engine/tool identities and source fingerprints. Build remains outside timing. Use unique campaign artifact paths; do not overwrite previous receipts.

```sh
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3 tool/dev_dashboard/run_benchmarks.py \
  --engine-tools-root /Users/eros/Dev/Eros_Projects/Madar_Engine \
  --case catalog.lookup --iterations 1 \
  --output outputs/completion/performance/pilot-catalog-001.json
```

Exact native build selected by the runner is `flutter build macos --profile --no-pub -t lib/platform/completion_performance_main.dart`. Direct binary invocation alone is not a measured campaign because it omits host resources, checks and provenance.

After a successful pilot and receipt review, use repeated `--case` arguments for the seven cases above and `--iterations 20`, writing to a new output path. `--fixture` remains a Phase02-only option; Completion uses the fixed documented workload. Avoid `all-ready` for this bounded campaign because it also includes earlier UI scenarios. The runner fingerprints this scenario source plus case/scenario identity, records `fixtureProfile: completion-v1`, and preserves the broader resource-window description.

The first valid run establishes a baseline. Compare only matching case, scenario/source identity, workload, engine/tool revision, platform, hardware, OS, profile mode and sample conditions. No numeric budget or speedup exists yet. Mobile/native screen behavior, full business workflows and maximum-size performance remain outside these cases. Report failed pilots and unavailable samples as failed/pending; do not relabel them as N/A or fabricate values.

Warm-up follow-up: added one unmeasured real command/verification/cleanup cycle before readiness. No Flutter rerun or measurement accompanied this entrypoint-only correction during the Lead’s serialized verification window; independent source recheck requested. Existing scenario tests exercise that same create/run/verify/close lifecycle.


## First native campaign and post-end protocol correction

The catalog one-sample native pilot passed. In the first20-sample seven-case run, catalog lookup, workspace hold and supplier save passed; inventory post, workspace resume, settings save and material save reported `resource_samples_unavailable`. All child cleanup completed. These unavailable cases remain preserved, not converted into passing latency-only results.

Source inspection found immediate producer exit after the end marker; a race with the host's final native resource read is the working hypothesis until rerun verification. The reviewed host protocol documents an approximately100ms post-end lifetime. The producer now waits100ms after flushing end; it adds no delay inside command elapsed or the start/end resource window. A new source-bound campaign/pilot is required for the corrected producer; the old source identity remains immutable.

## Measured first baseline

Source-bound successor campaign002 passed preflight, two one-sample pilots (catalog lookup and durable inventory write), then seven20-sample operations. All cleanup receipts passed. This verifies the post-end protocol remedy for this run; the original generic diagnostic did not expose which sampler read was absent. Earlier unavailable results remain intact.

macOS27.2, AppleM1Pro/8logicalCPUs, Flutter3.47.8/Dart3.13.7, profile mode, explicit Python3.13.0,20ms requested resource sampling. App0.0.0+1working tree at7067ea72e06c831791f7ea393b8587150671af18, dirty source fingerprint`24bc40f25c2f0eb1905d3050fa9586b84821f738065a2418e3be53ba5e8df9d7`; engine`7b1866fb8c9a40345c9d67b455c40053178fcb44`. No UI latency, performance budget or speedup claim.

| Operation | Samples | p50 ms | p95 ms | Sampled process peak MB | Window CPU seconds |
| --- | ---: | ---: | ---: | ---: | ---: |
| `catalog.lookup` | 20 | 0.0390 | 0.0420 | 244.19 | 4.7481 |
| `inventory.post_movement` | 20 | 179.5700 | 187.4310 | 250.68 | 9.0040 |
| `workspace.hold` | 20 | 14.6585 | 17.1230 | 235.77 | 5.4393 |
| `workspace.resume` | 20 | 15.2795 | 19.2000 | 233.47 | 5.6226 |
| `settings.save` | 20 | 148.8240 | 206.7080 | 242.60 | 8.8504 |
| `parties.save_supplier` | 20 | 145.7090 | 160.3970 | 248.89 | 8.5259 |
| `parties.save_material` | 20 | 135.3720 | 142.7090 | 239.47 | 7.9022 |

RAM/CPU cover each whole start/end marker window, including inter-iteration fixture preparation, verification and cleanup. They are not memory/CPU cost of one command. Catalog elapsed excludes model construction/stock projection. Small measured intervals retain sampler resolution limits. OS caches and background host load are uncontrolled.

Raw results, campaign state, and earlier unavailable campaign preserve samples, hashes, hardware/tool identities and cleanup. These are first baselines; no comparable earlier series exists.
