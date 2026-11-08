# Build-first spending and parties workflow candidate

Date: 2026-11-08. Status: implemented nonvisual operational ViewModel and controller files under `lib/accounting/` and `lib/parties/`; small targeted smoke checks passed; full tests, benchmarks, native checks, and independent review deferred under the owner build-first instruction.

## Scope and ownership

App owns:
- [`lib/accounting/spending_operations_view_model.dart`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/accounting/spending_operations_view_model.dart): Nonvisual operational ViewModel bound to an explicitly initialized complete-state account. Coordinates durable operating expenses (`CreateOperatingExpenseCommand`), expense corrections (`EditOperatingExpenseCommand`, `DeleteOperatingExpenseCommand`), daily-to-cashbox transfers (`DailyToCashboxTransferCommand`), and transfer corrections (`EditDailyTransferCommand`, `DeleteDailyTransferCommand`). Exposes queries via `DailyCashQueries` (`daySnapshot`, `expensesForDate`, `netSales`, `cashMovements`, `cashBalance`, `statement`), pure previews, intent builders, command submission, replay/uncertainty handling, and snapshot acceptance.
- [`lib/accounting/daily_cash_controller.dart`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/accounting/daily_cash_controller.dart): Operational daily drawer controller managing active date selection (`selectDate`, `previousDay`, `nextDay`, `today`), daily snapshot/totals, daily expenses, day transfers, cash movements, and delegating durable submissions to `SpendingOperationsViewModel`.
- [`lib/parties/parties_operations_view_model.dart`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/parties_operations_view_model.dart): Nonvisual operational ViewModel bound to an explicitly initialized complete-state account. Coordinates purchase invoices (`CreatePurchaseInvoiceCommand`) with line details and optional immediate payment, supplier payments (`CreateSupplierPaymentCommand`), and supplier payment corrections (`EditSupplierPaymentCommand`, `DeleteSupplierPaymentCommand`). Exposes supplier and material records, invoice and payment collections, `SupplierLedgerQueries` projection, pure previews, intent builders, command submission, replay/uncertainty handling, and snapshot acceptance.
- [`lib/parties/purchase_operations_controller.dart`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/purchase_operations_controller.dart): Operational controller for purchase line calculations (independent carton/piece prices and quantities using `CommerceCalculations.independentUnitLineTotal`), invoice totals, payment debt allocation (`allocatePayment` using `SupplierLedgerQueries` and `CommerceCalculations.allocatePayment`), funding split (`calculateFundingSplit`), and delegating submissions to `PartiesOperationsViewModel`.
- [`lib/parties/parties_view_model.dart`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/parties_view_model.dart): Additive public factories `SupplierRecord.fromMap` and `MaterialRecord.fromMap` to allow operational ViewModels to instantiate typed supplier and material records from complete-state accounts.

Madar implementation/API changes: N/A. Shared domain rules, calculation contracts, and coordinators from Madar suffice. No engine pins, dependencies, or copied engine code were modified.

## Preserved existing modules

The existing durable modules remain unchanged and preserved:
- `lib/accounting/restaurant_journal_spending_commands.dart`
- `lib/accounting/restaurant_journal_expense_correction_commands.dart`
- `lib/accounting/restaurant_journal_payment_correction_commands.dart`
- `lib/accounting/restaurant_journal_transfer_commands.dart`
- `lib/accounting/restaurant_journal_transfer_correction_commands.dart`
- `lib/accounting/restaurant_journal_mapper.dart`
- `lib/accounting/journal_command_host.dart`
- `lib/accounting/restaurant_journal_expense_history.dart`
- `lib/accounting/restaurant_journal_payment_history.dart`
- `lib/accounting/restaurant_journal_transfer_history.dart`
- `lib/accounting/daily_cash_queries.dart`
- `lib/accounting/categories_view_model.dart`
- `lib/parties/purchase_proposal.dart`
- `lib/parties/supplier_ledger.dart`
- `lib/accounts/legacy_account_codec.dart`
- `lib/accounts/portable_journal_codec.dart`

## Execution and targeted verification

1. Consulted Hindsight scoped memory for both `project-daftar` and `project-madar` banks per the `t3-hindsight-required` skill, verifying prior contracts, funding rules, and boundary expectations.
2. Implemented operational ViewModel and controller classes following the nonvisual durable command coordinator pattern demonstrated by `SalesOperationsViewModel`.
3. Created targeted unit test suites:
   - [`test/accounting/spending_operations_view_model_test.dart`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/test/accounting/spending_operations_view_model_test.dart): Verifies operating expense intent, pure preview, execution, receipt selection, idempotent replay without extra storage writes, daily-to-cashbox transfer intent, preview, execution, and `DailyCashController` snapshot/transfers/expenses integration.
   - [`test/parties/parties_operations_view_model_test.dart`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/test/parties/parties_operations_view_model_test.dart): Verifies purchase invoice intent with line items, preview, execution, idempotent replay without extra writes, supplier payment intent with invoice/debt settlement, preview, execution, and `PurchaseOperationsController` independent unit line calculation and payment allocation.
