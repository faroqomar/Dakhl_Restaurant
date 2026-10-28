# 0010 — Independent returns, held orders and receipt after payment

Status: approved within the owner's request of 2026-10-27. [Scope](../planning/2026-10-27-mvp-completion.md).

## Returns

Account schema 11 adds `saleReturns`. Migration from 1–10 preserves earlier records and amounts and starts with an empty returns register. A return records the sale, date, reason, lines, quantities, amounts and whether inventory is restored. Save/import validate quantities and the calculated amount; a form-provided amount is not accepted without recalculation.

The original sale remains saved; a return deducts daily collections on the return date and creates neither an expense nor a cashbox movement. No automatic cash transfer from the cashbox is assumed. Total daily collections may be negative on a returns day, so the remaining-cash snapshot accepts a negative sales baseline and prevents repeated deduction after actual cash is re-entered.

Allocate the net discounted receipt value across lines using integers, then calculate a partial return cumulatively from line quantity. Returning every quantity refunds the exact net receipt amount even with fractional quantities and dinar rounding. Inventory is restored only when selected and on the return date. A sale with returns cannot be voided; its remaining quantities may be returned. Historical voiding of sales without returns remains available for corrections.

## Held orders and receipt

A held order is a local unpaid draft; it neither reserves inventory nor changes a balance. Resuming it rechecks products and inventory at payment time. Its data remains in device/account-scoped storage, not in the transferable account file.

After a sale is successfully saved, automatically open the receipt with close, print and PDF actions. This supersedes choosing to open it from the success notification in [decision 0004](0004-ux-popouts-and-recovery.md). Printing opens the system dialog and never prints silently; the main process constructs it from a saved record, not UI-supplied HTML. No physical printer is available for testing.

First-run setup and backup reminders are deferred. Day review remains concise and does not create a closing record or comprehensive audit archive.
