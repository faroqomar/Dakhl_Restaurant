(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.DaftarModel = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const core = [{ id: 'samoon', name: 'الصمون' }, { id: 'bread', name: 'الخبز' }, { id: 'falafel', name: 'الفلافل' }, { id: 'market', name: 'الأسواق' }];
  function empty() { return { version: 11, products: [], stockEntries: [], sales: [], saleReturns: [], preferences: { shortcuts: [...defaultShortcuts], orderTypes: [...defaultOrderTypes], restaurant: { name: '', contact: '', footer: '' } }, categories: core.map(c => ({ ...c, type: 'primary' })), days: {}, transactions: [], transfers: [], suppliers: [], materials: [], invoices: [], payments: [], debts: [], workers: [], savingsEntries: [] }; }
  function dateKey(d = new Date()) { return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; }
  function validDate(s) { if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false; const d = new Date(`${s}T12:00:00`); return !isNaN(d) && dateKey(d) === s; }
  function numeric(raw, { signed = false, positive = false } = {}) {
    const s = String(raw).trim().replace(/[٠-٩]/g, d => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d))).replace(/[۰-۹]/g, d => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d))).replace(/[,٬\s]/g, '');
    if (!(signed ? /^-?\d+$/ : /^\d+$/).test(s)) throw new Error('اكتب مبلغاً صحيحاً بالدينار، بدون كسور.');
    const n = Number(s); if (!Number.isSafeInteger(n) || Math.abs(n) > 1e12 || (positive && n <= 0)) throw new Error('المبلغ خارج الحد المسموح أو يساوي صفر.');
    return n;
  }
  function day(state, key) { return state.days[key] || { expenses: [], chickenUsed: 0, chickenLeft: 0, balance: null, totalOverride: null, remaining: null }; }
  function total(state, key) { const d = day(state, key); return d.totalOverride ?? dailySpent(state, key); }
  function funding(e) { return e.funding || { source: 'daily', dailyAmount: e.amount, cashAmount: 0 }; }
  function dailySpent(state, key) { return expenses(state, key).reduce((sum, e) => sum + funding(e).dailyAmount, 0); }
  function transferred(state, key) { return (state.transfers || []).filter(t => t.date === key).reduce((sum, t) => sum + t.amount, 0); }
  // A manual remainder is a snapshot AFTER existing expenses and transfers.
  // Only subsequent differences are applied, including edits and deletions.
  function remaining(state, key) {
    const snapshot = day(state, key).remaining;
    return snapshot ? snapshot.amount - (dailySpent(state, key) - snapshot.dailySpent) - (transferred(state, key) - snapshot.transferred) + (salesTotal(state, key) - (snapshot.salesTotal || 0)) : null;
  }
  function balanceFromRemaining(state, key) {
    const available = remaining(state, key);
    if (available === null) return null;
    const sum = total(state, key) + available + transferred(state, key);
    assert(Number.isSafeInteger(sum) && Math.abs(sum) <= 1e12, 'الرصيد الكلي يتجاوز الحد المسموح للحساب.');
    return sum;
  }
  function recordRemaining(state, key, amount) {
    money(amount);
    const sum = total(state, key) + amount + transferred(state, key);
    assert(Number.isSafeInteger(sum) && Math.abs(sum) <= 1e12, 'الرصيد الكلي يتجاوز الحد المسموح للحساب.');
    const d = state.days[key] || (state.days[key] = { ...day(state, key) });
    d.remaining = { amount, dailySpent: dailySpent(state, key), transferred: transferred(state, key), salesTotal: salesTotal(state, key) };
    d.balance = sum;
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
    // Recover an unset total on older/manual records before the remainder is transferred.
    const d = day(state, key), sum = d.balance === null ? balanceFromRemaining(state, key) : d.balance;
    const t = { id: old?.id || transferId, date: key, amount, createdAt: old?.createdAt || createdAt };
    state.transfers = (state.transfers || []).filter(t => t.id !== editId); state.transfers.push(t); d.balance = sum;
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
    for (const p of plan) if (next.days[p.to]?.remaining && salesTotal(state, p.from) !== salesTotal(next, p.to)) {
      const r = next.days[p.to].remaining;
      const baseline = (r.salesTotal || 0) + salesTotal(next, p.to) - salesTotal(state, p.from);
      r.salesTotal = baseline;
    }
    // Supplier bills, sales, inventory and debt records keep their own dates. Validation rejects payments before their bill/debt.
    return validate(next);
  }
  function quantity(raw) {
    const s = String(raw).trim().replace(/[٠-٩]/g, d => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d))).replace(/[۰-۹]/g, d => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d))).replace(/٫/g, '.').replace(/[,٬\s]/g, '');
    assert(/^\d+(?:\.\d{1,3})?$/.test(s), 'اكتب كمية موجبة، بحد أقصى 3 أرقام بعد الفاصلة.');
    const n = Number(s); assert(n > 0 && n <= 1e9, 'الكمية خارج الحد المسموح.'); return n;
  }
  function lineTotal(line) {
    if (line.quantityCartons !== undefined || line.quantityPieces !== undefined) {
      const cartons = nonnegativeQuantity(line.quantityCartons ?? 0), pieces = nonnegativeQuantity(line.quantityPieces ?? 0);
      const cartonPrice = money(line.priceCarton ?? 0), piecePrice = money(line.pricePiece ?? 0);
      const cartonTotal = Math.round(Math.round(cartons * 1000) * cartonPrice / 1000), pieceTotal = Math.round(Math.round(pieces * 1000) * piecePrice / 1000);
      assert(Number.isSafeInteger(cartonTotal + pieceTotal), 'قيمة المادة أكبر من الحد الدقيق للحساب.'); return money(cartonTotal + pieceTotal);
    }
    const scaled = Math.round(quantity(line.quantity) * 1000), product = scaled * money(line.price);
    assert(Number.isSafeInteger(product), 'قيمة المادة أكبر من الحد الدقيق للحساب.'); return money(Math.round(product / 1000));
  }
  function nonnegativeQuantity(raw) { const s = String(raw).trim().replace(/[٠-٩]/g, d => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d))).replace(/[۰-۹]/g, d => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d))).replace(/٫/g, '.').replace(/[,٬\s]/g, ''); assert(/^\d+(?:\.\d{1,3})?$/.test(s), 'اكتب كمية صحيحة حتى 3 أرقام بعد الفاصلة.'); const n = Number(s); assert(n <= 1e9, 'الكمية خارج الحد المسموح.'); return n; }
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
  function expensesBySource(state, key, source) {
    return expenses(state, key).map(e => ({ ...e, amount: funding(e)[source === 'daily' ? 'dailyAmount' : 'cashAmount'] })).filter(e => e.amount > 0);
  }
  function allocation(amount, f) {
    assert(f && ['daily', 'cash', 'shared'].includes(f.source), 'مصدر الدفع غير صالح.');
    const dailyAmount = money(f.dailyAmount), cashAmount = money(f.cashAmount);
    assert(dailyAmount + cashAmount === amount, 'مجموع حصة اليومي والقاصة لازم يساوي مبلغ المصروف.');
    assert(f.source !== 'daily' || cashAmount === 0, 'مصروف اليومي ما يحتوي حصة من القاصة.');
    assert(f.source !== 'cash' || dailyAmount === 0, 'مصروف القاصة ما يحتوي حصة من اليومي.');
    return { source: f.source, dailyAmount, cashAmount };
  }
  function validateSuppliers(raw, categoryIds, catalogIds = new Set()) {
    const rawSuppliers = raw.suppliers ?? [], rawInvoices = raw.invoices ?? [], rawPayments = raw.payments ?? [], rawDebts = raw.debts ?? [];
    assert(Array.isArray(rawSuppliers) && rawSuppliers.length <= 5000 && Array.isArray(rawInvoices) && rawInvoices.length <= 100000 && Array.isArray(rawPayments) && rawPayments.length <= 100000 && Array.isArray(rawDebts) && rawDebts.length <= 100000);
    const supplierIds = new Set(), supplierNames = new Set(), invoiceIds = new Set(), paymentIds = new Set(), invoiceNumbers = new Set();
    const suppliers = rawSuppliers.map(s => {
      const key = id(s.id), name = string(s.name, 100).trim(); assert(name && !supplierIds.has(key) && !supplierNames.has(name.toLowerCase()), 'اسم المورد موجود أو غير صالح.'); supplierIds.add(key); supplierNames.add(name.toLowerCase());
      assert(categoryIds.has(s.categoryId), 'خانة مصروف المورد غير موجودة.'); assert(Array.isArray(s.materials ?? []) && (s.materials ?? []).length <= 1000);
      const materialIds = new Set(), names = new Set();
      const materials = (s.materials ?? []).map(m => { const key = id(m.id), name = string(m.name, 100).trim(), unit = string(m.unit, 30).trim(); assert(name && unit && !materialIds.has(key) && !names.has(name.toLowerCase()), 'اسم المادة مكرر أو فارغ.'); materialIds.add(key); names.add(name.toLowerCase()); assert(typeof m.archived === 'boolean'); return { id: key, name, unit, price: money(m.price), archived: m.archived }; });
      return { id: key, name, phone: string(s.phone, 80), note: string(s.note), categoryId: s.categoryId, openingBalance: money(s.openingBalance), ...(s.archived === true ? {archived:true} : {}), materials };
    });
    const invoices = rawInvoices.map(i => {
      const key = id(i.id), number = string(i.number, 80).trim(); assert(!invoiceIds.has(key)); invoiceIds.add(key); assert(supplierIds.has(i.supplierId) && validDate(i.date)); assert(number && !invoiceNumbers.has(i.supplierId + ':' + number), 'رقم القائمة موجود لهذا المورد.'); invoiceNumbers.add(i.supplierId + ':' + number);
      string(i.createdAt, 40); assert(!isNaN(Date.parse(i.createdAt))); assert(Array.isArray(i.lines) && i.lines.length > 0 && i.lines.length <= 200, 'أضف مادة واحدة على الأقل للقائمة.');
      const supplier = suppliers.find(s => s.id === i.supplierId);
      const lines = i.lines.map(l => { assert(supplier.materials.some(m => m.id === l.materialId) || catalogIds.has(l.materialId), 'المادة غير موجودة بقائمة المواد.'); const name = string(l.name, 100).trim(), unit = string(l.unit, 30).trim(); assert(name && unit); const line = l.quantityCartons !== undefined || l.quantityPieces !== undefined ? { materialId: l.materialId, name, unit, quantityCartons: nonnegativeQuantity(l.quantityCartons ?? 0), quantityPieces: nonnegativeQuantity(l.quantityPieces ?? 0), priceCarton: money(l.priceCarton ?? 0), pricePiece: money(l.pricePiece ?? 0), quantity: nonnegativeQuantity(l.quantityPieces ?? 0), price: money(l.pricePiece ?? 0) } : { materialId: l.materialId, name, unit, quantity: quantity(l.quantity), price: money(l.price) }; assert((line.quantity ?? 0) > 0 || (line.quantityCartons || 0) + (line.quantityPieces || 0) > 0, 'كمية المادة لازم تكون أكبر من صفر.'); lineTotal(line); return line; });
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
  // Savings are an independent worker ledger; they never enter restaurant expenses or cash.
  function savingsPeriod(worker, date) {
    assert(validDate(date) && validDate(worker.startDate), 'اختار تاريخاً صحيحاً.');
    if (date < worker.startDate) return null;
    const start = new Date(worker.startDate + 'T00:00:00Z'), target = new Date(date + 'T00:00:00Z');
    const key = d => d.toISOString().slice(0, 10);
    if (worker.frequency === 'monthly') {
      const anchor = start.getUTCDate();
      const at = months => { const y = start.getUTCFullYear(), m = start.getUTCMonth() + months; const next = new Date(start); next.setUTCFullYear(y, m + 1, 0); const last = next.getUTCDate(); const result = new Date(start); result.setUTCFullYear(y, m, Math.min(anchor, last)); return result; };
      let months = (target.getUTCFullYear() - start.getUTCFullYear()) * 12 + target.getUTCMonth() - start.getUTCMonth();
      if (at(months) > target) months--;
      return { start: key(at(months)), end: at(months + 1).getUTCFullYear() > 9999 ? '9999-12-31' : key(new Date(at(months + 1).getTime() - 86400000)) };
    }
    const interval = worker.frequency === 'weekly' ? 7 : 1;
    const offset = Math.floor((target - start) / 86400000 / interval) * interval;
    return { start: key(new Date(start.getTime() + offset * 86400000)), end: new Date(start.getTime() + (offset + interval - 1) * 86400000).getUTCFullYear() > 9999 ? '9999-12-31' : key(new Date(start.getTime() + (offset + interval - 1) * 86400000)) };
  }
  function savingsStatus(state, worker, date) {
    const period = savingsPeriod(worker, date);
    if (!period) return { period: null, due: worker.amount, paid: 0, remaining: 0 };
    const entries = (state.savingsEntries || []).filter(e => e.type === 'contribution' && e.workerId === worker.id && e.periodStart === period.start);
    const due = entries[0]?.dueAmount ?? worker.amount;
    const paid = entries.filter(e => e.date <= date).reduce((sum, e) => sum + e.amount, 0);
    return { period, due, paid, remaining: Math.max(0, due - paid) };
  }
  function savingsBalance(state, date = '9999-12-31') {
    return (state.savingsEntries || []).filter(e => e.date <= date).reduce((sum, e) => sum + (e.type === 'contribution' ? e.amount : -e.amount), 0);
  }
  function validateSavings(raw) {
    const workers = raw.workers ?? [], entries = raw.savingsEntries ?? [];
    assert(Array.isArray(workers) && workers.length <= 500 && Array.isArray(entries) && entries.length <= 100000, 'سجل السلفة أكبر من الحد المسموح.');
    const ids = new Set(), names = new Set();
    const cleanWorkers = workers.map(w => {
      const key = id(w.id), name = string(w.name, 100).trim();
      assert(name && !ids.has(key) && !names.has(name.toLowerCase()), 'اسم العامل مكرر أو فارغ.'); ids.add(key); names.add(name.toLowerCase());
      assert(['daily', 'weekly', 'monthly'].includes(w.frequency) && validDate(w.startDate) && typeof w.archived === 'boolean', 'جدول العامل غير صالح.');
      const amount = money(w.amount); assert(amount > 0, 'مبلغ اشتراك العامل لازم يكون أكبر من صفر.');
      return { id: key, name, amount, frequency: w.frequency, startDate: w.startDate, archived: w.archived, note: string(w.note) };
    });
    const entryIds = new Set(), periods = new Map();
    const savingsEntries = entries.map(e => {
      const key = id(e.id); assert(!entryIds.has(key) && ids.has(e.workerId), 'سجل السلفة مكرر أو العامل غير موجود.'); entryIds.add(key);
      assert(['contribution', 'receipt'].includes(e.type) && validDate(e.date), 'نوع حركة السلفة أو تاريخها غير صالح.');
      const amount = money(e.amount); assert(amount > 0, 'مبلغ الحركة لازم يكون أكبر من صفر.');
      string(e.createdAt, 40); assert(!isNaN(Date.parse(e.createdAt)));
      const clean = { id: key, workerId: e.workerId, type: e.type, date: e.date, amount, note: string(e.note), createdAt: e.createdAt };
      if (e.type === 'contribution') {
        const worker = cleanWorkers.find(w => w.id === e.workerId), period = savingsPeriod(worker, e.date);
        assert(period && e.periodStart === period.start && e.periodEnd === period.end, 'تاريخ الدفعة خارج فترة اشتراك العامل.');
        const due = money(e.dueAmount); assert(due > 0);
        const periodKey = e.workerId + ':' + period.start, previous = periods.get(periodKey) || { due, paid: 0 };
        assert(previous.due === due, 'مبلغ الاشتراك لهذه الفترة مختلف عن الدفعات السابقة.'); previous.paid += amount;
        assert(Number.isSafeInteger(previous.paid) && previous.paid <= due, 'الدفعات تتجاوز اشتراك العامل لهذه الفترة.'); periods.set(periodKey, previous);
        Object.assign(clean, { periodStart: period.start, periodEnd: period.end, dueAmount: due });
      }
      return clean;
    });
    let balance = 0, contributed = 0, received = 0;
    for (const e of [...savingsEntries].sort((a, b) => a.date.localeCompare(b.date) || Number(b.type === 'contribution') - Number(a.type === 'contribution') || a.id.localeCompare(b.id))) {
      contributed += e.type === 'contribution' ? e.amount : 0; received += e.type === 'receipt' ? e.amount : 0;
      assert(Number.isSafeInteger(contributed) && Number.isSafeInteger(received), 'مجموع السلفة يتجاوز الحد الدقيق للحساب.');
      balance += e.type === 'contribution' ? e.amount : -e.amount;
      assert(Number.isSafeInteger(balance) && balance >= 0, 'مبلغ الاستلام يتجاوز المتجمع بالسلفة بهذا التاريخ.');
    }
    return { workers: cleanWorkers, savingsEntries };
  }
  function assert(ok, message = 'ملف البيانات غير صالح.') { if (!ok) throw new Error(message); }
  function money(n, signed = false) { assert(Number.isSafeInteger(n) && Math.abs(n) <= 1e12 && (signed || n >= 0)); return n; }
  function string(s, max = 2000) { assert(typeof s === 'string' && s.length <= max); return s; }
  function id(s) { assert(typeof s === 'string' && /^[a-zA-Z0-9_-]{1,80}$/.test(s)); return s; }
  function materialCatalogInput(raw) {
    if (raw.materials !== undefined && raw.version >= 7) return raw.materials;
    const merged = new Map(), usedIds = new Set((raw.suppliers || []).flatMap(s => Array.isArray(s.materials) ? s.materials.map(m => m.id) : []));
    let serial = 1;
    for (const supplier of raw.suppliers || []) for (const material of supplier.materials || []) {
      const key = String(material.name || '').trim().toLocaleLowerCase();
      if (!key || merged.has(key)) continue;
      let materialId; do { materialId = `catalog-${serial++}`; } while (usedIds.has(materialId)); usedIds.add(materialId);
      merged.set(key, { id: materialId, name: material.name, unit: material.unit, priceCarton: 0, pricePiece: material.price, archived: Boolean(material.archived) });
    }
    return [...merged.values()];
  }
  function validateMaterials(rawMaterials) {
    assert(Array.isArray(rawMaterials) && rawMaterials.length <= 5000, 'قائمة المواد أكبر من الحد المسموح.');
    const ids = new Set(), names = new Set();
    return rawMaterials.map(m => {
      const key = id(m.id), name = string(m.name, 100).trim(), unit = string(m.unit, 30).trim(), nameKey = name.toLocaleLowerCase();
      assert(name && unit && !ids.has(key) && !names.has(nameKey), 'اسم المادة مكرر أو بياناتها غير صالحة.'); ids.add(key); names.add(nameKey);
      assert(typeof m.archived === 'boolean');
      return { id: key, name, unit, priceCarton: money(m.priceCarton ?? 0), pricePiece: money(m.pricePiece ?? m.price ?? 0), archived: m.archived };
    });
  }
  const destinations = ['sales', 'sale-history', 'inventory', 'expenses', 'statement', 'suppliers', 'invoices', 'materials', 'payments', 'cash', 'categories', 'settings'];
  const defaultShortcuts = ['sales', 'inventory', 'sale-history', 'expenses', 'cash', 'settings'];
  const defaultOrderTypes = ['صالة', 'سفري', 'توصيل'];
  const productPhotos = ['beef-kebab', 'chicken-kebab', 'grilled-chicken', 'dulaimiya', 'red-rice', 'appetizers', 'water', 'cola'];
  function saleSubtotal(sale) { return money(sale.lines.reduce((sum, l) => sum + lineTotal(l), 0)); }
  function saleTotal(sale) { const subtotal = saleSubtotal(sale), discount = money(sale.discount); assert(discount <= subtotal, 'الخصم أكبر من مجموع الفاتورة.'); return subtotal - discount; }
  function salesTotal(state, date) { return money((state.sales || []).filter(s => s.date === date && s.status === 'completed').reduce((sum, s) => sum + saleTotal(s), 0) - (state.saleReturns || []).filter(r => r.date === date).reduce((n,r)=>n+r.amount,0), true); }
  function saleRefundTotal(state, saleId) { return (state.saleReturns || []).filter(r=>r.saleId===saleId).reduce((n,r)=>n+r.amount,0); }
  function saleReturnable(state, saleId) {
    const sale=(state.sales||[]).find(s=>s.id===saleId); assert(sale, 'الفاتورة غير موجودة.');
    return sale.lines.map(l=>{const returned=Math.round((state.saleReturns||[]).filter(r=>r.saleId===saleId).flatMap(r=>r.lines).filter(x=>x.productId===l.productId).reduce((n,x)=>n+Math.round(x.quantity*1000),0));return {...l,returnedQuantity:returned/1000,returnableQuantity:(Math.round(l.quantity*1000)-returned)/1000};});
  }
  // Allocate integer dinars with cumulative floors; full returns exactly equal the discounted total.
  function returnQuote(state, saleId, requested) {
    const sale=(state.sales||[]).find(s=>s.id===saleId); assert(sale?.status==='completed','الفاتورة ملغاة أو غير موجودة.');
    assert(Array.isArray(requested)&&requested.length>0&&requested.length<=sale.lines.length,'اختر أصناف المرتجع.');
    const available=saleReturnable(state,saleId), subtotal=saleSubtotal(sale), net=saleTotal(sale), budgets=new Map(); let gross=0,allocated=0;
    for(const l of sale.lines){gross+=lineTotal(l);const target=subtotal?Number(BigInt(gross)*BigInt(net)/BigInt(subtotal)):0;budgets.set(l.productId,target-allocated);allocated=target;}
    const used=new Set();
    const lines=requested.map(x=>{const l=available.find(l=>l.productId===x.productId);assert(l&&!used.has(x.productId),'صنف المرتجع غير صالح أو مكرر.');used.add(x.productId);const q=quantity(x.quantity),units=Math.round(q*1000),remainingUnits=Math.round(l.returnableQuantity*1000);assert(units<=remainingUnits,'كمية المرتجع أكبر من الكمية المتبقية.');assert(typeof x.restock==='boolean'&&(!x.restock||l.trackStock),'إعادة المخزون غير صالحة لهذا الصنف.');const already=Math.round(l.returnedQuantity*1000),sold=Math.round(l.quantity*1000),budget=BigInt(budgets.get(l.productId));const amount=Number(budget*BigInt(already+units)/BigInt(sold)-budget*BigInt(already)/BigInt(sold));return {productId:l.productId,quantity:q,restock:x.restock,amount};});
    return {lines,amount:money(lines.reduce((n,l)=>n+l.amount,0))};
  }
  function validateSaleReturns(raw, sales) {
    const source=raw.saleReturns??[];assert(Array.isArray(source)&&source.length<=100000,'سجل المرتجعات غير صالح.');const records=[],ids=new Set();
    for(const r of source){const key=id(r.id);assert(!ids.has(key),'المرتجع محفوظ مسبقاً.');ids.add(key);const sale=sales.find(s=>s.id===r.saleId);assert(sale&&validDate(r.date)&&r.date>=sale.date,'تاريخ المرتجع يسبق البيع أو غير صالح.');const reason=string(r.reason,500).trim();assert(reason,'اكتب سبب المرتجع.');const createdAt=string(r.createdAt,40);assert(!isNaN(Date.parse(createdAt)));const quote=returnQuote({sales,saleReturns:records},r.saleId,r.lines);assert(r.amount===quote.amount&&r.lines.every((l,i)=>l.amount===quote.lines[i].amount),'مبلغ المرتجع لا يطابق الفاتورة.');records.push({id:key,saleId:r.saleId,date:r.date,reason,createdAt,...quote});}
    return records;
  }
  function returnSale(state,saleId,request,returnId,createdAt) {
    assert(validDate(request.date)&&request.date<=dateKey(),'اختار تاريخ مرتجع صحيحاً لا يتجاوز اليوم.');
    const quote=returnQuote(state,saleId,request.lines);
    return validate({...state,saleReturns:[...(state.saleReturns||[]),{id:returnId,saleId,date:request.date,reason:request.reason,createdAt,...quote}]});
  }
  // Quantities are accumulated as integer thousandths, including deductions from sales.
  function stock(state, productId, date = '9999-12-31') {
    const incoming = (state.stockEntries || []).filter(e => e.productId === productId && e.date <= date).reduce((sum, e) => sum + Math.round(e.quantity * 1000), 0);
    const outgoing = (state.sales || []).filter(s => s.status === 'completed' && s.date <= date).reduce((sum, s) => sum + s.lines.filter(l => l.productId === productId && l.trackStock).reduce((n, l) => n + Math.round(l.quantity * 1000), 0), 0);
    const returned=(state.saleReturns||[]).filter(r=>r.date<=date).flatMap(r=>r.lines).filter(l=>l.productId===productId&&l.restock).reduce((n,l)=>n+Math.round(l.quantity*1000),0);
    return (incoming - outgoing + returned) / 1000;
  }
  function stockBalances(state, date = '9999-12-31') {
    const balances=new Map(), add=(id,quantity)=>balances.set(id,(balances.get(id)||0)+Math.round(quantity*1000));
    for(const e of state.stockEntries||[]) if(e.date<=date)add(e.productId,e.quantity);
    for(const s of state.sales||[]) if(s.status==='completed'&&s.date<=date)for(const l of s.lines)if(l.trackStock)add(l.productId,-l.quantity);
    for(const r of state.saleReturns||[])if(r.date<=date)for(const l of r.lines)if(l.restock)add(l.productId,l.quantity);
    return new Map([...balances].map(([id,n])=>[id,n/1000]));
  }
  function validateCommerce(raw) {
    const rawProducts = raw.products ?? [], rawEntries = raw.stockEntries ?? [], rawSales = raw.sales ?? [];
    assert(Array.isArray(rawProducts) && rawProducts.length <= 10000 && Array.isArray(rawEntries) && rawEntries.length <= 100000 && Array.isArray(rawSales) && rawSales.length <= 100000);
    const productIds = new Set(), names = new Set(), codes = new Set();
    const products = rawProducts.map(p => {
      const key = id(p.id), name = string(p.name, 100).trim(), code = string(p.code, 80).trim(), unit = string(p.unit, 30).trim();
      assert(name && unit && !productIds.has(key) && !names.has(name.toLowerCase()), 'اسم الصنف مكرر أو فارغ.');
      assert(!code || !codes.has(code.toLowerCase()), 'رمز الصنف مستخدم.'); productIds.add(key); names.add(name.toLowerCase()); if (code) codes.add(code.toLowerCase());
      assert(typeof p.trackStock === 'boolean' && typeof p.archived === 'boolean');
      assert(p.photo === undefined || p.photo === '' || productPhotos.includes(p.photo), 'صورة الصنف غير صالحة.');
      return { ...(p.photo ? { photo: p.photo } : {}), id: key, name, code, unit, price: money(p.price), group: string(p.group, 60).trim(), minStock: nonnegativeQuantity(p.minStock), trackStock: p.trackStock, archived: p.archived };
    });
    const productIndex=new Map(products.map(p=>[p.id,p]));
    const entryIds = new Set();
    const stockEntries = rawEntries.map(e => {
      const key = id(e.id); assert(!entryIds.has(key) && productIds.has(e.productId)); entryIds.add(key); assert(validDate(e.date));
      assert(typeof e.quantity === 'number' && Number.isFinite(e.quantity) && e.quantity !== 0); nonnegativeQuantity(Math.abs(e.quantity));
      string(e.createdAt, 40); assert(!isNaN(Date.parse(e.createdAt))); assert(['opening', 'restock', 'adjustment'].includes(e.kind));
      assert(e.kind === 'adjustment' || e.quantity > 0, 'كمية الإضافة لازم تكون موجبة.');
      assert(productIndex.get(e.productId).trackStock, 'الصنف غير خاضع لتتبّع المخزون.');
      return { id: key, productId: e.productId, date: e.date, quantity: e.quantity, kind: e.kind, note: string(e.note), createdAt: e.createdAt, ...(e.reversesId ? { reversesId: id(e.reversesId) } : {}) };
    });
    const reversed = new Set();
    for (const e of stockEntries.filter(e => e.reversesId)) { const old = stockEntries.find(x => x.id === e.reversesId); assert(old && !old.reversesId && old.productId === e.productId && !reversed.has(old.id) && e.quantity === -old.quantity && e.date === old.date && e.note.trim(), 'تصحيح حركة المخزن غير صالح أو مكرر.'); reversed.add(old.id); }
    const saleIds = new Set(), numbers = new Set();
    const sales = rawSales.map(s => {
      const key = id(s.id), number = string(s.number, 80).trim(); assert(!saleIds.has(key) && number && !numbers.has(number), 'رقم فاتورة البيع مكرر.'); saleIds.add(key); numbers.add(number);
      assert(validDate(s.date) && ['completed', 'void'].includes(s.status)); string(s.createdAt, 40); assert(!isNaN(Date.parse(s.createdAt)));
      assert(Array.isArray(s.lines) && s.lines.length > 0 && s.lines.length <= 200, 'أضف صنفاً واحداً على الأقل.'); const used = new Set();
      const lines = s.lines.map(l => {
        const product = productIndex.get(l.productId); assert(product && !used.has(l.productId), 'صنف الفاتورة مكرر أو غير موجود.'); used.add(l.productId);
        const name = string(l.name, 100).trim(), unit = string(l.unit, 30).trim(); assert(name && unit && typeof l.trackStock === 'boolean' && l.trackStock === product.trackStock, 'لا يمكن تغيير طريقة تتبّع صنف له فواتير.');
        const line = { productId: l.productId, name, unit, quantity: quantity(l.quantity), price: money(l.price), trackStock: l.trackStock }; lineTotal(line); return line;
      });
      const sale = { id: key, number, date: s.date, status: s.status, lines, discount: money(s.discount), paid: money(s.paid), note: string(s.note), createdAt: s.createdAt };
      if (s.orderType !== undefined) { sale.orderType = string(s.orderType, 60).trim(); assert(sale.orderType, 'نوع الطلب فارغ.'); }
      assert(sale.paid >= saleTotal(sale), 'النقد المستلم أقل من إجمالي الفاتورة.');
      if (s.status === 'void') { sale.voidReason = string(s.voidReason, 500).trim(); assert(sale.voidReason, 'اكتب سبب إلغاء الفاتورة.'); string(s.voidedAt, 40); assert(!isNaN(Date.parse(s.voidedAt))); sale.voidedAt = s.voidedAt; }
      return sale;
    });
    const saleReturns=validateSaleReturns(raw,sales);
    // Check each date, not just today's final stock, so backdated withdrawals cannot overdraw stock.
    const events = new Map();
    function movement(productId, date, amount) { const dates = events.get(productId) || new Map(); dates.set(date, (dates.get(date) || 0) + amount); events.set(productId, dates); }
    for (const e of stockEntries) movement(e.productId, e.date, Math.round(e.quantity * 1000));
    for (const s of sales) if (s.status === 'completed') for (const l of s.lines) if (l.trackStock) movement(l.productId, s.date, -Math.round(l.quantity * 1000));
    for(const r of saleReturns)for(const l of r.lines)if(l.restock)movement(l.productId,r.date,Math.round(l.quantity*1000));
    for (const [productId, dates] of events) { let available = 0; for (const [date, amount] of [...dates].sort(([a], [b]) => a.localeCompare(b))) { available += amount; assert(Number.isSafeInteger(available) && available >= 0 && available <= 1e12, `المخزون غير كافٍ للصنف «${productIndex.get(productId).name}» بتاريخ ${date}.`); } }
    for (const date of new Set([...sales.map(s => s.date),...saleReturns.map(r=>r.date)])) salesTotal({ sales, saleReturns }, date);
    const shortcuts = raw.preferences?.shortcuts ?? defaultShortcuts;
    assert(Array.isArray(shortcuts) && shortcuts.length === 6 && shortcuts.every(s => s === '' || s === 'savings' || destinations.includes(s)), 'اختصارات الواجهات غير صالحة.');
    const orderTypes = raw.preferences?.orderTypes ?? defaultOrderTypes;
    assert(Array.isArray(orderTypes) && orderTypes.length > 0 && orderTypes.length <= 20, 'أضف نوع طلب واحداً على الأقل، وبحد أقصى 20 نوعاً.');
    const cleanTypes = orderTypes.map(t => string(t, 60).trim());
    assert(cleanTypes.every(Boolean) && new Set(cleanTypes.map(t => t.toLocaleLowerCase())).size === cleanTypes.length, 'أنواع الطلبات فارغة أو مكررة.');
    const disabledTypes = raw.preferences?.disabledOrderTypes ?? [];
    assert(Array.isArray(disabledTypes) && disabledTypes.length + cleanTypes.length <= 20, 'الحد الأقصى 20 نوع طلب، يشمل الأنواع المعطلة.');
    const cleanDisabledTypes = disabledTypes.map(t => string(t, 60).trim());
    const allTypes = [...cleanTypes, ...cleanDisabledTypes];
    assert(allTypes.every(Boolean) && new Set(allTypes.map(t => t.toLocaleLowerCase())).size === allTypes.length, 'أنواع الطلبات فارغة أو مكررة.');
    const restaurant = raw.preferences?.restaurant || {};
    return { products, stockEntries, sales, saleReturns, preferences: { shortcuts: shortcuts.map(s => s === 'savings' ? '' : s), orderTypes: cleanTypes, ...(cleanDisabledTypes.length ? {disabledOrderTypes: cleanDisabledTypes} : {}), restaurant: { name: string(restaurant.name || '', 100), contact: string(restaurant.contact || '', 160), footer: string(restaurant.footer || '', 300) } } };
  }
  function completeSale(state, draft, saleId, createdAt) {
    assert(!state.sales.some(s => s.id === saleId), 'هذه الفاتورة محفوظة مسبقاً.');
    assert(Array.isArray(draft.lines) && draft.lines.length, 'أضف صنفاً للفاتورة.');
    const orderType = draft.orderType ?? state.preferences.orderTypes[0];
    assert(state.preferences.orderTypes.includes(orderType), 'اختار نوع طلب متاحاً من القائمة.');
    const nextNumber = state.sales.reduce((n, s) => Math.max(n, /^S-(\d+)$/.test(s.number) ? Number(s.number.slice(2)) : 0), 0) + 1;
    const priceLines = draft.lines.map(l => { const p = state.products.find(p=>p.id===l.productId); assert(p && !p.archived, 'أحد الأصناف غير متاح للبيع.'); return { productId: p.id, name: p.name, unit: p.unit, trackStock: p.trackStock, price: l.price === undefined ? p.price : money(l.price), quantity: l.quantity }; });
    const sale = { id: saleId, number: `S-${String(nextNumber).padStart(6, '0')}`, date: draft.date, status: 'completed', orderType, discount: draft.discount, paid: draft.paid ?? saleTotal({ lines: priceLines, discount: draft.discount }), note: draft.note || '', createdAt,
      lines: priceLines };
    return validate({ ...state, sales: [...state.sales, sale] });
  }
  function voidSale(state, saleId, reason, createdAt) {
    const sale = state.sales.find(s => s.id === saleId); assert(sale?.status === 'completed', 'الفاتورة ملغاة أو غير موجودة.');
    assert(!(state.saleReturns||[]).some(r=>r.saleId===saleId),'الفاتورة لها مرتجعات؛ استخدم إرجاع الكمية المتبقية.');
    return validate({ ...state, sales: state.sales.map(s => s.id === saleId ? { ...s, status: 'void', voidReason: reason, voidedAt: createdAt } : s) });
  }

  function validate(raw) {
    assert(raw && [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].includes(raw.version) && Array.isArray(raw.categories) && raw.categories.length >= 4 && raw.categories.length <= 500);
    // Older files have no type; infer it from stable IDs, never array position.
    const categories = raw.categories.map(c => {
      const type = c.type === undefined ? (core.some(x => x.id === c.id) ? 'primary' : 'additional') : c.type;
      assert(['primary', 'additional'].includes(type), 'نوع الخانة غير صالح.');
      return { id: id(c.id), name: string(c.name, 80).trim(), type, ...(c.archived === true && !core.some(x => x.id === c.id) ? {archived:true} : {}) };
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
      if (d.remaining != null) { const r = d.remaining; assert(Number.isSafeInteger(r.dailySpent) && r.dailySpent >= 0 && Number.isSafeInteger(r.transferred) && r.transferred >= 0); snapshot = { amount: money(r.amount), dailySpent: r.dailySpent, transferred: r.transferred, ...(r.salesTotal !== undefined ? { salesTotal: money(r.salesTotal, true) } : {}) }; }
      days[key] = { expenses, chickenUsed: money(d.chickenUsed), chickenLeft: money(d.chickenLeft), balance: d.balance === null ? null : money(d.balance, true), totalOverride: d.totalOverride === null ? null : money(d.totalOverride), remaining: snapshot, ...(d.corrections?.length ? {corrections: d.corrections.map(c => { assert(!isNaN(Date.parse(c.createdAt)) && ['balance','total'].includes(c.field) && validDate(c.date) && typeof c.reason === 'string' && c.reason.trim(), 'اكتب سبب تصحيح الرصيد.'); return { field: c.field, date: c.date, before: c.before === null ? null : money(c.before, true), after: c.after === null ? null : money(c.after, true), reason: string(c.reason,500), createdAt: string(c.createdAt,40) }; })} : {}) };
    }
    assert(Array.isArray(raw.transactions) && raw.transactions.length <= 100000);
    const txIds = new Set();
    const transactions = raw.transactions.map(t => { const key = id(t.id); assert(!txIds.has(key)); txIds.add(key); assert(validDate(t.date) && ['deposit', 'withdrawal'].includes(t.type) && t.amount > 0); string(t.createdAt, 40); assert(!isNaN(Date.parse(t.createdAt))); return { id: key, date: t.date, type: t.type, amount: money(t.amount), note: string(t.note), createdAt: t.createdAt }; });
    const rawTransfers = raw.transfers ?? []; assert(Array.isArray(rawTransfers) && rawTransfers.length <= 100000);
    const transferIds = new Set();
    const transfers = rawTransfers.map(t => { const key = id(t.id); assert(!transferIds.has(key)); transferIds.add(key); assert(validDate(t.date) && days[t.date]?.remaining != null, 'إيداع الرصيد اليومي يحتاج رصيداً مسجّلاً.'); money(t.amount); assert(t.amount > 0); string(t.createdAt, 40); assert(!isNaN(Date.parse(t.createdAt))); return { id: key, date: t.date, amount: t.amount, createdAt: t.createdAt }; });
    const materials = validateMaterials(materialCatalogInput(raw));
    const clean = { version: 11, ...validateCommerce(raw), categories, days, transactions, transfers, ...validateSuppliers(raw, ids, new Set(materials.map(m => m.id))), materials, ...validateSavings(raw) };
    for (const date of new Set([...Object.keys(days), ...clean.payments.map(p => p.date)])) assert(Number.isSafeInteger(expenses(clean, date).reduce((sum, e) => sum + e.amount, 0)), 'مجموع المصاريف أكبر من الحد الدقيق للحساب.');
    let cashTotal = 0;
    for (const t of movements(clean)) { cashTotal += t.type === 'withdrawal' ? -t.amount : t.amount; assert(Number.isSafeInteger(cashTotal), 'مجموع حركات القاصة أكبر من الحد الدقيق للحساب.'); }
    for (const key of Object.keys(days)) { assert(Number.isSafeInteger(transferred(clean, key)), 'الإيداعات تتجاوز الحد الدقيق للحساب.'); const r = remaining(clean, key); assert(r === null || Number.isSafeInteger(r), 'الرصيد المتبقي يتجاوز الحد الدقيق للحساب.'); }
    // Older days with an entered remainder but no total can be recovered, including prior transfers.
    // Preserve explicitly entered totals and all historical movements.
    if (raw.version < 5) for (const key of Object.keys(days)) if (days[key].balance === null && days[key].remaining !== null) {
      const sum = total(clean, key) + remaining(clean, key) + transferred(clean, key);
      // A valid older ledger can exceed the total field's limit; do not block access to its records.
      if (Number.isSafeInteger(sum) && Math.abs(sum) <= 1e12) days[key].balance = sum;
    }
    return clean;
  }
  return { destinations, defaultShortcuts, defaultOrderTypes, productPhotos, stock, stockBalances, saleSubtotal, saleTotal, salesTotal, saleReturnable, saleRefundTotal, returnQuote, returnSale, completeSale, voidSale, empty, dateKey, validDate, numeric, day, total, funding, dailySpent, transferred, remaining, balanceFromRemaining, recordRemaining, movements, transferRemaining, cash, validate, recordedDays, dayDatePlan, correctDayDates, quantity, nonnegativeQuantity, lineTotal, invoiceTotal, invoicePaid, invoiceDue, paymentAllocation, splitPayment, debtAvailable, openingDue, supplierBalance, supplierLedger, balanceBefore, expenses, expensesBySource, allocation, savingsPeriod, savingsStatus, savingsBalance };
});
