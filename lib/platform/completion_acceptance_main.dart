import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';
import 'package:path_provider/path_provider.dart';

import '../accounting/restaurant_journal_mapper.dart';
import '../app/accounts_store.dart';
import '../app/bootstrap.dart';
import '../app/portable_restaurant_host.dart';
import '../app/source_collation_runtime.dart';
import '../sales/ticket_workspace.dart';
import 'review_performance_scenarios.dart';

/// Opt-in native acceptance composition. Never resolves normal account stores.
/// A marked synthetic child persists across process restart/update acceptance.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const identity = String.fromEnvironment(
    'DAKHL_ACCEPTANCE_ID',
    defaultValue: 'remaining-20261108-v1',
  );
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(identity)) {
    throw StateError('Invalid acceptance identity.');
  }
  final support = await getApplicationSupportDirectory();
  await support.create(recursive: true);
  final supportPath = await support.resolveSymbolicLinks();
  final root = Directory('$supportPath/dakhl-acceptance-$identity');
  final type = await FileSystemEntity.type(root.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory) {
    throw StateError('Unsafe acceptance directory.');
  }
  await root.create(recursive: true);
  final canonical = await root.resolveSymbolicLinks();
  if (canonical != root.absolute.path) {
    throw StateError('Redirected acceptance directory.');
  }
  final marker = File('${root.path}/.synthetic-acceptance-owner');
  final markerType = await FileSystemEntity.type(
    marker.path,
    followLinks: false,
  );
  if (markerType != FileSystemEntityType.notFound &&
      markerType != FileSystemEntityType.file) {
    throw StateError('Unsafe acceptance marker.');
  }
  final owner = 'dakhl-completion-acceptance-v1:$identity\n';
  if (await marker.exists()) {
    if (await marker.readAsString() != owner) {
      throw StateError('Unknown acceptance owner.');
    }
  } else {
    if (!await root.list().isEmpty) {
      throw StateError('Unmarked acceptance directory.');
    }
    await marker.create(exclusive: true);
    await marker.writeAsString(owner, flush: true);
  }
  final accountsRoot = await Directory('${root.path}/accounts').create();
  final store = AppAccountsStore(
    openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
      directoryPath: accountsRoot.path,
    ),
  );
  final preferences = AppPreferencesStore(
    openStore: () => PowerSyncLocalPreferencesStore.open(
      databasePath: '${root.path}/shell.sqlite',
    ),
    closeStore: (value) async {
      if (value is PowerSyncLocalPreferencesStore) {
        await value.close();
      }
    },
  );
  var read = await store.readDocument();
  if (read is! CapabilitySuccess<DocumentSnapshot?>) {
    throw StateError('Acceptance store unavailable.');
  }
  var snapshot = read.value;
  if (snapshot == null) {
    final seed = await ReviewPerformanceFixture.create(
      identity,
      'review.sales.checkout',
    );
    try {
      final write = await store.writeDocument(
        seed.snapshot.payload,
        writeToken: 'acceptance-initial-$identity',
      );
      if (write is! CapabilitySuccess<DocumentSnapshot>) {
        throw StateError('Acceptance initialization failed.');
      }
      snapshot = write.value;
    } finally {
      await seed.close();
    }
  }
  final initial = snapshot;
  final runtime = SourceCollationRuntime.loadBundled();
  final host = GlobalKey<PortableRestaurantHostState>();
  var ticket = 0;
  runApp(
    PortableRestaurantHost(
      key: host,
      store: store,
      initialSnapshot: initial,
      preferencesStore: preferences,
      acceptedOpeningEquityAccountId:
          RestaurantAccountProfile().openingEquityAccountId,
      compareText: runtime?.events.compare ?? (a, b) => a.compareTo(b),
      compareMaterialNames: runtime?.materialNames.compare,
      freshTicket: () => TicketDraft(
        id: 'acceptance-${DateTime.now().microsecondsSinceEpoch}-${ticket++}',
        date: '2026-11-08',
        orderType: 'سفري',
        discount: '',
        note: '',
        lines: const [],
      ),
      transfer: NativeFileTransfer(
        maxBytes: 20 * 1024 * 1024,
        fileName: 'dakhl-$identity-synthetic.json',
        mimeType: 'application/json',
      ),
    ),
  );
  // Native dialog/lifecycle evidence only, outside any performance measurement.
  // Only an acknowledged synthetic snapshot can update the evidence file.
  String? lastToken;
  var writing = false;
  Timer.periodic(const Duration(seconds: 1), (_) async {
    final current = host.currentState?.committedSnapshot;
    if (current == null || writing || current.writeToken == lastToken) {
      return;
    }
    writing = true;
    try {
      await File('${root.path}/acknowledged.json')
          .writeAsString(current.payload, flush: true);
      final evidence = {
        'event': 'acceptance_acknowledged',
        'fixture': identity,
        'pid': pid,
        'root': root.path,
        'revision': current.revision,
        'writeToken': current.writeToken,
        'fence': {
          'storeId': current.fence.storeId,
          'generation': current.fence.generation,
        },
        'icuBundled': runtime != null,
      };
      await File('${root.path}/launch-evidence.json')
          .writeAsString(jsonEncode(evidence), flush: true);
      stdout.writeln(jsonEncode(evidence));
      lastToken = current.writeToken;
    } finally {
      writing = false;
    }
  });
}
