# Dakhl_Restaurant — project rules and agent workflow

Adopted by the owner on 2026-10-28 from the supplied universal rules and phase-tracker template. Applies to this project; the source Vault files and other projects are not modified.

Read AGENTS.md, [PLANS.md](PLANS.md) and [PHASES.md](PHASES.md) before phase work. [PROMPTS.md](PROMPTS.md) contains the joint engine/app workflow prompts. The [workflow source record](docs/reference/workflow/README.md) preserves provenance.

## Always consult Madar_Engine documentation

Owner instruction, 2026-10-28. Before every task, including planning, design, implementation, tests, review, documentation and delivery, read the current Madar sources alongside this project's AGENTS.md, PLANS.md, PHASES.md and PROMPTS.md:

- [README](../Madar_Engine/README.md), [AGENTS](../Madar_Engine/AGENTS.md), [PLANS](../Madar_Engine/PLANS.md), [PHASES](../Madar_Engine/PHASES.md) and [PROMPTS](../Madar_Engine/PROMPTS.md).
- [Documentation index](../Madar_Engine/docs/README.md), [FULLSTACK](../Madar_Engine/FULLSTACK.md), [responsibility list](../Madar_Engine/docs/reference/madar-responsibility-list.md), [next-session/open decisions](../Madar_Engine/docs/how-to/start-next-session.md) and [memory guide](../Madar_Engine/docs/how-to/memory.md).

Then follow the index to the decisions, contracts, usage examples and package READMEs relevant to the task. Verify claims against current source and the actual engine revision consumed by the app; distinguish selected, implemented and verified behavior. Hindsight summaries do not replace current Madar sources.

Identify the engine work, app work and public contract before acting. Keep linked task/phase evidence in each affected project and record a justified N/A when engine changes are unnecessary. Shared rules, contracts and reusable adapters live only in Madar; Dakhl_Restaurant owns restaurant UI/ViewModels, industry workflows, document composition and app safeguards. Consume reviewed engine revisions and never copy/fork engine implementation into this app. Preserve single-restaurant, offline, Arabic RTL, IQD and historical-record constraints; Madar's planned cloud stack does not change the app's scope or resolve open policies.

Give every subagent this reading requirement and ownership boundary. Keep project-daftar and project-madar separate; task-specific engine recall may use Madar's own scoped wrapper with source provenance, without merging banks or querying unrelated history. If required Madar sources are unavailable, report the missing files and stop dependent work while continuing safe independent work. Reading documentation does not authorize a new phase, merge, publication or deployment.

## Application to this project

- Canonical project name: **Dakhl_Restaurant** (owner correction, 2026-10-28). Use it for current project, planning, agent and Penpot names. Legacy Electron names, source/screenshot hashes, archived evidence, `project-daftar`, `daftar_memory` and the memory selector `daftar` remain compatibility identifiers, not the current project name. [Naming record](docs/decisions/0016-dakhl-restaurant-project-name.md).

