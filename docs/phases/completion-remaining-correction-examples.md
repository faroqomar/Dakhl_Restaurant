Current owner acceptance, 2026-11-08: **Sections A–D and F accepted; section E missing-posting financial corrections remain blocked until a verified exception is accepted.** [Exact approval and boundaries](completion-remaining-correction-approval.md). This resolves the worked-example/compatibility-contract decision only; runtime implementation, live values/date and UI/merge/release gates remain separate. The proposal below preserves its pre-approval wording and evidence.

---

# Remaining F-03/F-04 correction and compatibility examples

Status: **review proposal, not an approval or runtime implementation**. Prepared 2026-11-08. These examples supplement [the accepted financial policy](../decisions/0021-completion-financial-policy.md), [the earlier worked mappings](completion-financial-mapping-proposal.md) and [the isolated portable-state contract](completion-journal-persistence-contract.md). They do not replace those records.

The owner already accepted 3A (original-date linked inverses/replacements), 2A (explicit cutover with verified openings) and 4A (portable complete state; Lead selects representation). Those directions need no renewed approval. F-03 still requires acceptance of the remaining edit/delete/date-shift/undo examples and their rejection cases. F-04 still requires the full identity/history/compatibility contract. This packet gives a concrete basis for that review; it does not close either row.

## Ownership and evidence

Dakhl_Restaurant owns source projections, correction commands, source snapshots, lineage reconciliation, import/restore safeguards and UI. Madar owns the existing exact balanced-journal value, durable coordinator and single-store protocol. **New engine implementation/API: N/A**; the examples use the reviewed public contracts at consumed revision `d316fd6076375daa3f412889f73eaebfeeb5d4d4`. Separate uncommitted collation/package work is not included in that consumption claim.

No UI, runtime repository, live account, bootstrap, schema activation, engine pin or Git state is changed by this work. Concurrent transfer edit/delete implementation has its own owner and contract; this packet neither changes nor certifies it. Benchmarks are N/A for this documentation/probe step; eventual implemented correction operations retain their separate performance obligation.

Frozen-source evidence is source-probe-result.json: **15 checks** against the actual model and exact extracted renderer/UX/payment bodies. DOM, confirmation and save adapters are synthetic. Public mapper/portable representation evidence is mapper-probe-result.json: **7 checks**. It proves balanced examples, links and serialization, not reconciled command execution or an import path. The review manifest freezes artifacts and source hashes. No expensive build or duplicate full suite was needed for this proposal.

## What the frozen source actually does

| Operation | Source behavior and restriction | Immutable-history translation |
|---|---|---|
| Expense edit | Renderer `submitForm`, expense branch: retain ID and original `createdAt`; remove old day row and append replacement at chosen date; trim note; funding shares must sum to amount. Zero amount is source-valid. | Preserve the old posting and source snapshot. Append its original-date inverse and a new posting for the replacement source state. Explicit allow-zero policy is needed for codec-valid zero examples. |
| Expense delete | Renderer `confirm-delete`: remove current row, save candidate, allow session undo. | Remove only the current source projection; retain its historical snapshot and posting. Append inverse, with no replacement until a later undo/restoration operation. No invented source soft-delete fields are required. |
| Payment edit | Suppliers `supplierSubmit`: preserve ID/`createdAt`; remove old payment for split calculation, then save new invoice/debt allocation, funding, date/category/note. Amount must be positive. | Inverse the exact old liability settlement and funding, then post the validated replacement settlement. Store both allocation snapshots. Editing funding/category/note must not corrupt journal/source reconciliation. |
| Payment delete | Supplier action removes the row then the complete candidate passes model validation. The handler has no blanket later-payment deletion ban. | Restore old invoice/debt allocations and cash by inverse; preserve remaining source records. Revalidate source references/timeline. Do not invent a stricter permission merely because other payments exist. |
| Invoice restrictions | An invoice with linked payments cannot be deleted until those payments are removed. Validation rejects invoice reduction below paid value. Payment date cannot precede the linked invoice; debt timeline must remain valid. | Refuse the entire candidate before persistence if these restrictions fail. No partial inverses or source deletion may commit. Invoice edit/delete composition itself is separate work. |
| Day date shift | `dayDatePlan`/`correctDayDates`: preview recorded range and common offset; prevent collision with records outside range; move day objects plus payment/transaction/transfer dates atomically. Sales, returns, invoices, inventory, debts and worker records retain independent dates. Source correction entries retain their stored `date`, even when their containing day moves. | Reverse eligible moved postings on their old effective dates and replace on target dates. Move source-only metadata exactly as source does. A component with no accepted mapping cannot be silently omitted. |
| Session undo | Successful ordinary commits retain at most 30 pre-save source snapshots. Failed saves do not pop history. Sales/return changes clear generic history; empty-history undo can open eligible completed-sale void, rather than erase sales. `preserveCorrectionTrail` keeps prior manual-total/balance audit entries and appends a compensating entry when undo changes their value. Import/account load resets session history. | Undo is a new compensating operation over the current accepted state. Never replace the durable envelope with an old snapshot or discard receipts/journals. Retain source-visible behavior and correction trail. |

