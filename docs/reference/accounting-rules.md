# Current accounting rules

Source-retirement update, 2026-11-12: source paths below describe the historical Electron behavior at Git revision `2c0eccd79ad3999b3b82779d9722bffbfb94f694`. The owner removed that application from the checkout; [decision 0022](../decisions/0022-retire-electron-reference.md) records recovery and fixture provenance. These accounting meanings remain subject to their current contracts and explicit policy decisions; source removal changes no financial rule.

Status: description of existing behavior; changes need a decision and verification. Date: 2026-10-16. Owner: Dakhl_Restaurant maintainer. Source: `electron-reference/app/ui/model.js`, `electron-reference/app/storage.cjs`, and tests for accounts, suppliers, payment sources, worker advances and dates.

## Amounts and expenses

- Current currency is Iraqi dinar; amounts are integers within validation limits, accepting and normalizing Arabic/Persian digits. Ordinary financial entry does not accept fractional dinars.
- Supplier-material quantity is positive and accepts up to three decimal places. A line total is rounded to the nearest dinar; the model defines precision/range limits.
- Every expense has daily, cashbox or shared funding. Its shares sum to the amount. Totals count the expense once, and its cashbox share creates a derived cashbox-balance effect.
- Automatic daily expenses equal the daily-funded share of every expense/payment; cashbox-funded shares are shown separately and deducted from the cashbox. Shared funding appears split across both tables without being counted twice in daily totals. Legacy records without a source are treated as daily-funded.
- The total may be manual (`totalOverride`): preserve the user's entered number, while analysis shows recorded funding shares. Overall balance calculated when remaining cash is recorded equals daily-funded expenses + remaining cash + transfers of remaining cash into the cashbox. Cashbox-funded expenses and cashbox portions of shared payments do not enter daily-expense totals.

## Daily balance and cashbox

Remaining cash is a snapshot of actual cash **after** the expenses/movements recorded at entry time. The snapshot stores `amount`, `dailySpent` and `transferred`. Current calculation:

```text
remaining = snapshot amount
          - (daily-funded spending now - daily-funded spending at snapshot)
          - (daily-to-cashbox transfers now - transfers at snapshot)
```

A daily-to-cashbox deposit is an independent record: deduct available daily cash and add it to the cashbox once. It is not an expense, and cannot exceed available cash. Editing/deleting a deposit reverses the appropriate effect. The cashbox totals deposits minus withdrawals, including its shares of expenses and supplier payments.

When remaining cash is entered, save overall balance as **daily-funded expenses + remaining cash + earlier daily-to-cashbox deposits**. Cashbox-funded expenses enter neither daily expenses nor daily balance; they remain within cashbox balance. Once entered, the overall total remains fixed through later deposits, and remaining cash is calculated separately.

These measures are neither established sales nor net profit. Any analysis inferring revenue by addition must identify it as inference and specify the entries, funding sources and manual overrides used. Cashbox money is available cash, not profit.

## Suppliers, invoices and debts

- An invoice adds debt only; its payment enters expenses on the payment date and affects its funding source once.
- Supplier balance = prior debts + added debts + invoice values - payments.
- A payment links to a specific invoice or debt and saves `invoiceAmount` and `debtAmount`. Excess beyond the invoice remainder settles available debt, not another invoice or future debt automatically.
- An invoice number is unique per supplier. One material catalog serves all suppliers; prices are entry defaults, while every invoice preserves carton/piece/unit prices at purchase time. Editing the catalog never rewrites an earlier invoice. Schema-6 migration merges material lists by name, uses the earlier piece price as default and sets carton price to zero because it was previously absent.
- An invoice with payments cannot be deleted until its payments are removed. Invoices/debts cannot be reduced below amounts already paid. Deleting/editing a payment corrects balances and allocations.
- Correcting a day's date moves its record and linked movements while preventing overlap and validating; supplier invoices, debts and worker advances retain independent dates.

## Worker advances and chicken counts

