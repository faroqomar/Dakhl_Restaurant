(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.DaftarModel = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const core = [{ id: 'samoon', name: 'الصمون' }, { id: 'bread', name: 'الخبز' }, { id: 'falafel', name: 'الفلافل' }, { id: 'market', name: 'الأسواق' }];
  function empty() { return { version: 2, categories: core.map(c => ({ ...c })), days: {}, transactions: [], transfers: [] }; }
  function dateKey(d = new Date()) { return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; }
  function validDate(s) { if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false; const d = new Date(`${s}T12:00:00`); return !isNaN(d) && dateKey(d) === s; }
  function numeric(raw, { signed = false, positive = false } = {}) {
    const s = String(raw).trim().replace(/[٠-٩]/g, d => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d))).replace(/[۰-۹]/g, d => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d))).replace(/[,٬\s]/g, '');
    if (!(signed ? /^-?\d+$/ : /^\d+$/).test(s)) throw new Error('اكتب مبلغاً صحيحاً بالدينار، بدون كسور.');
    const n = Number(s); if (!Number.isSafeInteger(n) || Math.abs(n) > 1e12 || (positive && n <= 0)) throw new Error('المبلغ خارج الحد المسموح أو يساوي صفر.');
    return n;
  }
  function day(state, key) { return state.days[key] || { expenses: [], chickenUsed: 0, chickenLeft: 0, balance: null, totalOverride: null, remaining: null }; }
  function total(state, key) { const d = day(state, key); return d.totalOverride ?? d.expenses.reduce((s, e) => s + e.amount, 0); }
  function funding(e) { return e.funding || { source: 'daily', dailyAmount: e.amount, cashAmount: 0 }; }
  function dailySpent(state, key) { return day(state, key).expenses.reduce((sum, e) => sum + funding(e).dailyAmount, 0); }
  function transferred(state, key) { return (state.transfers || []).filter(t => t.date === key).reduce((sum, t) => sum + t.amount, 0); }
  // A manual remainder is a snapshot AFTER existing expenses and transfers.
  // Only subsequent differences are applied, including edits and deletions.
  function remaining(state, key) {
    const snapshot = day(state, key).remaining;
    return snapshot ? snapshot.amount - (dailySpent(state, key) - snapshot.dailySpent) - (transferred(state, key) - snapshot.transferred) : null;
  }
  function recordRemaining(state, key, amount) {
    const d = state.days[key] || (state.days[key] = { ...day(state, key) });
    d.remaining = { amount: money(amount), dailySpent: dailySpent(state, key), transferred: transferred(state, key) };
  }
  function movements(state) {
    const result = state.transactions.map(t => ({ ...t, kind: 'cash' }));
    for (const [date, d] of Object.entries(state.days)) for (const e of d.expenses) {
      const f = funding(e);
      if (f.cashAmount) result.push({ id: e.id, date, type: 'withdrawal', kind: 'expense', amount: f.cashAmount, note: e.note, categoryId: e.categoryId, createdAt: e.createdAt || `${date}T12:00:00.000Z` });
    }
    for (const t of state.transfers || []) result.push({ ...t, type: 'deposit', kind: 'transfer' });
    return result;
  }
  function cash(state) { return movements(state).reduce((s, t) => s + (t.type === 'withdrawal' ? -t.amount : t.amount), 0); }
  function transferRemaining(state, key, amount, transferId, createdAt, editId = null) {
    money(amount); assert(amount > 0, 'حدد مبلغ إيداع أكبر من صفر.');
    const old = editId ? state.transfers.find(t => t.id === editId) : null;
    assert(!editId || old?.date === key, 'حركة الإيداع غير موجودة.');
    const available = remaining(state, key);
    assert(available !== null, 'سجّل الرصيد المتبقي أولاً.');
    assert(amount <= available + (old?.amount || 0), 'مبلغ الإيداع أكبر من الرصيد المتبقي.');
    const t = { id: old?.id || transferId, date: key, amount, createdAt: old?.createdAt || createdAt };
    state.transfers = (state.transfers || []).filter(t => t.id !== editId); state.transfers.push(t);
  }
  function assert(ok, message = 'ملف البيانات غير صالح.') { if (!ok) throw new Error(message); }
  function money(n, signed = false) { assert(Number.isSafeInteger(n) && Math.abs(n) <= 1e12 && (signed || n >= 0)); return n; }
  function string(s, max = 2000) { assert(typeof s === 'string' && s.length <= max); return s; }
  function id(s) { assert(typeof s === 'string' && /^[a-zA-Z0-9_-]{1,80}$/.test(s)); return s; }
  function validate(raw) {
    assert(raw && [1, 2].includes(raw.version) && Array.isArray(raw.categories) && raw.categories.length >= 4 && raw.categories.length <= 500);
    const categories = raw.categories.map(c => ({ id: id(c.id), name: string(c.name, 80).trim() }));
    const names = new Set(categories.map(c => c.name)); const ids = new Set(categories.map(c => c.id));
    assert(ids.size === categories.length && names.size === categories.length && categories.every(c => c.name.length > 0));
    assert(core.every(c => categories.some(x => x.id === c.id && x.name === c.name)), 'الخانات الرئيسية مفقودة من الملف.');
    assert(raw.days && typeof raw.days === 'object' && !Array.isArray(raw.days) && Object.keys(raw.days).length <= 50000);
    const days = {}; const expenseIds = new Set();
    for (const [key, d] of Object.entries(raw.days)) {
      assert(validDate(key)); assert(d && Array.isArray(d.expenses) && d.expenses.length <= 10000);
      const expenses = d.expenses.map(e => {
        assert(ids.has(e.categoryId)); const key = id(e.id); assert(!expenseIds.has(key)); expenseIds.add(key);
        const amount = money(e.amount), f = funding(e);
        assert(['daily', 'cash', 'shared'].includes(f.source), 'مصدر الدفع غير صالح.');
        const dailyAmount = money(f.dailyAmount), cashAmount = money(f.cashAmount);
        assert(dailyAmount + cashAmount === amount, 'مجموع حصة اليومي والقاصة لازم يساوي مبلغ المصروف.');
        assert(f.source !== 'daily' || cashAmount === 0, 'مصروف اليومي ما يحتوي حصة من القاصة.');
        assert(f.source !== 'cash' || dailyAmount === 0, 'مصروف القاصة ما يحتوي حصة من اليومي.');
        const clean = { id: key, categoryId: e.categoryId, amount, note: string(e.note), funding: { source: f.source, dailyAmount, cashAmount } };
        if (e.createdAt !== undefined) { string(e.createdAt, 40); assert(!isNaN(Date.parse(e.createdAt))); clean.createdAt = e.createdAt; }
        return clean;
      });
      assert(Number.isSafeInteger(expenses.reduce((s, e) => s + e.amount, 0)), 'مجموع المصاريف أكبر من الحد الدقيق للحساب.');
      let snapshot = null;
      if (d.remaining != null) { const r = d.remaining; assert(Number.isSafeInteger(r.dailySpent) && r.dailySpent >= 0 && Number.isSafeInteger(r.transferred) && r.transferred >= 0); snapshot = { amount: money(r.amount), dailySpent: r.dailySpent, transferred: r.transferred }; }
      days[key] = { expenses, chickenUsed: money(d.chickenUsed), chickenLeft: money(d.chickenLeft), balance: d.balance === null ? null : money(d.balance, true), totalOverride: d.totalOverride === null ? null : money(d.totalOverride), remaining: snapshot };
    }
    assert(Array.isArray(raw.transactions) && raw.transactions.length <= 100000);
    const txIds = new Set();
    const transactions = raw.transactions.map(t => { const key = id(t.id); assert(!txIds.has(key)); txIds.add(key); assert(validDate(t.date) && ['deposit', 'withdrawal'].includes(t.type) && t.amount > 0); string(t.createdAt, 40); assert(!isNaN(Date.parse(t.createdAt))); return { id: key, date: t.date, type: t.type, amount: money(t.amount), note: string(t.note), createdAt: t.createdAt }; });
    const rawTransfers = raw.transfers ?? []; assert(Array.isArray(rawTransfers) && rawTransfers.length <= 100000);
    const transferIds = new Set();
    const transfers = rawTransfers.map(t => { const key = id(t.id); assert(!transferIds.has(key)); transferIds.add(key); assert(validDate(t.date) && days[t.date]?.remaining != null, 'إيداع الرصيد اليومي يحتاج رصيداً مسجّلاً.'); money(t.amount); assert(t.amount > 0); string(t.createdAt, 40); assert(!isNaN(Date.parse(t.createdAt))); return { id: key, date: t.date, amount: t.amount, createdAt: t.createdAt }; });
    const clean = { version: 2, categories, days, transactions, transfers };
    let cashTotal = 0;
    for (const t of movements(clean)) { cashTotal += t.type === 'withdrawal' ? -t.amount : t.amount; assert(Number.isSafeInteger(cashTotal), 'مجموع حركات القاصة أكبر من الحد الدقيق للحساب.'); }
    for (const key of Object.keys(days)) { assert(Number.isSafeInteger(transferred(clean, key)), 'الإيداعات تتجاوز الحد الدقيق للحساب.'); const r = remaining(clean, key); assert(r === null || Number.isSafeInteger(r), 'الرصيد المتبقي يتجاوز الحد الدقيق للحساب.'); }
    return clean;
  }
  return { empty, dateKey, validDate, numeric, day, total, funding, dailySpent, transferred, remaining, recordRemaining, movements, transferRemaining, cash, validate };
});