Source authorities: [renderer.js](../../electron-reference/app/ui/renderer.js) (`commit`, `submitForm`, `undo`, `backup`, `confirm-delete`), [suppliers.js](../../electron-reference/app/ui/suppliers.js) (`supplierSubmit`, `supplierAction`), [ux.js](../../electron-reference/app/ui/ux.js) (`preserveCorrectionTrail`, `recordCorrection`), [model.js](../../electron-reference/app/ui/model.js) (`splitPayment`, `validateSuppliers`, `dayDatePlan`, `correctDayDates`). Exact method names are preferable to line offsets that may drift.

`splitPayment` allocates to the selected invoice remainder first and then available supplier debt. Its `debtAvailable` excludes the edited payment but deducts saved debt allocations from other payments, including later saved payments. The debt timeline validator separately rejects payment before debt. These source rules must be covered by differential tests; this packet does not replace them with a newly invented as-of balance policy. The isolated durable spending slice intentionally has additional verified-journal/cutover eligibility boundaries; raw manual debt is not thereby approved for posting.

## Synthetic notation and identities

All figures below are synthetic integer IQD (scale 0). `D0 = 2026-11-02`, `D1 = 2026-11-03`, and `R = 2026-11-08T04:00:00.000Z` are example dates only, **not proposed live cutover values**. The examples in sections A–D assume D0/D1 are on the accepted side of a hypothetical cutover and have eligible original postings. Section E covers the missing-posting boundary.

Accounts use the existing `RestaurantAccountProfile`: `asset:cash:daily`, `asset:cash:cashbox`, `expense:category:market`, `liability:supplier:supplier-01`. No counteraccount, COGS, tax or profit measure is added. `Dr`/`Cr` are balanced journal sides. Source IDs stay stable; every new journal, correction and operation has a new caller-owned ID. `createdAt` remains the source creation timestamp. `effectiveDate` determines financial date; `recordedAt = R` records when the correction was accepted. Receipt sequence, rather than a device clock, orders commits.

## A. Expense edit and deletion

Source `expense-01`: D0, category `market`, amount 30,000, daily funding 20,000, cashbox funding 10,000. Journal `E1`:

| Journal | Effective date | Debit | Credit |
|---|---|---|---|
| E1, original | D0 | `expense:category:market` 30,000 | daily cash 20,000; cashbox 10,000 |
| E1-inverse | D0 | daily cash 20,000; cashbox 10,000 | `expense:category:market` 30,000 |
| E2, edit replacement | D0 | `expense:category:market` 32,000 | daily cash 22,000; cashbox 10,000 |

For the edit, `correction-expense-01`/`operation-expense-01` commit E1-inverse + E2 + replacement source row together. E1 stays unchanged. `E1-inverse.reversesId = E1`; E2 has `correctedFromJournalId = E1`; the newly appended inverse may carry `replacementJournalId = E2`. This uses existing portable fields without rewriting E1. The mapper's `correctedFromId` is converted to the portable entry's `correctedFromJournalId`; they are distinct envelope field names, not new engine fields.

