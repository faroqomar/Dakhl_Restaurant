# Frozen legacy compatibility expectations

The owner retired `electron-reference/` on 2026-11-12. These synthetic fixtures preserve the former JavaScript outputs used by Flutter regression tests, without retaining or executing the Electron application. They contain authored test records, not restaurant data.

`provenance.json` records the pre-retirement repository commit, source SHA-256 hashes and Node/V8/ICU capture runtime. Recover the old source from that Git commit if an independent historical investigation needs it. Runtime dependencies on the deleted tree are removed.

- `sales_history.json`: ten source filter cases, canonical account, date-range acceptance and totals.
- `sales_large_total.json`: the 9,008-row source binary64 aggregate expectation.
- `daily_cash.json`: daily/cash queries, refund dates and movement ordering.
- `day_date_correction.json`: source before/after maps for date correction with an independent sale and recorded remaining baseline.
- `report_account.json`: the original synthetic PDF account plus one sale for seven report kinds.
- `return_proposal.json`: source return candidates including partial/cumulative refund history.
- `payment_corrections.json` and `expense_corrections.json`: complete source account maps after repeated edits and deletion; source-body hashes accompany the captured results.
- `product_photo_hashes.json`: SHA-256 of the eight former reference thumbnails; compare existing canonical Flutter assets without a second image copy.

The existing account, catalog, sale, purchase and supplier JSON oracles remain in their original test paths. Their finite cases retain their recorded limits. These tests compare Dart behavior to independent captured source results; they no longer claim a live differential JavaScript run. Do not derive replacement expected values from the implementation under test. Review intentional compatibility changes against independent requirements.

## Durable transfer oracles

`durable-transfer-oracle.json` and `durable-transfer-corrections-oracle.json` are fixed synthetic inputs to the transfer safety suites. They retain the exact bytes of the respective `oracle-repaired-1.json` files from the archived transfer and transfer-correction comparisons at `7b85ca43e6ff93f82c58a9da546147cb5779f1dd`.
