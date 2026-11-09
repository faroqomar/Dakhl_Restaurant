# Isolated durable spending commands

Status: repaired isolated candidate under ADR 0021; independent recheck pending. These APIs do not activate the version 12 envelope in the running app. They are not permission to migrate real accounts or select opening values/date. The accepted business policy is [ADR 0021](../decisions/0021-completion-financial-policy.md); the bounded scope is [the spending contract](../phases/completion-durable-spending-contract.md).

## Ownership and setup

Dakhl_Restaurant owns `JournalCommandHost`, `CreateOperatingExpenseCommand`, `CreatePurchaseInvoiceCommand`, `CreateSupplierPaymentCommand`, `RestaurantJournalSpendingCommandCoordinator`, `RestaurantJournalSpendingOutcome`, and the lineage-scoped journal codec adapter. Madar owns exact arithmetic, immutable `BalancedJournal` values, `DurableCommandCoordinator`, and the one `LocalDocumentWorkspaceStore` owner. Consume runtime `d316fd6076375daa3f412889f73eaebfeeb5d4d4`; no additional package is required.

Initialize an isolated store using the portable codec and verified synthetic opening journal before using this candidate. Normal `AccountsRepository`/bootstrap still reads schema 11 and has no migration/activation path to these commands. The executor neither creates an account nor chooses cutover data. It delegates read/recovery/CAS/write acknowledgements to Madar and rejects an injected coordinator or shared host bound to another store.

Capture `accountLineage` and `StorageFence` when forming an intent. The command values allow an omitted fence for pure proposal evaluation; executing one fails with `missing_authority_fence` before any store read. Do not acquire a fresh fence to retarget an old form after replacement. The host and codec check lineage before receipt replay and on every subsequent decode/extract/attach/encode.

## Examples using an already initialized synthetic store

### 1. Operating Expense

```dart
final coordinator = RestaurantJournalSpendingCommandCoordinator(store: fixtureStore);
final command = CreateOperatingExpenseCommand(
  operationId: callerOperationId,
  accountLineage: capturedLineage,
  expectedFence: capturedSnapshot.fence,
  expenseId: callerExpenseId,
  journalId: callerJournalId,
  date: DateOnly.parse('2026-01-10'),
  categoryId: 'samoon',
  amount: BigInt.from(15000),
  fundingSource: FundingSource.daily,
  note: 'Flour purchase',
  recordedAt: callerTimestamp,
);
final result = await coordinator.executeExpense(command);
```

### 2. Purchase Invoice with Atomic Immediate Payment

```dart
final command = CreatePurchaseInvoiceCommand(
  operationId: callerOperationId,
  accountLineage: capturedLineage,
  expectedFence: capturedSnapshot.fence,
  invoiceId: callerInvoiceId,
  invoiceJournalId: callerInvoiceJournalId,
  paymentJournalId: callerPaymentJournalId,
  supplierId: 'supp-1',
  invoiceNumber: 'INV-2026-001',
  date: DateOnly.parse('2026-01-10'),
  lines: [
    const PurchaseLine(
      materialIdForCreation: 'mat-flour',
      name: 'Flour',
      unit: 'bag',
      quantityCartons: 2,
      quantityPieces: 0,
      priceCarton: 20000,
      pricePiece: 0,
    ),
  ],
  immediatePayment: const PurchasePayment(
    id: callerPaymentId,
    amount: 25000,
    source: 'daily',
  ),
  recordedAt: callerTimestamp,
);
final result = await coordinator.executeInvoice(command);
```

### 3. Separate Supplier Payment

```dart
final command = CreateSupplierPaymentCommand(
  operationId: callerOperationId,
  accountLineage: capturedLineage,
  expectedFence: capturedSnapshot.fence,
  paymentId: callerPaymentId,
  journalId: callerJournalId,
  supplierId: 'supp-1',
  invoiceId: callerInvoiceId, // or null when paying verified historical debt
  date: DateOnly.parse('2026-01-11'),
  amount: BigInt.from(15000),
  fundingSource: FundingSource.daily,
  recordedAt: callerTimestamp,
);
final result = await coordinator.executePayment(command);
```

The caller owns IDs and time. New intents need new operation identities; retry the same frozen command after an uncertain acknowledgement. Handle `DurableCommandSuccess`, `DurableCommandReplayed`, and `DurableCommandFailure`. Success/replay includes the stored outcome and snapshot; failure is not permission to issue a replacement operation ID blindly when acknowledgement is uncertain.

## Accounting invariants and business rules

1. **Approved 1A-P Internal Invoice Expense/Liability Mapping**:
   - The invoice debits `expense:purchases` and credits `liability:supplier:<id>` at the invoice date.
   - Any payment (immediate or separate) debits `liability:supplier:<id>` and credits cash (`asset:cash:daily` or `asset:cash:cashbox`) on the payment date.
   - **No second expense is recognized on payment**.
2. **Paid Spending Visibility**:
   - Cash registers (`DailyCashQueries.statement()`) reflect only actual payment money outflows.
   - Unpaid invoices recognize internal expense and supplier liability, but create zero cash register rows and zero visible paid spending until actual payment is made.
