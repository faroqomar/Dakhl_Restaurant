Current local validation: [2026-11-09 successor closeout](log/2026-11-08-remaining-completion-closeout.md) records1,432full-suite checks, final affected rechecks, three-target native execution,65measured operations, normal builds and remaining acceptance gates.

## Completion phase — 2026-11-05

[One-phase scope, dependencies, references and readiness](phases/completion-scope-readiness.md). Original phase IDs remain work-package references. The owner authorized build, review and verification; see the current [tracker](../PHASES.md), [retained-plan matrix](phases/completion-review-stage-matrix.md) and [opening implementation](log/2026-11-08-supplier-opening-amendment-build.md). Native acceptance and delivery remain distinct.

**Historical delivery snapshot (2026-10-31).** [Engine PR #6](https://github.com/faroqomar/Madar_Engine/pull/6) is merged as `b0db782aa1763e5bbb20bd735f12b9ba5dc0027c`; the consumer now pins reviewed engine `899678fa0b85807850e626db69b3291b8a7b7b64`. [App PR #9](https://github.com/faroqomar/Dakhl_Restaurant/pull/9) remains under final verification. The owner authorized in-scope fixes and verified paired merge; final consumer checks, native evidence and completion recording remain required. Earlier hosted results do not certify the new candidate. Optional Cubic review at the newer source was unavailable because billing was inactive; no latest-Cubic pass or billing change is claimed.

The 18-case / 360-sample Mac baseline remains historical at app 5a11 / runtime a6 / tool 63. The 5a11 iOS 27.0 simulator's 9/9 outcomes and 5095 Android Open/Save passes are also dated evidence, not verification of later app library/engine changes. The import attempt timed out; final-candidate native checks remain separate. The incident assessment accepts known synthetic-fixture loss as a non-blocking bounded-preview residual; retention/restoration is **not** verified. No app merge, Phase 02 DONE, release, deployment or next phase is claimed here. [Tracker](../PHASES.md) and [publication evidence index](phases/02-publication-evidence-index.md) own subsequent evidence.

The dated summaries below preserve earlier access, approval and verification states; they are historical rather than current instructions.

Step5 publication preparation, 2026-10-30: **DRAFT / NOT MERGE-READY**. The owner requested reviewable pull requests; publication and hosted-check results are recorded in [the Step5 delivery record](phases/02-step5-delivery.md). Android preservation failed and prior installed-app data retention remains unverified; Android cancellation and current iOS verification remain open. No merge, release, target mutation or next phase is authorized. Earlier Step3/Step4 publication statements below are dated historical records.

Step4 final local review, 2026-10-30: Phase02 BLOCKED / NOT READY. Source fixes independently clear at app5a11c66d/runtimea6a8ebdd;529 app checks and18 Mac cases/360samples pass. Android preservation failed through automatic uninstall/reinstall; prior app-data retention unverified, cancellation/iOS/hosted CI/owner gates open. [Current evidence and incident](phases/02-step4-review.md). Earlier Step3 results stay historical; no DONE/publication/merge/release.

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
| Sales ticket/catalog ViewModel (mounted portable UI; live activation gated) | [API and lifecycle](reference/sales-view-model.md) |
| Run and use Dakhl_Restaurant | [Main guide](../README.md) |
| Accounting meanings and relationships | [Accounting rules](reference/accounting-rules.md) |
| Durable sale/return/void API (isolated candidate; runtime activation pending) | [Command setup, examples, errors and limits](reference/durable-sales-commands.md) |
| Durable spending/purchase API (reviewed portable candidate; live activation gated) | [Command setup, examples, errors and limits](reference/durable-spending-commands.md) |
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

The owner selected Flutter and Dart for macOS, Android and iPhone, locally without synchronization, with backups/import, PDFs and normal printing. The [plan](planning/flutter-rebuild/README.md) and [decision 0011](decisions/0011-flutter-rebuild-baseline.md) establish scope; the retained phase plans define its scope. The Flutter product screens now have mounted source implementations and portable operational composition; the Electron application remains the frozen reference. Current design is the reference until the owner approves a phase-specific change.

Current owner direction defines the request. Current documentation/source define decisions and behavior. A decision record explains why, a work log establishes what happened, and Hindsight helps find both. Memory replaces neither the files nor actual implementation evidence.

Every substantive document records state, date, owner/source, verification evidence and open work. Empty templates are excluded from indexing. Private restaurant details and financial data stay in their private locations and are not copied into documentation or memory.

Owner direction, 2026-10-28: develop Madar_Engine alongside the app, keeping shared source in the engine and consuming it here. [Ownership boundary](decisions/0018-madar-engine-boundary.md).

## Prevent repeated problems

[Observed failures, causes, remedies and prevention](how-to/repeated-problems.md) are maintained throughout each task under the owner's standing direction.

## Engine/consumer implementation contract

[Ownership, package use, documentation, safe diagnostics and verification](how-to/engine-consumer-contract.md) apply to every new phase and changed capability.

## Phase execution, delays and automation

[Required audit procedure](how-to/phase-execution-audit.md), [journal template](templates/phase-execution.md) and [Phase01 partial retrospective/live journal](log/phase-01-execution.md). Every phase records actual work, failures, wait causes, unknown costs and candidates for reliable automation.


Development campaigns: [source-bound workflow](how-to/development-campaigns.md), [fixture/device/delivery preflight](how-to/task-preflight.md), [verified tooling outcome](log/2026-11-04-tooling-hardening.md).
