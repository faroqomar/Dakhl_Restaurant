# Separate cashbox expenses and add the account statement

Status: implemented, verified and installed as a local update. Date: 2026-10-25. Source: application owner's request.

## Request and change

Separated cashbox expenses from daily expenses and total balance, and added an account statement with filters and analysis of the largest expenses. The automatic total and balance derived from the remainder now include only the daily share. The cashbox share appears in a separate table; a shared item is split between the tables according to payment allocation. Legacy records without a source continue to count as daily. Previously recorded balances are not rewritten.

Added an Account Statement page with from/to dates, category and funding-source filters. It shows the total, both shares, item count and categories ranked by recorded spending. The daily PDF displays the two expense groups separately. Statement analysis uses movements recorded as paid; it does not represent the value of unpaid credit invoices.

## Verification

Application tests passed after total/balance semantics were updated: 82 tests. Verification covered funding-source separation, both shares and statement filters. No synthetic data was used in the restaurant account.

## Installation status

Built macOS ARM64 and installed 1.9.0 at `/Users/eros/Applications/Daftar.app`. Launch and display of the Account Statement page and separated Daily Expenses page were verified. The previous application was preserved at `/Users/eros/Applications/Daftar-1.8.0-before-daily-statement.app`.