3. **Materials and Quantities**:
   - Cartons and pieces are calculated independently (`cartons * priceCarton + pieces * pricePiece`).
   - No sellable stock, COGS, tax, or cloud inventory is invented; purchasing rules reuse `PurchaseProposals` and `CommerceCalculations`.
4. **Historical Debt Payments**:
   - Historical debt payment requires either an eligible post-cutover invoice liability or an explicitly verified opening liability in the cutover opening journal (`openingJournalId`).
   - The selected invoice settles first; excess may settle eligible verified supplier debt, as in the frozen source. Other invoices and future debt never supply the excess.
   - The verified opening already includes pre-cutover settlements. Only matching post-cutover payment postings consume it. All saved payments, including future-dated ones, reserve liability to prevent double settlement; raw manual debt without a recognized posting cannot enlarge this slice's verified opening capacity.
   - If the opening journal lacks a credit line for the supplier liability account or if the payment exceeds available verified debt, the command is strictly rejected with `unverified_historical_debt` or `payment_exceeds_liability`. Unverified historical debt is never invented or paid blindly.
5. **Cross-Cutover Safeguards**:
   - Paying a pre-cutover invoice without an eligible post-cutover journal is rejected (`cross_cutover_source_has_no_post_cutover_journal`).
   - Operations dated before the cutover date fail closed (`pre_cutover_operation_rejected`).

## Identity, outcomes and limits

Payload version defaults to 1. Identity contains deterministic sorted JSON of the captured command fields, including lineage, expected fence, IDs, time, policy, lines, funding split, and note. It contains private source data and must not be logged. Changing submitted intent or version under an existing operation ID fails `changed_payload_rejected`.

Invoice and payment raw IDs occupy separate source namespaces; journal IDs remain unique.

Input collections snapshot once using deep recursive unmodifiable wrappers (`freezeMap`, `freezeList`). Recursion depth is capped at 100 levels; cyclical structures are detected and rejected. Integers exceeding JavaScript `maximumSafeAggregate` (`9,007,199,254,740,991`) and non-finite floats are rejected.

Mapper `BigInt` metadata snapshots use explicit decimal strings in the portable envelope. Returned outcomes detach nested metadata and compare/hash their full canonical content. Their `toString()` representation redacts private financial payloads. Replayed outcomes reconcile against saved source records and journals before replay. Entry metadata and receipt outcomes retain a canonical source-record snapshot string, including resolved material/category identities, amounts, allocations, funding, note and timestamps. The invoice snapshot also binds its optional immediate payment. Canonical invoice numbers in outcomes match the saved number; raw submitted text remains in command identity. Later material/supplier metadata edits do not rewrite those snapshots.

This remains an unreleased isolated candidate. Earlier candidate spending receipts lacking these snapshots fail closed on replay; no runtime account or migration uses this format. No historical record is silently rewritten to add missing evidence. Source records/journals/outcomes must agree, including optional outcome fields and exact journal policies. A zero optional immediate payment creates neither payment record/journal nor phantom outcome links. Explicit allowZero journal policy does not waive source validation: source invoices and supplier-payment allocation still require positive values; zero operating expenses remain supported with the explicit policy.

## Failures and evidence limits

| Condition | Result |
| --- | --- |
| Missing captured fence | `missing_authority_fence` before I/O |
| Replaced generation/fence | `stale_authority_fence` |
| Wrong account lineage | `account_lineage_mismatch` before replay |
| Changed payload/version under an existing operation | `changed_payload_rejected` |
| Gated/incomplete cutover | `cutover_gated` |
| Business date before cutover | `pre_cutover_operation_rejected` |
| Non-existent expense category | `missing_category` |
| Non-existent supplier | `missing_supplier` |
| Duplicate record ID or journal ID | `duplicate_record_id` |
| Duplicate invoice number for supplier | `duplicate_invoice_number` |
| Payment date precedes invoice date | `invalid_payment_date` |
| Immediate or debt payment exceeds liability | `payment_exceeds_liability` |
| Reversed invoice posting | `already_reversed` |
| Nonunique or mismatched invoice posting | `invoice_source_journal_mismatch` |
| A prior source settlement has no matching active posting | `payment_source_journal_mismatch` |
| Target invoice lacks post-cutover journal | `cross_cutover_source_has_no_post_cutover_journal` |
| Historical debt without opening verified liability | `unverified_historical_debt` |
| Negative payment amount | `negative_payment` |
| Zero amount without allowZero policy | `zero_value_requires_allow_zero_policy` |
| Malformed receipt/source outcome | structured corrupt state failure; no new write |
| Read cancellation / pending acknowledgement | Madar structured unavailable/recovery outcome |

Invalid constructor inputs raise a bounded `FormatException`; a mismatched injected store owner raises `ArgumentError`. Proposal validation and mapping failures return their structured rejection codes without committing source or journal changes.

The real-store conformance tests cover real-store reopen, replay, tampered payloads, changed versions, stale fences, lost acknowledgement recovery via `resolvePendingWrite()` (including a real committed invoice-plus-payment write with its acknowledgement suppressed, followed by reopen and exactly-once replay), and mixed sales/spending isolation on the same store. They do not prove every OS crash, WAL/fsync, disk-full, or physical-device condition. Live migration, UI, and release remain separate obligations.
