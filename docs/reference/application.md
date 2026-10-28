# Application and data — Current-state reference

> Update, 2026-10-28: the root now contains a Flutter development baseline (blank RTL shell and synthetic-data capability tests) under verification, without product screens, production accounts or migration. [Implementation evidence](../phases/00-build-evidence.md). The Electron description below remains historical reference.

> Current project name: **Dakhl_Restaurant**. This file documents the reference Electron application under its historical **Daftar** identity; the UI/storage names described below are compatibility evidence, not the current project name.

> Organization, 2026-10-28: Electron source, commands, dependencies and tests are in `electron-reference/`. Resolve bare code paths and npm commands in this document from that directory; direct links are updated. Documentation, plan and screenshots remain at the root, which is the Flutter rebuild location. [Decision 0013](../decisions/0013-electron-reference-folder.md).

> Planning update, 2026-10-27: the owner requested a Flutter/Dart rebuild. The [plan and visual references](../planning/flutter-rebuild/README.md) describe future work; this remains the current Electron application reference until its replacement is implemented and verified. Approved rebuild scope includes no cloud synchronization.

Status: documented from source; establishes neither an installed version nor a new build. Date: 2026-10-16. Owner: Dakhl_Restaurant developer. Sources: linked files below.

## Structure

| File | Responsibility |
| --- | --- |
| [package.json](../../electron-reference/package.json) | Version 1.12.0; Electron/JavaScript; run, test and package commands |
| [main.cjs](../../electron-reference/app/main.cjs) | Window/menus, data path, IPC-origin validation, save/import/export |
| [preload.cjs](../../electron-reference/app/preload.cjs) | Restricted `window.daftar` bridge between UI and main process |
| [storage.cjs](../../electron-reference/app/storage.cjs) | Validation, atomic saving, backups and unreadable-file protection |
| [model.js](../../electron-reference/app/ui/model.js) | Schema 11, migration/validation, accounting, suppliers and worker savings |
| [renderer.js](../../electron-reference/app/ui/renderer.js) | Rendering, forms, navigation and in-session undo |
| [suppliers.js](../../electron-reference/app/ui/suppliers.js) | Supplier, material, invoice, debt and payment UI |
| [numbers.js](../../electron-reference/app/ui/numbers.js) | Arabic/Persian digit normalization and input formatting |
| [index.html](../../electron-reference/app/ui/index.html) and [styles.css](../../electron-reference/app/ui/styles.css) | Arabic RTL UI, application sections and local styling |
| [pdf.cjs](../../electron-reference/app/reports/pdf.cjs) and [export.cjs](../../electron-reference/app/reports/export.cjs) | Build reports from saved data, generate/write A4 PDFs |

This structure belongs to Dakhl_Restaurant; it is not AlDakhl's Flutter/PowerSync architecture.

## Persistence and schema

On macOS the path is `~/Library/Application Support/Daftar/`. Accounts are in `accounts.json`, the previous backup in `accounts.backup.json`, and the pre-import copy in `accounts-before-import-<timestamp>.json`. `window.json` separately saves window position/size.

Current account root fields are `version`, `categories`, `days`, `transactions`, `transfers`, `suppliers`, `materials`, `invoices`, `payments`, `debts`, `workers`, `savingsEntries`, `products`, `stockEntries`, `sales`, `saleReturns` and `preferences`. `validate` accepts versions 1–11 and returns schema 11; `Storage.load` persists upgrades with a copy of the preceding file when its version differs. Days contain expenses, chicken counts, overall balance, a manual total override and a remaining-cash snapshot.

Every save validates before replacing the file. Write a temporary file with `fsync`, then rename; save the previous copy before replacement. The enforced save/import limit is 20 MiB. If reading fails, ordinary saving stops; validated import permits recovery and preserves the previous file. Import replaces accounts with in-app confirmation; it does not merge them.

## Isolation and connectivity

The window uses `contextIsolation: true`, `nodeIntegration: false` and `sandbox: true`. The main process validates the IPC window/origin and blocks external windows, links and HTTP/HTTPS/WS/WSS requests in its session. The UI page uses `connect-src 'none'`. No cloud synchronization is implemented. Local data is unencrypted; isolation does not justify calling it encrypted.

Hindsight is an external development-documentation service; adding its memory connection creates no network connection or runtime dependency in Daftar.

## Reports and invoices

`createReport` accepts `kind: 'daily'` with a date or `kind: 'invoice'` with a supplier-invoice ID. The main process uses a copy of saved data; it does not accept UI-supplied HTML or amounts to generate an invoice. Output is A4 with Arabic RTL, English digits and page-number footers. A daily report does not describe net profit; a supplier invoice distinguishes its paid portion from the portion settling supplier debt.

