# Organize the inventory toolbar

Status: implemented and verified in source/preview. Date: 2026-10-27. Request: organize the search, filter and action bar identified in the owner's screenshot.

Change and rationale: grouped search, status and group controls into a consistently aligned/sized grid, with restock filter and Open Sales in a separate action group. One light-background toolbar with a subtle border adapts to two rows at medium widths and full-width search when narrow. Clarified searching by name/code/group and displayed active restock-filter state. Restored list focus after status/group changes for keyboard use. No stock rules, accounting or persistence changed.

Verification: npm test passed 120/120, including inventory filtering/search/restock. Isolated Electron previews at 1512, 1024 and 390px confirmed no page-level horizontal overflow. Local evidence: outputs/layout-review/inventory-results.json, inventory-toolbar.png and verify-inventory.cjs. The preview was visually reviewed and the user's Inventory browser view refreshed. Restaurant accounts were not used and the installed application was not replaced.

Memory: recall returned withdrawn historical sources, so current project files were used. The previous service check was healthy without pending/failed work but sources=0. Sync/check are repeated without treating that as proof these documents were indexed without registered sources.
