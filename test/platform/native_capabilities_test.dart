import 'dart:io';
import 'dart:typed_data';

import 'package:dakhl_restaurant/capabilities/capability_contracts.dart';
import 'package:dakhl_restaurant/platform/native_file_selection.dart';
import 'package:dakhl_restaurant/platform/native_probe_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Native file selection boundary', () {
    test('open cancellation is distinct from native failure', () async {
      final cancelled = NativeFileSelection(pick: () async => null);
      expect(
        await cancelled.openSynthetic(),
        isA<CapabilityCancelled<Uint8List>>(),
      );
      final denied = NativeFileSelection(
        pick: () async => throw const FileSystemException('denied'),
      );
      expect(await denied.openSynthetic(), isA<CapabilityFailure<Uint8List>>());
    });

    test('opening copies plugin bytes so later plugin mutation cannot change the result', () async {
      final source = Uint8List.fromList([1, 2, 3]);
      final adapter = NativeFileSelection(pick: () async => source);
      final result =
          await adapter.openSynthetic() as CapabilitySuccess<Uint8List>;
      source[0] = 99;
      expect(result.value, [1, 2, 3]);
    });

    test(
      'cancelled and failed export preserve input and allow retry',
      () async {
        var attempts = 0;
        final source = SyntheticProbe.specimen.encode();
        final original = Uint8List.fromList(source);
        final adapter = NativeFileSelection(
          save: (bytes) async {
            bytes[0] = 99;
            attempts += 1;
            if (attempts == 1) return null;
            if (attempts == 2) throw const FileSystemException('denied');
            return Uri.parse('content://synthetic/export');
          },
        );
        expect(
          await adapter.saveSynthetic(source),
          isA<CapabilityCancelled<void>>(),
        );
        expect(
          await adapter.saveSynthetic(source),
          isA<CapabilityFailure<void>>(),
        );
        expect(
          await adapter.saveSynthetic(source),
          isA<CapabilitySuccess<void>>(),
        );
        expect(source, original);
      },
    );
  });

  group('Development data directory', () {
    late Directory sandbox;
    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('phase00-path-test-');
    });
    tearDown(() async {
      await sandbox.delete(recursive: true);
    });

    test('always resolves an isolated child of app support', () async {
      final result = await NativeProbeDirectory(
        applicationSupport: () async => sandbox,
      ).resolve();
      final root = (result as CapabilitySuccess<Directory>).value;
      expect(
        root.path,
        '${await sandbox.resolveSymbolicLinks()}${Platform.pathSeparator}dakhl_restaurant_phase00_devprobe',
      );
      expect(await root.exists(), isTrue);
    });

    test(
      'refuses legacy Daftar ancestor before any child is created',
      () async {
        final legacy = Directory('${sandbox.path}/Daftar/nested');
        await legacy.create(recursive: true);
        final result = await NativeProbeDirectory(
          applicationSupport: () async => legacy,
        ).resolve();
        expect(result, isA<CapabilityFailure<Directory>>());
        expect(
          await Directory('${legacy.path}/dakhl_restaurant_phase00_devprobe')
              .exists(),
          isFalse,
        );
      },
    );

    test('refuses symlinked development root without following it', () async {
      final elsewhere = await Directory('${sandbox.path}/elsewhere').create();
      await Link('${sandbox.path}/dakhl_restaurant_phase00_devprobe')
          .create(elsewhere.path);
      final result = await NativeProbeDirectory(
        applicationSupport: () async => sandbox,
      ).resolve();
      expect(result, isA<CapabilityFailure<Directory>>());
      expect(await elsewhere.list().isEmpty, isTrue);
    });

    test('refuses legacy com.daftar app identifier roots', () async {
      final legacy = await Directory('${sandbox.path}/com.daftar.desktop')
          .create();
      final result = await NativeProbeDirectory(
        applicationSupport: () async => legacy,
      ).resolve();
      expect(result, isA<CapabilityFailure<Directory>>());
    });

    test('path plugin failure propagates as failure', () async {
      final result = await NativeProbeDirectory(
        applicationSupport: () async =>
            throw const FileSystemException('unavailable'),
      ).resolve();
      expect(result, isA<CapabilityFailure<Directory>>());
    });
  });
}
