# Isolated durable daily-to-cashbox transfer candidate

Status: authorized Completion foundation slice, create-only. Advances the C4-16 foundation and F-07–F-09 evidence; it does not close operational UI/checklist rows. Design: N/A for this isolated nonvisual command. C4 UI and transfer edit/delete (C4-17) remain separate.

## Ownership and accepted basis

Dakhl_Restaurant owns source transfer/document composition, command identity and replay reconciliation through the existing JournalCommandHost and portable state. Reuse the reviewed public Madar exact arithmetic, balanced journal and durable coordinator contracts at d316fd6076375daa3f412889f73eaebfeeb5d4d4; new engine implementation/API is N/A unless a concrete missing shared capability is demonstrated first. The separate uncommitted collation candidate still fails the whole-source pin guard; preserve that failure and do not adopt or bypass it.

Use ADR0021's existing transfer mapping and the frozen model.js transferRemaining semantics: debit cashbox asset, credit daily-cash asset, no expense. Preserve the saved overall balance, including source recovery when an older/manual day has an unset total. Preserve the recorded remaining snapshot's subsequent sales/refund/spending/transfer deltas exactly once. Do not invent a snapshot, opening, debt or balancing amount.

## Acceptance

One command must atomically persist the source transfer, corresponding journal and one durable receipt through the same store owner. Capture caller-owned operation/transfer/journal IDs, date/time, lineage, expected fence and amount in bounded immutable intent; changed intent must reject replay. Validate source/journal/outcome reconciliation before receipt replay through the existing scoped host boundary. Require established eligible cutover and reject pre-cutover operation or missing captured authority before writes.

Transfer20000 from available100000 leaves80000 and adds20000cashbox; transfer-all reaches zero. Require a recorded remaining snapshot, positive source-compatible bounded IQD amount and sufficient current availability. Reject missing snapshot, excessive/zero/negative amount, duplicate source/journal IDs, stale authority and malformed inputs without changing payload/revision. Source totals and historical saved receipt outcomes remain stable across later valid commands.

Use actual frozen-JavaScript differential fixtures for ordinary, transfer-all, legacy-unset-total and subsequent dated-effects cases. Include meaningful pure tests plus real-store atomicity, reopen/replay, changed-payload and lost-ack tests; extend a bounded mixed sales/spending history without duplicating established algorithms or F08 campaigns. Run affected analysis/tests/boundary checks and obtain independent review. Document public app API/examples/stable errors, exact source and consumed engine identities, limits and storage cleanup.

Record separate transfer-operation performance as pending until a reviewed preflight/workflow campaign measures p50/p95, sampled RAM/CPU on declared fixtures. Other feature timings are not transfer performance. No native matrix, arbitrary-power-loss or hosted-CI claim follows from unit/real-store tests.

## Protected scope

No runtime repository/bootstrap/schema12 activation, live opening values/date/cutover, account access, UI/route/Penpot changes, worker-advance revival, manual-debt counteraccount choice, transfer edit/delete, engine source/version/pin edits or Git mutation. Preserve concurrent files and all earlier candidates/reviews. No self-approval or tracker closure.
