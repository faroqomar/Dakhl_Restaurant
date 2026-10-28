# Reusable Penpot skill and failure record

Date:2026-10-28 (Asia/Baghdad). Owner request: before more design work, create a skill for using Penpot and document the mistakes that caused excessive time and token usage.

Created and installed the discoverable user skill [penpot](/Users/eros/.codex/skills/penpot/SKILL.md), with separate references for the existing connection, screenshot-recreation mechanics and [41 observed mistakes/fixes](/Users/eros/.codex/skills/penpot/references/mistakes-2026-10-28.md). The short entrypoint loads only applicable details; future normal edits do not load the complete failure record.

The biggest agent errors were scope substitution (blank shell instead of the three screenshots), bulk creation before inspecting a representative native export, assuming source/browser success implied Penpot success, repeating full batches for small fixes, dumping excessive data and insufficiently robust error handling. The detailed record also covers fonts/baselines, hidden and native control states, SVG transforms/masks, image fill proportions, destructive replacement cleanup, dimensions/profiles, connection/runtime issues, screenshot evidence and the worktree-memory registration limitation. It records no invented token or timing total.

Added a reusable SDK helper for read-only diagnosis, explicit tool/code calls, staged large SVG transfer and scale-2 native export. It does not install, restart, retry mutations or create/import artwork automatically. It suppresses large transport output and catches tool errors delivered as plain text. Native Penpot tools remain preferred when exposed.

No live Penpot design was changed during this task. The connection diagnostic reached the endpoint and correctly reported that the Penpot plugin was disconnected; it did not reconnect or reopen the page. Phase00 remains DESIGN awaiting owner approval. No Flutter implementation, merge or next phase started.

Validation and independent review are recorded below after execution. The initial system Python lacked PyYAML for the bundled skill validator; the existing Hindsight Python environment ran it successfully, without installing packages. No unrelated runtime was repaired.

Final validation: bundled skill validator passed; nine offline protocol/error-handling checks passed; JavaScript syntax and local skill-reference links passed. Independent Reviewer dry-ran the screenshot-recreation scenario and inspected the helper. One P2—generic calls silently dropping image blocks—was fixed by explicit rejection with guidance to the dedicated PNG export command. Image-only and mixed-response regressions are now covered. Reviewer re-verified the fix and reported no remaining actionable findings in the reviewed scope. No live board creation/export test was claimed for this skill-creation task.

Memory delivery: the standard sync/check commands still use the registered root checkout. Their healthy/no-pending result cannot establish delivery of this worktree-only log or the global user skill. No shared registry/root files were overwritten to index them; integration/delivery of the new project log remains pending.
