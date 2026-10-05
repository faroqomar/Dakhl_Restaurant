const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const M = require('../app/ui/model.js'), { Storage } = require('../app/storage.cjs');
const date = '2026-10-05';
function fixture() {
  const s = M.empty(); s.suppliers.push({ id: 'supplier', name: 'مورد المواد', phone: '', note: '', categoryId: 'market', openingBalance: 100000, materials: [{ id: 'rice', name: 'رز', unit: 'كيلو', price: 5000, archived: false }] });
  s.invoices.push({ id: 'invoice', supplierId: 'supplier', number: 'A-١', date, lines: [{ materialId: 'rice', name: 'رز', unit: 'كيلو', quantity: 2.5, price: 5000 }], note: '', createdAt: `${date}T10:00:00.000Z` });
  s.transactions.push({ id: 'cash', date, type: 'deposit', amount: 200000, note: '', createdAt: `${date}T08:00:00.000Z` }); return s;
}
function pay(id = 'payment', amount = 5000, dailyAmount = 3000) { return { id, supplierId: 'supplier', invoiceId: 'invoice', date, amount, categoryId: 'market', funding: { source: 'shared', dailyAmount, cashAmount: amount - dailyAmount }, note: '', createdAt: `${date}T11:00:00.000Z` }; }
test('old and new data migrate to supplier schema without changing existing money or remainder snapshots', () => {
  const old = M.empty(); old.version = 2; delete old.suppliers; delete old.invoices; delete old.payments; M.recordRemaining(old, date, 50000); old.transactions = fixture().transactions;
  const next = M.validate(old); assert.equal(next.version, 3); assert.deepEqual(next.suppliers, []); assert.equal(M.cash(next), 200000); assert.equal(M.remaining(next, date), 50000);
});
test('invoice records debt only; settlement contributes exactly once to expenses and affects its allocated source', () => {
  const s = fixture(); M.recordRemaining(s, date, 50000); assert.equal(M.supplierBalance(s, 'supplier'), 112500); assert.equal(M.total(s, date), 0); assert.equal(M.cash(s), 200000);
  s.payments.push(pay()); const clean = M.validate(s); assert.equal(M.supplierBalance(clean, 'supplier'), 107500); assert.equal(M.invoiceDue(clean, 'invoice'), 7500); assert.equal(M.total(clean, date), 5000); assert.equal(M.cash(clean), 198000); assert.equal(M.remaining(clean, date), 47000); assert.equal(M.movements(clean).filter(t => t.kind === 'supplier-payment').length, 1);
  s.payments[0] = pay('payment', 5000, 1000); assert.equal(M.cash(s), 196000); assert.equal(M.remaining(s, date), 49000);
  s.payments = []; assert.equal(M.cash(s), 200000); assert.equal(M.remaining(s, date), 50000); assert.equal(M.supplierBalance(s, 'supplier'), 112500);
});
test('partial/full payments and opening debt are distinct; excess, orphan, wrong supplier, and invalid dates are rejected', () => {
  const s = fixture(); s.payments = [pay('partial', 5000), pay('rest', 7500, 7500)]; assert.equal(M.invoiceDue(M.validate(s), 'invoice'), 0);
  for (const change of [p => p.amount++, p => p.invoiceId = 'missing', p => p.supplierId = 'missing', p => p.date = '2026-10-04']) { const invalid = structuredClone(s); change(invalid.payments[0]); assert.throws(() => M.validate(invalid)); }
  s.payments.push({ ...pay('opening', 100000, 100000), invoiceId: null }); assert.equal(M.openingDue(M.validate(s), 'supplier'), 0); assert.equal(M.supplierBalance(s, 'supplier'), 0);
  s.suppliers[0].openingBalance = 99999; assert.throws(() => M.validate(s), /القديم/);
});
test('supplier ledger uses transaction dates with old/current running balances and responds to backdated entries', () => {
  const s = fixture(); s.payments.push(pay()); const ledger = M.supplierLedger(s, 'supplier'); assert.deepEqual(ledger.map(e => [e.type, e.before, e.balance]), [['invoice',100000,112500], ['payment',112500,107500]]);
  assert.equal(M.balanceBefore(s, 'supplier', date, '2026-10-05T10:00:00.000Z', 'invoice'), 100000);
  const earlier = structuredClone(s.invoices[0]); earlier.id = 'earlier'; earlier.number = 'older'; earlier.date = '2026-10-04'; s.invoices.push(earlier);
  assert.equal(M.supplierLedger(M.validate(s), 'supplier')[1].before, 112500);
});
test('fractional quantities, integer dinars, and saved line snapshots survive template price/name edits', () => {
  assert.equal(M.quantity('٢٫٥'), 2.5); assert.equal(M.lineTotal({ quantity: .125, price: 1004 }), 126);
  for (const q of [0, '-1', '1.0001', '2e2']) assert.throws(() => M.quantity(q)); assert.throws(() => M.lineTotal({ quantity: 1e9, price: 1e12 }));
  const s = fixture(); s.suppliers[0].materials[0].price = 6000; s.suppliers[0].materials[0].name = 'رز جديد'; s.suppliers[0].materials[0].archived = true;
  const clean = M.validate(s); assert.equal(M.invoiceTotal(clean.invoices[0]), 12500); assert.equal(clean.invoices[0].lines[0].name, 'رز');
});
test('paid invoice cannot be reduced below payment or removed; duplicate supplier numbers and malformed references fail safely', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'daftar-suppliers-')); t.after(() => fs.rmSync(dir, { recursive: true, force: true })); const store = new Storage(dir), s = fixture(); s.payments.push(pay()); const saved = store.save(s), before = fs.readFileSync(store.file);
  for (const mutate of [s => s.invoices[0].lines[0].price = 1000, s => s.invoices = [], s => s.invoices.push({ ...s.invoices[0], id: 'duplicate' }), s => s.invoices[0].lines[0].materialId = 'wrong', s => s.suppliers.push({ ...s.suppliers[0], id: 'same-name' })]) { const invalid = structuredClone(saved); mutate(invalid); assert.throws(() => store.save(invalid)); assert.deepEqual(fs.readFileSync(store.file), before); }
  assert.deepEqual(new Storage(dir).load(), saved); const exported = JSON.stringify(saved); store.save(M.empty()); store.save(JSON.parse(exported), true); assert.deepEqual(store.load(), saved);
});
test('moving a settlement between days corrects both remainders and leaves cash/counts consistent', () => {
  const s = fixture(), nextDate = '2026-10-06'; M.recordRemaining(s, date, 50000); M.recordRemaining(s, nextDate, 60000); s.payments.push(pay()); assert.equal(M.remaining(s, date), 47000);
  s.payments[0].date = nextDate; assert.equal(M.remaining(M.validate(s), date), 50000); assert.equal(M.remaining(s, nextDate), 57000); assert.equal(M.total(s, date), 0); assert.equal(M.total(s, nextDate), 5000); assert.equal(M.cash(s), 198000);
});
