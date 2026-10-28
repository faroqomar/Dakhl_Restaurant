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
  if (!M.recordedDays(state).includes(key)) throw new Error('ماكو مصاريف يومية مسجلة. لتصدير المبيعات افتح سجل المبيعات واختار تقرير هذا العرض.');
  const d = M.day(state,key), expenses = M.expenses(state,key), dailyExpenses = M.expensesBySource(state,key,'daily'), cashExpenses = M.expensesBySource(state,key,'cash'), actual = dailyExpenses.reduce((sum,e) => sum + e.amount,0);
  const movements = M.movements(state), cash = movements.filter(t => t.date <= key).reduce((sum,t) => sum + (t.type === 'deposit' ? t.amount : -t.amount),0);
  const today = movements.filter(t => t.date === key).sort((a,b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id));
  const rows = dailyExpenses.map(e => [escape(category(state,e.categoryId)),number(e.amount),funding(e),expenseNote(state,e)]), cashRows = cashExpenses.map(e => [escape(category(state,e.categoryId)),number(e.amount),funding(e),expenseNote(state,e)]);
  const title = 'فاتورة المصاريف اليومية';
  const body = summary([['مجموع المصاريف',M.total(state,key),d.totalOverride !== null ? 'مجموع معدّل يدوياً' : 'محسوب من المصاريف المسجّلة'],['الرصيد الكلي',d.balance],['الرصيد المتبقي من اليومي',M.remaining(state,key)]]) +
    `<section><div class="section-heading"><h2>مصاريف الرصيد اليومي</h2><small>${number(dailyExpenses.length)} بند · المبالغ بالدينار العراقي</small></div>${rows.length ? table(['الخانة','المبلغ · د.ع','مصدر الدفع','الملاحظات'],[22,18,25,35],rows) : '<p class="empty">ماكو مصاريف على الرصيد اليومي بهذا اليوم.</p>'}${total('مجموع مصاريف اليوم',M.total(state,key),d.totalOverride !== null ? 'مجموع البنود المسجّلة: ' + format(actual) + ' د.ع' : '')}</section>` +
    `<section class="cash-section"><div class="section-heading"><h2>مصاريف القاصة</h2><small>${number(cashExpenses.length)} بند منفصل عن مجموع اليومي</small></div>${cashRows.length ? table(['الخانة','المبلغ · د.ع','مصدر الدفع','الملاحظات'],[22,18,25,35],cashRows) : '<p class="empty">ماكو مصاريف من القاصة بهذا اليوم.</p>'}${total('مجموع مصاريف القاصة',cashExpenses.reduce((sum,e)=>sum+e.amount,0))}</section>` +
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
    `<section><div class="section-heading"><h2>مواد القائمة</h2><small>${number(inv.lines.length)} مادة · المبالغ بالدينار العراقي</small></div>${table(['المادة','الوحدة','الكمية · كارتون / قطعة','السعر · كارتون / قطعة','الإجمالي · د.ع'],[27,10,22,22,19],inv.lines.map(l => [escape(l.name),escape(l.unit),l.quantityCartons !== undefined ? `${number(l.quantityCartons)} / ${number(l.quantityPieces)}` : number(l.quantity),l.quantityCartons !== undefined ? `${number(l.priceCarton)} / ${number(l.pricePiece)}` : number(l.price),number(M.lineTotal(l))]))}${total('مجموع القائمة',M.invoiceTotal(inv))}</section>` +
    (inv.note ? `<section><h2>ملاحظات القائمة</h2><div class="note">${escape(inv.note)}</div></section>` : '') +
    `<section><div class="section-heading"><h2>تسديدات هذه القائمة</h2><small>${number(payments.length)} دفعة</small></div>${payments.length ? table(['التاريخ','المدفوع · د.ع','توزيع التسديد','المصدر / الملاحظات'],[18,21,29,32],payments.map(p => { const split = M.paymentAllocation(p); return [escape(date(p.date)),number(p.amount),`للقائمة ${number(split.invoiceAmount)}${split.debtAmount ? `<small>للديون ${number(split.debtAmount)}</small>` : ''}`,funding(p) + (p.note ? `<small>${escape(p.note)}</small>` : '')]; })) : '<p class="empty">ماكو تسديدات مسجّلة لهذه القائمة بعد.</p>'}<p class="hint">المسدّد من القائمة يحتسب حصتها فقط؛ أي زيادة بالتسديد تنخصم من ديون المورد.</p></section>` +
    `<section class="detail-panel"><h2>حساب المورد</h2>${detail('الحساب قبل هذه القائمة',amount(M.balanceBefore(state,s.id,inv.date,inv.createdAt,inv.id)))}${detail('الديون الباقية وقت التصدير',amount(M.debtAvailable(state,s.id)))}${detail('إجمالي الحساب عليك وقت التصدير',amount(M.supplierBalance(state,s.id)))}<p class="hint">إجمالي حساب المورد يشمل ديونه وكل قوائمه وتسديداته المسجّلة لغاية التصدير.</p></section>`;
  return { title:'قائمة ' + inv.number, subtitle:s.name + (s.phone ? '\n' + s.phone : ''), stamp:date(inv.date), reference:'قائمة مورد', filename:`Daftar-Invoice-${safeFilename(inv.number)}-${inv.date}.pdf`, body };
}
function sale(state, id) {
  const s = state.sales.find(s => s.id === id);
  if (!s) throw new Error('فاتورة البيع غير موجودة.');
  const body = (s.orderType ? `<section>${detail('نوع الطلب',escape(s.orderType))}</section>` : '') + (s.status === 'void' ? `<section class="note"><strong>فاتورة ملغاة</strong><p>${escape(s.voidReason)}</p><small>مستبعدة من المبيعات والمخزون</small></section>` : '') +
    table(['الصنف','الوحدة','الكمية','سعر البيع · د.ع','المجموع · د.ع'],[32,12,12,22,22],s.lines.map(l => [escape(l.name),escape(l.unit),number(l.quantity),number(l.price),number(M.lineTotal(l))])) +
    `<section class="detail-panel">${detail('المجموع قبل الخصم',amount(M.saleSubtotal(s)))}${detail('الخصم',amount(s.discount))}${total('إجمالي البيع',M.saleTotal(s))}${detail('النقد المستلم',amount(s.paid))}${detail('الباقي للزبون',amount(s.paid - M.saleTotal(s)))}</section>` +
    ((state.saleReturns||[]).some(r=>r.saleId===s.id) ? `<section><h2>المرتجعات المسجلة</h2>${table(['التاريخ','السبب','المبلغ المرتجع · د.ع'],[22,53,25],state.saleReturns.filter(r=>r.saleId===s.id).map(r=>[escape(r.date),escape(r.reason),number(r.amount)]))}${total('المتبقي بعد المرتجعات',M.saleTotal(s)-M.saleRefundTotal(state,s.id))}</section>` : '') +
    (s.note ? `<section><h2>ملاحظة</h2><p class="note">${escape(s.note)}</p></section>` : '') + '<p class="hint">وصل بيع نقدي · محفوظ على هذا الجهاز.</p>';
  return { title:'فاتورة بيع ' + s.number, subtitle:'وصل بيع نقدي', stamp:date(s.date)+' · '+new Intl.DateTimeFormat('ar-IQ-u-nu-latn',{hour:'2-digit',minute:'2-digit'}).format(new Date(s.createdAt)), reference:s.status === 'void' ? 'ملغاة' : s.number, filename:`Daftar-Sale-${safeFilename(s.number)}-${s.date}.pdf`, body };
}
function periodReport(state, kind, raw = {}) {
  const filter = Object.fromEntries(['from','to','query','categoryId','source','status','orderType','kind','type','workerId'].map(k=>[k,typeof raw[k]==='string'?raw[k]:'']));
  if((filter.from&&!M.validDate(filter.from))||(filter.to&&!M.validDate(filter.to))||(filter.from&&filter.to&&filter.from>filter.to))throw new Error('اختار فترة صحيحة للتقرير.');
  const within=e=>(!filter.from||e.date>=filter.from)&&(!filter.to||e.date<=filter.to), span=`${filter.from||'بداية السجل'} — ${filter.to||'نهاية السجل'}`;
  let title,body;
  if(kind==='sales'){
    if(filter.status&&!['completed','void'].includes(filter.status))throw new Error('حالة البيع غير صالحة.');
    const rows=state.sales.filter(s=>within(s)&&(!filter.status||s.status===filter.status)&&(!filter.orderType||s.orderType===filter.orderType)&&`${s.number} ${s.note} ${s.lines.map(l=>l.name).join(' ')}`.toLowerCase().includes(filter.query.toLowerCase())).sort((a,b)=>a.date.localeCompare(b.date)||a.createdAt.localeCompare(b.createdAt));
    const refunds=(state.saleReturns||[]).filter(r=>within(r)&&(!filter.status||filter.status==='completed')&&state.sales.some(s=>s.id===r.saleId&&(!filter.orderType||s.orderType===filter.orderType)&&`${s.number} ${s.note} ${s.lines.map(l=>l.name).join(' ')}`.toLowerCase().includes(filter.query.toLowerCase())));
    const gross=rows.filter(s=>s.status==='completed').reduce((n,s)=>n+M.saleTotal(s),0), refunded=refunds.reduce((n,r)=>n+r.amount,0);
    title='ملخص المبيعات';body=`<p>الفترة: ${escape(span)} · الحالة: ${escape(({completed:'مكتملة',void:'ملغاة'})[filter.status]||'الكل')} · نوع الطلب: ${escape(filter.orderType||'الكل')}</p>`+summary([['المبيعات بعد الخصم',gross],['مرتجعات الفترة',refunded],['صافي التحصيل',gross-refunded]])+'<p>المرتجع يحسب بتاريخ إرجاعه؛ هذا المبلغ ليس صافي الربح.</p>'+table(['الفاتورة','التاريخ / الوقت','نوع الطلب','الحالة','الإجمالي · د.ع'],[18,25,18,16,23],rows.map(s=>[escape(s.number),escape(s.date+' · '+new Intl.DateTimeFormat('ar-IQ-u-nu-latn',{hour:'2-digit',minute:'2-digit'}).format(new Date(s.createdAt))),escape(s.orderType||'—'),s.status==='void'?'ملغاة':'مكتملة',number(M.saleTotal(s))]));
    if(refunds.length)body+='<h2>مرتجعات الفترة</h2>'+table(['الفاتورة','التاريخ','السبب','المبلغ · د.ع'],[20,20,40,20],refunds.map(r=>[escape(state.sales.find(s=>s.id===r.saleId).number),escape(r.date),escape(r.reason),number(r.amount)]));
  } else if(kind==='statement'){
    if(filter.source&&!['all','daily','cash'].includes(filter.source))throw new Error('مصدر التقرير غير صالح.');
    const rows=[...new Set([...Object.keys(state.days),...state.payments.map(p=>p.date)])].sort().flatMap(date=>M.expenses(state,date).map(e=>({...e,date}))).filter(e=>within(e)&&(!filter.categoryId||e.categoryId===filter.categoryId)).map(e=>({...e,displayAmount:filter.source==='daily'?M.funding(e).dailyAmount:filter.source==='cash'?M.funding(e).cashAmount:e.amount})).filter(e=>e.displayAmount>0);
    title='كشف المصروفات';const daily=rows.reduce((n,e)=>n+(filter.source==='cash'?0:M.funding(e).dailyAmount),0),cash=rows.reduce((n,e)=>n+(filter.source==='daily'?0:M.funding(e).cashAmount),0);
    body=`<p>الفترة: ${escape(span)} · الخانة: ${escape(filter.categoryId?category(state,filter.categoryId):'الكل')} · المصدر: ${escape(({daily:'اليومي',cash:'القاصة'})[filter.source]||'الكل')}</p>`+summary([['حصة اليومي',daily],['حصة القاصة',cash],['المجموع',daily+cash]])+table(['التاريخ','الخانة','المبلغ · د.ع','المصدر الأصلي','التفاصيل'],[16,18,18,22,26],rows.map(e=>[escape(e.date),escape(category(state,e.categoryId)),number(e.displayAmount),funding(e),expenseNote(state,e)]));
  } else if(kind==='cash'){
    if(filter.kind&&!['cash','transfer','expense','supplier-payment'].includes(filter.kind))throw new Error('نوع الحركة غير صالح.');
    let balance=0;const all=M.movements(state).sort((a,b)=>a.date.localeCompare(b.date)||a.createdAt.localeCompare(b.createdAt)||a.id.localeCompare(b.id)).map(e=>({...e,balance:balance+=e.type==='deposit'?e.amount:-e.amount})),rows=all.filter(e=>within(e)&&(!filter.kind||e.kind===filter.kind));
    title='كشف القاصة';const opening=all.filter(e=>filter.from&&e.date<filter.from).at(-1)?.balance||0,closing=all.filter(e=>!filter.to||e.date<=filter.to).at(-1)?.balance||0;
    body=`<p>الفترة: ${escape(span)} · الرصيد يشمل كل المصادر حتى لو كانت الحركات مصفاة.</p>`+summary([['افتتاح الفترة',opening],['إغلاق الفترة',closing]])+table(['التاريخ','الحركة','المبلغ · د.ع','الرصيد بعدها','التفاصيل'],[17,18,20,20,25],rows.map(e=>[escape(e.date),e.type==='deposit'?'إيداع':'سحب',number(e.amount),number(e.balance),escape(e.kind==='transfer'?'تحويل من اليومي':e.note||e.kind)]));
  } else {
    if(filter.type&&!['contribution','receipt'].includes(filter.type))throw new Error('نوع السلفة غير صالح.');
    const rows=state.savingsEntries.filter(e=>within(e)&&(!filter.workerId||e.workerId===filter.workerId)&&(!filter.type||e.type===filter.type)&&state.workers.find(w=>w.id===e.workerId).name.toLowerCase().includes(filter.query.toLowerCase())).sort((a,b)=>a.date.localeCompare(b.date)||a.createdAt.localeCompare(b.createdAt));
    title='سجل سلفة العمال';body=`<p>الفترة: ${escape(span)} · سجل مستقل عن المصاريف والقاصة · ${escape(filter.type==='receipt'?'الاستلام':filter.type==='contribution'?'الدفعات':'كل الحركات')}</p>`+table(['التاريخ','العامل','نوع الحركة','المبلغ · د.ع','الملاحظة'],[17,23,18,20,22],rows.map(e=>[escape(e.date),escape(state.workers.find(w=>w.id===e.workerId).name),e.type==='receipt'?'استلام':'دفعة',number(e.amount),escape(e.note)]));
  }
  return {title,subtitle:'حسب التصفية المختارة · السجلات المحفوظة',stamp:span,reference:'تقرير فترة',filename:`Daftar-${kind}-${filter.from||'start'}-${filter.to||'end'}.pdf`,body};
}
function paymentReceipt(state,id){const p=state.payments.find(p=>p.id===id);if(!p)throw new Error('التسديد غير موجود.');const supplier=state.suppliers.find(s=>s.id===p.supplierId),inv=state.invoices.find(i=>i.id===p.invoiceId),split=M.paymentAllocation(p);return{title:'وصل تسديد',subtitle:supplier.name,stamp:date(p.date),reference:inv?'قائمة '+inv.number:'تسديد ديون',filename:`Daftar-Payment-${safeFilename(p.id)}.pdf`,body:total('المبلغ المسدد',p.amount)+detail('للقائمة',amount(split.invoiceAmount))+detail('للديون',amount(split.debtAmount))+detail('الرصيد بعد هذه الدفعة',amount(M.supplierLedger(state,p.supplierId).find(e=>e.type==='payment'&&e.id===p.id).balance))+detail('مصدر الدفع',funding(p))+`<p>${escape(p.note)}</p>`};}

