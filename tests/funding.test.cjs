const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const M = require('../app/ui/model.js');
const { Storage } = require('../app/storage.cjs');
const date = '2026-10-05', timestamp = `${date}T10:00:00.000Z`;
function expense(id, amount, source = 'daily', dailyAmount = source === 'cash' ? 0 : amount) {
  return { id, categoryId: 'bread', amount, note: '', funding: { source, dailyAmount, cashAmount: amount - dailyAmount }, createdAt: timestamp };
}
function state() {
  const s = M.empty(); s.days[date] = M.day(s, date);
  s.transactions.push({ id: 'opening', type: 'deposit', date, amount: 100000, note: '', createdAt: timestamp }); return s;
}
test('version 1 migration keeps cash and totals, defaults old expenses to daily without assuming a remainder', () => {
  const s = state(); s.version = 1; delete s.transfers; delete s.days[date].remaining;
  const old = expense('old', 25000); delete old.funding; delete old.createdAt; s.days[date].expenses.push(old);
  const next = M.validate(s); assert.equal(next.version, 6); assert.equal(M.cash(next), 100000); assert.equal(M.total(next, date), 25000);
  assert.deepEqual(next.days[date].expenses[0].funding, { source: 'daily', dailyAmount: 25000, cashAmount: 0 }); assert.equal(M.remaining(next, date), null);
});
test('all sources count once in expenses; only cash allocation withdraws, and editing or deleting corrects it', () => {
  const s = state(); s.days[date].expenses = [expense('daily', 10000), expense('cash', 20000, 'cash'), expense('shared', 30000, 'shared', 18000)];
  assert.equal(M.total(M.validate(s), date), 60000); assert.equal(M.cash(s), 68000); assert.equal(M.dailySpent(s, date), 28000);
  assert.equal(M.movements(s).filter(t => t.kind === 'expense').length, 2);
  s.days[date].expenses[2] = expense('shared', 30000, 'shared', 25000); assert.equal(M.cash(s), 75000);
  s.days[date].expenses = s.days[date].expenses.filter(e => e.id !== 'cash'); assert.equal(M.cash(s), 95000);
});
test('actual remainder snapshots exclude earlier expenses and transfers, then apply daily allocation changes', () => {
  const s = state(); s.days[date].expenses.push(expense('old', 25000)); M.recordRemaining(s, date, 50000); assert.equal(M.remaining(s, date), 50000);
  s.days[date].expenses.push(expense('new', 20000, 'shared', 12000)); assert.equal(M.remaining(s, date), 38000); assert.equal(M.cash(s), 92000);
  s.days[date].expenses[1] = expense('new', 20000, 'cash'); assert.equal(M.remaining(s, date), 50000); assert.equal(M.cash(s), 80000);
  s.days[date].expenses[0] = expense('old', 30000); assert.equal(M.remaining(s, date), 45000);
  s.days[date].expenses = s.days[date].expenses.filter(e => e.id !== 'old'); assert.equal(M.remaining(s, date), 75000);
  M.transferRemaining(s, date, 10000, 'first', timestamp); M.recordRemaining(s, date, 32000); assert.equal(M.remaining(s, date), 32000);
  M.transferRemaining(s, date, 2000, 'second', timestamp); assert.equal(M.remaining(M.validate(s), date), 30000);
});
test('partial and full deposits move the same amount between balances and reject repeated or excessive deposits', () => {
  const s = state(); M.recordRemaining(s, date, 50000); const total = M.total(s, date);
  assert.throws(() => M.transferRemaining(s, date, 50001, 'bad', timestamp), /أكبر/); assert.equal(s.transfers.length, 0);
  M.transferRemaining(s, date, 20000, 'partial', timestamp); assert.equal(M.remaining(s, date), 30000); assert.equal(M.cash(s), 120000);
  M.transferRemaining(s, date, 30000, 'rest', timestamp); assert.equal(M.remaining(s, date), 0); assert.equal(M.cash(s), 150000); assert.equal(M.total(s, date), total);
  assert.throws(() => M.transferRemaining(s, date, 1, 'again', timestamp), /أكبر/); assert.throws(() => M.transferRemaining(s, date, 0, 'zero', timestamp));
  assert.throws(() => M.transferRemaining(s, '2026-10-06', 1, 'missing', timestamp), /أولاً/); assert.equal(s.transfers.length, 2);
  assert.equal(M.remaining(M.validate(s), date), 0);
});
test('editing and deleting a transfer correct both balances; expense date changes correct the two daily remainders', () => {
  const s = state(); M.recordRemaining(s, date, 50000); M.transferRemaining(s, date, 50000, 'transfer', timestamp);
  M.transferRemaining(s, date, 20000, 'ignored', timestamp, 'transfer'); assert.equal(M.remaining(s, date), 30000); assert.equal(M.cash(s), 120000); assert.equal(s.transfers[0].id, 'transfer');
  assert.throws(() => M.transferRemaining(s, date, 50001, 'ignored', timestamp, 'transfer'), /أكبر/);
  s.transfers = []; assert.equal(M.remaining(s, date), 50000); assert.equal(M.cash(s), 100000);
  s.days[date].expenses.push(expense('move', 10000)); const nextDate = '2026-10-06'; M.recordRemaining(s, nextDate, 30000);
  s.days[nextDate].expenses.push(s.days[date].expenses.pop()); assert.equal(M.remaining(s, date), 50000); assert.equal(M.remaining(s, nextDate), 20000);
});
test('save, restart and backup import preserve both allocations and atomic transfers; invalid allocations leave disk untouched', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'daftar-funding-')); t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const store = new Storage(dir), s = state(); s.days[date].expenses.push(expense('old', 10000)); M.recordRemaining(s, date, 50000);
  s.days[date].expenses.push(expense('shared', 20000, 'shared', 12000)); M.transferRemaining(s, date, 30000, 'transfer', timestamp);
  const saved = store.save(s); assert.equal(M.remaining(saved, date), 8000); assert.equal(M.cash(saved), 122000);
  assert.deepEqual(new Storage(dir).load(), saved); const exported = JSON.stringify(saved); store.save(M.empty()); store.save(JSON.parse(exported), true); assert.deepEqual(store.load(), saved);
  const before = fs.readFileSync(store.file);
  for (const f of [{ source: 'shared', dailyAmount: 100, cashAmount: 100 }, { source: 'daily', dailyAmount: 0, cashAmount: 20000 }, { source: 'shared', dailyAmount: -1, cashAmount: 20001 }, { source: 'other', dailyAmount: 20000, cashAmount: 0 }]) {
    const invalid = structuredClone(saved); invalid.days[date].expenses[1].funding = f; assert.throws(() => store.save(invalid)); assert.deepEqual(fs.readFileSync(store.file), before);
  }
});
test('recording the actual remainder saves total expenses plus remainder; split deposits and corrections cannot consume that saved sum', () => {
  const s=state(); s.days[date].expenses=[expense('daily',100000),expense('cash',20000,'cash'),expense('shared',30000,'shared',10000)];
  const before={ total:M.total(s,date),cash:M.cash(s),spent:M.dailySpent(s,date) };
  M.recordRemaining(s,date,50000); assert.equal(s.days[date].balance,200000); assert.equal(M.balanceFromRemaining(s,date),200000);
  assert.deepEqual({ total:M.total(s,date),cash:M.cash(s),spent:M.dailySpent(s,date) },before); assert.equal(s.transfers.length,0);
  M.transferRemaining(s,date,20000,'first',timestamp); assert.equal(s.days[date].balance,200000); assert.equal(M.remaining(s,date),30000);
  M.transferRemaining(s,date,30000,'second',timestamp); assert.equal(s.days[date].balance,200000); assert.equal(M.remaining(s,date),0); assert.equal(M.balanceFromRemaining(s,date),200000);
  M.transferRemaining(s,date,10000,'ignored',timestamp,'first'); assert.equal(s.days[date].balance,200000); assert.equal(M.remaining(s,date),10000);
  s.transfers=s.transfers.filter(t=>t.id!=='second'); assert.equal(s.days[date].balance,200000); assert.equal(M.remaining(s,date),40000);
  M.recordRemaining(s,date,45000); assert.equal(s.days[date].balance,205000); assert.equal(M.remaining(s,date),45000);
  s.days[date].totalOverride=160000; M.recordRemaining(s,date,45000); assert.equal(s.days[date].balance,215000);
  s.days[date].balance=123456; M.transferRemaining(s,date,1000,'third',timestamp); assert.equal(s.days[date].balance,123456);
});
test('old blank daily totals are restored using remainder plus earlier deposits; entered totals and all financial movements survive migration and reload', t => {
  const s=state(); s.days[date].expenses=[expense('daily',100000)]; M.recordRemaining(s,date,50000); M.transferRemaining(s,date,50000,'first',timestamp);
  s.version=4; s.days[date].balance=null; const nextDate='2026-10-06'; s.days[nextDate]={...M.day(s,nextDate),balance:999999};
  const before=structuredClone(s),clean=M.validate(s); assert.equal(clean.days[date].balance,150000); assert.equal(clean.days[nextDate].balance,999999); assert.deepEqual(s,before);
  assert.equal(M.remaining(clean,date),0); assert.equal(M.total(clean,date),100000); assert.equal(M.cash(clean),M.cash(s)); assert.deepEqual(clean.transfers,s.transfers); assert.deepEqual(clean.transactions,s.transactions); assert.deepEqual(clean.days[date].remaining,s.days[date].remaining);
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'daftar-total-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));const store=new Storage(dir);fs.writeFileSync(store.file,JSON.stringify(s));assert.deepEqual(store.load(),clean);
  assert.deepEqual(JSON.parse(fs.readFileSync(store.file,'utf8')),clean);assert.deepEqual(JSON.parse(fs.readFileSync(store.backup,'utf8')),s);
  assert.deepEqual(new Storage(dir).load(),clean);assert.deepEqual(JSON.parse(fs.readFileSync(store.backup,'utf8')),s);
  const cleared=structuredClone(clean);cleared.days[date].balance=null;assert.equal(M.validate(cleared).days[date].balance,null);
});
test('an invalid or overflowing remainder sum never partly changes the saved total, remainder or cash', () => {
  const s=state();s.days[date].expenses=[expense('large',1e12)];const before=structuredClone(s);
  assert.throws(()=>M.recordRemaining(s,date,1),/الرصيد الكلي/);assert.deepEqual(s,before);
  assert.throws(()=>M.recordRemaining(s,date,-1));assert.deepEqual(s,before);
});

test('migration leaves a valid legacy ledger accessible when its reconstructed total exceeds the daily total limit', () => {
  const s=state();s.version=4;s.days[date].expenses=[expense('large',1e12)];s.days[date].remaining={amount:1e12,dailySpent:1e12,transferred:0};
  const clean=M.validate(s);assert.equal(clean.days[date].balance,null);assert.equal(M.remaining(clean,date),1e12);assert.equal(M.total(clean,date),1e12);
});
