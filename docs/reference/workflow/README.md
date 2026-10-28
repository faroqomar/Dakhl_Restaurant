# Adopted workflow sources

Status: project rules adopted at the owner’s explicit request, 2026-10-28. This is workflow setup, not execution of a Flutter phase.

The owner supplied:

- [Universal Rules & Agents](</Users/eros/Dev/ErosVault/My_Workflow/AGENTS.md — Universal Rules & Agents.md>) — permanent workflow and role rules.
- [Phase Tracker](</Users/eros/Dev/ErosVault/My_Workflow/PHASES.md — Phase Tracker.md>) — the tracker template, instantiated for the current 00–11 phases.

Exact local source copies are universal-rules.source.txt and phase-tracker.source.txt. source-manifest.json records their SHA-256 hashes. The previous project-specific AGENTS.md is preserved in project-rules-before-adoption.source.txt and its rules remain in the active root AGENTS.md. The Vault originals and other projects were not edited.

## Active files

- [AGENTS.md](../../../AGENTS.md): full universal rules plus retained project-specific constraints and precedence notes.
- [PLANS.md](../../../PLANS.md): current phase index incorporating the existing detailed scope.
- [PHASES.md](../../../PHASES.md): authoritative status/evidence tracker; all phases initially TODO.
- [PROMPTS.md](../../../PROMPTS.md): joint phase workflow, Steps1–6 plus Penpot Step1.5, applied to engine and app.
- [.codex/agents/](../../../.codex/agents/): planner, ux and reviewer definitions; Lead/Workers use the available general roles.
- [Evidence index](../../phases/README.md): where phase evidence is recorded when work begins.

The shared memory source allowlist for Dakhl_Restaurant (legacy selector `daftar`) includes the three new root workflow files, alongside its existing documentation sources. No app/account data or other project’s source patterns were added.

## Agent configuration evidence

The project-scoped TOML files use name, description and developer_instructions, following [official OpenAI subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents), checked 2026-10-28. Model/provider and permission settings are left inherited. Read-only instructions are a role boundary, not a separate filesystem permission mode. Parsing these files does not prove runtime discovery in an already-running chat; use explicit role instructions if a role is not available, and report that limitation.

## Approval and completion interpretation

The screenshot direction remains the owner’s approved design intent. Penpot superseded Figma on2026-10-28; active prompts and UX configuration now use Penpot. Supplied screenshots are not evidence that the design approval gate passed. UI phases record that gate as pending; 00/02/11 record N/A for their present non-UI setup/data/release scope and must reassess if UI changes enter scope.

The existing worktree contains earlier uncommitted work. Adoption does not discard it, claim it merged, create a retroactive PR or start phase 00. At the next explicitly requested phase, the Lead must establish the required Git isolation while preserving that work. Do not merge without user approval, and do not auto-start the next phase.

## Standing joint workflow update —2026-10-28

The owner made side-by-side Madar_Engine/Dakhl_Restaurant development mandatory for all work, not only phase00 extraction. Both projects' AGENTS/PROMPTS now require ownership/contract assessment, separate documentation/evidence, independent engine and consumer checks, explicit dependency pins and approval gates. Madar now has its own registered work plan/tracker; its IDs do not mirror app phase IDs. The original source copies/manifest remain preserved historical provenance. Active prompts supersede their old Figma wording.