- Current user instructions govern scope. The adopted universal workflow and the restaurant-specific rules below apply together. Retain single-restaurant, Arabic RTL/IQD, offline-data and historical-record protections; do not import the stack or product scope of another project.
- Owner direction2026-10-28: develop Madar_Engine alongside this app. Shared engine contracts/business capabilities/reusable adapters live only in Madar_Engine; consume its packages here, never copy/fork engine source. App UI, restaurant workflows, document composition and app-specific safeguards stay here. Read both projects' current scope before cross-project changes; do not add Madar's proposed cloud stack or unresolved financial policies to this offline app. [Boundary decision](docs/decisions/0018-madar-engine-boundary.md).
- Flutter work belongs at the root. Preserve electron-reference/ and keep the detailed plan/screenshots in docs/planning/flutter-rebuild/.
- PLANS.md defines the current 12 phases (00–11) and incorporates their detailed scope. PHASES.md is authoritative for execution status and completion evidence. Published plan pages do not override the tracker.
- The owner's screenshot-reproduction direction is approved as intent, not evidence of design validation or approval. On 2026-10-28 the owner explicitly replaced Figma with **Penpot**. Penpot is the design/reference-validation destination for this project; the approval gate remains mandatory. The Figma wording in the preserved universal source below is superseded only as to the tool. Non-UI phases record Design: N/A; reassess when UI enters scope.
- Reuse one Penpot project/file/page for all future create/recreate-design requests: project **Dakhl_Restaurant**, file **Dakhl_Restaurant · Phase designs & wireframes**, page **Dakhl_Restaurant · Designs & Wireframes / Designs**. This is an English rendering for documentation; canonical IDs and the external workspace are not renamed by this translation. [Canonical page](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455). Keep phase versions in named boards on that page, preserve prior work, and use computer use if MCP is blocked. Phase 00's current design prerequisite covers only its three listed desktop screenshots and matching wireframes. [Decision and scope](docs/decisions/0015-penpot-design-workspace.md).
- For each implementation phase, create a dedicated branch/worktree and a traceable PR, preserving existing work. Never reset, discard or silently include unrelated changes. The current rules adoption is a documentation/configuration chore, not the start or completion of phase 00.
- DONE requires all applicable tests/CI, independent review, user approval, merged PR and applicable release/rollback evidence. Missing design, hardware, signing or access remains pending/blocked, never passed. Never merge without the owner’s approval; never automatically start the next phase.
- Use the Lead plus appropriate specialist agents automatically as described below; independent Workers have non-overlapping ownership and cannot self-approve. Custom role instructions do not establish separate permissions. Do not change model/provider or permission settings merely to configure these roles.
- The 12 phases initially started as TODO; use PHASES.md for current execution state. Earlier Electron tests, captures and folder preparation are reference evidence, not proof that any Flutter phase passed.

## Standing rule: engine and app develop side by side

Owner instruction,2026-10-28; always applicable to work on these projects, not only to extraction or a particular phase. Apply it during research, design, planning, coding, execution, testing, review, documentation, dependency upgrades and delivery. Follow the joint PROMPTS.md workflow; the Lead must include this rule in every specialist brief.

Prompt style: define only the objective, acceptance criteria and hard boundaries. Keep prompts concise; do not prescribe exact files, implementation steps or tools beyond an explicit owner constraint. The Lead chooses the optimal execution path within the standing rules.


- Before changing anything, identify the Madar responsibility, the app responsibility and their public contract. Read the relevant current rules/plans/trackers and source documentation from both projects. Record N/A with a reason when one side is unaffected; do not add unnecessary changes.
- Madar_Engine is the sole source of shared business rules, contracts and reusable adapters. Keep its pure Dart code independent of Flutter, databases/cloud and hardware; optional integrations live in separate adapters. Reuse existing capabilities before adding them and implement new shared behavior there with concrete consumer/conformance tests. No copied/forked engine implementation inside apps, and no engine dependency on consumer code.
- Dakhl_Restaurant owns its UI/ViewModels, restaurant workflows, presentation/document composition and app-specific safeguards. It consumes a reviewed, versioned engine revision. Preserve one-restaurant/offline/Arabic RTL/IQD/history constraints; shared engine work does not add cloud/auth/multitenancy or settle open financial/recovery policies.
- Keep each project's own plan/tracker, contracts/API/usage examples, decisions, tests and dated evidence current for its affected scope. Cross-link work and engine revisions; do not substitute one project's evidence for another's or duplicate writable engine authority in the app. Keep project-madar and project-daftar memory separate.
- The goal is an engine future apps can build on without rebuilding shared foundations. Validate reusable boundaries and consumer compatibility; avoid speculative abstractions and do not claim a supported release before its documented gates pass. Design, implementation, tests and delivery approvals remain separate.

## Adopted universal rules — full source text

# Universal Development Rules

Applies to AlDakhl, Dakhl_Restaurant, Madar Engine, and future projects.

All agents must follow AGENTS.md, PLANS.md, and PHASES.md.

## 1. Agent Responsibilities

