# Sales design feedback — second round

Status: implemented and verified in source/browser preview. Date: 2026-10-26. Source version: 1.11.0 / data schema 9. Source: four exported review comments, followed by owner confirmation that the requested list represents order types.

## Result

Sales stays within the window; scrolling moves to the product list and ticket lines while payment remains fixed. Eight locally generated reference images appear in sample cards, and inventory can assign a reference image to a product. New sales settle the exact discounted amount without entering cash received. A dine-in/takeaway/delivery list replaces the quick-sale note field and can be edited/reordered in settings. Order type is saved as text in the invoice/PDF receipt and is unaffected by later settings changes. [Decision 0003](../decisions/0003-sales-layout-review.md) and [photo assets/final text set](../reference/product-photos.md).

## Actual verification

- `npm test`: 96/96 passed. New tests cover schema-8 migration, allowed photo keys, payment without entered cash, order-type editing and preservation of historical invoice labels, duplicate rejection and unavailable types. Expense/cashbox/supplier/inventory/worker-advance/UI tests remained green.
- An isolated Electron run checked 1440×1000, 1252×943, 1000×700, 900×580, 760×844, 390×844 and 390×640: no horizontal overflow or document scrolling, with ticket/payment inside the window. Scrolling products by 600 pixels did not move payment. Product content height 1303 pixels scrolled within a 303-pixel area in the short window.
- A real test-data sale saved the exact amount/order type and produced a PDF. Editing a type in settings and selecting it for a new sale succeeded. All eight product images loaded locally; zero page errors.
- Reviewed `dist/commerce-qa/layout-review-v2.png` and an actual one-page A4 PDF rasterized to an image. Order type, Arabic, lines and total were clear. No actual accounts were opened or test data written into restaurant accounts.
- Restarted the local preview server to support images. The review toolbar shows round 2, preserves earlier comments and avoids painting their old coordinates on the new layout. The preview is open in the Codex browser with photos, order type and cash-received input removed.
- `git diff --check` passed. This is a browser-review round; installed 1.10.1 was not replaced and its accounts were not opened.

Documentation is current; Hindsight sync is followed by `memory check`. Queue submission alone is not completion.
