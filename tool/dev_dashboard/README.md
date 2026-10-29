# Dakhl development benchmarks

These opt-in cases run the actual macOS **profile** app in a new process with a fresh temporary Madar preferences database. The normal app entrypoint, installed app, restaurant accounts and existing development-app database are never opened by the harness. Version remains `0.0.0+1`; this tooling does not advance Phase 01 or resolve reader/CI/release gates.

```sh
python3 tool/dev_dashboard/run_benchmarks.py \
  --engine-tools-root /path/to/reviewed/Madar_Engine \
  --case app.startup --output outputs/dev-dashboard/startup.json
```

Repeat `--case` for several operations, or use `--case all-ready` (also the default). `--iterations 1` through `100` overrides the registry defaults. Single-case output is one result object; multiple-case output is `{schemaVersion: 1, results: [...]}`. A sanitized JSON result is written atomically to `--output` and stdout; preparation diagnostics use stderr. A failed/unavailable measurement returns a nonzero exit code and never becomes a passing baseline.

The supplied engine-tools root supplies Madar's separate development-only `tool/dev_benchmarks/benchmark.py` API. It must be independently reviewed before delivery. It is not a Dart runtime dependency or a reason to change the app's exact runtime engine revision. The runner checks the current actual dependency resolution with `scripts/check-engine.py` before measuring. The app continues to consume exact `6d4ae39f35b005dfa1123a82c6df316901e1e1e4` through its existing sibling path.

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
