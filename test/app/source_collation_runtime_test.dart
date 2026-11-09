import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_icu_collation/madar_icu_collation.dart';
import 'package:dakhl_restaurant/app/source_collation_runtime.dart';

void main() {
  test('missing native runtime exposes no lexical or host fallback', () {
    expect(
      SourceCollationRuntime.loadLibrary('/not-present/madar-runtime.dylib'),
      isNull,
    );
  });
  final entry = File(
    '../Madar_Engine/outputs/icu-runtime/macos-arm64/libicu_collation_pilot.dylib',
  );
  final bundledEntry = File(
    '../Madar_Engine/outputs/icu-mobile/runtime/macos-arm64/libmadar_icu_collation.dylib',
  );
  test(
    'refused second profile closes the first and exposes no comparator',
    () {
      CollationSession? first;
      final runtime = SourceCollationRuntime.loadWithAdapter(
        IcuCollationAdapter.loadBundled,
        openSession: (adapter, profile) {
          if (profile == CollationProfile.ar) {
            throw StateError('Synthetic native profile refusal.');
          }
          return first = adapter.openSession(profile);
        },
      );
      expect(runtime, isNull);
      expect(first, isNotNull);
      expect(
        () => first!.compare('a', 'b'),
        throwsA(isA<CollationClosedException>()),
      );
    },
    skip: !Platform.isMacOS || !bundledEntry.existsSync()
        ? 'Bundled native artifact absent; failure cleanup has no host fallback.'
        : false,
  );

  test(
    'bundled consumer owns both source profiles without an executable-relative path',
    () {
      final runtime = SourceCollationRuntime.loadBundled();
      expect(runtime, isNotNull);
      final value = runtime!;
      try {
        expect(value.events.profile, CollationProfile.enUs);
        expect(value.materialNames.profile, CollationProfile.ar);
        expect(identical(value.events, value.materialNames), isFalse);
        expect(value.events.compare('café', 'cafe\u0301'), 0);
        expect(value.materialNames.compare('ماء', 'ماء'), 0);
        expect(value.events.compare('a\u0000b', 'a\u0000c'), lessThan(0));
        expect(
          () => value.materialNames.compare(String.fromCharCode(0xd800), 'ماء'),
          throwsA(isA<CollationInvalidInputException>()),
        );
      } finally {
        value.close();
      }
      value.close();
      expect(
        () => value.events.compare('a', 'b'),
        throwsA(isA<CollationClosedException>()),
      );
      expect(
        () => value.materialNames.compare('ماء', 'ملح'),
        throwsA(isA<CollationClosedException>()),
      );
    },
    skip: !Platform.isMacOS || !bundledEntry.existsSync()
        ? 'Host bundled artifact absent; native target qualification remains separate.'
        : false,
  );
  test(
    'consumer owns distinct source profiles and closes both sessions',
    () {
      final runtime = SourceCollationRuntime.loadLibrary(entry.absolute.path);
      expect(runtime, isNotNull);
      final value = runtime!;
      expect(value.events.profile, CollationProfile.enUs);
      expect(value.materialNames.profile, CollationProfile.ar);
      expect(value.events.compare('café', 'cafe\u0301'), 0);
      expect(value.materialNames.compare('ماء', 'ماء'), 0);
      expect(value.events.compare('a\u0000b', 'a\u0000c'), lessThan(0));
      value.close();
      value.close();
      expect(
        () => value.events.compare('a', 'b'),
        throwsA(isA<CollationClosedException>()),
      );
      expect(
        () => value.materialNames.compare('ماء', 'ملح'),
        throwsA(isA<CollationClosedException>()),
      );
    },
    skip: !Platform.isMacOS || !entry.existsSync()
        ? 'Native ICU candidate not available on this host; no mobile/native qualification inferred.'
        : false,
  );
}
