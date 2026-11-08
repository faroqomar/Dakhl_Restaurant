# ADR0021: Completion financial mapping and history treatment

Date: 2026-11-07. Status: **Accepted conceptual policy; implementation and verification pending.** Source: owner selected “Approve the recommended policy package” after reviewing the [financial mapping packet](../phases/completion-financial-mapping-proposal.md#owner-decision-summary). The implementation instruction covers the existing Completion plan; this decision does not authorize live migration, named UI designs, exact merge revisions or release.

## Accepted worked-example supplement — 2026-11-08

The owner accepted [sections A–D and F](../phases/completion-remaining-correction-approval.md) after independent review: eligible expense/payment corrections, day/range shifts, compensating session undo and complete-state compatibility semantics. Section E remains fail-closed for financial corrections without an eligible original posting until a separately verified exception is accepted. No backfill/opening adjustment, live date/amount, UI approval or runtime activation follows. The earlier conceptual-policy record below retains its original scope.

## Accepted supplier-opening amendment supplement — 2026-11-08

The owner explicitly approved the [supplier-opening amendment proposal](../phases/supplier-opening-amendment-proposal.md). Preserve the verified original opening and append linked differences effective at the established cutover date against an explicitly accepted opening-equity counterpart. Require a reason and durable proof; reject amendments that underfund retained settlements. New supplier metadata plus nonzero opening commits atomically. This supersedes the earlier opening-adjustment exclusion only for this named development contract. Actual opening values, live migration/cutover and release remain separately gated. Implementation and verification follow; approval is not a passed result.

## Context

Madar requires balanced journals and immutable posted history. Dakhl_Restaurant retains its frozen offline single-restaurant Arabic RTL/IQD workflows, source paid-spending definitions and schema1–11 history. The earlier record left account classification, historical treatment and correction mappings unresolved. The owner has now selected the packet's recommended package, following independent review and the parent's five adjustments.

## Accepted policy

| Area | Selected semantics |
| --- | --- |
| Purchases1A-P | Internally debit purchase expense and credit supplier liability when an invoice posts. Settlement debits liability and credits its daily/cashbox funding. Do not also create a day-expense source entry for the unpaid invoice or recognize the purchase expense again at payment. |
| Visible paid spending | Continue computing the source paid-spending register from actually paid expenses/payments, once each. This screen and internal accrual purchase expense have different meanings. No profit/COGS/stock-valuation report is added. |
| SalesR1 | Debit daily cash and credit net sale revenue for saved net receipt value; retain original gross/discount/net snapshots. |
| RefundsT1 | Debit separate sales-return contra-revenue and credit daily cash on return date. Preserve original sale, cumulative allocation and optional tracked-item restock. No expense/cashbox refund deduction. |
| History2A | Preserve pre-cutover source history; establish an explicit cutover from verified openings rather than fabricate complete historical journals. Actual cutover date, values, opening counterparts and pre-cutover correction examples still need verification/acceptance before migration. |
| Corrections3A | Use linked original-date inverse and replacement semantics preserving source daily-register outcomes. Already-fixed sale-void and stock-reversal date rules remain intact. No correction-date reporting layer/day locking. |
| Portability4A | Preserve complete source/journal/correction/operation identity/outcome state in validated portable form through one reviewed persistence owner. Lead selects/reviews technical representation within these semantics. New schema readers retain supported old-input migrations; old readers reject new versions. Rollback requires a compatible verified pre-upgrade backup. |

Use the accepted symbolic classification profile from the packet. Shared generic contracts remain in Madar; this app owns restaurant account/schema mapping and document composition. Do not add chart defaults to generic Madar values. App replacement/correction envelope links are not fields on current BalancedJournal unless a separate shared extension is reviewed.

## Consequences and remaining gates

Dependent generic contracts, app proposals and isolated synthetic implementation can proceed under these accepted outcomes. F-05–F-10 still require durable operation identity, single-owner atomic commits, independent engine/consumer fault/restart/reconciliation tests, API documentation and exact reviewed engine adoption. Conceptual policy acceptance does not prove these capabilities.

No live opening amount, cutover date or source account is selected. Preserve original records, previous/recovery copies and unknown outcomes. Before any migration, verify explicit opening values and cross-cutover correction examples, backup/restore/replay behavior, size limits and source preservation. Keep all actual native, UI/design, signing/access, CI, exact merge and release evidence separate. Scope exclusions and retired-worker compatibility remain unchanged.

## Verification

This ADR records the owner's choice and reviewed boundaries. No runtime test/build/native migration result follows from writing it. Track implementation through the [213-item plan](../phases/completion-unfinished-implementation-plan.md) and [execution journal](../log/phase-completion-execution.md).
