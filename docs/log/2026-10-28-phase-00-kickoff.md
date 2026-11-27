# Phase 00 kickoff

Date: 2026-10-28 (Asia/Baghdad). Status: tracker initialized; implementation not started.

Request: start phase 00 from PLANS.md with Lead + UX, initialize its tracker, return earlier screenshots/design references, and stop before proceeding; record N/A for non-UI work.

Changes: created `codex/phase-00-baseline` from `aa624bc`, preserving all prior uncommitted work. Updated only the phase 00 tracker and kickoff evidence/index/log files. UX independently confirmed Design: N/A for setup-only scope; a read-only Planner bounded future implementation. [Evidence and plan](../phases/00-baseline-kickoff.md).

Reason: phase 00 is a toolchain/delivery/capability foundation. Product UI and design-system implementation belong to later approved scope. Existing reference screenshots and the partial Figma handoff are returned without claiming fresh Figma validation, accessibility approval or recovered original Nook attachment.

Verification: passed kickoff consistency checks across five documents and 97 local links; all 12 tracker statuses are consistent (00 PLANNING, 01–11 TODO), the phase branch is active and the staging area is empty. All 179 screenshot SHA-256 hashes match the frozen manifest. `git diff --check` passed for tracked changes; new kickoff documents were checked directly. These are documentation/reference checks, not Flutter verification. Project-memory sync/check is recorded below. No application launched, real accounts opened, Flutter tests/builds run, installation attempted, PR created or merge performed.

Memory delivery: `./scripts/memory sync` accepted the update. The first `./scripts/memory check` returned exit 1 with five pending documents (PHASES.md, both index files, this log and the phase evidence record), no failures and a healthy API/database. Delivery remains pending until a later check reports no pending/failed work; queue acceptance is not completion.

Limits and next step: stop after kickoff. Before implementation, separate prerequisite uncommitted adoption/layout work into a traceable baseline for a phase-only PR. Device/signing/font/package evidence, independent implementation review, mandatory CI, owner merge approval and release/rollback evidence remain pending. Phase 01 remains TODO.

## Follow-up — Figma recreation requested

The owner then requested recreating the design in Figma before proceeding. Created task session `64fe741d-7d09-4d7a-bd38-851fbde666ef` for the existing file. Both metadata inspection and editable-canvas inspection were rejected by the Starter MCP quota; live account inspection confirmed Full seat on Starter. No Figma content changed. UX prepared a reference/state/accessibility matrix locally. Phase 00 is now BLOCKED on this owner-requested prerequisite; its technical-shell design classification remains N/A. [Live evidence and resume scope](../phases/00-figma-reference-preparation.md). No implementation or phase 01 work started; owner design approval remains pending.

## Follow-up — Penpot replaces Figma

The owner explicitly replaced Figma with Penpot, authorized plugin/MCP setup and requested only phase-00 designs and wireframes matching the screenshots. The initial blank-shell boards misinterpreted that scope; they are superseded. The current review set is the three listed sales, daily-expenses and settings/data screenshots plus one matching wireframe each, at 1440×1000 logical pixels. [Current evidence](../phases/00-penpot-reference-recreation.md), [workspace decision](../decisions/0015-penpot-design-workspace.md).

Created a dedicated managed worktree on `codex/phase00-penpot` from `ecf692b`; preserved concurrent root-checkout work. Installed official Penpot MCP/plugin locally with loopback-only services and registered it with Codex. The stable plugin/server reports a cloud-version mismatch; creation/export operations were tested individually rather than treating installation as compatibility proof.

An isolated synthetic Electron export reproduced all three frozen source PNGs byte for byte. Measured geometry, native control text, exact browser baselines and macOS font outlines supply the editable recreation. No font files or whole-screen raster substitutes were uploaded. Initial native Penpot exports revealed dropped/misplaced icons, clipped-photo rendering and hidden collapsed-details text. Those failures were recorded by independent UX review and are being corrected and re-exported before owner review. Source-renderer pixel parity alone is not Penpot parity.

No Flutter implementation, real-account access, phase 01, merge or phase completion is authorized by this preparation record. Owner design approval remains pending.

Final preparation result: all three native designs and their three matching wireframes are saved in the canonical Penpot page. Superseded blank-shell boards are hidden at x=-15000. Independent UX rechecked all six final native exports and resolved every identified transfer finding, including the 7px sales ready dot. The result is ready for owner design review, not marked approved. Native PNGs retain small rendering differences; measured comparison explicitly records `pixelIdentical:false` for all three designs.

Verification: all three isolated source PNGs remain byte-identical to their originals; six native board sizes and image-fill boundaries checked; no whole-screen UI raster found; 130 local documentation links checked with zero broken links; source exporter syntax, vector builder syntax and `git diff --check` passed. Native exports and the independent review contain the final artifact hashes. No Flutter tests or builds were run because no Flutter behavior was implemented.

Project memory: `./scripts/memory sync` and `./scripts/memory check` completed against the registered root checkout; check reported healthy API/database, 102 sources, no pending or failed work. That registration still points to the root checkout, so this does **not** establish delivery of the new worktree-only documents. Their project-memory delivery remains pending integration; no root files or shared project registry were overwritten merely to index them.

Stop: await explicit owner approval of the Penpot design. Phase00 remains DESIGN, phase01 remains TODO; PR/merge and implementation verification remain pending.
