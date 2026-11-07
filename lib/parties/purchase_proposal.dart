import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import 'supplier_ledger.dart';

final class PurchaseLine {
  const PurchaseLine({
    required this.materialIdForCreation,
    required this.name,
    required this.unit,
    required this.quantityCartons,
    required this.quantityPieces,
    required this.priceCarton,
    required this.pricePiece,
  });
  final String materialIdForCreation, name, unit;
  final num quantityCartons, quantityPieces;
  final int priceCarton, pricePiece;
}

final class PurchasePayment {
  const PurchasePayment({
    required this.id,
    required this.amount,
    required this.source,
    this.dailyAmount = 0,
    this.cashAmount = 0,
  });
  final String id, source;
  final int amount, dailyAmount, cashAmount;
}

/// Pure hypothetical candidate only; caller must not persist before approved
/// financial mapping, fencing and atomic journal/effect contracts are integrated.
final class PurchaseProposals {
  PurchaseProposals(this.baseline);
  final AccountDocument baseline;
  static final _limit = BigInt.from(1000000000000);
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: _limit,
    maximumMoney: _limit,
    maximumSafeInteger: BigInt.from(9007199254740991),
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );
  static String _trim(String text) => LegacyText.trimJavaScript(text);
  static String _latin(String text) =>
      text.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
        final c = m[0]!.codeUnitAt(0);
        return '${c >= 0x6f0 ? c - 0x6f0 : c - 0x660}';
      });
  static String _key(String text) => LegacyCase.lower(
    _latin(text),
    profile: LegacyCaseProfile.ecmascriptUnicode17,
  );
  static List<Map<String, Object?>> _rows(
    Map<String, Object?> state,
    String name,
  ) => (state[name]! as List).cast<Map<String, Object?>>();
  static void _require(bool condition, String code) {
    if (!condition) throw FormatException(code);
  }

  static SupplierLedgerQueries _queries(AccountDocument doc) =>
      SupplierLedgerQueries(
        doc,
        compareText: (_, _) =>
            throw StateError('No ordered queries in purchase proposals.'),
      );
  Map<String, Object?> _payment(
    Map<String, Object?> state, {
    required PurchasePayment payment,
    required String supplierId,
    required String? invoiceId,
    required String categoryId,
    required String date,
    required String createdAt,
    required String note,
    String? editingId,
  }) {
    DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
    _require(
      _rows(state, 'suppliers').any((s) => s['id'] == supplierId),
      'missing_supplier',
    );
    final invoices = _rows(
      state,
      'invoices',
    ).where((i) => i['id'] == invoiceId).toList();
    _require(
      invoiceId == null ||
          (invoices.length == 1 &&
              invoices.single['supplierId'] == supplierId &&
              date.compareTo(invoices.single['date']! as String) >= 0),
      'invalid_invoice_reference',
    );
    final other = AccountDocument.canonical({
      ...state,
      'payments': _rows(
        state,
        'payments',
      ).where((p) => p['id'] != editingId).toList(),
    }, sourceVersion: 11);
    final q = _queries(other);
    final split = CommerceCalculations.allocatePayment(
      amount: BigInt.from(payment.amount),
      selectedLiabilityDue: invoiceId == null
          ? BigInt.zero
          : q.invoiceDue(invoiceId),
      eligibleDebt: q.debtAvailable(supplierId, date: date),
      policy: _policy,
    );
    final source = FundingSource.values
        .where((s) => s.name == payment.source)
        .toList();
    _require(source.length == 1, 'invalid_funding_source');
    final funding = CommerceCalculations.fundingSplit(
      amount: BigInt.from(payment.amount),
      daily: BigInt.from(
        payment.source == 'daily'
            ? payment.amount
            : payment.source == 'cash'
            ? 0
            : payment.dailyAmount,
      ),
      cash: BigInt.from(
        payment.source == 'cash'
            ? payment.amount
            : payment.source == 'daily'
            ? 0
            : payment.cashAmount,
      ),
      source: source.single,
      policy: _policy,
    );
    return {
      'id': payment.id,
      'supplierId': supplierId,
      'invoiceId': invoiceId,
      'categoryId': categoryId,
      'date': date,
      'amount': payment.amount,
      'invoiceAmount': split.selectedLiability.toInt(),
      'debtAmount': split.debt.toInt(),
      'funding': {
        'source': payment.source,
        'dailyAmount': funding.daily.toInt(),
        'cashAmount': funding.cash.toInt(),
      },
      'note': _trim(note),
      'createdAt': createdAt,
    };
  }

  AccountDocument invoice({
    required String id,
    required String supplierId,
    required String number,
    required String date,
    required String createdAt,
    required List<PurchaseLine> lines,
    String note = '',
    PurchasePayment? immediatePayment,
    bool editing = false,
  }) {
    final state = baseline.toJson();
    final suppliers = _rows(
      state,
      'suppliers',
    ).where((s) => s['id'] == supplierId).toList();
    _require(suppliers.length == 1, 'missing_supplier');
    final existing = _rows(
      state,
      'invoices',
    ).where((i) => i['id'] == id).toList();
    _require(
      editing ? existing.length == 1 : existing.isEmpty,
      'invoice_identity',
    );
    if (editing) {
      _require(existing.single['supplierId'] == supplierId, 'supplier_change');
    }
    final normalized = _trim(_latin(number));
    _require(
      !_rows(state, 'invoices').any(
        (i) =>
            i['id'] != id &&
            i['supplierId'] == supplierId &&
            _latin(i['number']! as String) == normalized,
      ),
      'duplicate_invoice_number',
    );
    final materials = [..._rows(state, 'materials')];
    final savedLines = <Map<String, Object?>>[];
    for (final line in lines) {
      final name = _trim(line.name), unit = _trim(line.unit);
      _require(name.isNotEmpty && unit.isNotEmpty, 'missing_material_details');
      final matches = materials
          .where((m) => _key(m['name']! as String) == _key(name))
          .toList();
      final material = matches.isNotEmpty
          ? matches.first
          : <String, Object?>{
              'id': line.materialIdForCreation,
              'name': name,
              'unit': unit,
              'priceCarton': line.priceCarton,
              'pricePiece': line.pricePiece,
              'archived': false,
            };
      if (matches.isEmpty) materials.add(material);
      savedLines.add({
        'materialId': material['id'],
        'name': name,
        'unit': unit,
        'quantityCartons': line.quantityCartons,
        'quantityPieces': line.quantityPieces,
        'priceCarton': line.priceCarton,
        'pricePiece': line.pricePiece,
      });
    }
    final inv = <String, Object?>{
      'id': id,
      'supplierId': supplierId,
      'number': normalized,
      'date': date,
      'createdAt': editing ? existing.single['createdAt'] : createdAt,
      'lines': savedLines,
      'note': _trim(note),
    };
    final candidate = <String, Object?>{
      ...state,
      'materials': materials,
      'invoices': [
        ..._rows(state, 'invoices').where((i) => i['id'] != id),
        inv,
      ],
    };
    // Validate invoice/inline material together before optional payment allocation.
    var validated = const LegacyAccountCodec().decodeJson(candidate);
    if (!editing && immediatePayment != null && immediatePayment.amount > 0) {
      final p = _payment(
        validated.toJson(),
        payment: immediatePayment,
        supplierId: supplierId,
        invoiceId: id,
        categoryId: suppliers.single['categoryId']! as String,
        date: date,
        createdAt: createdAt,
        note: '',
      );
      validated = const LegacyAccountCodec().decodeJson({
        ...validated.toJson(),
        'payments': [..._rows(validated.toJson(), 'payments'), p],
      });
    }
    if (immediatePayment != null) {
      _require(immediatePayment.amount >= 0, 'negative_payment');
    }
    return validated;
  }

  AccountDocument payment({
    required PurchasePayment payment,
    required String supplierId,
    required String? invoiceId,
    required String categoryId,
    required String date,
    required String createdAt,
    String note = '',
    bool editing = false,
  }) {
    final state = baseline.toJson();
    final old = _rows(
      state,
      'payments',
    ).where((p) => p['id'] == payment.id).toList();
    _require(editing ? old.length == 1 : old.isEmpty, 'payment_identity');
    final p = _payment(
      state,
      payment: payment,
      supplierId: supplierId,
      invoiceId: invoiceId,
      categoryId: categoryId,
      date: date,
      createdAt: editing ? old.single['createdAt']! as String : createdAt,
      note: note,
      editingId: editing ? payment.id : null,
    );
    return const LegacyAccountCodec().decodeJson({
      ...state,
      'payments': [
        ..._rows(state, 'payments').where((p) => p['id'] != payment.id),
        p,
      ],
    });
  }

  AccountDocument removeInvoice(String id) {
    final state = baseline.toJson();
    _require(
      !_rows(state, 'payments').any((p) => p['invoiceId'] == id),
      'invoice_has_payments',
    );
    return const LegacyAccountCodec().decodeJson({
      ...state,
      'invoices': _rows(state, 'invoices').where((i) => i['id'] != id).toList(),
    });
  }
}
