# Reversed-opening debt eligibility repair

Observed UTC: 2026-11-07T22:36:00.843166+00:00. Fresh independent spending review found that a valid opening journal plus its inverse could still authorize supplier debt payment. The complete-state codec accepted the synthetic state, and a50payment against a reversed100opening was accepted. This review replaced an unreported older task after cancellation request; it did not change policy.

Root retained two proposal and two actual-store regressions for direct debt and selected-invoice spillover. All four failed before the one-condition active-opening guard.194accounting tests and scoped analysis pass afterward; fresh focused reviewer independently passes42safety cases and21exact hashes. Actual-store rejection preserves payload, revision, fence, journals and receipts.

Existing unverified_historical_debt is reused. Future-payment reservation, selected-invoice-first allocation, codec, mapper, source schema and approved financial policy remain unchanged. No live cutover/amount approval or runtime UI/posting activation follows. Engine implementation/API/Design N/A for this app guard; reviewed public contracts consumed.

Current source15535658999e254c762d31641a632d6195b67320850b3fdd9303b559ba14cfa1; tests875e3cd164336540c92b78fb0cb8c295616ce7b73d00c41688ec4358af1acb15. Canonical evidence: outputs/completion-review/durable-spending-opening-repair/.

Reviewer free108239808→108233792KiB, no temporary Git stores or fixture directories. Prior broader reviewer removed three explicit probe directories; no production files changed by reviewers. Root retains only specification/regression source and compact canonical logs. Current memory checks determine delivery separately.
