'use strict';
const M = window.DaftarModel, N = window.DaftarNumbers;
let state, directory = '', selectedDate = M.dateKey(), view = 'expenses', history = [], drawer = null, busy = false, previousFocus;
const main = document.getElementById('main'), host = document.getElementById('drawer-host');
const esc = value => N.latin(value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const paths = { ledger: 'M4 2h14v18H4z M8 7h6 M8 11h6 M8 15h4', wallet: 'M2 5h16v14H2z M3 5V2h12 M13 10h7v5h-7z', supplier: 'M2 8h16v12H2z M0 8l3-6h14l3 6 M6 20v-7h8v7', transfer: 'M2 6h16 M14 2l4 4-4 4 M18 16H2 M6 12l-4 4 4 4', grid: 'M2 2h7v7H2z M13 2h7v7h-7z M2 13h7v7H2z M13 13h7v7h-7z', settings: 'M3 5h16 M3 11h16 M3 17h16 M7 2v6 M15 8v6 M9 14v6', plus: 'M11 4v14 M4 11h14', close: 'M5 5l12 12 M17 5L5 17', left: 'M14 4l-7 7 7 7', right: 'M8 4l7 7-7 7', edit: 'M4 15l11-11 4 4-11 11H4z M13 6l4 4', download: 'M11 2v12 M6 9l5 5 5-5 M3 16v4h16v-4', upload: 'M11 15V3 M6 8l5-5 5 5 M3 16v4h16v-4', folder: 'M2 5h7l2 3h9v12H2z', undo: 'M7 4L2 9l5 5 M2 9h10a7 7 0 0 1 7 7', check: 'M4 11l4 4 10-11' };
const icon = name => `<svg class="icon" viewBox="0 0 22 22" aria-hidden="true"><path d="${paths[name] || paths.ledger}"/></svg>`;
const fmt = n => new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(n);
const num = (n, cls = '') => `<span class="number ${cls}">${fmt(n)}</span>`;
const prettyDate = date => new Intl.DateTimeFormat('ar-IQ-u-nu-latn', { day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(`${date}T12:00:00`));
const shortDate = date => new Intl.DateTimeFormat('ar-IQ-u-nu-latn', { day: 'numeric', month: 'short' }).format(new Date(`${date}T12:00:00`));
const button = (label, action, primary = false, ic = '') => `<button class="button ${primary ? 'primary' : ''}" data-action="${action}">${ic ? icon(ic) : ''}${label}</button>`;
const categoryName = id => state.categories.find(c => c.id === id)?.name || 'خانة';
function status(text, error = false) { const el = document.getElementById('save-status'); el.classList.toggle('error', error); el.innerHTML = '<span class="status-dot"></span>'; el.append(document.createTextNode(text)); }
let toastTimer;
function toast(text, error = false) { const el = document.getElementById('toast'); el.textContent = text; el.className = `visible${error ? ' error' : ''}`; clearTimeout(toastTimer); toastTimer = setTimeout(() => el.className = '', error ? 7000 : 3500); }
function orderedTransactions() { return M.movements(state).sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt)); }
function movementLabel(t) { return t.kind === 'supplier-payment' ? `تسديد ${supplierById(t.supplierId)?.name || 'مورد'}` : t.kind === 'expense' ? `مصروف ${categoryName(t.categoryId)}` : t.kind === 'transfer' ? 'إيداع من رصيد اليوم' : t.type === 'deposit' ? 'إيداع بالقاصة' : 'سحب من القاصة'; }
function fundingLabel(e) { const f = M.funding(e); return f.source === 'daily' ? 'من الرصيد اليومي' : f.source === 'cash' ? 'من القاصة' : `مشترك · يومي ${fmt(f.dailyAmount)} / قاصة ${fmt(f.cashAmount)}`; }
function cashCard() { const balance = M.cash(state); return `<section class="cash-card" aria-label="القاصة الرئيسية"><div class="cash-heading">${icon('wallet')}القاصة الرئيسية</div><p class="cash-label">المبلغ الموجود بالقاصة</p>${num(balance, `cash-number${balance < 0 ? ' negative' : ''}`)}<span class="cash-unit">دينار عراقي</span><div class="cash-actions"><button class="button lime" data-action="deposit">إيداع +</button><button class="button withdraw" data-action="withdrawal">سحب −</button></div><p class="hint">${balance < 0 ? 'السحوبات أكثر من الإيداعات المسجّلة.' : 'أنت تحدد مبلغ كل حركة.'}</p></section>`; }
function activity() { const recent = orderedTransactions().slice(0, 3); return `<section class="activity"><div class="activity-head"><h2>آخر حركات القاصة</h2><button class="text-link" data-action="view-cash">عرض الكل</button></div>${recent.length ? `<ul class="activity-list">${recent.map(t => `<li class="activity-item"><span class="activity-symbol">${t.type === 'deposit' ? '+' : '−'}</span><div class="activity-details"><strong>${esc(movementLabel(t))}</strong><small>${esc(shortDate(t.date))}${t.note ? ` · ${esc(t.note)}` : ''}</small></div><span class="number activity-amount ${t.type === 'withdrawal' ? 'out' : ''}">${t.type === 'deposit' ? '+' : '−'} ${fmt(t.amount)}</span></li>`).join('')}</ul>` : '<div class="activity-empty">ماكو حركات بعد.<br>ابدأ بإيداع المبلغ الموجود بالقاصة.</div>'}</section>`; }
function dateControl() { return `<div class="date-picker"><button class="icon-button" data-action="previous-day" aria-label="اليوم السابق">${icon('right')}</button><input type="date" id="selected-date" value="${selectedDate}" aria-label="تاريخ سجل المصاريف"><button class="icon-button" data-action="next-day" aria-label="اليوم التالي">${icon('left')}</button></div>`; }
function header(title, description, actions, eyebrow = 'المصاريف / سجل اليوم') { return `<header class="page-header"><div><p class="eyebrow">${eyebrow}</p><h1>${title}</h1><p class="description">${description}</p></div><div class="header-actions">${actions}</div></header>`; }
function expensesPage() {
  const d = M.day(state, selectedDate), items = M.expenses(state, selectedDate), actual = items.reduce((s, e) => s + e.amount, 0);
  const rows = items.map(e => `<tr><td class="category-name"><span class="category-dot"></span>${esc(categoryName(e.categoryId))}</td><td>${num(e.amount)}<small class="funding-note">${esc(fundingLabel(e))}</small></td><td><div class="note">${e.note ? esc(e.note) : '—'}</div></td><td><button class="icon-button" data-action="${e.kind === 'supplier-payment' ? 'payment-edit' : 'edit-expense'}" data-id="${e.id}" aria-label="تعديل مصروف ${esc(categoryName(e.categoryId))}">${icon('edit')}</button></td></tr>`);
  for (const c of state.categories.filter(c => !items.some(e => e.categoryId === c.id))) rows.push(`<tr class="row-empty"><td class="category-name"><span class="category-dot"></span>${esc(c.name)}</td><td><button class="amount-add" data-action="category-expense" data-id="${c.id}">+ إضافة مبلغ</button></td><td><div class="note">—</div></td><td></td></tr>`);
  return header('كل يوم، حسابه واضح.', 'سجّل مصاريفك وتابع القاصة من مكان واحد.', button('إضافة مصروف', 'expense', true, 'plus') + (state.suppliers.length ? button('تسديد مورد', 'payment-new') : '') + button('تصدير PDF', 'daily-pdf', false, 'download') + dateControl()) +
    `<div class="date-label">${esc(prettyDate(selectedDate))}${selectedDate !== M.dateKey() ? ' · <button class="text-link" data-action="today">الرجوع لليوم</button>' : ''}<button class="text-link" data-action="day-date" ${M.recordedDays(state).includes(selectedDate) ? '' : 'disabled'}>تعديل تاريخ الفاتورة</button></div><section class="summary" aria-label="ملخص اليوم"><div><p class="summary-label">مجموع مصاريف اليوم</p>${num(M.total(state, selectedDate), 'summary-value')}<span class="unit">د.ع</span>${d.totalOverride !== null ? '<span class="badge">مجموع يدوي</span>' : ''}</div><div><p class="summary-label">الرصيد الكلي</p>${d.balance === null ? '<span class="summary-value">—</span>' : num(d.balance, 'summary-value')}<span class="summary-sub"><button class="text-link" data-action="balance">${d.balance === null ? 'تسجيل الرصيد' : 'تعديل الرصيد'}</button></span></div><div><p class="summary-label">المصاريف المسجّلة</p>${num(items.length, 'summary-value')}<span class="summary-sub">لهذا اليوم</span></div></section>
    <div class="dashboard"><div><section class="ledger"><div class="section-head"><h2>تفاصيل المصاريف</h2><button class="button ghost" data-action="category">+ إضافة خانة</button></div><div class="table-scroll"><table class="expenses-table"><thead><tr><th>الخانة</th><th>المبلغ · د.ع</th><th>ملاحظات</th><th><span class="sr-only">تعديل</span></th></tr></thead><tbody>${rows.join('')}</tbody></table></div><div class="table-total"><div class="total-name">مجموع المصاريف${d.totalOverride !== null ? `<div class="total-manual">المحسوب: ${num(actual)} د.ع</div>` : ''}</div><div>${num(M.total(state, selectedDate), 'total-amount')}<span class="unit">د.ع</span></div><button class="text-link" data-action="total">تعديل المجموع</button></div>${!items.length ? '<p class="empty-help">ابدأ بمبلغ أول خانة. تگدر تضيف أكثر من مصروف لنفس الخانة.</p>' : ''}</section>
    ${remainingPanel()}<section class="chicken"><div class="chicken-head"><div><h2>تتبّع الدجاج</h2><p class="chicken-description">أعداد فقط · خارج مجموع المصاريف</p></div><button class="text-link" data-action="chicken">تعديل الأعداد</button></div><div class="chicken-stats"><div>${num(d.chickenUsed, 'chicken-number')}<div>الدجاج المصروف<small>دجاجة</small></div></div><div>${num(d.chickenLeft, 'chicken-number')}<div>الدجاج المتبقي<small>دجاجة</small></div></div></div></section></div><aside class="cash-rail">${cashCard()}${activity()}</aside></div>`;
}
function remainingPanel() {
  const amount = M.remaining(state, selectedDate);
  return `<section class="remaining-panel" aria-label="الرصيد المتبقي"><div><p class="summary-label">الرصيد المتبقي من اليومي</p><div>${amount === null ? '<span class="remaining-number">—</span>' : num(amount, 'remaining-number')}<span class="unit">د.ع</span></div><p class="remaining-hint">${amount === null ? 'سجّل الباقي الفعلي بعد مصاريفك الحالية.' : amount < 0 ? 'المصروف اليومي تجاوز الرصيد المسجّل.' : 'الإيداع بالقاصة ينخصم من هذا الرصيد.'}</p></div><div class="remaining-actions"><button class="button small" data-action="remaining">${amount === null ? 'تسجيل المبلغ' : 'تعديل المبلغ'}</button><button class="button primary small" data-action="remaining-transfer" ${amount === null || amount <= 0 ? 'disabled' : ''}>إيداع بالقاصة</button></div></section>`;
}
function cashPage() { const txs = orderedTransactions(); return header('القاصة، بحركة واضحة.', 'الإيداعات والسحوبات مسجّلة بتاريخ وملاحظة.', button('إيداع بالقاصة', 'deposit', true, 'plus'), 'القاصة / سجل الحركات') + `<div class="cash-layout"><section class="panel"><div class="activity-head"><h2>كل الحركات</h2><span class="badge">${fmt(txs.length)} حركة</span></div>${txs.length ? `<div class="table-scroll"><table class="cash-table"><thead><tr><th>التاريخ</th><th>الحركة</th><th>المبلغ · د.ع</th><th>ملاحظات</th><th>تعديل</th></tr></thead><tbody>${txs.map(t => `<tr><td>${esc(shortDate(t.date))}</td><td><span class="badge ${t.type === 'withdrawal' ? 'out' : ''}">${t.type === 'deposit' ? 'إيداع' : 'سحب'}</span><small class="funding-note">${['expense', 'supplier-payment'].includes(t.kind) ? esc(movementLabel(t)) : t.kind === 'transfer' ? 'من رصيد اليوم' : 'حركة مباشرة'}</small></td><td>${num(t.amount)}</td><td class="note">${t.note ? esc(t.note) : '—'}</td><td><button class="icon-button" data-action="edit-transaction" data-id="${t.id}" data-kind="${t.kind}" data-date="${t.date}" aria-label="تعديل حركة القاصة">${icon('edit')}</button></td></tr>`).join('')}</tbody></table></div>` : `<div class="empty-state">${icon('wallet')}<h3>ابدأ برصيد القاصة الموجود.</h3><p>سجّله كإيداع أول، وبعدها تابع السحب والإضافة.</p>${button('تسجيل أول إيداع', 'deposit', true)}</div>`}</section><aside class="cash-rail">${cashCard()}<div class="panel"><h2>كل حركة بمصدرها</h2><p>حصة القاصة من المصروف تنخصم تلقائياً. وإيداع الرصيد المتبقي ينضاف للقاصة وينخصم من اليومي بنفس الحفظ.</p></div></aside></div>`; }
function categoryTypeOptions(type = 'additional') { return `<option value="primary" ${type === 'primary' ? 'selected' : ''}>رئيسية</option><option value="additional" ${type === 'additional' ? 'selected' : ''}>إضافية</option>`; }
function categoryTypeField() { return `<div class="field"><label for="category-type">نوع الخانة</label><select id="category-type" name="categoryType">${categoryTypeOptions()}</select></div>`; }
function categoriesPage() { return header('خاناتك، حسب شغلك.', 'اختار لكل خانة رئيسية أو إضافية. أي تغيير ينحفظ تلقائياً.', button('إضافة خانة', 'category', true, 'plus'), 'المصاريف / الخانات') + `<section class="panel"><div class="category-grid">${state.categories.map(c => `<div class="category-item"><strong>${esc(c.name)}</strong><select class="category-type-select" data-category-id="${c.id}" aria-label="نوع خانة ${esc(c.name)}">${categoryTypeOptions(c.type)}</select></div>`).join('')}</div></section>`; }
function settingsPage() { return header('حساباتك تبقى يمّك.', 'الحفظ محلي وتلقائي. تگدر تحتفظ بنسخة إضافية بأي وقت.', '', 'البيانات / النسخ الاحتياطية') + `<div class="settings-grid"><section class="panel"><h2>نسخة احتياطية بإيدك</h2><p>صدّر كل الأيام والخانات وحركات القاصة والموردين وموادهم وقوائمهم وتسديداتهم بملف واحد، واستورده على نفس الجهاز بعدين.</p><div class="backup-actions">${button('تصدير نسخة', 'export', true, 'download')}${button('استيراد نسخة', 'import', false, 'upload')}</div><p>الاستيراد يستبدل البيانات الحالية؛ نحفظ نسخة من الملف القديم قبل الاستبدال.</p></section><section class="panel"><h2>طريقة الحساب الحالية</h2><ul class="info-list"><li>المصاريف تجمع تلقائياً<small>تگدر تحدد مجموعاً يدوياً وترجع للحساب التلقائي.</small></li><li>الرصيد الكلي يُسجّل يدوياً<small>ما ربطناه بدخل اليوم إلى أن تحدد طريقة حسابه.</small></li><li>مصدر الدفع محفوظ لكل مصروف<small>حصة اليومي تنخصم من المتبقي المسجّل، وحصة القاصة تنخصم منها.</small></li><li>الرصيد المتبقي بعد المصاريف<small>أي مبلغ تودعه منه بالقاصة ينخصم من اليومي بنفس العملية.</small></li></ul></section><section class="panel"><h2>مكان البيانات</h2><p>ملف الحسابات يبقى خارج التطبيق، حتى تبقى البيانات عند تحديثه.</p><div class="path">${esc(directory)}</div><div class="backup-actions">${button('فتح مجلد البيانات', 'folder', false, 'folder')}</div><p>نحتفظ أيضاً بملف النسخة السابقة قبل كل حفظ ناجح.</p></section><section class="panel"><h2>التراجع عن التغييرات</h2><p>تگدر تتراجع عن آخر تغييراتك خلال جلسة التطبيق الحالية. ويشمل هذا تعديل المصاريف وحركات القاصة وحذفها.</p>${button('تراجع عن آخر تغيير', 'undo', false, 'undo')}</section></div>`; }
function render() {
  if (!state) return;
  document.querySelectorAll('[data-view]').forEach(el => { const active = el.dataset.view === view; el.classList.toggle('active', active); el.setAttribute('aria-current', active ? 'page' : 'false'); });
  main.innerHTML = ({ expenses: expensesPage, suppliers: suppliersPage, payments: paymentsPage, cash: cashPage, categories: categoriesPage, settings: settingsPage }[view])() + `<footer class="page-footer"><span>كل حساباتك محفوظة على هذا الجهاز</span><span class="number">DAFTAR / 1.5</span></footer>`;
}
async function commit(next, message, { remember = true } = {}) {
  if (busy) return false;
  busy = true; document.body.classList.add('busy'); status('جارٍ حفظ التغيير…');
  try {
    const clean = M.validate(next); const result = await window.daftar.save(clean); if (!result.ok) throw new Error(result.error);
    if (remember) { history.push(structuredClone(state)); if (history.length > 30) history.shift(); }
    state = result.data; status('محفوظ على جهازك'); render(); if (message) toast(message); return true;
  } catch (error) { status('تعذّر الحفظ · حاول مرة ثانية', true); if (host.querySelector('form')) formError(error.message); else toast(error.message, true); return false; }
  finally { busy = false; document.body.classList.remove('busy'); }
}
function editableDay(next, key) { if (!next.days[key]) next.days[key] = structuredClone(M.day(next, key)); return next.days[key]; }
function field(name, label, type = 'text', value = '', extra = '') { return `<div class="field"><label for="${name}">${label}</label><input id="${name}" name="${name}" type="${type}" value="${esc(value)}" ${extra}></div>`; }
function amountField(value = '', label = 'المبلغ', signed = false) { return `<div class="field"><label for="amount">${label}</label><div class="money-input"><input id="amount" name="amount" inputmode="${signed ? 'text' : 'numeric'}" type="text" data-number-format="${signed ? 'signed' : 'integer'}" value="${esc(N.format(value, signed ? 'signed' : 'integer'))}" required maxlength="24" autocomplete="off"><span>د.ع</span></div></div>`; }
function noteField(value = '') { return `<div class="field"><label for="note">ملاحظات<span class="optional">اختياري</span></label><textarea id="note" name="note" maxlength="2000" placeholder="اكتب أي تفاصيل تحب ترجع إلها…">${esc(value)}</textarea></div>`; }
function dExpense(date, id) { return id ? M.day(state, date).expenses.find(e => e.id === id) : null; }
function fundingFields(e, label = 'مصدر دفع المصروف') {
  const f = e ? M.funding(e) : { source: 'daily', dailyAmount: '', cashAmount: '' };
  return `<section class="funding-fields"><div class="field"><label for="payment-source">${esc(label)}</label><select id="payment-source" name="paymentSource"><option value="daily" ${f.source === 'daily' ? 'selected' : ''}>الرصيد اليومي</option><option value="cash" ${f.source === 'cash' ? 'selected' : ''}>القاصة</option><option value="shared" ${f.source === 'shared' ? 'selected' : ''}>مشترك بين اليومي والقاصة</option></select></div><div id="funding-split" class="funding-split"><div class="field"><label for="daily-amount">من الرصيد اليومي · د.ع</label><input id="daily-amount" name="dailyAmount" type="text" inputmode="numeric" maxlength="24" value="${esc(f.dailyAmount)}"></div><div class="field"><label for="cash-amount">من القاصة · د.ع</label><input id="cash-amount" name="cashAmount" type="text" inputmode="numeric" maxlength="24" value="${esc(f.cashAmount)}"></div></div><p id="funding-total" class="funding-total" role="status"></p></section>`;
}
function toggleFunding() {
  const shared = document.getElementById('payment-source').value === 'shared';
  document.getElementById('funding-split').classList.toggle('visible', shared);
  for (const id of ['daily-amount', 'cash-amount']) { const el = document.getElementById(id); el.disabled = !shared; el.required = shared; }
  if (shared && !document.getElementById('daily-amount').value && !document.getElementById('cash-amount').value) { document.getElementById('daily-amount').value = document.getElementById('amount').value || '0'; document.getElementById('cash-amount').value = '0'; }
  N.formatInputs(host); refreshFundingTotal();
}
function refreshFundingTotal() {
  const el = document.getElementById('funding-total'); if (!el) return;
  const source = document.getElementById('payment-source').value;
  el.classList.remove('mismatch');
  if (source !== 'shared') { const name = drawer?.kind === 'expense' ? 'المصروف' : 'التسديد'; el.textContent = source === 'daily' ? `مبلغ ${name} كله من الرصيد اليومي.` : `مبلغ ${name} كله ينخصم من القاصة تلقائياً.`; return; }
  try { const total = M.numeric(document.getElementById('daily-amount').value) + M.numeric(document.getElementById('cash-amount').value); const amount = M.numeric(document.getElementById('amount').value); el.textContent = `مجموع الحصتين: ${fmt(total)} من ${fmt(amount)} د.ع`; el.classList.toggle('mismatch', total !== amount); }
  catch { el.textContent = 'حدد حصة اليومي وحصة القاصة، ومجموعهن يساوي المصروف.'; }
}
function deleteBlock() { return '<div class="danger-zone"><button type="button" class="button danger" data-action="ask-delete">حذف هذا السجل</button></div>'; }
function closeDrawer() { if (busy) return; host.innerHTML = ''; drawer = null; document.body.classList.remove('drawer-open'); document.querySelector('.shell').inert = false; if (previousFocus?.isConnected) previousFocus.focus(); }
function openDrawer(kind, id = null, options = {}) {
  if (!state || busy) return;
  previousFocus = document.activeElement; drawer = { kind, id, originalDate: selectedDate };
  const d = M.day(state, selectedDate); let title, subtitle, fields, saveLabel = 'حفظ التغيير';
  if (['supplier', 'material', 'invoice', 'payment', 'debt'].includes(kind)) {
    const spec = supplierDrawer(kind, id, options); ({ title, subtitle, fields, saveLabel } = spec); drawer.wide = spec.wide;
  } else if (kind === 'expense') {
    const e = id ? d.expenses.find(e => e.id === id) : null;
    title = e ? 'تعديل المصروف' : 'إضافة مصروف'; subtitle = 'تفاصيل بسيطة، وسجل مرتب.'; saveLabel = e ? 'حفظ التعديل' : 'حفظ المصروف';
    fields = `<div class="field"><label for="category">الخانة</label><select id="category" name="category">${state.categories.map(c => `<option value="${c.id}" ${c.id === (e?.categoryId || drawer.categoryId) ? 'selected' : ''}>${esc(c.name)}</option>`).join('')}<option value="__new">+ خانة جديدة</option></select></div><div class="field inline-category" id="new-category-field"><label for="new-category">اسم الخانة الجديدة</label><input id="new-category" name="newCategory" maxlength="80" placeholder="مثلاً: الغاز">${categoryTypeField()}</div>${amountField(e?.amount ?? '')}${field('date', 'التاريخ', 'date', selectedDate, 'required')}${noteField(e?.note || '')}${fundingFields(e)}${e ? deleteBlock() : ''}`;
  } else if (kind === 'deposit' || kind === 'withdrawal' || kind === 'transaction') {
    const t = id ? state.transactions.find(t => t.id === id) : null; const type = t?.type || kind;
    drawer.type = type; title = t ? 'تعديل حركة القاصة' : type === 'deposit' ? 'إيداع بالقاصة' : 'سحب من القاصة'; subtitle = 'حدد المبلغ وسجّل حركة القاصة.'; saveLabel = t ? 'حفظ التعديل' : type === 'deposit' ? 'تسجيل الإيداع' : 'تسجيل السحب';
    fields = `<div class="drawer-summary"><p>الموجود بالقاصة</p>${num(M.cash(state))}<span class="unit">د.ع</span></div>${t ? `<div class="field"><label for="type">نوع الحركة</label><select id="type" name="type"><option value="deposit" ${type === 'deposit' ? 'selected' : ''}>إيداع</option><option value="withdrawal" ${type === 'withdrawal' ? 'selected' : ''}>سحب</option></select></div>` : ''}${amountField(t?.amount ?? '', type === 'deposit' ? 'مبلغ الإيداع' : 'مبلغ السحب')}${field('date', 'التاريخ', 'date', t?.date || selectedDate, 'required')}${noteField(t?.note || '')}${t ? deleteBlock() : ''}`;
  } else if (kind === 'day-date') {
    title = 'تعديل تاريخ الفاتورة اليومية'; subtitle = `السجل الحالي: ${prettyDate(selectedDate)}`; saveLabel = 'حفظ التواريخ';
    const last = M.recordedDays(state).filter(date => date >= selectedDate).at(-1) || selectedDate;
    fields = `${field('correct-date', 'التاريخ الصحيح لهذا اليوم', 'date', selectedDate, 'required')}<label class="checkline"><input type="checkbox" name="shiftFollowing" id="shift-following">تصحيح الأيام التالية أيضاً بنفس فرق التاريخ</label><div id="date-range-field" hidden>${field('range-end', 'لحد أي يوم مسجّل؟', 'date', last, `min="${selectedDate}"`)}</div><div class="note-box">ينتقل سجل كل يوم بمصاريفه وتسديداته وأعداد الدجاج وأرصدته وحركات القاصة. تواريخ قوائم الموردين والديون تتعدّل من سجلاتها الخاصة. تگدر تتراجع عن النقل بـ ⌘Z.</div><div id="date-preview" class="date-preview" role="status" aria-live="polite"></div>`;
  } else if (kind === 'remaining') {
    title = 'الرصيد المتبقي'; subtitle = `الباقي الفعلي ليوم ${prettyDate(selectedDate)}`;
    fields = `${amountField(M.remaining(state, selectedDate) ?? '', 'المبلغ المتبقي')}<div class="note-box">اكتب الباقي الفعلي <strong>بعد مصاريفك المسجّلة حالياً</strong>. المصاريف السابقة ما تنخصم مرة ثانية؛ ينخصم فقط أي تغيير بعدها من اليومي، وأي إيداع منه بالقاصة.</div>`;
  } else if (kind === 'remaining-transfer' || kind === 'transfer') {
    const old = id ? state.transfers.find(t => t.id === id) : null;
    if (old) { drawer.originalDate = old.date; }
    const available = M.remaining(state, drawer.originalDate);
    title = old ? 'تعديل إيداع الرصيد' : 'إيداع الرصيد بالقاصة'; subtitle = `من رصيد يوم ${prettyDate(drawer.originalDate)}`; saveLabel = old ? 'حفظ التعديل' : 'تأكيد الإيداع';
    fields = `<div class="drawer-summary"><p>المتبقي المتاح من اليومي</p>${num(available ?? 0)}<span class="unit">د.ع</span></div>${amountField(old?.amount ?? Math.max(0, available ?? 0), 'مبلغ الإيداع')}${old ? deleteBlock() : ''}<div class="note-box">تگدر تودع المبلغ كله أو جزء منه. ينضاف للقاصة وينخصم من الرصيد المتبقي بعملية واحدة.${old ? ' حذف الإيداع يرجّع المبلغ للرصيد اليومي.' : ''}</div>`;
  } else if (kind === 'chicken') {
    title = 'تتبّع الدجاج'; subtitle = `أعداد يوم ${prettyDate(selectedDate)}`;
    fields = `<div class="field-row">${field('used', 'الدجاج المصروف', 'text', d.chickenUsed, 'inputmode="numeric" required maxlength="12"')}${field('left', 'الدجاج المتبقي', 'text', d.chickenLeft, 'inputmode="numeric" required maxlength="12"')}</div><div class="note-box">الأعداد للتتبّع فقط وما تدخل بمجموع المصاريف. المتبقي يتسجّل حسب العدد اللي تحدده.</div>`;
  } else if (kind === 'balance') {
    title = 'الرصيد الكلي'; subtitle = `الرصيد المسجّل ليوم ${prettyDate(selectedDate)}`;
    fields = `${amountField(d.balance ?? '', 'الرصيد الكلي', true)}<div class="note-box">حالياً تسجّل الرصيد بإيدك. ما ينحسب تلقائياً من الدخل أو المصاريف.</div>${d.balance !== null ? '<button type="button" class="button ghost" data-action="clear-balance">إزالة الرصيد المسجّل لهذا اليوم</button>' : ''}`;
  } else if (kind === 'total') {
    title = 'مجموع المصاريف'; subtitle = 'تگدر تعتمد الجمع التلقائي أو تسجّل مجموعك.';
    fields = `<div class="drawer-summary"><p>مجموع الخانات المحسوب</p>${num(M.expenses(state, selectedDate).reduce((s, e) => s + e.amount, 0))}<span class="unit">د.ع</span></div><label class="checkline"><input type="checkbox" name="automatic" id="automatic" ${d.totalOverride === null ? 'checked' : ''}>اعتماد مجموع الخانات تلقائياً</label>${amountField(M.total(state, selectedDate), 'المجموع اليدوي')}<div class="note-box">من تعتمد مجموع يدوي، يبقى ثابت حتى تغيّره أو ترجع للحساب التلقائي.</div>`;
  } else if (kind === 'category') {
    title = 'إضافة خانة'; subtitle = 'اسم الخانة ينحفظ ويظهر بكل الأيام.';
    fields = `${field('name', 'اسم الخانة', 'text', '', 'required maxlength="80" placeholder="مثلاً: الغاز، مشتريات، أجور…"')}${categoryTypeField()}<div class="note-box">كل خانة جديدة تقبل مبلغ وملاحظات اختيارية.</div>`; saveLabel = 'حفظ الخانة';
  } else return;
  host.innerHTML = `<button class="scrim" data-action="close-drawer" aria-label="إغلاق النموذج" tabindex="-1"></button><section class="drawer ${drawer.wide ? 'wide' : ''}" role="dialog" aria-modal="true" aria-labelledby="drawer-title"><div class="drawer-top"><span>دفتر / ${kind === 'deposit' || kind === 'withdrawal' || kind === 'transaction' ? 'القاصة' : 'سجل اليوم'}</span><button class="icon-button" data-action="close-drawer" aria-label="إغلاق">${icon('close')}</button></div><div class="drawer-intro"><h2 id="drawer-title">${esc(title)}</h2><p>${esc(subtitle)}</p></div><form class="drawer-form"><div id="form-error" class="form-error" role="alert"></div>${fields}<div class="form-footer"><button class="button primary" type="submit">${saveLabel}</button><p>يحفظ التغيير تلقائياً على جهازك</p></div></form></section>`;
  document.body.classList.add('drawer-open'); document.querySelector('.shell').inert = true;
  N.formatInputs(host);
  if (kind === 'day-date') refreshDayDatePreview();
  if (kind === 'total') toggleAutomatic();
  if (kind === 'expense' || kind === 'payment' || (kind === 'invoice' && !id)) toggleFunding();
  if (kind === 'invoice') refreshInvoice();
  if (kind === 'payment') refreshPaymentChoices();
  const focus = host.querySelector('#supplier-name, #material-name, #invoice-number, #amount:not(:disabled), #used, #name, #correct-date'); if (focus) { focus.focus(); focus.select(); }
}
function refreshDayDatePreview() {
  if (drawer?.kind !== 'day-date') return;
  const range = document.getElementById('shift-following').checked, end = document.getElementById('range-end');
  document.getElementById('date-range-field').hidden = !range; end.disabled = !range; end.required = range;
  const destination = document.getElementById('correct-date').value, preview = document.getElementById('date-preview'), save = host.querySelector('[type=submit]');
  save.disabled = true;
  if (destination === drawer.originalDate) { preview.textContent = 'حدد التاريخ الصحيح حتى تشوف معاينة النقل.'; return; }
  try {
    const last = range ? end.value : drawer.originalDate, plan = M.dayDatePlan(state, drawer.originalDate, destination, last);
    M.correctDayDates(state, drawer.originalDate, destination, last);
    preview.innerHTML = `<p>راح يتغيّر تاريخ ${fmt(plan.length)} يوم. المبالغ تبقى نفسها.</p><table><thead><tr><th>التاريخ المسجّل</th><th>التاريخ الصحيح</th></tr></thead><tbody>${plan.slice(0, 100).map(p => `<tr><td class="number">${p.from}</td><td class="number">${p.to}</td></tr>`).join('')}</tbody></table>${plan.length > 100 ? '<p>المعاينة تعرض أول 100 يوم؛ الحفظ يشمل كل الأيام المختارة.</p>' : ''}`;
    save.disabled = false;
  } catch (error) { preview.textContent = error.message; }
}
function formError(message) { const error = document.getElementById('form-error'); error.textContent = message; error.classList.add('visible'); error.scrollIntoView({ block: 'nearest' }); }
function toggleAutomatic() { const automatic = document.getElementById('automatic'); const amount = document.getElementById('amount'); amount.disabled = automatic.checked; amount.required = !automatic.checked; }
function addCategory(next, name, type = 'additional') { name = String(name).trim(); if (!name || name.length > 80) throw new Error('اكتب اسم الخانة، بحد أقصى 80 حرف.'); if (next.categories.some(c => c.name === name)) throw new Error('اسم الخانة موجود مسبقاً. اختاره من القائمة.'); if (next.categories.length >= 500) throw new Error('وصلت للحد الأقصى للخانات.'); const id = crypto.randomUUID(); next.categories.push({ id, name, type }); return id; }
async function submitForm(event) {
  event.preventDefault(); if (busy || !drawer) return;
  const form = event.target; N.formatInputs(form);
  const values = new FormData(form), next = structuredClone(state), context = { ...drawer }; let message = 'تم حفظ التغيير';
  try {
    if (['supplier', 'material', 'invoice', 'payment', 'debt'].includes(context.kind)) { message = supplierSubmit(next, context, values, form); }
    else if (context.kind === 'day-date') {
      const destination = values.get('correct-date'), end = values.has('shiftFollowing') ? values.get('range-end') : context.originalDate;
      Object.assign(next, M.correctDayDates(state, context.originalDate, destination, end)); context.resultDate = destination; message = 'تم تصحيح تواريخ الفواتير اليومية';
    } else if (context.kind === 'expense') {
      const date = values.get('date'); if (!M.validDate(date)) throw new Error('اختار تاريخ صحيح.');
      let categoryId = values.get('category'); if (categoryId === '__new') categoryId = addCategory(next, values.get('newCategory'), values.get('categoryType'));
      const amount = M.numeric(values.get('amount')), source = values.get('paymentSource');
      const dailyAmount = source === 'daily' ? amount : source === 'cash' ? 0 : M.numeric(values.get('dailyAmount'));
      const cashAmount = source === 'cash' ? amount : source === 'daily' ? 0 : M.numeric(values.get('cashAmount'));
      if (dailyAmount + cashAmount !== amount) throw new Error('مجموع حصة اليومي والقاصة لازم يساوي مبلغ المصروف.');
      const old = dExpense(context.originalDate, context.id);
      const e = { id: context.id || crypto.randomUUID(), categoryId, amount, note: String(values.get('note')).trim(), funding: { source, dailyAmount, cashAmount }, createdAt: old?.createdAt || new Date().toISOString() };
      if (context.id) editableDay(next, context.originalDate).expenses = editableDay(next, context.originalDate).expenses.filter(e => e.id !== context.id);
      editableDay(next, date).expenses.push(e); context.resultDate = date; message = context.id ? 'تم تعديل المصروف' : 'تم حفظ المصروف';
    } else if (['deposit', 'withdrawal', 'transaction'].includes(context.kind)) {
      const date = values.get('date'); if (!M.validDate(date)) throw new Error('اختار تاريخ صحيح.');
      const old = next.transactions.find(t => t.id === context.id);
      const t = { id: context.id || crypto.randomUUID(), type: values.get('type') || context.type, amount: M.numeric(values.get('amount'), { positive: true }), note: String(values.get('note')).trim(), date, createdAt: old?.createdAt || new Date().toISOString() };
      next.transactions = next.transactions.filter(t => t.id !== context.id); next.transactions.push(t); message = context.id ? 'تم تعديل الحركة' : t.type === 'deposit' ? 'تم تسجيل الإيداع' : 'تم تسجيل السحب';
    } else if (context.kind === 'remaining') { M.recordRemaining(next, selectedDate, M.numeric(values.get('amount'))); message = 'تم تسجيل الرصيد المتبقي'; }
    else if (context.kind === 'remaining-transfer' || context.kind === 'transfer') { M.transferRemaining(next, context.originalDate, M.numeric(values.get('amount'), { positive: true }), crypto.randomUUID(), new Date().toISOString(), context.id); message = context.id ? 'تم تعديل الإيداع والرصيدين' : 'تم إيداع المبلغ بالقاصة وخصمه من اليومي'; }
    else if (context.kind === 'chicken') { const d = editableDay(next, selectedDate); d.chickenUsed = M.numeric(values.get('used')); d.chickenLeft = M.numeric(values.get('left')); message = 'تم حفظ أعداد الدجاج'; }
    else if (context.kind === 'balance') { editableDay(next, selectedDate).balance = M.numeric(values.get('amount'), { signed: true }); message = 'تم تسجيل الرصيد'; }
    else if (context.kind === 'total') { editableDay(next, selectedDate).totalOverride = values.has('automatic') ? null : M.numeric(values.get('amount')); message = values.has('automatic') ? 'تم اعتماد الجمع التلقائي' : 'تم حفظ المجموع اليدوي'; }
    else if (context.kind === 'category') { addCategory(next, values.get('name'), values.get('categoryType')); message = 'تم حفظ الخانة الجديدة'; }
    if (await commit(next, message)) { if (context.resultSupplier) { selectedSupplier = context.resultSupplier; view = 'suppliers'; render(); } if (context.resultDate) { selectedDate = context.resultDate; render(); } closeDrawer(); }
  } catch (error) { formError(error.message); }
}
async function undo() { if (!state || busy) return; if (!history.length) { toast('ماكو تغيير للتراجع عنه بهالجلسة.'); return; } const next = history[history.length - 1]; if (await commit(next, 'تم التراجع عن آخر تغيير', { remember: false })) { history.pop(); closeDrawer(); } }
async function backup(action) {
  if (busy) return; closeDrawer();
  try { const result = await window.daftar[action](); if (!result.ok) throw new Error(result.error); if (result.canceled) return; if (action === 'import') { state = result.data; directory = result.directory; history = []; selectedDate = M.dateKey(); view = 'expenses'; render(); status('محفوظ على جهازك'); } toast(action === 'export' ? 'تم تصدير النسخة الاحتياطية' : 'تم استيراد الحسابات'); }
  catch (error) { toast(error.message, true); }
}
async function exportPDF(request, trigger = null) {
  if (!state || busy) return;
  busy = true;
  if (trigger) { trigger.disabled = true; trigger.setAttribute('aria-busy', 'true'); }
  try {
    const result = await window.daftar.pdf(request);
    if (!result.ok) throw new Error(result.error);
    if (!result.canceled) toast('تم حفظ ملف PDF');
  } catch (error) { toast('تعذّر تصدير PDF: ' + error.message, true); }
  finally { busy = false; if (trigger) { trigger.disabled = false; trigger.removeAttribute('aria-busy'); } }
}
function moveDate(step) { const d = new Date(`${selectedDate}T12:00:00`); d.setDate(d.getDate() + step); selectedDate = M.dateKey(d); render(); }
document.addEventListener('click', async event => {
  const nav = event.target.closest('[data-view]'); if (nav) { view = nav.dataset.view; render(); return; }
  const el = event.target.closest('[data-action]'); if (!el || busy) return; const action = el.dataset.action;
  if (action === 'daily-pdf' || action === 'invoice-pdf') { await exportPDF(action === 'daily-pdf' ? { kind: 'daily', date: selectedDate } : { kind: 'invoice', id: el.dataset.id }, el); return; }
  const handled = supplierAction(action, el); if (handled) { await handled; return; }
  if (action === 'close-drawer') closeDrawer();
  else if (['expense', 'deposit', 'withdrawal', 'category', 'chicken', 'balance', 'total', 'remaining', 'remaining-transfer', 'day-date'].includes(action)) openDrawer(action);
  else if (action === 'edit-expense') openDrawer('expense', el.dataset.id);
  else if (action === 'edit-transaction') { if (el.dataset.kind === 'supplier-payment') openDrawer('payment', el.dataset.id); else if (el.dataset.kind === 'expense') { selectedDate = el.dataset.date; openDrawer('expense', el.dataset.id); } else openDrawer(el.dataset.kind === 'transfer' ? 'transfer' : 'transaction', el.dataset.id); }
  else if (action === 'category-expense') { openDrawer('expense'); document.getElementById('category').value = el.dataset.id; }
  else if (action === 'view-cash') { view = 'cash'; render(); }
  else if (action === 'previous-day' || action === 'next-day') moveDate(action === 'previous-day' ? -1 : 1);
  else if (action === 'today') { selectedDate = M.dateKey(); render(); }
  else if (action === 'export' || action === 'import') backup(action);
  else if (action === 'folder') { const result = await window.daftar.folder(); if (!result.ok) toast(result.error, true); }
  else if (action === 'undo') undo();
  else if (action === 'clear-balance') { const next = structuredClone(state); editableDay(next, selectedDate).balance = null; if (await commit(next, 'تمت إزالة الرصيد المسجّل')) closeDrawer(); }
  else if (action === 'ask-delete') { el.parentElement.innerHTML = '<div class="confirm-delete"><p>تحذف هذا السجل؟ تگدر تتراجع عن الحذف خلال هالجلسة.</p><button type="button" class="button danger small" data-action="confirm-delete">حذف السجل</button><button type="button" class="button small" data-action="cancel-delete">إلغاء</button></div>'; }
  else if (action === 'cancel-delete') el.closest('.danger-zone').innerHTML = '<button type="button" class="button danger" data-action="ask-delete">حذف هذا السجل</button>';
  else if (action === 'confirm-delete') { const next = structuredClone(state); if (drawer.kind === 'expense') { const d = editableDay(next, drawer.originalDate); d.expenses = d.expenses.filter(e => e.id !== drawer.id); } else if (drawer.kind === 'transfer') next.transfers = next.transfers.filter(t => t.id !== drawer.id); else next.transactions = next.transactions.filter(t => t.id !== drawer.id); if (await commit(next, 'تم حذف السجل · تگدر تتراجع بـ ⌘Z')) closeDrawer(); }
});
document.addEventListener('change', async event => {
  if (event.target.matches('.category-type-select')) {
    const el = event.target, category = state.categories.find(c => c.id === el.dataset.categoryId);
    if (!category) return;
    if (busy || el.value === category.type) { el.value = category.type; return; }
    const next = structuredClone(state), hadFocus = document.activeElement === el;
    next.categories.find(c => c.id === category.id).type = el.value; el.disabled = true;
    const saved = await commit(next, 'تم حفظ نوع الخانة');
    if (!saved) { el.value = category.type; el.disabled = false; }
    if (hadFocus && view === 'categories') main.querySelector(`[data-category-id="${category.id}"]`)?.focus();
  } else if (drawer?.kind === 'day-date' && ['correct-date', 'shift-following', 'range-end'].includes(event.target.id)) refreshDayDatePreview();
  else if (event.target.id === 'selected-date' && M.validDate(event.target.value)) { selectedDate = event.target.value; render(); }
  else if (event.target.id === 'category') { const field = document.getElementById('new-category-field'); const isNew = event.target.value === '__new'; field.classList.toggle('visible', isNew); document.getElementById('new-category').required = isNew; if (isNew) document.getElementById('new-category').focus(); }
  else if (event.target.id === 'automatic') toggleAutomatic();
  else if (event.target.id === 'payment-source') toggleFunding();
});
host.addEventListener('submit', submitForm);
host.addEventListener('input', event => { if (drawer?.kind === 'day-date') refreshDayDatePreview(); if (['expense', 'payment', 'invoice'].includes(drawer?.kind) && ['amount', 'daily-amount', 'cash-amount'].includes(event.target.id)) refreshFundingTotal(); });
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && drawer) { event.preventDefault(); closeDrawer(); }
  if (event.key === 'Tab' && drawer) { const focusable = [...host.querySelectorAll('button:not([disabled]):not(.scrim), input:not([disabled]), select, textarea')].filter(el => el.getClientRects().length); const first = focusable[0], last = focusable[focusable.length - 1]; if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); } else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); } }
});
document.querySelectorAll('[data-icon]').forEach(el => el.innerHTML = icon(el.dataset.icon));
main.innerHTML = '<div class="loading">جارٍ فتح حساباتك…</div>';
if (window.daftar) {
  window.daftar.onAction(action => { if (action === 'undo') { if (document.activeElement.matches('input,textarea')) document.execCommand('undo'); else undo(); } else if (action === 'daily-pdf') { if (drawer) { toast('كمّل النموذج أو أغلقه حتى تصدّر الحسابات المحفوظة.'); return; } exportPDF({ kind: 'daily', date: selectedDate }); } else if (action === 'export' || action === 'import') backup(action); else if (action === 'expense') openDrawer('expense'); else if (action === 'settings') { closeDrawer(); view = 'settings'; render(); } });
  window.daftar.load().then(result => { if (!result.ok) throw new Error(result.error); state = M.validate(result.data); directory = result.directory; render(); status('محفوظ على جهازك'); }).catch(error => { status('الحسابات تحتاج استعادة', true); main.innerHTML = `<section class="panel load-error"><h1>نحافظ على بياناتك أولاً.</h1><p>${esc(error.message)}</p>${button('استيراد نسخة احتياطية', 'import', true, 'upload')}</section>`; });
} else main.innerHTML = '<section class="panel load-error"><h1>افتح تطبيق دفتر.</h1><p>هذه الواجهة تشتغل من داخل التطبيق حتى تحفظ الحسابات بملف محلي.</p></section>';
