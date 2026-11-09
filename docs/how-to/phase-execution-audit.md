# Phase execution audit

Owner-required from 2026-10-29 for every new or resumed Madar/Dakhl phase. Purpose: make work, delays and avoidable cost visible and identify what code/scripts should automate. This supplements the existing prevention catalog; it does not waive checks or authorize extra features, publication, merge or deployment.

## One running file per phase and project

Create `docs/log/phase-<ID>-execution.md` from [the template](../templates/phase-execution.md) before substantial work. Resume the same journal rather than create a competing one. Each affected project owns its own events; link counterpart events and record N/A when unaffected. Shared runtime ownership stays in Madar; this audit adds no runtime contract or app feature.

At session start read the compact handoff and relevant prevention entries, then only the needed event/evidence slice. Do not reload the full history on every action. Include the journal path in that phase's tracker. If work began without a journal, create one immediately, identify retrospective gaps and log prospectively; never invent missing timestamps or claim complete coverage.

## Record as work happens

Append an event for every tool/command attempt or batch (list its individual operations), file-change batch, agent task/handoff, review, test/build, approval and wait. Record cheap reads/no-ops as concise rows too. Append failures immediately; link a later fix/verification to the original event ID. Use sanitized exact commands when useful; link lengthy stdout/stderr/artifacts rather than duplicate them. Preserve previous outcomes when adding a correction.

Required fields: event ID; recorded/start/end UTC; actor and project/phase or separately authorized extra scope; action and reason; affected files/source/tool revisions; actual outcome/exit status; evidence; problem and cause confidence; retry count; wait category and duration; avoidable/unavoidable/mixed/unknown; next action; automation candidate. Record approvals narrowly and distinguish unavailable, failed, excluded and passed. Document agent-caused errors and repeated work as plainly as external delays.

Classify time as execution, tests/build/CI queue, service/tool access, approval/owner response, agent coordination, rework, audit overhead or unknown. Capture start/end when starting a wait. Concurrent intervals overlap: do not add them into a fictional phase total. Wall-clock time is not active human/agent effort. If duration is measured by a tool, identify that source. If unavailable, use unknown rather than estimate. Retrospective timestamps must identify their evidence.

Record exact API token/cost metadata only when available for that operation. Otherwise mark unknown. Tool-reported output-token counts, output bytes and number of calls are useful separately labelled proxies, not billable totals. Never infer money saved from shorter text or claim a measured improvement without comparable before/after runs. Do not query account-wide quota to pretend it is phase cost.

## Closeout and automation review

Keep the handoff short: current scope, exact approved/source revisions, latest verified result, blockers, pending operations and next concrete action. At each step/closeout summarize measured critical-path waits, repeated attempts, avoidable causes, unknown attribution and original versus added scope. Rank time/cost causes only as far as evidence permits; include logging overhead itself.

For each automation candidate record evidence/event IDs, repeated manual operation, proposed reusable owner, expected benefit (measured or hypothesis), implementation effort (unknown or labelled estimate), authorization/dependencies, acceptance test and status. Prefer a small reliable script over a new service. Candidate status is not implementation. Do not weaken required tests/approvals to reduce cost. Update the existing prevention catalog with verified reusable remedies, linking events instead of duplicating the entire log.

## Keep this affordable and safe

The detailed journal and blank template carry `<!-- hindsight:ignore -->`. The journal stays readable in Git; the memory watcher must not repeatedly ingest its growing history. Write one short English milestone/closeout digest under docs/log, then sync/check that digest and standing policy in the correct project bank. Preserve source/operation receipts; resume a saved pending operation rather than re-submit. Do not copy raw conversations, secrets, account data or hidden reasoning. Avoid broad searches/output dumps, repeated full reviews of unchanged source, speculative retries and updates that only narrate unchanged polls.
