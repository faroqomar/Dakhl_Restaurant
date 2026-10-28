# Remove the worker-advance UI

Status: implemented and verified in source/preview. Date: 2026-10-27. Request: remove worker advances from the application.

## Change and rationale

Removed the advances UI module, bindings, forms and handlers, and removed its page from navigation/shortcut customization. Validation clears old shortcut slots targeting that screen while preserving other shortcut positions. The workers and savingsEntries records, historical validation, persistence/backup/report compatibility remain. The request does not require destroying data or changing restaurant accounts. [Decision 0007](../decisions/0007-retire-worker-savings.md).

## Actual verification

npm test passed 120/120. Three removed-screen tests were replaced with two tests for removal of entrypoints, preservation of records during settings save, and legacy file/shortcut compatibility with save/reopen/JSON. Historical advance-model tests continue to validate old records. The count changed from 121 to 120 because retired UI tests were removed and compatibility tests added.

The isolated preview checks remaining screens at three widths; results: outputs/layout-review/results.json. Browser navigation was visually reviewed to confirm the worker-advance screen was absent, and both browser previews refreshed. Local image: outputs/layout-review/no-worker-savings.png.

## Limits and follow-up

Restaurant account files were neither read nor modified during testing; data was isolated/illustrative. The installed application was not replaced. project-daftar recall returned withdrawn historical sources, so current files were used. Memory service had been healthy without pending/failed work but sources=0. Sync/check are repeated without claiming unregistered sources were indexed.