## Verification and development commands

```sh
npm ci
npm start
npm test
npm run package
```

Current packaging targets macOS ARM64 only; do not infer Windows/iOS/Android support. Normal startup may read restaurant accounts; tests use fake data, temporary folders or an isolated bridge. Optional PDF verification, `./node_modules/.bin/electron scripts/verify-pdf.cjs`, generates samples in `dist/pdf-qa/` without opening user accounts; inspect output visually when changing reports.

Current tests cover accounting/storage, funding sources, suppliers, dates, worker savings, numbers, UI and PDF report content. Content-test success proves neither visual print quality nor application signing. Actual run results belong in [work logs](../log/README.md).

## Purchase invoices

Daily expenses separate daily-funded entries from cashbox shares; daily totals/calculated balance exclude the cashbox share, which has its own table. The account-statement page filters movements by period, category and funding source, ranking categories by recorded spending. Purchase invoices are separate from supplier management, with supplier/date selection and entry of new or older invoices. One materials/prices catalog serves all suppliers; material selection fills carton/piece/unit prices. Invoice lines store carton quantity/price and piece quantity/price and calculate line/overall totals. There is no universal carton-to-piece conversion; both quantities remain separate. Older invoices remain readable/editable without losing earlier quantity/price. Material/period/supplier analysis filters show quantities, amounts, suppliers, prices and price differences. Payment receipts use saved payment records, their date/source and the supplier balance remaining afterward.

## Sales, inventory and shortcuts — 2026-10-26

`commerce.js` and `commerce.css` add sales, inventory, sale history, shortcuts and settings; `model.js` provides validation, quantities, sales and the daily snapshot, and `pdf.cjs` builds sales receipts. Schema 8 adds products, stock movements, sales and preferences while preserving old record meanings. The new remaining-cash snapshot adds `salesTotal` to avoid counting earlier sales twice. [Detailed decision](../decisions/0002-sales-inventory-shortcuts.md) and [usage guide](../how-to/sales-inventory.md).

`tests/commerce.test.cjs` covers migration, saving, dated stock, discounts, voids, daily-account integration and PDFs; UI tests cover the complete flow, save failures and shortcut customization. `scripts/verify-commerce.cjs` is a review app with isolated illustrative data under `dist/commerce-qa/`; it does not read restaurant accounts.

Version 1.10.1's show/hide-sidebar action expands the workspace without rebuilding page content. Its preference is local UI storage key `daftar.sidebar-collapsed`, changing neither account schema 8 nor its records.

## Second sales-review round — Source 1.11.0, schema 9

Sales fit window height, with internally scrolling product/ticket lists. Checkout records the exact receipt total without a cash-received field. `preferences.orderTypes` stores types, `sales[].orderType` optionally stores the name at sale time for backward compatibility, and `products[].photo` is an allowed local image key. Migration changes neither older receipts nor accounts; [decision 0003](../decisions/0003-sales-layout-review.md). Preview uses reference images in `app/ui/photos/` and preserves earlier review comments; old coordinates are not drawn over the new layout. Installed version 1.10.1 was unchanged during this review round.

## Audit fixes — Source 1.12.0 / schema 10

`ux.js` and `ux.css` supply shared interaction rules: popouts, edited-form protection, save indicators, filtering/pagination, draft recovery, worker/inventory details and receipt-identity settings. `backup-info.cjs` builds import/restore summaries. Source starts with navigation closed; the previous fixed-sidebar preference no longer determines page layout.

Schema 10 adds `preferences.restaurant`, optional `archived` on suppliers/custom categories, `days[].corrections` and `stockEntries[].reversesId`. Corrections preserve reasons, values and timestamps; original inventory movements remain. Financial/stock history continues under existing validation. Sales changes break ordinary undo history so it cannot restore a state that erases an issued receipt.

Supported reports: `daily`, `invoice`, `sale`, `sales`, `statement`, `cash`, `workers`, `payment`. Period reports accept filters only and calculate from saved records; the daily report remains an expense report. Opening exports is restricted to files exported by the application during that session. `backup-meta.json` stores the time/path of the last successful manual export. Restoring the previous backup also works when the current file is unreadable, preserving it unchanged before replacement.

Original sales-image assets remain in source; the UI uses 240/480 WebP derivatives, and packaging excludes original PNGs and development docs/output. Build target is macOS ARM64. [Decision](../decisions/0004-ux-popouts-and-recovery.md) and [change evidence](../planning/2026-10-26-ux-audit-resolution.md).

## Settings organization — 2026-10-27

