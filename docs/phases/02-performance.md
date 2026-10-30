# Phase 02 — operation performance baselines

App `69fef62452dd70a57de1c024d0ef49d807f272a1`, runtime engine `ea9c21adfde746c40d0e8d15a7e5bbe017beb70c`, measurement tool `63bbed8303bf8561084c5f82a3ebd52e2bf9e95d`. Eighteen accepted measurements, twenty independent fixture iterations each (360 samples).

| Profile | Operation | p50 ms | p95 ms | RAM MB peak | CPU avg % |
|---|---|---:|---:|---:|---:|
| small | accounts.open | 16.678 | 21.399 | 158.826 | 22.749 |
| small | accounts.save | 8.095 | 8.317 | 164.905 | 14.475 |
| small | accounts.migrate_legacy | 25.076 | 47.585 | 172.769 | 20.057 |
| small | accounts.replace | 16.648 | 16.921 | 175.522 | 23.175 |
| small | accounts.recover_previous | 25.058 | 25.239 | 175.538 | 30.057 |
| small | workspace.save_restore | 8.102 | 8.411 | 167.903 | 14.846 |
| medium | accounts.open | 42.471 | 50.017 | 174.604 | 71.942 |
| medium | accounts.save | 66.665 | 67.713 | 193.348 | 84.994 |
| medium | accounts.migrate_legacy | 75.065 | 83.389 | 191.087 | 51.128 |
| medium | accounts.replace | 91.721 | 95.719 | 193.397 | 98.466 |
| medium | accounts.recover_previous | 125.066 | 133.377 | 195.625 | 97.365 |
| medium | workspace.save_restore | 32.664 | 33.459 | 192.037 | 63.883 |
| largest | accounts.open | 1731.704 | 1773.031 | 663.929 | 101.475 |
| largest | accounts.save | 3948.694 | 3965.612 | 644.989 | 103.048 |
| largest | accounts.migrate_legacy | 3329.463 | 3342.962 | 666.960 | 100.646 |
| largest | accounts.replace | 5981.432 | 6017.067 | 792.297 | 103.970 |
| largest | accounts.recover_previous | 7552.577 | 7598.694 | 796.754 | 104.015 |
| largest | workspace.save_restore | 1381.324 | 1398.130 | 669.221 | 102.840 |

All accepted raw results, manifest checksums and exact identities are indexed in raw result index (local-only artifact `outputs/phase02/performance-frame-id/summary.json`, SHA-256 `d2e7a977ea3d08162e84a1fd294c7ed07cc233191383f41e51205de119a3a8e9`).

- Elapsed latency starts before the actual consumer command and ends at the matching fresh native frame rasterFinish, including a deliberate final repaint. It is not pure command time.
- SDK timing callback delivery is awaited before proceeding but its later delivery delay is excluded from sample elapsed latency.
- Sampled process RAM and CPU cover one start/end window including inter-iteration fixture reset, rendering setup, callback observation and teardown; resources are not isolated per elapsed sample.
- CPU uses one logical core =100%; values above100% reflect multi-threaded work. RAM is sampled resident peak in decimal MB at20ms interval.
- Synthetic small10/medium1000/largest10000 cash transactions and active1+held40 drafts; largest document20759123bytes within20MiB. No production capacity promise.
- Same-source medium migration initial host attempt failed; filtered direct20 and one authorized host retry passed. Cause remains unresolved; accepted results do not establish absence of intermittency.
- Host user apps and OS cache/thermal state are uncontrolled. Mac profile-mode measurements are not mobile measurements. No performance target or optimization claim.
- sourceDirty records documentation/evidence changes; measured producer/native/package inputs are bound by source and binary fingerprints.

Earlier source epochs and diagnostics remain preserved and excluded from the accepted cohort. The initial failed medium migration result is retained alongside its first successful authorized retry; no result file was overwritten.

## Environment and fixtures

Native macOS profile mode, Darwin 27.2/arm64, Apple M1 Pro (MacBookPro18,3), 8 logical CPUs; Flutter 3.47.8/Dart 3.13.7; Python 3.13.0. Captured toolchain: Xcode 27.2 build 27B52, macOS SDK build 26B118. Fresh local toolchain queries matched the captured values; no toolchain change was performed for this closeout. Native restart records keep their own dated contexts.

| Profile | Synthetic records | Canonical account bytes | Legacy input bytes | Replacement bytes | Workspace bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| small | 10 | 2904 | 2903 | 2906 | 3416 |
| medium | 1000 | 192733 | 192732 | 192735 | 3416 |
| largest | 10000 | 20759123 | 20759122 | 20759125 | 3416 |

Each profile uses one active presentation state and 40 held presentation records. The workspace is 3,416 bytes; the largest account is near the 20 MiB boundary. These results do not measure a near-20-MiB workspace or production restaurant records. Legacy migration consumes schema 1; the canonical fixture is schema 11. The largest fixture pads each synthetic record with 1,896 note characters.

## Method, evidence and review limits

p50 is the median; p95 uses nearest rank over 20 independent iterations. Input preparation/reset is outside command elapsed time. The endpoint is the actual matching fresh native frame's rasterFinish on the same documented VM monotonic clock as the command start. The frame-ID guard replaces an invalid comparison between presentation target time and vsync start; old source epochs are excluded. Sample latency includes a deliberate final repaint, and excludes later SDK callback-delivery delay.

The independent evidence review recomputed quantiles and CPU arithmetic and checked all accepted artifact/manifest hashes and exact identities. The reviewed producer enforces fresh frame IDs and valid phase clocks; individual GPU-frame traces and periodic resource observations were not retained for independent reconstruction. The resource aggregates come from the reviewed macOS libproc collector. This is evidence for the specified instrumented development workload, not a reliability certification.

The medium migration original failed host attempt has zero accepted samples. A same-source direct diagnostic completed 20 operations (not a RAM/CPU baseline), and one authorized host retry produced the accepted measurement. The first failure's cause is unresolved; successful retry does not establish absence of intermittency. Earlier artifacts remain unchanged and are indexed as excluded evidence.

Independent metrics review (local-only artifact `outputs/phase02/app-performance-evidence-review-20261030T101056Z.md`, SHA-256 `66e2c36a6c9c98516aee3c74f5cd0e3e16654fc667a442ed251826e3a6056be8`), benchmark execution audit (local-only artifact `outputs/phase02/native-performance-audit.md`, SHA-256 `a577015ac87ad5878b8fb34bf05e0667a7cdcb5f25038c029195f7ddb9f351e3`), [Step3 build](02-step3-build.md). No optimization target or before/after improvement was claimed. Mobile performance lacks a supported collector and is not inferred from these Mac figures.
