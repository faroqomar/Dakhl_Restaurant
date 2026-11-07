# Daily, cash and paid-spending projections

Status: nonvisual implementation; independent review and Flutter verification pending. No posting or UI integration.

`DailyCashQueries` consumes codec-validated immutable `AccountDocument`. Frozen model.js dailySpent/transferred/remaining/total/salesTotal/cash/expenses and renderer.js statementPage define behavior. App owns record projections and labels; engine owns exact/binary64 arithmetic and commerce calculations. No engine changes or financial mapping policy selected.

Daily spending counts original expenses plus supplier payments exactly once, using only daily funding share. Cash balance follows source movement order: explicit cash transactions, cash shares of expenses/payments in insertion date order, then transfers. Invoices, debts, workers/savings and chicken quantities are not cash spending. Returns reduce net sales on their return date, not cashbox or expense totals. Remaining uses source snapshot delta grouping; recorded balance remains the saved value. Manual total override affects displayed daily total only. None of these quantities denotes profit.

Statements filter date/category/funding, retain source date order and within-date record order, and omit zero selected shares. Cash-only daily share is zero. Category totals retain insertion order for callers to apply stable amount ranking. This API does not implement localized timestamp sorting, rankings presentation, PDFs or operational screens. No locale comparator is used: statement dates are validated ISO dates.

Verification: synthetic Node oracle invokes actual frozen model and validates its state, covering shared expenses, supplier payment, cash deposit, transfer, sale and next-day refund. Test-first analyzer failed for missing API before implementation. Targeted analysis passes. A standalone pure-Dart probe passed23 checks against source oracle; Flutter execution is pending the shared test slot/storage recovery. Test code additionally covers manual override, chicken independence, filtering, invalid dates/ranges and immutable results. No production records used.

Cashbox row integration foundation: cashMovements now exposes immutable source-ordered rows, preserving editable-versus-derived kinds and IDs; cashBalance consumes the same rows. Root implementation followed missing-API red; four-row frozen oracle/immutability and original23checks pass. Independent reviewer also verified missing timestamp fallback. Flutter/UI integration remains pending.
