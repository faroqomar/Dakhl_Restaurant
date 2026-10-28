<!-- hindsight:ignore -->

> Historical 19-phase plan, superseded by the [current 12-phase plan](../../README.md) on 2026-10-27. Do not use these phase numbers for new work.

# Financial and data parity contract

Status: current-source behavior to preserve, 2026-10-27. This is not a new accounting policy or a claim of Flutter implementation.

Sources: model.js symbols in feature-coverage.md, current accounting-rules.md, decisions 0002, 0003, 0004 and 0010. Use exact arithmetic and the source’s bounds/rounding; do not substitute visually plausible totals.

## Rules and reference examples

| Case | Required behavior / deterministic example |
| --- | --- |
| Money and input | Whole IQD amounts; Arabic/Persian digits normalize; reject invalid sign, fraction, exponent and out-of-range values according to the source. Current money validator bounds magnitude at 10^12. Quantities allow up to three decimal places. |
| Shared expense | Expense 30,000 split daily 20,000 + cash 10,000: daily spending rises 20,000, cashbox falls 10,000, combined expense remains 30,000. |
| Remaining snapshot | Start with daily spending 20,000, transferred 5,000 and net sales 30,000. Record physical remaining 100,000. After another daily expense 3,000, transfer 2,000, sale 8,000 and refund 1,000, remaining becomes 102,000. Earlier movements are not applied again. |
| Remaining formula | snapshot.amount − (current dailySpent − snapshot.dailySpent) − (current transferred − snapshot.transferred) + (current net sales − snapshot.salesTotal, default 0 in legacy snapshots). |
| Recorded total balance | On recording remaining: total(daily, including manual override if set) + recorded physical remaining + transfers already made from that day. Future transfer does not rewrite that recorded balance. Cashbox-funded expense is excluded. |
| Daily transfer | From remaining 100,000, transfer 20,000: daily remaining 80,000; cashbox +20,000; no expense; saved total balance unchanged. Edit/delete reverses the prior effect once. |
| Supplier invoice | 2 cartons ×40,000 +3 pieces ×2,500 =87,500 liability. No paid expense until settlement. No carton-to-piece conversion. |
| Supplier payment | Invoice due 12,500 + eligible debt 50,000; payment 20,000 splits invoice 12,500 and debt 7,500. If funding daily 15,000/cash 5,000, expenses get that single 20,000 payment and each source only its share. |
| Supplier excess | Excess cannot pay a different invoice, unavailable future debt or a nonexistent liability. Invoice number uniqueness is per supplier. |
| Snapshot preservation | Changing catalog material price or current product price does not rewrite old invoice/sale lines or totals. |
| Sale | Subtotal minus fixed discount = net. New quick sale records exact net received; old tendered/change values remain as recorded. Type has no automatic fee. |
| Returns | Original sale remains. Refund on return date reduces daily net sales, not expenses/cashbox. Optional restock on return date only. Cumulative discounted partial refunds equal original net at full return. |
| Void | Only eligible sale without returns; reason required; reverse at original sale date while preserving number/history. |
| Inventory | Opening + restocks + signed adjustments − completed sale quantities + selected restocked returns, with dated reversals. Prevent negative historical stock. Supplier materials never silently add sellable stock. |
| Worker history | Preserve workers and savingsEntries with legacy validation and no operational worker screen; these do not affect expenses, supplier balances or cashbox. |
| Chicken | Quantities only; no monetary effect. |
| Statement | Paid expenses/payments, filtered by actual funding share. Cash-only filter gives daily share zero. Unpaid purchase liability is not paid spending. |
| Day review | Temporary checkboxes and facts; no new close-day ledger or immutable audit claim. |
| Undo/corrections | Preserve current session undo and financial correction trails, including inverse corrections; do not invent a permanent universal audit log. |

The labels remaining, daily total balance and cashbox balance are never aliases for profit. Sales net is after discount/void/refund, not business net profit.

## Compatibility and failure corpus

Use synthetic fixtures for schema 1–11 covering empty accounts and every entity: categories, days/expenses/chicken/balances/snapshots/corrections, transactions, transfers, suppliers, materials, invoices, payments/allocations, debts, workers, savingsEntries, products, stockEntries, sales, saleReturns and preferences. Check missing optional fields and historic order types/disabled types/retired shortcuts.

For each domain command, retain input, stable IDs/date/timestamp, expected validated output, derived totals, rejection reason and unchanged-state expectation. Run JavaScript and Dart on the same corpus. Compare per-record identity and allocations as well as totals; canceling errors can hide record corruption.

Cover boundaries: fractional quantity rounding; full discount/zero-value line; cumulative partial returns; earlier/later dates and midnight; negative refund-only net; manual total overrides; backdated stock and payments; duplicate IDs/numbers; orphan relationships; oversized/unknown-version files; malformed amounts; interrupted save; stale second window; duplicate taps/retries; lossless export/import and recovery.

Maintain separate suites for pure Dart domain tests, repository fault injection, widget/golden checks and real platform integration. The existing JavaScript suite passed 140 tests for this planning baseline. No Dart parity results exist yet.
