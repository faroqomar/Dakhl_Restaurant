# Decision 0001 — One restaurant and dedicated Daftar documentation and memory

Status: approved by the owner; operational verification is recorded separately in the work log. Date: 2026-10-16. Owner: restaurant and project owner. Source: current direction and confirmation that ResturanetAccounting is the selected project.

## Context

The owner confirmed that the project and application serve only one restaurant, and that invoices, campaigns, ideas and the dedicated application need documentation, follow-up and Hindsight memory. The parent folder also contains AlDakhl, which has different scope, technology and memory; those must not be imported into Daftar as its decisions.

## Decision

1. Establish the [single-restaurant scope](../reference/project-scope.md) for all future work.
2. Preserve the current financial behavior and structure as demonstrated by the source, documenting them in separate references.
3. Record ideas, campaigns, their states and evidence; documentation does not mean implementing advertising tools or approving a budget.
4. Use project Markdown as the authoritative reference, with decisions, rationale, dated verification logs and empty templates.
5. Register the project as `daftar` in the shared local service and use bank `project-daftar`. Project files are the source of truth and memory is a derived index; restaurant account data is not stored in this bank.
6. Require future work to recall relevant context, inspect source, document outcomes and verify completed synchronization under `AGENTS.md`.

## Rationale and consequences

One restaurant is an explicit request; a multi-restaurant product would add unrequested scope. Documentation keeps decisions reviewable without depending on the conversation, while the index helps retrieve them. A separate bank prevents the usual confusion with AlDakhl. Reuse the existing service rather than install another one.

This choice does not change Electron or the account format and does not add Hindsight to the running application. Documentation must track actual work. Indexing uses the configured provider and may fail; project files remain available. There is no claim that every conversation is retained automatically.

## Verification

See the [2026-10-16 log](../log/2026-10-16-project-documentation.md) for file inspection, tests, completed synchronization and recall. This decision did not define a campaign or a new invoice type and did not publish an advertisement.