Settings have four sections: restaurant/receipt, sales/shortcuts, backups/data and about Daftar. Section forms remain mounted while navigating to preserve drafts; **Save changes** or ⌘/Ctrl+S validates and saves receipt identity, order types and shortcuts together. Receipt identity has a live safe text preview and changes neither saved sale lines nor amounts; viewing/reprinting an older receipt uses the current restaurant identity, as in the earlier flow. Validation/save failures preserve field values.

At the owner's request on 2026-10-27, sales-card size changes only on the sales screen and was removed from settings. It remains device-local key `daftar.catalog-compact`, outside the account backup. Receipt identity, shortcuts and order types remain account preferences included in backups. The backup section separates export/import and puts restore within separate details; previews explain that file operations require the desktop application. No financial-rule or JSON-schema change.

### Order-type management — 2026-10-27

Replace multiline type entry with a list supporting add/delete/disable/enable and a dropdown for default type. Edits remain drafts until **Save changes**. At least one active type remains; names are unique across active/disabled types, with at most 20 names.

`preferences.orderTypes` remains the active-name array, default first. Optional `preferences.disabledOrderTypes` is an additional schema-10 field retaining disabled names; absence in older files means no disabled types. The model validates/persists it through existing save/backup flows without changing older sales or amounts. Empty tickets adopt the new default after saving settings; a populated open ticket does not change type merely because the default changed, provided its type remains active.

### Inventory toolbar — 2026-10-27

The toolbar has a consistently aligned search/status/group cluster, with a separate low-stock filter and open-sales group. Actions wrap to a second row at medium widths and search gets its own row at narrow widths. Filter changes preserve keyboard focus; search, stock and saving criteria are unchanged.

### Compact sales cards — 2026-10-27

Add through the card itself with a plus in the image corner instead of an add row below it. Count sits in the opposite corner; name, price and stock remain. Images/cards are shorter in both layouts, with an additional density option only on sales. There are no nested buttons; each card remains one button with an Arabic accessible name describing add, product and price, and adding is disabled when available stock is exhausted.

## Worker-savings UI removal — 2026-10-27

At the owner's request, delete UI module savings.js, its HTML connection and handlers in renderer.js/ux.js. No savings page, worker/payment/withdrawal forms or associated shortcut choices remain. Unknown destinations return to sales; historical `savings` in an older file is accepted but becomes an empty shortcut slot during validation.

Keep `workers`, `savingsEntries` and model validation for lossless reading, saving, import and export of older accounts. No balances, expenses or schema-10 change. Historical compatibility functions/reports are not a new worker UI. Historical model tests remain; removed UI tests were replaced with checks for absence and record preservation after settings save. [Decision](../decisions/0007-retire-worker-savings.md).

### Browser-test catalog — 2026-10-27

Preview script scripts/preview-design.cjs uses scripts/preview-fixture.cjs: eight originals plus 25 illustrative products, 33 total. Baseline tests/commerce-fixture.cjs is unchanged. The preview bridge adds only missing illustrative product IDs to saved preview data, preserving existing sales/settings/products; reload does not duplicate products. Repeated images are illustrative references, not an approved menu. Preview cannot access restaurant accounts.

### Order-detail density — 2026-10-27

Order details use a compact row combining product name/unit price, quantity control, line total and delete icon. Ticket header, type/discount fields and confirm/clear actions are smaller, preserving control names and keyboard behavior. Below 360px, rows wrap to prevent text/control crowding. Quantities, totals and draft calculations are unchanged.

### Full-window review — 2026-10-27

Later owner direction removed 1120/1360px limits because of wasted side margins. Pages now use window width with 24px desktop and 14px narrow-screen gutters, aligning navigation, titles, summaries and panels. Filters/ticket stay compact; settings fields/receipt preview use adaptive columns. The small-screen header-height fix remains. [Current decision 0009](../decisions/0009-fluid-aligned-workspace.md).

### In-page content organization — 2026-10-27

The expense page distributes its daily table alongside a secondary column for cashbox expenses, remaining cash and chicken counts. Cashbox expenses are compact rows preserving name, note, amount and edit action. Totals stay by their labels and summary measures are clustered rather than equally spread across the window. Cashbox filters/actions share a toolbar; empty states are concise. No accounting-meaning or persistence change.

## MVP completion — Schema 11

Adds `saleReturns` while preserving older records. The application includes returns, held-order and post-payment receipt screens; [decision 0010](../decisions/0010-mvp-returns-and-held-orders.md). Native `accounts:print` accepts a saved-sale ID and opens the system dialog; it accepts neither UI HTML nor amounts. Held orders are local to the device, not sale records in account backups. The task log records final verification status.
