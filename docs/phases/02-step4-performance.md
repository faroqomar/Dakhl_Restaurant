# Phase02 — Step4 fixed-source operation measurements

Date: 2026-10-30. **All18 local macOS cases passed,360 real samples,20 per case; no retries or replacement selection in this cohort.** This is descriptive local evidence, not phase approval, an optimization result or reliability certification. Android preservation failure, iOS verification and hosted CI remain open.

## Exact cohort

- App `5a11c66dbf665972b17b545c105eac74c17bfeeb`; runtime engine `a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294`; separate measurement tool `63bbed8303bf8561084c5f82a3ebd52e2bf9e95d`.
- Source fingerprint `b04753cd7925359de3baef86748fcd3c030d0c6e68df7143c785a5bdd0dc6fe3`; binary `0d32c268da110e029ecd36d93741cda25c832cac26872f69ba692142119b2eb4`; full input tree `15073d8bc40405796e4665632d7a1b6d8057e30e053567b5ec3882d557a82559`.
- UTC 2026-10-30T12:45:18.461673+00:00 → 2026-10-30T13:03:05.971704+00:00; campaign 1067.510s, command wall sum 1058.102s, resource windows 925.095s. These overlap and must not be added to execution wall time.
- Formerly failing largest migration was predeclared first; its20 valid samples/cleanup preceded the other17 distinct pairs once. All source/manifest/run/binary/cleanup identities were validated. No isolated/old source case is merged.

Complete machine-readable index and hashes, raw table and per-case artifacts. Independent final arithmetic/provenance review passed805 fresh checks and108 artifact hashes with zero discrepancies: review.

## Results

Latency is milliseconds; RSS is sampled absolute peak decimal MB. CPU average is cumulative process CPU over its broader resource window;100% equals one logical core and values above100% are valid. No numeric performance budget was agreed.

| Fixture | Real operation | Median ms | p95 ms | RSS peak MB | CPU average % |
| --- | --- | ---: | ---: | ---: | ---: |
| small | accounts.open | 15.230 | 17.074 | 158.417 | 26.12 |
| small | accounts.save | 7.652 | 16.045 | 172.098 | 20.64 |
| small | accounts.migrate_legacy | 31.295 | 32.733 | 173.015 | 25.01 |
| small | accounts.replace | 15.307 | 16.999 | 176.488 | 24.42 |
| small | accounts.recover_previous | 23.686 | 25.456 | 174.670 | 29.20 |
| small | workspace.save_restore | 7.002 | 9.112 | 167.936 | 19.29 |
| medium | accounts.open | 40.142 | 48.380 | 174.424 | 66.50 |
| medium | accounts.save | 56.892 | 63.161 | 191.922 | 73.92 |
| medium | accounts.migrate_legacy | 73.466 | 75.338 | 190.956 | 48.90 |
| medium | accounts.replace | 81.955 | 88.684 | 192.643 | 86.35 |
| medium | accounts.recover_previous | 115.047 | 123.083 | 193.954 | 105.03 |
| medium | workspace.save_restore | 27.752 | 33.533 | 190.824 | 60.06 |
| largest | accounts.open | 1656.209 | 1657.363 | 717.128 | 101.19 |
| largest | accounts.save | 3748.990 | 3814.721 | 716.112 | 102.46 |
| largest | accounts.migrate_legacy | 3188.012 | 3242.811 | 739.459 | 99.54 |
| largest | accounts.replace | 5723.102 | 5750.237 | 818.332 | 103.24 |
| largest | accounts.recover_previous | 7273.328 | 7339.703 | 843.842 | 103.48 |
| largest | workspace.save_restore | 1306.543 | 1319.042 | 741.409 | 102.27 |

## Workload and method

Small/medium/largest contain10/1,000/10,000 authored synthetic cash records. Canonical account sizes are2,904 /192,733 /20,759,123 UTF-8 bytes, with separate source/replacement sizes retained in the index; account limit20,971,520 bytes. Largest records use1,896-character notes to approach the byte ceiling. Every workspace is3,416 bytes, active1 plus40 held presentation drafts; this is not a near-limit workspace stress test. These are no order-processing or posting benchmarks.

Each iteration prepares a fresh owned synthetic store outside elapsed measurement. Latency begins with the actual consumer ViewModel/repository command and ends at the deliberately repainted matching fresh native frame's rasterFinish in the shared VM monotonic clock. Later timing-callback delivery and native input dispatch are excluded. Median is p50; p95 uses nearest rank. All20 raw latencies are retained without selection.

Sampled direct-process RSS/Mach CPU span host start/end markers, including between-iteration fixture reset, bootstrap/render setup, callback idle and teardown. They are aggregate case resources, not per-latency-sample attribution; descendants are excluded. Requested sampling interval20ms does not guarantee the instantaneous memory peak. OS/native caches and thermal state are uncontrolled. Hardware is Apple M1 Pro/MacBookPro18,3,8 logical CPUs, macOS27.2 arm64, Flutter3.47.8/Dart3.13.7; exact Python/tool/sampler/Xcode/SDK identity is in the index. Only lightweight documentation/evidence coordination occurred concurrently; no other tests/profiles/heavy commands, and the task Android target was off.

Initial root/warm-up/first-raster readiness now precedes fresh-frame baseline selection under one total ten-second guard. It does not replace actual matching native ID/rasterFinish. Operation timing/resource-window boundaries are unchanged, but bootstrap adds setup work within later reset windows. This source cohort is therefore separate from earlier partials and no cross-epoch resource delta or optimization claim is made. Independent bootstrap review.

## Preserved failures and limits

The historical Step3 full360 baseline is retained at app69/runtimeea9/tool63. Its original medium migration failure and successful explicit retry remain separate. In Step4, app62 stopped at8accepted/160samples plus a generic medium failure. Appdf72 isolatedmedium20 and exact-prefix180 passed without explaining those errors; its later cohort stopped14accepted/280samples at a captured initialRender timeout before migration, with3 unexecuted cases. None is relabelled into this5a11 cohort.

The captured failure exposed a source-backed reachable root-attachment/warm-up observer race, corrected and independently reviewed with meaningful RED→GREEN tests. Its exact historic frame IDs/interleaving and the earlier generic failures' causes remain unproven. Current360 successful samples do not certify all-attempt reliability, physical hardware/mobile behavior, production capacity, physical power-loss recovery or a released-installation migration.

Individual native timing-event/clock traces and periodic resource observations were not retained; independent reconstruction of those underlying traces is unavailable. Source guards, actual validated outputs and raw20-value latency arrays support this bounded descriptive baseline. Process cleanup was verified; that does not assert all synthetic temporary fixture directories were deleted. No real account payload was read in the Android impact checks, and prior installed Android app-data retention remains unverified after automatic uninstall/reinstall. Mac performance cannot clear that preservation failure.

[Current independent review/readiness](02-step4-review.md), [Android incident](../log/2026-10-30-phase02-android-preservation-incident.md), execution/time-cost audit (local-only artifact `docs/log/phase-02-execution.md`, SHA-256 `d490433a2ead39ecf2f36721364cd1003b550152426fa7b98b90c3bb069c639c`).
