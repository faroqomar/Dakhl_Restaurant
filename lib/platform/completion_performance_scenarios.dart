import 'dart:convert';
import 'dart:io';

import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_repository.dart';
import '../app/accounts_store.dart';
import '../catalog/catalog_read_model.dart';
import '../inventory/inventory_commands.dart';
import '../parties/parties_view_model.dart';
import '../sales/ticket_workspace.dart';
import '../settings/account_settings_controller.dart';

const completionPerformanceCases = {
  'catalog.lookup',
  'inventory.post_movement',
  'workspace.hold',
  'workspace.resume',
  'settings.save',
  'parties.save_supplier',
  'parties.save_material',
};

/// Fixed synthetic workload, not the maximum supported account size.
const completionWorkload = {
  'id': 'completion-v1',
  'products': 1000,
  'stockEntries': 1000,
  'suppliers': 100,
  'materials': 100,
  'heldDrafts': 39,
  'linesPerDraft': 4,
};

final class CompletionPerformanceOptions {
  const CompletionPerformanceOptions(
    this.operationId,
    this.iterations,
    this.runId,
  );
  final String operationId, runId;
  final int iterations;
  factory CompletionPerformanceOptions.parse(List<String> args) {
    final values = <String, String>{};
    for (var i = 0; i < args.length; i += 2) {
      if (i + 1 >= args.length ||
          !{'--case', '--iterations', '--run-id'}.contains(args[i]) ||
          values.containsKey(args[i])) {
        throw const FormatException('Invalid nonvisual benchmark arguments.');
      }
      values[args[i]] = args[i + 1];
    }
    final operation = values['--case'] ?? '';
    final iterations = int.tryParse(values['--iterations'] ?? '1') ?? 0;
    final runId = values['--run-id'] ?? 'local';
    if (!completionPerformanceCases.contains(operation) ||
        iterations < 1 ||
        iterations > 100 ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(runId)) {
      throw const FormatException('Unsupported nonvisual benchmark options.');
    }
    return CompletionPerformanceOptions(operation, iterations, runId);
  }
}

TicketDraft _ticket(String id, {bool empty = false}) => TicketDraft(
  id: id,
  date: '2026-01-01',
  orderType: 'سفري',
  discount: '',
  note: 'Synthetic benchmark',
  lines: empty
      ? []
      : [
          for (var i = 0; i < 4; i++)
            TicketLine(
              productId: 'product-$i',
              quantityUnits: BigInt.from(1000),
              price: 1000,
            ),
        ],
);

void _ack(CapabilityResult<Object?> result) {
  if (result is! CapabilitySuccess) {
    throw StateError('Benchmark command not acknowledged.');
  }
}

