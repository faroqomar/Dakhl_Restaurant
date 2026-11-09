# 2026-10-28: Required Madar documentation reading

Status: instruction changes implemented and source-reviewed; source delivery verified. Owner: maintainer.

The owner requested that this app always consult Madar_Engine documentation. The root AGENTS.md now requires its current README, rules, plan/tracker/prompts, documentation index, FULLSTACK, responsibility list, open-decision guide and memory guide before every task. Relevant contracts, decisions, examples and package READMEs follow. Every subagent receives the same requirement.

Shared engine implementation remains solely in Madar; the app owns UI/ViewModels, restaurant workflows, document composition and safeguards. Single-restaurant, offline, Arabic RTL, IQD, historical-record and unresolved-policy constraints remain required. The rule authorizes scoped source reading, not bank merging, phase progression, merge or deployment.

Engine runtime/public-contract changes: N/A — documentation instructions only. App runtime, design, benchmarks, migration and native tests: N/A. The existing phase statuses and unrelated pending work were preserved; PHASES.md links this maintenance record without starting a phase. [Madar outcome](../../../Madar_Engine/docs/log/2026-10-28-consumer-documentation-rule.md); [AlDakhl outcome](../../../AlDakhl/docs/log/2026-10-28-madar-documentation-rule.md).

Verification: current project sources were read and project-daftar recalled separately. The independent read-only reviewer `documentation_review` found no actionable issues across both new rule sections and verified all 20 Madar links. Direct validation of reading links, outcome links, scope/subagent wording, tracker/index references and log whitespace passed; `git diff --check` passed. No runtime checks were run or claimed. `./scripts/memory sync` followed by `./scripts/memory check` establishes source delivery separately; queued work remains pending until check passes.

Closeout snapshot, 2026-10-28 14:04 Asia/Baghdad: AGENTS.md matches its completed delivery hash and has no pending operation. Overall check still returns exit 1: 103 sources; pending `docs/log/README.md`, `PHASES.md` and this log; no failures; API/database healthy. The source files and latest outcome revision are preserved. Re-run `./scripts/memory sync` and `./scripts/memory check` after processing resumes; no complete-sync claim is made. Shared services were not restarted.

Future tasks must consult the current sources and the engine revision actually consumed. No new architecture choice or app phase was selected.

Later verification, 2026-10-28 15:05 Asia/Baghdad: processing completed without a service restart. The first full delivery pass returned exit 0 in all three project wrappers: Madar 27 sources, Dakhl_Restaurant 103 sources, AlDakhl 38 sources; no pending or failed operations and healthy API/database. This supersedes the earlier pending snapshot, which is retained as dated evidence. These final outcome revisions use the same sync/check closeout; no application phase status changed.
