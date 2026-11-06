import 'dart:convert';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';

/// Editable consumer settings values; all final validation uses the account codec.
final class AccountSettingsValues {
  AccountSettingsValues({
    required Iterable<String> activeOrderTypes,
    required Iterable<String> disabledOrderTypes,
    required Iterable<String> shortcuts,
    required this.name,
    required this.contact,
    required this.footer,
  }) : activeOrderTypes = List.unmodifiable(activeOrderTypes),
       disabledOrderTypes = List.unmodifiable(disabledOrderTypes),
       shortcuts = List.unmodifiable(shortcuts);
  factory AccountSettingsValues.fromAccount(AccountDocument document) {
    final p = document.preferences;
    return AccountSettingsValues(
      activeOrderTypes: p.orderTypes,
      disabledOrderTypes: p.disabledOrderTypes,
      shortcuts: p.shortcuts,
      name: p.restaurant['name']!,
      contact: p.restaurant['contact']!,
      footer: p.restaurant['footer']!,
    );
  }
  final List<String> activeOrderTypes, disabledOrderTypes, shortcuts;
  final String name, contact, footer;
  AccountSettingsValues copyWith({
    List<String>? activeOrderTypes,
    List<String>? disabledOrderTypes,
    List<String>? shortcuts,
    String? name,
    String? contact,
    String? footer,
  }) => AccountSettingsValues(
    activeOrderTypes: activeOrderTypes ?? this.activeOrderTypes,
    disabledOrderTypes: disabledOrderTypes ?? this.disabledOrderTypes,
    shortcuts: shortcuts ?? this.shortcuts,
    name: name ?? this.name,
    contact: contact ?? this.contact,
    footer: footer ?? this.footer,
  );
  Map<String, Object?> _json({bool trim = false}) => {
    'orderTypes': activeOrderTypes,
    'disabledOrderTypes': disabledOrderTypes,
    'shortcuts': shortcuts,
    'restaurant': {
      'name': trim ? name.trim() : name,
      'contact': trim ? contact.trim() : contact,
      'footer': trim ? footer.trim() : footer,
    },
  };
}

/// No writes or account activation. Caller owns fencing and durable acknowledgement.
final class AccountSettingsDraft {
  AccountSettingsDraft(AccountDocument baseline)
    : _baseline = AccountSettingsValues.fromAccount(baseline),
      _values = AccountSettingsValues.fromAccount(baseline);
  AccountSettingsValues _baseline, _values;
  AccountSettingsValues get values => _values;
  bool get isDirty =>
      jsonEncode(_values._json()) != jsonEncode(_baseline._json());
  void replace(AccountSettingsValues values) {
    _values = values;
  }

  void discard() {
    _values = _baseline;
  }

  AccountDocument prepareSave(AccountDocument current) =>
      const LegacyAccountCodec().decodeJson({
        ...current.toJson(),
        'preferences': {
          ...(current.toJson()['preferences'] as Map<String, Object?>),
          ..._values._json(trim: true),
        },
      });

  /// Call only after the repository confirms durable save under the current fence.
  void acceptSaved(AccountDocument saved) {
    _baseline = AccountSettingsValues.fromAccount(saved);
    _values = _baseline;
  }
}