Current source effects: daily spending +2,000; cashbox delta 0; unchanged remaining snapshot yields remaining −2,000. A saved manual `totalOverride` or overall `balance` is preserved; automatic total changes with source daily spending. The snapshot amount is not overwritten to hide the correction. The original source ID and creation timestamp remain; before/after source snapshots and reason belong to correction metadata/history.

For deletion, commit E1-inverse and remove the original current row, with no E2. Relative to the original state: daily spending −20,000, cashbox cash +10,000, remaining +20,000 if the same remaining snapshot exists. Current row disappears; original posting/snapshot remains durable. If the current row is E2's version, invert E2, not E1 again.

Category-only/funding-only/note-only edits retain the same source edit semantics. Category change moves the expense debit; funding change moves the cash credits. An edit whose journal amounts are equal still needs retained source intent/history; equal amounts do not authorize mutable posted rows. Exact command/event representation is a Lead technical choice under 4A, subject to source reconciliation and tested roundtrip.

Reject mismatched funding, unsupported category, invalid date/amount, missing source or missing/changed expected source posting. Reject a second inverse of the same original. A zero expense requires the accepted explicit allow-zero mapping profile; this is compatibility, not permission to accept negative expenses. No drawer cash sufficiency rule is invented: source permits negative derived cash balances.

## B. Supplier payment edit and deletion

Assume invoice `invoice-01` has 12,500 due and separately verified eligible supplier debt is 7,500. Source `payment-01` settles 20,000 (invoice 12,500 + debt 7,500), funded daily 15,000/cashbox 5,000. Journal P1 is Dr supplier liability 20,000 / Cr daily 15,000, cashbox 5,000. The invoice itself is recognized once under accepted 1A-P; settlement never adds another purchase expense.

| Action | New journal entries, all effective D0 and recorded R | Source result |
|---|---|---|
| Edit to 18,000; funding daily 13,000/cashbox 5,000 | P1-inverse: Dr daily 15,000 + cashbox 5,000 / Cr liability 20,000. P2: Dr liability 18,000 / Cr daily 13,000 + cashbox 5,000. | Same payment ID/timestamp. Actual source split: invoice 12,500, debt 5,500. Remaining debt 2,000. Daily spending −2,000; cashbox unchanged. |
| Delete original P1 | P1-inverse only | Invoice due +12,500 and general eligible debt +7,500; daily cash +15,000, cashbox +5,000. Payment no longer appears as paid spending. |

Both allocation portions are source metadata on the liability settlement, not two extra expense journals. Preserve source supplier/category/invoice/date/funding/note/creation fields and exact allocation amounts. Replaying either operation must reconcile those fields and journal lines, including equal-total tampering.

The source permits the selected invoice's excess to settle available debt. The create-only isolated command's explicit no-silent-spillover boundary does not grant blanket correction support. A correction command must carry the captured invoice/debt intent and validate it against the accepted source result and verified liability; no other invoice or unjournaled manual debt may be silently funded.

Reject moving payment before its bill/debt, a foreign/missing invoice, overpayment, incoherent allocation/funding, unverified historical liability, reversed/ambiguous original posting, and changed expected source version. An invoice-with-payments delete or reduction below paid amount fails as one candidate. Removing a payment can make a later operation ineligible; subsequent commands must be re-evaluated against committed state. Do not rewrite an already committed later receipt/outcome to force consistency.

## C. Single-day and range date shifts

Take source `expense-01` 30,000 (20,000 daily/10,000 cashbox), payment P1 20,000 (15,000/5,000), and a 10,000 daily-to-cashbox transfer on D0. A single date-shift intent maps D0 → D1. Invoice `invoice-01` remains D0; a sale/stock movement/return/debt retains its independent date. Source payment date becomes D1 only if all validation remains valid.

