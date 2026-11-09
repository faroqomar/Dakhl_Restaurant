# Reviewed engine source adoption

2026-11-08T04:43:17.376375+00:00 — App now deliberately pins independently reviewed engine source 783e29cf8ae5c829cbb09bdb5b7a547aa92bc8d6, application dev.5. Only engine-dependency.json and the application path version in pubspec.lock changed. Offline enforced resolution passed; pubspec and other lock entries are unchanged. No optional ICU adapter dependency or comparator wiring was added. The source/pin/boundary guard passes and both consumer adapter wiring tests pass. [Verification](../../outputs/completion-review/collation-consumer-adoption/verification.json).

Fresh adoption review and exact F10 assessment remain pending. F08/F09 fixtures used unchanged domain/coordinator/storage implementations; their historical consumed-pin provenance remains d316fd. Transfer correction repair frozen under d316 was rebound in a successor manifest only for the listed pin/lock hashes; prior manifest stays immutable. No new business/runtime schema or live account changed. No push, merge, tag, hosted CI, mobile collation qualification or release.

Audit: initial lock-stanza end search matched child indentation after the pin write; root corrected it before any pub/test command, and verified the original pin bytes hash. This is avoidable parser overhead. Enforced offline pub get updated no other dependency.
