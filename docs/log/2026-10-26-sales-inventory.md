# Cash sales, simple inventory and customizable shortcuts

Status: implemented, locally verified and installed, 2026-10-26. Source: the owner requested sales/inventory according to the sketch and assignment of any screen to a settings shortcut, confirming ResturanetAccounting. Version: 1.10.0 / schema 8.

## Change

The sales UI places products on the left and a ticket on the right, with search, groups, quantities, discount, cash received/change, saved receipts and PDF. Inventory supports products, prices, opening quantities, restock, spoilage, movement history, low-stock alerts and product deactivation. Sales history filters invoices, opens receipts and cancels whole sales with returned stock and a cancellation reason. Six shortcuts can target screens or be hidden; they are saved in accounts/backups. The active order survives navigation during the session, and duplicate save is blocked while writing.

Sales update inventory automatically and daily accounts through the sales difference after the remainder snapshot; money is not automatically deposited in the cashbox. Ingredients and purchase cartons do not automatically become meals. [Decision 0002](../decisions/0002-sales-inventory-shortcuts.md) defines details, cash-sales boundaries and cancellation on the original date. [Usage guide](../how-to/sales-inventory.md).

## Actual verification

- `npm test`: **93/93 passed**, covering legacy migration, save/import/previous backup, chronological stock, decimal quantities, sales/cancellation/discount/cash, input integrity, shortcuts and save failure. Existing complete expense/supplier/cashbox/worker-advance/PDF tests remained green.
- Actual isolated Electron run using `scripts/verify-commerce.cjs`, without opening restaurant accounts: added items, completed a sale, saved PDF, assigned a shortcut and opened its destination. Column order and no window-width overflow were verified at 1440, 1000, 900, 760 and 390 widths; zero page errors. Images in `dist/commerce-qa/` use illustrative data only.
- Actually generated a one-page A4 sales receipt PDF and visually inspected its Poppler-rasterized image: tables, Arabic, discount, received amount and change were clear.
- `git diff --check` passed. `npm run package` successfully built macOS ARM64. The existing packaging icon warning remained without blocking the build.
- Before updating, installed 1.9.0 was open without an entry form. It was closed normally, preserved beside the application as `Daftar-1.9.0-before-sales-2026-10-26.app`, and the original accounts file was privately backed up within its data folder as `accounts-before-sales-update-2026-10-26.json`.
- Installed 1.10.0 at `/Users/eros/Applications/Daftar.app` and opened it successfully: screens/shortcuts appeared and save state was healthy. Comparing every legacy account area before/after confirmed equality against reference validation; new lists were empty, with no synthetic data in restaurant accounts.

## Documentation and memory

Updated application, accounting, scope, usage and decision references. The latest Hindsight check after synchronizing documents showed a healthy API, connected database and 32 sources, with no pending or failed operations.