| Moved posting | Original-date inverse at D0 | Replacement at D1 |
|---|---|---|
| Expense E1 | Dr daily 20,000 + cashbox 10,000 / Cr expense 30,000 | Dr expense 30,000 / Cr daily 20,000 + cashbox 10,000 |
| Payment P1 | Dr daily 15,000 + cashbox 5,000 / Cr supplier liability 20,000 | Dr supplier liability 20,000 / Cr daily 15,000 + cashbox 5,000 |
| Eligible transfer T1 | Dr daily 10,000 / Cr cashbox 10,000 | Dr cashbox 10,000 / Cr daily 10,000 |

Lifetime cash/liability/expense totals are unchanged. Dated effects move only with the source records above; source totals/manual values/remaining/chicken counts and existing correction trail move as the day object does. Transfers remain zero-expense movements. Transfer correction implementation and verification belong to its separate concurrent task.

Concrete remaining-snapshot case executed by the source probe: record 50,000 remaining after a 1,000 sale on D0, then add a 10,000 transfer. Available is 40,000. Shift the day to D1 while leaving the sale on D0. `correctDayDates` updates the moved snapshot's sales baseline from 1,000 to 0, preserving available 40,000; it does not create a sale at D1. Keep `balance` fixed and preserve a correction entry's original embedded date. General formula: new snapshot sales baseline = old baseline + sales currently at target − sales originally at source. This is a baseline reconciliation, not a journal cash adjustment.

For a range D0..D1 shifted +1 day, preview D0→D1 and D1→D2 together. Build the new day map before publication so one moved day cannot overwrite the other. Original source IDs/creation timestamps remain stable. One operation commits all eligible source changes, all inverses/replacements, mappings and its receipt. No loop of separately committed daily corrections.

Reject an occupied target outside the selected range, invalid range, missing starting record, source dependency failure or a new collision on retry. Reject the entire financial date shift if any moved financial source lacks an eligible journal or accepted mapping. In particular, generic cash transactions can be external money adjustments whose counterpart is still unresolved (`unmapped_financial_gap`); a date shift cannot invent that account. Quantity-only day fields have no invented journal. A no-financial-effect day shift can be source-only, but still needs durable operation/history composition and accepted compatibility behavior.

## D. Session undo without deleting durable history

After A's edit, current source has 32,000 and E2 is active; E1, E1-inverse and E2 remain immutable. Undo `operation-undo-expense-01` restores the source-visible 30,000 version with original ID/creation timestamp, while appending:

| New entry | Effective date | Debit | Credit |
|---|---|---|---|
| E2-inverse (`reversesId = E2`) | D0 | daily 22,000 + cashbox 10,000 | expense 32,000 |
| E3 (`correctedFromJournalId = E2`) | D0 | expense 30,000 | daily 20,000 + cashbox 10,000 |

Undo changes expense −2,000, daily cash +2,000 and cashbox 0 relative to the edited state. Never reverse E1-inverse: the mapper and portable validator reject inverse-of-inverse. Undoing deletion instead creates a new replacement posting/source version linked to the deleted original; it does not remove the inverse or revive an old receipt. Undoing a date shift compensates current active target-date postings and reposts at former dates after validating the complete restored candidate.

The frozen undo stack is session-local, capped at 30 and reset on load/import or sales/return change. **Restart does not promise a new durable undo UI/history stack.** Persisting a recoverable undo stack would be a separate behavioral change, not implied by 4A. Durable correction lineage and operation receipts must survive restart regardless of whether the session stack does.

An undo target is the previous source snapshot for the current accepted state. Preserve correction history exactly as `preserveCorrectionTrail` does: restoring a manual balance from 100 to 80 retains the original 80→100 event and appends 100→80 with the frozen source undo reason. Manual totals/balances are source observations, not a newly authorized capital/profit journal. If compensation cannot be reconciled for any affected financial component, refuse the complete undo and keep the stack intact.

On definite save failure, preserve current state, form/candidate and undo position. On confirmed success, pop once. On unknown acknowledgement, resolve the original operation before retry/undo; use the same operation ID and canonical intent so the coordinator can replay instead of applying a second compensation. A user changing intent submits a new operation ID after the unresolved intent is settled. No source snapshot can overwrite newer intervening committed operations; stale source/fence/lineage requires re-evaluation, not forced restore.

