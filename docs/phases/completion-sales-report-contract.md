# Completion sales history report contract

Status: nonvisual read-only implementation; independent review and UI integration pending.

## Source and ownership

`lib/reports/sales_report.dart` composes validated `AccountDocument` snapshots into sales history. Its source is the frozen `electron-reference/app/ui/commerce.js` `salesHistoryPage` calculation and `model.js` sale totals. Madar `CommerceCalculations`, `ExactDecimal`, `ExactMath` and `DateOnly` own reusable arithmetic/date primitives. No engine source is copied. The app owns source schema mapping and history selection. No new engine capability is required for this slice; reviewed dependency identity remains the parent Completion integration's responsibility.

## API

`SalesReport.build(document, filter: SalesHistoryFilter(...))` accepts a codec-validated account. Empty filter strings disable that filter. `from` and `to` are inclusive business dates, validated as date-only values. Reversed bounds are rejected, matching the source validRange guard before rendering. `status` accepts empty, `completed`, or `void`; invalid status is rejected. Order type uses exact saved text. Query is a lowercase substring search across receipt number, note and saved line names, including source separators; it is not trimmed, tokenized or searched against current product names.

`sales` contains immutable `SaleHistoryRow` values with the saved `snapshot`, original post-discount `total`, and all-time `lifetimeRefunded`. Sale rows sort descending by business date, then the saved timestamp text, with original order retained for equal keys. This is not timezone-normalized timestamp ordering. Current timestamp comparison is Dart lexical ordering; source uses JavaScript localeCompare. Canonical ISO timestamp parity is covered, but noncanonical legacy timestamp collation remains a known compatibility gap pending resolution. The saved snapshot includes original line names, units, quantities and prices; catalog changes do not rewrite it.

`returns` contains immutable saved return records in their source order. Return eligibility uses the return's business date plus the originating sale's status, order type and text. The originating sale need not fall within the date range. `completedTotal` includes selected completed sales after discounts; void sales appear in history/counts but contribute no amount. `refunded` is the selected period's refund total. `netMovement = completedTotal - refunded`; a return-only period can be negative. Counts are `completedCount` and `voidCount`.

These amounts describe net sales movement, not profit, cost of goods, expenses, cashbox or remaining cash. The API writes nothing and adds no receipt/PDF/UI/posting policy.

## Numeric boundary

Line arithmetic uses the source quantity scale3, quantity-unit and IQD money limit1,000,000,000,000, safe-integer limit9,007,199,254,740,991 and half-toward-positive-infinity rounding through Madar. History aggregates use existing shared `ExactMath.binary64IntegerSum`: preserve sorted active-sale accumulation, source-order refunds and separately accumulated groups before subtraction. This explicitly reproduces the frozen history UI, including representable totals above2^53; it does not select a new financial rounding policy or widen account validation.

## Evidence and limits

Tests precede implementation; the first attempt hit a concurrent Flutter native-assets codesigning race, and the bounded retry observed the expected missing-report API failure. Focused tests execute the actual frozen `salesHistoryPage` calculation prefix using Node and source-generated, validated synthetic records across ten filter cases. They cover negative return-only periods, void exclusion, historical name/price preservation, all-time refunds, immutable nested snapshots, invalid filter rejection, and a codec-valid 9,008-day history exceeding the safe aggregate boundary. Node is required for the conformance test; missing Node is a failure, not a skipped pass.

No production records or native app were opened. No performance optimization was attempted; feature benchmark evidence is pending the parent Completion campaign. Focused results are recorded in Completion build evidence. This is not full Phase 05 completion or release readiness.

## Full-app parity repair checkpoint

Added a codec-valid9,008-day history with alternating discounts and compared the actual frozen salesHistoryPage calculation prefix. Test-first Flutter run:5passed/1expected failure at old checked sum. After reusing shared binary64 summation, targeted analysis passes and standalone pure-Dart actual-source probe passes with total9007999999995496. Flutter green attempt failed before loading tests because compiler copy hit ENOSPC; no suite pass claimed, no unchanged retry. Logs: /tmp/report-parity-red.log, /tmp/report-parity-green.log, /tmp/report-parity-pure-green.log.

Collation remains unresolved: accepted noncanonical timestamp strings need the shared explicit en-US ICU78.2/CLDR48 comparison profile observed from Electron44.5.1, sensitivity variant, numeric false, caseFirst false, ignorePunctuation false. Parsed-time ordering or a one-case lowercase workaround is not equivalent. The parent owns shared API allocation; this app does not duplicate an ICU comparator.
