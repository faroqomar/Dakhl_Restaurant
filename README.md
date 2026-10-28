# Dakhl_Restaurant — Flutter rebuild workspace

Current project name: **Dakhl_Restaurant**. The old Electron app name and storage identifiers are preserved only for compatibility and frozen reference evidence.

This root contains the phase 00 Flutter development baseline for macOS, Android and iPhone Simulator. The default app is a blank offline Arabic RTL shell; product screens and production account persistence are not implemented.

Workflow: [AGENTS.md](AGENTS.md) · [PLANS.md](PLANS.md) · [PHASES.md](PHASES.md) · [six reusable prompts](PROMPTS.md). Phase 00 is under build verification; phases 01–11 remain TODO. The tracker records actual execution and approval evidence.

| Location | Purpose |
| --- | --- |
| [electron-reference/](electron-reference/REFERENCE.md) | Preserved Electron app source, dependencies, tests and app-specific tools |
| [12-phase rebuild plan](docs/planning/flutter-rebuild/plan.html) | Current implementation sequence and acceptance checks |
| [Screenshot library](docs/planning/flutter-rebuild/gallery.html) | All 179 frozen reference captures, grouped by current phase |
| [Design reference](docs/planning/flutter-rebuild/design-system.html) | Current visual language to reproduce |
| [docs/](docs/README.md) | Shared project rules, accounting definitions, decisions and logs |
| outputs/, dist/, design/ | Existing visual references, generated evidence and build/design artifacts; retained at their original paths |
| scripts/ | Shared memory and rebuild-plan/capture tooling |

The current design and financial behavior remain the baseline. Work is offline for one restaurant; backup/import is manual transfer, not synchronization. Preserve historical account records, with no testing in restaurant accounts.

## Engine and app development

Madar_Engine is developed alongside this app and owns shared contracts/native adapters. Keep both independent repositories as sibling folders; app `pubspec.yaml` uses relative package paths and `engine-dependency.json` pins the engine commit. This nested Codex worktree uses a sibling symlink to the canonical engine, with no copied engine source. Read [ownership and setup](docs/decisions/0018-madar-engine-boundary.md) before updating the dependency. Hosted CI also needs the independent engine source published/configured; local success does not satisfy that gate.

## Flutter development

Pinned SDK: Flutter 3.47.8 / Dart 3.13.7. Development app ID: `com.eros.dakhlrestaurant.phase00`; display name: **Dakhl_Restaurant Dev**. It is separate from the preserved application and its data.

```sh
flutter pub get --enforce-lockfile
python3 scripts/check-engine.py
flutter test --no-pub
flutter analyze --no-pub
flutter run -d macos
```

The default entrypoint is blank. The explicitly selected development probe exercises synthetic platform capabilities:

```sh
flutter run -d macos -t lib/platform/probe_main.dart
```

Use only new disposable synthetic files in native dialogs. [Native probe/restart instructions](integration_test/README.md) explain required fresh nonces, `--no-uninstall` and limits. [Build evidence](docs/phases/00-build-evidence.md) separates tests/builds, runtime results and pending checks. Plugin candidates are not production account import/export infrastructure. [Development baseline decision](docs/decisions/0017-phase00-development-baseline.md).

## Use the reference

```sh
npm --prefix electron-reference test
```

The original app instructions are preserved in [electron-reference/README.md](electron-reference/README.md). Normal app launch may open restaurant accounts; use isolated fixtures for development verification. The reference folder is not a separate Git repository; Git history remains at this project root.

The plan, screenshots and shared documentation were **not moved** into the reference folder. Read [the folder-layout decision](docs/decisions/0013-electron-reference-folder.md) before changing this structure.
