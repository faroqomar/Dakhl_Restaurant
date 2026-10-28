# 0017 — Isolated Flutter development baseline

Status: implemented locally; review/CI/merge/release evidence is separate. Date:2026-10-28.

## Decision and boundaries

Implement phase00 at the project root with Flutter3.47.8/Dart3.13.7, exact direct package pins and a committed lockfile. Native application ID is `com.eros.dakhlrestaurant.phase00`, display name **Dakhl_Restaurant Dev**. Default `lib/main.dart` is an offline Arabic RTL blank shell; technical capability controls require the separate `lib/platform/probe_main.dart` entrypoint. No product screens, restaurant accounts, migrations or cloud services are connected.

Views render a ViewModel's observable operation state. `lib/capabilities/` owns platform-neutral contracts, bounded synthetic schema and the development repository; `lib/platform/` owns plugin adapters and the opt-in probe. Cancellation and failure are distinct; overlapping ViewModel operations are rejected and stale generated PDFs are invalidated.

The owned development child directory is `dakhl_restaurant_phase00_devprobe`. Its synthetic schema and4096-byte accepted-payload limit are not a restaurant-account format. The repository publishes immutable revisions, preserves previous committed bytes on failure, deduplicates identical retries, refuses unowned/symlink/legacy roots and fails closed on a corrupt newest revision. This is a capability prototype, not phase02 production persistence or a promise of power-loss durability or coordinated cross-process writers.

## Platform candidates and typography

Exact candidate pins: `file_picker13.3.0`, `path_provider2.1.6`, `path1.9.1`, `pdf3.13.1`, `printing5.15.1`. Native storage and PDF generation/raster passed on macOS, Android emulator and iPhone Simulator; native file/share/print evidence is listed per target in [build evidence](../phases/00-build-evidence.md). A successful build is not proof of every plugin operation.

The native picker can copy/materialize a selected document before Dart validates its size. Production bounded import, cache control, external-provider rollback and in-flight chooser recovery therefore remain unverified; do not promote these candidates to production-safe import/export based on wrapper tests.

Bundle unmodified Amiri Regular and its full OFL1.1 license/source SHA record for offline Arabic rendering/PDF embedding. This proves a licensed technical font path; it does not approve phase01 typography or change the frozen Geeza/Tahoma reference.

## Targets and verification

Configured minimums are AndroidAPI24, iOS15 and macOS12, derived from the generated Flutter scaffold and tested package configuration. Actual runtime evidence is Android17/API37 ARM64 emulator, iPhone18Pro/iOS27.0 Simulator and macOS27.2 ARM64. Minimum-version devices and IntelMac runtime are not certified.

The owner explicitly selected **“use the simulator in the mac”** for the phone check. This run uses iPhone Simulator; physical-device installation/signing is deferred and never described as passed. macOS debug/ad-hoc, Android debug and unsigned iOS Simulator builds do not establish release distribution or signing arrangements.

Fresh caller-supplied run nonces and explicit process-stop preconditions prevent stale restart evidence. Flutter integration runs must use `--no-uninstall` because the pinned runner otherwise deletes app data at teardown. Native PDF raster results are retained for human Arabic/RTL inspection. Share handoff is not delivery; no recipient is selected and no print job is submitted during probes.

Optimization benchmarks:N/A. CI checks format, analysis, tests and target builds; reference tests/frozen hashes remain a separate gate. No release workflow, credential changes, automatic merge or next-phase start is introduced.
