'use strict';
const fs = require('node:fs'), path = require('node:path');
const M = require('../ui/model.js'), N = require('../ui/numbers.js');
const css = fs.readFileSync(path.join(__dirname, 'pdf.css'), 'utf8');
const escape = value => N.latin(String(value ?? '')).replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
const format = value => new Intl.NumberFormat('en-US', { maximumFractionDigits:3 }).format(value);
const number = value => `<span class="number${format(value).length > 12 ? ' wide' : ''}">${format(value)}</span>`;
const amount = value => value === null ? 'غير مسجّل' : number(value) + '<span class="unit">د.ع</span>';
const date = value => new Intl.DateTimeFormat('ar-IQ-u-nu-latn', { day:'numeric', month:'long', year:'numeric' }).format(new Date(value + 'T12:00:00'));
const safeFilename = value => N.latin(value).replace(/[\x00-\x1f\x7f<>:"/\\|?*]/g,'-').slice(0,90);
const category = (state, id) => state.categories.find(c => c.id === id)?.name || 'خانة';
function funding(e) {
  const f = M.funding(e);
  return f.source === 'daily' ? 'الرصيد اليومي' : f.source === 'cash' ? 'القاصة' : `مشترك<small>يومي ${number(f.dailyAmount)} · قاصة ${number(f.cashAmount)}</small>`;
}
function table(headers, widths, rows) {
  return `<table><colgroup>${widths.map(w => `<col style="width:${w}%">`).join('')}</colgroup><thead><tr>${headers.map(h => `<th scope="col">${escape(h)}</th>`).join('')}</tr></thead><tbody>${rows.map(row => `<tr>${row.map(cell => `<td>${cell}</td>`).join('')}</tr>`).join('')}</tbody></table>`;
}
function summary(items) { return `<div class="summary">${items.map(([label,value,hint]) => `<div><p>${escape(label)}</p><strong class="value">${amount(value)}</strong>${hint ? `<small>${escape(hint)}</small>` : ''}</div>`).join('')}</div>`; }
function total(label, value, hint = '') { return `<div class="total"><div>${escape(label)}${hint ? `<small>${escape(hint)}</small>` : ''}</div><strong>${amount(value)}</strong></div>`; }
function detail(label, value) { return `<div class="detail-line"><span>${escape(label)}</span><strong>${value}</strong></div>`; }
function expenseNote(state, e) {
  if (e.kind !== 'supplier-payment') return escape(e.note || '—');
  const s = state.suppliers.find(s => s.id === e.supplierId), inv = state.invoices.find(i => i.id === e.invoiceId), split = M.paymentAllocation(e);
  const original = state.payments.find(p => p.id === e.id);
  return escape('تسديد ' + s.name + ' · ' + (inv ? 'قائمة ' + inv.number : 'الديون')) + (inv && split.debtAmount ? ' · ديون ' + number(split.debtAmount) + ' د.ع' : '') + (original.note ? '<small>' + escape(original.note) + '</small>' : '');
}
function daily(state, key) {
  if (!M.validDate(key)) throw new Error('اختار تاريخاً صحيحاً للتصدير.');
  if (!M.recordedDays(state).includes(key)) throw new Error('ماكو بيانات مسجّلة بهذا اليوم حتى تصدّرها.');
  const d = M.day(state,key), expenses = M.expenses(state,key), actual = expenses.reduce((sum,e) => sum + e.amount,0);
  const movements = M.movements(state), cash = movements.filter(t => t.date <= key).reduce((sum,t) => sum + (t.type === 'deposit' ? t.amount : -t.amount),0);
  const today = movements.filter(t => t.date === key).sort((a,b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id));
  const rows = expenses.map(e => [escape(category(state,e.categoryId)),number(e.amount),funding(e),expenseNote(state,e)]);
  const title = 'فاتورة المصاريف اليومية';
  const body = summary([['مجموع المصاريف',M.total(state,key),d.totalOverride !== null ? 'مجموع معدّل يدوياً' : 'محسوب من المصاريف المسجّلة'],['الرصيد الكلي',d.balance],['الرصيد المتبقي من اليومي',M.remaining(state,key)]]) +
    `<section><div class="section-heading"><h2>تفاصيل المصاريف</h2><small>${number(expenses.length)} مصروف · المبالغ بالدينار العراقي</small></div>${rows.length ? table(['الخانة','المبلغ · د.ع','مصدر الدفع','الملاحظات'],[22,18,25,35],rows) : '<p class="empty">ماكو مصاريف مسجّلة بهذا اليوم.</p>'}${total('مجموع مصاريف اليوم',M.total(state,key),d.totalOverride !== null ? 'مجموع البنود المسجّلة: ' + format(actual) + ' د.ع' : '')}</section>` +
    `<section class="detail-grid"><div class="detail-panel"><h2>توزيع المصروف</h2>${detail('من الرصيد اليومي',amount(M.dailySpent(state,key)))}${detail('من القاصة',amount(expenses.reduce((sum,e) => sum + M.funding(e).cashAmount,0)))}${detail('المودع من اليومي بالقاصة',amount(M.transferred(state,key)))}<p class="hint">التوزيع من البنود الفعلية، حتى إذا المجموع معدّل يدوياً.</p></div><div class="detail-panel"><h2>تتبّع الدجاج</h2>${detail('الدجاج المصروف',number(d.chickenUsed) + ' دجاجة')}${detail('الدجاج المتبقي',number(d.chickenLeft) + ' دجاجة')}<p class="hint">أعداد للتتبّع فقط، خارج مجموع المصاريف.</p></div></section>` +
    `<section class="cash-section"><div class="section-heading"><h2>حركات القاصة لهذا اليوم</h2><small>${number(today.length)} حركة</small></div>${today.length ? table(['الحركة','المبلغ · د.ع','التفاصيل'],[26,22,52],today.map(t => [t.type === 'deposit' ? 'إيداع' : 'سحب',number(t.amount),t.kind === 'supplier-payment' ? expenseNote(state,expenses.find(e => e.id === t.id)) : escape(t.kind === 'transfer' ? 'إيداع من الرصيد اليومي' : t.kind === 'expense' ? 'مصروف ' + category(state,t.categoryId) + (t.note ? ' · ' + t.note : '') : t.kind === 'supplier-payment' ? t.note : t.note || '—')])) : '<p class="empty">ماكو حركات قاصة بهذا اليوم.</p>'}${total('القاصة بنهاية اليوم',cash,'حسب الحركات المسجّلة لغاية هذا التاريخ')}</section>`;
  return { title, subtitle:'سجل حسابات المطعم', stamp:date(key), reference:key, filename:`Daftar-Day-${key}.pdf`, body };
}
function invoice(state, id) {
  const inv = state.invoices.find(i => i.id === id);
  if (!inv) throw new Error('القائمة غير موجودة.');
  const s = state.suppliers.find(s => s.id === inv.supplierId);
  const payments = state.payments.filter(p => p.invoiceId === id).sort((a,b) => a.date.localeCompare(b.date) || a.createdAt.localeCompare(b.createdAt));
  const body = summary([['قيمة القائمة',M.invoiceTotal(inv)],['المسدّد من القائمة',M.invoicePaid(state,id)],['المتبقي من القائمة',M.invoiceDue(state,id),M.invoiceDue(state,id) === 0 ? 'مسدّدة بالكامل' : 'باقي للتسديد']]) +
    `<section><div class="section-heading"><h2>مواد القائمة</h2><small>${number(inv.lines.length)} مادة · المبالغ بالدينار العراقي</small></div>${table(['المادة','الوحدة','الكمية','سعر الوحدة','الإجمالي · د.ع'],[34,12,12,20,22],inv.lines.map(l => [escape(l.name),escape(l.unit),number(l.quantity),number(l.price),number(M.lineTotal(l))]))}${total('مجموع القائمة',M.invoiceTotal(inv))}</section>` +
    (inv.note ? `<section><h2>ملاحظات القائمة</h2><div class="note">${escape(inv.note)}</div></section>` : '') +
    `<section><div class="section-heading"><h2>تسديدات هذه القائمة</h2><small>${number(payments.length)} دفعة</small></div>${payments.length ? table(['التاريخ','المدفوع · د.ع','توزيع التسديد','المصدر / الملاحظات'],[18,21,29,32],payments.map(p => { const split = M.paymentAllocation(p); return [escape(date(p.date)),number(p.amount),`للقائمة ${number(split.invoiceAmount)}${split.debtAmount ? `<small>للديون ${number(split.debtAmount)}</small>` : ''}`,funding(p) + (p.note ? `<small>${escape(p.note)}</small>` : '')]; })) : '<p class="empty">ماكو تسديدات مسجّلة لهذه القائمة بعد.</p>'}<p class="hint">المسدّد من القائمة يحتسب حصتها فقط؛ أي زيادة بالتسديد تنخصم من ديون المورد.</p></section>` +
    `<section class="detail-panel"><h2>حساب المورد</h2>${detail('الحساب قبل هذه القائمة',amount(M.balanceBefore(state,s.id,inv.date,inv.createdAt,inv.id)))}${detail('الديون الباقية وقت التصدير',amount(M.debtAvailable(state,s.id)))}${detail('إجمالي الحساب عليك وقت التصدير',amount(M.supplierBalance(state,s.id)))}<p class="hint">إجمالي حساب المورد يشمل ديونه وكل قوائمه وتسديداته المسجّلة لغاية التصدير.</p></section>`;
  return { title:'قائمة ' + inv.number, subtitle:s.name + (s.phone ? '\n' + s.phone : ''), stamp:date(inv.date), reference:'قائمة مورد', filename:`Daftar-Invoice-${safeFilename(inv.number)}-${inv.date}.pdf`, body };
}
function createReport(state, request) {
  if (!request || !['daily','invoice'].includes(request.kind)) throw new Error('نوع التصدير غير صالح.');
  const report = request.kind === 'daily' ? daily(state,request.date) : invoice(state,request.id);
  const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>${escape(report.title)} · دفتر</title><style>${css}</style></head><body><header class="brand-row"><div class="brand"><div class="mark" aria-hidden="true"><i></i><i></i><i></i></div><div><strong>دفتر</strong><small>حسابات المطعم</small></div></div><span class="document-tag">DAFTAR / ACCOUNTS</span></header><div class="hero"><div><p class="eyebrow">${request.kind === 'daily' ? 'المصاريف / سجل اليوم' : 'الموردون / القوائم'}</p><h1>${escape(report.title)}</h1><p class="subtitle">${escape(report.subtitle)}</p></div><div class="stamp"><span>تاريخ الفاتورة</span><strong>${escape(report.stamp)}</strong><span>${escape(report.reference)}</span></div></div>${report.body}</body></html>`;
  return { title:report.title, filename:report.filename, html };
}
module.exports = { createReport };
