# Move Electron into a reference folder

Status: owner-requested folder reorganization; Flutter implementation had not started. Date: 2026-10-28, Asia/Baghdad.

## Request and change

The owner requested preserving the current application in a new project subfolder for reference, while leaving plans/images outside it. electron-reference/ now contains source, dependencies, tests, application tools and original README. docs/, outputs/, dist/, design/, Git and project configuration remain at root; links inside the reference preserve old paths without moving images.

Added the root README, reference-work boundaries and decision 0013. Planning/memory/capture tools remain in scripts/; capture paths and documentation/plan source links were updated to Electron's new location. Updated the recommended Flutter location to root.

## Actual verification and limits

- Hashes of 68 source/asset/test/npm-configuration/README/tool files match their pre-move originals.
- All 502 verified images/drawings in docs/planning/flutter-rebuild, outputs, dist and design retained original paths/content, including 179 plan screenshots. The capture manifest was unchanged and no new capture ran.
- npm --prefix electron-reference test: 140/140 passed, zero failed/skipped. Local evidence: dist/electron-reference-relocation-tests.log.
- Opening Electron UI with illustrative data and an isolated bridge from the new location succeeded: 12 navigation destinations and 8 fake products. The plan gallery loaded 179 images/12 phases. Evidence: dist/reference-folder-smoke.json. Real app/main.cjs was not run to access restaurant accounts.
- Checked 97 current/archived Markdown/HTML documents and affected links: no broken links in the checked set. Capture-tool syntax passed; the plan was regenerated with updated reference paths without recapturing images.
- Ran memory sync/check: healthy service, 90 sources and indexing requests still processing without failed operations at follow-up. Indexing is not complete until pending work clears. Local evidence: dist/reference-folder-memory-check.json.

Accounts and installed application were not opened, and no Flutter scaffold was created. Git remained at root; no separate repository or automatic commit was created.

## Next action

Start the rebuild at project root according to the plan; consult electron-reference/ when old source is needed. Plans/images remain at docs/planning/flutter-rebuild/.