The historical Arabic feature name is rendered as "worker advances" in English documentation. Existing `savings`/`savingsEntries` identifiers and the contribution/withdrawal rules below are retained for compatibility; this terminology correction does not redefine their accounting behavior.

Worker advances are an independent scope: daily/weekly/monthly contributions from a start date, partial/full payments and withdrawals from accumulated funds. They do not change expenses, cashbox or supplier balances. A withdrawal cannot exceed funds available on its movement date; a payment cannot be deleted if it would leave an earlier withdrawal uncovered. Recorded periods preserve their amount/date, and deactivating a worker preserves history.

Issued/remaining chicken counts are tracking quantities only and enter neither expense totals nor cashbox balance.

## Daily account statement

Period, category and funding-source filters show actually paid movements within categories, total them and rank categories by descending amount for the selected period. This ranks paid spending in the register; it is not the total of unpaid purchase invoices.

## Historical preservation

Preserve the meaning of records/older backups during migration. Current undo is in-session and saved through validation; it is neither a permanent audit archive nor a backup replacement. Including advertising expenses or linking a campaign to accounts requires an explicit definition preventing double counting; a planning entry alone creates no expense.

## Carton/piece purchase invoices

A new invoice stores carton/piece quantities and prices per material and calculates total as (cartons × carton price) + (pieces × piece price). Do not assume a carton-to-piece conversion: pieces per carton vary by material. Older quantity/unit-price invoices remain valid and appear in purchase analysis. Analysis aggregates each quantity in its own unit and shows suppliers, prices and changes between invoices. Total invoice value is supplier debt; only payment enters expenses and cashbox effects according to funding source.

## Sales and inventory — Schema 8, 2026-10-26

Completed sales preserve prices at save time. Net = line total - discount; customer change = cash received - net. Voided sales are excluded from totals/inventory with the reason preserved. [Integration/date rules](../decisions/0002-sales-inventory-shortcuts.md): the sales difference after the remaining-cash snapshot is added to daily cash, without automatic cashbox deposit. Net here follows discounts/voids; it is not net profit. Inventory = additions/adjustments - completed-sale quantities, in each product's unit without assuming conversions from purchase invoices.

## Faster payment — Schema 9, 2026-10-26

At the owner's request, quick sale no longer requires entering cash received. Completing a sale acknowledges receipt of the exact net receipt total without entering an amount; the financial effect remains net lines minus discount. Earlier records retain their received amount and change as saved. Order type is descriptive stored data; it neither changes calculations nor automatically adds delivery charges. [Decision](../decisions/0003-sales-layout-review.md).

## Audit corrections — Schema 10, 2026-10-26

Daily-account, cashbox and worker-advance equations remain. Filtering the expense statement to the cashbox share shows zero daily share and the cashbox amount, never reinterpreting that filtered share as daily expense. The manual-expense-total preview uses only summed daily shares. Supplier-invoice preview uses previous balance + invoice value - its payment.

Suggested selling price is fixed in the draft when a product is added. A completed sale remains a record; undo opens voiding rather than making its number reusable. A wrong inventory movement is corrected through a full reversal linked to the original on its original date, with a reason and new recording timestamp; reject reversals causing negative historical stock. A correct movement may then be recorded. Available quantity refers to today; future movements are identified in history.

Changing overall balance or a manual total requires a reason and adds correction history. Undo preserves that correction and adds inverse values. This is a trail for specific corrections, not a claim of a comprehensive audit archive for every program edit.

## Sales returns — Schema 11, 2026-10-27

A return is an independent record preserving the original sale. Deduct its discounted amount from net daily collections on the return date; it is neither an expense nor a cashbox deduction. Net collections may be negative during returns periods. Re-entering remaining cash preserves that net baseline to prevent double deduction. Quantities return to inventory on the return date only when selected. Allocate discount and dinar rounding cumulatively so returning all quantities refunds the exact full net receipt; reject returns exceeding sold quantities and voids of sales with returns. [Details](../decisions/0010-mvp-returns-and-held-orders.md).
