# Daftar · Restaurant accounts

Historical reference README, translated into English under the owner's documentation-language direction. Version/installation statements below retain the original document's historical context; this translation is not a fresh installation audit. UI labels are English descriptions of the unchanged Arabic RTL application.

An offline Mac application based on the approved Sketch design and calm green palette.

## Project scope and documentation

**Daftar is a dedicated project for one restaurant only.** Invoices, accounts, advertising campaigns, ideas and the dedicated application all serve that restaurant. This is the scope approved by owner direction on 2026-10-16.

Accounts/invoices described below exist in the current application; campaigns/ideas have documentation and tracking registers, while adding their functions to the application needs later requirements and implementation.

- [Documentation and tracking guide](docs/README.md): starting point for all project documentation.
- [Restaurant scope and capability status](docs/reference/project-scope.md).
- [Accounting rules](docs/reference/accounting-rules.md) and [application/data architecture](docs/reference/application.md).
- [Idea register](docs/planning/ideas.md) and [campaign register](docs/planning/campaigns.md).
- [Decisions](docs/decisions/README.md) and [work logs](docs/log/README.md).
- [Hindsight memory use](docs/how-to/memory.md): project bank `project-daftar`; local documentation is authoritative.

## Open the application

Version 1.10.1 is installed at `/Users/eros/Applications/Daftar.app`, with a desktop shortcut using the historical Arabic Daftar name. Double-click to open. The packaged build also exists at `dist/Daftar-darwin-arm64/Daftar.app`. The application targets Apple Silicon Macs; data remains independent of the application location.

## Available capabilities

- UI review 1.12.0: popout navigation/forms, sales-draft recovery, inventory correction, additional filters/reports and backup/restore status. [Details of the 64-item remediation](docs/planning/2026-10-26-ux-audit-resolution.md). The new build is separate from the installed application.

- Sales in source/preview 1.12.0: illustrated products on the left and a fixed ticket on the right, internal list scrolling, discount/exact-value payment without entering cash received, and order types configurable in settings, with PDF receipt, history and voiding that restores quantity. Installed version remains 1.10.1 during the current review.
- Sellable-product inventory: prices, opening quantities, restock, shortages, low-stock warnings and movement history, with optional meals sold without quantity tracking. Inventory is independent of supplier ingredients/cartons; there is no automatic recipe conversion.
- Six top shortcuts, configurable in settings for any main screen and included in backups.
- [Sales, inventory and shortcut usage](docs/how-to/sales-inventory.md). Cash sales belong to the daily account and enter the remaining-cash snapshot without duplicate addition to the cashbox.

- Purchase Invoices page: choose a supplier and enter new/historical invoices with dates and carton/piece quantity/prices. Purchase analysis by material, period and supplier shows quantities, amounts and price changes; payment receipts show the remainder after payment.
- Export the daily statement or any supplier invoice to a local A4 PDF in Daftar's colors, with clear Arabic text, English digits and thousands separators. The daily report includes expenses, funding sources, balances, chicken counts and cashbox movements; supplier invoices include materials, payments and allocation between invoice/debt. Tables span numbered pages when needed. Choose the save location using **Export PDF** or the invoice's PDF button.

- A record for every day with date selection and access to earlier days.
- **Edit invoice date** moves the entire day's record: expenses, payments, chicken counts, balances and cashbox movements. The following-days correction option moves days in the selected period by the same date offset, previewing before saving and preventing collisions. Supplier-invoice/debt dates remain independent; payment cannot precede its invoice/recorded debt. The move is undoable during the session.
- Samoon, bread, falafel and market categories, plus custom categories preserving names. Choose **Primary** or **Additional** when adding a category or change its type in the Categories section; the selection is stored locally and in backups.
- Arabic/Persian digits normalize to English digits during entry. Amounts, counts and quantities show thousands separators, retaining entered fractions. Invoice/phone numbers preserve leading zeros and formatting.
- An amount and optional notes per expense, with editing, moving to another day and deletion.
- Funding source at the end of the form: daily balance by default, cashbox or shared with a specified amount from each. Both shares must total the expense.
- Remaining cash per day beneath expenses: enter actual cash left after current expenses, then deposit all or part into the cashbox.
- Automatic expense total or a manually selected total, with return to automatic at any time.
- Overall balance is saved when remaining cash is recorded: daily expenses + actual remaining cash + earlier deposits of that cash into the cashbox. Cashbox-funded expenses do not enter daily totals. Saved manual/historical balances are not replaced when opening accounts.
- Issued/remaining chicken counts without including them in expenses.
- Cashbox deposits/withdrawals with dates, notes and complete movement history.
- Undo changes during the current session and export/import backups.

