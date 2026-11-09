# Completion Financial Review Packet (F-01–F-04)

Owner outcome, 2026-11-07: **recommended conceptual policy package accepted**. [ADR0021](../decisions/0021-completion-financial-policy.md) records1A-P/R1/T1/2A/3A and4Acomplete-portable-state semantics with the stated verification/migration/design/merge/release limits. The packet below preserves alternatives and review context; its older awaiting-decision wording is historical. Actual cutover date/opening amounts and pre-cutover correction examples remain pending.

Status: Concrete Review Packet for Owner Decision. Prepared by research sub-agent; no runtime code, pin, or financial account writes performed. Cross-links Madar generic contracts without duplicating shared authority.

Parent review, 2026-11-07: corrected unsupported safety/compatibility claims, historical-debt clearing assumptions, UUID wording and source descriptions. Independent Gemini review found five bounded gaps; the parent addressed them below. **Proposed; awaiting owner decisions. No F-01–F-04 acceptance or implementation follows from the recommendations.** Account names, new IDs/fields/schema and journal mappings remain proposed. Exact money bounds come from the consumer codec/profile; generic Madar contracts take explicit caller policies.

- **Scope Gates Addressed**: F-01 (Account Classifications), F-02 (Cutover vs. Historical Reconstruction), F-03 (Immutable Correction Mappings), F-04 (Correction Identity, Dates, Export & Schema Compatibility).
- **Consuming Plan Reference**: [completion-unfinished-implementation-plan.md](completion-unfinished-implementation-plan.md) (Items F-01–F-04, C3-04/06, C4-05/08/09/10/14/17, C5-04/12, C6-14/17, C9-07).
- **Shared Engine Authority**: Madar generic balanced journal contract at [Madar completion-journal-contract.md](../../../Madar_Engine/docs/reference/completion-journal-contract.md) and [`BalancedJournal`](../../../Madar_Engine/packages/domain/lib/src/journal.dart).

---

## 1. Baseline Authority & Existing Approved Policy (No Re-Questioning)

The following boundaries are fixed by existing approved architecture decisions and frozen restaurant behavior. They are preserved intact and require no re-confirmation:

1. **Monetary Unit & Precision**: Currency is strictly Iraqi Dinar (`IQD`), integer scale (`0`), bounded by magnitude $10^{12}$ (`CommercePolicy`, `FIN-04`). Floats are prohibited.
2. **Single-Restaurant Offline Model**: No multi-tenant cloud, no user authentication, no external banking APIs, no remote sync dependencies (`ADR 0001`, `ADR 0018`).
3. **Arabic RTL & Single Daily Register**: Interface and receipt outputs remain Arabic RTL. Daily cash is tracked per business date (`DateOnly`).
4. **No Tax, Costing, or Profit Invention**: The restaurant does not track VAT/sales tax, does not compute recipe consumption or raw material COGS at checkout, and does not equate remaining cash to profit (`FIN-07`, `accounting-rules.md`).
5. **Funding Allocation Hierarchy**: Expenses and supplier payments can be funded from daily cash, cashbox, or split between both. Cashbox-funded expenses never enter the daily cash register expense total (`accounting-rules.md`, `daily_cash_queries.dart`).
6. **Supplier Debt & Payment Allocation**: Invoices establish debt only. Paid spending occurs only upon payment. Payment allocation settles the selected invoice first, then eligible prior debt; excess cannot pay unrelated invoices or future debts (`C6-10`, `accounting-rules.md`).
7. **Carton & Piece Pricing**: Materials store carton and piece quantities with independent unit prices; no carton-to-piece conversion factor is assumed (`accounting-rules.md`).
8. **Returns & Voids Invariants**: Returns decrease net daily collections on the return date and do not deduct from cashbox or expenses. Restocking to inventory is optional on return date. Voids reverse stock and sales on original sale date; voids are rejected if any partial return exists (`ADR 0010`, `C3-04–C3-06`).
9. **Immutable Financial Records**: In accordance with `FIN-02`, posted financial records cannot be overwritten; corrections are executed via linked reversal and replacement records (`completion-journal-contract.md`).

---

## 2. F-01: Account Classifications & Worked Operational Scenarios

### 2.1 Chart of Accounts Hierarchy

