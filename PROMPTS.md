# Six reusable phase execution prompts

Use with AGENTS.md, PLANS.md and PHASES.md. Replace bracketed values before use. A prompt does not waive design, Git, review, approval or completion gates.

## 1. Lead — start one phase

Run phase [ID] only. Read the rules, scope, tracker and relevant source/evidence. Confirm dependencies, preserve existing work and establish dedicated branch/worktree isolation. Coordinate the applicable UX, read-only Planner, Workers and independent Reviewer with explicit ownership and interfaces. Record actual evidence in PHASES.md. Keep the reference app and restaurant records safe. Do not merge without user approval and do not start the next phase automatically.

## 2. UX — validate the reference

For UI phase [ID], validate the existing screenshot/design reference in Figma, preserving the owner’s approved direction. Check responsive layouts, accessibility, keyboard/safe areas and applicable loading, empty, error and success states. Return the Figma link, differences, evidence and specific approval required before implementation. Do not invent features or implement UI code. For non-UI scope, record Design: N/A.

## 3. Planner — bounded implementation plan

Plan phase [ID] read-only. Inspect its requirements, dependencies and relevant source. Define the exact deliverables, interfaces, acceptance tests, meaningful benchmarks where applicable, CI/build needs and risks. Keep the plan short and actionable. Do not edit files, implement code or propose unrelated improvements. Report missing decisions and design/approval evidence.

## 4. Worker — implement owned scope

Implement [TASK] for phase [ID], owning only [FILES/MODULES] within [BRANCH/WORKTREE]. Respect [INTERFACES] and other Workers’ ownership. Follow MVVM where applicable. Write meaningful requirement-based tests before behavior changes; establish numeric baselines before optimization. Preserve financial/data semantics and use isolated fixtures. Return changes, executed tests, results and limitations. Do not self-approve, merge or mark the phase DONE.

## 5. Independent Reviewer — verify the implementation

Review phase [ID] independently and read-only against requirements and the actual diff/evidence. Check correctness, architecture/MVVM, data integrity, security, realistic tests, edge cases, races/recovery and meaningful benchmark methods/results. Prefer a different available model/provider where practical and record the actual choice. Report actionable findings with file/line evidence; require re-verification after fixes. Do not edit or approve your own work, invent verification results or mark skipped checks passed.

## 6. Lead — verify, prepare PR and close the phase

For phase [ID], resolve independent review findings and re-run affected verification. Confirm required lint/analysis/tests/builds/CI and applicable staging, migration and rollback evidence. Update PHASES.md with links and actual results, prepare a scoped PR, then request user approval for merge. Do not merge without that approval. Mark DONE only after approved merge and all applicable release validation; otherwise record the remaining state/blocker. Stop after this phase. Never automatically start another phase.
