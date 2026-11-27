# Document and track work

Status: approved working method. Date: 2026-10-16. Owner: project owner and implementer. Source: the request to document restaurant-related work and track it with Hindsight.

## Where information belongs

| Information | Location |
| --- | --- |
| Idea or improvement before implementation | `docs/planning/ideas.md`, then a separate document when needed |
| Campaign, objective, status and outcomes | Private campaign records |
| Significant decision and rationale | `docs/decisions/NNNN-topic.md`, updating the decision index |
| Rule or description of the current state | `docs/reference/` |
| Repeated operating or recovery procedure | `docs/how-to/` |
| Completed work, actual tests and remaining work | `docs/log/YYYY-MM-DD-topic.md`, updating the work index |

## From idea to implementation

1. Record the owner's direction with date, source and a stable identifier such as `IDEA-0001`. The initial state is "idea"; it does not approve construction.
2. During discussion, identify the problem, desired outcome and open questions. Link related campaigns or decisions.
3. When implementation is approved, record scope and success criteria, then carry out the request and update the affected reference.
4. After work, record changes, actual verification and limits, linking evidence to the idea. Use "implemented" and then "verified" when appropriate evidence exists for each.
5. Synchronize memory and verify completion under the [Hindsight guide](memory.md). If the service fails, files remain preserved and pending status is reported honestly.

## Campaign tracking

Each campaign has an ID such as `CAM-0001`, objective, audience, platform, duration, budget, status, asset links and approval decision. Do not turn a proposed budget into actual spending. At campaign end, separate actual spend from planned spend, state the result source/period and record lessons. Do not calculate financial return without a clear attribution basis.

Publishing, spending a budget or sending a message requires an authorizing request; a campaign entry is not permission for external execution. Public project files and memory contain sanitized descriptions/results; customer materials and sensitive information stay outside them.

## Finishing a task

Update state, date, source and related documentation. Write the work log with verification results and update its index. Avoid repeating behavior descriptions: the reference owns the rule, the decision owns its rationale and the log owns the event outcome. Preserve superseded decisions and link their replacements; do not erase earlier reasoning.

This method tracks work actually recorded. It claims neither automatic capture of every conversation nor that no agent can ever violate the rules.