To map user-facing restaurant workflows to a double-entry ledger (`FIN-01`) without violating the single-restaurant offline scope, the following symbolic account classification structure is proposed:

| Account ID Pattern | Classification | Purpose / Role | Normal Balance |
| :--- | :--- | :--- | :--- |
| `asset:cash:daily` | Asset | Physical drawer / daily register cash | Debit |
| `asset:cash:cashbox` | Asset | Restaurant safe / secondary cash reserve | Debit |
| `liability:supplier:<id>` | Liability | Outstanding accounts payable to named supplier | Credit |
| `<approved_invoice_counteraccount>` | Owner-approved classification pending | Debit counterpart for supplier invoice liability; classification must not imply inventory valuation or profit | Depends on approved classification |
| `revenue:sales` | Revenue | Net ticket sales after saved discount in this proposed journal mapping; gross/discount remain saved source facts | Credit |
| `contra_revenue:sales_return` | Contra-Revenue | Customer refunds on returned tickets | Debit |
| `expense:category:<id>` | Expense | Operating expenses grouped by category ID (e.g. samoon, bread, market, rent) | Debit |
| `equity:opening_balance` | Equity, proposed | Explicit, verified cutover residual; not an invented historical amount | Debit or credit according to verified balances |

### 2.2 Worked Operational Scenarios

Each scenario details:
- **Source Visible Effect**: What the cashier sees in the register, cashbox, and reports.
- **Underlying Stock / Quantity Effect**: Physical units movement.
- **Candidate Balanced Journal**: Debit/Credit lines satisfying `BalancedJournal.validate()`.

#### Scenario 1: Sale with Discount
- **Source Input**: Sale ticket of 2 items: 1x Beef Kebab (10,000 IQD), 1x Drink (3,000 IQD), manual discount of 1,000 IQD. Net customer cash received = 12,000 IQD.
- **Source Visible Effect**: Daily net sales increases by +12,000 IQD. Daily cash on hand increases by +12,000 IQD.
- **Stock Effect**: 1 unit Beef Kebab and 1 unit Drink deducted from tracked inventory.
- **Balanced Journal**:
  ```text
  ID: jnl_sale_20261101_001
  Effective Date: 2026-11-01
  Policy: IQD, scale 0
  Lines:
    Debit  asset:cash:daily    12,000 IQD
    Credit revenue:sales       12,000 IQD
  Total Units: 12,000 IQD (Balanced)
  ```
  Net revenue here is a proposed ledger mapping. The source sale retains gross lines, saved discount and net separately. This does not introduce a profit report or choose an account classification without F-01 acceptance.

#### Scenario 2: Shared Operating Expense
- **Source Input**: Operating expense of 30,000 IQD for fresh vegetables (`category:market`), funded 20,000 IQD from daily cash drawer and 10,000 IQD from cashbox.
- **Source Visible Effect**: Daily spending increases by +20,000 IQD. Cashbox balance decreases by -10,000 IQD. Paid spending statement shows 1 expense of 30,000 IQD.
- **Stock Effect**: None (operating expense).
- **Balanced Journal**:
  ```text
  ID: jnl_exp_20261101_002
  Effective Date: 2026-11-01
  Policy: IQD, scale 0
  Lines:
    Debit  expense:category:market  30,000 IQD
    Credit asset:cash:daily         20,000 IQD
    Credit asset:cash:cashbox       10,000 IQD
  Total Units: 30,000 IQD (Balanced)
  ```

#### Scenario 3: Supplier Purchase Invoice
- **Source Input**: Invoice from Supplier `SUP-1` for 2 cartons oil @ 40,000 IQD = 80,000 IQD + 3 pieces sauce @ 2,500 IQD = 7,500 IQD. Total = 87,500 IQD.
- **Source Visible Effect**: No cash disbursed. Paid spending statement shows 0 IQD. Supplier `SUP-1` debt balance increases by +87,500 IQD.
- **Stock Effect**: Saved invoice lines retain the two carton and three piece quantities for purchase analysis. The material catalog holds identities/defaults; this proposal adds no material-stock ledger or sellable-stock conversion.
- **Candidate Balanced Journal (counteraccount still requires approval)**:
  ```text
  ID: jnl_inv_20261101_003
  Effective Date: 2026-11-01
  Policy: IQD, scale 0
  Lines:
    Debit  <approved_invoice_counteraccount> 87,500 IQD
    Credit liability:supplier:SUP-1      87,500 IQD
  Total Units: 87,500 IQD (Balanced)
  ```

