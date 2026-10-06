const { test } = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const M = require('../app/ui/model.js'), { Storage } = require('../app/storage.cjs');
function fixture() {
  const s = M.empty();
  for (const [date, amount] of [['2026-10-02', 10000], ['2026-10-03', 20000], ['2026-10-04', 30000]]) {
    s.days[date] = { ...M.day(s, date), chickenUsed: amount / 1000, chickenLeft: 20, balance: 500000, totalOverride: date === '2026-10-03' ? 25000 : null, expenses: [{ id: 'e-' + date, categoryId: 'bread', amount, note: date, funding: { source: 'shared', dailyAmount: amount / 2, cashAmount: amount / 2 } }] };
    M.recordRemaining(s, date, 50000);
    M.transferRemaining(s, date, 10000, 't-' + date, date + 'T10:00:00.000Z');
  }
  s.transactions.push({ id: 'cash', type: 'deposit', date: '2026-10-02', amount: 100000, note: '', createdAt: '2026-10-02T10:00:00.000Z' });
  s.suppliers.push({ id: 's', name: 'المورد', phone: '', note: '', categoryId: 'market', openingBalance: 50000, materials: [{ id: 'm', name: 'مادة', unit: 'قطعة', price: 5000, archived: false }] });
  s.invoices.push({ id: 'i', supplierId: 's', number: '1', date: '2026-10-01', lines: [{ materialId: 'm', name: 'مادة', unit: 'قطعة', quantity: 1, price: 5000 }], note: '', createdAt: '2026-10-01T10:00:00.000Z' });
  s.payments.push({ id: 'p', supplierId: 's', invoiceId: 'i', date: '2026-10-02', categoryId: 'market', amount: 7000, invoiceAmount: 5000, debtAmount: 2000, funding: { source: 'daily', dailyAmount: 7000, cashAmount: 0 }, note: '', createdAt: '2026-10-02T11:00:00.000Z' });
  return M.validate(s);
}
test('one-day correction moves all daily records and snapshots without changing balances, amounts, identities, or supplier bill dates', () => {
  const s = fixture(), before = structuredClone(s), next = M.correctDayDates(s, '2026-10-02', '2026-10-06');
  assert.deepEqual(s, before); assert.equal(next.days['2026-10-02'], undefined); assert.deepEqual(next.days['2026-10-06'], s.days['2026-10-02']);
  assert.equal(next.payments[0].date, '2026-10-06'); assert.equal(next.transfers[0].date, '2026-10-06'); assert.equal(next.transactions[0].date, '2026-10-06');
  assert.deepEqual(next.invoices, s.invoices); assert.equal(M.invoiceDue(next, 'i'), M.invoiceDue(s, 'i')); assert.equal(M.debtAvailable(next, 's'), M.debtAvailable(s, 's')); assert.equal(M.cash(next), M.cash(s));
  assert.equal(M.remaining(next, '2026-10-06'), M.remaining(s, '2026-10-02')); assert.equal(M.total(next, '2026-10-06'), M.total(s, '2026-10-02')); assert.equal(M.total(next, '2026-10-02'), 0);
});
test('adjacent days shift together without overwriting, preserve gaps, and can move backwards across month/year boundaries', () => {
  const s = fixture(), plan = M.dayDatePlan(s, '2026-10-02', '2026-10-03', '2026-10-04');
  assert.deepEqual(plan, [{ from: '2026-10-02', to: '2026-10-03' }, { from: '2026-10-03', to: '2026-10-04' }, { from: '2026-10-04', to: '2026-10-05' }]);
  const next = M.correctDayDates(s, '2026-10-02', '2026-10-03', '2026-10-04');
  for (const p of plan) { assert.deepEqual(next.days[p.to], s.days[p.from]); assert.equal(M.remaining(next, p.to), M.remaining(s, p.from)); assert.equal(M.total(next, p.to), M.total(s, p.from)); }
  assert.equal(M.cash(next), M.cash(s)); assert.deepEqual(M.correctDayDates(next, '2026-10-03', '2026-10-02', '2026-10-05'), s);
  const year = M.empty(); year.days['2026-12-31'] = { ...M.day(year, '2026-12-31'), chickenUsed: 1 }; year.days['2027-01-02'] = { ...M.day(year, '2027-01-02'), totalOverride: 0 };
  assert.deepEqual(M.dayDatePlan(year, '2026-12-31', '2026-12-30', '2027-01-02'), [{ from: '2026-12-31', to: '2026-12-30' }, { from: '2027-01-02', to: '2027-01-01' }]);
});
test('collision, invalid dates, backwards range, and payments before bills fail without changing persisted records; valid correction survives reload/import', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'daftar-date-test-')); t.after(() => fs.rmSync(dir, { recursive: true, force: true })); const store = new Storage(dir), s = fixture(); store.save(s); const original = fs.readFileSync(store.file);
  for (const args of [['2026-10-02', '2026-10-03'], ['2026-10-02', '2026-02-30'], ['2026-10-02', '2026-10-06', '2026-10-01'], ['2026-10-02', '2026-09-30']]) {
    assert.throws(() => store.save(M.correctDayDates(s, ...args))); assert.deepEqual(fs.readFileSync(store.file), original);
  }
  const next = store.save(M.correctDayDates(s, '2026-10-02', '2026-10-03', '2026-10-04')); assert.deepEqual(new Storage(dir).load(), next);
  store.save(M.empty()); store.save(JSON.parse(JSON.stringify(next)), true); assert.deepEqual(store.load(), next);
});
test('empty placeholders cannot block or overwrite a correction, while explicitly recorded zero balances are preserved', () => {
  const s = fixture(); s.days['2026-10-05'] = M.day(s, '2026-10-05');
  const next = M.correctDayDates(s, '2026-10-02', '2026-10-03', '2026-10-04'); assert.deepEqual(next.days['2026-10-05'], s.days['2026-10-04']);
  s.days['2026-10-05'].balance = 0; assert.throws(() => M.correctDayDates(s, '2026-10-02', '2026-10-03', '2026-10-04'), /بيه سجل آخر/);
});