4. Ran small targeted test verification:
   - `flutter test test/accounting/spending_operations_view_model_test.dart test/parties/parties_operations_view_model_test.dart`: 2/2 tests passed with 0 failures.
   - `dart analyze lib/accounting/ lib/parties/ test/accounting/spending_operations_view_model_test.dart test/parties/parties_operations_view_model_test.dart`: 0 issues found.
5. In accordance with owner instructions: broad test suites, full benchmarks, visual UI integration, and independent review were deferred.

## Storage review

- Available disk space: 95,308,208 KiB (~97.6 GB).
- Canonical directory sizes:
  - `.git`: 18,436,040 KiB
  - `build`: 2,183,372 KiB
  - `outputs`: 7,398,232 KiB
- New source and test code written strictly under canonical directories (`lib/accounting/`, `lib/parties/`, `test/accounting/`, `test/parties/`, `docs/log/`).
- No git mutations, resets, or worktrees created. No temporary directories, child agents, or obsolete artifact debris.

## Exact completed vs. remaining build

### Completed in this step
- Nonvisual operational ViewModels for spending (`SpendingOperationsViewModel`) and parties (`PartiesOperationsViewModel`).
- Operational controllers for daily cash workflow (`DailyCashController`) and purchase/payment workflow (`PurchaseOperationsController`).
- Full nonvisual category/daily/cash/supplier/purchase/payment workflow integration using durable commands, pure previews, replay handling, and single-store coordination.
- Additive public factory constructors on `SupplierRecord` and `MaterialRecord`.
- Small targeted verification passing cleanly with 0 analyzer issues.

### Remaining build
- Visual operational UI screens for daily cash drawer, expense entry, purchase invoice entry, supplier payment forms, and supplier ledger views (deferred pending owner design approval; user deferred Penpot login).
- Top-level composition wiring in `lib/app/app.dart` by root agent to bind these ViewModels and controllers into the application lifecycle when portable account state is active.
- Live cutover execution and financial account activation (currently gated under Schema 11).
- Full fault injection, process restart tests, native device checks, benchmarks, and independent review.

## APIs root should wire

Root (composition owner) can wire the following operational contracts into application composition or workflow sessions:
1. **Spending & Daily Cash Operations**:
   - `SpendingOperationsViewModel(snapshot: snapshot, store: store)`
     - Exposes: `postingEnabled`, `busy`, `needsReadback`, `errorCode`
     - Queries: `daySnapshot(date)`, `expensesForDate(date)`, `netSales(date)`, `cashMovements`, `cashBalance`, `statement(...)`
     - Intent builders & submission: `createExpenseIntent`, `submitExpense`, `editExpenseIntent`, `deleteExpenseIntent`, `submitExpenseCorrection`, `transferIntent`, `submitTransfer`, `editTransferIntent`, `deleteTransferIntent`, `submitTransferCorrection`, `retry()`, `acceptSnapshot(snapshot)`
   - `DailyCashController(spending: spendingViewModel, initialDate: dateString)`
     - Exposes: `selectedDate`, `selectDate`, `previousDay`, `nextDay`, `today`, `daySnapshot`, `expenses`, `transfers`, `cashMovements`, `cashBalance`, `recordExpense`, `editExpense`, `deleteExpense`, `transferToCashbox`, `editTransfer`, `deleteTransfer`
2. **Parties & Purchase/Payment Operations**:
   - `PartiesOperationsViewModel(snapshot: snapshot, store: store)`
     - Exposes: `postingEnabled`, `busy`, `needsReadback`, `errorCode`
     - Collections: `suppliers`, `materials`, `invoices`, `payments`
     - Ledger: `supplierLedger(supplierId)`
     - Intent builders & submission: `purchaseInvoiceIntent`, `submitInvoice`, `supplierPaymentIntent`, `submitPayment`, `editPaymentIntent`, `deletePaymentIntent`, `submitPaymentCorrection`, `retry()`, `acceptSnapshot(snapshot)`
   - `PurchaseOperationsController(parties: partiesViewModel, initialSupplierId: id)`
     - Exposes: `selectedSupplierId`, `selectSupplier`, `suppliers`, `materials`, `invoices`, `payments`
     - Calculations: `calculateLineTotal(line)`, `calculateInvoiceTotal(lines)`, `allocatePayment(...)`, `calculateFundingSplit(...)`, `debtAvailable(...)`, `invoiceDue(...)`
     - Operations: `createInvoice`, `createPayment`, `editPayment`, `deletePayment`

## Blockers and gates
- **Design approval**: Visual surfaces for daily cash drawer, expenses, purchase invoices, and supplier payments require owner approval before UI code is mounted; Penpot login remains deferred by the user.
- **Financial cutover**: Live financial posting remains gated under Schema 11 until cutover date and opening balance verification are authorized by the owner.
