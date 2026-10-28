# Phase evidence index

Status: phase 00 technical implementation is under verification on 2026-10-28. Phases 01–11 remain TODO.

- [Phase 00 — build, test and runtime evidence](00-build-evidence.md).
- [Phase 00 — current implementation plan and isolation](00-implementation-plan.md).
- [Phase 00 — initial kickoff, UX applicability and read-only plan](00-baseline-kickoff.md).
- [Phase 00 — Penpot screenshot designs and matching wireframes](00-penpot-reference-recreation.md).
- [Historical Figma reference preparation — superseded by Penpot](00-figma-reference-preparation.md).

[PLANS.md](../../PLANS.md) defines phase scope. [PHASES.md](../../PHASES.md) records live execution state and links to evidence. Read [AGENTS.md](../../AGENTS.md) for the required workflow.

When phase NN starts, create a phase evidence record here and link it from the tracker. Reference existing logs, ADRs, screenshot files, test outputs and PRs instead of duplicating them. Keep private restaurant accounts, actual invoices, credentials and raw conversations outside this evidence directory and memory indexing.

Each record should identify scope and dependencies; branch/worktree and task ownership; Penpot validation and user design approval or N/A; the read-only plan; meaningful test commands/results and CI; numeric benchmark conditions/baseline/final/target or justified N/A; independent reviewer findings and re-verification; staging/migration/rollback results where applicable; PR, explicit merge approval, merged revision and release evidence; and remaining issues/lessons.

Do not prefill results or approvals. Earlier Electron checks are reference evidence, not Flutter phase completion. DONE requires all applicable checks, approved merge and applicable release validation. Never automatically start the next phase.
