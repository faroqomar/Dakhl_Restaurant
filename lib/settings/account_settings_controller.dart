import 'package:madar_application/madar_application.dart';

import '../accounts/accounts_repository.dart';
import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import 'account_settings.dart';

/// One editor bound to a captured account revision. Reload after conflicts or
/// unknown-write reconciliation; it never overwrites newer account state.
final class AccountSettingsController {
  AccountSettingsController(this.repository)
    : _expected = repository.snapshot,
      _draft = AccountSettingsDraft(
        repository.document ?? (throw StateError('Open an account first.')),
      );

  final AccountsRepository repository;
  DocumentSnapshot? _expected;
  final AccountSettingsDraft _draft;
  bool _busy = false;
  int _editVersion = 0;
  AccountSettingsValues get values => _draft.values;
  bool get isDirty => _draft.isDirty;
  bool get isBusy => _busy;

  void replace(AccountSettingsValues values) {
    _editVersion++;
    _draft.replace(values);
  }

  void discard() {
    _editVersion++;
    _draft.discard();
  }

  Future<CapabilityResult<void>> save() async {
    if (_busy) return const CapabilityFailure('busy', 'Save in progress.');
    if (repository.hasUnknownWrite) {
      return const CapabilityFailure(
        'commit_unknown',
        'Reconcile before editing.',
      );
    }
    final current = repository.document;
    if (_expected == null ||
        repository.snapshot != _expected ||
        current == null) {
      return const CapabilityFailure(
        'stale_revision',
        'Reload the settings editor.',
      );
    }
    _busy = true;
    final submittedVersion = _editVersion;
    try {
      final candidate = _draft.prepareSave(current);
      final result = await repository.save(candidate);
      if (result is CapabilityFailure<AccountDocument>) {
        return CapabilityFailure(
          result.code,
          'Settings were not acknowledged.',
        );
      }
      // Another operation may have changed account authority before this
      // continuation. Do not adopt its revision as consent for a future write.
      if (!identical(repository.document, candidate)) {
        return const CapabilityFailure(
          'stale_revision',
          'Reload the settings editor.',
        );
      }
      _expected = repository.snapshot;
      final laterEdits = _draft.values;
      _draft.acceptSaved(candidate);
      if (_editVersion != submittedVersion) _draft.replace(laterEdits);
      return const CapabilitySuccess(null);
    } on AccountCodecException catch (error) {
      return CapabilityFailure(error.code, 'Settings are invalid.');
    } finally {
      _busy = false;
    }
  }
}
