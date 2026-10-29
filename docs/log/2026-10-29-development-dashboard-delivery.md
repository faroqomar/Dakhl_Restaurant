# Minimal development dashboard and version method — 2026-10-29

Owner requested a minimalist Sites dashboard with real test/benchmark launch/results, versioned future GitHub delivery, and separate speed/RAM/CPU measurements for each major operation. The standalone console uses three views: Progress, Checks, Performance. It adds no restaurant feature, financial policy or whole-app redesign.

## Ownership and source

App worktree `/Users/eros/.codex/worktrees/dashboard-app/Dakhl_Restaurant`, branch `codex/dev-dashboard`, base `f38ff2817ab8c5a280f89845d3e6bd1e8202ed33`: real isolated scenarios, app frame hooks/build cache, registry, version helper, CI/PR procedure and own documentation. Madar development-tools worktree `/Users/eros/.codex/worktrees/dashboard-engine-tools/Madar_Engine`, branch `codex/dev-benchmarks`, owns generic host/protocol/resource sampling/validation/comparison. Standalone Site source `/Users/eros/Dev/Eros_Projects/Dakhl_Development_Dashboard` owns minimal UI, loopback pairing and allowlisted orchestration. Runtime engine remains exact `6d4ae39f35b005dfa1123a82c6df316901e1e1e4`; no shared implementation is copied into app or Site.

Reviewed generic module SHA256: `03895ffc543845e88b0f48aba42c3290d5f5f8a644f1ba73dc791434a2e3cd14`. Reviewed app CLI SHA256: `677d2a68daa65f7674ed15bc85e1ead908f52dc2de5fd2dc00e76ffced8b98f7`. These identify unpublished local tooling candidates, not released packages. Actual source/binary/workload/environment fingerprints are in the receipt.

## Actual verification

Dashboard button launched `run-da4fb11fcd67b2b6`: **246 passed** across nine allowlisted commands: source pin check, 27 app source/version regressions, version format, 151 Flutter tests, 6 app-runner regressions, 5 engine application, 16 engine storage, 27 engine adapters and 14 generic benchmark tests. Independent review also reran runner11/UI5/version3/app-cache6/generic14 focused tests. Flutter analysis was clean in worker verification. Existing full-suite baseline was151; source/runtime Flutter code did not change after that. Dashboard support CI additions have not run on hosted GitHub.

Dashboard button launched `run-f57aad3e9bc2b13a`, all three real macOS profile operations passed with source guards. Python3.13/macOS27.2/AppleM1Pro; app0.0.0+1, isolated fixture storage. These are baseline measurements, not budgets or optimization improvements:

| Operation | Samples | Median ms | p95 ms | Sampled RAM peak MB | CPU average % | CPU interval peak % |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Fresh process to usable shell | 5 | 392.349 | 1463.965 | 182.551 | 59.378 | 396.083 |
| Switch route, persist and render (ViewModel) | 20 | 17.095 | 19.160 | 192.578 | 29.502 | 126.947 |
| Save six shortcuts, persist and render (ViewModel) | 20 | 13.228 | 14.296 | 186.417 | 22.359 | 47.501 |

CPU uses one logical core=100%, can exceed100% across cores. RAM is sampled process resident peak, not absolute peak/heap. Startup includes host/frame-report delivery and uncontrolled OS caches; compilation/install excluded. Workflow durations use command-to-raster same-clock timestamps and exclude native input dispatch. Resources include marker-report waiting. Reusable methodology/error/limit details are authoritative in Madar `tool/dev_benchmarks/README.md`.

Local browser verified real pairing, disabled busy controls,246-check result display, real per-operation metrics, baseline save/persistence and390px layout without page overflow. Private Site native deployment succeeded: [Dakhl Development](https://dakhl-development-dashboard.eros-6.chatgpt.site), project `appgprj_6ae362717ed08191a885ecaf744a336c`, source `3de2983c4e79ddd651715ec2692bcec0e2bfaf30`, deployment `appgdep_6ae36b28da448191bb74c20d98290b71`, owner-private. Owner completed normal sign-in; hosted connection verification is recorded below when complete. Local tests/benchmark runs are genuine, distinct from earlier UI fixture QA. Detailed receipt: `outputs/dev-dashboard/delivery.json`; screenshot in standalone Site `evidence/performance.jpg`.

## Review and future delivery

Independent `dashboard_runner_review` identified and closed runner orphan lifecycle/source provenance, missing command result details and engine-aware profile-cache issues. Real signal tests preserve unrelated processes. Actual app/engine/tool source is captured and checked around every command; a mutated source run fails. Resolved package paths/actual package bytes bind binary cache identity, so old engine binaries cannot report a new pin. HTTP tests cover Host/Origin/bearer/pairing/expiry/single-flight/traversal. No open actionable code finding remained; final receipts were independently checked. Initial root bridge was implemented before its tests; regression fixes were independently reproduced/reverified. Do not label the whole bridge TDD.

[Version/performance procedure](../how-to/versioning-and-performance.md) defines explicit MAJOR.MINOR.PATCH+BUILD candidates, monotonic builds, reviewed source/engine/test evidence and owner-approved exact-commit merge/tag steps. Current0.0.0+1 is unchanged/unreleased. The helper only checks/prepares explicit pubspec version; it cannot commit/tag/push/merge. CI validates format and regression tests; actual previous delivered version remains an explicit release-record input. PR template records version choice and each major feature's own operation scenario.

## Limits and readiness

Orders, catalog creation and adding a sales item stay planned; real implementations/approved fixtures are prerequisites. No fake measurements for placeholder UI. Native resource support currently macOS only; phone performance is not established. Console authentication/allowlisted execution is local and origin-bound; no public tunnel, account payloads, remote telemetry, arbitrary commands or Git actions are exposed. Double-click standalone `Start Dashboard.command` to start/reconnect, keeping its Terminal open. Closing stops owned jobs; history persists locally. Hosted snapshot is dated evidence when unpaired.

Phase01 remains BLOCKED by required genuine reader traversal; hosted app CI/PR/merge/release remain pending. Developer Site publication does not close those gates or authorize another phase. App/engine work remains isolated and unmerged. Project memory delivery is verified separately after final documentation freeze; queued work is not completion.

## Published connection acceptance

Owner completed normal sign-in and explicitly approved the exact Chrome device-access prompt. Chrome hosted Site then showed Connected to Mac, launched `run-43f3530ce4c44462` and displayed its successful results and comparable baseline deltas. Latest medians: startup462.429ms (RAM181.027MB, CPU67.909%); navigation14.354ms (RAM193.954MB, CPU27.048%); shortcut save13.985ms (RAM186.057MB, CPU22.894%); complete precision/p95/CPU interval peaks are authoritative in the receipt. These second-run deltas illustrate normal measurement variation and are not optimization claims. Source guards passed; no implementation changed between runs. Browser screenshot: `outputs/dev-dashboard/published-dashboard.jpg`.

In-app browser initially timed out waiting on device access; its existing private sign-in succeeded but the Chrome permission prompt required native foreground inspection. Reused approved permission and generated a fresh one-use link after the first request expired; verified remedy is the actual connected Chrome run, not a timeout retry loop. Use Chrome and the existing Start Dashboard command; do not disable browser security or expose a public tunnel. The hosted snapshot intentionally remains dated first-run evidence when unpaired.
