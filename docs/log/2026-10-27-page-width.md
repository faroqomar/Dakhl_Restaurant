# Control excessive UI stretching

Status: implemented and verified in source/isolated Electron preview. Date: 2026-10-27.

Request: fix excessively stretched elements on all screens in wide windows, based on the owner's screenshot.

Change and rationale: capped work pages at 1280px instead of 1800px, and Sales at 1440px to fit catalog/ticket. Pages are centered, with headings/actions wrapping at narrow widths. Source: app/ui/ux.css; design direction is in .impeccable.md. No accounting or persistence changes.

Actual verification: npm test passed 114/114. An isolated illustrative-data Electron preview tested 13 screens at 1512, 1024 and 390px, 39 cases: headings present and no page-level horizontal overflow. The expense screenshot was visually reviewed. Local evidence: outputs/layout-review/results.json, expenses.png and verify.cjs. No restaurant data was saved.

Limits and next action: source/preview verification only; installed application was not replaced. Continue owner screenshots for remaining corrections.

Memory: recall was available but referenced withdrawn historical sources; current files were used. Sync then check returned a healthy service and no pending/failed work, but sources=0; there is no proof this log was indexed in the bank.
