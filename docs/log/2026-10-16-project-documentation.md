# 2026-10-16 — Daftar scope, documentation and memory

Status: complete; documentation, local verification, source indexing and recall succeeded. Date: 2026-10-16, Baghdad time. Owner: project maintainer. Source: the owner's request and confirmation of ResturanetAccounting.

## Request and changes

Established that this project serves one restaurant only and includes its invoices, campaigns, ideas and dedicated application, with documentation, follow-up and Hindsight. Added the documentation guide; scope, architecture and accounting references; idea/campaign records; decision/work templates; and agent instructions. Added the Codex connection and `scripts/memory` wrapper for bank `project-daftar`, and registered the folder in the shared Hindsight service.

This changes documentation and development-memory configuration. Application source, dependency files and real accounts were unchanged, and no synthetic financial records were created. During the task, the owner requested research for an old/new-price menu template. That actual request was recorded as IDEA-0001 and CAM-0001, with candidate links and verification limits. No design or published advertisement was implemented.

## Decisions and rationale

[Decision 0001](../decisions/0001-single-restaurant-and-project-memory.md) establishes the owner's scope, prevents confusion with AlDakhl and distinguishes existing capabilities from planned ones. I checked the total-balance rules in `model.js` rather than repeating an old design note that treated the formula as undecided.

## Verification

- Git was clean before the task. README, package.json, application/storage/report/model/UI source and tests were reviewed.
- Registering `daftar` returned bank `project-daftar`, the correct path and the Markdown allowlist. Initial recall returned zero results, as expected for a new bank before documents were submitted.
- `git diff --check`: passed after initial documentation was written.
- Final Python check: 20 Markdown documents and 60 local links, with no broken links. TOML parsing, project-daftar routing and template exclusion passed; AlDakhl routing remained separate and `retainSessions: false` remained configured.
- `npm test`: 78 passed, zero failed and zero skipped, on this task's date. Tests did not use actual restaurant accounts.
- `./scripts/memory sync`, then `./scripts/memory check`: after processing completed, the check returned exit 0, 16 sources, `pending: []` and `failed: {}`, with a healthy API and connected database. This proves delivery of the document versions before this verification result was added; delivery of the log update itself must be checked again after saving.
- `./scripts/memory recall --query 'Daftar is a one-restaurant project, advertising campaigns and worker advances'`: returned 22 results with Daftar source paths. A sample covering independent worker advances, application structure and memory boundaries was checked against documentation and source. No AlDakhl facts were transferred to the Daftar bank.

## Limits and follow-up

No new release testing or visual printing checks were included in this documentation task. MCP server visibility in a fresh Codex session was not verified; the project wrapper is the current verification path. The restaurant name, new invoice types, menu prices and publication details were not yet specified. The first idea was recorded at its actual status without inventing results.
