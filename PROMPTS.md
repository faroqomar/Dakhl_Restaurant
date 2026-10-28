# Madar_Engine + Dakhl_Restaurant — simple workflow prompts

Use one prompt for the selected phase or work item `{{PHASE}}`. Existing project rules remain mandatory. The Lead chooses the analysis, agents, files, tools and execution path.

## Shared guardrails

Develop the engine and app side by side. Shared capabilities belong only in Madar; the app owns its UI, restaurant workflows and composition. Preserve separate project documentation, evidence and compatible engine versions so future apps can reuse the foundation. Do not copy engine implementation into apps, change protected accounting/data behavior, expand scope or bypass approvals without permission. Record N/A when one project is unaffected. Each phase makes ownership, contract/revision, engine documentation, justified package choices, safe diagnostics and meaningful test evidence explicit. Documentation and project memory are English-only.

## Step 1 — Scope, References & Track

- **Objective:** Establish the scope and readiness of `{{PHASE}}` across the engine and app.
- **Acceptance criteria:** Ownership, dependencies, tracking and blockers are clear. Previously supplied screenshots/references are shown back to me. UI design needs are identified, or Design is recorded as N/A.
- **Hard boundaries:** No implementation, unrelated scope, discarded prior work or assumed approval.

## Step 1.5 — Penpot Design & Wireframes

- **Objective:** Prepare the active phase's design and matching structural wireframes in Penpot.
- **Acceptance criteria:** The result follows my references and direction, addresses relevant accessibility, responsive layouts and UI states, and is presented with previews, discrepancies and evidence for my explicit approval.
- **Hard boundaries:** Reuse the existing project design space and preserve prior work. No whole-app redesign, invented features or UI implementation before my design approval. Non-UI work is N/A.

## Step 2 — Isolate & Plan

- **Objective:** Produce a bounded, reviewable implementation plan for `{{PHASE}}` with suitable isolation in each affected project.
- **Acceptance criteria:** The plan defines deliverables, engine/app responsibilities, contracts, dependencies, meaningful tests, applicable benchmarks and CI, documentation needs, risks and completion criteria.
- **Hard boundaries:** No implementation, unrelated changes or silent decisions on unresolved business policies. Preserve existing work; build only after plan approval.

## Step 3 — Orchestrate & Build

- **Objective:** Implement the approved outcome for `{{PHASE}}` in the appropriate engine and app boundaries.
- **Acceptance criteria:** Approved behavior works, shared capabilities are reusable, consumer integration is compatible, meaningful tests precede behavior changes, applicable checks pass, and each affected project's documentation and tracker reflect actual results. Optimization has a measured baseline.
- **Hard boundaries:** No unapproved design or scope changes, copied engine code, overwritten work, production-record testing or weakening of required checks. No self-approval or merge.

## Step 4 — Independent Review & Verification

- **Objective:** Independently establish whether `{{PHASE}}` is correct and ready for approval.
- **Acceptance criteria:** Blocking findings are resolved and reverified. Evidence covers relevant architecture, engine/app compatibility, security, data integrity, realistic tests, CI/builds, benchmarks and recovery/readiness requirements.
- **Hard boundaries:** No self-review, fabricated results or passing labels for missing/failed verification. Unavailable required evidence remains pending or blocked; scope changes need approval.

## Step 5 — Pull Requests & Approval

- **Objective:** Present the verified `{{PHASE}}` changes for my merge approval across affected projects.
- **Acceptance criteria:** Reviewable PRs show final diffs, linked engine/app dependencies and revisions, actual verification results, benchmark comparisons or N/A, documentation changes and remaining non-blocking risks.
- **Hard boundaries:** No automatic merge, implied approval or readiness claims while required checks are unresolved. Report access/delivery blockers honestly.

## Step 6 — Approved Merge & Completion

- **Objective:** Integrate the explicitly approved `{{PHASE}}` revisions and record truthful completion in each affected project.
- **Acceptance criteria:** Approved changes are merged in a compatible dependency order; the app uses the approved engine revision; applicable checks, documentation, trackers and release/rollback evidence support DONE.
- **Hard boundaries:** Merge only approved revisions; changed revisions need renewed approval. Do not mark unfinished requirements complete, deploy without authorization or start the next phase automatically.
