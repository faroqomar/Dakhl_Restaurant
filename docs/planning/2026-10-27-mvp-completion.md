# MVP completion scope — 2026-10-27

Status: owner-approved; implementation and verification are recorded separately.

## Implement now

- Full or partial item returns from a saved invoice, with date/reason, amount calculated after discount and an option to return quantities to stock.
- Held orders: save multiple unpaid orders and resume them without reserving stock or recording a sale.
- Successful payment opens a detailed receipt with Close, Print and Save PDF. No physical printer is available; hardware testing is outside current scope.
- Keep day review simple in one screen; no crowded dashboard or new mandatory closing process.
- Standardize empty/search/failure/loading states in affected flows and review screens.

## Deferred until the end of the application

- First-use setup.
- Backup reminders. Existing backup/restore tools remain.

## Not requested in this round

New payment methods, multiple branches, recipes/ingredient costing and delivery management.

## Financial implementation details

A return is an independent schema-11 record. The original sale remains unchanged. Refunded amounts reduce net daily collections on the return date; they are neither expenses nor cashbox deductions. The UI explicitly identifies the cash source. Stock returns only when the user chooses, dated on the return. Cancelling an invoice with returns is blocked to prevent double correction. Discount is mathematically allocated to lines, with rounding remainders completed when the entire quantity is returned.

Current daily review remains a simple action without a closing ledger or persistent audit status; adding that record is deferred. Held orders are device/account-local like the draft, not invoices or part of account backups.
