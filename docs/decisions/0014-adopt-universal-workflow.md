# 0014 — Adopt universal development rules and phase tracking

Status: adopted at the owner's explicit request; Flutter phase implementation has not started. Date: 2026-10-28.

## Source and decision

The owner requested using Universal Rules & Agents and Phase Tracker from ErosVault/My_Workflow as this project's rules. The complete universal-rules text was copied into AGENTS.md while retaining restaurant rules, electron-reference organization, account protection, the plan and screenshots. Source copies and hashes were preserved in docs/reference/workflow/ without modifying the two originals.

Added PLANS.md for the current 12 phases and detailed scope, PHASES.md for tracking 00–11, PROMPTS.md for six reusable requests, docs/phases/ for evidence, and three role files: planner, ux and reviewer. Memory, model and permission configuration remained unchanged.

> Historical adoption snapshot: the Figma/TODO wording below describes the original adoption task. The owner later selected Penpot in [decision 0015](0015-penpot-design-workspace.md); current [AGENTS.md](../../AGENTS.md) and [PHASES.md](../../PHASES.md) govern the active design tool and phase status.

## New execution rules

The Lead coordinates appropriate agents automatically, with a read-only Planner, independent work under explicit file ownership and a Reviewer independent of implementation. UI phases need a suitable reference validated in Figma and owner approval before implementation. Current screenshot direction is not evidence of Figma verification.

Every implementation phase has a traceable branch/worktree and PR, meaningful behavior tests before implementation, numeric measurements before optimization where applicable, and appropriate CI checks. Never merge without owner approval. Record DONE only after checks, review, approval, merge and required release verification; never start the next phase automatically.

## Status and limits

This is documentation/role preparation, not phase 00. All phases are TODO; no branches, PRs, approvals or Flutter results were invented. Earlier Electron tests and reference captures do not establish completion of new phases. Financial/local-scope and data-integrity rules remain in force, and this task changes neither AlDakhl, Madar nor Vault files.

Actual evidence, inspection and review outcomes are in the [adoption log](../log/2026-10-28-universal-workflow.md).