#### Scenario 4: Supplier Payment with Split Funding
- **Source Input**: Separate allocation fixture: selected Invoice `INV-1` has only 12,500 IQD remaining and eligible older debt is at least 7,500 IQD on payment date. A 20,000 IQD payment allocates 12,500/7,500, funded 15,000 daily and 5,000 cashbox. Do not assume the separate 87,500 unpaid-invoice example has only 12,500 remaining without explicit prior payments.
- **Source Visible Effect**: Supplier `SUP-1` balance decreases by -20,000 IQD. Daily spending increases by +15,000 IQD. Cashbox balance decreases by -5,000 IQD. Paid spending statement shows 1 payment entry of 20,000 IQD.
- **Stock Effect**: None.
- **Balanced Journal**:
  ```text
  ID: jnl_pay_20261101_004
  Effective Date: 2026-11-01
  Policy: IQD, scale 0
  Lines:
    Debit  liability:supplier:SUP-1  20,000 IQD
    Credit asset:cash:daily          15,000 IQD
    Credit asset:cash:cashbox         5,000 IQD
  Total Units: 20,000 IQD (Balanced)
  ```
  Paid spending remains the validated source-record query and counts this payment once. No automatic second expense journal is selected. If F-01 selects a clearing-to-expense model, the exact supported clearing amount must distinguish invoice settlement from historical/opening-debt settlement and have matching verified balances; clearing the entire20,000 without that contract is invalid.

#### Scenario 5: Customer Sales Return (Refund)
- **Source Input**: Independent refund fixture: `SAL-1` has an eligible tracked saved line whose original net/cumulative allocation permits a1,000 IQD return of1unit. This is not an assumed1,000 refund of the discounted12,000 ticket in Scenario1. Item restocks by explicit selection.
- **Source Visible Effect**: Daily net sales decreases by -1,000 IQD on return date. Cash drawer cash decreases by -1,000 IQD. (Not an expense; no cashbox effect).
- **Stock Effect**: +1 unit restocked to tracked inventory on return date.
- **Balanced Journal**:
  ```text
  ID: jnl_ret_20261102_005
  Effective Date: 2026-11-02
  Policy: IQD, scale 0
  Lines:
    Debit  contra_revenue:sales_return  1,000 IQD
    Credit asset:cash:daily             1,000 IQD
  Total Units: 1,000 IQD (Balanced)
  ```

#### Scenario 6: Daily Register to Cashbox Transfer
- **Source Input**: Transfer of 20,000 IQD from remaining daily drawer cash to cashbox.
- **Source Visible Effect**: Daily drawer remaining cash decreases by -20,000 IQD. Cashbox balance increases by +20,000 IQD. Overall recorded balance remains unchanged.
- **Stock Effect**: None.
- **Balanced Journal**:
  ```text
  ID: jnl_xfer_20261102_006
  Effective Date: 2026-11-02
  Policy: IQD, scale 0
  Lines:
    Debit  asset:cash:cashbox  20,000 IQD
    Credit asset:cash:daily    20,000 IQD
  Total Units: 20,000 IQD (Balanced)
  ```

---

## 3. F-02: Historical Reconstruction vs. Cutover & Opening Balances

The restaurant application holds historical records across Schemas 1–11. A critical architectural choice governs how historical records meet the double-entry ledger.

### 3.1 Comparison of Alternatives

| Dimension | Alternative A: Historical Reconstruction (Backfill) | Alternative B: Explicit Cutover with Opening Balances (Recommended) |
| :--- | :--- | :--- |
| **Mechanics** | Synthesize balanced journals retrospectively for every historic sale, expense, payment, and transfer since Day 1. | Keep pre-cutover records authoritative in source format; post an explicit verified opening balance journal at cutover date; enforce double-entry only from cutover date onward. |
| **Audit provenance** | Can derive journals only where source and accepted mapping establish exact effects; label derivation and preserve provenance. Missing evidence remains unresolved, not filled with invented amounts. | Preserve source history and establish explicitly verified opening balances, cutover coverage and reconciliation. Do not infer those values from an incomplete register. |
| **Historical gaps** | Must define treatment of manual overrides, absent cash counts and legacy fields; do not reinterpret saved totals as revenue/equity. | Must define verified balances, opening liabilities/counteraccounts and later corrections of pre-cutover records; cutover alone does not resolve them. |
| **Storage and performance** | More derived rows than cutover; volume/cost depends on actual data and needs measurement. | Usually fewer initial journals, but source history and operation/correction receipts still require retention. No measured advantage is claimed. |
| **Rollback and portability** | Needs a versioned migration/export and rehearsed compatible rollback with source history retained. | Also needs versioned export and verified pre-upgrade backup. Older schema11 readers cannot be assumed to accept a schema12 document. |

