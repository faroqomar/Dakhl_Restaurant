import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';

const corpusSha256 =
    '53cf4d356cb24fcb6309591d9587f8d74ad3bab0b8918a39980f7fabdf373e83';
final positiveNames = [
  for (var version = 1; version <= 11; version++) 'schema-$version',
  for (var version = 1; version <= 11; version++)
    'schema-$version-rich-history',
  'all-entities-history',
];
const rejectionNames = [
  'future-version',
  'bad-reversal',
  'bad-savings-period',
  'savings-over-receipt',
];

// These unconditional checks also run with VM assertions disabled.
void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Object? ordered(Object? object) {
  if (object is Map) {
    final keys = object.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: ordered(object[key])};
  }
  if (object is List) return object.map(ordered).toList();
  return object;
}

String canonical(Object? object) => jsonEncode(ordered(object));
String digest(List<int> bytes) => sha256.convert(bytes).toString();
String mapDigest(Object? object) => digest(utf8.encode(canonical(object)));
void equal(Object? actual, Object? expected, String label) {
  require(canonical(actual) == canonical(expected), '$label differs');
}

T value<T>(CapabilityResult<T> result, String label) {
  if (result is CapabilitySuccess<T>) return result.value;
  final failure = result as CapabilityFailure<T>;
  throw StateError('$label: ${failure.code}');
}

Map<String, Object?> snapshotMap(DocumentSnapshot snapshot) => {
  'payload': snapshot.payload,
  'payloadSha256': digest(utf8.encode(snapshot.payload)),
  'revision': snapshot.revision,
  'writeToken': snapshot.writeToken,
  'fence': {
    'storeId': snapshot.fence.storeId,
    'generation': snapshot.fence.generation,
  },
};

Future<Map<String, Object?>> stateOf(
  PowerSyncLocalDocumentWorkspaceStore store,
) async {
  final current = value(await store.readDocument(), 'read current');
  require(current != null, 'Missing durable account; reseeding is forbidden');
  final previous = value(await store.readPrevious(), 'read previous');
  require(previous != null, 'Missing independent previous copy');
  return {
    'current': snapshotMap(current!),
    'previous': {
      ...snapshotMap(previous!.snapshot),
      'identity': previous.identity,
    },
  };
}

// Read-only evidence of source/archive/backup/identity/pointer bytes. SQLite
// housekeeping files have no stable byte representation across an SDK reopen;
// stateOf compares their entire public durable payload and authority instead.
Future<Map<String, Object?>> protectedArtifacts(Directory store) async {
  final hashes = <String, Object?>{};
  await for (final entity in store.list(recursive: true, followLinks: false)) {
    require(entity is! Link, 'Unexpected link in owned fixture');
    if (entity is! File) continue;
    final relative = entity.path.substring(store.path.length + 1);
    if (relative == 'owner.lock' ||
        relative.endsWith('snapshot.sqlite') ||
        relative.endsWith('snapshot.sqlite-wal') ||
        relative.endsWith('snapshot.sqlite-shm') ||
        relative.endsWith('snapshot.sqlite-journal')) {
      continue;
    }
    final bytes = await entity.readAsBytes();
    hashes[relative] = {'bytes': bytes.length, 'sha256': digest(bytes)};
  }
  return hashes;
}

Future<Map<String, Object?>> archiveEvidence(
  Directory root,
  List<int> original,
) async {
  final sources = Directory('${root.path}/sources');
  require(await sources.exists(), 'Original source archive missing');
  final matches = <String>[];
  await for (final entity in sources.list(followLinks: false)) {
    if (entity is File &&
        digest(await entity.readAsBytes()) == digest(original)) {
      equal(await entity.readAsBytes(), original, 'original archive bytes');
      matches.add(entity.path.substring(root.path.length + 1));
    }
  }
  require(matches.length == 1, 'Expected exactly one original-byte archive');
  return {
    'path': matches.single,
    'sha256': digest(original),
    'bytes': original.length,
  };
}

