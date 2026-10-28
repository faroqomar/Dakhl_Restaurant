'use strict';
let selectedSupplier = null, supplierTab = 'invoices', supplierQuery = '', invoiceRowId = 0;
const supplierById = id => state.suppliers.find(s => s.id === id);
const invoiceById = id => state.invoices.find(i => i.id === id);
const debtById = id => state.debts.find(d => d.id === id);
const paymentBreakdown = p => { const split = M.paymentAllocation(p); return p.invoiceId && split.debtAmount ? `للقائمة ${fmt(split.invoiceAmount)} · للديون ${fmt(split.debtAmount)} د.ع` : ''; };
const supplierOptions = id => state.suppliers.filter(s => !s.archived || s.id === id).map(s => `<option value="${s.id}" ${s.id === id ? 'selected' : ''}>${esc(s.name)}</option>`).join('');
const expenseCategorySelect = id => `<div class="field"><label for="expense-category">خانة المصروف عند التسديد</label><select id="expense-category" name="categoryId">${state.categories.filter(c => !c.archived || c.id === id).map(c => `<option value="${c.id}" ${c.id === id ? 'selected' : ''}>${esc(c.name)}</option>`).join('')}</select></div>`;
function supplierEmpty(title, description, label, action) { return `<div class="empty-state supplier-empty"><h3>${title}</h3><p>${description}</p>${button(label, action, true, 'plus')}</div>`; }
function suppliersPage() {
  if (!supplierById(selectedSupplier)) selectedSupplier = state.suppliers.find(s=>!s.archived)?.id || null;
  const supplier = supplierById(selectedSupplier);
  return header('كل مورد، حسابه مرتب.', 'قوائم ومواد محفوظة، وتسديدات مرتبطة بالمصاريف.', button('إضافة مورد', 'supplier-new', true, 'plus'), 'الموردون / الحسابات') + (supplier ? `<div class="supplier-workspace"><aside class="supplier-index"><div class="supplier-index-head"><h2>الموردون</h2><span class="badge">${fmt(state.suppliers.length)}</span></div><label class="sr-only" for="supplier-search">ابحث عن مورد</label><input id="supplier-search" type="search" placeholder="ابحث عن مورد…" value="${esc(supplierQuery)}" class="supplier-search"><div id="supplier-list" class="supplier-list">${supplierList()}</div></aside><section class="supplier-detail">${supplierDetail(supplier)}</section></div>` : supplierEmpty('ابدأ بأول مورد.', 'سجّل اسمه والديون الباقية عليك، ثم أضف قوائمه ومواده.', 'إضافة مورد', 'supplier-new'));
}
let invoiceFilter = { material: '', from: '', to: '', supplierId: '' };
function invoicesPage() {
  if (!supplierById(selectedSupplier)) selectedSupplier = state.suppliers.find(s=>!s.archived)?.id || null;
  const materials = [...new Set(state.invoices.flatMap(i => i.lines.map(l => l.name)))].sort((a,b)=>a.localeCompare(b,'ar'));
  const selected = invoiceFilter.material;
  const filtered = state.invoices.filter(i => (!invoiceFilter.from || i.date >= invoiceFilter.from) && (!invoiceFilter.to || i.date <= invoiceFilter.to) && (!invoiceFilter.supplierId || i.supplierId === invoiceFilter.supplierId) && (!selected || i.lines.some(l => N.latin(l.name).toLowerCase() === N.latin(selected).toLowerCase()))).sort((a,b)=>a.date.localeCompare(b.date));
  const lines = filtered.flatMap(i => i.lines.filter(l => !selected || N.latin(l.name).toLowerCase() === N.latin(selected).toLowerCase()).map(l => ({ invoice:i,line:l,supplier:supplierById(i.supplierId) })));
  const cartonQty = lines.reduce((n,x)=>n+(x.line.quantityCartons ?? 0),0), pieceQty = lines.reduce((n,x)=>n+(x.line.quantityPieces ?? x.line.quantity ?? 0),0), amount = lines.reduce((n,x)=>n+M.lineTotal(x.line),0);
  const priceHistory = state.invoices.filter(i=>!invoiceFilter.supplierId||i.supplierId===invoiceFilter.supplierId).flatMap(i=>i.lines.filter(l=>!selected||N.latin(l.name).toLowerCase()===N.latin(selected).toLowerCase()).map(line=>({date:i.date,supplier:supplierById(i.supplierId)?.name||'مورد',price:line.pricePiece??line.price??0,carton:line.priceCarton??0,name:line.name}))).sort((a,b)=>a.date.localeCompare(b.date));
  const changes = priceHistory.map((p,n,all)=>{const prev=[...all.slice(0,n)].reverse().find(x=>x.name===p.name);return prev&&(p.price!==prev.price||p.carton!==prev.carton)?{...p,deltaPiece:p.price-prev.price,deltaCarton:p.carton-prev.carton}:null}).filter(p=>p&&(!invoiceFilter.from||p.date>=invoiceFilter.from)&&(!invoiceFilter.to||p.date<=invoiceFilter.to));
  return header('فواتير المشتريات', 'أدخل القوائم بتاريخها، وتابع الكميات والأسعار وتسديد كل مورد.', button('إضافة فاتورة', 'invoice-new', true, 'plus'), 'المشتريات / الفواتير') + `<section class="panel invoice-filters"><div class="section-head"><div><h2>تحليل المشتريات</h2><p class="section-description">اختار مادة وفترة حتى تشوف الكمية والموردين وتغيّر الأسعار.</p></div></div><div class="invoice-filter-fields"><label>المادة<select id="invoice-filter-material"><option value="">كل المواد</option>${materials.map(m=>`<option ${selected===m?'selected':''}>${esc(m)}</option>`).join('')}</select></label><label>من تاريخ<input id="invoice-filter-from" type="date" value="${esc(invoiceFilter.from)}"></label><label>إلى تاريخ<input id="invoice-filter-to" type="date" value="${esc(invoiceFilter.to)}"></label><label>المورد<select id="invoice-filter-supplier"><option value="">كل الموردين</option>${state.suppliers.map(s=>`<option value="${s.id}" ${invoiceFilter.supplierId===s.id?'selected':''}>${esc(s.name)}</option>`).join('')}</select></label></div><div class="invoice-analysis-summary"><div class="unit-totals">${purchaseUnitTotals(lines)}</div><div><span>المبلغ الكلي</span><strong>${fmt(amount)} د.ع</strong></div><div><span>عدد الفواتير</span><strong>${fmt(filtered.length)}</strong></div></div></section><section class="panel supplier-body"><div class="section-head"><h2>${selected ? `تفاصيل شراء ${esc(selected)}` : 'الفواتير'}</h2><span class="badge">${fmt(lines.length)} بند</span></div>${purchaseGroups(filtered, selected)}</section><section class="panel supplier-body"><div class="section-head"><div><h2>تغيّر الأسعار</h2><p class="section-description">مقارنة سعر الكارتون والقطعة مع آخر شراء للصنف.</p></div></div>${changes.length?`<div class="table-scroll"><table class="supplier-table"><thead><tr><th>التاريخ</th><th>المورد</th><th>سعر الكارتون</th><th>سعر القطعة</th><th>التغير عن الشراء السابق</th></tr></thead><tbody>${pageItems(changes, 'price-history').map(p=>`<tr><td>${esc(shortDate(p.date))}</td><td>${esc(p.supplier)} · ${esc(p.name)}</td><td>${num(p.carton)}</td><td>${num(p.price)}</td><td>${p.deltaPiece>=0?'+':''}${fmt(p.deltaPiece)} د.ع للقطعة · ${p.deltaCarton>=0?'+':''}${fmt(p.deltaCarton)} للكارتون</td></tr>`).join('')}</tbody></table></div>`:'<p class="empty-help">تغيّر السعر يظهر بعد تسجيل أكثر من شراء للمادة بأسعار مختلفة.</p>'}</section>`;
}
function supplierList() {
  const suppliers = state.suppliers.filter(s => N.latin(s.name).toLowerCase().includes(supplierQuery.trim().toLowerCase()));
  return suppliers.length ? suppliers.map(s => `<button class="supplier-choice ${selectedSupplier === s.id ? 'selected' : ''}" data-action="supplier-select" data-id="${s.id}" aria-pressed="${selectedSupplier === s.id}"><strong>${esc(s.name)}${s.archived?' · موقوف':''}</strong><span>${num(M.supplierBalance(state, s.id))}<small>د.ع متبقي</small></span></button>`).join('') : '<p class="empty-help">ماكو مورد بهذا الاسم.</p>';
}
function supplierDetail(s) {
  const invoices = state.invoices.filter(i => i.supplierId === s.id).sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
  const payments = state.payments.filter(p => p.supplierId === s.id), balance = M.supplierBalance(state, s.id);
  let body;
  if (supplierTab === 'materials') body = materialsCatalogPanel();
  else if (supplierTab === 'debts') body = supplierDebtsPanel(s);
  else if (supplierTab === 'ledger') body = supplierLedgerPanel(s);
  else body = `<section class="panel supplier-body"><div class="section-head"><h2>قوائم ${esc(s.name)}</h2><button class="button small" data-action="invoice-new">+ قائمة جديدة</button></div>${invoices.length ? `<div class="table-scroll"><table class="supplier-table"><thead><tr><th>رقم القائمة / التاريخ</th><th>قيمة القائمة</th><th>التسديد</th><th>المتبقي منها</th><th>إجراءات</th></tr></thead><tbody>${pageItems(invoices, 'supplier-invoices').map(i => { const due = M.invoiceDue(state, i.id); return `<tr><td><strong>${esc(i.number)}</strong><small>${esc(shortDate(i.date))} · ${fmt(i.lines.length)} مادة</small></td><td>${num(M.invoiceTotal(i))}</td><td>${num(M.invoicePaid(state, i.id))}</td><td>${num(due)}${due === 0 ? '<small class="paid-label">مسددة بالكامل</small>' : ''}</td><td><div class="row-actions"><button class="text-link" data-action="invoice-pdf" data-id="${i.id}" aria-label="تصدير القائمة ${esc(i.number)} PDF">PDF</button><button class="icon-button" data-action="invoice-edit" data-id="${i.id}" aria-label="تفاصيل وتعديل القائمة ${esc(i.number)}">${icon('edit')}</button><button class="text-link" data-action="invoice-pay" data-id="${i.id}" ${due === 0 ? 'disabled' : ''}>تسديد</button></div></td></tr>`; }).join('')}</tbody></table></div>` : supplierEmpty('أول قائمة، بداية سجل واضح.', 'رقم القائمة، المواد، الكميات والسعر. التسديد الآن أو بعدين.', 'إضافة قائمة', 'invoice-new')}</section>`;
  return `<div class="supplier-detail-head"><div><p class="eyebrow">حساب المورد</p><h2>${esc(s.name)}</h2>${s.phone ? `<p class="supplier-contact" dir="auto">${esc(s.phone)}</p>` : ''}${s.note ? `<p class="supplier-note">${esc(s.note)}</p>` : ''}</div><div class="header-actions"><button class="button small" data-action="supplier-edit" data-id="${s.id}">تعديل المورد</button><button class="button primary small" data-action="payment-new" ${balance <= 0 ? 'disabled' : ''}>تسجيل تسديد</button></div></div><div class="supplier-summary"><div><p class="summary-label">الديون الباقية عليك</p>${num(M.debtAvailable(state, s.id), 'summary-value')}<span class="unit">د.ع</span></div><div><p class="summary-label">مجموع التسديدات</p>${num(payments.reduce((n, p) => n + p.amount, 0), 'summary-value')}<span class="unit">د.ع</span></div><div><p class="summary-label">الرصيد الحالي عليك</p>${num(balance, 'summary-value')}<span class="unit">د.ع</span></div></div><nav class="supplier-tabs" aria-label="تفاصيل المورد">${[['invoices', 'القوائم'], ['debts', 'الديون'], ['materials', 'كتالوج المواد المشترك'], ['ledger', 'كشف الحساب']].map(([key, label]) => `<button data-action="supplier-tab" data-tab="${key}" class="${supplierTab === key ? 'active' : ''}" aria-current="${supplierTab === key ? 'page' : 'false'}">${label}</button>`).join('')}</nav>${body}`;
}
function materialsCatalogPanel() {
  const matches=state.materials.filter(m => (!materialsFilter.query || `${m.name} ${m.unit}`.toLowerCase().includes(materialsFilter.query.toLowerCase())) && (materialsFilter.status==='all' || m.archived === (materialsFilter.status==='archived'))); pageCounts.materials=matches.length;
  return `<section class="panel supplier-body"><div class="section-head"><div><h2>مواد فواتير كل الموردين</h2><p class="section-description">قائمة مشتركة؛ الأسعار هنا تُعبّأ تلقائياً عند اختيار المادة بأي فاتورة.</p></div><button class="button small" data-action="material-new">+ إضافة مادة</button></div>${matches.length ? `<p class="filter-summary">${fmt(matches.length)} نتيجة</p><div class="table-scroll"><table class="supplier-table materials-table"><thead><tr><th>المادة</th><th>الوحدة</th><th>سعر الكارتون · د.ع</th><th>سعر القطعة · د.ع</th><th>الحالة</th><th>تعديل</th></tr></thead><tbody>${pageItems(matches, 'materials').map(m => `<tr class="${m.archived ? 'archived-row' : ''}"><td><strong>${esc(m.name)}</strong></td><td>${esc(m.unit)}</td><td>${num(m.priceCarton)}</td><td>${num(m.pricePiece)}</td><td>${m.archived ? 'متوقفة عن الفواتير الجديدة' : 'نشطة'}</td><td><button class="icon-button" data-action="material-edit" data-id="${m.id}" aria-label="تعديل مادة ${esc(m.name)}">${icon('edit')}</button></td></tr>`).join('')}</tbody></table></div>` : state.materials.length ? '<p class="empty-help">ماكو مواد مطابقة. <button class="button" data-action="materials-reset">مسح التصفية</button></p>' : supplierEmpty('قائمة مواد مشتركة.', 'أضف المادة وأسعار الكارتون والقطعة مرة واحدة، وتظهر عند اختيار أي مورد.', 'إضافة مادة', 'material-new')}</section>`;
}
function materialsPage() {
  return header('المواد والأسعار', 'قائمة موحّدة لكل الموردين. حدّث الاسم والوحدة وسعري الكارتون والقطعة من هنا.', button('إضافة مادة', 'material-new', true, 'plus'), 'المشتريات / المواد والأسعار') + materialsCatalogPanel();
}
function supplierDebtsPanel(s) {
  const debts = state.debts.filter(d => d.supplierId === s.id).sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
  return `<section class="panel supplier-body"><div class="section-head"><div><h2>ديون ${esc(s.name)}</h2><p class="section-description">الزيادة بتسديد القائمة تنخصم من هذه الديون تلقائياً.</p></div><button class="button small" data-action="debt-new">+ إضافة دين</button></div><div class="table-scroll"><table class="supplier-table"><thead><tr><th>التاريخ / الملاحظة</th><th>الدين المسجّل · د.ع</th><th>تعديل</th></tr></thead><tbody>${pageItems(debts, 'supplier-debts').map(d => `<tr><td>${esc(shortDate(d.date))}${d.note ? `<small>${esc(d.note)}</small>` : ''}</td><td>${num(d.amount)}</td><td><button class="icon-button" data-action="debt-edit" data-id="${d.id}" aria-label="تعديل الدين">${icon('edit')}</button></td></tr>`).join('')}<tr><td><strong>ديون سابقة عند تسجيل المورد</strong><small>المتبقي من جميع الديون ظاهر بالأعلى.</small></td><td>${num(s.openingBalance)}</td><td><button class="text-link" data-action="supplier-edit" data-id="${s.id}">تعديل</button></td></tr></tbody></table></div></section>`;
}
function supplierLedgerPanel(s) {
  const events = M.supplierLedger(state, s.id).reverse();
  return `<section class="panel supplier-body"><div class="section-head"><h2>كشف الحساب</h2><span class="badge">الديون + القوائم − التسديدات</span></div><div class="table-scroll"><table class="supplier-table"><thead><tr><th>التاريخ / الحركة</th><th>الحساب قبل الحركة</th><th>المبلغ</th><th>الحساب بعدها</th><th>تعديل</th></tr></thead><tbody>${pageItems(events, 'supplier-ledger').map(e => {
    const label = e.type === 'invoice' ? 'قائمة ' + e.number : e.type === 'debt' ? 'دين' : 'تسديد ' + (e.invoiceId ? 'قائمة ' + (invoiceById(e.invoiceId)?.number || '') : 'الديون');
    const action = e.type === 'invoice' ? 'invoice-edit' : e.type === 'debt' ? 'debt-edit' : 'payment-edit';
    return `<tr><td><strong>${esc(label)}</strong><small>${esc(shortDate(e.date))}</small>${e.type === 'payment' && paymentBreakdown(e) ? `<small>${esc(paymentBreakdown(e))}</small>` : e.type === 'debt' && e.note ? `<small>${esc(e.note)}</small>` : ''}</td><td>${num(e.before)}</td><td><span class="badge ${e.type === 'payment' ? '' : 'out'}">${e.type === 'payment' ? '−' : '+'} ${num(e.amount)}</span></td><td>${num(e.balance)}</td><td><button class="icon-button" data-action="${action}" data-id="${e.id}" aria-label="تعديل ${esc(label)}">${icon('edit')}</button></td></tr>`;
  }).join('')}<tr><td><strong>ديون سابقة عند تسجيل المورد</strong></td><td>—</td><td>${num(s.openingBalance)}</td><td>${num(s.openingBalance)}</td><td></td></tr></tbody></table></div></section>`;
}
function paymentsPage() {
  const payments = state.payments.filter(p=>(!paymentsFilter.from||p.date>=paymentsFilter.from)&&(!paymentsFilter.to||p.date<=paymentsFilter.to)&&(!paymentsFilter.supplierId||p.supplierId===paymentsFilter.supplierId)&&`${supplierById(p.supplierId).name} ${p.note}`.toLowerCase().includes(paymentsFilter.query.toLowerCase())).sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
  return header('التسديد، بمحله الصحيح.', 'كل دفعة مرتبطة بالمورد والقائمة ومصدر الدفع.', state.suppliers.length ? button('تسجيل تسديد', 'payment-new', true, 'plus') : '', 'الموردون / التسديدات') + `<section class="panel supplier-body">${payments.length ? `<p class="filter-summary">${fmt(payments.length)} نتيجة</p><div class="table-scroll"><table class="supplier-table payments-table"><thead><tr><th>المورد / القائمة</th><th>التاريخ</th><th>التسديد · د.ع</th><th>المصدر / الملاحظة</th><th>تعديل</th></tr></thead><tbody>${pageItems(payments, 'payments').map(p => `<tr><td><strong>${esc(supplierById(p.supplierId).name)}</strong><small>${p.invoiceId ? 'قائمة ' + esc(invoiceById(p.invoiceId).number) : 'الديون'}</small>${paymentBreakdown(p) ? `<small>${esc(paymentBreakdown(p))}</small>` : ''}</td><td>${esc(shortDate(p.date))}</td><td>${num(p.amount)}</td><td class="note">${esc(fundingLabel(p))}${p.note ? `<small>${esc(p.note)}</small>` : ''}</td><td><button class="icon-button" data-action="payment-edit" data-id="${p.id}" aria-label="تعديل التسديد">${icon('edit')}</button><button class="text-link" data-action="payment-pdf" data-id="${p.id}">وصل PDF</button></td></tr>`).join('')}</tbody></table></div>` : state.payments.length ? '<p class="empty-help">ماكو تسديدات مطابقة. <button class="button" data-action="filter-preset" data-key="payments" data-period="all">مسح التصفية</button></p>' : supplierEmpty('الدفعات تنحفظ هنا.', 'ابدأ بمورد وقائمة، وبعدها سجّل التسديد الجزئي أو الكامل.', state.suppliers.length ? 'تسجيل تسديد' : 'إضافة مورد', state.suppliers.length ? 'payment-new' : 'supplier-new')}</section>`;
}
function supplierDrawer(kind, id, options) {
  let title, subtitle, fields, saveLabel = 'حفظ التغيير';
  if (kind === 'supplier') {
    const s = supplierById(id); title = s ? 'تعديل المورد' : 'إضافة مورد'; subtitle = 'اسم المورد والديون السابقة الباقية عليك.';
    fields = `${field('supplier-name', 'اسم المورد', 'text', s?.name || '', 'required maxlength="100"')}${field('phone', 'رقم الهاتف · اختياري', 'text', s?.phone || '', 'maxlength="80"')}${amountField(s?.openingBalance || 0, 'الديون السابقة عليك')}${expenseCategorySelect(s?.categoryId || 'market')}${noteField(s?.note || '')}<div class="note-box">هذا المبلغ دين لازم تسدده. يظهر المتبقي منه بحساب المورد، والزيادة بتسديد أي قائمة تنخصم منه. التسديد وحده يظهر بالمصاريف اليومية.</div>`;
  } else if (kind === 'debt') {
    const d = debtById(id); drawer.supplierId = d?.supplierId || selectedSupplier; const s = supplierById(drawer.supplierId); if (!s) throw new Error('اختار مورداً أولاً.');
    title = d ? 'تعديل الدين' : 'إضافة دين'; subtitle = `ديون ${s.name}`; saveLabel = 'حفظ الدين';
    fields = `${amountField(d?.amount ?? '', 'مبلغ الدين')}${field('date', 'تاريخ الدين', 'date', d?.date || selectedDate, 'required')}${noteField(d?.note || '')}<div class="note-box">ينضاف للديون الباقية عليك. تسجيل الدين ما يحسب مصروفاً؛ المصروف ينحسب عند التسديد.${d ? ' ما تگدر تقلله أو تحذفه إذا يصير أقل من التسديدات المسجّلة.' : ''}</div>${d ? deleteBlock() : ''}`;
  } else if (kind === 'material') {
    const m = state.materials.find(m => m.id === id);
    title = m ? 'تعديل مادة مشتركة' : 'إضافة مادة مشتركة'; subtitle = 'تظهر المادة وأسعارها عند إنشاء فاتورة لأي مورد.';
    fields = `${field('material-name', 'اسم المادة', 'text', m?.name || '', 'required maxlength="100"')}${field('unit', 'وحدة القياس', 'text', m?.unit || 'قطعة', 'required maxlength="30" placeholder="كيلو، كارتون، قطعة…"')}${amountField(m?.priceCarton || 0, 'سعر الكارتون')}${field('piece-price', 'سعر القطعة · د.ع', 'text', m?.pricePiece || 0, 'inputmode="numeric" data-number-format="integer" required maxlength="24"')}${m ? `<label class="checkline"><input type="checkbox" name="archived" ${m.archived ? 'checked' : ''}>إيقاف اختيار المادة بالفواتير الجديدة</label>` : ''}<div class="note-box">تعديل السعر الافتراضي ما يغيّر أي فاتورة محفوظة؛ كل فاتورة تحتفظ بأسعارها وقت تسجيلها.</div>`;
  } else if (kind === 'invoice') {
    const inv = invoiceById(id); drawer.supplierId = inv?.supplierId || options.supplierId || (supplierById(selectedSupplier)?.archived ? null : selectedSupplier) || state.suppliers.find(s=>!s.archived)?.id; const s = supplierById(drawer.supplierId); if (!s) throw new Error('اختار مورداً أولاً.'); drawer.createdAt = inv?.createdAt || new Date().toISOString();
    title = inv ? 'تفاصيل وتعديل القائمة' : 'قائمة جديدة'; subtitle = `حساب ${s.name}`; saveLabel = inv ? 'حفظ القائمة' : 'حفظ القائمة والتسديد';
    fields = `${!inv ? `<div class="field"><label for="invoice-supplier">المورد</label><select id="invoice-supplier">${supplierOptions(s.id)}</select></div>` : ''}<div class="field-row">${field('invoice-number', 'رقم القائمة', 'text', inv?.number || '', 'required maxlength="80"')}${field('date', 'تاريخ القائمة', 'date', inv?.date || selectedDate, 'required')}</div><datalist id="supplier-materials">${state.materials.filter(m => !m.archived).map(m => `<option value="${esc(m.name)}">${esc(m.unit)} · كارتون ${fmt(m.priceCarton)} / قطعة ${fmt(m.pricePiece)} د.ع</option>`).join('')}</datalist><div class="invoice-lines-head"><h3>مواد القائمة</h3><button type="button" class="text-link" data-action="invoice-line-add">+ إضافة مادة</button></div><div id="invoice-lines">${(inv?.lines || [null]).map(l => invoiceLine(l)).join('')}</div><p class="invoice-line-hint">اختار مادة محفوظة أو اكتب اسماً جديداً وينحفظ بكتالوج مشترك لكل الموردين. الكمية تقبل كسوراً حتى 3 خانات؛ مبلغ المادة يقرّب لأقرب دينار.</p><div class="invoice-totals"><div><span>الحساب قبل القائمة</span><strong id="invoice-old-balance"></strong></div><div><span>مجموع القائمة · د.ع</span><strong id="invoice-total"></strong></div><div><span>${inv ? 'المسدّد من هذه القائمة' : 'التسديد الآن'}</span><strong id="invoice-paid"></strong></div><div class="invoice-current"><span>الرصيد بعد القائمة وتسديدها</span><strong id="invoice-current-balance"></strong></div></div>${inv ? `<div class="note-box">التسديدات المسجّلة تتعدّل من <strong>كشف الحساب أو التسديدات</strong>. ما تگدر تنزل قيمة القائمة أقل من المسدّد منها.</div>` : amountField('0', 'التسديد الآن · صفر إذا آجل')}${noteField(inv?.note || '')}${inv ? deleteBlock() : paymentSplitPanel('invoice-payment-split') + fundingFields(null, 'مصدر التسديد')}<div class="note-box">تگدر تسدد أكثر من قيمة القائمة؛ الزيادة تنخصم من ديون المورد. المبلغ المدفوع كله ينحسب مرة واحدة بالمصاريف ومن مصدر الدفع.</div>`;
  } else if (kind === 'payment') {
    const p = state.payments.find(p => p.id === id); drawer.supplierId = p?.supplierId || options.supplierId || selectedSupplier || state.suppliers.find(s=>!s.archived)?.id; if (!supplierById(drawer.supplierId)) throw new Error('أضف مورداً أولاً.'); drawer.invoiceId = p?.invoiceId ?? options.invoiceId ?? null;
    title = p ? 'تعديل التسديد' : 'تسجيل تسديد'; subtitle = 'تسديد جزئي أو كامل، ومصدره محفوظ.'; saveLabel = 'حفظ التسديد';
    fields = `<div class="field"><label for="payment-supplier">المورد</label><select id="payment-supplier" name="supplierId">${supplierOptions(drawer.supplierId)}</select></div><div class="field"><label for="invoice-id">القائمة / الديون</label><select id="invoice-id" name="invoiceId"></select></div><div class="drawer-summary"><p id="payment-invoice-due"></p><p id="payment-debt-due"></p><p>أقصى مبلغ متاح للتسديد</p><span id="payment-available" class="number"></span><span class="unit">د.ع</span></div>${amountField(p?.amount ?? '', 'مبلغ التسديد')}${field('date', 'تاريخ التسديد', 'date', p?.date || selectedDate, 'required')}${expenseCategorySelect(p?.categoryId || supplierById(drawer.supplierId).categoryId)}${noteField(p?.note || '')}${paymentSplitPanel('payment-split')}${fundingFields(p, 'مصدر التسديد')}${p ? deleteBlock() : ''}`;
  } else return null;
  return { title, subtitle, fields, saveLabel, wide: kind === 'invoice' };
}
function invoiceLine(line) {
  const key = ++invoiceRowId;
  const legacy = line?.quantity !== undefined && line?.quantityCartons === undefined;
  return `<div class="invoice-line" data-key="${key}" data-material-id="${esc(line?.materialId || '')}" data-original-name="${esc(line?.name || '')}"><div class="invoice-line-fields"><div class="field line-name"><label for="line-name-${key}">المادة</label><input id="line-name-${key}" class="line-name-input" list="supplier-materials" value="${esc(line?.name || '')}" maxlength="100" required autocomplete="off" placeholder="اختار أو اكتب اسم المادة"></div><div class="field"><label for="line-cartons-${key}">الكمية كارتون</label><input id="line-cartons-${key}" class="line-cartons" inputmode="decimal" value="${esc(legacy?'0':line?.quantityCartons??0)}" required></div><div class="field"><label for="line-pieces-${key}">الكمية قطعة</label><input id="line-pieces-${key}" class="line-pieces line-quantity" inputmode="decimal" value="${esc(legacy?line.quantity:line?.quantityPieces??0)}" required></div><div class="field"><label for="line-unit-${key}">الوحدة</label><input id="line-unit-${key}" class="line-unit" value="${esc(line?.unit || 'قطعة')}" required maxlength="30"></div><div class="field"><label for="line-carton-price-${key}">سعر الكارتون · د.ع</label><input id="line-carton-price-${key}" class="line-carton-price" inputmode="numeric" value="${esc(line?.priceCarton ?? 0)}" required></div><div class="field"><label for="line-price-${key}">سعر القطعة · د.ع</label><input id="line-price-${key}" class="line-piece-price line-price" inputmode="numeric" value="${esc(legacy?line.price:line?.pricePiece??'')}" required></div></div><div class="invoice-line-footer"><span>المبلغ الكلي: <strong class="number line-total">—</strong> د.ع</span><button type="button" class="text-link" data-action="invoice-line-remove" aria-label="إزالة المادة من القائمة">إزالة</button></div></div>`;
}
function readInvoiceLines(form, next = null, supplierId = drawer.supplierId) {
  const catalog = (next || state).materials;
  return [...form.querySelectorAll('.invoice-line')].map(row => {
    const name = row.querySelector('.line-name-input').value.trim(), unit = row.querySelector('.line-unit').value.trim();
    if (!name || !unit) throw new Error('اكتب اسم كل مادة ووحدة قياسها.');
    const quantityCartons = M.nonnegativeQuantity(row.querySelector('.line-cartons').value), quantityPieces = M.nonnegativeQuantity(row.querySelector('.line-pieces').value), priceCarton = M.numeric(row.querySelector('.line-carton-price').value), pricePiece = M.numeric(row.querySelector('.line-piece-price').value);
    let m = catalog.find(m => N.latin(m.name).toLowerCase() === N.latin(name).toLowerCase());
    if (!m && next) { m = { id: crypto.randomUUID(), name, unit, priceCarton, pricePiece, archived: false }; catalog.push(m); }
    return { materialId: m?.id || '', name, unit, quantityCartons, quantityPieces, priceCarton, pricePiece };
  });
}
function refreshInvoice() {
  if (drawer?.kind !== 'invoice') return;
  let total = 0, valid = true;
  for (const row of host.querySelectorAll('.invoice-line')) { try { const amount = M.lineTotal({ quantityCartons: row.querySelector('.line-cartons').value, quantityPieces: row.querySelector('.line-pieces').value, priceCarton: M.numeric(row.querySelector('.line-carton-price').value), pricePiece: M.numeric(row.querySelector('.line-piece-price').value) }); row.querySelector('.line-total').textContent = fmt(amount); total += amount; } catch { valid = false; row.querySelector('.line-total').textContent = '—'; } }
  const inv = invoiceById(drawer.id), date = document.getElementById('date').value; const old = M.validDate(date) ? M.balanceBefore(state, drawer.supplierId, date, drawer.createdAt, drawer.id) : 0;
  let paid = inv ? M.invoicePaid(state, inv.id) : 0; if (!inv) try { paid = M.numeric(document.getElementById('amount').value); } catch { valid = false; }
  if (!inv) {
    const debt = Math.max(0, M.debtAvailable(state, drawer.supplierId, date)), split = { invoiceAmount: Math.min(paid, total), debtAmount: Math.max(0, paid - total) };
    if (valid && split.debtAmount <= debt) showPaymentSplit('invoice-payment-split', split, M.debtAvailable(state, drawer.supplierId) - split.debtAmount, old + total - paid);
    else { document.getElementById('invoice-payment-split').textContent = valid ? 'التسديد يتجاوز قيمة القائمة والديون المتاحة.' : 'أكمل مبلغ القائمة والتسديد حتى يظهر التوزيع.'; if (split.debtAmount > debt) valid = false; }
  }
  document.getElementById('invoice-total').textContent = valid ? fmt(total) : '—'; document.getElementById('invoice-old-balance').textContent = fmt(old); document.getElementById('invoice-paid').textContent = fmt(paid); document.getElementById('invoice-current-balance').textContent = valid ? fmt(old + total - paid) : '—';
}
function changeInvoiceSupplier(supplierId) {
  const s = supplierById(supplierId); if (!s || drawer?.kind !== 'invoice' || drawer.id) return;
  drawer.supplierId = s.id;
  document.getElementById('supplier-materials').innerHTML = state.materials.filter(m=>!m.archived).map(m=>`<option value="${esc(m.name)}">${esc(m.unit)} · كارتون ${fmt(m.priceCarton)} / قطعة ${fmt(m.pricePiece)} د.ع</option>`).join('');
  host.querySelectorAll('.invoice-line').forEach(row=>{row.dataset.materialId='';row.dataset.originalName='';});
  refreshInvoice();
}
function refreshPaymentChoices(reset = false) {
  const s = supplierById(document.getElementById('payment-supplier').value), p = state.payments.find(p => p.id === drawer.id), select = document.getElementById('invoice-id'); drawer.supplierId = s.id;
  const old = !reset ? drawer.invoiceId : null;
  const choices = []; if (M.openingDue(state, s.id) > 0 || (p?.supplierId === s.id && p.invoiceId === null)) choices.push({ id: '', label: 'الديون الباقية عليك' });
  for (const i of state.invoices.filter(i => i.supplierId === s.id && (M.invoiceDue(state, i.id) > 0 || p?.invoiceId === i.id))) choices.push({ id: i.id, label: `قائمة ${i.number} · ${shortDate(i.date)}` });
  select.innerHTML = choices.length ? choices.map(i => `<option value="${i.id}" ${i.id === (old || '') ? 'selected' : ''}>${esc(i.label)}</option>`).join('') : '<option value="">ماكو دين متبقي لهذا المورد</option>';
  if (reset) document.getElementById('expense-category').value = s.categoryId;
  refreshPaymentAvailable(reset || !p);
}
function paymentSplitPanel(id) { return `<div id="${id}" class="note-box payment-split" role="status" aria-live="polite"></div>`; }
function showPaymentSplit(id, split, debtLeft, draftBalance) {
  const el = document.getElementById(id); if (!el) return;
  const p = state.payments.find(x => x.id === drawer?.id), supplierId = drawer?.supplierId || selectedSupplier, date = document.getElementById('date')?.value || selectedDate, current = M.balanceBefore(state, supplierId, date, p?.createdAt || new Date().toISOString(), p?.id || null), paid = split.invoiceAmount + split.debtAmount;
  el.textContent = `تاريخ الوصل: ${date} · المبلغ: ${fmt(paid)} د.ع. (للقائمة ${fmt(split.invoiceAmount)} · للديون ${fmt(split.debtAmount)}). بعد الوصل يبقى عليك للمورد: ${fmt(draftBalance ?? (current-paid))} د.ع.`;
}
function refreshPaymentAvailable(fillAmount = false) {
  const supplierId = document.getElementById('payment-supplier').value, invoiceId = document.getElementById('invoice-id').value || null, date = document.getElementById('date').value;
  const other = { ...state, payments: state.payments.filter(p => p.id !== drawer.id) };
  const due = invoiceId ? M.invoiceDue(other, invoiceId) : 0, debt = Math.max(0, M.debtAvailable(other, supplierId, date));
  document.getElementById('payment-invoice-due').textContent = invoiceId ? `المتبقي من القائمة: ${fmt(due)} د.ع` : 'التسديد للديون فقط.';
  document.getElementById('payment-debt-due').textContent = `الديون المتاحة: ${fmt(debt)} د.ع`;
  document.getElementById('payment-available').textContent = fmt(due + debt);
  if (fillAmount) { document.getElementById('amount').value = N.format(Math.max(0, invoiceId ? due : debt)); refreshFundingTotal(); }
  try { const split = M.splitPayment(state, supplierId, invoiceId, M.numeric(document.getElementById('amount').value), date, drawer.id); showPaymentSplit('payment-split', split, M.debtAvailable(other, supplierId) - split.debtAmount); }
  catch (error) { document.getElementById('payment-split').textContent = error.message; }
}
function supplierSubmit(next, context, values, form) {
  const now = new Date().toISOString();
  if (context.kind === 'supplier') {
    const old = next.suppliers.find(s => s.id === context.id);
    const s = { id: context.id || crypto.randomUUID(), name: String(values.get('supplier-name')).trim(), phone: String(values.get('phone')).trim(), note: String(values.get('note')).trim(), openingBalance: M.numeric(values.get('amount')), categoryId: values.get('categoryId'), materials: old?.materials || [] };
    s.archived = values.has('archived'); replaceRecord(next.suppliers, s); context.resultSupplier = s.id; return 'تم حفظ المورد';
  }
  if (context.kind === 'debt') {
    const old = next.debts.find(d => d.id === context.id);
    const d = { id: context.id || crypto.randomUUID(), supplierId: context.supplierId, amount: M.numeric(values.get('amount'), { positive: true }), date: values.get('date'), note: String(values.get('note')).trim(), createdAt: old?.createdAt || now };
    next.debts = next.debts.filter(d => d.id !== context.id); next.debts.push(d); return 'تم حفظ الدين وتحديث حساب المورد';
  }
  if (context.kind === 'material') {
    const old = next.materials.find(m => m.id === context.id), name = String(values.get('material-name')).trim();
    if (next.materials.some(m => m.id !== context.id && N.latin(m.name).toLowerCase() === N.latin(name).toLowerCase())) throw new Error('اسم المادة موجود بالقائمة المشتركة.');
    const m = { id: context.id || crypto.randomUUID(), name, unit: String(values.get('unit')).trim(), priceCarton: M.numeric(values.get('amount')), pricePiece: M.numeric(values.get('piece-price')), archived: values.has('archived') };
    replaceRecord(next.materials, m); return old ? 'تم تحديث المادة وأسعارها لكل الموردين' : 'تمت إضافة المادة للقائمة المشتركة';
  }
  if (context.kind === 'invoice') {
    const number = N.latin(values.get('invoice-number')).trim();
    if (next.invoices.some(i => i.id !== context.id && i.supplierId === context.supplierId && N.latin(i.number) === number)) throw new Error('رقم القائمة موجود لهذا المورد.');
    const inv = { id: context.id || crypto.randomUUID(), supplierId: context.supplierId, number, date: values.get('date'), createdAt: context.createdAt, lines: readInvoiceLines(form, next, context.supplierId), note: String(values.get('note')).trim() };
    next.invoices = next.invoices.filter(i => i.id !== context.id); next.invoices.push(inv);
    if (!context.id) { const paid = M.numeric(values.get('amount')); if (paid > 0) { const split = M.splitPayment(next, inv.supplierId, inv.id, paid, inv.date); const s = next.suppliers.find(s => s.id === inv.supplierId); next.payments.push({ id: crypto.randomUUID(), supplierId: inv.supplierId, invoiceId: inv.id, categoryId: s.categoryId, date: inv.date, amount: paid, ...split, funding: readPaymentFunding(values, paid), note: '', createdAt: now }); } }
    return context.id ? 'تم تعديل القائمة' : 'تم حفظ القائمة وموادها';
  }
  const old = next.payments.find(p => p.id === context.id), amount = M.numeric(values.get('amount'), { positive: true });
  const p = { id: context.id || crypto.randomUUID(), supplierId: values.get('supplierId'), invoiceId: values.get('invoiceId') || null, date: values.get('date'), categoryId: values.get('categoryId'), amount, ...M.splitPayment(next, values.get('supplierId'), values.get('invoiceId') || null, amount, values.get('date'), context.id), funding: readPaymentFunding(values, amount), note: String(values.get('note')).trim(), createdAt: old?.createdAt || now };
  next.payments = next.payments.filter(p => p.id !== context.id); next.payments.push(p); return 'تم حفظ التسديد وتحديث الأرصدة';
}
function readPaymentFunding(values, amount) {
  const source = values.get('paymentSource'), dailyAmount = source === 'daily' ? amount : source === 'cash' ? 0 : M.numeric(values.get('dailyAmount')), cashAmount = source === 'cash' ? amount : source === 'daily' ? 0 : M.numeric(values.get('cashAmount'));
  return M.allocation(amount, { source, dailyAmount, cashAmount });
}
function supplierAction(action, el) {
  if (action === 'supplier-select') { selectedSupplier = el.dataset.id; render(); return true; }
  if (action === 'supplier-tab') { supplierTab = el.dataset.tab; render(); return true; }
  if (action === 'supplier-new' || action === 'supplier-edit') { openDrawer('supplier', action === 'supplier-edit' ? el.dataset.id : null); return true; }
  if (action === 'debt-new' || action === 'debt-edit') { openDrawer('debt', action === 'debt-edit' ? el.dataset.id : null); return true; }
  if (action === 'material-new' || action === 'material-edit') { openDrawer('material', action === 'material-edit' ? el.dataset.id : null); return true; }
  if (action === 'invoice-new' || action === 'invoice-edit') { openDrawer('invoice', action === 'invoice-edit' ? el.dataset.id : null); return true; }
  if (action === 'payment-new' || action === 'payment-edit' || action === 'invoice-pay') { const inv = action === 'invoice-pay' ? invoiceById(el.dataset.id) : null; openDrawer('payment', action === 'payment-edit' ? el.dataset.id : null, inv ? { supplierId: inv.supplierId, invoiceId: inv.id } : {}); return true; }
  if (action === 'invoice-line-add') { if (host.querySelectorAll('.invoice-line').length >= 200) { formError('وصلت للحد الأقصى: 200 مادة بالقائمة.'); return true; } document.getElementById('invoice-lines').insertAdjacentHTML('beforeend', invoiceLine(null)); enhanceInvoiceLine(document.getElementById('invoice-lines').lastElementChild); N.formatInputs(host); refreshInvoice(); document.getElementById('invoice-lines').lastElementChild.querySelector('input').focus(); return true; }
  if (action === 'invoice-line-remove') { el.closest('.invoice-line').remove(); refreshInvoice(); return true; }
  if (action === 'confirm-delete' && ['invoice', 'payment', 'debt'].includes(drawer?.kind)) return (async () => {
    const next = structuredClone(state);
    if (drawer.kind === 'invoice') { if (next.payments.some(p => p.invoiceId === drawer.id)) { formError('القائمة بيها تسديدات. احذف تسديداتها أولاً حتى ترجع مبالغها لأرصدة الدفع.'); return true; } next.invoices = next.invoices.filter(i => i.id !== drawer.id); }
    else if (drawer.kind === 'debt') next.debts = next.debts.filter(d => d.id !== drawer.id);
    else next.payments = next.payments.filter(p => p.id !== drawer.id);
    if (await commit(next, 'تم حذف السجل وتحديث الأرصدة · تگدر تتراجع بـ ⌘Z')) closeDrawer(); return true;
  })();
  return false;
}
document.addEventListener('input', event => {
  if (event.target.id === 'supplier-search') { supplierQuery = event.target.value; document.getElementById('supplier-list').innerHTML = supplierList(); }
  if (drawer?.kind === 'invoice') refreshInvoice();
  if (drawer?.kind === 'payment' && ['amount', 'date'].includes(event.target.id)) refreshPaymentAvailable();
});
document.addEventListener('change', event => {
  if (drawer?.kind === 'invoice' && event.target.classList.contains('line-name-input')) { const m = state.materials.find(m => !m.archived && N.latin(m.name).toLowerCase() === N.latin(event.target.value.trim()).toLowerCase()); if (m) { const row = event.target.closest('.invoice-line'); row.dataset.materialId = m.id; row.dataset.originalName = m.name; row.querySelector('.line-carton-price').value = N.format(m.priceCarton); row.querySelector('.line-piece-price').value = N.format(m.pricePiece); row.querySelector('.line-unit').value = m.unit; } refreshInvoice(); }
  if (drawer?.kind === 'invoice' && event.target.id === 'date') refreshInvoice();
  if (drawer?.kind === 'payment' && event.target.id === 'payment-supplier') refreshPaymentChoices(true);
  if (drawer?.kind === 'payment' && event.target.id === 'invoice-id') refreshPaymentAvailable(true);
  if (drawer?.kind === 'payment' && event.target.id === 'date') refreshPaymentAvailable();
});
