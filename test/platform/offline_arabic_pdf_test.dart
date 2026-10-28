import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dakhl_restaurant/capabilities/capability_contracts.dart';
import 'package:dakhl_restaurant/platform/offline_arabic_pdf.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates a real PDF with embedded offline Arabic font and no source mutation', () async {
    final adapter = OfflineArabicPdf(
      loadFont: () async => ByteData.sublistView(
        await File('assets/fonts/Amiri-Regular.ttf').readAsBytes(),
      ),
    );
    final result = await adapter.generate(
      SyntheticProbe.specimen,
    ) as CapabilitySuccess<Uint8List>;
    expect(ascii.decode(result.value.take(5).toList()), '%PDF-');
    final source = latin1.decode(result.value);
    expect(source, contains('/FontFile2'));
    expect(source, contains('/ToUnicode'));
    expect(SyntheticProbe.specimen.sequence, 1);
  });

  test(
    'font failure and invalid probe stay failures; no silent network fallback',
    () async {
      var loads = 0;
      final adapter = OfflineArabicPdf(
        loadFont: () async {
          loads++;
          throw StateError('missing font');
        },
      );
      expect(
        await adapter.generate(const SyntheticProbe(message: '', sequence: 1)),
        isA<CapabilityFailure<Uint8List>>(),
      );
      expect(loads, 0);
      expect(
        await adapter.generate(SyntheticProbe.specimen),
        isA<CapabilityFailure<Uint8List>>(),
      );
      expect(loads, 1);
    },
  );

  test(
    'print cancel differs from failure and retry uses unchanged PDF bytes',
    () async {
      var attempts = 0;
      final bytes = Uint8List.fromList(utf8.encode('%PDF-synthetic-test'));
      final original = Uint8List.fromList(bytes);
      final adapter = OfflineArabicPdf(
        print: (copy) async {
          copy[0] = 0;
          attempts++;
          if (attempts == 1) return false;
          if (attempts == 2) throw StateError('native print failed');
          return true;
        },
      );
      expect(await adapter.print(bytes), isA<CapabilityCancelled<void>>());
      expect(await adapter.print(bytes), isA<CapabilityFailure<void>>());
      expect(await adapter.print(bytes), isA<CapabilitySuccess<void>>());
      expect(bytes, original);
    },
  );

  test(
    'share false is unconfirmed, never falsely reported delivered or cancelled',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('%PDF-synthetic-test'));
      final adapter = OfflineArabicPdf(share: (_) async => false);
      final result = await adapter.share(bytes) as CapabilityFailure<void>;
      expect(result.code, 'share_unconfirmed');
    },
  );

  test('invalid PDF is rejected before any native handoff', () async {
    var calls = 0;
    final adapter = OfflineArabicPdf(
      share: (_) async {
        calls++;
        return true;
      },
      print: (_) async {
        calls++;
        return true;
      },
    );
    expect(await adapter.share(Uint8List(0)), isA<CapabilityFailure<void>>());
    expect(
      await adapter.print(Uint8List.fromList([1, 2, 3])),
      isA<CapabilityFailure<void>>(),
    );
    expect(calls, 0);
  });
}
