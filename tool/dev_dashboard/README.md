# Dakhl development benchmarks

These opt-in cases run the actual macOS **profile** app in a new process with fresh synthetic Madar preferences or account/workspace stores, according to the registered scenario. The normal app entrypoint, installed app, restaurant accounts and existing development-app database are never opened by the harness. Version remains `0.0.0+1`; this tooling does not advance Phase 01 or resolve reader/CI/release gates.

```sh
python3 tool/dev_dashboard/run_benchmarks.py \
  --engine-tools-root /path/to/reviewed/Madar_Engine \
  --case app.startup --output outputs/dev-dashboard/startup.json
```

Repeat `--case` for several operations, or use `--case all-ready` (also the default). `--iterations 1` through `100` overrides the registry defaults. Single-case output is one result object; multiple-case output is `{schemaVersion: 1, results: [...]}`. A sanitized JSON result is written atomically to `--output` and stdout; preparation diagnostics use stderr. A failed/unavailable measurement returns a nonzero exit code and never becomes a passing baseline.

The supplied engine-tools root supplies Madar's separate development-only `tool/dev_benchmarks/benchmark.py` API. It must be independently reviewed before delivery. It is not a Dart runtime dependency or a reason to change the app's exact runtime engine revision. The runner checks the current actual dependency resolution with `scripts/check-engine.py` before measuring. The exact runtime revision and package versions come from `engine-dependency.json` and verified resolved package sources; the measurement-tool revision is recorded separately.

`operations.json` is the app's operation registry. Ready cases:

- `app.startup`: five independent process launches, each from host process creation to observed usable shell readiness, including native startup, fresh database bootstrap and an actual rasterized frame. Build, dependency resolution and installation are excluded. Native/OS caches are uncontrolled. The readiness observation includes Flutter frame-timing callback delivery and stdout receipt; it is an upper bound on first usable-frame time, not a precisely timestamped first pixel. Each child reports one zero timing sentinel that the host deliberately replaces with its own process-to-ready measurement.
- `navigation.switch_route`: 20 actual shell ViewModel commands alternating Inventory and Sales. Each includes a real isolated preference commit and the next completed frame. This measures command-to-render latency, including native storage; it does not measure pointer/keyboard dispatch.
- `shortcuts.save`: 20 actual shell ViewModel six-slot edits/saves, alternating two explicit synthetic layouts and verifying acknowledgement before a subsequent frame. Editor opening/closing and native input dispatch are excluded.

Workflow timing uses Dart's monotonic timeline start and the matching Flutter frame's raster-finish timestamp. Frame timing callback batching is excluded from the elapsed sample. A missing frame, incompatible timestamp, failed bootstrap, rejected commit, wrong protocol or missing resource sample fails the run. Resource windows run from host receipt of start/end markers, including callback-reporting idle time, so CPU/RAM windows are broader than individual workflow latency samples. Startup resources cover process creation through readiness receipt. RAM is the sampled direct-process resident peak in decimal MB, not a guaranteed instantaneous allocation peak. CPU 100% means one logical core; percentages can exceed 100%. The generic Madar tool owns the native sampler and aggregation semantics.

The benchmark app deletes only its freshly created `dakhl-bench-<run>-<pid>-…` temporary directory and exits itself. The generic runner terminates only its own process group on failure/timeout. An abrupt forced termination can leave that run's isolated temporary directory; it never points to production data and is not a reason to delete any broad application directory.

The profile build cache keys app Dart/assets/native configuration, lockfile, profile mode, entrypoint and SDK identity. Missing/replaced launcher or AOT binaries, or key changes, trigger a rebuild, excluded from measured timing. Source commit, dirty flag, source fingerprint, fixture/scenario version, engine revision, machine and tool identities accompany every result. Compare results only when the generic comparability key agrees; there is no invented performance budget or optimization claim.

`orders.process`, `catalog.add_item` and `sales.add_item` are explicitly planned and cannot run. Presentation/toast behavior is not a business operation benchmark. Every later major feature needs a stable separate case ID, real approved workflow, isolated fixture, scenario version and fresh verification before its registry status becomes ready. Planned phase references follow PLANS.md (catalog 03; sales/orders 04) and do not approve those phases.

Verification:

```sh
flutter test --no-pub test/app/performance_test.dart
python3 -m unittest discover -s tool/dev_dashboard/tests -v
```

Use one Flutter command at a time in this checkout. Concurrent native asset preparation can collide on the generated SQLite universal binary.

## Current console setup

