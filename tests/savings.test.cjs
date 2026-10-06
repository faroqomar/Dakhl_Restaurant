const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const M = require('../app/ui/model.js');
const { Storage } = require('../app/storage.cjs');
const worker = (frequency = 'weekly', startDate = '2026-10-02') => ({ id: 'worker-1', name: 'عامل تجريبي', amount: 10000, frequency, startDate, archived: false, note: '' });
function sample() { const s = M.empty(); s.workers.push(worker()); return s; }
function contribution(s, key, date, amount, due = 10000) { const period = M.savingsPeriod(s.workers[0], date); return { id: key, type: 'contribution', workerId: 'worker-1', date, amount, periodStart: period.start, periodEnd: period.end, dueAmount: due, note: '', createdAt: date + 'T12:00:00.000Z' }; }
const receipt = (id, date, amount) => ({ id, workerId: 'worker-1', type: 'receipt', date, amount, note: '', createdAt: date + 'T13:00:00.000Z' });
test('anchored daily, weekly and monthly savings periods cross months, leap days and years correctly', () => {
  assert.deepEqual(M.savingsPeriod(worker('daily'), '2026-10-04'), { start: '2026-10-04', end: '2026-10-04' });
  assert.equal(M.savingsPeriod(worker(), '2026-10-01'), null);
  assert.deepEqual(M.savingsPeriod(worker(), '2026-10-08'), { start: '2026-10-02', end: '2026-10-08' });
  assert.deepEqual(M.savingsPeriod(worker(), '2026-10-09'), { start: '2026-10-09', end: '2026-10-15' });
  assert.deepEqual(M.savingsPeriod(worker('monthly', '2024-01-31'), '2024-02-29'), { start: '2024-02-29', end: '2024-03-30' });
  assert.deepEqual(M.savingsPeriod(worker('monthly', '2026-01-31'), '2026-03-30'), { start: '2026-02-28', end: '2026-03-30' });
  assert.deepEqual(M.savingsPeriod(worker('monthly', '2026-12-31'), '2027-01-31'), { start: '2027-01-31', end: '2027-02-27' });
  assert.equal(M.savingsPeriod(worker('monthly', '9999-12-31'), '9999-12-31').end, '9999-12-31');
});
test('partial contributions accumulate once per period; amount changes preserve already recorded dues and future payments do not mark past dates paid', () => {
  const s = sample(); s.savingsEntries.push(contribution(s, 'p1', '2026-10-02', 4000), contribution(s, 'p2', '2026-10-04', 6000)); s.workers[0].amount = 20000;
  const clean = M.validate(s); assert.equal(M.savingsStatus(clean, clean.workers[0], '2026-10-03').remaining, 6000);
  assert.equal(M.savingsStatus(clean, clean.workers[0], '2026-10-04').remaining, 0);
  assert.equal(M.savingsStatus(clean, clean.workers[0], '2026-10-09').due, 20000);
  s.savingsEntries.push(contribution(s, 'excess', '2026-10-05', 1)); assert.throws(() => M.validate(s), /تتجاوز اشتراك/);
});
test('receipt amounts are capped by savings available on their actual date; removing contributions cannot invalidate paid receipts', () => {
  const s = sample(); s.savingsEntries.push(contribution(s, 'p1', '2026-10-02', 10000), receipt('r1', '2026-10-03', 8000));
  assert.equal(M.savingsBalance(M.validate(s)), 2000); assert.equal(M.savingsBalance(s, '2026-10-02'), 10000);
  s.savingsEntries[1].date = '2026-10-01'; assert.throws(() => M.validate(s), /بهذا التاريخ/);
  s.savingsEntries[1].date = '2026-10-03'; s.savingsEntries[0].amount = 7000; assert.throws(() => M.validate(s), /المتجمع/);
});
test('invalid worker names, references, dates, periods and duplicate records cannot overwrite account files', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'daftar-savings-')); t.after(() => fs.rmSync(dir, { recursive: true, force: true })); const store = new Storage(dir); store.load();
  const s = sample(); s.savingsEntries.push(contribution(s, 'p1', '2026-10-02', 10000)); store.save(s); const before = fs.readFileSync(store.file);
  for (const mutate of [s => s.workers.push({ ...s.workers[0], id: 'duplicate' }), s => s.savingsEntries[0].workerId = 'missing', s => s.savingsEntries[0].periodStart = '2026-10-03', s => s.savingsEntries.push({ ...s.savingsEntries[0] }), s => s.workers[0].amount = 0, s => s.workers[0].frequency = 'yearly', s => s.savingsEntries[0].date = '2026-02-30']) {
    const bad = structuredClone(s); mutate(bad); assert.throws(() => store.save(bad)); assert.deepEqual(fs.readFileSync(store.file), before);
  }
});
test('savings survive reload and backup recovery without changing daily accounts, cash, supplier balances or date corrections', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'daftar-savings-')); t.after(() => fs.rmSync(dir, { recursive: true, force: true })); const store = new Storage(dir); store.load();
  const old = M.empty(); old.version = 5; delete old.workers; delete old.savingsEntries; old.days['2026-10-02'] = { ...M.day(old, '2026-10-02'), balance: 15000, expenses: [{ id: 'expense', categoryId: 'bread', amount: 5000, note: '', funding: { source: 'daily', dailyAmount: 5000, cashAmount: 0 } }] }; M.recordRemaining(old, '2026-10-02', 10000);
  const s = M.validate(old); assert.deepEqual(s.days, old.days); s.workers.push(worker()); s.savingsEntries.push(contribution(s, 'p1', '2026-10-02', 10000), receipt('r1', '2026-10-03', 5000));
  store.save(s); assert.deepEqual(new Storage(dir).load(), s); const exported = JSON.parse(fs.readFileSync(store.file)); store.save(M.empty()); store.save(exported, true); assert.deepEqual(store.load(), s);
  assert.equal(M.cash(s), 0); assert.equal(M.total(s, '2026-10-02'), 5000); assert.equal(M.remaining(s, '2026-10-02'), 10000);
  const moved = M.correctDayDates(s, '2026-10-02', '2026-10-04'); assert.deepEqual(moved.savingsEntries, s.savingsEntries); assert.equal(M.total(moved, '2026-10-04'), 5000);
});
