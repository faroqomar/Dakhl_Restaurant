import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/c0_import_boundary_fixture.dart';

void main() {
  const codec = LegacyAccountCodec();
  late C0ImportBoundaryBytes fixture;
  setUpAll(() => fixture = C0ImportBoundaryBytes.build());

  test('recognized schema11 notes produce exactly 20MiB canonical UTF8', () {
    expect(fixture.exact.length, 20971520);
    expect(fixture.baseBytes + fixture.noteBytes, 20971520);
    expect(fixture.noteBytes, inInclusiveRange(0, 10000 * 2000));
    final document = codec.decodeBytes(fixture.exact);
    expect(document.sourceVersion, 11);
    expect(codec.encode(document), fixture.exact);
    final rows = document.toJson()['transactions'] as List;
    expect(rows, hasLength(10000));
    expect(rows.map((dynamic row) => row['id']).toSet(), hasLength(10000));
    var notes = 0;
    for (final raw in rows) {
      final row = Map<String, Object?>.from(raw as Map);
      expect(row.keys.toSet(), {
        'id',
        'date',
        'type',
        'amount',
        'note',
        'createdAt',
      });
      expect(row['date'], '2026-11-08');
      expect(row['createdAt'], '2026-11-08T00:00:00.000Z');
      expect(row['type'], 'deposit');
      expect(row['amount'], 1);
      final note = row['note']! as String;
      expect(note.length, lessThanOrEqualTo(2000));
      expect(note.codeUnits.every((unit) => unit == 110), isTrue);
      notes += note.length;
    }
    expect(notes, fixture.noteBytes);
  });

  test(
    'staged regular files report actual SHA256 and clean all40MiB',
    () async {
      final created = await Directory.systemTemp.createTemp(
        'dakhl-boundary-stage-',
      );
      final namespace = Directory(await created.resolveSymbolicLinks());
      final owned = await C0ImportBoundaryFixture.open(
        namespace: namespace,
        fixtureId: '22000000-0000-4000-8000-000000000002',
        stage: 'exact-cancel',
      );
      try {
        final report = await owned.stagePickerFiles();
        final exact = report['exact']! as Map;
        final oversized = report['oversized']! as Map;
        expect(exact['bytes'], 20971520);
        expect(oversized['bytes'], 20971521);
        expect(exact['sha256'], sha256.convert(fixture.exact).toString());
        expect(
          oversized['sha256'],
          sha256.convert(fixture.oversized).toString(),
        );
        expect(await owned.exactFile.readAsBytes(), fixture.exact);
        expect(await owned.oversizedFile.length(), 20971521);
        await owned.assertAuthorityUnchanged();
      } finally {
        await owned.cleanup();
        expect(await owned.root.exists(), isFalse);
        await namespace.delete(recursive: true);
      }
    },
  );

  test(
    'one LF adds one incoming byte without changing the parsed document',
    () {
      final oversized = fixture.oversized;
      expect(oversized.length, 20971521);
      expect(oversized.last, 10);
      final parsed = jsonDecode(utf8.decode(oversized)) as Map<String, dynamic>;
      expect(codec.encode(codec.decodeJson(parsed)), fixture.exact);
      expect(
        () => codec.decodeBytes(oversized),
        throwsA(
          isA<AccountCodecException>().having(
            (error) => error.code,
            'code',
            'payload_too_large',
          ),
        ),
      );
    },
  );
}
