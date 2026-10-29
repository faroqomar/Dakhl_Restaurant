# Dakhl_Restaurant — Project documentation

Status: approved baseline documentation checked against source. Original date: 2026-10-16. Owner: restaurant/project owner. Scope source: the owner's conversation direction and selection of the ResturanetAccounting folder.

**All work here serves one restaurant only.** This project tracks its accounts, invoices, campaigns, ideas and application development.

| Topic | Reference |
| --- | --- |
| Agent rules, phase scope and execution status | [AGENTS](../AGENTS.md) · [PLANS](../PLANS.md) · [PHASES](../PHASES.md) · [PROMPTS](../PROMPTS.md) |
| Universal-rule sources and phase evidence | [Adoption](reference/workflow/README.md) · [Evidence index](phases/README.md) |
| Project purpose, implemented work and plans | [Project scope](reference/project-scope.md) |
| Flutter/Dart rebuild plan and phase screenshots | [12-phase MVP plan](planning/flutter-rebuild/README.md) · [Screenshot gallery](planning/flutter-rebuild/gallery.html) · [Consolidation map](planning/flutter-rebuild/phase-map.md) |
| Sales, inventory and shortcuts | [Usage guide](how-to/sales-inventory.md) |
| Run and use Dakhl_Restaurant | [Main guide](../README.md) |
| Accounting meanings and relationships | [Accounting rules](reference/accounting-rules.md) |
| Files, architecture, persistence, reports and tests | [Application reference](reference/application.md) |
| Follow work from idea to outcome | [Documentation and tracking](how-to/documentation.md) |
| Hindsight use, synchronization and recovery | [Memory guide](how-to/memory.md) |
| Ideas and improvements | [Idea register](planning/ideas.md) |
| Dine-in menu | [Menu and prices](planning/dine-in-menu.md) |
| Advertising campaigns | [Campaign register](planning/campaigns.md) |
| Decisions and rationale | [Decision register](decisions/README.md) |
| Changes and actual verification | [Work logs](log/README.md) |
| Templates for new records | [Templates](templates/README.md) |
| Agent instructions | [AGENTS.md](../AGENTS.md) |

## Project state

2026-10-28 organization: the [legacy application](../electron-reference/REFERENCE.md) is in electron-reference/ and the root is for the Flutter rebuild. The plan, screenshots and documentation remained in place. [Organization decision](decisions/0013-electron-reference-folder.md). Bare source paths below refer to that reference application.

The existing Dakhl_Restaurant application is local and built with Electron; its `package.json` version is 1.12.0 and account schema in `app/ui/model.js` is 11. Accounts and invoices are implemented in source. Campaigns and ideas are documented tracking registers, with no corresponding current UI module. An installed version or published campaign requires independent verification evidence.

## Reference precedence

### Planned rebuild — 2026-10-27

The owner selected Flutter and Dart for macOS, Android and iPhone, locally without synchronization, with backups/import, PDFs and normal printing. The [plan](planning/flutter-rebuild/README.md) and [decision 0011](decisions/0011-flutter-rebuild-baseline.md) establish scope; the phase00 technical baseline has started. The reference application remains Electron and product screens are not implemented. Current design is the reference until the owner approves a phase-specific change.

Current owner direction defines the request. Current documentation/source define decisions and behavior. A decision record explains why, a work log establishes what happened, and Hindsight helps find both. Memory replaces neither the files nor actual implementation evidence.

Every substantive document records state, date, owner/source, verification evidence and open work. Empty templates are excluded from indexing. Private restaurant details and financial data stay in their private locations and are not copied into documentation or memory.

Owner direction, 2026-10-28: develop Madar_Engine alongside the app, keeping shared source in the engine and consuming it here. [Ownership boundary](decisions/0018-madar-engine-boundary.md).

## Prevent repeated problems

[Observed failures, causes, remedies and prevention](how-to/repeated-problems.md) are maintained throughout each task under the owner's standing direction.

## Engine/consumer implementation contract

[Ownership, package use, documentation, safe diagnostics and verification](how-to/engine-consumer-contract.md) apply to every new phase and changed capability.
