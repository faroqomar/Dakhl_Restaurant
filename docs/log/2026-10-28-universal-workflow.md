# Adopt workflow rules and phase tracking

Status: rules/documentation/roles initialization, not Flutter-phase implementation. Date: 2026-10-28, Asia/Baghdad.

## Request and change

The owner requested adopting the supplied universal-rules and phase-tracker template files. Included the complete universal text alongside retained project rules in AGENTS.md, and preserved source copies/hashes. Added PLANS.md and PHASES.md for current phases, PROMPTS.md with six prompts, the docs/phases/ evidence index and three project-role files. Updated published-plan acceptance gates to reference tracking, approval, merge and required review.

At this adoption snapshot, all phases were TODO, with implementation/result/approval fields unverified. Figma is pending for UI phases and N/A for the current nonvisual 00/02/11 scope, subject to reassessment when UI is added. Reference preparation and Electron tests do not count as completed Flutter work.

## Verification

- An independent Planner performed read-only review before adoption; an independent Reviewer then inspected the result read-only and found no actionable findings.
- Both source copies match their Vault-file hashes; universal text and prior project rules remain complete in AGENTS.md. The original files were unchanged.
- At the original adoption snapshot, verified 12 table entries and 12 phase records, all TODO, with required template fields, Figma pending for 9 phases and conditional N/A for 00/02/11.
- planner/ux/reviewer TOML parsed with the three required keys, without model/provider/permission changes. Automatic discovery in a running session or security isolation from read-only role wording is not claimed.
- Checked 49 rule/plan/publication documents without broken links, 6 reusable prompts and unchanged hashes for 179 images. Local evidence: dist/universal-workflow-validation.json.
- Default Python lacked tomllib; validation succeeded using the existing Hindsight interpreter without installing packages. Regenerated the plan with acceptance gates; no Flutter tests ran and previous Electron results were not relabeled as new.
- Added PLANS.md, PHASES.md and PROMPTS.md only to daftar memory sources, preserving a private prior-source-configuration backup. Sync/check ran: 97 sources, healthy service and indexing operations processing without visible failures. Indexing was not declared complete; local evidence: dist/universal-workflow-memory-check.json.

Reference-application files, images and MCP/model/permission configuration were unchanged. No Flutter implementation, PR or merge began. Existing uncommitted changes were preserved. This initializes rules rather than an implementation phase requiring an invented branch/PR record.

## Next action

The owner chooses a phase to start. Apply the new design/planning/isolation/testing/review/approval rules, update PHASES.md with actual evidence, and stop at phase end without automatically starting the next phase.

Later-state clarification, 2026-10-28: the owner subsequently selected Penpot ([decision 0015](../decisions/0015-penpot-design-workspace.md)) and phase00 advanced to its current BLOCKED state. The adoption counts above remain historical evidence; [PHASES.md](../../PHASES.md) owns current status.
