import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounting/financial_session_undo.dart';
import '../accounting/deleted_party_restoration.dart';
import '../accounting/party_session_compensation.dart';
import '../accounting/source_record_order.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/account_document.dart';
import '../accounting/source_material_restoration.dart';
import '../accounting/journal_command_host.dart' show canonicalIdentity;
import '../accounting/restaurant_journal_payment_history.dart';
import '../accounting/restaurant_journal_invoice_correction_commands.dart';
import '../accounts/portable_journal_state.dart';
import '../catalog/catalog_formatters.dart';
import 'parties_operations_view_model.dart';
import 'purchase_proposal.dart';

/// Receipt-driven compensation using existing invoice/payment command owners.
/// A preview must restore the complete prior visible source before any write.
final class PartiesSessionUndoAdapter implements FinancialUndoAdapter {
  PartiesSessionUndoAdapter({required this.parties, required this.identity});
  final PartiesOperationsViewModel parties;
  final DurableCommandIdentity identity;
  static const supportedCommandTypes = {
    'purchase_invoice',
    'edit_purchase_invoice',
    'supplier_payment',
    'edit_supplier_payment',
    'delete_purchase_invoice',
    'delete_supplier_payment',
  };
  static const reason = 'تراجع عن التغيير السابق';
  @override
  String get label => 'آخر تغيير للموردين';
  static List<Map<String, Object?>> _rows(
    PortableJournalState state,
    String key,
    String id,
  ) => (state.account.toJson()[key]! as List)
      .map((e) => (e as Map).cast<String, Object?>())
      .where((e) => e['id'] == id)
      .toList();
  static Map<String, Object?> _source(PortableJournalState state) => {
    ...state.account.toJson(),
    'days': {
      for (final entry in state.account.days.entries)
        entry.key: ({...(entry.value! as Map).cast<String, Object?>()}
          ..remove('corrections')),
    },
  };
  static bool _sameSource(PortableJournalState a, PortableJournalState b) =>
      canonicalIdentity(_source(a)) == canonicalIdentity(_source(b));
  static void _requireRestored(
    DurableProposalEvaluation<PortableJournalState, dynamic> preview,
    AccountDocument expected,
  ) {
    if (preview.rejected) {
      throw FormatException(preview.rejectionCode ?? 'undo_not_reconciled');
    }
    if (preview.candidateState == null ||
        canonicalIdentity(_source(preview.candidateState!)) !=
            canonicalIdentity({
              ...expected.toJson(),
              'days': {
                for (final day in expected.days.entries)
                  day.key: ({...(day.value! as Map).cast<String, Object?>()}
                    ..remove('corrections')),
              },
            })) {
      throw const FormatException('undo_complete_source_restore_required');
    }
  }

  PortableJournalEntry? _activePayment(PortableJournalState state, String id) {
    for (final entry in state.journals.reversed) {
      if (entry.sourceRecordId == id &&
          RestaurantJournalPaymentHistory.validate(
            state: state,
            paymentId: id,
            mapper: parties.paymentCorrectionCommands.mapper,
            expectedActiveJournalId: entry.journal.id,
          )) {
        return entry;
      }
    }
    return null;
  }

  static AccountDocument _expected(
    PortableJournalState current,
    String key,
    String id,
    Map<String, Object?>? row,
    int position,
  ) {
    final rows = (current.account.toJson()[key]! as List)
        .cast<Map<String, Object?>>()
        .where((r) => r['id'] != id)
        .toList();
    if (row != null) rows.insert(position.clamp(0, rows.length), row);
    return const LegacyAccountCodec().decodeJson({
      ...current.account.toJson(),
      key: rows,
    });
  }