### 3.2 Candidate Opening Balance Journal Specification (Alternative B)

At cutover date $T_{\text{cutover}}$, an opening journal is generated from verified balances:
```text
ID: jnl_opening_cutover
Effective Date: <Cutover Date>
Policy: IQD, scale 0
Lines:
  Debit   asset:cash:daily              <Verified Physical Register Cash>
  Debit   asset:cash:cashbox            <Verified Cashbox Safe Balance>
  Credit  liability:supplier:<SUP-1>    <Verified Outstanding Debt SUP-1>
  Credit  liability:supplier:<SUP-N>    <Verified Outstanding Debt SUP-N>
  Debit/Credit equity:opening_balance   <Verified residual; side depends on totals>
Total Units: Debit Total == Credit Total (Balanced)
```

This is a structural example, not permission to create balancing values. Signed/negative source balances require explicit orientation rules; never pass a negative line amount to BalancedJournal. Verify each opening amount and its source, agree outstanding-liability counterparts, define corrections crossing cutover and preserve the pre-migration backup before activation. No actual cutover date or balance is chosen here.

Proposed signed-balance orientation: positive verified opening daily/cashbox book balance produces a debit to that asset; a negative verified book balance produces a credit of its absolute value to the same asset. Zero needs no amount line. A negative calculated register balance is not negative physical banknotes and must not be silently relabeled as a physical count. Do not invent an overdraft account or accept an unverified snapshot as an opening amount. Compute the signed residual only from accepted verified lines; a positive credit residual credits opening equity, a negative residual debits it by absolute value. All journal line amounts remain nonnegative. Cross-cutover corrections must link retained source history to the accepted opening treatment without replaying missing historical journals; policy remains pending until that mapping is accepted.

---

## 4. F-03: Immutable Correction Mappings & Undo Scenarios

FIN-02 requires immutable posted history. The following source-version/soft-delete representation is a proposed mapping, not an existing schema capability or accepted policy. Preserve existing visible edit/delete/undo outcomes through the agreed correction contract.

### 4.1 Correction Rules
1. **Expense Edit**: Commits an atomic pair:
   - Reversal Journal: exactly swaps original Debits and Credits, setting `reversesId = original.id` and `reason = "<Correction Reason>"`.
   - Replacement Journal: posts new lines with a new unique ID. A proposed app-owned command/document envelope links it through `correctedFromId = original.id`; this is not a field on current shared BalancedJournal. Madar's current value exposes `reversesId` and `reason` for inverses. Any shared-contract field extension requires separate review.
2. **Expense / Payment Delete**: Commits an atomic Reversal Journal (`reversesId = original.id`), and marks the source entity soft-deleted/voided with `voidedAt` and `voidReason`.
3. **Session Undo**: Under `FIN-02`, Undo is implemented as an automated inverse operation. It issues a reversal journal (`reversesId = target.id`, `reason = "Session Undo"`), restoring visible state without erasing history or reusing IDs.
4. **Rejection Safety**: If validation fails (e.g. invalid date, orphan reference or allocation underflow), abort with zero writes. Preserve source-permitted negative cash/cashbox states; do not invent a negative-cash prohibition. Historical stock nonnegativity remains its separate source rule.

### 4.2 Worked Correction Scenarios