### Lead / Architect Agent

- Orchestrates the entire workflow.
    
- Launches and coordinates specialized agents.
    
- Assigns tasks and manages dependencies.
    
- Maintains Git isolation and the phase tracker.
    
- Integrates worker results and resolves conflicts.
    
- Prepares pull requests and manages completion.
    

### UX Agent

- Researches suitable UI/UX references.
    
- Creates or adjusts designs in Figma.
    
- Validates usability, accessibility, responsiveness, and all relevant UI states.
    
- Requires user approval before implementation.
    
- Only used for phases involving UI/UX.
    

### Planner Agent

- Read-only planning; never implements code.
    
- Inspects relevant project files and requirements.
    
- Defines exactly what needs implementation.
    
- Identifies required references, dependencies, tests, benchmarks, and CI changes.
    
- Produces short, actionable plans without unnecessary context.
    
- Never suggests unrelated features or speculative improvements.
    

### Worker Agents

- Implement independently assigned tasks.
    
- Use fresh, focused context windows.
    
- May specialize in UI, business logic, backend, testing, or infrastructure.
    
- Write meaningful tests before implementing behavior.
    
- Establish measurable performance baselines before optimization.
    
- Respect assigned ownership and existing architecture.
    

### Independent Reviewer Agent

- Independently reviews work completed by Workers.
    
- Verifies logic, correctness, architecture, and MVVM compliance.
    
- Evaluates whether automated tests cover meaningful real-world scenarios.
    
- Identifies missing edge cases and regressions.
    
- Validates benchmark methodology, baseline measurements, and improvements.
    
- Reviews security, data integrity, and production readiness.
    
- Reports actionable findings and requires re-verification.
    
- Prefer a different model/provider where available.
    

## 2. Multi-Agent Orchestration

- The Lead launches appropriate agents automatically for each workflow step.
    
- Use parallel Workers only for independent tasks.
    
- Assign explicit task ownership, interfaces, and non-overlapping file boundaries.
    
- Never allow agents to overwrite or interfere with one another's work.
    
- Workers cannot approve their own implementations.
    
- The Reviewer must be independent of implementation.
    
- Keep agent context focused on the files and information relevant to its task.
    

## 3. Design Rules

- Every UI phase requires an approved Figma design or suitable reference validated in Figma.
    
- Validate responsive layouts, accessibility, usability, and loading, empty, error, and success states where relevant.
    
- Do not implement unapproved design changes.
    
- For non-UI phases, record Design: N/A.
    

## 4. Git Isolation

- Every phase has its own dedicated branch/worktree.
    
- Every phase must be traceable through a pull request.
    
- Protect `main` from unfinished changes.
    
- Never merge without user approval.
    
- Prevent cross-agent interference and unrelated modifications.
    

## 5. Architecture & Implementation

- Enforce MVVM for applicable application UI layers.
    
- Respect existing architecture, conventions, and module boundaries.
    
- Maintain clear separation of responsibilities.
    
- Avoid unnecessary dependencies, abstractions, or refactoring.
    
- Never alter unrelated features without authorization.
    

## 6. Testing & Numeric Benchmarks

### Automated Testing

- Write meaningful automated tests before implementing behavior.
    
- Cover normal usage, boundaries, invalid inputs, network errors, concurrency, race conditions, data failures, and recovery scenarios where relevant.
    
- Use appropriate unit, integration, and end-to-end tests.
    
- Reject superficial tests, meaningless assertions, and artificial coverage.
    
- Tests must validate actual requirements and realistic behavior.
    
- No implementation is considered complete until all required automated tests pass.
    

### Benchmarks

- Establish numeric baselines before optimization.
    
- Never accept vague goals such as "make it faster."
    
- Measure relevant metrics such as latency, memory, startup time, rendering performance, or throughput.
    
- Record baseline values, measurement conditions, and acceptable targets.
    
- Automatically compare results after changes wherever practical.
    
- Reject meaningless benchmarks or improvements without evidence.
    
