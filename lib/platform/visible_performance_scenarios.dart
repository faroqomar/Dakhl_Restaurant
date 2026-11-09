import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/portable_journal_codec.dart';
import '../accounts/accounts_view_model.dart';
import '../accounts/workspace_document.dart';
import '../app/accounts_store.dart';
import '../app/restaurant_operations_session.dart';
import '../catalog/catalog_view_model.dart';
import '../catalog/inventory_surface.dart';
import '../parties/parties_surface.dart';
import '../sales/sales_surface.dart';
import '../sales/ticket_workspace.dart';
import '../ui/components.dart';
import 'review_performance_scenarios.dart';

const visiblePerformanceCases = {
  'orders.process',
  'catalog.add_item',
  'sales.add_item',
  'visible.suppliers.ledger',
};

/// Explicitly synthetic ordinal comparison. This benchmark does not qualify ICU.
int _compare(String a, String b) => a.compareTo(b);

final class VisiblePerformanceOptions {
  const VisiblePerformanceOptions(
    this.operationId,
    this.iterations,
    this.runId,
  );
  final String operationId, runId;
  final int iterations;
  factory VisiblePerformanceOptions.parse(List<String> args) {
    final values = <String, String>{};
    for (var i = 0; i < args.length; i += 2) {
      if (i + 1 >= args.length ||
          !{'--case', '--iterations', '--run-id'}.contains(args[i]) ||
          values.containsKey(args[i])) {
        throw const FormatException('Invalid visible benchmark options.');
      }
      values[args[i]] = args[i + 1];
    }
    final operation = values['--case'] ?? '';
    final count = int.tryParse(values['--iterations'] ?? '1') ?? 0;
    final run = values['--run-id'] ?? 'local';
    if (!visiblePerformanceCases.contains(operation) ||
        count < 1 ||
        count > 100 ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(run)) {
      throw const FormatException('Unsupported visible benchmark options.');
    }
    return VisiblePerformanceOptions(operation, count, run);
  }
}

T _ack<T>(CapabilityResult<T> result) {
  if (result is! CapabilitySuccess<T>) {
    throw StateError('Visible benchmark capability was not acknowledged.');
  }
  return result.value;
}

TicketDraft _fresh(String id) => TicketDraft(
  id: id,
  date: '2026-11-07',
  orderType: 'سفري',
  discount: '0',
  note: '',
  lines: const [],
);

/// Owns an isolated, real adapter and the app's actual surface/controllers.
/// The existing review seed supplies 20 products and 200 historical cash rows;
/// ledger adds 200 historical invoices. No normal storage location is resolved.
final class VisiblePerformanceFixture {
  VisiblePerformanceFixture._(this.seed, this.operation);
  final ReviewPerformanceFixture seed;
  final String operation;
  late final RestaurantOperationsSession session;
  late final CatalogViewModel catalog;
  late final AccountsViewModel accounts;
  late final CatalogEditSession _edit;
  late final String _beforePayload;
  late final String? _beforeWorkspace;
  bool _disposed = false;
  bool _sessionReady = false, _catalogReady = false, _accountsReady = false;
  static const productName = 'Visible benchmark product';

