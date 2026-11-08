# Restaurant journal proposal candidate

Date: 2026-11-07T14:23:29.324040+00:00. Status: pure candidate; independent review pending.

Gemini delivered lib/accounting/restaurant_journal_mapper.dart and19tests using the already-public pinned Madar journal API. App owns symbolic chart/source mapping and correction metadata; Madar owns journal validation/reversal. No store/codec/public pin/routing changes occurred. Accepted ADR0021 applies; actual date/amounts and migration remain gated.

Root found that negative verified register/safe openings were rejected despite the accepted signed orientation rule. Root replaced the contrary test with two policy regressions, observed both fail, then mapped signed cash to debit/credit using positive absolute units while retaining signed net assets for opening equity.20mappertests and the combined42accountingtests pass; targeted analysis passes. Independent review must check source-valid zero values, immutable snapshots, amount/aggregate limits, corrections/eligibility and unmapped counterparts before adoption. Feature benchmarks and durable consumer integration remain pending.

No actual balances or restaurant records were read or modified. Engine runtime/API change: N/A for this mapping candidate; it consumes existing reviewed BalancedJournal/JournalPolicy. Generic durable coordination remains in Madar and is not yet adopted here.


## Independent review and root integrity fixes — 2026-11-07T14:55:29.501229+00:00

Independent review73dfce71 passed the original accepted-policy mapping and all four category fixes. Root addressed its metadata/reversal/opening observations before persistence integration. Six new integrity tests all failed before source changes. Metadata now snapshots exact scalars and string-keyed map/list containers, recursively freezes them, and rejects cycles or unsupported mutable values. Structural inverse-of-inverse voids reject with already_reversed even if a caller asserts eligibility; durable uniqueness and return eligibility remain command responsibilities. Voids preserve source schema version as well as receipt/date lineage.

Opening values represent verified aggregates. Their default profile now permits safe-integer line/side totals up to2^53-1 and the supported5000supplier identities (at most5003lines), while ordinary transactions retain the10^12entry bound. Explicit caller policy overrides remain honored. Opening line/side overflow maps to opening_balance_limit_exceeded; source supplier count overflow has its own guard. This selects no actual opening value, date or migration.

Review prose named JournalValidationException, but current Madar source throws DomainValidationException with structured journal_* codes; the implementation catches the actual type. Seven integrity cases plus20mapping cases pass, and all53accounting tests pass. Analysis initially reported one missing brace; root fixed the style-only issue and final analysis passes. No new engine implementation/API change was needed for these app mapping/envelope fixes. Exact hashes: outputs/completion-review/journal-integrity-recheck-inputs.json. Fresh focused independent recheck remains pending.


Focused independent recheck2034e449 on 2026-11-07T15:22:46.728151+00:00 matched all three exact hashes and passed27mapper/integritytests,53accountingtests andanalysis, with no actionable defect. Metadata snapshots, inverse guards, source-version lineage and opening safe-aggregate/supplier limits are independently verified. Actual cutover/migration/runtime posting remain pending.