An expense's cashbox share is deducted automatically; editing/deleting it corrects that effect. Depositing remaining cash adds to the cashbox and deducts daily cash in one save, and cannot exceed availability. Cashbox history identifies movement sources; editing/deleting a deposit returns the amount to daily cash. Record initial cashbox funds as an opening deposit with an **Opening balance** note.

Remaining cash is actual cash after expenses recorded at entry time, so earlier expenses are not deducted again. Daily overall balance is calculated as summed daily expense shares + remaining cash + deposits from it into the cashbox. Cashbox expenses and cashbox portions of shared funding do not enter daily-expense totals. Re-entering remaining cash establishes a new baseline for later movements. Older expenses are treated as daily-funded; historical cashbox balances remain unchanged. Daily totals include only daily shares; the cashbox share is shown separately, deducted from its own balance and excluded from daily overall balance. Full movement cost remains visible in the account statement. Legacy records without a funding source are daily-funded.

## Historical worker-record compatibility

At the owner's request on 2026-10-27, the worker-savings UI was removed. It is absent from navigation/shortcut customization. Historical worker/movement records remain in account files/backups without changing balances or expenses; old shortcuts to that screen become empty slots. [Decision](docs/decisions/0007-retire-worker-savings.md).

## Suppliers, invoices and payments

- Each supplier has a name, optional phone/note, prior debt owed and a default payment-expense category. The former opening-balance amount is treated as prior debt, showing its remainder after settlement.
- Permanent materials preserve name, unit and unit price. Selecting a material in an invoice fills unit/price, which can be changed for that invoice.
- An invoice saves number, date, materials, quantities, prices and note. Numbers cannot repeat for the same supplier but may repeat across suppliers.
- A new material entered in an invoice is automatically saved for the supplier. Later permanent-material price edits do not change earlier invoices.
- Quantities accept up to 3 decimal places; line totals round to the nearest Iraqi dinar.
- Supplier balance = prior debt + added debt + invoice totals - payment totals. Statements show the balance before/after each dated movement.
- When adding an invoice, pay some/all immediately or enter zero for later settlement. Excess beyond its remaining value automatically settles debt; debt can also be paid independently.
- Payment links to a specified invoice or debt, with date, category, note and daily/cashbox/shared funding.
- Adding an invoice records debt only; its payment is the expense on the payment date and deducts its source once.
- The debt tab records an amount, date and note, permitting edit/delete provided debt is not reduced below the amount already settled. Recording debt alone creates no expense.
- Payment preview shows invoice/debt portions and remaining debt afterward. Payment cannot exceed invoice remainder plus debt available on its date, and excess is not moved to other invoices. Allocation is stored with the payment and does not change when an invoice value is later edited.
- Invoices/payments support edit/delete and undo. An invoice with payments cannot be deleted until those payments are removed; deleting a payment corrects debt, daily account and cashbox.

Older data is read automatically without value changes; suppliers, materials, invoices and payments share the same save/backup file.

## Data persistence

Account file:

`~/Library/Application Support/Daftar/accounts.json`

Every successful change is saved to disk atomically, with preceding data retained in `accounts.backup.json`. Import first preserves existing data in `accounts-before-import-<timestamp>.json`. If reading fails, saving stops to protect data rather than clearing accounts.

Under **Data and backups**, export another copy, import a file or open the data folder. Window position/size are saved separately. Data is local and unencrypted; its protection depends on the macOS user account.

## Shortcuts

- ⌘N: add expense.
- ⌘Z: undo the last change, or undo typing while focused in a text field.
- ⌘⇧E: export backup.
- ⌘O: import backup.
- ⌘,: data settings.
- Esc: close the entry form.

## Development

```sh
npm ci
npm start
npm test
npm run package
```

The UI is local HTML/CSS/JavaScript inside Electron. It uses neither network connections nor internet fonts. The UI is isolated from Node; all file operations pass through a restricted, origin-validated bridge. Validate the model before save/import.

The current application has no Apple distribution-signing certificate; this is a local build for use on this device.
