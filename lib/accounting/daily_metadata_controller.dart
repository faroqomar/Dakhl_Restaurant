import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/accounts_repository.dart';
import '../accounts/legacy_account_codec.dart';

/// Nonfinancial chicken counts only. Never changes funding, balances or journals.
/// Normal schema11 composition uses its existing single repository writer.
final class DailyMetadataController {
  DailyMetadataController(this.repository) : _expected = repository.snapshot;
  final AccountsRepository repository;
  DocumentSnapshot? _expected;
  bool _busy = false, _ownsPending = false;
  bool get busy => _busy;
  bool get needsReadback => _ownsPending;
  static final _counts = ExactIntegerPolicy(
    maxAbs: BigInt.from(1000000000000),
    signed: false,
    positive: false,
    maxSafeInteger: BigInt.parse('9007199254740991'),
  );
  CapabilityFailure<void> _failure(String code) =>
      CapabilityFailure(code, 'Chicken counts were not confirmed.');
  Future<CapabilityResult<void>> saveChicken({
    required String date,
    required String used,
    required String left,
  }) async {
    if (_busy) return _failure('busy');
    if (_ownsPending || repository.hasUnknownWrite) {
      return _failure('commit_unknown');
    }
    final current = repository.document;
    if (_expected == null ||
        repository.snapshot != _expected ||
        current == null) {
      return _failure('stale_revision');
    }
    final AccountDocument candidate;
    try {
      DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
      final days = {...current.days};
      final day =
          days[date] as Map<String, Object?>? ??
          const {
            'expenses': <Object?>[],
            'chickenUsed': 0,
            'chickenLeft': 0,
            'balance': null,
            'totalOverride': null,
            'remaining': null,
          };
      days[date] = {
        ...day,
        'chickenUsed': _counts
            .parse(used, normalizeDigits: true, allowGrouping: true)
            .toInt(),
        'chickenLeft': _counts
            .parse(left, normalizeDigits: true, allowGrouping: true)
            .toInt(),
      };
      candidate = const LegacyAccountCodec().decodeJson({
        ...current.toJson(),
        'days': days,
      });
    } on Object {
      return _failure('invalid_counts');
    }
    _busy = true;
    try {
      final result = await repository.save(candidate);
      if (result is CapabilitySuccess<AccountDocument>) {
        _expected = repository.snapshot;
        return const CapabilitySuccess(null);
      }
      _ownsPending = repository.hasUnknownWrite;
      return switch (result) {
        CapabilityFailure(:final code) => _failure(code),
        _ => _failure('cancelled'),
      };
    } finally {
      _busy = false;
    }
  }

  Future<CapabilityResult<void>> reconcile() async {
    if (_busy) return _failure('busy');
    if (!_ownsPending) return _failure('nothing_to_reconcile');
    _busy = true;
    try {
      final result = await repository.reconcile();
      if (result is CapabilitySuccess<AccountDocument>) {
        _ownsPending = false;
        _expected = repository.snapshot;
        return const CapabilitySuccess(null);
      }
      return switch (result) {
        CapabilityFailure(:final code) => _failure(code),
        _ => _failure('cancelled'),
      };
    } finally {
      _busy = false;
    }
  }
}