List<Map<String, dynamic>> loadCorpus() {
  final bytes = File('test/fixtures/accounts/oracle.json').readAsBytesSync();
  require(digest(bytes) == corpusSha256, 'Frozen corpus changed');
  final corpus = jsonDecode(utf8.decode(bytes)) as Map;
  final cases = (corpus['cases'] as List).cast<Map<String, dynamic>>();
  for (final name in [...positiveNames, ...rejectionNames]) {
    require(
      cases.where((sample) => sample['name'] == name).length == 1,
      'Missing/ambiguous frozen case $name',
    );
  }
  return cases;
}

List<int> inputBytes(Map sample) =>
    utf8.encode(sample['rawJson'] as String? ?? jsonEncode(sample['input']));

Future<PowerSyncLocalDocumentWorkspaceStore> openStore(Directory root) async =>
    value(
      await PowerSyncLocalDocumentWorkspaceStore.open(directoryPath: root.path),
      'real owner open',
    );

Future<Map<String, Object?>> importAndSave(
  Directory fixture,
  Map sample,
) async {
  final source = File('${fixture.path}/original.json');
  final bytes = inputBytes(sample);
  await source.writeAsBytes(bytes, flush: true);
  final root = await Directory('${fixture.path}/store').create();
  final store = await openStore(root);
  try {
    final repository = AccountsRepository(store: store);
    require(
      value(await repository.open(), 'initial open') == null,
      'Writer requires actual initial absence',
    );
    final pending = repository.prepare(await source.readAsBytes());
    final originalVersion = (sample['input'] as Map)['version'];
    require(
      pending.document.sourceVersion == originalVersion,
      'Original schema provenance changed during preparation',
    );
    equal(pending.document.toJson(), sample['expected'], 'frozen expected map');
    value(
      await repository.save(pending.document, source: pending),
      'migration save',
    );
    final first = repository.snapshot!;
    require(first.revision == 1, 'Initial migration did not commit revision 1');
    value(await repository.save(pending.document), 'ordinary canonical save');
    final second = repository.snapshot!;
    require(
      second.revision == 2 && second.fence == first.fence,
      'Ordinary save changed fence or failed to advance revision',
    );
    require(second.writeToken != first.writeToken, 'Save reused initial token');
    equal(
      jsonDecode(second.payload),
      sample['expected'],
      'persisted canonical map',
    );
    equal(await source.readAsBytes(), bytes, 'original source after saves');
    final state = await stateOf(store);
    equal(
      (state['previous'] as Map)['payload'],
      first.payload,
      'previous canonical payload',
    );
    equal(
      (state['previous'] as Map)['writeToken'],
      first.writeToken,
      'previous token',
    );
    return {
      'name': sample['name'],
      'originalSourceVersion': originalVersion,
      'sourceSha256': digest(bytes),
      'sourceBytes': bytes.length,
      'expectedCanonical': sample['expected'],
      'expectedCanonicalSha256': mapDigest(sample['expected']),
      'archive': await archiveEvidence(root, bytes),
      'durableState': state,
    };
  } finally {
    await store.close();
  }
}

