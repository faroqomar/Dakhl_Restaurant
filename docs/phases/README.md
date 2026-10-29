# Phase evidence index

Status, 2026-10-29: Phase 00 technical native dependency independently verified; Phase 01 approved implementation is locally built and in verification. Hosted CI and remaining native/release gates are explicit in the current build evidence. Phases 02–11 remain TODO.

- [Phase 00 — build, test and runtime evidence](00-build-evidence.md).
- [Phase 00 — current implementation plan and isolation](00-implementation-plan.md).
- [Phase 00 — initial kickoff, UX applicability and read-only plan](00-baseline-kickoff.md).
- [Phase 00 — Penpot screenshot designs and matching wireframes](00-penpot-reference-recreation.md).
- [Historical Figma reference preparation — superseded by Penpot](00-figma-reference-preparation.md).

[PLANS.md](../../PLANS.md) defines phase scope. [PHASES.md](../../PHASES.md) records live execution state and links to evidence. Read [AGENTS.md](../../AGENTS.md) for the required workflow.

When phase NN starts, create a phase evidence record here and link it from the tracker. Reference existing logs, ADRs, screenshot files, test outputs and PRs instead of duplicating them. Keep private restaurant accounts, actual invoices, credentials and raw conversations outside this evidence directory and memory indexing.

Each record should identify scope and dependencies; branch/worktree and task ownership; Penpot validation and user design approval or N/A; the read-only plan; meaningful test commands/results and CI; numeric benchmark conditions/baseline/final/target or justified N/A; independent reviewer findings and re-verification; staging/migration/rollback results where applicable; PR, explicit merge approval, merged revision and release evidence; and remaining issues/lessons.

Do not prefill results or approvals. Earlier Electron checks are reference evidence, not Flutter phase completion. DONE requires all applicable checks, approved merge and applicable release validation. Never automatically start the next phase.

- [Phase00 / CAP-00 Step4 independent review](00-step4-review.md) — local finding closed; full acceptance remains blocked.

- [Phase00/CAP-00 linked draft PR review package](00-pr-approval.md).

- [Phase 01 — Step 1 scope, supplied references and readiness](01-scope-readiness.md) — historical preparation assessment; current execution status is below.

- [Phase 01 — Penpot designs, structural wireframes and approval evidence](01-penpot-design-review.md) — explicitly approved by the owner on 2026-10-29; prior pending wording is historical.

- [Phase 01 — bounded implementation plan and isolation](01-implementation-plan.md) — owner-approved plan; last route/six shortcuts restore after restart.

- [Phase 01 — Step 3 approval and native preflight](../log/2026-10-29-phase01-step3-preflight.md) — historical blocked preflight, followed by Device Hub correction and verified dependency closure.

- [Phase 01 — implementation and verification evidence](01-build-evidence.md) — current local results, native limits, independent findings and remaining delivery gates.
- [Phase 01 — app shell contract/setup](../reference/phase01-shell-contract.md) — payload, composition, reviewed engine revision, guarded retry and development data isolation.

- [Phase01 — independent Step4 review and verification](01-step4-review.md) — independent app/engine audit, scoped repairs and actual native/readiness gates; no merge or completion approval.
