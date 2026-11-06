# Completion financial mapping decision packet

Status: proposal only; no owner decision or durable implementation. Prepared during authorized Step3 independent work. The no-questions instruction means preserve the alternatives and continue independent work, not silently select policy.

## Fixed source behavior

Whole IQD; shared expense30,000 draws20,000daily/10,000cashbox exactly once. Invoice87,500 adds supplier debt without paid spending. Payment20,000 against selected invoice12,500 and eligible debt allocates12,500/7,500; daily15,000/cashbox5,000 funding creates one paid expense. Sale12,000 raises daily net collections; refund reduces net collections on return date and is not an expense. Remaining-cash snapshots are not revenue/profit. Source authority: accounting-rules.md, accounting-parity.md and frozen model.js. These numeric fixtures are synthetic.

## Proposed symbolic postings for review

Names below are placeholders, not selected chart identifiers or a financial report classification.

| Action | Debit proposal | Credit proposal | Required reconciliation |
| --- | --- | --- | --- |
| Sale12,000 | Daily cash12,000 | Sales12,000 | One sale identity, stock effects and daily collections |
| Shared expense30,000 | Expense category30,000 | Daily cash20,000 + cashbox10,000 | One source expense and both funding shares |
| Purchase invoice87,500 | Purchase/material clearing87,500 | Supplier liability87,500 | Debt only; no paid expense at invoice time |
| Supplier payment20,000 | Supplier liability20,000 | Daily cash15,000 + cashbox5,000 | Allocation12,500/7,500; paid-spending query counts payment once, not invoice plus payment |
| Refund1,000 | Sales-return contra account1,000 | Daily cash1,000 | Original sale preserved; return-date collections decrease; optional stock return separate |
| Daily-to-cashbox transfer20,000 | Cashbox20,000 | Daily cash20,000 | No expense or revenue; saved total balance unchanged |

Purchase/material clearing classification and chart identifiers need an explicit decision. They must not imply inventory valuation, recipe consumption, profit or tax policy. The restaurant source-paid-spending statement and ledger classifications must reconcile without treating them as interchangeable reports.

## Opening/migration alternatives

A. Reconstruct supported source history into linked postings, preserving every original identity/date/amount. This needs full historical mapping and rejected-record policy; unknown provenance cannot be manufactured.
B. Keep pre-cutover source records authoritative and create explicitly documented migration-opening postings for verified balances, with a clear cutover boundary. This needs agreed opening account identifiers, verified balances and visibility rules; do not derive them from remaining-cash snapshots by assumption.

Neither alternative is selected. Both require schema/version/export compatibility, rollback and original-byte preservation tests. No production migration is authorized by this document.

## Corrections and undo

Proposed rule: durable posted records remain immutable; a correction command atomically writes linked inverse/adjustment plus the new source interpretation and related cash/stock effects. Original source identity/history remains traceable. Exact policy still needs disposition for ordinary source edit/delete, original-date versus correction-date effects, invoice paid restrictions, day-date shift and in-session undo. An undo of a correction must preserve correction provenance rather than delete its existence. This does not add a universal user-facing audit screen.

Worked acceptance fixture: shared expense30,000 changed to32,000 while preserving cashbox10,000 implies daily22,000. Proposed linked inverse cancels old20,000/10,000 and replacement posts22,000/10,000 in one commit. Inject failures before source/journal/effect publication: either previous30,000 state or complete32,000 state is authoritative, never partial. Actual correction date and export representation remain undecided.

## Unblocked engineering

Generic balanced journal validation/reversal values, exact arithmetic, fixture corpus, stock/query/eligibility, nonfinancial catalog/settings/workspace and read-only report definitions can proceed. Durable restaurant postings, historical reconstruction and affected corrections wait for accepted mappings. No question or assumed approval is emitted while the owner is sleeping.