#### Scenario 7: Expense Edit (Amount Shift)
- **Initial State**: Expense #E1 (30,000 IQD: 20,000 daily, 10,000 cashbox) recorded under `jnl_exp_001`.
- **Edit Action**: Cashier corrects amount to 32,000 IQD (22,000 daily, 10,000 cashbox).
- **Atomic Commits**:
  1. Reversal Journal `jnl_rev_001`:
     ```text
     Debit  asset:cash:daily         20,000 IQD
     Debit  asset:cash:cashbox       10,000 IQD
     Credit expense:category:market  30,000 IQD
     reversesId: jnl_exp_001, reason: "Corrected amount to 32,000 IQD"
     ```
  2. Replacement Journal `jnl_exp_002`:
     ```text
     Debit  expense:category:market  32,000 IQD
     Credit asset:cash:daily         22,000 IQD
     Credit asset:cash:cashbox       10,000 IQD
     proposed app envelope correctedFromId: jnl_exp_001
     ```
- **Net Visible Result**: Daily spent increases by +2,000 IQD; cashbox unchanged; expense updated to 32,000 IQD.

#### Scenario 8: Supplier Payment Deletion with Active Allocation
- **Initial State**: Payment of 20,000 IQD settled Invoice `INV-1` (12,500 IQD) and Debt (7,500 IQD).
- **Action**: Cashier deletes payment.
- **Pre-check**: In this fixture no later dependent correction or allocation exists. Actual commands must verify current references/coverage and accepted correction eligibility; this example is not a general deletion permission.
- **Commit**:
  1. Reversal Journal `jnl_rev_pay_001`:
     ```text
     Debit  asset:cash:daily          15,000 IQD
     Debit  asset:cash:cashbox         5,000 IQD
     Credit liability:supplier:SUP-1  20,000 IQD
     reversesId: jnl_pay_001, reason: "Payment entered in error"
     ```
  2. Source payment marked deleted; Invoice `INV-1` balance due restored to 12,500 IQD; eligible debt restored by 7,500 IQD.

If F-01 later adds settlement-related recognition journals, their linked reversal belongs in this same atomic correction. Undo of a corrected operation must restore the whole accepted source/journal/allocation/funding state; reversing one line/journal is insufficient by itself.

#### Scenario 9: Day Date-Shift
- **Initial State**: Expenses recorded on `2026-11-01` are shifted to `2026-11-02` due to cashier calendar misconfiguration.
- **Commit**:
  1. Reversal Journal effective on `2026-11-01` (zeroing out the incorrect date).
  2. Replacement Journal effective on `2026-11-02` (establishing balance on the true date).
  Source date correction also needs the agreed day metadata/remaining/manual-total/correction history and linked transfer handling, optional following-day preview, collision rejection and atomicity. Supplier invoice/debt, sale and inventory dates stay independent. This is no day-close/locking feature. Journals alone cannot prove register reconciliation.

---

## 5. F-04: Correction Identity, Dates, Export & Schema Compatibility

### 5.1 Identity & Date Semantics
- **Operation Identity (proposed)**: Generate one stable operation ID before first submission and retain it through retries/restart. UUID v4 is one random-ID candidate, not deterministic. A versioned canonical payload digest is another engineering proposal; its serialization, collision assumptions, persisted scope/retention and stable error codes need reviewed contracts. Same ID+same payload returns its durable saved outcome; changed payload under the same ID rejects. Storage write tokens alone do not establish indefinite business idempotency.
- **Journal Identity (proposed)**: Unique stable string ID scoped to the account lineage. Reversals retain their own ID and original link. Select one replacement-link name and version its serialized meaning. Define eligible inverse-of-inverse, duplicate reversal and pre-cutover correction behavior; generic reversed() does not enforce them.
- **Envelope ownership**: `correctedFromId`, source versions, void metadata and durable command outcomes belong to the proposed app document/command mapping over reviewed Madar contracts; do not pretend these fields exist in BalancedJournal. Shared persistence/retry invariants remain Madar-owned, with one adapter committing the complete opaque state.
- **Effective Date vs. Recorded Timestamp**:
  - `effectiveDate` (`DateOnly`, e.g. `2026-11-01`): The accounting date governing daily register totals and financial period statements.
  - `recordedAt` (proposed ISO8601 UTC field): A recorded timestamp under an explicit capture/retry contract. A device wall clock is not proof of physical durable-commit time or total ordering. Effective business date stays distinct.