Future<Map<String, Object?>> writeRejection(
  Directory fixture,
  Map sample,
  Map seed,
) async {
  final seeded = await importAndSave(fixture, seed);
  final badBytes = inputBytes(sample);
  final rejectedSource = File('${fixture.path}/rejected-original.json');
  await rejectedSource.writeAsBytes(badBytes, flush: true);
  final root = Directory('${fixture.path}/store');
  final beforeClosed = await protectedArtifacts(root);
  final store = await openStore(root);
  String? rejectedCode;
  Map<String, Object?>? before;
  Map<String, Object?>? after;
  try {
    final repository = AccountsRepository(store: store);
    final current = value(await repository.open(), 'rejection base open');
    require(current != null, 'Missing rejection base; never reseed');
    before = await stateOf(store);
    equal(before, seeded['durableState'], 'rejection seed authority');
    final filesBefore = await protectedArtifacts(root);
    try {
      repository.prepare(await rejectedSource.readAsBytes());
      throw StateError('Protected rejection case was accepted');
    } on AccountCodecException catch (error) {
      rejectedCode = error.code;
    }
    final expectedCode = sample['name'] == 'future-version'
        ? 'unsupported_version'
        : 'invalid_payload';
    require(rejectedCode == expectedCode, 'Wrong protected rejection code');
    after = await stateOf(store);
    equal(after, before, 'durable state after rejection');
    equal(
      await protectedArtifacts(root),
      filesBefore,
      'artifacts after rejection',
    );
    equal(
      await rejectedSource.readAsBytes(),
      badBytes,
      'rejected original bytes',
    );
    equal(
      repository.document!.toJson(),
      seed['expected'],
      'cached account after rejection',
    );
  } finally {
    await store.close();
  }
  final afterClosed = await protectedArtifacts(root);
  equal(afterClosed, beforeClosed, 'closed protected artifacts');
  return {
    ...seeded,
    'name': sample['name'],
    'rejectedSourceSha256': digest(badBytes),
    'rejectionCode': rejectedCode,
    'beforeRejection': before,
    'afterRejection': after,
    'protectedArtifacts': afterClosed,
  };
}

Future<Map<String, Object?>> verifyExisting(
  Directory fixture,
  Map receipt,
  Map originalSample,
) async {
  final root = Directory('${fixture.path}/store');
  // Missing stores fail before the API can create an empty owner directory.
  require(await root.exists(), 'Missing existing store');
  require(
    await File('${root.path}/active.json').exists(),
    'Missing existing active pointer',
  );
  final expected = receipt['expectedCanonical'];
  final store = await openStore(root);
  Map<String, Object?>? actualState;
  try {
    final repository = AccountsRepository(store: store);
    final document = value(
      await repository.open(),
      'verifier repository reopen',
    );
    require(document != null, 'Missing reopened account; reseeding forbidden');
    require(
      document!.sourceVersion == 11,
      'Canonical reopened sourceVersion must be 11',
    );
    equal(document.toJson(), expected, 'reopened full canonical map');
    require(
      mapDigest(document.toJson()) == receipt['expectedCanonicalSha256'],
      'Reopened canonical hash mismatch',
    );
    actualState = await stateOf(store);
    equal(
      actualState,
      receipt['durableState'],
      'reopened entire durable state',
    );
    // This is the public codec operation used by AccountsViewModel.exportBytes.
    final exported = repository.codec.encode(document);
    final exportJson = jsonDecode(utf8.decode(exported)) as Map;
    require(
      exportJson['version'] == 11,
      'Public canonical export version changed',
    );
    equal(exportJson, expected, 'export full canonical map');
    final decoded = repository.codec.decodeBytes(exported);
    equal(
      decoded.toJson(),
      expected,
      'public export/decode full canonical map',
    );
    require(
      decoded.sourceVersion == 11,
      'Export provenance must describe canonical version',
    );
    equal(
      repository.codec.encode(decoded),
      exported,
      'export normalization idempotence',
    );
    final originalBytes = inputBytes(originalSample);
    equal(
      await File('${fixture.path}/original.json').readAsBytes(),
      originalBytes,
      'original source bytes on restart',
    );
    equal(
      await archiveEvidence(root, originalBytes),
      receipt['archive'],
      'original archive on restart',
    );
    if (receipt['rejectionCode'] != null) {
      require(
        digest(
              await File('${fixture.path}/rejected-original.json')
                  .readAsBytes(),
            ) ==
            receipt['rejectedSourceSha256'],
        'Rejected source changed after restart',
      );
      equal(
        await protectedArtifacts(root),
        receipt['protectedArtifacts'],
        'reopened protected artifacts',
      );
    }
    if (receipt['name'] == 'all-entities-history') {
      final preferences =
          (originalSample['input'] as Map)['preferences'] as Map;
      require(
        (preferences['shortcuts'] as List)[1] == 'savings',
        'Frozen savings shortcut missing',
      );
      require(
        document.preferences.shortcuts[1] == '',
        'Retired savings shortcut must normalize empty',
      );
    }
    return {
      'name': receipt['name'],
      'status': 'passed',
      'originalSourceVersion': receipt['originalSourceVersion'],
      'reopenedSourceVersion': document.sourceVersion,
      'canonicalSha256': mapDigest(document.toJson()),
      'exportSha256': digest(exported),
      'exportBytes': exported.length,
      'exportVersion': exportJson['version'],
      'durableState': actualState,
      'archive': receipt['archive'],
      if (receipt['rejectionCode'] != null)
        'rejectionCode': receipt['rejectionCode'],
    };
  } finally {
    await store.close();
    if (receipt['rejectionCode'] != null) {
      equal(
        await protectedArtifacts(root),
        receipt['protectedArtifacts'],
        'closed restart protected artifacts',
      );
    }
  }
}