  static Future<VisiblePerformanceFixture> create(
    String runId,
    String operation,
  ) async {
    VisiblePerformanceOptions.parse(['--case', operation, '--run-id', runId]);
    final seed = await ReviewPerformanceFixture.create(
      runId,
      operation == 'visible.suppliers.ledger'
          ? 'review.suppliers.ledger_query'
          : 'review.sales.checkout',
    );
    final fixture = VisiblePerformanceFixture._(seed, operation);
    try {
      fixture.session = _ack(
        await RestaurantOperationsSession.open(
          store: seed.store,
          snapshot: seed.snapshot,
          compareText: _compare,
          fresh: _fresh('visible-active'),
        ),
      );
      fixture._sessionReady = true;
      fixture.accounts = AccountsViewModel(
        repository: fixture.session.metadataRepository,
      );
      fixture._accountsReady = true;
      await fixture.accounts.initialize();
      if (fixture.accounts.state != AccountsState.saved) {
        throw StateError('Visible account did not initialize.');
      }
      fixture.catalog = CatalogViewModel(fixture.session.metadataRepository);
      fixture._catalogReady = true;
      fixture._edit = fixture.catalog.beginEdit();
      if (operation == 'orders.process') {
        _ack(await fixture.session.sales.addProduct('product-0'));
      }
      if (operation == 'catalog.add_item') {
        fixture.catalog.filter(query: 'VISIBLE-CREATE');
      }
      fixture._beforePayload = _ack(await seed.store.readDocument())!.payload;
      fixture._beforeWorkspace = _ack(
        await seed.store.readWorkspace(fixture.session.snapshot.fence),
      ).snapshot?.payload;
      return fixture;
    } on Object {
      await fixture.close();
      rethrow;
    }
  }

  Widget surface() => switch (operation) {
    'catalog.add_item' => InventorySurface(
      model: catalog,
      accounts: accounts,
      today: DateOnly.parse('2026-11-07', minimumYear: 1000, maximumYear: 9999),
    ),
    'visible.suppliers.ledger' => PartiesSurface(
      routeId: 'suppliers',
      operations: session.parties,
      compareText: _compare,
      compareMaterialNames: _compare,
    ),
    _ => SalesSurface(session: session.sales),
  };

  /// Only the real command/callback is timed. No pointer/keyboard dispatch,
  /// form typing or paid-confirmation modal is included.
  Future<void> run() async {
    switch (operation) {
      case 'orders.process':
        _ack(
          await session.sales.checkout(
            fresh: _fresh('visible-after-sale'),
            operationId: 'visible-checkout',
            journalId: 'visible-sale-journal',
            recordedAt: '2026-11-07T12:00:00Z',
          ),
        );
        _ack(await session.synchronize());
        return;
      case 'sales.add_item':
        _ack(await session.sales.addProduct('product-0'));
        _ack(await session.synchronize());
        return;
      case 'catalog.add_item':
        _ack(
          await catalog.createProduct({
            'id': 'visible-created-product',
            'name': productName,
            'code': 'VISIBLE-CREATE',
            'unit': 'piece',
            'group': 'Synthetic',
            'price': 1000,
            'minStock': 0,
            'trackStock': false,
            'archived': false,
          }, session: _edit),
        );
        _ack(await session.synchronize());
        return;
      case 'visible.suppliers.ledger':
        final buttons = visibleWidgets<DakhlButton>()
            .where((b) => b.label == 'كشف الحساب' && b.onPressed != null)
            .toList();
        if (buttons.length != 1) {
          throw StateError('Ledger action is ambiguous.');
        }
        buttons.single.onPressed!();
        return;
      default:
        throw StateError('Unknown visible operation.');
    }
  }

  /// Checks actual built surface state after the raster boundary. This is not a
  /// substitute for the native frame timing event in the profile producer.
  void verifyRendered() {
    if (operation == 'catalog.add_item') {
      if (!visibleWidgets<Text>().any((t) => t.data == productName)) {
        throw StateError('Created product did not reach the rendered surface.');
      }
    } else if (operation == 'visible.suppliers.ledger') {
      final rows = visibleWidgets<ListTile>()
          .where(
            (t) =>
                t.title is Text &&
                ((t.title! as Text).data?.contains(' · invoice') ?? false),
          )
          .length;
      if (rows != 200) throw StateError('Ledger did not render all 200 rows.');
    } else {
      final buttons = visibleWidgets<DakhlButton>()
          .where((b) => b.label == 'تأكيد البيع النقدي')
          .toList();
      final expectedEnabled = operation == 'sales.add_item';
      if (buttons.length != 1 ||
          (buttons.single.onPressed != null) != expectedEnabled) {
        throw StateError('Rendered cart state does not match the command.');
      }
    }
  }

