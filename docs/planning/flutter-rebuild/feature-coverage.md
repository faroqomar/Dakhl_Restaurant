# Feature and source coverage

Status: current-source observations, checked 2026-10-27. Source identity: working tree, not a claim about the installed app. This inventory is newer than the historic 13-screen memory: index.html contains 12 visible routes and worker savings UI is retired by decision 0007.

Each observation includes file, enclosing symbol and proof location. Read the current source before implementation; the manifest fingerprints this capture baseline. Numeric ranges below are proof locations, not a promise that later source line numbers remain stable.

| Observation | File | Symbol | Proof | Owning phase |
| --- | --- | --- | --- | --- |
| 12 routes; worker route removed | electron-reference/app/ui/index.html | top-level navigation | 25–37 | 01; visible features 03–10 |
| Daily expenses, statement, cash and category pages | electron-reference/app/ui/renderer.js | expensesPage / statementPage / cashPage / categoriesPage | 44–70 | 06,10 |
| Dialogs and mutation dispatch | electron-reference/app/ui/renderer.js | openDrawer / submitForm / commit | 86–98;124–180;199–235 | 02 and feature phase |
| Sales catalog, cart and checkout | electron-reference/app/ui/commerce.js | salesPage / renderProducts / renderCart / commerceAction | 14–38;87–115 | 04 |
| Products and sale history | electron-reference/app/ui/commerce.js | inventoryPage / renderInventory / salesHistoryPage / commerceDrawer | 39–71 | 03,05 |
| Return and held workflows | electron-reference/app/ui/commerce.js | saleReturnFields / refreshReturnQuote / heldOrdersDialog / holdCurrentOrder / resumeHeldOrder | 156–215 | 04,05 |
| Durable drafts, focus, dirty guards and lists | electron-reference/app/ui/ux.js | allowLeave / restoreSaleDraft / writeSaleWorkspace / pageItems / enhanceDialog | 49–76;120–129 | 01,02,04 |
| Day review and stock event history | electron-reference/app/ui/ux.js | stockHistory / dayReview | 152–153 | 03,10 |
| Settings and order manager | electron-reference/app/ui/ux.js | organizedSettingsPage / initializeSettings / activateSettingsSection / orderTypeManager | 209–300 | 09 |
| Supplier tabs, materials, invoice analysis and payments | electron-reference/app/ui/suppliers.js | suppliersPage / invoicesPage / supplierDetail / materialsPage / supplierDrawer / supplierSubmit | 10–87;150–183 | 07,08 |
| Daily, funding, balances, dates, supplier calculations | electron-reference/app/ui/model.js | dailySpent / remaining / recordRemaining / transferRemaining / correctDayDates / splitPayment / supplierBalance | 16–150 | 06,07,08,10 |
| Integer money, quantities and compatibility | electron-reference/app/ui/model.js | numeric / quantity / money / validate / validateSavings | 9–14;95–109;226–263;265;416–451 | 02 |
| Sales/return/inventory arithmetic and validation | electron-reference/app/ui/model.js | returnQuote / returnSale / stock / validateCommerce / completeSale / voidSale | 294–414 | 03,04,05 |
| Validated atomic writes and backups | electron-reference/app/storage.cjs | Storage | 4–32: constructor / load / atomic / save | 02,09 |
| Native file, import, print and report boundary | electron-reference/app/main.cjs | IPC handlers; app.whenReady | 43–103: handle and accounts:* registrations | 09,10,11 |
| Seven active report kinds | electron-reference/app/reports/pdf.cjs | daily / invoice / sale / periodReport / paymentReceipt / createReport | 28–100 | 10 |
| Visual controls and responsive rules | electron-reference/app/ui/styles.css; electron-reference/app/ui/commerce.css; electron-reference/app/ui/ux.css | .button / .drawer / .product-grid / :root / media queries | frozen files in reference-assets; source hashes in manifest | 01 and every visual phase |

## User-facing scope mapping

| Current screen/workflow | Planned phase |
| --- | --- |
| Sales, compact catalog, ticket and paid receipt | 04 |
| Active ticket recovery and held orders | 02,04 |
| Sales history, receipt detail, returns and voids | 05 |
| Inventory/product editor/stock history/reversal | 03 |
| Daily expenses, funding, balances, chicken and date correction | 06 |
| Account statement and quick day review | 10 |
| Suppliers, opening/additional debts and ledger | 07 |
| Materials and prices | 07 |
| Purchase invoices, carton/piece lines and analysis | 08 |
| Supplier payments and allocation | 08 |
| Cashbox, external movements and daily transfer | 06 |
| Categories | 06 |
| Restaurant/workflow/data/about settings | 09 |
| File replacement, backup recovery and legacy records | 02,09 |
| PDFs, native share/open and system print | 10 |
| Dirty forms, keyboard focus, filters, pagination, undo, failures | 01,02 and each owning feature |
| Signed installs, physical devices and migration/cutover evidence | 00,11 |

## Explicit limitations and unknowns

No Flutter code, native phone screenshot, real account migration, signed release or physical printer verification was performed by this plan. Report captures show HTML reference output rather than actual Flutter PDFs. Native file/print dialogs are platform-owned and cannot be specified by these Electron screenshots; reproduce their operation and test them in phases 00/09/10/11.

Campaign/idea documentation is not an app feature. Workers/savingsEntries and historical report support are retained for compatibility; the removed worker screen is not in the rebuild. No cloud backend, multi-restaurant model, recipe conversion, camera scanner, thermal printer or profit dashboard is implied.

## Phase 01 Flutter implementation mapping — 2026-10-29

The frozen source inventory above remains unchanged. Current app-owned presentation is in `lib/ui/`, route/schema/guards in `lib/shell/`, composition in `lib/app/` and `lib/main.dart`, and the isolated location safeguard in `lib/platform/shell_preferences_directory.dart`. Madar CAP-01 owns the actual snapshot storage/adapter; the app consumes its independently reviewed exact revision. [App contract](../../reference/phase01-shell-contract.md), [build evidence](../../phases/01-build-evidence.md).

This maps Phase 01 components/navigation, six shortcuts, cold restart of UI preferences, session dirty/undo/ticket safeguards and responsive examples only. It does not mark domain screens03–10, account persistence02, durable ticket recovery04, settings/backups09 or accounting/reporting10 implemented. The eight-item synthetic catalog is a fixture limit; frozen screenshot/source data and all original references are preserved.
