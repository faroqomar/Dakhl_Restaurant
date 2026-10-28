# Dakhl_Restaurant Hindsight memory

Status: project-specific configuration; operating results are in the [setup log](../log/2026-10-16-project-documentation.md). Date: 2026-10-16. Owner: project maintainer. Source: shared local Hindsight configuration and owner request.

> Current displayed project name: **Dakhl_Restaurant**. Connection keys `daftar`, `project-daftar` and `daftar_memory` remain unchanged to preserve the existing bank; they are not current project names.

## Project identity

- Legacy registration key: `daftar`; current project name: **Dakhl_Restaurant**; current folder: `/Users/eros/Dev/Eros_Projects/Dakhl_Restaurant`. Registration path and bank mapping were corrected on 2026-10-27 after verifying the old ResturanetAccounting folder no longer existed; the bank ID did not change.
- Displayed bank name: **Dakhl_Restaurant**, with stable technical ID **project-daftar**, separate from `project-aldakhl`.
- Shared service: `/Users/eros/Dev/Eros_Projects/Hindsight`.
- [Memory UI](http://127.0.0.1:9999): select **Dakhl_Restaurant** (ID `project-daftar`) to browse documents, facts and recall.
- Codex connection: `.codex/config.toml`, server `daftar_memory`. Opening/reopening a session from the project folder may be needed to load the server; the project command works independently of MCP tools appearing in this conversation.

## Recall and retention

Update, 2026-10-28: root PLANS.md, PHASES.md and PROMPTS.md were added to the daftar project's source allowlist so phase definitions, state and execution rules participate in synchronization. This excludes source code, dependencies and accounts. Original-rule archives in source.txt format are not Markdown-indexed. Other projects' source lists were unchanged.

From the Dakhl_Restaurant folder:

```sh
./scripts/memory recall --query 'What is the project scope and what are the worker-advance rules?'
./scripts/memory reflect --query 'Which decisions remain open for this idea, and what are their sources?'
./scripts/memory sync
./scripts/memory check
./scripts/memory status
```

Recall before work, then read current source. `reflect` performs deeper analysis and uses subscription capacity. Retention means writing a decision/useful knowledge into project files and then indexing them, not retaining every conversation. Shared configuration currently uses `retainSessions: false`, imports no raw conversations and runs no automatic codebase survey.

The watcher checks documents approximately every 60 seconds using stable IDs and content hashes. Registered paths are `README.md`, `AGENTS.md`, `docs/**/*.md` and `FULLSTACK.md` if created later. There is no need to create FULLSTACK or import another project's technology. Templates containing `<!-- hindsight:ignore -->` on a separate line are excluded. Source code and account files are outside this scope; the application reference summarizes necessary behavior.

`sync` submits changes. `check` updates operation states and fails if anything remains pending or failed. A `queued` response or healthy API alone is not success. Recheck after processing, and recall a specific rule to verify discoverability. `hindsight_sync_status` describes the default seeding workflow disabled here; project-file checks are authoritative for completed delivery.

## Retained knowledge and private material

Retain scope, decisions, rationale, acceptance criteria, verified outcomes, blockers and next actions. Never retain `accounts.json`, its backups, invoice exports, phones, customer data, secrets or complete sessions. Review a document before placing it in indexed paths.

Hindsight is not part of the running Dakhl_Restaurant application or its account persistence. The memory database is local, but the shared service uses provider `openai-codex` to send indexed text and reflection questions to OpenAI through the configured subscription; processing is not fully offline. Banks provide organizational separation within this local service, not multi-account access control.

## Failure or incorrect information

Preserve documentation and record failure/pending status. Inspect `./scripts/memory status` and shared-service logs before retrying. After repairing the cause:

```sh
./scripts/memory sync
./scripts/memory retry
./scripts/memory check
```

Do not repeatedly retry a permanent failure without addressing its cause. On discovering stale information, correct the source, add a dated correction decision/log, link the superseded record and synchronize. Do not solve a memory error by reinitializing the bank or deleting history.

## English-only knowledge

Owner confirmed English-only source documentation, retained facts/contexts/entity labels and generated knowledge/reflections on 2026-10-28. Both project banks have scoped English-language missions/directives; preserve them during reconfiguration. Translate source prose without changing Arabic runtime UI or frozen evidence. Replace/correct the affected project sources with provenance and verify actual active content after processing; an accepted operation, healthy API or empty generated page alone does not prove migration. Never clear whole banks, mix projects or change shared model/provider settings for language conversion.
