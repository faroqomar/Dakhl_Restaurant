import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';

void main() {
  final mapper = RestaurantJournalMapper();
  final date = DateOnly.parse(
    '2026-11-01',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  RestaurantJournalProposal sale() => mapper.mapSaleTicket(
    journalId: 'sale-journal',
    saleId: 'sale',
    receiptNumber: '1',
    effectiveDate: date,
    grossAmount: BigInt.from(100),
    discountAmount: BigInt.zero,
    netAmount: BigInt.from(100),
  );
  test('void preserves the source schema snapshot version', () {
    final original = sale();
    final historical = RestaurantJournalProposal(
      journal: original.journal,
      sourceType: original.sourceType,
      sourceRecordId: original.sourceRecordId,
      receiptNumber: original.receiptNumber,
      metadata: original.metadata,
      sourceVersion: 9,
    );
    final inverse = mapper.mapOriginalDateVoid(
      originalProposal: historical,
      reversalJournalId: 'historical-inverse',
      reason: 'fixture',
      isEligible: true,
    );
    expect(inverse.sourceVersion, 9);
    expect(inverse.journal.effectiveDate, original.journal.effectiveDate);
    expect(inverse.receiptNumber, original.receiptNumber);
  });
  test(
    'proposal metadata snapshots borrowed nested values and prevents mutation',
    () {
      final source = sale();
      final nested = <String, Object?>{'note': 'first'};
      final list = <Object?>[nested];
      final borrowed = <String, Object?>{
        'details': list,
        'exact': BigInt.from(100),
      };
      final proposal = RestaurantJournalProposal(
        journal: source.journal,
        sourceType: source.sourceType,
        sourceRecordId: source.sourceRecordId,
        metadata: borrowed,
      );
      borrowed['exact'] = BigInt.zero;
      nested['note'] = 'changed';
      list.clear();
      expect(proposal.metadata['exact'], BigInt.from(100));
      final savedList = proposal.metadata['details']! as List;
      expect((savedList.single as Map)['note'], 'first');
      expect(
        () => proposal.metadata['exact'] = BigInt.zero,
        throwsUnsupportedError,
      );
      expect(() => savedList.add('later'), throwsUnsupportedError);
      expect(
        () => (savedList.single as Map)['note'] = 'later',
        throwsUnsupportedError,
      );
    },
  );
  test(
    'cyclic or unsupported mutable metadata is rejected before composition',
    () {
      final source = sale();
      final cyclic = <Object?>[];
      cyclic.add(cyclic);
      for (final metadata in [
        <String, Object?>{'cycle': cyclic},
        <String, Object?>{'mutable': StringBuffer('value')},
      ]) {
        expect(
          () => RestaurantJournalProposal(
            journal: source.journal,
            sourceType: source.sourceType,
            sourceRecordId: source.sourceRecordId,
            metadata: metadata,
          ),
          throwsA(isA<RestaurantJournalMappingException>()),
        );
      }
    },
  );
  test('caller eligibility cannot reverse an already-reversing journal', () {
    final inverse = mapper.mapOriginalDateVoid(
      originalProposal: sale(),
      reversalJournalId: 'inverse',
      reason: 'fixture',
      isEligible: true,
    );
    expect(
      () => mapper.mapOriginalDateVoid(
        originalProposal: inverse,
        reversalJournalId: 'inverse-of-inverse',
        reason: 'fixture',
        isEligible: true,
      ),
      throwsA(
        isA<RestaurantJournalMappingException>().having(
          (e) => e.code,
          'code',
          'already_reversed',
        ),
      ),
    );
  });
  test('verified opening aggregates may exceed a single transaction limit', () {
    final proposal = mapper.mapVerifiedCutoverOpening(
      journalId: 'opening',
      effectiveDate: date,
      verifiedPhysicalRegisterCash: BigInt.zero,
      verifiedCashboxBalance: BigInt.zero,
      verifiedSupplierDebts: {
        'one': BigInt.from(600000000000),
        'two': BigInt.from(600000000000),
      },
    );
    expect(proposal.journal.totalUnits, BigInt.from(1200000000000));
    expect(
      proposal.journal.lines
          .singleWhere((line) => line.accountId == 'equity:opening_balance')
          .amountUnits,
      BigInt.from(1200000000000),
    );
    expect(
      () => mapper.mapPurchaseInvoice(
        journalId: 'too-large-invoice',
        invoiceId: 'invoice',
        supplierId: 'one',
        invoiceNumber: '1',
        effectiveDate: date,
        amount: BigInt.from(1200000000000),
      ),
      throwsA(isA<Exception>()),
    );
  });
  test('verified opening includes the supported 5000 supplier identities', () {
    final proposal = mapper.mapVerifiedCutoverOpening(
      journalId: 'opening-many',
      effectiveDate: date,
      verifiedPhysicalRegisterCash: BigInt.zero,
      verifiedCashboxBalance: BigInt.zero,
      verifiedSupplierDebts: {
        for (var i = 0; i < 5000; i++) 'supplier-$i': BigInt.one,
      },
    );
    expect(proposal.journal.lines, hasLength(5001));
    expect(proposal.journal.totalUnits, BigInt.from(5000));
  });
  test(
    'opening rejects beyond safe aggregate and respects explicit caller bounds',
    () {
      final safe = BigInt.parse('9007199254740991');
      expect(
        () => mapper.mapVerifiedCutoverOpening(
          journalId: 'opening-unsafe',
          effectiveDate: date,
          verifiedPhysicalRegisterCash: safe,
          verifiedCashboxBalance: BigInt.one,
          verifiedSupplierDebts: {},
        ),
        throwsA(
          isA<RestaurantJournalMappingException>().having(
            (e) => e.code,
            'code',
            'opening_balance_limit_exceeded',
          ),
        ),
      );
      expect(
        () => mapper.mapVerifiedCutoverOpening(
          journalId: 'opening-custom',
          effectiveDate: date,
          verifiedPhysicalRegisterCash: BigInt.from(2000000000000),
          verifiedCashboxBalance: BigInt.zero,
          verifiedSupplierDebts: {},
          policy: RestaurantJournalPolicies.standard,
        ),
        throwsA(
          isA<RestaurantJournalMappingException>().having(
            (e) => e.code,
            'code',
            'opening_balance_limit_exceeded',
          ),
        ),
      );
    },
  );
}
