import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/portable_journal_codec.dart';
import '../catalog/catalog_formatters.dart';
import 'restaurant_journal_expense_correction_commands.dart';
import 'restaurant_journal_expense_history.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_spending_commands.dart';
import 'spending_operations_view_model.dart';

/// Captured restaurant form intent. All money/funding and durable history logic
/// remain in existing domain calculations and restaurant command owners.
final class ExpenseEditorController {
  ExpenseEditorController({
    required this.spending,
    required this.date,
    Map<String, Object?>? expense,
  }) : original = expense == null ? null : Map.unmodifiable(expense),
       categoryId =
           expense?['categoryId'] as String? ??
           spending.account.categories
                   .where((c) => c['archived'] != true)
                   .first['id']!
               as String,
       amount = '${expense?['amount'] ?? 0}',
       note = expense?['note'] as String? ?? '' {
    final funding = expense?['funding'] as Map?;
    source = FundingSource.values.byName(
      funding?['source'] as String? ?? 'daily',
    );
    daily = '${funding?['dailyAmount'] ?? expense?['amount'] ?? 0}';
    cash = '${funding?['cashAmount'] ?? 0}';
    if (expense != null) {
      final state = const PortableJournalCodec().decodeState(
        spending.snapshot.payload,
      );
      final id = expense['id']! as String;
      for (final entry in state.journals.reversed) {
        if (entry.sourceRecordId == id &&
            RestaurantJournalExpenseHistory.validate(
              state: state,
              expenseId: id,
              mapper: spending.expenseCorrectionCommands.mapper,
              expectedActiveJournalId: entry.journal.id,
            )) {
          _activeJournalId = entry.journal.id;
          break;
        }
      }
    }
  }
  final SpendingOperationsViewModel spending;
  final Map<String, Object?>? original;
  String date, categoryId, amount, daily = '', cash = '', note, reason = '';
  late FundingSource source;
  String? _activeJournalId;
  Object? _pending;
  bool _busy = false;
  bool get busy => _busy;
  bool get pending => _pending != null;
  bool get editable => original == null || _activeJournalId != null;
  List<Map<String, Object?>> get categories => spending.account.categories
      .where((c) => c['archived'] != true || c['id'] == categoryId)
      .toList();
  static final _money = ExactIntegerPolicy(
    maxAbs: BigInt.from(1000000000000),
    signed: false,
    positive: false,
    maxSafeInteger: BigInt.parse('9007199254740991'),
  );
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: BigInt.from(1000000000000),
    maximumMoney: BigInt.from(1000000000000),
    maximumSafeInteger: BigInt.parse('9007199254740991'),
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );
  CapabilityFailure<void> _fail(String code) =>
      CapabilityFailure(code, 'Expense change was not confirmed.');
  Future<CapabilityResult<void>> save({bool delete = false}) async {
    if (_busy) return _fail('busy');
    if (!editable) return _fail('missing_original_posting');
    if (_pending == null) {
      if (spending.needsReadback || spending.busy || !spending.postingEnabled) {
        return _fail('busy');
      }
      try {
        final id = CatalogFormatters.generateId('expense-op');
        final recordedAt = CatalogFormatters.currentIsoTimestamp();
        if (delete) {
          if (original == null) return _fail('missing_expense');
          _pending = spending.deleteExpenseIntent(
            operationId: id,
            expenseId: original!['id']! as String,
            expectedActiveJournalId: _activeJournalId!,
            inverseJournalId: 'inverse-$id',
            reason: reason,
            recordedAt: recordedAt,
          );
        } else {
          final units = _money.parse(
            amount,
            normalizeDigits: true,
            allowGrouping: true,
          );
          final split = CommerceCalculations.fundingSplit(
            amount: units,
            source: source,
            daily: source == FundingSource.daily
                ? units
                : source == FundingSource.cash
                ? BigInt.zero
                : _money.parse(
                    daily,
                    normalizeDigits: true,
                    allowGrouping: true,
                  ),
            cash: source == FundingSource.cash
                ? units
                : source == FundingSource.daily
                ? BigInt.zero
                : _money.parse(
                    cash,
                    normalizeDigits: true,
                    allowGrouping: true,
                  ),
            policy: _policy,
          );
          final selectedDate = DateOnly.parse(
            date,
            minimumYear: 1000,
            maximumYear: 9999,
          );
          final policy = units == BigInt.zero
              ? RestaurantJournalPolicies.allowZero
              : null;
          _pending = original == null
              ? spending.createExpenseIntent(
                  operationId: id,
                  expenseId: 'expense-$id',
                  journalId: 'journal-$id',
                  date: selectedDate,
                  categoryId: categoryId,
                  amount: units,
                  fundingSource: source,
                  dailyAmount: split.daily,
                  cashAmount: split.cash,
                  note: note,
                  recordedAt: recordedAt,
                  policy: policy,
                )
              : spending.editExpenseIntent(
                  operationId: id,
                  expenseId: original!['id']! as String,
                  expectedActiveJournalId: _activeJournalId!,
                  inverseJournalId: 'inverse-$id',
                  replacementJournalId: 'replacement-$id',
                  date: selectedDate,
                  categoryId: categoryId,
                  amount: units,
                  fundingSource: source,
                  dailyAmount: split.daily,
                  cashAmount: split.cash,
                  note: note,
                  reason: reason,
                  recordedAt: recordedAt,
                  policy: policy,
                );
        }
      } on Object {
        return _fail('invalid_input');
      }
    }
    _busy = true;
    try {
      final command = _pending!;
      final DurableCommandResult result;
      if (command is CreateOperatingExpenseCommand) {
        result = await spending.submitExpense(command);
      } else {
        result = await spending.submitExpenseCorrection(
          command as OperatingExpenseCorrectionCommand,
        );
      }
      if (result is DurableCommandSuccess || result is DurableCommandReplayed) {
        _pending = null;
        return const CapabilitySuccess(null);
      }
      final code = (result as DurableCommandFailure).code;
      if (code != DurableCommandErrorCodes.commitUnknown &&
          code != DocumentErrorCodes.pendingWrite) {
        _pending = null;
      }
      return _fail(code);
    } on Object {
      return _fail('commit_unknown');
    } finally {
      _busy = false;
    }
  }
}
