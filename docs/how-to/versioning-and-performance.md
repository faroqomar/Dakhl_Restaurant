# Versioning and development performance

Owner request: 2026-10-29. This applies to future Dakhl_Restaurant development and delivery. It does not approve a release or merge, advance Phase 01, or change business policies.

## Version method

`pubspec.yaml` is the app version authority: `MAJOR.MINOR.PATCH+BUILD`. The current candidate remains **0.0.0+1**, unreleased. Do not invent a delivered version for existing work.

- Increase major for an incompatible delivered change, minor for a backward-compatible feature, patch for a fix. During 0.x development, describe any compatibility break explicitly; do not silently treat it as safe.
- Every delivered binary increases the positive build number, including a rebuild of the same semantic version. Documentation-only work may retain the app version with a reason in the PR.
- Choose the candidate during PR preparation, record the previous delivered version, and run `python3 scripts/release_version.py prepare --version X.Y.Z+N`. This changes only the explicit pubspec version and refuses a downgrade or reused build. It performs no Git action.
- Validate with `python3 scripts/release_version.py check` and, for delivery, `python3 scripts/release_version.py check --previous PREVIOUS_VERSION+BUILD`. CI validates the format and version-tool regressions. The previous delivered version must be supplied from the actual approved release record; CI does not infer one from nonexistent tags.
- Before a future authorized push, record source commit, dirty-source fingerprint when applicable, runtime engine pin, test/build results and operation measurements in the linked trackers/PR. Recheck the final candidate after a version change; a new build is a new artifact.
- Merge only the independently reviewed exact candidate after required checks and explicit owner approval. Create `vX.Y.Z` only for the approved merged release commit, with build number, changelog and rollback artifact recorded. Never move an existing tag. A merge or tag is not proof of installation or release acceptance.

## Separate benchmarks for major features

Register every major implemented feature in `tool/dev_dashboard/operations.json` with a stable operation ID, phase, scenario version, real workflow, isolated fixture and meaningful sample count. Measure elapsed time (median and p95), sampled process peak RAM and process CPU. Include app version, exact app/engine/tool provenance, dirty fingerprints, hardware, OS, build mode, workload and sampling interval. Never benchmark a placeholder/toast as a real order or save.

The registry currently contains nine ready macOS profile cases: `app.startup`, `navigation.switch_route`, `shortcuts.save`, `accounts.open`, `accounts.save`, `accounts.migrate_legacy`, `accounts.replace`, `accounts.recover_previous` and `workspace.save_restore`. Ready means an implemented measurable scenario; each result retains its exact source revision and does not certify a later candidate. Orders, catalog creation and adding a sales item remain planned until their actual workflows exist. Future report or other operations require their own scenarios when implemented. Mobile measurements need their own platform adapter and real target evidence; macOS results do not prove phone performance.

Startup launches a fresh process and observes usable-shell readiness; compilation/install are excluded, OS cache state is uncontrolled, and frame-report delivery contributes to readiness. Workflow timing starts at actual ViewModel command and ends at completed raster frame, including real isolated preferences persistence; native input dispatch is excluded. CPU/RAM cover the marker window, including frame-report idle time. Very short windows and sampled RAM have resolution limits. See the [scenario contract](../../tool/dev_dashboard/README.md).

Use a first successful run as baseline and compare only matching workload/tool/hardware/OS/build/sample conditions. Keep raw results locally. Display a delta, not a pass/fail performance target, until a numeric budget is explicitly agreed. A change in workload or protocol creates a new comparison series. No optimization claim exists in this initiative.

## Minimal dashboard

Private Site: [Dakhl Development](https://dakhl-development-dashboard.eros-6.chatgpt.site). Its source and loopback-only runner are in `/Users/eros/Dev/Eros_Projects/Dakhl_Development_Dashboard` with setup in that project's README.

Progress reads the app tracker. Checks launches allowlisted local app/engine tests. Performance launches only ready app scenarios, retaining history and comparable baselines. Hosted snapshots are dated evidence; a running, paired local runner is required for fresh execution. No restaurant account data, arbitrary command execution, Git push or merge is exposed.

Madar owns generic measurement/protocol/resources; Dakhl owns real UI/ViewModel/storage fixtures and scenario meaning. The exact reviewed runtime dependency is recorded in `engine-dependency.json` and verified by the source checker; each test/build/measurement receipt records the revision it actually used. Separate development tooling has its own recorded revision and does not repin runtime dependencies. Keep each project's evidence and memory separate.