Use the live standalone dashboard project, not the frozen review snapshot in outputs. Copy its runner-config.example.json to ignored runner-config.json. Set app_root, engine_root and engine_tools_root to the intended checkouts. Also set the fourth absolute placeholder, data_dir, to the local dashboard var directory, or remove data_dir to use the default ignored var directory. Do not leave any /absolute/path placeholder. Start Dashboard.command in the authoritative project is executable; the review snapshot preserves its original mode for provenance only.

Profile cache identity includes active Xcode version and macOS SDK build as well as Flutter/Dart, app/native inputs and the verified runtime-engine identity. Toolchain changes force a build; changes during build or measurement reject the result. Results carry the same toolchain identity so older conditions are not silently compared.

## Phase02 account/workspace profiles

The opt-in Phase02 entrypoint exercises `accounts.open`, `accounts.save`,
`accounts.migrate_legacy`, `accounts.replace`, `accounts.recover_previous` and
`workspace.save_restore` through the actual consumer codec/repository/ViewModel
and rendered account surface. Profiles `small`, `medium` and `largest` contain
10, 1,000 and 10,000 synthetic cash transactions. Account byte sizes are recorded
and bounded independently for input/output. Workspace fixtures contain one active
and 40 held drafts (about 3.4KiB); they do not establish near-limit workspace or
production capacity. Each elapsed sample excludes fresh-store preparation/reset,
includes the consumer command and deliberate final repaint, and ends at the
matching fresh native frame's raster-finish timestamp. Later timing callback
delivery is excluded from elapsed latency but remains in the aggregate host
resource window with reset, rendering setup and teardown. Initial rendering waits
for root/warm-up and public first-raster readiness before selecting a fresh native
frame-ID baseline. Readiness and the subsequent matching native raster event
share one ten-second timeout; framework post-frame/first-raster readiness alone
cannot complete the observation. This initial bootstrap remains outside operation
elapsed latency and inside the existing aggregate resource window for later
iterations. Normal app initialization is unaffected. No mobile measurement,
performance target, optimization or reliability claim follows from these cases.

## Failure-only context — app owned

A failed Phase02 producer best-effort writes an exclusive, flushed companion file
`<operation>-<profile>-<32hex-run>.json.failure.json` beside the existing task-owned
fixture-manifest destination only after retaining successful exclusive creation,
flush and validated synthetic-content ownership binding. Filename or matching
pre-existing content grants no authority. The bound original must remain unchanged.
Pre-ownership failures record no companion (capture can remain missing/rejected),
and the original benchmark failure still stands. Diagnostic I/O is bounded
to two seconds, cannot change a passing result, and cannot replace the original
protocol error if unavailable. Normal app entrypoints and engine runtime APIs are
unaffected.

The context has exactly these 11 fields: `schemaVersion` (1), `operationId`,
`profile`, `runId`, `requestedIterations`, `attemptedIteration`,
`completedSampleCount`, `stage`, `errorKind`, `state` and `failureCode`.
Operation/profile/run are bound to the current command and filename. Attempt is
zero before iteration processing, otherwise one-based; completed sample count is
the number of producer samples that passed command/raster/clock checks, not the
host's reported iterations. Both are bounded by the requested 1–100 iterations,
with at most one in-flight attempt. Stages, error kinds, states and codes use
static allowlists; unknown codes become `redacted`. No exception message, stack,
account payload, filesystem path, service URL or arbitrary extra field is logged.

The app runner collects at most 4KiB through existing directory-descriptor,
no-follow and exclusive-evidence guards. Duplicate JSON keys, unknown fields,
foreign attempts, invalid types/counts and filesystem redirects are rejected.
Validated context and its SHA256 are linked by a separate app capture receipt in
`outputs/phase02/performance-diagnostics/`. The command writes a separate
`<output>.diagnostics.json` index only for failed/unavailable Phase02 measurements.
Capture status is `captured`, `missing`, `rejected` or `unavailable`; failures to
write/copy metadata preserve the original failed measurement and nonzero exit.
The generic Madar result/protocol/metrics are unchanged. Zero host-reported
iterations does not prove zero producer iterations when a failed host run omits
partial samples.

Focused verification:

```sh
flutter test --no-pub test/platform/phase02_performance_test.dart
python3 tool/dev_dashboard/tests/test_app_runner.py
```

Failure metadata is diagnostic evidence, not a passing benchmark or a substitute
for an independently reviewed current-source measurement cohort. Historical
failed and partial results remain at their original source identities.
