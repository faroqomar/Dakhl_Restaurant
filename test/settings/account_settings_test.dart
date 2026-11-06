import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/settings/account_settings.dart';

void main() {
  const codec = LegacyAccountCodec();
  test('draft save and discard preserve immutable baseline and unrelated current records', () {
    final baseline = codec.empty();
    final draft = AccountSettingsDraft(baseline);
    final values = draft.values.copyWith(
      name: ' مطعم ',
      activeOrderTypes: ['سفري', 'محلي'],
    );
    draft.replace(values);
    expect(draft.isDirty, isTrue);
    expect(baseline.preferences.restaurant['name'], '');
    final current = codec.decodeJson({
      ...baseline.toJson(),
      'products': [
        {
          'id': 'p',
          'name': 'صنف',
          'code': '',
          'group': '',
          'unit': 'قطعة',
          'price': 1000,
          'minStock': 0,
          'trackStock': false,
          'archived': false,
        },
      ],
    });
    final candidate = draft.prepareSave(current);
    expect(candidate.preferences.restaurant['name'], 'مطعم');
    expect((candidate.toJson()['products'] as List).length, 1);
    expect(
      draft.isDirty,
      isTrue,
    ); // Preparing is not a durable save acknowledgement.
    draft.acceptSaved(candidate);
    expect(draft.isDirty, isFalse);
    draft.replace(draft.values.copyWith(name: 'changed'));
    draft.discard();
    expect(draft.values.name, 'مطعم');
  });
  test('codec rejects empty enabled list, duplicate disabled name and total above20', () {
    final baseline = codec.empty();
    final draft = AccountSettingsDraft(baseline);
    for (final values in [
      draft.values.copyWith(activeOrderTypes: []),
      draft.values.copyWith(activeOrderTypes: ['A'], disabledOrderTypes: ['a']),
      draft.values.copyWith(
        activeOrderTypes: [for (var i = 0; i < 21; i++) 'نوع$i'],
      ),
    ]) {
      draft.replace(values);
      expect(
        () => draft.prepareSave(baseline),
        throwsA(isA<AccountCodecException>()),
      );
      expect(draft.isDirty, isTrue);
    }
  });
  test(
    'settings values defensively copy lists and detect raw whitespace edits',
    () {
      final baseline = codec.empty();
      final draft = AccountSettingsDraft(baseline);
      final list = ['سفري'];
      draft.replace(draft.values.copyWith(activeOrderTypes: list));
      list.clear();
      expect(draft.values.activeOrderTypes, ['سفري']);
      expect(
        () => draft.values.activeOrderTypes.add('x'),
        throwsUnsupportedError,
      );
      draft.discard();
      draft.replace(draft.values.copyWith(name: ' '));
      expect(draft.isDirty, isTrue);
    },
  );
}