  Future<void> verifyDurable() async {
    final snapshot = _ack(await seed.store.readDocument())!;
    final workspace = _ack(await seed.store.readWorkspace(snapshot.fence));
    final state = const PortableJournalCodec().decodeState(snapshot.payload);
    final raw = state.account.toJson();
    final persistedTicket = workspace.snapshot == null
        ? null
        : TicketWorkspace.fromEnvelope(
            WorkspaceDocument.decode(workspace.snapshot!.payload),
            _fresh('invalid'),
          );
    if (operation == 'orders.process') {
      if ((raw['sales']! as List).length != 1 ||
          state.journals.length != 2 ||
          state.receipts.length != 1 ||
          state.receipts.single.identity.operationId != 'visible-checkout' ||
          session.sales.active?.id != 'visible-after-sale' ||
          session.sales.active!.lines.isNotEmpty ||
          persistedTicket?.active.id != 'visible-after-sale' ||
          persistedTicket!.active.lines.isNotEmpty) {
        throw StateError('Visible checkout postcondition failed.');
      }
    } else if (operation == 'catalog.add_item') {
      if ((raw['products']! as List).length != 21 ||
          !(raw['products']! as List).any(
            (p) =>
                p['id'] == 'visible-created-product' &&
                p['name'] == productName,
          ) ||
          state.journals.length != 1 ||
          state.receipts.isNotEmpty ||
          workspace.snapshot?.payload != _beforeWorkspace) {
        throw StateError('Visible catalog postcondition failed.');
      }
      final expected = jsonDecode(_beforePayload) as Map<String, dynamic>;
      final actual = jsonDecode(snapshot.payload) as Map<String, dynamic>;
      final expectedAccount = expected['account'] as Map<String, dynamic>;
      final actualAccount = actual['account'] as Map<String, dynamic>;
      final retainedProducts = (actualAccount['products']! as List)
          .where((p) => p['id'] != 'visible-created-product')
          .toList();
      if (jsonEncode(retainedProducts) !=
          jsonEncode(expectedAccount['products'])) {
        throw StateError('Catalog creation changed an existing product.');
      }
      expectedAccount['products'] = actualAccount['products'];
      if (jsonEncode(expected) != jsonEncode(actual)) {
        throw StateError('Catalog creation changed unrelated envelope state.');
      }
    } else if (operation == 'sales.add_item') {
      if (snapshot.payload != _beforePayload || workspace.snapshot == null) {
        throw StateError(
          'Cart edit changed account state or missed workspace.',
        );
      }
      final ticket = persistedTicket!.active;
      if (ticket.id != 'visible-active' ||
          ticket.lines.length != 1 ||
          ticket.lines.single.productId != 'product-0' ||
          ticket.lines.single.quantityUnits != BigInt.from(1000)) {
        throw StateError('Cart edit did not persist its exact line.');
      }
    } else if (snapshot.payload != _beforePayload ||
        workspace.snapshot?.payload != _beforeWorkspace) {
      throw StateError('Ledger rendering wrote state.');
    }
    final expectedDocument = snapshot.payload;
    final expectedWorkspace = workspace.snapshot?.payload;
    await seed.store.close();
    final reopened = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: seed.directory.path,
      ),
    );
    try {
      final document = _ack(await reopened.readDocument())!;
      final draft = _ack(await reopened.readWorkspace(document.fence));
      if (document.payload != expectedDocument ||
          draft.snapshot?.payload != expectedWorkspace) {
        throw StateError('Visible operation failed exact durable reopen.');
      }
    } finally {
      await reopened.close();
    }
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    if (_catalogReady) catalog.dispose();
    if (_accountsReady) accounts.dispose();
    if (_sessionReady) session.dispose();
    await seed.close();
  }
}

/// Traverses the actual mounted element tree; never synthesizes a substitute UI.
List<T> visibleWidgets<T extends Widget>() {
  final result = <T>[];
  void visit(Element element) {
    if (element.widget is T) result.add(element.widget as T);
    element.visitChildElements(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return result;
}