- Benchmarks are optional when no meaningful performance requirement exists; document N/A.
    

## 7. CI & Quality Gates

- Existing mandatory CI checks must pass for every PR.
    
- Add targeted CI tests, architecture checks, or regression checks when required.
    
- Validate linting, static analysis, automated tests, and builds as applicable.
    
- Avoid redundant or unnecessarily expensive CI pipelines.
    
- Never mark failed, skipped, or unverified required checks as passed.
    

## 8. Security & Production Readiness

- Review authorization, secrets, data integrity, and security-sensitive behavior.
    
- Validate database changes, migrations, and recovery where applicable.
    
- Run staging validation and smoke tests for deployable changes.
    
- Verify rollback procedures when necessary.
    
- Resolve blocking review findings before final approval.
    

## 9. Phase Tracking & Documentation

- `PLANS.md` defines the phases and their scope.
    
- `PHASES.md` records each phase's status, branch, PR, design approval, tests, benchmarks, and completion.
    
- Update the tracker as work progresses.
    
- Record important architecture decisions, benchmark results, discovered issues, and lessons learned.
    
- Keep documentation useful, concise, and relevant.
    
- Mark a phase DONE only after all required checks, approval, merge, and applicable release validation.
    
- Never automatically start the next phase.
    

## 10. Prompt & Communication Rules

- Prompts define the objective, acceptance criteria, and hard boundaries.
    
- Avoid micromanaging implementation details.
    
- Let the Lead and specialized agents determine the execution strategy.
    
- Keep plans, progress updates, and summaries concise.
    
- Report blockers and failed verification explicitly.
    
- Never claim work is verified when it has not been executed and checked.


Final structure:
Project/
├── AGENTS.md          # Permanent rules + agent roles
├── PLANS.md           # Project phases and scope
├── PHASES.md          # Phase tracker
├── PROMPTS.md         # 6 reusable execution prompts
├── docs/
│   └── phases/        # Evidence and decisions
└── .codex/
    └── agents/
        ├── planner.toml
        ├── ux.toml
        └── reviewer.toml

## Existing restaurant-specific rules — retained

# Dakhl_Restaurant — Project, documentation and memory rules

Status: approved instructions. Date: 2026-10-16. Source: project-owner direction and review of current files.

## Scope

### Folder organization — 2026-10-28

The project root is for the Flutter/Dart rebuild. The old application, dependencies and tests are in `electron-reference/` for reference; do not implement Flutter features there. The plan/screenshots stay in `docs/planning/flutter-rebuild/` outside the reference folder; documentation, memory and Git remain shared at the root. Links named `docs/`, `outputs/`, `dist/` and `design/` inside the reference point to root folders and do not mean those folders moved. Run reference tests from the root with `npm --prefix electron-reference test`. Do not launch the normal application merely to verify relocation because it may read restaurant accounts. [Organization decision](docs/decisions/0013-electron-reference-folder.md).

This project serves **one restaurant only**. Read `docs/reference/project-scope.md` and `docs/README.md` first. Do not automatically turn it into a multi-restaurant platform or general-purpose product. Invoices, campaigns, ideas and the dedicated application serve the same restaurant. These instructions document direction, not implemented in-app campaign functionality.

## Before work

1. Recall task-relevant context from **project-daftar** through `daftar_memory` or `./scripts/memory recall --query 'task topic'`.
2. Inspect current files cited by memory. Project files and current user direction take precedence over historical memory. Do not use AlDakhl's bank or assume its technologies belong to Dakhl_Restaurant.
3. Read `docs/reference/accounting-rules.md` before financial changes and `docs/reference/application.md` before persistence/report changes. For UI work, read `.impeccable.md`.
4. If memory is unavailable, continue safe independent work and record the outage; do not claim successful recall or synchronization.

## Protect the application

