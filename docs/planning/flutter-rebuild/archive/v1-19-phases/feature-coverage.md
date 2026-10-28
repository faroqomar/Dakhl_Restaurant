<!-- hindsight:ignore -->

> Historical 19-phase plan, superseded by the [current 12-phase plan](../../README.md) on 2026-10-27. Do not use these phase numbers for new work.

# Feature and source coverage

Status: current-source observations, checked 2026-10-27. Source identity: working tree, not a claim about the installed app. This inventory is newer than the historic 13-screen memory: index.html contains 12 visible routes and worker savings UI is retired by decision 0007.

Each observation includes file, enclosing symbol and proof location. Read the current source before implementation; the manifest fingerprints this capture baseline. Numeric ranges below are proof locations, not a promise that later source line numbers remain stable.

| Observation | File | Symbol | Proof | Owning phase |
| --- | --- | --- | --- | --- |
| 12 routes; worker route removed | app/ui/index.html | top-level navigation | 25–37 | 03; visible features 04–16 |
| Daily expenses, statement, cash and category pages | app/ui/renderer.js | expensesPage / statementPage / cashPage / categoriesPage | 44–70 | 04,09,10,15 |
| Dialogs and mutation dispatch | app/ui/renderer.js | openDrawer / submitForm / commit | 86–98;124–180;199–235 | 02 and feature phase |
| Sales catalog, cart and checkout | app/ui/commerce.js | salesPage / renderProducts / renderCart / commerceAction | 14–38;87–115 | 06 |
| Products and sale history | app/ui/commerce.js | inventoryPage / renderInventory / salesHistoryPage / commerceDrawer | 39–71 | 05,08 |
| Return and held workflows | app/ui/commerce.js | saleReturnFields / refreshReturnQuote / heldOrdersDialog / holdCurrentOrder / resumeHeldOrder | 156–215 | 07,08 |
| Durable drafts, focus, dirty guards and lists | app/ui/ux.js | allowLeave / restoreSaleDraft / writeSaleWorkspace / pageItems / enhanceDialog | 49–76;120–129 | 02,03,07 |
| Day review and stock event history | app/ui/ux.js | stockHistory / dayReview | 152–153 | 05,10 |
| Settings and order manager | app/ui/ux.js | organizedSettingsPage / initializeSettings / activateSettingsSection / orderTypeManager | 209–300 | 16 |
| Supplier tabs, materials, invoice analysis and payments | app/ui/suppliers.js | suppliersPage / invoicesPage / supplierDetail / materialsPage / supplierDrawer / supplierSubmit | 10–87;150–183 | 11–14 |
| Daily, funding, balances, dates, supplier calculations | app/ui/model.js | dailySpent / remaining / recordRemaining / transferRemaining / correctDayDates / splitPayment / supplierBalance | 16–150 | 09–15 |
| Integer money, quantities and compatibility | app/ui/model.js | numeric / quantity / money / validate / validateSavings | 9–14;95–109;226–263;265;416–451 | 02 |
| Sales/return/inventory arithmetic and validation | app/ui/model.js | returnQuote / returnSale / stock / validateCommerce / completeSale / voidSale | 294–414 | 05–08 |
| Validated atomic writes and backups | app/storage.cjs | Storage | 4–32: constructor / load / atomic / save | 02,16 |
| Native file, import, print and report boundary | app/main.cjs | IPC handlers; app.whenReady | 43–103: handle and accounts:* registrations | 16,17,18 |
| Seven active report kinds | app/reports/pdf.cjs | daily / invoice / sale / periodReport / paymentReceipt / createReport | 28–100 | 17 |
| Visual controls and responsive rules | app/ui/styles.css; app/ui/commerce.css; app/ui/ux.css | .button / .drawer / .product-grid / :root / media queries | frozen files in reference-assets; source hashes in manifest | 01 and every visual phase |

## User-facing scope mapping

| Current screen/workflow | Planned phase |
| --- | --- |
| Sales, compact catalog, ticket and paid receipt | 06 |
| Active ticket recovery and held orders | 02,07 |
| Sales history, receipt detail, returns and voids | 08 |
| Inventory/product editor/stock history/reversal | 05 |
| Daily expenses, funding, balances, chicken and date correction | 09 |
| Account statement and quick day review | 10 |
| Suppliers, opening/additional debts and ledger | 11 |
| Materials and prices | 12 |
| Purchase invoices, carton/piece lines and analysis | 13 |
| Supplier payments and allocation | 14 |
| Cashbox, external movements and daily transfer | 15 |
| Categories | 04 |
| Restaurant/workflow/data/about settings | 16 |
| File replacement, backup recovery and legacy records | 02,16 |
| PDFs, native share/open and system print | 17 |
| Dirty forms, keyboard focus, filters, pagination, undo, failures | 01–03 and each owning feature |
| Signed installs, physical devices and migration/cutover evidence | 00,18 |

## Explicit limitations and unknowns

No Flutter code, native phone screenshot, real account migration, signed release or physical printer verification was performed by this plan. Report captures show HTML reference output rather than actual Flutter PDFs. Native file/print dialogs are platform-owned and cannot be specified by these Electron screenshots; reproduce their operation and test them in phases 00/16/17/18.

Campaign/idea documentation is not an app feature. Workers/savingsEntries and historical report support are retained for compatibility; the removed worker screen is not in the rebuild. No cloud backend, multi-restaurant model, recipe conversion, camera scanner, thermal printer or profit dashboard is implied.
