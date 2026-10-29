import 'dart:async';

import 'package:dakhl_restaurant/app/bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import '../support/preferences_store.dart';

void main() {
  test(
    'overlapping reads share one initialization and use the real contract',
    () async {
      final ready = Completer<CapabilityResult<LocalPreferencesStore>>();
      var opens = 0;
      final target = MemoryPreferencesStore();
      final app = AppPreferencesStore(
        openStore: () {
          opens++;
          return ready.future;
        },
      );
      final first = app.read('ui');
      final second = app.read('ui');
      expect(opens, 1);
      ready.complete(CapabilitySuccess(target));
      expect(await first, isA<CapabilitySuccess<PreferenceSnapshot?>>());
      expect(await second, isA<CapabilitySuccess<PreferenceSnapshot?>>());
      expect(opens, 1);
      await app.close();
    },
  );

  test(
    'failed bootstrap is retryable and cannot claim a saved value',
    () async {
      var opens = 0;
      final target = MemoryPreferencesStore();
      final app = AppPreferencesStore(
        openStore: () async {
          opens++;
          return opens == 1
              ? const CapabilityFailure('unavailable', 'Fixture')
              : CapabilitySuccess(target);
        },
      );
      expect((await app.read('ui') as CapabilityFailure).code, 'unavailable');
      expect(
        await app.read('ui'),
        isA<CapabilitySuccess<PreferenceSnapshot?>>(),
      );
      expect(target.writes, isEmpty);
      expect(opens, 2);
      await app.close();
    },
  );

  test(
    'closing during initialization releases a late opened store once',
    () async {
      final ready = Completer<CapabilityResult<LocalPreferencesStore>>();
      var closes = 0;
      final app = AppPreferencesStore(
        openStore: () => ready.future,
        closeStore: (_) async {
          closes++;
        },
      );
      final read = app.read('ui');
      final close = app.close();
      ready.complete(CapabilitySuccess(MemoryPreferencesStore()));
      expect(
        (await read as CapabilityFailure).code,
        PreferenceErrorCodes.closed,
      );
      await close;
      await app.close();
      expect(closes, 1);
    },
  );

  test(
    'composition forwards opaque payload/revision without app-side storage',
    () async {
      final target = MemoryPreferencesStore();
      final app = AppPreferencesStore(
        openStore: () async => CapabilitySuccess(target),
      );
      final result = await app.replace('ui', '{"fixture":true}');
      expect(
        (result as CapabilitySuccess<PreferenceSnapshot>).value.revision,
        1,
      );
      expect(target.writes, ['{"fixture":true}']);
      expect(
        (await app.replace('ui', 'stale') as CapabilityFailure).code,
        PreferenceErrorCodes.conflict,
      );
      await app.close();
    },
  );

  test(
    'opening exceptions are sanitized and closed startup does not open',
    () async {
      var opens = 0;
      final app = AppPreferencesStore(
        openStore: () async {
          opens++;
          throw StateError('private path');
        },
      );
      final result = await app.read('ui') as CapabilityFailure;
      expect(result.code, PreferenceErrorCodes.unavailable);
      expect(result.message, isNot(contains('private path')));
      await app.close();
      await app.read('ui');
      expect(opens, 1);
    },
  );
}
