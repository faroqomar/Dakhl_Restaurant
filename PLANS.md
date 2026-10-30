# Dakhl_Restaurant — project phases and scope

Execution update,2026-10-29: Phase01 approved development-preview scope is DONE after independent verification, exact revision approval and four linked merges. Phase00 technical prerequisites are closed; its broader historical completion remains separately scoped. See PHASES.md and the local Step6 record for actual outcomes and publication/release limits. The existing12phase definitions remain unchanged; Phase02 scope/design/implementation planning is in progress, with no implementation or owner approval inferred.

Historical initialization status,2026-10-28: Phase00 baseline was under verification and product UI implementation had not started.

Read [AGENTS.md](AGENTS.md) for mandatory workflow and [PHASES.md](PHASES.md) for live status/evidence. This file is the binding phase index and incorporates the scope and acceptance requirements in each linked detailed phase file. The [visual plan](docs/planning/flutter-rebuild/plan.html) and [179-image library](docs/planning/flutter-rebuild/gallery.html) remain in place.

## Phase definitions

| Phase | Name and detailed scope | Dependencies | Outcome |
| --- | --- | --- | --- |
| 00 | [Baseline and delivery setup](docs/planning/flutter-rebuild/phases/00.md) | None | A runnable, isolated Flutter app on macOS, Android and iPhone, with a frozen specification. |
| 01 | [Design system, navigation and interaction shell](docs/planning/flutter-rebuild/phases/01.md) | 00 | A responsive Arabic component system and complete navigation shell with shortcuts and safe form interactions. |
| 02 | [Local accounts, validation and safe persistence](docs/planning/flutter-rebuild/phases/02.md) | 00, 01 | Accounts can be saved, reopened and recovered safely while offline. |
| 03 | [Sellable products and inventory](docs/planning/flutter-rebuild/phases/03.md) | 01, 02 | The sellable catalog and quantity ledger work end to end. |
| 04 | [Cash sales, saved receipt, drafts and held orders](docs/planning/flutter-rebuild/phases/04.md) | 01, 02, 03 | A cashier can build, suspend, recover and complete a ticket safely, with a saved receipt and one stock/cash effect. |
| 05 | [Sales history, returns and voids](docs/planning/flutter-rebuild/phases/05.md) | 02, 03, 04 | Saved sales can be found, inspected, refunded or corrected with faithful accounting. |
| 06 | [Daily accounting, expense categories and cashbox](docs/planning/flutter-rebuild/phases/06.md) | 01, 02, 05 | Categories, source-funded expenses, daily balances, chicken counts, cash movements and daily-to-cashbox transfers reconcile as one workflow. |
| 07 | [Suppliers, debts, materials and prices](docs/planning/flutter-rebuild/phases/07.md) | 01, 02, 06 | Supplier liabilities and a shared materials/default-price catalog are ready for purchasing. |
| 08 | [Purchase invoices, analysis and supplier payments](docs/planning/flutter-rebuild/phases/08.md) | 02, 06, 07 | Invoices, quantity/price analysis and partial/full settlement work together, including atomic invoice-with-payment. |
| 09 | [Settings, backups, import and recovery](docs/planning/flutter-rebuild/phases/09.md) | 01, 02, 04, 06, 08 | A user can configure the app and safely move or restore all finalized records. |
| 10 | [Statements, day review, PDF reports and printing](docs/planning/flutter-rebuild/phases/10.md) | 03, 04, 05, 06, 07, 08, 09 | The owner can review paid spending and the restaurant day, then export/share/print every operational report. |
| 11 | [Complete MVP verification, migration rehearsal and release](docs/planning/flutter-rebuild/phases/11.md) | 00–10 | Installable MVP builds on all three platforms, with end-to-end evidence and rollback instructions. |

## Required execution gates

For each phase, the Lead records Git isolation, assigned agents and applicable design requirements in PHASES.md. A read-only Planner defines the bounded work, tests, meaningful performance measurements and CI needs. UI work first validates the suitable reference in Penpot and obtains approval; non-UI work records Design: N/A. Workers implement with meaningful tests written before behavior changes. An independent Reviewer verifies the result and fixes are re-verified.

Create a traceable PR, satisfy mandatory quality gates, obtain user approval before merging, then perform applicable release/rollback validation. Update PHASES.md and evidence in docs/phases/. DONE requires the approved, merged PR and every applicable check; stop afterward until the owner starts the next phase.

## Scope boundaries

Preserve all existing phase work items, financial invariants, failure/recovery checks and screenshots. All platforms remain macOS, Android and iPhone; data remains offline with backup/import. Exact current-design reproduction remains the default, subject to phase-specific owner edits and the Penpot design approval gate. The reference app is for consultation, not the destination for new Flutter features.

Changes to phase definitions must update this index, linked detail, tracker and generated views together. The plan builder is a publication helper, not independent authorization to change scope or reset status.

## Shared engine ownership —2026-10-28

Develop Madar_Engine alongside these phases. Implement shared contracts and reusable capabilities in its independently owned packages; app phases consume them and retain restaurant workflows/UI. [Decision0018](docs/decisions/0018-madar-engine-boundary.md) establishes standing engine/app source ownership for all future work and supersedes the earlier no-implied-engine-dependency assumption. Each new capability still requires its own bounded plan and authorization. No cloud/auth/multitenancy, new financial policies or phase01 implementation is added.

## Development support — owner request 2026-10-29

Maintain a minimal private development dashboard and [versioned delivery/per-operation measurements](docs/how-to/versioning-and-performance.md) alongside approved phases. Shared measurement tooling stays in Madar; app instrumentation/fixtures stay here. This support initiative neither adds a restaurant feature nor advances the 12-phase plan. Each future major feature registers its own real speed/RAM/CPU scenario; planned operations cannot claim measured readiness.

## Approved source integration — 2026-10-29

[Phase 01 / development dashboard Step6 outcome](docs/phases/01-step6-completion.md) records exact owner-approved revisions, actual merges, independent/CI evidence, compatible engine pin and rollback limits. These tracker/completion amendments are local records, not additional unapproved changes to main. No next phase or deployment.
