# Completion Financial Packet Evidence Log — 2026-11-07

## Task Ownership & Mandate

- **Role**: Research sub-agent.
- **Sole Ownership**: Compact concrete review packet for F-01–F-04; no runtime, source, dependency, or pin changes.
- **Target Deliverable**: [completion-financial-mapping-proposal.md](../phases/completion-financial-mapping-proposal.md).
- **Boundaries**: Strictly read-only documentation work. Preserved all pre-existing dirty work; no commits, branches, merges, tags, or releases; no financial database writes; no child subagents invoked.

## Inputs & Authority Inspected

1. **Hindsight Memory Preflight**: Performed project-scoped recall via local CLI fallback for `daftar` (`project-daftar`) and `madar` (`project-madar`) per `t3-hindsight-required/SKILL.md`. Verified existing observations and findings.
2. **Madar Engine Contracts**:
   - `BalancedJournal`, `JournalLine`, and `JournalPolicy` in [journal.dart](../../../Madar_Engine/packages/domain/lib/src/journal.dart).
   - Reviewed contract documentation at [completion-journal-contract.md](../../../Madar_Engine/docs/reference/completion-journal-contract.md).
   - System invariants in [FULLSTACK.md](../../../Madar_Engine/FULLSTACK.md) (FIN-01, FIN-02, FIN-03, FIN-04, FIN-07, FIN-09, ARCH-02).
3. **Dakhl Restaurant Frozen Parity & Rules**:
   - [accounting-rules.md](../reference/accounting-rules.md).
   - [accounting-parity.md](../planning/flutter-rebuild/accounting-parity.md).
   - [daily_cash_queries.dart](../../lib/accounting/daily_cash_queries.dart).
   - [legacy_account_codec.dart](../../lib/accounts/legacy_account_codec.dart).
   - [account_document.dart](../../lib/accounts/account_document.dart).
   - Repeated problems prevention in [repeated-problems.md](../how-to/repeated-problems.md) (A09: financial/reference history preservation; A23: financial terminology fidelity).

## Packet Synthesis & Concrete Structure

The review packet [completion-financial-mapping-proposal.md](../phases/completion-financial-mapping-proposal.md) was drafted to provide complete, actionable reviewability for the owner across all four gates:

1. **Approved Invariants Separated**: Separated fixed constraints (single-restaurant, offline Arabic RTL, IQD whole units, no invented tax/COGS/recipe consumption, cash is not profit, carton/piece pricing, return/void semantics) so the owner is not burdened with re-deciding approved policy.
2. **F-01 Account Classifications & Worked Scenarios**:
   - Established symbolic hierarchy: `asset:cash:daily`, `asset:cash:cashbox`, `liability:supplier:<id>`, `clearing:purchases:invoiced`, `revenue:sales`, `contra_revenue:sales_return`, `expense:category:<id>`, `equity:opening_balance`.
   - Developed 6 complete worked scenarios covering: Sale with discount (12,000 IQD net), Shared expense (30,000 IQD funded 20,000 daily + 10,000 cashbox), Purchase invoice (87,500 IQD debt), Supplier payment (20,000 IQD split 12,500 invoice / 7,500 debt, funded 15,000 daily / 5,000 cashbox), Customer refund (1,000 IQD with stock restock), and Daily-to-cashbox cash transfer (20,000 IQD).
   - Every scenario demonstrates debit/credit equality, exact integer IQD units, and source cash/stock movements.
3. **F-02 Cutover vs. Historical Backfill**:
   - Compared Alternative A (retrospective synthetic backfill) vs. Alternative B (explicit cutover with opening balance journal).
   - Provided reasoned recommendation for Alternative B to eliminate the risk of inventing unverified historical accounting records.
4. **F-03 Immutable Correction Mappings**:
   - Mapped ordinary user edits/deletions/date-shifts to atomic pairs of `BalancedJournal.reversed()` and new replacement postings.
   - Grounded Session Undo as automated inverse execution preserving audit provenance under `FIN-02`.
   - Demonstrated 3 worked correction/undo scenarios (expense edit, payment delete, date shift).
5. **F-04 Identity, Dates, Export & Schema Compatibility**:
   - Defined stable UUID v4 and SHA-256 payload identity with duplicate retry protection.
   - Distinguished accounting `effectiveDate` (`DateOnly`) from system `recordedAt` (UTC timestamp).
   - Outlined Schema 12 extension to `AccountDocument` and `LegacyAccountCodec` for lossless portable backup/restore.
6. **Four Precise Unresolved Decisions**:
   - Formulated 4 explicit decision gates with concrete alternatives, trade-offs, and reasoned recommendations ready for root presentation.

## Storage Baseline & Closeout

- **Intake Disk State**: Filesystem `/dev/disk3s1`: Size 460Gi, Used 326Gi, Avail 101Gi (77% capacity, iused 3.6M).
- **Exact Intake Block Available**: ~105,900,000 KiB.
- **Closeout Disk State**: Filesystem `/dev/disk3s1`: Size 460Gi, Used 327Gi, Avail 101Gi (77% capacity, iused 3.55M).
- **Exact Closeout Block Available**: 105,900,868 KiB.
- **Task Storage Impact**: Zero runtime scratch copies, zero temporary databases, zero binary exports, zero extra worktrees created. Pure documentation artifacts total < 30 KiB. Storage containment maintained.

## Handoff & Next Steps

This documentation review packet is complete and self-contained. Root agent owns the presentation of the 4 decision gates to the owner. Independent authorized development (such as non-financial UI, pure generic validation tests, and queries) can proceed unblocked.


## Parent review corrections

Initial packet was not accepted as approval-ready. Parent checked current generic JournalPolicy/BalancedJournal, canonical schema11 codec/model and frozen accounting rules. Corrected: unsupported100percent safety/forward-reader claims; random UUID versus deterministic identity; invoice-line quantities versus material-stock records; clearing historical debt without verified opening counterpart; distinct87,500invoice and12,500/7,500allocation fixtures; negative-cash rejection incompatible with source; proposed replacement/soft-delete fields presented as established; recordedAt wall-clock versus proof of commit; date-shift source/snapshot/transfer dependencies; optional journals alone omitting durable operation receipts; misleading backfill/cutover risk absolutes and separate-table export assumptions. Initial source-log Madar relative links fixed. No policy selected or runtime writes made. Independent recheck remains required.

Storage note: child storage observations establish small document artifacts, not containment of recurring Git growth. Parent measured app.git31,401,532KiB, about1.47GiB above implementation kickoff, and sent the running storage owner this actual measurement. No full campaigns start until containment has evidence. Root must not infer existing generic journal implementation from this packet as new delivered consumer posting.
