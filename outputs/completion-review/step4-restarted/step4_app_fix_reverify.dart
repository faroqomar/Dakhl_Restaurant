
import 'dart:async';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/settings/account_settings.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';
import 'package:dakhl_restaurant/reports/sales_report.dart';
void check(bool condition,String label) {if(!condition) throw StateError(label); print('PASS $label');}
void rejected(void Function() call,String label){try{call();}on FormatException {print('PASS $label');return;}on DomainValidationException {print('PASS $label');return;}throw StateError('accepted $label');}
TicketDraft draft(String id,String date,{bool populated=false})=>TicketDraft(id:id,date:date,orderType:'',discount:'',note:'',lines:populated?[TicketLine(productId:'synthetic',quantityUnits:BigInt.from(1000),price:1)]:[]);
Future<void> main()async{
const codec=LegacyAccountCodec();final account=codec.empty();
for(final input in ['\u0085','\uFEFF\u0085\uFEFF','\uFEFF']){
 final settings=AccountSettingsDraft(account);settings.replace(settings.values.copyWith(name:input,contact:input,footer:input));
 final saved=settings.prepareSave(account).preferences.restaurant;final expected=input=='\uFEFF'?'':'\u0085';
 for(final key in ['name','contact','footer']) check(saved[key]==expected,'settings $key input ${input.runes.toList()}');
}
for(final date in ['0001-01-01','0999-12-31'])rejected(()=>draft('d',date),'ticket rejects $date');
for(final date in ['1000-01-01','9999-12-31'])check(draft('d',date).date==date,'ticket accepts $date');
rejected(()=>SalesReport.build(account,filter:const SalesHistoryFilter(from:'2026-02-01',to:'2026-01-01')),'report reversed range');
rejected(()=>SalesReport.build(account,filter:const SalesHistoryFilter(from:'0999-12-31')),'report low from');
rejected(()=>SalesReport.build(account,filter:const SalesHistoryFilter(to:'0999-12-31')),'report low to');
check(SalesReport.build(account,filter:const SalesHistoryFilter(from:'1000-01-01',to:'9999-12-31')).sales.isEmpty,'report valid bounds');
for(final (label,expected) in [('\uFEFF\u0085\uFEFF','\u0085'),('\uFEFF','طلب 1')]){
 final store=FixtureStore();final repo=AccountsRepository(store:store);await repo.open();await repo.save(account);
 final controller=TicketWorkspaceController(repo);await controller.load(draft('a','2026-11-07',populated:true));
 check(await controller.hold(label:label,heldId:'h',fresh:draft('b','2026-11-07'),savedAt:'2026-11-07T10:00:00Z') is CapabilitySuccess<void>,'hold succeeds ${label.runes.toList()}');
 final reopened=AccountsRepository(store:store);await reopened.open();final restored=TicketWorkspaceController(reopened);await restored.load(draft('unused','2026-11-07'));
 check(restored.state!.held.single.label==expected,'held label persisted ${label.runes.toList()}');
}
}
final class FixtureStore implements LocalDocumentWorkspaceStore {
  DocumentSnapshot? document;
  PreviousDocument? previous;
  String? readFailure, writeFailure;
  int writes = 0,
      archives = 0,
      workspaceWrites = 0,
      resumes = 0,
      previousReads = 0;
  bool throwAfterCommit = false;
  WorkspaceSnapshot? workspace;
  WorkspaceState? workspaceReadOverride;
  String? workspaceWriteFailure;
  Completer<CapabilityResult<DocumentSnapshot?>>? delayedRead;
  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async =>
      delayedRead?.future ??
      (readFailure == null
          ? CapabilitySuccess(document)
          : CapabilityFailure(readFailure!, 'Fixture read failure'));
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    writes++;
    if (writeFailure != null) {
      return CapabilityFailure(writeFailure!, 'Fixture failure');
    }
    if (expected != document) {
      return const CapabilityFailure('stale_revision', 'Stale');
    }
    final old = document;
    if (old != null) {
      previous = PreviousDocument(snapshot: old, identity: 'backup');
    }
    document = DocumentSnapshot(
      payload: payload,
      revision: (old?.revision ?? 0) + 1,
      fence: StorageFence(
        storeId: 'store',
        generation: replaceGeneration
            ? 'generation-$writes'
            : old?.fence.generation ?? 'first',
      ),
      writeToken: writeToken,
    );
    if (throwAfterCommit) throw StateError('Lost acknowledgement');
    return CapabilitySuccess(document!);
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) {
    resumes++;
    return writeDocument(payload, writeToken: writeToken);
  }

  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(
    StorageFence fence,
  ) async => CapabilitySuccess(
    workspaceReadOverride ?? WorkspaceState(fence: fence, snapshot: workspace),
  );
  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) async {
    workspaceWrites++;
    if (document?.fence != fence || expectedRevision != workspace?.revision) {
      return const CapabilityFailure('conflict', 'Stale fixture authority');
    }
    if (workspaceWriteFailure != null &&
        workspaceWriteFailure != 'commit_unknown') {
      return CapabilityFailure(
        workspaceWriteFailure!,
        'Definite fixture failure',
      );
    }
    workspace = WorkspaceSnapshot(
      payload: payload,
      revision: (workspace?.revision ?? 0) + 1,
      fence: fence,
      writeToken: writeToken,
    );
    if (workspaceWriteFailure != null) {
      return CapabilityFailure(
        workspaceWriteFailure!,
        'Fixture acknowledgement',
      );
    }
    return CapabilitySuccess(workspace!);
  }

  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() async {
    previousReads++;
    return CapabilitySuccess(previous);
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument selected, {
    required String payload,
    required String writeToken,
  }) async {
    writes++;
    document = DocumentSnapshot(
      payload: payload,
      revision: 1,
      fence: const StorageFence(storeId: 'recovered', generation: 'fresh'),
      writeToken: writeToken,
    );
    return CapabilitySuccess(document!);
  }

  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async =>
      const CapabilitySuccess(null);
  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) async {
    archives++;
    return const CapabilitySuccess('source');
  }

  @override
  Future<void> close() async {}
}