  static int _position(PortableJournalState state, String key, String id) =>
      (state.account.toJson()[key]! as List).indexWhere(
        (row) => (row as Map)['id'] == id,
      );
  @override
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) {
    if (!parties.postingEnabled) throw const FormatException('busy');
    if (before.accountLineage != after.accountLineage ||
        current.accountLineage != after.accountLineage ||
        current.accountLineage != parties.accountLineage ||
        !after.receipts.any(
          (r) =>
              r.identity == identity &&
              r.status == DurableCommandStatus.committed,
        )) {
      throw const FormatException('undo_missing_original_receipt');
    }
    if (!_sameSource(current, current.copyWith(account: parties.account))) {
      throw const FormatException('undo_source_changed');
    }
    final intent = (jsonDecode(identity.canonicalPayloadIdentity) as Map)
        .cast<String, Object?>();
    final kind = intent['commandType'];

    if (!supportedCommandTypes.contains(kind)) {
      throw const FormatException('undo_kind_not_supported');
    }
    final targetCollection = kind.toString().contains('invoice')
        ? 'invoices'
        : 'payments';
    final targetId =
        intent[targetCollection == 'invoices' ? 'invoiceId' : 'paymentId']!
            as String;
    if (canonicalIdentity({
          'rows': _rows(current, targetCollection, targetId),
        }) !=
        canonicalIdentity({'rows': _rows(after, targetCollection, targetId)})) {
      throw const FormatException('undo_source_changed');
    }
    final operation = CatalogFormatters.generateId('undo-party-op');
    final inverse = CatalogFormatters.generateId('undo-party-inverse');
    final replacement = CatalogFormatters.generateId('undo-party-replacement');
    final recordedAt = CatalogFormatters.currentIsoTimestamp();
    if (kind == 'delete_purchase_invoice' ||
        kind == 'delete_supplier_payment') {
      final invoice = kind == 'delete_purchase_invoice';
      final key = invoice ? 'invoices' : 'payments';
      final id = intent[invoice ? 'invoiceId' : 'paymentId']! as String;
      final old = _rows(before, key, id), now = _rows(current, key, id);
      if (old.length != 1 || now.isNotEmpty) {
        throw const FormatException('undo_source_changed');
      }
      final siblings = (current.account.toJson()[key]! as List)
          .cast<Map<String, Object?>>();
      final original = (before.account.toJson()[key]! as List)
          .cast<Map<String, Object?>>();
      final command = RestoreDeletedPartyCommand(
        kind: invoice ? DeletedPartyKind.invoice : DeletedPartyKind.payment,
        operationId: operation,
        accountLineage: current.accountLineage,
        expectedFence: parties.authorityFence,
        recordId: id,
        deletedJournalId: intent['expectedActiveJournalId']! as String,
        deleteInverseJournalId: intent['inverseJournalId']! as String,
        deleteOperationId: identity.operationId,
        replacementJournalId: replacement,
        sourceSnapshot: old.single,
        position: original.indexWhere((row) => row['id'] == id),
        expectedSiblingIds: siblings.map((row) => row['id']! as String),
        reason: reason,
        recordedAt: recordedAt,
        mapper: parties.restorationCommands.mapper,
      );
      _requireRestored(
        parties.restorationCommands.evaluate(command, current),
        _expected(current, key, id, old.single, command.position),
      );
      return FinancialUndoAttempt(() => parties.submitRestoration(command));
    }

    if (kind == 'purchase_invoice') {
      final id = intent['invoiceId']! as String;
      final rows = _rows(current, 'invoices', id);
      if (rows.length != 1 || _rows(before, 'invoices', id).isNotEmpty) {
        throw const FormatException('undo_source_changed');
      }
      final invoicePosting = parties.activeInvoicePosting(id);
      if (invoicePosting == null) {
        throw const FormatException('undo_missing_original_posting');
      }
      final children = <Map<String, Object?>>[];
      final immediate = (intent['immediatePayment'] as Map?)
          ?.cast<String, Object?>();
      if (immediate != null && (immediate['amount']! as int) > 0) {
        final paymentId = immediate['id']! as String;
        final payments = _rows(current, 'payments', paymentId);
        final posting = _activePayment(current, paymentId);
        if (payments.length != 1 || posting == null) {
          throw const FormatException('undo_missing_original_posting');
        }
        final child = parties.deletePaymentIntent(
          operationId: '$operation-payment',
          paymentId: paymentId,
          expectedActiveJournalId: posting.journal.id,
          expectedSource: payments.single,
          inverseJournalId: '$inverse-payment',
          reason: reason,
          recordedAt: recordedAt,
          profile: parties.paymentCorrectionCommands.mapper.profile,
        );
        children.add(
          (jsonDecode(child.canonicalPayloadIdentity) as Map)
              .cast<String, Object?>(),
        );
      }
      final child = parties.deleteInvoiceIntent(
        operationId: '$operation-invoice',
        invoiceId: id,
        expectedSource: rows.single,
        expectedActiveJournalId: invoicePosting.journal.id,
        inverseJournalId: '$inverse-invoice',
        reason: reason,
        recordedAt: recordedAt,
      );
      children.add(
        (jsonDecode(child.canonicalPayloadIdentity) as Map)
            .cast<String, Object?>(),
      );
      var target = current.account;
      if (immediate != null && (immediate['amount']! as int) > 0) {
        final paymentId = immediate['id']! as String;
        if (canonicalIdentity({
              'rows': _rows(current, 'payments', paymentId),
            }) !=
            canonicalIdentity({'rows': _rows(after, 'payments', paymentId)})) {
          throw const FormatException('undo_source_changed');
        }
        target = _expected(
          current.copyWith(account: target),
          'payments',
          paymentId,
          null,
          0,
        );
      }
      target = _expected(
        current.copyWith(account: target),
        'invoices',
        id,
        null,
        0,
      );
      target = SourceMaterialRestoration(
        before: before.account.toJson()['materials']! as List,
        after: after.account.toJson()['materials']! as List,
      ).apply(target);
      final command = PartySessionCompensationCommand.capture(
        operationId: operation,
        snapshot: parties.snapshot,
        state: current,
        restoredAccount: target,
        originalIdentity: identity,
        children: children,
        reason: reason,
      );
      _requireRestored(
        parties.compensationCommands.evaluate(
          command,
          current,
          parties.authorityFence,
        ),
        target,
      );
      return FinancialUndoAttempt(() => parties.submitCompensation(command));
    }
    if (kind == 'purchase_invoice' || kind == 'edit_purchase_invoice') {
      final id = intent['invoiceId']! as String;
      final old = _rows(before, 'invoices', id),
          now = _rows(current, 'invoices', id);
      if (now.length != 1 ||
          (kind == 'purchase_invoice' ? old.isNotEmpty : old.length != 1)) {
        throw const FormatException('undo_source_changed');
      }
      final active = parties.activeInvoicePosting(id);
      if (active == null) {
        throw const FormatException('undo_missing_original_posting');
      }
      final materialRestoration = SourceMaterialRestoration(
        before: before.account.toJson()['materials']! as List,
        after: after.account.toJson()['materials']! as List,
      );
      final command = kind == 'purchase_invoice'
          ? parties.deleteInvoiceIntent(
              operationId: operation,
              invoiceId: id,
              expectedSource: now.single,
              expectedActiveJournalId: active.journal.id,
              inverseJournalId: inverse,
              reason: reason,
              recordedAt: recordedAt,
            )
          : parties.editInvoiceIntent(
              operationId: operation,
              invoiceId: id,
              expectedSource: now.single,
              expectedActiveJournalId: active.journal.id,
              inverseJournalId: inverse,
              replacementJournalId: replacement,
              supplierId: old.single['supplierId']! as String,
              invoiceNumber: old.single['number']! as String,
              date: CatalogFormatters.parseDate(old.single['date']! as String),
              lines: (old.single['lines']! as List).map((value) {
                final line = (value as Map).cast<String, Object?>();
                return PurchaseLine(
                  materialIdForCreation: line['materialId']! as String,
                  name: line['name']! as String,
                  unit: line['unit']! as String,
                  quantityCartons: line['quantityCartons'] as num? ?? 0,
                  quantityPieces:
                      line['quantityPieces'] as num? ??
                      line['quantity'] as num? ??
                      0,
                  priceCarton: line['priceCarton'] as int? ?? 0,
                  pricePiece:
                      line['pricePiece'] as int? ?? line['price'] as int? ?? 0,
                );
              }),
              materialRestoration: materialRestoration,
              sourceOrder: SourceRecordOrder(
                position: (before.account.toJson()['invoices']! as List)
                    .indexWhere((row) => (row as Map)['id'] == id),
                siblingIds: (current.account.toJson()['invoices']! as List)
                    .cast<Map>()
                    .where((row) => row['id'] != id)
                    .map((row) => row['id']! as String),
              ),
              note: old.single['note']! as String,
              reason: reason,
              recordedAt: recordedAt,
              policy: RestaurantJournalInvoiceHistory.activePosting(
                before,
                id,
                parties.invoiceCorrectionCommands.mapper,
              )?.journal.policy,
            );
      _requireRestored(
        parties.previewInvoiceCorrection(command),
        materialRestoration.apply(
          _expected(
            current,
            'invoices',
            id,
            old.single,
            _position(before, 'invoices', id),
          ),
        ),
      );
      return FinancialUndoAttempt(
        () => parties.submitInvoiceCorrection(command),
      );
    }
    final id = intent['paymentId']! as String;
    final old = _rows(before, 'payments', id),
        now = _rows(current, 'payments', id);
    if (now.length != 1 ||
        (kind == 'supplier_payment' ? old.isNotEmpty : old.length != 1)) {
      throw const FormatException('undo_source_changed');
    }
    final active = _activePayment(current, id);
    if (active == null) {
      throw const FormatException('undo_missing_original_posting');
    }
    final prior = old.isEmpty ? null : old.single;
    final funding = (prior?['funding'] as Map?)?.cast<String, Object?>();
    final command = kind == 'supplier_payment'
        ? parties.deletePaymentIntent(
            operationId: operation,
            paymentId: id,
            expectedActiveJournalId: active.journal.id,
            expectedSource: now.single,
            inverseJournalId: inverse,
            reason: reason,
            recordedAt: recordedAt,
            profile: parties.paymentCorrectionCommands.mapper.profile,
          )
        : parties.editPaymentIntent(
            operationId: operation,
            paymentId: id,
            expectedActiveJournalId: active.journal.id,
            expectedSource: now.single,
            inverseJournalId: inverse,
            replacementJournalId: replacement,
            date: CatalogFormatters.parseDate(prior!['date']! as String),
            categoryId: prior['categoryId']! as String,
            supplierId: prior['supplierId']! as String,
            invoiceId: prior['invoiceId'] as String?,
            invoiceAmount: BigInt.from(prior['invoiceAmount']! as int),
            debtAmount: BigInt.from(prior['debtAmount']! as int),
            amount: BigInt.from(prior['amount']! as int),
            fundingSource: FundingSource.values.byName(
              funding!['source']! as String,
            ),
            dailyAmount: BigInt.from(funding['dailyAmount']! as int),
            cashAmount: BigInt.from(funding['cashAmount']! as int),
            sourceOrder: SourceRecordOrder(
              position: (before.account.toJson()['payments']! as List)
                  .indexWhere((row) => (row as Map)['id'] == id),
              siblingIds: (current.account.toJson()['payments']! as List)
                  .cast<Map>()
                  .where((row) => row['id'] != id)
                  .map((row) => row['id']! as String),
            ),
            note: prior['note']! as String,
            reason: reason,
            recordedAt: recordedAt,
            profile: parties.paymentCorrectionCommands.mapper.profile,
            policy: _activePayment(before, id)?.journal.policy,
          );
    _requireRestored(
      parties.previewPaymentCorrection(command),
      _expected(
        current,
        'payments',
        id,
        old.isEmpty ? null : old.single,
        old.isEmpty ? 0 : _position(before, 'payments', id),
      ),
    );
    return FinancialUndoAttempt(() => parties.submitPaymentCorrection(command));
  }
}