### 5.2 Schema Versioning & Export Compatibility
- **Current Canonical Schema**: Schema 11 (`AccountDocument`, `LegacyAccountCodec`).
- **Proposed Evolution**:
  - **Schema12 candidate, not selected**: Versioned portable representation must preserve source data, journals, immutable correction links, accepted cutover metadata and durable operation identities/outcomes needed to prevent replay after restart/import/restore. Adding only an optional journals list is not a complete durable-command protocol. Define account-lineage scoping, validation/bounds and recovery states before encoding it.
  - **Codec Forward/Backward Compatibility**:
    - A changed codec must retain supported schema1–11 reading and record-preserving migration; current source implements canonical schema11 only. Future schemas stay protected. A schema11-era installation must reject schema12 rather than silently discard journals/identities.
    - Exporting account data to a portable `.json` backup retains all source subledger tables plus the journal ledger.
    - Reimport must validate source/journal/correction/operation consistency and reject malformed/future/partial records unchanged. Demonstrate round trips,20MiB limits, duplicate replay protection, stale-workspace fences and pre-import backup with actual tests. No such result exists from this packet.

---

## 6. Genuinely Unresolved Decisions for Owner Resolution

To avoid asking redundant questions, previously approved policies (Section 1) are treated as settled. Only the following four architectural decisions require explicit owner determination:

### Decision Gate 1 (F-01): Purchase Invoice Ledger Recognition
- **Context**: In the restaurant, unpaid invoices create supplier debt immediately, but paid spending is recognized only upon cash payment.
- **Alternatives**:
  - **Option1A (include invoice liabilities, recommended contract direction)**: Journal invoice debit counterpart and supplier liability at invoice date, and settle liability against daily/cashbox funding at payment date. Owner must accept the invoice counterpart's classification and how invoice-derived versus opening/historical debt settlements map. Paid spending remains a source-record query counting the payment once; it does not require an automatic additional expense journal.
    - *Consequence*: Shared financial/source/liability reconciliation can include invoices. A clearing variant is possible only with complete matching balances and reversal rules; clearing all historical-debt payments without that evidence is prohibited.
    - **1A-P (purchase expense at invoice date; recommended for the internal ledger)**: For87,500, debit `expense:purchases`87,500 and credit supplier liability87,500. Settlement debits liability and credits funded cash only. Do not also insert the invoice into the app's paid-expense list or post another purchase expense when paying. Internal accrual purchase-expense totals differ from the paid-spending screen, which continues to show only actual paid expense/payment records. This adds no costing, stock valuation or profit report.
    - **1A-C (purchase clearing until invoice settlement)**: For87,500, debit `clearing:purchases`87,500 and credit liability87,500. Invoice settlement of12,500 also debits the agreed expense and credits clearing12,500, in the same accepted complete operation. Do not clear the7,500 historical/opening-debt portion without a matching verified clearing balance and agreed history treatment. Paid spending can remain20,000 even when current-period ledger recognition differs. This option needs more opening/correction rules and is not selected by this packet.
  - **Option1B (omit invoice journals)**: Keep liabilities only in supplier subledger and journal cash payments.
    - *Consequence*: This changes the currently planned F-01/F-09 reconciliation scope and needs an explicit authority exception before dependent code; it is not an equivalent implementation of the existing plan.
- **Recommendation**:1A-P, with explicit owner acceptance that internal purchase-expense recognition and the paid-spending register have different meanings. Preserve source liabilities and never infer profit from either.

#### F-01 sales and refund subchoices

- **Revenue R1 (recommended)**: Debit cash12,000, credit net `revenue:sales`12,000 for13,000 gross less1,000 discount. Keep saved gross/discount/net fields; this recommendation chooses no new visible charge.
- **Revenue R2**: Debit cash12,000 and `contra_revenue:discount`1,000, credit gross revenue13,000. Same cash/source net; more explicit ledger classification.
- **Refund T1 (recommended)**: Debit `contra_revenue:sales_return`1,000 and credit daily cash1,000 on return date; keep original sale intact.
- **Refund T2**: Debit `revenue:sales`1,000 and credit daily cash1,000 on return date. Same source cash outcome, different ledger account classification.

Owner acceptance of F-01 must name the selected purchase, revenue and refund alternatives; adopting an isolated example must not silently select the others.