## E. Legacy/pre-cutover records without an original journal

Existing 2A establishes a cutover opening instead of reconstructing every historical posting. Legacy schema1..11 enrollment preserves history but creates **zero journals and receipts**, with cutover gated. Neither mapper inverses nor portable links authorize inventing a missing original.

Concrete unresolved case: a pre-cutover payment is 20,000 and was included in verification of a hypothetical opening supplier liability of 7,500. The owner later corrects it to 18,000. Source supplier balance would increase by 2,000 and historical daily-funded spending may decrease. There is no original journal to inverse. Silently changing the opening liability/cash would revise the cutover basis; leaving the opening unchanged while permitting later settlement could disconnect financial and source states. This packet does not select either outcome.

| Concrete path for review | Benefit | Risk / boundary |
|---|---|---|
| Keep financial source corrections blocked until a verified exception is accepted | Preserves existing opening and prevents unsupported postings. Read/export/history access continues. | Historical error remains visible until resolved. This is the current fail-closed candidate boundary, not a final rejection of all future corrections. |
| Historical correction plus explicitly reverified opening revision | Can align corrected historical source with a changed cutover basis. | Requires exact old/new source effects, opening verification, counterparty/cash reconciliation and immutable opening-correction history. Actual amounts/date/counterparts and review remain required. No automatic opening adjustment is authorized. |
| Reconstruct the affected historical posting chain before correcting | Could supply a valid original and traceable inverse/replacement. | Risks double-counting the opening and contradicting 2A if backfill is mixed into the active ledger without an explicit historical-vs-opening treatment. Requires a separately accepted bounded migration policy; not an implementation choice under 4A. |

The same boundary applies to a legacy expense edit/delete, undo restoring a pre-cutover source, or a day shift crossing the cutover boundary. Date-shifting the hypothetical payment from before cutover to after cutover cannot silently create active settlement for an opening that already incorporates it. Pure source metadata/quantity changes with no financial effect may be technically separable, but must prove no affected cash/debt/posted-history effect before execution; “metadata” is not a label that bypasses reconciliation.

**Owner choice still needed:** accepted worked treatment for an actual class of missing-posting/cross-cutover correction, if that class must become executable. Opening values/date remain a distinct later live gate. The original-date direction for eligible existing postings is already settled.

## F. F-04 complete-state, operation and compatibility contract for review

The following implements accepted 4A semantics at the contract level. The Lead can choose field/container details; no new accounting choice is implied.

1. Account lineage, source ID/version/snapshot, immutable journal IDs, correction ID, reason, effective/recorded dates, original/inverse/replacement links, operation ID, payload version/identity and outcome must travel together in version12 complete state. Exact financial metadata uses decimal strings where JSON-safe integer bounds would be exceeded. Preserve prior IDs and source provenance. Storage fence is store authority; it is not account lineage.
2. An expense/payment edit/delete or range correction is one complete candidate plus one durable operation outcome/receipt through the existing single owner. Attach source before/after intent and links in app-owned representation; do not add a second journal database or duplicate coordinator. Original source records can disappear from the current schema11 projection while their historical snapshots remain in the complete envelope. No existing `voidedAt` source field is assumed.
3. A correction applies only to the exact expected active source version/posting. Verify source amount, date, funding, category, supplier/invoice/allocations, immutable snapshots and journal lines before replay as well as proposal. An equal amount with different funding/category/note is changed intent, not proof of equivalence. Use receipt sequence for durable operation order; recorded timestamps are retained facts, not trusted ordering authority.
4. Preserve original journals byte-equivalently in value and preserve receipt history. Link newly appended entries without changing prior entries. One inverse per original, no inverse-of-inverse, no missing/cyclic correction targets, no dangling replacement, valid IQD policy/totals and contiguous unique receipt operations remain enforced by the current portable validator. Generic validation does **not** prove family-specific source reconciliation; new correction commands still need it.
5. Same operation ID + same intent + valid matching lineage/fence/history replays its stored historical outcome without new journal/source/revision. Same ID + changed payload/version rejects without writes. New operation ID against stale or already corrected source fails eligibility. Replaying a valid old outcome after later compensation must validate the retained historical snapshot, not require its source version to remain current.
6. Definite precommit failure leaves the complete durable state unchanged. Unknown acknowledgement is resolved by Madar pending-write/receipt lookup; replay resumes the same intent. Restore/replacement authority fences invalidate captured commands. A source swap with the same fence must still fail account-lineage or receipt/source reconciliation. Existing atomicity evidence is not proof that these unimplemented correction families already satisfy the contract.

