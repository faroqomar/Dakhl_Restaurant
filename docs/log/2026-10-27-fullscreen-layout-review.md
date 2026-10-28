# Review layout stretching in a full window

Status: implemented and verified. Date: 2026-10-27. Request: capture full-window screens, review excessive stretching and fix it.

## Result and change

Reviewing twelve screens showed date fields, filters and summaries stretching beyond their content needs. Work-page width was capped at 1120px and Sales at 1360px; the large sales ticket ranges from 330 to 380px. Filter widths were constrained while retaining wrapping, section/empty-state spacing reduced, and product tabs sized to content.

Measurements also showed the previous header's flex-basis:280px created vertical blank space when narrow layouts changed to a column. Removed that fixed basis. At width 390px, inventory header height changed from 342 to 158px, and settings from 296 to 96px. The taller expense header contains its actual actions; no forced height basis remains.

## Actual verification

- Before/after screenshots for each screen at 1512×982 and 1920×1080: 24 images per stage. Screens were visually reviewed, with extra inspection at the larger size.
- Checked 12 screens at 1512×982, 1920×1080, 1024×768 and 390×844: 48 cases without horizontal overflow or missing headings. Verification compares requested and active destinations when their shortcuts exist.
- npm test passed 120/120.
- Local evidence: outputs/fullscreen-review/README.md links full captures; before/results.json and after/results.json contain measurements. Recheck tool review.cjs is in the same folder. The isolated fixture has 33 products and an illustrative 15-item order.
- Refreshed the browser preview and confirmed order-item count/total remained unchanged after reload.

## Limits

The installed application was not replaced; restaurant accounts/financial data were untouched. Captures show window content, not PDFs. Recall returned withdrawn historical sources, so current source was used. Earlier memory service status was healthy without pending/failed work but sources=0; sync/check run without interpreting that result as indexing documents without registered sources.
