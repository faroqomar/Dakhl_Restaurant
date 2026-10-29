# Purchase invoices by carton and piece

Status: implemented and verified by automated tests, packaged and installed as local update 1.7.0 on the MacBook. Date: 2026-10-25.

## Request

Add a dedicated list for entering new/historical invoices and selecting the supplier; record carton/piece quantities and prices plus the total; analyze item purchases over a period, including suppliers and price changes; and show the payment receipt, date and remainder.

## Change

- Added a separate Purchase Invoices page with material, period and supplier filters and quantity/amount summaries.
- Updated the invoice model to preserve separate carton/piece quantities and prices plus line totals, and added supplier selection when creating an invoice from the page.
- Kept the previous quantity/price format valid for validation and editing, and updated PDF output to show carton/piece fields.
- Improved payment-receipt details to show date, amount, allocation and supplier balance remaining afterward.

## Rationale and boundaries

No fixed number of pieces per carton is assumed. Quantities therefore aggregate in two separate units and amounts are calculated directly from each unit price. Invoices remain debt; only payment adds an expense and affects the funding source.

## Verification

`node --check` passed for model, supplier and UI files. `npm test` passed after adding checks for separate quantities/prices and compatibility with the previous invoice format. PDF generation and example-page checks passed; a historical invoice page was visually reviewed to confirm previous invoices still display correctly. The build was installed at `/Users/eros/Applications/Daftar.app` and started successfully, with version 1.7.0, the purchases page and reading of the local restaurant account confirmed. The previous application was preserved at `/Users/eros/Applications/Daftar-1.6.0.app`. No PDF example using new carton/piece data was generated.

## Files

`app/ui/index.html`, `app/ui/model.js`, `app/ui/suppliers.js`, `app/ui/renderer.js`, `app/ui/styles.css`, `app/reports/pdf.cjs`, `tests/suppliers.test.cjs`, `docs/reference/accounting-rules.md`, `docs/reference/application.md`.
