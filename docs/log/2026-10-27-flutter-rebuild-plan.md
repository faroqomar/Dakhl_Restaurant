# Flutter rebuild plan and screenshot library

> Later update: the owner requested consolidation into 12 phases; see the [consolidation log](2026-10-27-flutter-phase-consolidation.md) and [decision 0012](../decisions/0012-merge-flutter-rebuild-phases.md). Counts and divisions below describe the original pre-consolidation output, not current implementation numbering.

Status: plan and visual references created; Flutter implementation had not started. Date: 2026-10-27, Asia/Baghdad.

## Request and clarifications

The owner requested a complete feature-based phase plan, with screen/design images through MVP. Confirmed macOS, Android and iPhone; local offline operation with backup/import; matching the current design until phase-specific owner changes; and PDF/sharing/ordinary system printing.

## Change and rationale

Created docs/planning/flutter-rebuild: master plan, 19 phase files, filterable local gallery, complete window/document/empty/form captures, extracted reference design board, design tokens, reference CSS/images, financial-parity contract, feature/source coverage and MVP acceptance list. Every phase describes outcome, dependencies, work, acceptance criteria, screenshot links and implementation handoff.

Added decision 0011 to establish the owner's choices. Storage, package, font and distribution recommendations remain labeled proposals or early decisions. No Flutter files were created or application source changed during this task. Pre-existing application changes were preserved.

## Actual verification

- Current-source inspection: 12 visible destinations, account schema 11 and source version 1.12.0; returns, held orders and payment receipts exist; worker UI is removed while historical records remain.
- npm test: 140/140 passed, zero failed/skipped. Local log: dist/flutter-rebuild-baseline-tests.log. This verifies Electron, not Flutter.
- Final capture: 179 images, no errors in the final run. Count, dimensions and source/image hashes are in screenshot-manifest.json. scripts/capture-flutter-reference.cjs uses synthetic in-memory data and an isolated profile; it does not read restaurant accounts or the installed app's folder.
- Visually reviewed samples of Sales with a ticket, the narrow purchase form, design board and report reference. Image-hash/dimension checks, unchanged application-source hashes, links for every plan document and at least two embedded images per phase file passed.
- Electron gallery verification passed: 179 cards, all 19 filters show images, 14 report HTML references, invoice search returns results and no broken visible images. Added an explicit assertion that populated sales history displays the illustrative invoice before capture.
- Created readable HTML for plans/phases/contracts alongside Markdown, gallery and design board: 27 HTML documents. Local links, images and source hashes passed. Visual inspection found the illustrative sales-history status filter was wrong; corrected only the capture tool and repeated the final capture with populated history plus an additional bottom capture, resulting in 179 final images.

## Limits

Phone captures are narrow Electron layouts, not iPhone/Android execution. Report images show HTML, not proven Flutter PDF output. Android font availability, signing, distribution, printing and actual devices require verification in their phases. Visible error states are synthesized for reference; no actual disk failure is claimed.

project-daftar recall succeeded but returned old withdrawal facts referencing the previous folder; current files were authoritative and those facts were not used to establish project state. Initial memory check showed sources:0 because registration still pointed to deleted ResturanetAccounting. After confirming the old folder was absent, only daftar's shared Hindsight path/bank mapping was corrected, preserving a private backup of prior configuration and leaving other project banks/paths/index patterns unchanged. The check then saw 92 sources; requests were processing at the first post-correction check. The final outcome below follows the completed inspection; submission is not treated as ingestion completion.

## Next action

Memory follow-up at plan delivery: healthy service, correct current folder and 92 visible sources. Indexing was still processing and was not declared complete; no operation errors appeared in the checks performed. Detailed local results: dist/flutter-plan-memory-check.json. The package is preserved independently of indexing completion; queue submission does not yet prove recall availability.

Phase 00 starts when implementation is requested: establish the environment, distribution paths and devices, then components/persistence before application features. Current design remains the reference unless the owner decides otherwise at a phase.
