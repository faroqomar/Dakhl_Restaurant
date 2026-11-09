# Development dashboard app benchmarks

Date: 2026-10-29. Status: implemented and locally verified; independent review/delivery remain separate. Scope: actual development-app profile measurements and an app-owned operation registry for the requested development dashboard. This does not complete Phase 01, resolve its screen-reader/hosted-CI gates, authorize a later business phase or change app version `0.0.0+1`.

## Ownership and contract

Dakhl owns the opt-in profile entrypoint, synthetic shell preferences fixture, actual ShellViewModel operation semantics, optional composition observer, profile build/cache and operation registry. Madar owns the generic development-only process/protocol/resource/result/comparison foundation in its separate tooling worktree. App consumption uses `run_benchmark(spec)` and protocol v1 `DAKHL_BENCH` ready/start/sample/end/error markers; shared sampler/aggregation implementation is not copied into the app.

Runtime engine changes: N/A. The app continues to consume exact reviewed `6d4ae39f35b005dfa1123a82c6df316901e1e1e4`; the separate development-tool source revision/fingerprint is recorded independently. No engine package, dependency, native identifier, data schema or production account is changed. Design: N/A for these technical measurements and optional observation; the normal Arabic shell's layout is unchanged. Dashboard visual approval/publication is owned by the separate dashboard work, not this record.

## Implemented behavior

- `app.startup` launches the built macOS profile executable five times with a fresh isolated actual Madar database per process. Timing is host process creation to observed usable shell/raster-frame readiness. Compilation, dependency preparation and installation are outside the measurement. Startup OS/native caches remain uncontrolled and frame-report delivery makes readiness an upper bound on the first usable frame.
- `navigation.switch_route` runs 20 real ViewModel route changes with actual preference commit and a subsequent rasterized frame. `shortcuts.save` runs 20 real six-slot edits/saves, alternating two fixed layouts. These are explicitly ViewModel-command measurements; pointer/keyboard dispatch and editor opening/closing are excluded.
- Workflow latency uses monotonic action-start to the matching frame's raster finish, excluding Flutter callback batching. Resource windows include host marker delivery and frame-report waiting. See the [runner contract and limits](../../tool/dev_dashboard/README.md).
- `orders.process`, `catalog.add_item` and `sales.add_item` are planned/unimplemented registry entries and cannot run. A presentation-only toast is not treated as a business operation. Future major features require their own stable case, approved actual workflow, isolated fixture, scenario version and verification.
- Profile caching includes source, assets, native configuration, lockfile, mode, SDK and binary identity. An overwritten launcher/AOT framework forces rebuild; changed source/tooling during build/measurement fails closed.
- Each child owns/deletes only its fresh temporary fixture and exits itself. The generic runner's timeout cleanup is limited to its own child process group. Abrupt termination can leave only that isolated temporary fixture; production/development account locations are never opened by this harness.

## Verification

- Full Flutter suite: **151 passed** (147 existing plus four new benchmark regressions).
- Flutter analysis: **no issues**.
- App runner/registry/cache Python tests: **3 passed**.
- macOS profile build and real direct-process startup/navigation/six-slot runs passed. Final machine/result details are retained in `outputs/dev-dashboard/profile-baseline-final.json`; earlier `profile-baseline.json` is preliminary and superseded for final evidence.
- Actual target: macOS 27.2, Apple M1 Pro, arm64; Flutter 3.47.8 / Dart 3.13.7; profile build. RAM is direct-process sampled resident peak in decimal MB; CPU 100% means one logical core. No performance target, regression budget or improvement is claimed from these baselines. Other platforms and physical/mobile performance are unmeasured.

## Complications and prevention

1. An initial broad combined documentation read returned truncated output. Relevant current rules/status/contracts were subsequently inspected in bounded sections. Prevention: consult the existing A01 guidance and use bounded relevant sections rather than combining entire project catalogs.
2. A second Flutter test was accidentally started while the first prepared native assets. The second command failed `lipo ... File exists`; the first completed its four tests. Subsequent Flutter commands ran strictly sequentially; app/shell 72 tests and the full 151-test suite passed. Prevention: hold one Flutter tool slot through completion, including native asset preparation; do not start a duplicate command while its session is active. No global build cache or pre-existing files were deleted.
3. The first profile compile exposed a missing `FrameTiming` import; importing the explicit `dart:ui` timing types repaired compilation. Analysis then identified one unused import and three style issues; all were fixed and analysis passed before final measurement.
4. Awaiting frame-timing callback delivery would have inflated workflow latency by callback batching. The final implementation uses the matching raster-finish timestamp and rejects incompatible clocks. Startup retains the explicitly documented host-observed readiness upper bound.

Independent review, project tracker integration and sanitized project-memory delivery belong to the Lead's linked dashboard task. This log does not claim those steps passed. No commit, merge, publication or deployment was performed by this app benchmark worker.