### Decision Gate 2 (F-02): Cutover vs. Historical Backfill
- **Context**: Historical data from Schemas 1–11 exists without double-entry journal metadata.
- **Alternatives**:
  - **Option 2A (Explicit Cutover with Opening Balances - Recommended)**: Freeze historical data as authoritative subledger records; establish an explicit cutover date with an opening balanced journal based on verified physical cash and supplier debt.
    - *Consequence*: Avoids fabricating full historical journal coverage, but requires verified opening amounts/counterparts, agreed cross-cutover corrections, migration/restore tests and a compatible backup. It guarantees no safety percentage.
  - **Option 2B (Retrospective Historical Backfill)**: Generate synthetic balanced journals for all historic sales, expenses, and payments back to Day 1.
    - *Consequence*: Requires evidence-complete mappings and a treatment for gaps; derive only provable amounts with provenance. Neither reconstructing nor cutover authorizes invented balancing entries.
- **Recommendation**: **Option 2A**.

### Decision Gate 3 (F-03): Reversal Effective Date for Historical Corrections
- **Context**: When an earlier posted entry is edited or deleted, what business date should its reversing journal bear?
- **Alternatives**:
  - **Option 3A (Original-Date Reversal - Recommended)**: Reversal journal is dated on the original entry's `effectiveDate`.
    - *Consequence*: Retains frozen source effective-date correction outcomes when implemented with the full accepted source/snapshot/transfer contract. Already-fixed sale-void and inventory-reversal dates are not reopened by this choice.
  - **Option 3B (Correction-Date Reversal)**: Reversal journal is dated on today's `effectiveDate`.
    - *Consequence*: Changes source historical daily-register outcomes; requires explicit business-scope approval rather than being silently substituted. No general claim about corporate-accounting standards is made here.
    - If source history still changes on its original date but journal reversal uses today, historical daily register and journals no longer reconcile1:1. This needs an explicit dual-period reconciliation/reporting contract for F-09, or a changed source behavior. Neither exists in the current plan. Recommend3A to retain source date semantics.
- **Recommendation**: **Option 3A**.

### Decision Gate 4 (F-04): Storage & Document Schema Strategy for Journals
- **Context**: Storing immutable double-entry journals alongside portable account documents.
- **Alternatives**:
  - **Option4A (versioned unified portable account, recommended engineering candidate)**: Encode the full validated source/journal/correction/operation state in a new version under one persistence owner. Schema12 is a candidate version, not an implemented guarantee.
    - *Consequence*: Portable backup can contain required state together; older readers reject the new version, so rollback needs a verified compatible pre-upgrade backup. Validate size limits and replay behavior before adoption.
  - **Option4B (normalized local ledger with complete portable export)**: A reviewed Madar data adapter may keep local financial/operation tables while the app exports a new complete versioned envelope atomically with source state.
    - *Consequence*: Local table separation alone does not require two exported files or losing ledger data, but adds transaction/migration ownership work. A bare schema11 export that drops journals/identities does not satisfy this plan.
- **Recommendation**: Review the smallest compatible unified-state candidate after identity/date/export/cross-cutover policy acceptance. The Lead can choose representation details within accepted semantics; the owner need not choose a database layout to approve business outcomes.

Single persistence owner: app AccountsRepository validates/maps the app schema through Madar's LocalDocumentWorkspaceStore; the selected Madar data adapter owns durable commit/activation/fence/recovery behavior. AccountsRepository is not an independent SQL/file writer. Future source/journal/operation changes must commit through this same reviewed owner or a reviewed compatible extension, never two competing stores. Technical representation may be chosen by the Lead within accepted business/portability semantics; a version change requires preservation tests, review and exact engine adoption before execution.

## Owner decision summary

Proposed default package: **1A-P + R1 + T1** for internal postings; **2A** for explicit cutover with verified openings rather than fabricated history; **3A** for source-compatible original-date linked correction; and **4A's complete portable-state semantics** with Lead-owned reviewed representation. Preserve a compatible pre-upgrade backup; old readers reject the new version. Actual cutover balances/date and pre-cutover correction examples require explicit verification and acceptance before migration, even if the conceptual package is approved. This request approves no live migration, design revision, merge, release or unrun verification result.

---

## 7. Storage & Safety Summary
- This review packet is purely analytical and documentation-based.
- No runtime source files, dependencies, pins, or database records were modified.
- Independent reviewer judged the corrected packet provisionally suitable after the five adjustments now recorded. Parent applied those adjustments; this packet alone closes no gate. Conceptual owner approval permits dependent contract work within its stated limits, not F-05–F-10 completion or migration without verified backups.
