# Return proposal contract

Status: pure candidate implementation; no durable posting, journal mapping, refund acknowledgement or UI integration. Engine APIs unchanged.

`ReturnProposal.build` accepts a codec-validated immutable base, sale identity, explicit return identity/timestamp/date/reason, caller-supplied current local date, and requested integer-thousandth quantities. It returns a new codec-validated immutable candidate and amount; it never saves or changes the base. The caller must bind a future durable operation to its base fence and obtain required cash-refund confirmation.

Frozen model.js returnQuote/returnSale define behavior: completed sale only; original saved price/quantity/tracking snapshots; unique known requested products; positive remaining quantities; restock only originally tracked items; date at/after sale and no later than supplied today; nonblank source-compatible trimmed reason; unique return identity and accepted timestamp. Madar CommerceCalculations supplies discounted line budgets and cumulative-floor refund deltas. Full cumulative returns exhaust original net. Codec revalidation protects schema, aggregate and historical stock constraints.

Verification: tests precede implementation (missing API compilation failure). Actual frozen model creates/validates a two-line discounted sale and two successive partial/full returns, including restock. The Dart base/candidate both pass LegacyAccountCodec, full candidate JSON matches source, and base remains unchanged. Pure-Dart checks cover empty/duplicate/unknown/excess lines, untracked restock, before-sale/future dates, blank reason, duplicate return identity and candidate immutability. Focused analysis passes. Flutter wrapper is provided but has not run under current storage constraint. No production records, merge or readiness claims.

The pure proposal does not resolve FIN-01/FIN-02 journal/opening/history/correction mapping. It is a specification and reusable consumer preparation seam for later approved durable integration.