Future<void> main(List<String> args) async {
  require(
    args.length == 3,
    'Expected owned-root, writer|verify and receipt path',
  );
  final root = Directory(args[0]).absolute;
  require(
    await File('${root.path}/.legacy-corpus-owned').exists(),
    'Owned-root marker missing',
  );
  final mode = args[1];
  require(mode == 'writer' || mode == 'verify', 'Unknown child mode');
  final cases = loadCorpus();
  Map sample(String name) =>
      cases.singleWhere((entry) => entry['name'] == name);
  final bootNonce = List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final receipts = <Map<String, Object?>>[];
  final output = File(args[2]);
  if (mode == 'writer') {
    require(
      (await root.list().toList()).length == 1,
      'Writer requires empty owned fixture root',
    );
    for (final name in positiveNames) {
      final fixture = await Directory('${root.path}/$name').create();
      final receipt = await importAndSave(fixture, sample(name));
      receipt['protectedArtifacts'] = await protectedArtifacts(
        Directory('${fixture.path}/store'),
      );
      receipts.add(receipt);
    }
    for (final name in rejectionNames) {
      final fixture = await Directory('${root.path}/$name').create();
      receipts.add(
        await writeRejection(
          fixture,
          sample(name),
          sample('all-entities-history'),
        ),
      );
    }
  } else {
    final writer = jsonDecode(
      await File('${root.path}/writer.json').readAsString(),
    ) as Map;
    require(writer['pid'] != pid, 'Verifier reused writer process');
    require(writer['bootNonce'] != bootNonce, 'Verifier reused boot nonce');
    for (final raw in writer['cases'] as List) {
      final receipt = raw as Map;
      final name = receipt['name'] as String;
      receipts.add(
        await verifyExisting(
          Directory('${root.path}/$name'),
          receipt,
          sample(rejectionNames.contains(name) ? 'all-entities-history' : name),
        ),
      );
    }
    equal(receipts.map((entry) => entry['name']).toList(), [
      ...positiveNames,
      ...rejectionNames,
    ], 'complete verifier case identities');
  }
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'format': 'dakhl-legacy-corpus-process-v1',
      'mode': mode,
      'status': 'passed',
      'pid': pid,
      'bootNonce': bootNonce,
      'corpusSha256': corpusSha256,
      'positiveCases': positiveNames.length,
      'protectedRejections': rejectionNames.length,
      'cases': receipts,
    }),
    flush: true,
  );
  stdout.writeln(
    jsonEncode({
      'event': 'legacy-corpus-$mode-complete',
      'pid': pid,
      'bootNonce': bootNonce,
      'cases': receipts.length,
    }),
  );
}
