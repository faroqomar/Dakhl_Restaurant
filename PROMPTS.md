# Madar_Engine + Dakhl_Restaurant — reusable workflow prompts

Workflow revision: 2026-10-28.2. Replace `{{PHASE}}` with the active app phase or explicitly named engine work item. These prompts are instructions for the selected step, not permission to run every step or start another phase.

## Standing instructions — apply to every step

Develop **Madar_Engine and Dakhl_Restaurant side by side**. Before researching, designing, planning, coding, refactoring, testing, reviewing, documenting or releasing, read both projects' applicable `AGENTS.md`, `PLANS.md`, `PHASES.md` and current decisions. Read Madar's `FULLSTACK.md` and responsibility list for engine boundaries; read the app's phase scope, accounting rules, reference and approved design when relevant. Resolve the actual paths/branches; preserve existing work.

For every task, identify **Madar work, app work, and the contract between them**. Shared business rules, deliberate contracts and reusable adapters belong in Madar; app UI, ViewModels, restaurant workflows, document composition and app-specific safeguards belong in Dakhl_Restaurant. Keep pure Dart code free of Flutter, database/cloud and hardware dependencies; put optional implementations behind separate adapter boundaries. Consume engine packages at a reviewed revision; never copy/fork their implementation into an app or make the engine depend on this app.

Build reusable capabilities from real requirements and verified contracts so future apps can use the engine without rebuilding the foundation. Check existing engine capabilities before adding code. Avoid restaurant branding/schema in shared packages, speculative frameworks, empty modules and premature abstractions. Do not silently select unresolved financial, stock, offline, security or recovery policies. Preserve the app's single-restaurant, offline, Arabic RTL/IQD and historical-record rules. Madar's planned cloud stack does not automatically enter this app; grocery and restaurant remain equal first-release engine acceptance domains.

Keep each project's own plan, tracker, decisions, API/usage documentation, tests and evidence current for its affected scope, with links between related work. Record `N/A` with a reason when one side needs no change; do not manufacture work or duplicate authoritative engine documentation in the app. Keep project memory banks separate. After meaningful changes, save sanitized outcomes in each affected project, synchronize its memory and verify delivery; report pending/failed ingestion honestly.

The Lead launches, coordinates and verifies the specialists required by the step. Give every agent the two-project ownership rules, relevant scope, paths, interfaces and acceptance criteria. Use parallel Workers only for independent ownership. Read-only Planners and independent Reviewers do not implement or self-approve. Use focused context and proportionate checks; do not rerun expensive tests without a change, failure or unresolved requirement that justifies them.

## Step 1 — Scope, References & Track

**Agents: Lead + UX Agent when UI is involved**

Start only `{{PHASE}}` from the applicable plan. Inspect current status, dependencies, approvals and blockers. Initialize or update the app phase record and its linked Madar work items without resetting prior evidence or marking unstarted work complete. Record engine/app ownership, interfaces, documentation owners and Design status on each side.

Find any screenshots or design references I previously supplied in the accessible project/chat sources. Show them back to me with their names and provenance before design work. Distinguish supplied reference, proposed changes and approved design; do not substitute another reference silently. If an exact reference is unavailable, state what is missing and obtain it before claiming a match.

For UI scope, launch UX to inspect only this phase's references, workflows, Arabic RTL, accessibility, responsive needs and relevant states; identify the precise Penpot deliverables for Step 1.5. For a non-UI phase, record **Design: N/A** and skip Step 1.5. This step authorizes scope/design preparation, not application implementation.

## Step 1.5 — Penpot Design, Wireframes & Approval

**Agents: Lead + UX Agent**

Create or update **only the active phase's design and matching wireframes in Penpot**. Reuse the canonical Dakhl_Restaurant project/file/page recorded in its AGENTS.md; keep versions and states in named boards and preserve previous work. Read the Penpot skill first. Use its MCP/plugin API when available; use computer use if blocked. Do not create designs for the whole app or use Figma.

Follow the supplied screenshots and approved direction closely. The visual design reproduces appearance; the structural wireframe preserves content, placement, hierarchy and interactions without claiming pixel identity. Validate relevant desktop/phone layouts, RTL/mixed numerals, text scaling, contrast, readable labels, keyboard/focus, screen-reader semantics and touch targets. Cover loading, empty, populated, validation, error, success, disabled and recovery states where relevant; record N/A where a state does not apply. Clearly identify proposed states/layouts absent from the source.

Compare the Penpot result against the actual reference at equivalent state, size and scale. Return the original references, Penpot link/board names, visible previews, discrepancies and validation evidence. Record which checks are design review versus runtime checks still needed. **Stop for my explicit design approval before UI implementation.** Screenshot-recreation intent, an opened file or an agent's validation is not my approval.

## Step 2 — Isolate & Plan

**Agents: Lead + read-only Planner Agent**

