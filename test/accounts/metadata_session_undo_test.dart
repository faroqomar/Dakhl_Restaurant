import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/financial_session_undo.dart';
import 'package:dakhl_restaurant/accounting/expense_editor_controller.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/metadata_session_undo.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/workspace_document.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';

import '../sales/sales_workflow_session_test.dart' show fixture, fresh;

const _legacy = LegacyAccountCodec();
const _portable = PortableJournalCodec();

void main() {
  test('metadata compensation changes only captured fields over later financial state', () async {
    final (store, snapshot) = await fixture();
    final session = ((await RestaurantOperationsSession.open(
      store: store,
      snapshot: snapshot,
      compareText: (a, b) => a.compareTo(b),
      fresh: fresh('active'),
    )) as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);
    final before = _portable.decodeState(store.document!.payload);
    final raw = before.account.toJson();
    final edited = _legacy.decodeJson({
      ...raw,
      'products': [
        {
          ...(raw['products'] as List).single as Map<String, Object?>,
          'name': 'Renamed',
        },
      ],
    });
    expect(
      await session.metadataRepository.save(edited),
      isA<CapabilitySuccess>(),
    );
    await session.synchronize();
    final after = _portable.decodeState(store.document!.payload);
    final expense =
        ExpenseEditorController(spending: session.spending, date: '2026-11-07')
          ..amount = '500'
          ..source = FundingSource.daily;
    expect(await expense.save(), isA<CapabilitySuccess>());
    await session.synchronize();
    final latest = session.metadataRepository.document!.toJson();
    expect(
      await session.metadataRepository.save(
        _legacy.decodeJson({
          ...latest,
          'products': [
            {
              ...(latest['products'] as List).single as Map<String, Object?>,
              'price': 1200,
            },
          ],
        }),
      ),
      isA<CapabilitySuccess>(),
    );
    await session.synchronize();
    final current = _portable.decodeState(store.document!.payload);
    final plan = MetadataUndoPlan.prepare(
      before: before,
      after: after,
      current: current,
    );
    final product = (plan.candidate.toJson()['products'] as List).single as Map;
    expect(product['name'], 'Product');
    expect(product['price'], 1200);
    expect(plan.candidate.days, current.account.days);
    expect(
      await session.metadataRepository.save(plan.candidate),
      isA<CapabilitySuccess>(),
    );
    final saved = _portable.decodeState(store.document!.payload);
    expect(saved.copyWith(account: current.account).toJson(), current.toJson());
    expect(saved.account.days, current.account.days);
  });
  test('controller undo preserves dirty workspace and resolves exact uncertain compensation', () async {
    final (store, snapshot) = await fixture();
    final session = ((await RestaurantOperationsSession.open(
      store: store,
      snapshot: snapshot,
      compareText: (a, b) => a.compareTo(b),
      fresh: fresh('active'),
    )) as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);
    final repository = session.metadataRepository;
    await repository.readWorkspace();
    expect(
      await repository.saveWorkspace(
        WorkspaceDocument(
          active: const {'draft': 'keep'},
          form: const {'note': 'unsaved'},
          held: const [],
        ),
        repository.snapshot!.fence,
      ),
      isA<CapabilitySuccess<void>>(),
    );
    final workspace = store.workspace;
    final workspaceWrites = store.workspaceWrites;
    final undo = FinancialSessionUndoController(
      readSnapshot: () => session.metadataBridge.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(undo.dispose);
    final before = session.metadataBridge.snapshot;
    final raw = repository.document!.toJson();
    expect(
      await repository.save(
        _legacy.decodeJson({
          ...raw,
          'preferences': {
            ...raw['preferences'] as Map<String, Object?>,
            'restaurant': {'name': 'Changed', 'contact': '', 'footer': ''},
          },
        }),
      ),
      isA<CapabilitySuccess>(),
    );
    await session.synchronize();
    final after = session.metadataBridge.snapshot;
    expect(
      undo.registerTransition(
        before: before,
        after: after,
        adapter: MetadataSessionUndoAdapter(
          repository: repository,
          bridge: session.metadataBridge,
        ),
      ),
      isA<CapabilitySuccess<void>>(),
    );
    store.throwAfterCommit = true;
    expect(await undo.undo(), isA<CapabilityFailure<void>>());
    expect(undo.needsReadback, true);
    expect(undo.length, 1);
    final committed = store.document!.revision;
    store.throwAfterCommit = false;
    expect(await undo.undo(), isA<CapabilitySuccess<void>>());
    expect(store.document!.revision, committed);
    expect(undo.length, 0);
    expect(repository.document!.preferences.restaurant['name'], '');
    expect(store.workspace, same(workspace));
    expect(store.workspaceWrites, workspaceWrites);
    final restored = _portable.decodeState(store.document!.payload);
    final original = _portable.decodeState(before.payload);
    expect(
      restored.journals.map((j) => j.toJson()).toList(),
      original.journals.map((j) => j.toJson()).toList(),
    );
    expect(restored.receipts, original.receipts);
  });
  test('changed target field or financial transition refuses without source restoration', () async {
    final (_, snapshot) = await fixture();
    final before = _portable.decodeState(snapshot.payload);
    final raw = before.account.toJson();
    final after = before.copyWith(
      account: _legacy.decodeJson({
        ...raw,
        'products': [
          {
            ...(raw['products'] as List).single as Map<String, Object?>,
            'name': 'After',
          },
        ],
      }),
    );
    final current = after.copyWith(
      account: _legacy.decodeJson({
        ...raw,
        'products': [
          {
            ...(raw['products'] as List).single as Map<String, Object?>,
            'name': 'Later',
          },
        ],
      }),
    );
    expect(
      () => MetadataUndoPlan.prepare(
        before: before,
        after: after,
        current: current,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'code',
          'undo_metadata_conflict',
        ),
      ),
    );
    final financial = before.copyWith(
      account: _legacy.decodeJson({
        ...raw,
        'transactions': [
          {
            'id': 'cash',
            'date': '2026-11-07',
            'type': 'deposit',
            'amount': 100,
            'note': '',
            'createdAt': '2026-11-07T10:00:00Z',
          },
        ],
      }),
    );
    expect(
      () => MetadataUndoPlan.prepare(
        before: before,
        after: financial,
        current: financial,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'code',
          'metadata_financial_mutation_refused',
        ),
      ),
    );
  });
}