/// Owns only its fresh temporary real-adapter directory. Fixture setup, reopen
/// verification and cleanup are outside elapsed command samples.
final class CompletionPerformanceFixture {
  CompletionPerformanceFixture._(this.directory, this.operation) {
    store = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ),
    );
    repository = AccountsRepository(store: store);
  }
  final Directory directory;
  final String operation;
  late final AppAccountsStore store;
  late final AccountsRepository repository;
  late final TicketWorkspaceController workspace;
  late final AccountSettingsController settings;
  late final PartiesViewModel parties;
  late final SupplierDraft supplier;
  late final MaterialDraft material;
  late final CatalogReadModel catalog;
  List<String>? lookupIds;
  bool _prepared = false;

  static Future<CompletionPerformanceFixture> create(
    String runId,
    String operation,
  ) async {
    CompletionPerformanceOptions.parse([
      '--case',
      operation,
      '--run-id',
      runId,
    ]);
    final directory = await Directory.systemTemp.createTemp(
      'dakhl-completion-bench-$runId-$pid-',
    );
    final fixture = CompletionPerformanceFixture._(directory, operation);
    try {
      await fixture._prepare();
      return fixture;
    } on Object {
      await fixture.close();
      rethrow;
    }
  }

  Future<void> _prepare() async {
    _ack(await repository.open());
    final raw = Map<String, Object?>.from(repository.codec.empty().toJson());
    final category = ((raw['categories'] as List).first as Map)['id'];
    raw['products'] = [
      for (var i = 0; i < 1000; i++)
        {
          'id': 'product-$i',
          'name': 'Synthetic product $i',
          'code': 'CODE-$i',
          'unit': 'piece',
          'price': 1000,
          'group': 'group-${i % 10}',
          'minStock': 2,
          'trackStock': true,
          'archived': false,
        },
    ];
    raw['stockEntries'] = [
      for (var i = 0; i < 1000; i++)
        {
          'id': 'opening-$i',
          'productId': 'product-$i',
          'quantity': 100,
          'date': '2026-01-01',
          'kind': 'opening',
          'note': '',
          'createdAt': '2026-01-01T00:00:00Z',
        },
    ];
    raw['suppliers'] = [
      for (var i = 0; i < 100; i++)
        {
          'id': 'supplier-$i',
          'name': 'Synthetic supplier $i',
          'phone': '',
          'note': '',
          'categoryId': category,
          'openingBalance': 0,
          'materials': <Object?>[],
        },
    ];
    raw['materials'] = [
      for (var i = 0; i < 100; i++)
        {
          'id': 'material-$i',
          'name': 'Synthetic material $i',
          'unit': 'bag',
          'priceCarton': 1000,
          'pricePiece': 100,
          'archived': false,
        },
    ];
    _ack(await repository.save(repository.codec.decodeJson(raw)));
    final initial = TicketWorkspace(
      active: _ticket('active'),
      held: [
        for (var i = 0; i < 39; i++)
          HeldTicket(
            id: 'held-$i',
            label: 'Synthetic $i',
            savedAt: '2026-01-01T00:00:00Z',
            draft: _ticket('draft-$i'),
          ),
      ],
      form: {'unrelated': 'retain'},
    );
    _ack(
      await repository.saveWorkspace(
        initial.toEnvelope(),
        repository.snapshot!.fence,
      ),
    );
    workspace = TicketWorkspaceController(repository);
    _ack(await workspace.load(_ticket('unused')));
    settings = AccountSettingsController(repository);
    settings.replace(
      settings.values.copyWith(name: 'Synthetic updated restaurant'),
    );
    parties = PartiesViewModel(repository);
    _prepared = true;
    supplier = parties.editSupplier('supplier-99')!
      ..note = 'Synthetic updated metadata';
    material = parties.editMaterial('material-99')!..pricePiece = 200;
    // Lookup measures filtering/pagination over a prepared immutable read model.
    // Stock projection, codec validation and model construction are excluded.
    catalog = CatalogReadModel.fromAccount(
      repository.document!,
      balanceUnitsByProduct: {
        for (var i = 0; i < 1000; i++) 'product-$i': BigInt.from(100000),
      },
    );
  }

  Future<void> run() async {
    switch (operation) {
      case 'catalog.lookup':
        lookupIds = catalog
            .sales(query: 'CODE-999', group: 'group-9')
            .items
            .map((p) => p.id)
            .toList();
      case 'inventory.post_movement':
        _ack(
          await InventoryCommands(repository).postMovement(
            InventoryMovement(
              id: 'restock',
              productId: 'product-999',
              quantityUnits: BigInt.from(1000),
              effectiveDate: DateOnly.parse(
                '2026-01-02',
                minimumYear: 1000,
                maximumYear: 9999,
              ),
              kind: StockEntryKind.restock,
              createdAt: '2026-01-02T00:00:00Z',
            ),
            expected: repository.snapshot!,
          ),
        );
      case 'workspace.hold':
        _ack(
          await workspace.hold(
            label: 'Synthetic active',
            heldId: 'held-new',
            fresh: _ticket('fresh', empty: true),
            savedAt: '2026-01-02T00:00:00Z',
          ),
        );
      case 'workspace.resume':
        _ack(
          await workspace.resume(
            'held-38',
            swapId: 'swapped',
            swapLabel: 'Synthetic active',
            savedAt: '2026-01-02T00:00:00Z',
          ),
        );
      case 'settings.save':
        _ack(await settings.save());
      case 'parties.save_supplier':
        _ack(await parties.saveSupplier(supplier));
      case 'parties.save_material':
        _ack(await parties.saveMaterial(material));
      default:
        throw StateError('Unsupported nonvisual operation.');
    }
  }

  /// Assertions outside the elapsed interval also run in the profile producer.
  Future<void> verifyDurable() async {
    bool correct = switch (operation) {
      'catalog.lookup' => lookupIds?.join(',') == 'product-999',
      'inventory.post_movement' =>
        (repository.document!.toJson()['stockEntries'] as List).length == 1001,
      'workspace.hold' =>
        workspace.state!.held.length == 40 &&
            workspace.state!.active.id == 'fresh',
      'workspace.resume' =>
        workspace.state!.held.length == 39 &&
            workspace.state!.active.id == 'draft-38' &&
            workspace.state!.held.last.draft.id == 'active',
      'settings.save' =>
        repository.document!.preferences.restaurant['name'] ==
                'Synthetic updated restaurant' &&
            !settings.isDirty,
      'parties.save_supplier' =>
        parties.suppliers.last.note == 'Synthetic updated metadata',
      'parties.save_material' => parties.materials.last.pricePiece == 200,
      _ => false,
    };
    if (!correct) throw StateError('Benchmark postcondition failed.');
    final account = jsonEncode(repository.document!.toJson());
    final workspacePayload = repository.workspaceSnapshot!.payload;
    await store.close();
    final reopenedStore = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ),
    );
    try {
      final reopened = AccountsRepository(store: reopenedStore);
      _ack(await reopened.open());
      _ack(await reopened.readWorkspace());
      if (jsonEncode(reopened.document!.toJson()) != account ||
          reopened.workspaceSnapshot?.payload != workspacePayload) {
        throw StateError('Benchmark durable readback mismatch.');
      }
    } finally {
      await reopenedStore.close();
    }
  }

  Future<void> close() async {
    if (_prepared) parties.dispose();
    await store.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