For authorized `{{PHASE}}`, verify prerequisites and required design approval. Create or reuse a suitable dedicated branch/worktree in **each repository that needs changes**, preserving unrelated work and recording base revisions. Link engine work items to the app phase; do not assume their phase IDs or completion states are identical. If a project needs no change, record N/A and why. Remote access limitations must remain visible.

Launch the Planner to inspect both projects' relevant code, contracts and documentation. Produce a concise plan containing: current behavior and exact deliverables; engine/app ownership and interfaces; reusable engine capabilities versus app-specific policy; approved references; acceptance criteria; realistic unit, contract, integration and target-device tests; dependencies and the engine revision/upgrade strategy; numeric benchmark baselines/targets when optimization is requested, otherwise N/A; required CI/build checks; documentation, migration and rollback needs; and unresolved decisions/blockers.

Plan engine tests independently of the app and prove the app consumes the same contract. Include additional consumer/conformance examples where required by the changed capability and release scope. Do not invent financial rules, unrelated features or new app scope. **No implementation.** Present the bounded plan for approval before Step 3; approvals already given remain valid within their recorded scope.

## Step 3 — Orchestrate & Build

**Agents: Lead + specialized Worker Agents**

Execute only the approved plan for `{{PHASE}}`. Assign non-overlapping repository/files/module ownership and explicit interfaces. Implement shared capabilities in Madar first or in coordinated independent tasks, then integrate the app through its public contracts. Workers must respect other edits and cannot self-approve.

Write meaningful requirement-based tests before behavior changes, including relevant boundaries, invalid inputs, cancellation, failure/retry, concurrency, interruption and recovery. A compile-only red result is not proof of a behavioral regression test. Establish measured numeric baselines before optimization; do not invent performance requirements. Use isolated synthetic fixtures and never restaurant records.

Keep pure engine logic, optional adapters, app MVVM and document/UI composition separate. Update each affected project's contracts, decisions, usage examples and evidence as work proceeds. Pin and verify the actual engine revision/package versions consumed by the app; keep local path convenience separate from reproducible hosted delivery. Run targeted checks as tasks integrate. Draft PRs may be opened when needed to obtain CI, but they are not ready for approval while required checks are pending. Update both linked trackers with actual results and unresolved limits.

## Step 4 — Independent Review & Verification

**Agents: independent Reviewer + Lead + responsible Workers**

Launch an independent, read-only Reviewer for `{{PHASE}}` across every changed repository and the consumer dependency. Audit correctness, engine/app ownership, pure Dart boundaries, MVVM, reusable API design, compatibility, security, data integrity, historical meaning, actual test effectiveness, missing scenarios, benchmark methodology and production readiness. Verify no copied engine implementation or consumer-specific policy leaked across the boundary.

Return actionable findings to their owning Workers. Re-review fixes and rerun affected tests, analysis, builds and required CI until applicable checks pass. Verify engine behavior independently, engine/app contract integration and affected app workflows against the recorded engine revision. Use actual target-device, staging, migration, smoke and rollback checks where applicable; distinguish simulator/emulator evidence from physical hardware and signing. Record N/A with reasons and keep unavailable required evidence pending/blocked.

Do not promote a prototype to production support, treat package availability as integration proof or mark failing/unexecuted checks passed. Scope-changing fixes return to planning/design approval as needed. No final approval or merge in this step.

## Step 5 — Pull Requests & Approval

**Agent: Lead**

Prepare or finalize one scoped PR per changed repository for `{{PHASE}}` after independent review and applicable verification. Link engine/app PRs and tracker items; show engine-first dependency order, exact reviewed heads/base branches and the app's engine pin. If remote publication/access or required CI is blocked, keep delivery pending/draft and report the specific blocker rather than declaring readiness.

Show me a concise implementation summary, final reviewable diffs, engine/app ownership, actual test/build/CI results, benchmark baseline/comparison or N/A, documentation/API/version changes, rollback implications and remaining non-blocking risks. Separate design approval, plan approval, PR approval and release approval.

**Stop and wait for my explicit merge approval. Do not merge automatically or treat an earlier design/build instruction as merge permission.**

## Step 6 — Approved Merge & Completion

**Agent: Lead**

After my explicit approval, merge only the approved PRs/revisions into their intended main branches, in dependency order. Merge the engine first when the app depends on it. Update the consumer pin to the actual reviewed/merged engine revision and reverify compatibility. If that changes the app PR/head, return to Step 5 for approval of the updated app revision before merging it. Do not merge either repository while its required checks fail or remain unverified.

Update each project's documentation, decisions, release/upgrade information, memory, test/benchmark evidence and linked PHASES.md records. Record actual merge revisions and applicable release/staging/smoke/rollback results. Mark each work item DONE only when its own applicable requirements, approval, merge and validation are satisfied; app completion cannot conceal incomplete engine work or vice versa. Never label publication, signing or physical-device checks passed without evidence.

Stop after this phase. **Do not start the next phase automatically.**
