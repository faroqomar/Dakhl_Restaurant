(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.DaftarModel = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const core = [{ id: 'samoon', name: 'الصمون' }, { id: 'bread', name: 'الخبز' }, { id: 'falafel', name: 'الفلافل' }, { id: 'market', name: 'الأسواق' }];
  function empty() { return { version: 4, categories: core.map(c => ({ ...c, type: 'primary' })), days: {}, transactions: [], transfers: [], suppliers: [], invoices: [], payments: [], debts: [] }; }
  function dateKey(d = new Date()) { return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; }
  function validDate(s) { if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false; const d = new Date(`${s}T12:00:00`); return !isNaN(d) && dateKey(d) === s; }
  function numeric(raw, { signed = false, positive = false } = {}) {
    const s = String(raw).trim().replace(/[٠-٩]/g, d => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d))).replace(/[۰-۹]/g, d => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d))).replace(/[,٬\s]/g, '');
    if (!(signed ? /^-?\d+$/ : /^\d+$/).test(s)) throw new Error('اكتب مبلغاً صحيحاً بالدينار، بدون كسور.');
    const n = Number(s); if (!Number.isSafeInteger(n) || Math.abs(n) > 1e12 || (positive && n <= 0)) throw new Error('المبلغ خارج الحد المسموح أو يساوي صفر.');
    return n;
  }
  function day(state, key) { return state.days[key] || { expenses: [], chickenUsed: 0, chickenLeft: 0, balance: null, totalOverride: null, remaining: null }; }
  function total(state, key) { const d = day(state, key); return d.totalOverride ?? expenses(state, key).reduce((s, e) => s + e.amount, 0); }
  function funding(e) { return e.funding || { source: 'daily', dailyAmount: e.amount, cashAmount: 0 }; }
  function dailySpent(state, key) { return expenses(state, key).reduce((sum, e) => sum + funding(e).dailyAmount, 0); }
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
    for (const date of new Set([...Object.keys(state.days), ...(state.payments || []).map(p => p.date)])) for (const e of expenses(state, date)) {
      const f = funding(e);
      if (f.cashAmount) result.push({ id: e.id, date, type: 'withdrawal', kind: e.kind || 'expense', supplierId: e.supplierId, amount: f.cashAmount, note: e.note, categoryId: e.categoryId, createdAt: e.createdAt || `${date}T12:00:00.000Z` });
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
  function recordedDays(state) {
    return [...new Set([...Object.entries(state.days).filter(([, d]) => d.expenses.length || d.chickenUsed || d.chickenLeft || d.balance != null || d.totalOverride != null || d.remaining != null).map(([date]) => date), ...['payments', 'transactions', 'transfers'].flatMap(key => (state[key] || []).map(e => e.date))])].sort();
  }
  function dayDatePlan(state, from, to, end = from) {
    assert(validDate(from) && validDate(to) && validDate(end), 'اختار تواريخ صحيحة.');
    assert(from !== to, 'اختار تاريخاً مختلفاً عن التاريخ الحالي.');
    assert(end >= from, 'آخر يوم لازم يكون نفس يوم البداية أو بعده.');
    const dates = recordedDays(state), selected = dates.filter(date => date >= from && date <= end);
    assert(dates.includes(from), 'ماكو سجل يومي بهذا التاريخ.');
    const offset = Date.parse(to + 'T00:00:00Z') - Date.parse(from + 'T00:00:00Z');
    const originals = new Set(selected), recorded = new Set(dates);
    return selected.map(date => {
      const destination = new Date(Date.parse(date + 'T00:00:00Z') + offset).toISOString().slice(0, 10);
      assert(validDate(destination), 'التاريخ الجديد خارج المجال المسموح.');
      assert(!recorded.has(destination) || originals.has(destination), 'التاريخ ' + destination + ' بيه سجل آخر. فعّل تصحيح الأيام التالية وحدّد آخر يوم حتى ما تتداخل الحسابات.');
      return { from: date, to: destination };
    });
  }
  function correctDayDates(state, from, to, end = from) {
    const plan = dayDatePlan(state, from, to, end), mapping = new Map(plan.map(p => [p.from, p.to]));
    const next = structuredClone(state), destinations = new Set(plan.map(p => p.to));
    // Build a new map: moving adjacent days must never overwrite a day still being moved.
    next.days = Object.fromEntries(Object.entries(next.days).filter(([date]) => mapping.has(date) || !destinations.has(date)).map(([date, d]) => [mapping.get(date) || date, d]));
    for (const key of ['payments', 'transactions', 'transfers']) for (const e of next[key] || []) e.date = mapping.get(e.date) || e.date;
    // Supplier bills and debt records keep their own dates. Validation rejects payments before their bill/debt.
    return validate(next);
  }
  function quantity(raw) {
    const s = String(raw).trim().replace(/[٠-٩]/g, d => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d))).replace(/[۰-۹]/g, d => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d))).replace(/٫/g, '.').replace(/[,٬\s]/g, '');
    assert(/^\d+(?:\.\d{1,3})?$/.test(s), 'اكتب كمية موجبة، بحد أقصى 3 أرقام بعد الفاصلة.');
    const n = Number(s); assert(n > 0 && n <= 1e9, 'الكمية خارج الحد المسموح.'); return n;
  }
  function lineTotal(line) {
    const scaled = Math.round(quantity(line.quantity) * 1000), product = scaled * money(line.price);
    assert(Number.isSafeInteger(product), 'قيمة المادة أكبر من الحد الدقيق للحساب.'); return money(Math.round(product / 1000));
  }
  function invoiceTotal(invoice) { return money(invoice.lines.reduce((sum, line) => sum + lineTotal(line), 0)); }
  function paymentAllocation(p) { return { invoiceAmount: p.invoiceAmount === undefined ? (p.invoiceId ? p.amount : 0) : p.invoiceAmount, debtAmount: p.debtAmount === undefined ? (p.invoiceId ? 0 : p.amount) : p.debtAmount }; }
  function invoicePaid(state, invoiceId) { return (state.payments || []).filter(p => p.invoiceId === invoiceId).reduce((sum, p) => sum + paymentAllocation(p).invoiceAmount, 0); }
  function invoiceDue(state, invoiceId) { const inv = (state.invoices || []).find(i => i.id === invoiceId); return inv ? invoiceTotal(inv) - invoicePaid(state, invoiceId) : 0; }
  function debtAvailable(state, supplierId, date = '9999-12-31', excludeId = null) {
    return ((state.suppliers || []).find(s => s.id === supplierId)?.openingBalance || 0) + (state.debts || []).filter(d => d.supplierId === supplierId && d.date <= date).reduce((sum, d) => sum + d.amount, 0) - (state.payments || []).filter(p => p.supplierId === supplierId && p.id !== excludeId).reduce((sum, p) => sum + paymentAllocation(p).debtAmount, 0);
  }
  function openingDue(state, supplierId) { return debtAvailable(state, supplierId); }
  function splitPayment(state, supplierId, invoiceId, amount, date, excludeId = null) {
    money(amount); assert(amount > 0, 'مبلغ التسديد لازم يكون أكبر من صفر.'); assert(validDate(date));
    assert((state.suppliers || []).some(s => s.id === supplierId), 'المورد غير موجود.');
    const invoice = invoiceId ? (state.invoices || []).find(i => i.id === invoiceId) : null;
    assert(!invoiceId || (invoice?.supplierId === supplierId && date >= invoice.date), 'اختار قائمة لهذا المورد وتاريخاً لا يسبقها.');
    const other = { ...state, payments: (state.payments || []).filter(p => p.id !== excludeId) };
    const invoiceAmount = invoiceId ? Math.min(amount, Math.max(0, invoiceDue(other, invoiceId))) : 0;
    const debtAmount = amount - invoiceAmount;
    assert(debtAmount <= Math.max(0, debtAvailable(other, supplierId, date)), 'مبلغ التسديد يتجاوز المتبقي من القائمة والديون المتاحة بهذا التاريخ.');
    return { invoiceAmount, debtAmount };
  }
  function supplierBalance(state, supplierId) { return ((state.suppliers || []).find(s => s.id === supplierId)?.openingBalance || 0) + (state.debts || []).filter(d => d.supplierId === supplierId).reduce((sum, d) => sum + d.amount, 0) + (state.invoices || []).filter(i => i.supplierId === supplierId).reduce((sum, i) => sum + invoiceTotal(i), 0) - (state.payments || []).filter(p => p.supplierId === supplierId).reduce((sum, p) => sum + p.amount, 0); }
  function supplierEvents(state, supplierId) {
    return [...(state.invoices || []).filter(i => i.supplierId === supplierId).map(i => ({ ...i, type: 'invoice', amount: invoiceTotal(i) })), ...(state.debts || []).filter(d => d.supplierId === supplierId).map(d => ({ ...d, type: 'debt' })), ...(state.payments || []).filter(p => p.supplierId === supplierId).map(p => ({ ...p, type: 'payment' }))].sort((a, b) => a.date.localeCompare(b.date) || a.createdAt.localeCompare(b.createdAt) || (Number(a.type === 'payment') - Number(b.type === 'payment') || a.id.localeCompare(b.id)));
  }
  function supplierLedger(state, supplierId) {
    let balance = (state.suppliers || []).find(s => s.id === supplierId)?.openingBalance || 0;
    return supplierEvents(state, supplierId).map(e => { const before = balance; balance += e.type !== 'payment' ? e.amount : -e.amount; return { ...e, before, balance }; });
  }
  function balanceBefore(state, supplierId, date, createdAt, excludeId = null) {
    return ((state.suppliers || []).find(s => s.id === supplierId)?.openingBalance || 0) + supplierEvents(state, supplierId).filter(e => e.id !== excludeId && (e.date < date || (e.date === date && (e.createdAt < createdAt || (e.createdAt === createdAt && e.type !== 'payment'))))).reduce((sum, e) => sum + (e.type !== 'payment' ? e.amount : -e.amount), 0);
  }
  function expenses(state, key) {
    return [...day(state, key).expenses, ...(state.payments || []).filter(p => p.date === key).map(p => {
      const supplier = (state.suppliers || []).find(s => s.id === p.supplierId), invoice = (state.invoices || []).find(i => i.id === p.invoiceId);
      return { ...p, kind: 'supplier-payment', note: `تسديد ${supplier?.name || 'مورد'} · ${invoice ? 'قائمة ' + invoice.number + (paymentAllocation(p).debtAmount ? ` · ديون ${paymentAllocation(p).debtAmount} د.ع` : '') : 'الديون'}${p.note ? ' · ' + p.note : ''}` };
    })];
  }
  function allocation(amount, f) {
    assert(f && ['daily', 'cash', 'shared'].includes(f.source), 'مصدر الدفع غير صالح.');
    const dailyAmount = money(f.dailyAmount), cashAmount = money(f.cashAmount);
    assert(dailyAmount + cashAmount === amount, 'مجموع حصة اليومي والقاصة لازم يساوي مبلغ المصروف.');
    assert(f.source !== 'daily' || cashAmount === 0, 'مصروف اليومي ما يحتوي حصة من القاصة.');
    assert(f.source !== 'cash' || dailyAmount === 0, 'مصروف القاصة ما يحتوي حصة من اليومي.');
    return { source: f.source, dailyAmount, cashAmount };
  }
  function validateSuppliers(raw, categoryIds) {
    const rawSuppliers = raw.suppliers ?? [], rawInvoices = raw.invoices ?? [], rawPayments = raw.payments ?? [], rawDebts = raw.debts ?? [];
    assert(Array.isArray(rawSuppliers) && rawSuppliers.length <= 5000 && Array.isArray(rawInvoices) && rawInvoices.length <= 100000 && Array.isArray(rawPayments) && rawPayments.length <= 100000 && Array.isArray(rawDebts) && rawDebts.length <= 100000);
    const supplierIds = new Set(), supplierNames = new Set(), invoiceIds = new Set(), paymentIds = new Set(), invoiceNumbers = new Set();
    const suppliers = rawSuppliers.map(s => {
      const key = id(s.id), name = string(s.name, 100).trim(); assert(name && !supplierIds.has(key) && !supplierNames.has(name.toLowerCase()), 'اسم المورد موجود أو غير صالح.'); supplierIds.add(key); supplierNames.add(name.toLowerCase());
      assert(categoryIds.has(s.categoryId), 'خانة مصروف المورد غير موجودة.'); assert(Array.isArray(s.materials) && s.materials.length <= 1000);
      const materialIds = new Set(), names = new Set();
      const materials = s.materials.map(m => { const key = id(m.id), name = string(m.name, 100).trim(), unit = string(m.unit, 30).trim(); assert(name && unit && !materialIds.has(key) && !names.has(name.toLowerCase()), 'اسم المادة مكرر أو فارغ.'); materialIds.add(key); names.add(name.toLowerCase()); assert(typeof m.archived === 'boolean'); return { id: key, name, unit, price: money(m.price), archived: m.archived }; });
      return { id: key, name, phone: string(s.phone, 80), note: string(s.note), categoryId: s.categoryId, openingBalance: money(s.openingBalance), materials };
    });
    const invoices = rawInvoices.map(i => {
      const key = id(i.id), number = string(i.number, 80).trim(); assert(!invoiceIds.has(key)); invoiceIds.add(key); assert(supplierIds.has(i.supplierId) && validDate(i.date)); assert(number && !invoiceNumbers.has(i.supplierId + ':' + number), 'رقم القائمة موجود لهذا المورد.'); invoiceNumbers.add(i.supplierId + ':' + number);
      string(i.createdAt, 40); assert(!isNaN(Date.parse(i.createdAt))); assert(Array.isArray(i.lines) && i.lines.length > 0 && i.lines.length <= 200, 'أضف مادة واحدة على الأقل للقائمة.');
      const supplier = suppliers.find(s => s.id === i.supplierId);
      const lines = i.lines.map(l => { assert(supplier.materials.some(m => m.id === l.materialId), 'المادة غير موجودة عند المورد.'); const name = string(l.name, 100).trim(), unit = string(l.unit, 30).trim(); assert(name && unit); const line = { materialId: l.materialId, name, unit, quantity: quantity(l.quantity), price: money(l.price) }; lineTotal(line); return line; });
      const inv = { id: key, supplierId: i.supplierId, number, date: i.date, lines, note: string(i.note), createdAt: i.createdAt }; assert(invoiceTotal(inv) > 0, 'مجموع القائمة لازم يكون أكبر من صفر.'); return inv;
    });
    const debtIds = new Set();
    const debts = rawDebts.map(d => {
      const key = id(d.id); assert(!debtIds.has(key)); debtIds.add(key); assert(supplierIds.has(d.supplierId) && validDate(d.date));
      const amount = money(d.amount); assert(amount > 0, 'مبلغ الدين لازم يكون أكبر من صفر.'); string(d.createdAt, 40); assert(!isNaN(Date.parse(d.createdAt)));
      return { id: key, supplierId: d.supplierId, date: d.date, amount, note: string(d.note), createdAt: d.createdAt };
    });
    const payments = rawPayments.map(p => {
      const key = id(p.id); assert(!paymentIds.has(key)); paymentIds.add(key); assert(supplierIds.has(p.supplierId) && validDate(p.date)); const invoice = p.invoiceId === null ? null : invoices.find(i => i.id === p.invoiceId); assert(p.invoiceId === null || (invoice?.supplierId === p.supplierId && p.date >= invoice.date), 'اختار قائمة لهذا المورد وتاريخاً لا يسبقها.');
      assert(categoryIds.has(p.categoryId)); const amount = money(p.amount); assert(amount > 0, 'مبلغ التسديد لازم يكون أكبر من صفر.'); string(p.createdAt, 40); assert(!isNaN(Date.parse(p.createdAt)));
      const split = paymentAllocation(p); money(split.invoiceAmount); money(split.debtAmount);
      assert(split.invoiceAmount + split.debtAmount === amount && (p.invoiceId !== null || split.invoiceAmount === 0), 'توزيع التسديد بين القائمة والديون غير صالح.');
      return { id: key, supplierId: p.supplierId, invoiceId: p.invoiceId, ...split, categoryId: p.categoryId, date: p.date, amount, funding: allocation(amount, p.funding), note: string(p.note), createdAt: p.createdAt };
    });
    const state = { suppliers, invoices, payments, debts };
    for (const i of invoices) assert(invoicePaid(state, i.id) <= invoiceTotal(i), 'التسديد يتجاوز قيمة القائمة؛ عدّل التسديد أولاً.');
    for (const s of suppliers) { assert(openingDue(state, s.id) >= 0, 'تسديد الديون والرصيد القديم أكبر من قيمته.');
      let available = s.openingBalance;
      const timeline = [...debts.filter(d => d.supplierId === s.id).map(d => ({ ...d, credit: true })), ...payments.filter(p => p.supplierId === s.id).map(p => ({ ...p, credit: false }))].sort((a, b) => a.date.localeCompare(b.date) || Number(b.credit) - Number(a.credit));
      for (const e of timeline) { available += e.credit ? e.amount : -e.debtAmount; assert(Number.isSafeInteger(available), 'الديون تتجاوز الحد الدقيق للحساب.'); assert(available >= 0, 'تسديد الديون يسبق تسجيلها أو يتجاوز قيمتها.'); }
       assert(Number.isSafeInteger(supplierBalance(state, s.id)), 'رصيد المورد يتجاوز الحد الدقيق للحساب.'); for (const e of supplierLedger(state, s.id)) assert(Number.isSafeInteger(e.balance), 'رصيد المورد يتجاوز الحد الدقيق للحساب.'); }
    return state;
  }
  function assert(ok, message = 'ملف البيانات غير صالح.') { if (!ok) throw new Error(message); }
  function money(n, signed = false) { assert(Number.isSafeInteger(n) && Math.abs(n) <= 1e12 && (signed || n >= 0)); return n; }
  function string(s, max = 2000) { assert(typeof s === 'string' && s.length <= max); return s; }
  function id(s) { assert(typeof s === 'string' && /^[a-zA-Z0-9_-]{1,80}$/.test(s)); return s; }
  function validate(raw) {
    assert(raw && [1, 2, 3, 4].includes(raw.version) && Array.isArray(raw.categories) && raw.categories.length >= 4 && raw.categories.length <= 500);
    // Older files have no type; infer it from stable IDs, never array position.
    const categories = raw.categories.map(c => {
      const type = c.type === undefined ? (core.some(x => x.id === c.id) ? 'primary' : 'additional') : c.type;
      assert(['primary', 'additional'].includes(type), 'نوع الخانة غير صالح.');
      return { id: id(c.id), name: string(c.name, 80).trim(), type };
    });
    const names = new Set(categories.map(c => c.name)); const ids = new Set(categories.map(c => c.id));
    assert(ids.size === categories.length && names.size === categories.length && categories.every(c => c.name.length > 0));
    assert(core.every(c => categories.some(x => x.id === c.id && x.name === c.name)), 'الخانات الأصلية مفقودة من الملف.');
    assert(raw.days && typeof raw.days === 'object' && !Array.isArray(raw.days) && Object.keys(raw.days).length <= 50000);
    const days = {}; const expenseIds = new Set();
    for (const [key, d] of Object.entries(raw.days)) {
      assert(validDate(key)); assert(d && Array.isArray(d.expenses) && d.expenses.length <= 10000);
      const expenses = d.expenses.map(e => {
        assert(ids.has(e.categoryId)); const key = id(e.id); assert(!expenseIds.has(key)); expenseIds.add(key);
        const amount = money(e.amount), f = funding(e);
        const clean = { id: key, categoryId: e.categoryId, amount, note: string(e.note), funding: allocation(amount, f) };
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
    const clean = { version: 4, categories, days, transactions, transfers, ...validateSuppliers(raw, ids) };
    for (const date of new Set([...Object.keys(days), ...clean.payments.map(p => p.date)])) assert(Number.isSafeInteger(expenses(clean, date).reduce((sum, e) => sum + e.amount, 0)), 'مجموع المصاريف أكبر من الحد الدقيق للحساب.');
    let cashTotal = 0;
    for (const t of movements(clean)) { cashTotal += t.type === 'withdrawal' ? -t.amount : t.amount; assert(Number.isSafeInteger(cashTotal), 'مجموع حركات القاصة أكبر من الحد الدقيق للحساب.'); }
    for (const key of Object.keys(days)) { assert(Number.isSafeInteger(transferred(clean, key)), 'الإيداعات تتجاوز الحد الدقيق للحساب.'); const r = remaining(clean, key); assert(r === null || Number.isSafeInteger(r), 'الرصيد المتبقي يتجاوز الحد الدقيق للحساب.'); }
    return clean;
  }
  return { empty, dateKey, validDate, numeric, day, total, funding, dailySpent, transferred, remaining, recordRemaining, movements, transferRemaining, cash, validate, recordedDays, dayDatePlan, correctDayDates, quantity, lineTotal, invoiceTotal, invoicePaid, invoiceDue, paymentAllocation, splitPayment, debtAvailable, openingDue, supplierBalance, supplierLedger, balanceBefore, expenses, allocation };
});
