<!-- hindsight:ignore -->
# Final fixed-source Phase02 performance cohort

All18 distinct cases passed:360 real samples,20 percase; no retries or selected replacements. App `5a11c66dbf665972b17b545c105eac74c17bfeeb`, runtime `a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294`, measurement tool `63bbed8303bf8561084c5f82a3ebd52e2bf9e95d`.
Source `b04753cd7925359de3baef86748fcd3c030d0c6e68df7143c785a5bdd0dc6fe3`; binary `0d32c268da110e029ecd36d93741cda25c832cac26872f69ba692142119b2eb4`; inputtree `15073d8bc40405796e4665632d7a1b6d8057e30e053567b5ec3882d557a82559`.

Campaign UTC 2026-10-30T12:45:18.461673+00:00–2026-10-30T13:03:05.971704+00:00. Host command wall 1058.102s (first command includes new build); total campaign wall 1067.510s. Tokens/cost unknown.

| Fixture | Operation | p50ms | p95ms | RSSpeakMB | CPUavg% | CPUpeak% |
|---|---|---:|---:|---:|---:|---:|
| small | [accounts.open](small/accounts.open.json) | 15.230 | 17.074 | 158.417 | 26.12 | 106.28 |
| small | [accounts.save](small/accounts.save.json) | 7.652 | 16.045 | 172.098 | 20.64 | 106.30 |
| small | [accounts.migrate_legacy](small/accounts.migrate_legacy.json) | 31.295 | 32.733 | 173.015 | 25.01 | 131.28 |
| small | [accounts.replace](small/accounts.replace.json) | 15.307 | 16.999 | 176.488 | 24.42 | 105.91 |
| small | [accounts.recover_previous](small/accounts.recover_previous.json) | 23.686 | 25.456 | 174.670 | 29.20 | 110.59 |
| small | [workspace.save_restore](small/workspace.save_restore.json) | 7.002 | 9.112 | 167.936 | 19.29 | 106.44 |
| medium | [accounts.open](medium/accounts.open.json) | 40.142 | 48.380 | 174.424 | 66.50 | 160.06 |
| medium | [accounts.save](medium/accounts.save.json) | 56.892 | 63.161 | 191.922 | 73.92 | 165.30 |
| medium | [accounts.migrate_legacy](medium/accounts.migrate_legacy.json) | 73.466 | 75.338 | 190.956 | 48.90 | 178.81 |
| medium | [accounts.replace](medium/accounts.replace.json) | 81.955 | 88.684 | 192.643 | 86.35 | 174.41 |
| medium | [accounts.recover_previous](medium/accounts.recover_previous.json) | 115.047 | 123.083 | 193.954 | 105.03 | 182.13 |
| medium | [workspace.save_restore](medium/workspace.save_restore.json) | 27.752 | 33.533 | 190.824 | 60.06 | 179.01 |
| largest | [accounts.open](largest/accounts.open.json) | 1656.209 | 1657.363 | 717.128 | 101.19 | 187.62 |
| largest | [accounts.save](largest/accounts.save.json) | 3748.990 | 3814.721 | 716.112 | 102.46 | 190.24 |
| largest | [accounts.migrate_legacy](largest/accounts.migrate_legacy.json) | 3188.012 | 3242.811 | 739.459 | 99.54 | 217.98 |
| largest | [accounts.replace](largest/accounts.replace.json) | 5723.102 | 5750.237 | 818.332 | 103.24 | 208.86 |
| largest | [accounts.recover_previous](largest/accounts.recover_previous.json) | 7273.328 | 7339.703 | 843.842 | 103.48 | 212.21 |
| largest | [workspace.save_restore](largest/workspace.save_restore.json) | 1306.543 | 1319.042 | 741.409 | 102.27 | 192.17 |

The predeclared first case was largest migration; all remaining17 unique pairs followed original profile/registry order. Each passed20samples, native raster checks, source/cache/manifest checks, cleanup and zero remaining owned processes before continuation. [Machine index](summary.json) contains every raw sample, result/receipt/manifest/cache/log SHA256, UUID and exact command.

Hardware: AppleM1Pro, MacBookPro18,3,8logicalcores, macOS27.2 arm64; Flutter3.47.8/Dart3.13.7; Xcode27.2 build27B52/macOSSDK26B118. Mac profile mode, native Mach direct-process sampler20ms.

Latency includes the actual consumer command and final repaint, ending at matching fresh native frame rasterFinish. Fixture creation/reset and initial bootstrap are outside elapsed. The broader host resource window includes inter-iteration reset, readiness, setup, callbacks and teardown; it is not per-sample CPU/RAM. OS caches are uncontrolled; RSS is sampled direct-process peak, descendants excluded; CPU100% is one logical core.

Synthetic cash transaction counts:10/1000/10000. Largest canonical20759123bytes, limit20971520bytes. Workspace active1+held40/about3.4KiB for allprofiles; no near-limit workspace claim.

No mobile performance, optimization, target attainment or reliability claim. No proof of the specific historical warm-up interleaving or that earlier failures are fixed. Prior62/df72/isolated/Step3 evidence remains archived and excluded; changed bootstrap setup prevents an unqualified resource comparison. Android preservation failure/iOS platform pending remain blockers outside this Mac measurement gate.

All18 host cleanup flags true; final owned profile/runner PID list empty. This does not assert temporary fixture directory deletion. Measured source inputs remained clean and matched reviewed hashes; generic sourceDirty includes unrelated documentation/evidence. No runtime/source/SDK/key/config/target mutations occurred.
