# Reorganize Settings

Status: implemented and verified in source/isolated preview. Date: 2026-10-27. Source: the owner requested a Settings redesign grouping useful options clearly.

## Change and rationale

- Four clear sections replace one long mixed page: Restaurant and Receipt, Sales and Shortcuts, Backups and Data, and About Daftar.
- Live receipt-identity preview, sales-card size options and links to edit categories/materials/products.
- Unified preference save across sections, with cancel, unsaved indicator and Command/Ctrl+S. Drafts survive section changes.
- Separate backup/export/import/restore actions, showing data location and backup state. File operations retain native desktop-application paths.
- Preferences use existing model fields; card size remains device-local under the existing key. No accounting, save-format or external-service changes.

## Actual verification

- npm test: 117/117 passed, including three new tests for cross-section drafts/unified save, unchanged data on validation/save failure, and keyboard navigation/cancel. The test also verifies safe escaping in receipt preview.
- Isolated illustrative-data Electron preview: four sections at 1512, 1024 and 390px, 12 cases without horizontal overflow. Local evidence: outputs/layout-review/settings-results.json; section images and verify-settings.cjs in the same folder.
- Visually reviewed the UI and opened the new Settings in the user's browser preview. Browser image: outputs/layout-review/settings-browser.png.

## Limits and next action

The installed application was not replaced. Backup export/import operations were not performed against restaurant accounts during this round; their existing paths were preserved. Next: owner design review in the browser.

project-daftar recall was available but returned withdrawn historical sources, so current files were used. Synchronization outcome is recorded after checking.

Memory outcome: sync/check returned healthy service without pending/failed operations, but sources=0. This does not prove this round's documentation was indexed; source configuration needs separate follow-up.
