# Implement Daftar audit fixes

Status: implemented and verified in source/local build; not an update to the installed application. Date: 2026-10-26. Authorization: the owner requested "fix them all" after the 64-item report and pop-up request.

Addressed D01–D64 while preserving one-restaurant scope, local accounts, Arabic RTL and separation between daily funds, cashbox, suppliers and worker advances. Individual details and each item's verification basis are in the [resolution matrix](../planning/2026-10-26-ux-audit-resolution.md).

Version 1.12.0, account schema 10. Navigation/forms use pop-ups, the sales draft can be restored, corrections preserve their trace, filters/reports are clearer and records are paginated. UI WebP photos total approximately 500 KB instead of loading approximately 20 MB of originals; originals remain in the workspace and are excluded from the build.

## Actual verification

- 113 passing tests cover accounting, compatibility, persistence, UI, PDF reports and native import/restore through Electron handlers using temporary files.
- Restoring corrupt data preserved the corrupt original before replacement; cancelled import left accounts unchanged; opening exports is restricted to session-owned files.
- Browser pass across all thirteen sections, without JavaScript errors in recorded flows. Visible-text checks on captured screens found no contrast candidate below the threshold; this is not comprehensive accessibility certification.
- Sizes 1440×1000, 900×580, 760×844 and 390×640, plus 200% zoom: payment and purchase fields/save remained reachable.
- A 5,000-invoice fixture displays 50 rows per page while retaining totals for all results. Recorded local timing applies only to this fixture/device.
- Actually generated all eight PDF types; reviewed report screenshots and rasterized sales/purchase PDFs.
- macOS ARM64 build at `dist/Daftar-darwin-arm64/Daftar.app`. The installed application was not replaced and restaurant records were not opened for testing.

Evidence in outputs/ux-fixes-2026-10-26 includes tests, browser verification, screenshots, PDFs, resolution report and build. The new preview on port 4329 uses separate illustrative data. Old port 4317 was not refreshed to avoid losing the user's context.

## Limits

Actual scanner/printer hardware and a comprehensive VoiceOver session were not tested. The preview does not implement native Mac file operations; these exist in the build and were tested in isolation. Resolving the list does not guarantee absence of every possible defect. Next: owner review of the updated experience. Documentation-index synchronization completed; the service check returned empty pending/failed sets.
