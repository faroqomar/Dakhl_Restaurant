# Consolidate Flutter plan phases

Status: plan/documentation change only; Flutter implementation had not started. Date: 2026-10-27, Asia/Baghdad.

## Request

The owner requested identifying and merging phases that could be combined. Platform, persistence, design, image and feature requirements remained as approved in the previous task.

## Change and rationale

Reorganized 19 phases into 12, numbered 00–11, combining design/navigation; sales/drafts/held orders; categories/daily accounts/cashbox; suppliers/materials; purchases/payments; and statements/day review/reports. Combining invoice/payment removes an internal dependency on a later delivery; combining daily accounts/cashbox makes transfer/funding-source verification one workflow.

Each original path's items remain under separate headings in its consolidated phase. All images and the capture manifest were retained, with gallery phase numbers mapped to the new plan. Added a phase map, merge rationale and item audit. Archived the previous version, repaired its links and excluded archived Markdown from indexing. Updated readable pages, indexes, dependencies, MVP acceptance and decision 0012.

## Verification and limits

- Original-plan preservation check passed: the 19 original phase definitions match the archive, and every previous phase has exactly one owner among the 12 new phases.
- Preserved 89 work items and 39 feature-specific acceptance criteria. Every item was found in its new file after phase-reference updates; each phase retains the common acceptance gates.
- Checked all 179 image hashes unchanged; every old phase's image links remain under its new owner.
- Markdown/HTML links passed for current/archived packages; dependency direction points to earlier phases; no active implementation references use numbers 12–18. All archived Markdown carries hindsight:ignore.
- Electron gallery verification passed: 179 images, 12 phase filters each showing images, 14 report references, invoice search returning results and no broken visible images. Local evidence: dist/flutter-phase-merge-validation.json and dist/flutter-phase-merge-gallery-qa.json.
- Ran memory sync then memory check: 88 sources, healthy service, processing requests and no failed operations. Indexing was not declared complete. Detailed local result: dist/flutter-phase-merge-memory-check.json.

No new application-test result exists for this task. Application source, restaurant data and reference images were unchanged. The earlier record's 140 passing tests belong to its previous baseline and are not presented as a new result here.

## Next action

Use the [current plan](../planning/flutter-rebuild/README.md) and new phase map when implementation begins. All phases remain planned; design edits are decided with the owner at each phase.