- The current application is Electron/JavaScript with local JSON data. Do not impose a new technology/database because another project's examples use it.
- Preserve older accounts, backups and validation before save/import. Every schema change needs a record-preserving migration and appropriate tests.
- Worker advances are independent of expenses/cashbox. Chicken counts are outside financial amounts. A supplier invoice records debt; payment enters expenses and deducts its source exactly once.
- Remaining cash, cashbox and overall balance are not alternative names for net profit. Document a report's meaning before implementation.
- Use Arabic RTL, calm green and a light background in the application UI. During verification, never save sample data into restaurant accounts; use isolated test fixtures.
- A request to document an idea authorizes neither publishing an advertisement, spending a budget, messaging people nor changing real accounts.

## During work and before completion

1. Record ideas/campaigns in `docs/planning/`, policies in `docs/reference/` and procedures in `docs/how-to/`.
2. Record significant decisions and rationale in `docs/decisions/`; preserve earlier decisions with successor links.
3. Update affected documentation and record the task outcome in `docs/log/YYYY-MM-DD-topic.md`: request, change, reason, actual verification, limits and next action.
4. Distinguish proposed, approved, implemented and verified states. Never record test/campaign results without evidence. Do not invent ideas/campaigns in the owner's name merely to fill a register.
5. Run verification appropriate to the change. Application changes need `npm test` and the affected-path checks; documentation-only changes need source/link/state-accuracy review.
6. Run `./scripts/memory sync` and then `./scripts/memory check`; queue submission is not completion. Recheck pending operations and disclose failures/pending work.

## Project-memory boundaries

Hindsight is a derived index of documentation/development decisions, not a restaurant-account store or application runtime component. Shared configuration currently disables raw-conversation retention (`retainSessions: false`); write useful knowledge into documents and synchronize it.

Never index account files/backups, actual invoices, customer data, phone numbers, passwords, keys, `.env` or conversation dumps. Retain only what is needed for follow-up and keep template examples empty. A standalone `<!-- hindsight:ignore -->` line excludes a document; consult the memory guide before adding indexing paths.

## Selected project skills — 2026-10-28

Use the nine task-specific skills in [.agents/skills/README.md](.agents/skills/README.md) only when relevant. Prefer these project-local sources over global skills with the same names. Use local `flutter-testing` for test guidance and `documentation-and-adrs` instead of SLine `docs-sync`. Do not invoke SLine-specific scaffolders, architecture, integration-test or caching skills for Dakhl_Restaurant. Global skills are retained for other projects. Skills do not override project scope, financial contracts, approved architecture, design gates or merge approval.

For Penpot tasks, use the reusable [Penpot skill](/Users/eros/.codex/skills/penpot/SKILL.md). It contains a minimal native-export pilot workflow, the existing local connection, screenshot-recreation mechanics and the documented mistakes from phase00. Load detailed failure references only when relevant; the skill does not waive project scope or design approval.

## Repeated problems and efficient execution

Owner instruction, 2026-10-28: continuously document new and repeated problems, complications, failed approaches and unnecessary time/token use so later runs do not repeat them. Consult [the project prevention record](docs/how-to/repeated-problems.md) before retrying a known issue; keep symptom, cause, verified remedy or unresolved status, prevention and evidence current. Reuse task context and valid unchanged-source evidence, keep output bounded, batch necessary documentation/review work, and avoid redundant polling or speculative investigations. Preserve required verification, independent review, explicit design/revision approvals and separate engine/app ownership and memory; efficiency never waives a gate.

## Per-phase ownership, packages, documentation and diagnostics

Owner reaffirmation, 2026-10-28: apply [the consumer delivery obligations](docs/how-to/engine-consumer-contract.md) and Madar's authoritative delivery standards in every phase. Classify engine work, app work and contract/revision first. Write shared rules/contracts/adapters once in Madar and consume reviewed packages here; keep app UI/workflows/safeguards here. Deliver engine capability documentation, justified Dart/Flutter packages when needed, safe structured terminal logging and meaningful engine/consumer tests. No unused dependency or logger retrofit is introduced by this rule. All documentation and Hindsight knowledge are English-only; preserve Arabic executable UI/fixtures and frozen screenshots/source assets.
