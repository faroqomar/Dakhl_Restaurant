# Dakhl_Restaurant — Flutter rebuild workspace

Current project name: **Dakhl_Restaurant**. The old Electron app name and storage identifiers are preserved only for compatibility and frozen reference evidence.

This project root is reserved for the Flutter/Dart rebuild for macOS, Android and iPhone. Flutter implementation has not started.

Workflow: [AGENTS.md](AGENTS.md) · [PLANS.md](PLANS.md) · [PHASES.md](PHASES.md) · [six reusable prompts](PROMPTS.md). Phase 00 is in design review; phases 01–11 remain TODO. The tracker records actual execution and approval evidence.

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

## Use the reference

```sh
npm --prefix electron-reference test
```

The original app instructions are preserved in [electron-reference/README.md](electron-reference/README.md). Normal app launch may open restaurant accounts; use isolated fixtures for development verification. The reference folder is not a separate Git repository; Git history remains at this project root.

The plan, screenshots and shared documentation were **not moved** into the reference folder. Read [the folder-layout decision](docs/decisions/0013-electron-reference-folder.md) before changing this structure.
