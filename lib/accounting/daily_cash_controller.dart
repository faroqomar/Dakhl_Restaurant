import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import 'daily_cash_queries.dart';
import 'restaurant_journal_expense_correction_commands.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_spending_commands.dart';
import 'restaurant_journal_transfer_commands.dart';
import 'restaurant_journal_transfer_correction_commands.dart';
import 'spending_operations_view_model.dart';

/// Operational controller for daily cash drawer workflow, day selection,
/// expense submissions, and cashbox transfers.
final class DailyCashController extends ChangeNotifier {
  DailyCashController({required this.spending, String? initialDate})
    : _selectedDate = initialDate ?? _defaultDate() {
    spending.addListener(_onSpendingChanged);
  }

  final SpendingOperationsViewModel spending;
  String _selectedDate;
  bool _disposed = false;

  String get selectedDate => _selectedDate;
  bool get busy => spending.busy;
  bool get postingEnabled => spending.postingEnabled;
  String? get errorCode => spending.errorCode;

  DailyCashSnapshot get daySnapshot => spending.daySnapshot(_selectedDate);
  List<Map<String, Object?>> get expenses =>
      spending.expensesForDate(_selectedDate);
  List<Map<String, Object?>> get cashMovements => spending.cashMovements;
  BigInt get cashBalance => spending.cashBalance;
  BigInt get netSales => spending.netSales(_selectedDate);

  List<Map<String, Object?>> get transfers {
    final list = (spending.account.toJson()['transfers'] as List?) ?? const [];
    return List.unmodifiable(
      list.cast<Map<String, Object?>>().where(
        (t) => t['date'] == _selectedDate,
      ),
    );
  }

  void selectDate(String date) {
    if (_disposed || spending.busy) return;
    DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
    _selectedDate = date;
    notifyListeners();
  }

  void previousDay() {
    if (_disposed || spending.busy) return;
    final parsed = DateOnly.parse(
      _selectedDate,
      minimumYear: 1000,
      maximumYear: 9999,
    );
    final dt = DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    ).subtract(const Duration(days: 1));
    _selectedDate = _format(dt);
    notifyListeners();
  }

  void nextDay() {
    if (_disposed || spending.busy) return;
    final parsed = DateOnly.parse(
      _selectedDate,
      minimumYear: 1000,
      maximumYear: 9999,
    );
    final dt = DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    ).add(const Duration(days: 1));
    _selectedDate = _format(dt);
    notifyListeners();
  }

  void today() {
    if (_disposed || spending.busy) return;
    _selectedDate = _defaultDate();
    notifyListeners();
  }

  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> recordExpense({
    required String operationId,
    required String expenseId,
    required String journalId,
    required String categoryId,
    required BigInt amount,
    required FundingSource fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    String note = '',
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final intent = spending.createExpenseIntent(
      operationId: operationId,
      expenseId: expenseId,
      journalId: journalId,
      date: DateOnly.parse(_selectedDate, minimumYear: 1000, maximumYear: 9999),
      categoryId: categoryId,
      amount: amount,
      fundingSource: fundingSource,
      dailyAmount: dailyAmount,
      cashAmount: cashAmount,
      note: note,
      recordedAt: recordedAt,
      policy: policy,
    );
    return spending.submitExpense(intent);
  }

  Future<DurableCommandResult<RestaurantJournalExpenseCorrectionOutcome>>
  editExpense({
    required String operationId,
    required String expenseId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String replacementJournalId,
    required String categoryId,
    required BigInt amount,
    required FundingSource fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    String note = '',
    required String reason,
    required String recordedAt,
    RestaurantAccountProfile? profile,
    JournalPolicy? policy,
  }) {
    final intent = spending.editExpenseIntent(
      operationId: operationId,
      expenseId: expenseId,
      expectedActiveJournalId: expectedActiveJournalId,
      inverseJournalId: inverseJournalId,
      replacementJournalId: replacementJournalId,
      date: DateOnly.parse(_selectedDate, minimumYear: 1000, maximumYear: 9999),
      categoryId: categoryId,
      amount: amount,
      fundingSource: fundingSource,
      dailyAmount: dailyAmount,
      cashAmount: cashAmount,
      note: note,
      reason: reason,
      recordedAt: recordedAt,
      profile: profile,
      policy: policy,
    );
    return spending.submitExpenseCorrection(intent);
  }

  Future<DurableCommandResult<RestaurantJournalExpenseCorrectionOutcome>>
  deleteExpense({
    required String operationId,
    required String expenseId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
    RestaurantAccountProfile? profile,
    JournalPolicy? policy,
  }) {
    final intent = spending.deleteExpenseIntent(
      operationId: operationId,
      expenseId: expenseId,
      expectedActiveJournalId: expectedActiveJournalId,
      inverseJournalId: inverseJournalId,
      reason: reason,
      recordedAt: recordedAt,
      profile: profile,
      policy: policy,
    );
    return spending.submitExpenseCorrection(intent);
  }

  Future<DurableCommandResult<RestaurantJournalTransferOutcome>>
  transferToCashbox({
    required String operationId,
    required String transferId,
    required String journalId,
    required BigInt amount,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final intent = spending.transferIntent(
      operationId: operationId,
      transferId: transferId,
      journalId: journalId,
      date: DateOnly.parse(_selectedDate, minimumYear: 1000, maximumYear: 9999),
      amount: amount,
      recordedAt: recordedAt,
      policy: policy,
    );
    return spending.submitTransfer(intent);
  }

  Future<DurableCommandResult<RestaurantJournalTransferCorrectionOutcome>>
  editTransfer({
    required String operationId,
    required String transferId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String replacementJournalId,
    required BigInt newAmount,
    required String reason,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final intent = spending.editTransferIntent(
      operationId: operationId,
      transferId: transferId,
      expectedActiveJournalId: expectedActiveJournalId,
      inverseJournalId: inverseJournalId,
      replacementJournalId: replacementJournalId,
      newAmount: newAmount,
      reason: reason,
      recordedAt: recordedAt,
      policy: policy,
    );
    return spending.submitTransferCorrection(intent);
  }

  Future<DurableCommandResult<RestaurantJournalTransferCorrectionOutcome>>
  deleteTransfer({
    required String operationId,
    required String transferId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final intent = spending.deleteTransferIntent(
      operationId: operationId,
      transferId: transferId,
      expectedActiveJournalId: expectedActiveJournalId,
      inverseJournalId: inverseJournalId,
      reason: reason,
      recordedAt: recordedAt,
      policy: policy,
    );
    return spending.submitTransferCorrection(intent);
  }

  void _onSpendingChanged() {
    if (!_disposed) notifyListeners();
  }

  static String _defaultDate() {
    final now = DateTime.now();
    return _format(now);
  }

  static String _format(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    spending.removeListener(_onSpendingChanged);
    super.dispose();
  }
}
