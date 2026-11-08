import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

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

  /// The first enabled type is the default for new tickets. Historical labels
  /// are snapshots and are never rewritten by these preference operations.
  String get defaultOrderType => values.activeOrderTypes.first;

  CapabilityResult<void> _edit(AccountSettingsValues next) {
    final current = repository.document;
    if (current == null || repository.snapshot != _expected) {
      return const CapabilityFailure('stale_revision', 'Reload settings.');
    }
    final candidate = AccountSettingsDraft(current)..replace(next);
    try {
      final validated = candidate.prepareSave(current);
      replace(AccountSettingsValues.fromAccount(validated));
      return const CapabilitySuccess(null);
    } on AccountCodecException catch (error) {
      return CapabilityFailure(error.code, 'Invalid settings.');
    }
  }

  CapabilityResult<void> addOrderType(String name) => _edit(
    values.copyWith(
      activeOrderTypes: [
        ...values.activeOrderTypes,
        LegacyText.trimJavaScript(name),
      ],
    ),
  );

  CapabilityResult<void> renameOrderType(String oldName, String name) {
    if (![
      ...values.activeOrderTypes,
      ...values.disabledOrderTypes,
    ].contains(oldName)) {
      return const CapabilityFailure('not_found', 'Order type not found.');
    }
    final clean = LegacyText.trimJavaScript(name);
    return _edit(
      values.copyWith(
        activeOrderTypes: [
          for (final t in values.activeOrderTypes) t == oldName ? clean : t,
        ],
        disabledOrderTypes: [
          for (final t in values.disabledOrderTypes) t == oldName ? clean : t,
        ],
      ),
    );
  }

  CapabilityResult<void> setOrderTypeEnabled(String name, bool enabled) {
    final active = [...values.activeOrderTypes];
    final disabled = [...values.disabledOrderTypes];
    if (!active.contains(name) && !disabled.contains(name)) {
      return const CapabilityFailure('not_found', 'Order type not found.');
    }
    if (enabled && disabled.remove(name)) active.add(name);
    if (!enabled && active.remove(name)) disabled.add(name);
    return _edit(
      values.copyWith(activeOrderTypes: active, disabledOrderTypes: disabled),
    );
  }

  CapabilityResult<void> deleteOrderType(String name) => _edit(
    values.copyWith(
      activeOrderTypes: values.activeOrderTypes
          .where((t) => t != name)
          .toList(),
      disabledOrderTypes: values.disabledOrderTypes
          .where((t) => t != name)
          .toList(),
    ),
  );

  CapabilityResult<void> makeDefaultOrderType(String name) {
    if (!values.activeOrderTypes.contains(name)) {
      return const CapabilityFailure(
        'disabled_order_type',
        'Enable the type first.',
      );
    }
    return _edit(
      values.copyWith(
        activeOrderTypes: [
          name,
          ...values.activeOrderTypes.where((t) => t != name),
        ],
      ),
    );
  }

  CapabilityResult<void> moveOrderType(int from, int to) {
    final active = [...values.activeOrderTypes];
    if (from < 0 || to < 0 || from >= active.length || to >= active.length) {
      return const CapabilityFailure(
        'invalid_index',
        'Invalid order type position.',
      );
    }
    active.insert(to, active.removeAt(from));
    return _edit(values.copyWith(activeOrderTypes: active));
  }

  CapabilityResult<void> setShortcut(int slot, String destination) {
    if (slot < 0 || slot >= values.shortcuts.length) {
      return const CapabilityFailure(
        'invalid_index',
        'Invalid shortcut position.',
      );
    }
    final shortcuts = [...values.shortcuts]..[slot] = destination;
    return _edit(values.copyWith(shortcuts: shortcuts));
  }

  CapabilityResult<void> moveShortcut(int from, int to) {
    final shortcuts = [...values.shortcuts];
    if (from < 0 ||
        to < 0 ||
        from >= shortcuts.length ||
        to >= shortcuts.length) {
      return const CapabilityFailure(
        'invalid_index',
        'Invalid shortcut position.',
      );
    }
    shortcuts.insert(to, shortcuts.removeAt(from));
    return _edit(values.copyWith(shortcuts: shortcuts));
  }

  /// Live identity preview; it has no save or posting side effect.
  Map<String, String> get receiptIdentityPreview => Map.unmodifiable({
    'name': LegacyText.trimJavaScript(values.name),
    'contact': LegacyText.trimJavaScript(values.contact),
    'footer': LegacyText.trimJavaScript(values.footer),
  });

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
