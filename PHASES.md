# Project Phase Tracker

Source of phase definitions: [PLANS.md](PLANS.md). Rules: [AGENTS.md](AGENTS.md). Adopted 2026-10-28 from the owner’s supplied tracker template.

## Statuses

TODO → DESIGN → PLANNING → BUILDING → REVIEW → VERIFYING → PR → DONE

Use BLOCKED when progress cannot continue and record the reason and required action. Skip inapplicable steps and record N/A. Branch, PR, design approval and verification are evidence fields, not assumed from status labels.

## Phases

| Phase | Name | Status | Branch | PR |
| --- | --- | --- | --- | --- |
| 00 | [Baseline and delivery setup](docs/planning/flutter-rebuild/phases/00.md) | PLANNING | codex/phase-00-baseline | Pending |
| 01 | [Design system, navigation and interaction shell](docs/planning/flutter-rebuild/phases/01.md) | TODO | — | — |
| 02 | [Local accounts, validation and safe persistence](docs/planning/flutter-rebuild/phases/02.md) | TODO | — | — |
| 03 | [Sellable products and inventory](docs/planning/flutter-rebuild/phases/03.md) | TODO | — | — |
| 04 | [Cash sales, saved receipt, drafts and held orders](docs/planning/flutter-rebuild/phases/04.md) | TODO | — | — |
| 05 | [Sales history, returns and voids](docs/planning/flutter-rebuild/phases/05.md) | TODO | — | — |
| 06 | [Daily accounting, expense categories and cashbox](docs/planning/flutter-rebuild/phases/06.md) | TODO | — | — |
| 07 | [Suppliers, debts, materials and prices](docs/planning/flutter-rebuild/phases/07.md) | TODO | — | — |
| 08 | [Purchase invoices, analysis and supplier payments](docs/planning/flutter-rebuild/phases/08.md) | TODO | — | — |
| 09 | [Settings, backups, import and recovery](docs/planning/flutter-rebuild/phases/09.md) | TODO | — | — |
| 10 | [Statements, day review, PDF reports and printing](docs/planning/flutter-rebuild/phases/10.md) | TODO | — | — |
| 11 | [Complete MVP verification, migration rehearsal and release](docs/planning/flutter-rebuild/phases/11.md) | TODO | — | — |

## Per-Phase Record

### Phase 00

- **Name:** Baseline and delivery setup
- **Status:** PLANNING — initialized 2026-10-28; kickoff/reference assessment only, stopped before implementation.
- **Dependencies:** None
- **Figma / Design approval:** N/A — UX Agent confirmed setup-only scope; blank RTL capability shell is not product UI. No Figma validation or design approval claimed. Reassess and obtain owner design approval before any product UI implementation.
- **Branch / Worktree:** `codex/phase-00-baseline`, current checkout; created from `aa624bc`. Prior uncommitted work preserved and unstaged; separate its adoption/layout baseline before preparing a phase-only PR.
- **Assigned agents:** Lead (tracker/evidence); UX `phase00_ux` (read-only applicability/reference assessment); Planner `phase00_plan` (read-only bounded plan). Workers/independent implementation Reviewer not launched.
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/00.md); [read-only plan and kickoff evidence](docs/phases/00-baseline-kickoff.md).
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Owner authorized phase 00 kickoff on 2026-10-28 and requested a stop before proceeding. Design N/A; no merge approval or phase completion approval recorded. Implementation has not begun.
- **Decisions / Lessons:** Preserve exact existing reference direction. No phase 01 work; native device/signing/font/plugin evidence remains pending. Existing Figma handoff is partial according to its local record; present access unverified.
- **Evidence:** [Kickoff record](docs/phases/00-baseline-kickoff.md); [task log](docs/log/2026-10-28-phase-00-kickoff.md). Reference integrity check is not Flutter verification.
- **Completed:** —

### Phase 01

- **Name:** Design system, navigation and interaction shell
- **Status:** TODO
- **Dependencies:** 00
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/01.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 01 execution evidence yet.
- **Completed:** —

### Phase 02

- **Name:** Local accounts, validation and safe persistence
- **Status:** TODO
- **Dependencies:** 00, 01
- **Figma / Design approval:** N/A — non-UI setup/data/release scope; reassess if UI changes are introduced.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/02.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 02 execution evidence yet.
- **Completed:** —

### Phase 03

- **Name:** Sellable products and inventory
- **Status:** TODO
- **Dependencies:** 01, 02
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/03.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 03 execution evidence yet.
- **Completed:** —

### Phase 04

- **Name:** Cash sales, saved receipt, drafts and held orders
- **Status:** TODO
- **Dependencies:** 01, 02, 03
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/04.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 04 execution evidence yet.
- **Completed:** —

### Phase 05

- **Name:** Sales history, returns and voids
- **Status:** TODO
- **Dependencies:** 02, 03, 04
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/05.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 05 execution evidence yet.
- **Completed:** —

### Phase 06

- **Name:** Daily accounting, expense categories and cashbox
- **Status:** TODO
- **Dependencies:** 01, 02, 05
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/06.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 06 execution evidence yet.
- **Completed:** —

### Phase 07

- **Name:** Suppliers, debts, materials and prices
- **Status:** TODO
- **Dependencies:** 01, 02, 06
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/07.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 07 execution evidence yet.
- **Completed:** —

### Phase 08

- **Name:** Purchase invoices, analysis and supplier payments
- **Status:** TODO
- **Dependencies:** 02, 06, 07
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/08.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 08 execution evidence yet.
- **Completed:** —

### Phase 09

- **Name:** Settings, backups, import and recovery
- **Status:** TODO
- **Dependencies:** 01, 02, 04, 06, 08
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/09.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 09 execution evidence yet.
- **Completed:** —

### Phase 10

- **Name:** Statements, day review, PDF reports and printing
- **Status:** TODO
- **Dependencies:** 03, 04, 05, 06, 07, 08, 09
- **Figma / Design approval:** Pending — validate the current reference in Figma and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/10.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 10 execution evidence yet.
- **Completed:** —

### Phase 11

- **Name:** Complete MVP verification, migration rehearsal and release
- **Status:** TODO
- **Dependencies:** 00–10
- **Figma / Design approval:** N/A — non-UI setup/data/release scope; reassess if UI changes are introduced.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/11.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 11 execution evidence yet.
- **Completed:** —

## Completion Rule

Mark DONE only after all applicable requirements pass, the PR is approved and merged, and required release validation is completed. Never mark a phase DONE based only on implementation progress. Never automatically start the next phase.

Prior Electron tests, screenshots, planning and folder relocation remain historical reference evidence. They do not mark any Flutter phase as started, reviewed, approved, merged or completed.