### Concrete restart/reimport matrix

| Input / action | Required outcome and evidence still needed |
|---|---|
| Restart after accepted correction | Read all old/new source history, journals, links, lineage, receipts and original outcome. Replay same operation once; no new revision. Existing codec/coordinator foundation is evidence; each correction family needs real-store conformance. |
| Import/export version12, same complete account | Preserve account lineage, IDs, source/journal/correction metadata and receipts exactly. Do not turn imported operations into new postings. Generic structural roundtrip passed here; file import/activation path remains unimplemented. |
| Reimport the same backup into the same account | Treat replacement/restore as one explicit complete-state operation with store authority transition where required. Do not append duplicate receipts/journals or merge repeated history blindly. Preserve portable historical receipt fences as provenance; newly captured commands use the new active fence. |
| Older complete backup restored after newer operations | This is rollback of the whole account, not command replay or selective merge. Preserve the displaced current complete state/backup before authorized replacement. Commands from the displaced fence cannot resume. No implicit merge or “latest timestamp wins.” Exact restore UX and authorization remain separate integration gates. |
| Legacy schema1..11 import | Validate/migrate with existing legacy codec; preserve source-version/enrollment provenance; require caller-owned lineage and gated cutover; synthesize no journal or receipt. Never overwrite an existing active version12 account with source-only legacy input or silently erase its history. |
| Legacy import into an already established account lineage | Require an explicit supported replacement/re-enrollment path; no inferred identity by filename, no receipt reset disguised as continuation. Block until that compatibility path and backup/restore safeguards are implemented. This follows 4A preservation, not a new financial policy. |
| Future/unknown schema or durable field, corrupt inverse/total/link/receipt | Fail closed with stable errors and retain the existing account unchanged. Do not normalize unknown state away. Current portable decoder rejects these classes; import integration must propagate the failure. |
| Open version12 with old runtime | Existing legacy reader returns `unsupported_version`; it cannot downgrade. Rollback uses a verified compatible pre-upgrade backup, never a stripped source-only export that discards new durable state. |
| Independent copy to a genuinely different account lineage | Do not relabel imported operation history as belonging to a different account. Fork/merge identity policy is outside this offline single-restaurant scope; fail closed if lineage identity is ambiguous. |

The receipt/source probes here do not establish OS crash/power-loss safety, live migration, backup retention, native UI behavior, export encryption or release readiness.

## Review disposition requested

| Item | Current disposition |
|---|---|
| 3A/2A/4A direction; existing symbolic accounts | Already accepted. No repeat approval requested. |
| A–D source-parity examples, inverse/replacement outcomes and rejection/retry cases | Prepared for independent source/policy review, then owner acceptance of the remaining worked examples required by F-03. No implementation approval is inferred. |
| F complete-state/identity/compatibility rules | Proposed contract completing the example set for F-04; Lead may refine technical representation under accepted 4A. Runtime import/undo/correction commands still require implementation and tests. |
| E missing-posting/cross-cutover financial cases | Explicit unresolved policy boundary. No automatic backfill/opening adjustment chosen. |
| Actual cutover date/opening values, financial activation, UI, phase closure, merge/release | Unchanged separate gates. |

F-03/F-04 remain open. A complete row cannot be closed by balanced examples or a standalone codec pass alone. Independent review should challenge source parity, the pre-cutover boundary and the compatibility matrix without treating an unchanged accepted direction as a new policy question.
