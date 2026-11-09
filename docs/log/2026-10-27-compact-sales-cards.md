# Smaller sales cards with corner addition

Status: implemented and verified in source/preview. Date: 2026-10-27. Request: remove the wide add button, place an icon in a corner and make cards compact.

Change: replaced the bottom Add + label with a plus icon over the image corner, retaining quantity in the opposite corner. Reduced image dimensions, spacing and typography to shorten cards while preserving name, price, stock and photo. Each card is one button, without nested buttons; clicking either the icon or card adds the item. Accessible button names describe item and price. No account, stock or sales rules changed.

Verification: npm test passed 121/121. The new test clicks the corner icon twice and confirms one unit added per click, with total/count updated and no actual sale recorded. Isolated Electron previews at 1512, 1024 and 390px had no page-level horizontal overflow. Local evidence: outputs/layout-review/sales-corner-results.json, sales-corner-cards.png and verify-sales-cards.cjs. The browser screen was visually inspected and left open; sales-cards-browser.png is in the same folder.

Limits: restaurant accounts and the installed application were untouched. Recall returned withdrawn historical sources; current files were authoritative. Earlier memory checks had no pending/failed work but sources=0; this run uses sync/check without claiming absent sources were indexed.