function createReport(state, request) {
  if (!request || !['daily','invoice','sale','sales','statement','cash','workers','payment'].includes(request.kind)) throw new Error('نوع التصدير غير صالح.');
  const report = ['sales','statement','cash','workers'].includes(request.kind) ? periodReport(state,request.kind,request.filter) : request.kind === 'payment' ? paymentReceipt(state,request.id) : request.kind === 'daily' ? daily(state,request.date) : request.kind === 'sale' ? sale(state,request.id) : invoice(state,request.id);
  const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>${escape(report.title)} · دفتر</title><style>${css}</style></head><body><header class="brand-row"><div class="brand"><div class="mark" aria-hidden="true"><i></i><i></i><i></i></div><div><strong>${escape(state.preferences.restaurant?.name || 'دفتر')}</strong><small>${escape(state.preferences.restaurant?.contact || 'حسابات المطعم')}</small></div></div><span class="document-tag">DAFTAR / ACCOUNTS</span></header><div class="hero"><div><p class="eyebrow">${({daily:'المصاريف / سجل اليوم',sale:'المبيعات / وصل بيع',sales:'المبيعات / ملخص الفترة',statement:'الحسابات / كشف المصاريف',cash:'القاصة / سجل الحركات',workers:'سلفة العمال / سجل الحركات',payment:'الموردون / وصل تسديد',invoice:'المشتريات / فاتورة'})[request.kind]}</p><h1>${escape(report.title)}</h1><p class="subtitle">${escape(report.subtitle)}</p></div><div class="stamp"><span>التاريخ / الفترة</span><strong>${escape(report.stamp)}</strong><span>${escape(report.reference)}</span></div></div>${report.body}${state.preferences.restaurant?.footer ? `<footer>${escape(state.preferences.restaurant.footer)}</footer>` : ''}</body></html>`;
  return { title:report.title, filename:report.filename, html };
}
module.exports = { createReport };
