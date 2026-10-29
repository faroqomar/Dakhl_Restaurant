# Compact order details

Status: implemented and verified in source/preview. Date: 2026-10-27. Request: reduce text, button sizes and space in order details.

Change: each item uses a compact row for name, unit price, quantity, total and deletion; spacing/type were reduced, as were quantity-counter height, delete/confirm/clear buttons and order-type fields. Ticket header/total are smaller. Details remain scrollable, and very narrow windows use two rows when needed. No order data or sales formulas changed.

Verification: npm test passed 120/120. Browser verification used the owner's existing illustrative order: its 15 items and IQD 167,000 total remained unchanged after the UI update. A separate Electron preview with a 15-item fixture checked widths 1512, 1024 and 390px. Local evidence: outputs/layout-review/compact-order-results.json, compact-order-panel.png and verify-order-panel.cjs. No restaurant-account save or sale occurred during this run. The installed application was not replaced.

Memory: recall returned withdrawn historical sources, so current files were authoritative. The previous service check had no pending/failed work but sources=0. Sync/check run without treating that state as proof of document indexing when no sources are registered.
