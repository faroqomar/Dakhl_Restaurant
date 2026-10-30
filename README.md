Current Step5 delivery, 2026-10-30: **APP PUBLICATION ACCESS-BLOCKED / NOT MERGE-READY**. GitHub rejected the push of local candidate `0b75862a87aad3ae044ed0e3df4c6e3acfd7cd0b` because the active OAuth credential lacks workflow scope; no app PR or hosted app checks exist. [Engine draft PR#6](https://github.com/faroqomar/Madar_Engine/pull/6) is published; its CI is ongoing, not passed here. [Delivery evidence](docs/phases/02-step5-delivery.md) preserves tested app5a11/runtimea6/tool63 and all Android preservation/iOS blockers. No credentials, permissions, CI requirements or target state were changed; no merge, release or next phase. Earlier records below retain their original dated scope.

Step4 final local review, 2026-10-30: Phase02 BLOCKED / NOT READY. Source fixes independently clear at app5a11c66d/runtimea6a8ebdd;529 app checks and18 Mac cases/360samples pass. Android preservation failed through automatic uninstall/reinstall; prior app-data retention unverified, cancellation/iOS/hosted CI/owner gates open. [Current evidence and incident](docs/phases/02-step4-review.md). Earlier Step3 results stay historical; no DONE/publication/merge/release.

Current Phase02 update, 2026-10-30: bounded accounts/validation/persistence and workspace presentation are implemented locally at69fef624, consuming reviewed Madar runtimeea9 and measurement tool63. Final462 tests/analysis, three-target persistence and18 operation baselines passed within documented limits. [Build and remaining gates](docs/phases/02-step3-build.md). Earlier dated execution descriptions below are historical; no production release or next phase.

# Dakhl_Restaurant — Flutter rebuild workspace

Current project name: **Dakhl_Restaurant**. The old Electron app name and storage identifiers are preserved only for compatibility and frozen reference evidence.

This root contains the offline Arabic RTL development app for macOS, Android and iPhone Simulator. Phase 01 now adds the approved component/navigation shell and durable device-only route/six-shortcut preferences through Madar. Sales/invoice layouts use synthetic presentation fixtures; production account and later business workflows are not implemented.

Workflow: [AGENTS.md](AGENTS.md) · [PLANS.md](PLANS.md) · [PHASES.md](PHASES.md) · [six reusable prompts](PROMPTS.md). Phase 00 technical prerequisites are verified; Phase 01 implementation/verification is in progress; phases 02–11 remain TODO. The tracker records actual execution and approval evidence.

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

Madar_Engine is developed alongside this app and owns shared contracts/native adapters. Keep both independent repositories as sibling folders; app `pubspec.yaml` uses relative package paths and `engine-dependency.json` pins the engine commit. This implementation worktree uses a sibling symlink to the reviewed Phase01 engine build tree, with no copied engine source. Read [ownership and setup](docs/decisions/0018-madar-engine-boundary.md) before updating the dependency. Hosted CI also needs the independent engine source published/configured; local success does not satisfy that gate.

## Flutter development

Pinned SDK: Flutter 3.47.8 / Dart 3.13.7. Development app ID: `com.eros.dakhlrestaurant.phase00`; display name: **Dakhl_Restaurant Dev**. It is separate from the preserved application and its data.

```sh
flutter pub get --enforce-lockfile
python3 scripts/check-engine.py
flutter test --no-pub
flutter analyze --no-pub
flutter run -d macos
```

The default entrypoint opens the Phase01 navigation/component shell. The separately selected Phase00 development probe still exercises synthetic platform capabilities:

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

Phase 01 setup, schema, guards and limits: [shell contract](docs/reference/phase01-shell-contract.md). iPhone interactive controls use Device Hub 27.1 in the installed Xcode, while `simctl` remains the lifecycle command. The locally reviewed engine candidate is not published by these changes.
