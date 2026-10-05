'use strict';
let selectedSupplier = null, supplierTab = 'invoices', supplierQuery = '', invoiceRowId = 0;
const supplierById = id => state.suppliers.find(s => s.id === id);
const invoiceById = id => state.invoices.find(i => i.id === id);
const supplierOptions = id => state.suppliers.map(s => `<option value="${s.id}" ${s.id === id ? 'selected' : ''}>${esc(s.name)}</option>`).join('');
const expenseCategorySelect = id => `<div class="field"><label for="expense-category">خانة المصروف عند التسديد</label><select id="expense-category" name="categoryId">${state.categories.map(c => `<option value="${c.id}" ${c.id === id ? 'selected' : ''}>${esc(c.name)}</option>`).join('')}</select></div>`;
function supplierEmpty(title, description, label, action) { return `<div class="empty-state supplier-empty"><h3>${title}</h3><p>${description}</p>${button(label, action, true, 'plus')}</div>`; }
function suppliersPage() {
  if (!supplierById(selectedSupplier)) selectedSupplier = state.suppliers[0]?.id || null;
  const supplier = supplierById(selectedSupplier);
  return header('كل مورد، حسابه مرتب.', 'قوائم ومواد محفوظة، وتسديدات مرتبطة بالمصاريف.', button('إضافة مورد', 'supplier-new', true, 'plus'), 'الموردون / الحسابات') + (supplier ? `<div class="supplier-workspace"><aside class="supplier-index"><div class="supplier-index-head"><h2>الموردون</h2><span class="badge">${fmt(state.suppliers.length)}</span></div><label class="sr-only" for="supplier-search">ابحث عن مورد</label><input id="supplier-search" type="search" placeholder="ابحث عن مورد…" value="${esc(supplierQuery)}" class="supplier-search"><div id="supplier-list" class="supplier-list">${supplierList()}</div></aside><section class="supplier-detail">${supplierDetail(supplier)}</section></div>` : supplierEmpty('ابدأ بأول مورد.', 'سجّل اسمه والدين القديم، ثم أضف قوائمه ومواده.', 'إضافة مورد', 'supplier-new'));
}
function supplierList() {
  const suppliers = state.suppliers.filter(s => s.name.toLowerCase().includes(supplierQuery.trim().toLowerCase()));
  return suppliers.length ? suppliers.map(s => `<button class="supplier-choice ${selectedSupplier === s.id ? 'selected' : ''}" data-action="supplier-select" data-id="${s.id}" aria-pressed="${selectedSupplier === s.id}"><strong>${esc(s.name)}</strong><span>${num(M.supplierBalance(state, s.id))}<small>د.ع متبقي</small></span></button>`).join('') : '<p class="empty-help">ماكو مورد بهذا الاسم.</p>';
}
function supplierDetail(s) {
  const invoices = state.invoices.filter(i => i.supplierId === s.id).sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
  const payments = state.payments.filter(p => p.supplierId === s.id), balance = M.supplierBalance(state, s.id);
  let body;
  if (supplierTab === 'materials') body = `<section class="panel supplier-body"><div class="section-head"><div><h2>المواد الدائمية</h2><p class="section-description">السعر الافتراضي يتعبّى بالقائمة وتگدر تغيّره.</p></div><button class="button small" data-action="material-new">+ إضافة مادة</button></div>${s.materials.length ? `<div class="table-scroll"><table class="supplier-table materials-table"><thead><tr><th>المادة</th><th>الوحدة</th><th>سعر الوحدة · د.ع</th><th>تعديل</th></tr></thead><tbody>${s.materials.map(m => `<tr class="${m.archived ? 'archived-row' : ''}"><td><strong>${esc(m.name)}</strong>${m.archived ? '<small class="funding-note">متوقفة للقوائم الجديدة</small>' : ''}</td><td>${esc(m.unit)}</td><td>${num(m.price)}</td><td><button class="icon-button" data-action="material-edit" data-id="${m.id}" aria-label="تعديل مادة ${esc(m.name)}">${icon('edit')}</button></td></tr>`).join('')}</tbody></table></div>` : supplierEmpty('مواد تختارها بكل مرة.', 'أضف اسم المادة وسعرها، أو اكتبها بأول قائمة وتنحفظ تلقائياً.', 'إضافة مادة', 'material-new')}</section>`;
  else if (supplierTab === 'ledger') body = supplierLedgerPanel(s);
  else body = `<section class="panel supplier-body"><div class="section-head"><h2>قوائم ${esc(s.name)}</h2><button class="button small" data-action="invoice-new">+ قائمة جديدة</button></div>${invoices.length ? `<div class="table-scroll"><table class="supplier-table"><thead><tr><th>رقم القائمة / التاريخ</th><th>قيمة القائمة</th><th>التسديد</th><th>المتبقي منها</th><th>إجراءات</th></tr></thead><tbody>${invoices.map(i => { const due = M.invoiceDue(state, i.id); return `<tr><td><strong>${esc(i.number)}</strong><small>${esc(shortDate(i.date))} · ${fmt(i.lines.length)} مادة</small></td><td>${num(M.invoiceTotal(i))}</td><td>${num(M.invoicePaid(state, i.id))}</td><td>${num(due)}${due === 0 ? '<small class="paid-label">مسددة بالكامل</small>' : ''}</td><td><div class="row-actions"><button class="icon-button" data-action="invoice-edit" data-id="${i.id}" aria-label="تفاصيل وتعديل القائمة ${esc(i.number)}">${icon('edit')}</button><button class="text-link" data-action="invoice-pay" data-id="${i.id}" ${due === 0 ? 'disabled' : ''}>تسديد</button></div></td></tr>`; }).join('')}</tbody></table></div>` : supplierEmpty('أول قائمة، بداية سجل واضح.', 'رقم القائمة، المواد، الكميات والسعر. التسديد الآن أو بعدين.', 'إضافة قائمة', 'invoice-new')}</section>`;
  return `<div class="supplier-detail-head"><div><p class="eyebrow">حساب المورد</p><h2>${esc(s.name)}</h2>${s.phone ? `<p class="supplier-contact" dir="auto">${esc(s.phone)}</p>` : ''}${s.note ? `<p class="supplier-note">${esc(s.note)}</p>` : ''}</div><div class="header-actions"><button class="button small" data-action="supplier-edit" data-id="${s.id}">تعديل المورد</button><button class="button primary small" data-action="payment-new" ${balance <= 0 ? 'disabled' : ''}>تسجيل تسديد</button></div></div><div class="supplier-summary"><div><p class="summary-label">الرصيد القديم عند البدء</p>${num(s.openingBalance, 'summary-value')}<span class="unit">د.ع</span></div><div><p class="summary-label">مجموع التسديدات</p>${num(payments.reduce((n, p) => n + p.amount, 0), 'summary-value')}<span class="unit">د.ع</span></div><div><p class="summary-label">الرصيد الحالي عليك</p>${num(balance, 'summary-value')}<span class="unit">د.ع</span></div></div><nav class="supplier-tabs" aria-label="تفاصيل المورد">${[['invoices', 'القوائم'], ['materials', 'المواد الدائمية'], ['ledger', 'كشف الحساب']].map(([key, label]) => `<button data-action="supplier-tab" data-tab="${key}" class="${supplierTab === key ? 'active' : ''}" aria-current="${supplierTab === key ? 'page' : 'false'}">${label}</button>`).join('')}</nav>${body}`;
}
function supplierLedgerPanel(s) {
  const events = M.supplierLedger(state, s.id).reverse();
  return `<section class="panel supplier-body"><div class="section-head"><h2>كشف الحساب</h2><span class="badge">القديم + القائمة − التسديد</span></div><div class="table-scroll"><table class="supplier-table"><thead><tr><th>التاريخ / الحركة</th><th>الرصيد القديم</th><th>القائمة / التسديد</th><th>الرصيد الحالي</th><th>تعديل</th></tr></thead><tbody>${events.map(e => `<tr><td><strong>${e.type === 'invoice' ? 'قائمة ' + esc(e.number) : 'تسديد ' + esc(e.invoiceId ? invoiceById(e.invoiceId)?.number || '' : 'الرصيد القديم')}</strong><small>${esc(shortDate(e.date))}</small></td><td>${num(e.before)}</td><td><span class="badge ${e.type === 'payment' ? '' : 'out'}">${e.type === 'payment' ? '−' : '+'} ${num(e.amount)}</span></td><td>${num(e.balance)}</td><td><button class="icon-button" data-action="${e.type === 'invoice' ? 'invoice-edit' : 'payment-edit'}" data-id="${e.id}" aria-label="تعديل ${e.type === 'invoice' ? 'القائمة' : 'التسديد'}">${icon('edit')}</button></td></tr>`).join('')}<tr><td><strong>الرصيد الافتتاحي</strong></td><td>—</td><td>${num(s.openingBalance)}</td><td>${num(s.openingBalance)}</td><td></td></tr></tbody></table></div></section>`;
}
function paymentsPage() {
  const payments = [...state.payments].sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
  return header('التسديد، بمحله الصحيح.', 'كل دفعة مرتبطة بالمورد والقائمة ومصدر الدفع.', state.suppliers.length ? button('تسجيل تسديد', 'payment-new', true, 'plus') : '', 'الموردون / التسديدات') + `<section class="panel supplier-body">${payments.length ? `<div class="table-scroll"><table class="supplier-table payments-table"><thead><tr><th>المورد / القائمة</th><th>التاريخ</th><th>التسديد · د.ع</th><th>المصدر / الملاحظة</th><th>تعديل</th></tr></thead><tbody>${payments.map(p => `<tr><td><strong>${esc(supplierById(p.supplierId).name)}</strong><small>${p.invoiceId ? 'قائمة ' + esc(invoiceById(p.invoiceId).number) : 'الرصيد القديم'}</small></td><td>${esc(shortDate(p.date))}</td><td>${num(p.amount)}</td><td class="note">${esc(fundingLabel(p))}${p.note ? `<small>${esc(p.note)}</small>` : ''}</td><td><button class="icon-button" data-action="payment-edit" data-id="${p.id}" aria-label="تعديل التسديد">${icon('edit')}</button></td></tr>`).join('')}</tbody></table></div>` : supplierEmpty('الدفعات تنحفظ هنا.', 'ابدأ بمورد وقائمة، وبعدها سجّل التسديد الجزئي أو الكامل.', state.suppliers.length ? 'تسجيل تسديد' : 'إضافة مورد', state.suppliers.length ? 'payment-new' : 'supplier-new')}</section>`;
}
function supplierDrawer(kind, id, options) {
  let title, subtitle, fields, saveLabel = 'حفظ التغيير';
  if (kind === 'supplier') {
    const s = supplierById(id); title = s ? 'تعديل المورد' : 'إضافة مورد'; subtitle = 'اسم المورد ورصيده قبل أول قائمة.';
    fields = `${field('supplier-name', 'اسم المورد', 'text', s?.name || '', 'required maxlength="100"')}${field('phone', 'رقم الهاتف · اختياري', 'text', s?.phone || '', 'maxlength="80"')}${amountField(s?.openingBalance || 0, 'الرصيد القديم عليك')}${expenseCategorySelect(s?.categoryId || 'market')}${noteField(s?.note || '')}<div class="note-box">الرصيد القديم هو الدين السابق. القوائم تزيده والتسديدات تنقصه. التسديد يظهر بالخانة اللي تختارها بالمصاريف اليومية.</div>`;
  } else if (kind === 'material') {
    drawer.supplierId = options.supplierId || selectedSupplier; const s = supplierById(drawer.supplierId); if (!s) throw new Error('اختار مورداً أولاً.'); const m = s.materials.find(m => m.id === id);
    title = m ? 'تعديل المادة' : 'إضافة مادة دائمية'; subtitle = `مواد ${s.name}`;
    fields = `${field('material-name', 'اسم المادة', 'text', m?.name || '', 'required maxlength="100"')}${field('unit', 'وحدة القياس', 'text', m?.unit || 'قطعة', 'required maxlength="30" placeholder="كيلو، كارتون، قطعة…"')}${amountField(m?.price || 0, 'سعر الوحدة الافتراضي')}${m ? `<label class="checkline"><input type="checkbox" name="archived" ${m.archived ? 'checked' : ''}>إيقاف اختيار المادة بالقوائم الجديدة</label>` : ''}<div class="note-box">تعديل الاسم أو السعر هنا ما يغيّر القوائم السابقة. لكل قائمة أسعارها وموادها المحفوظة وقت تسجيلها.</div>`;
  } else if (kind === 'invoice') {
    const inv = invoiceById(id); drawer.supplierId = inv?.supplierId || options.supplierId || selectedSupplier; const s = supplierById(drawer.supplierId); if (!s) throw new Error('اختار مورداً أولاً.'); drawer.createdAt = inv?.createdAt || new Date().toISOString();
    title = inv ? 'تفاصيل وتعديل القائمة' : 'قائمة جديدة'; subtitle = `حساب ${s.name}`; saveLabel = inv ? 'حفظ القائمة' : 'حفظ القائمة والتسديد';
    fields = `<div class="field-row">${field('invoice-number', 'رقم القائمة', 'text', inv?.number || '', 'required maxlength="80"')}${field('date', 'تاريخ القائمة', 'date', inv?.date || selectedDate, 'required')}</div><datalist id="supplier-materials">${s.materials.filter(m => !m.archived).map(m => `<option value="${esc(m.name)}">${esc(m.unit)} · ${fmt(m.price)} د.ع</option>`).join('')}</datalist><div class="invoice-lines-head"><h3>مواد القائمة</h3><button type="button" class="text-link" data-action="invoice-line-add">+ إضافة مادة</button></div><div id="invoice-lines">${(inv?.lines || [null]).map(l => invoiceLine(l)).join('')}</div><p class="invoice-line-hint">اختار مادة محفوظة أو اكتب اسماً جديداً وينحفظ للمورد. الكمية تقبل كسوراً حتى 3 خانات؛ مبلغ المادة يقرّب لأقرب دينار.</p><div class="invoice-totals"><div><span>الرصيد القديم قبل القائمة</span><strong id="invoice-old-balance"></strong></div><div><span>مجموع القائمة · د.ع</span><strong id="invoice-total"></strong></div><div><span>${inv ? 'المسدّد من هذه القائمة' : 'التسديد الآن'}</span><strong id="invoice-paid"></strong></div><div class="invoice-current"><span>الرصيد بعد القائمة وتسديدها</span><strong id="invoice-current-balance"></strong></div></div>${inv ? `<div class="note-box">التسديدات المسجّلة تتعدّل من <strong>كشف الحساب أو التسديدات</strong>. ما تگدر تنزل قيمة القائمة أقل من المسدّد منها.</div>` : amountField('0', 'التسديد الآن · صفر إذا آجل')}${noteField(inv?.note || '')}${inv ? deleteBlock() : fundingFields(null, 'مصدر التسديد')}<div class="note-box">القائمة تسجّل الدين فقط. المصروف ينضاف عند التسديد، حسب مصدر الدفع.</div>`;
  } else if (kind === 'payment') {
    const p = state.payments.find(p => p.id === id); drawer.supplierId = p?.supplierId || options.supplierId || selectedSupplier || state.suppliers[0]?.id; if (!supplierById(drawer.supplierId)) throw new Error('أضف مورداً أولاً.'); drawer.invoiceId = p?.invoiceId ?? options.invoiceId ?? null;
    title = p ? 'تعديل التسديد' : 'تسجيل تسديد'; subtitle = 'تسديد جزئي أو كامل، ومصدره محفوظ.'; saveLabel = 'حفظ التسديد';
    fields = `<div class="field"><label for="payment-supplier">المورد</label><select id="payment-supplier" name="supplierId">${supplierOptions(drawer.supplierId)}</select></div><div class="field"><label for="invoice-id">القائمة / الرصيد القديم</label><select id="invoice-id" name="invoiceId"></select></div><div class="drawer-summary"><p>المتبقي المتاح للتسديد</p><span id="payment-available" class="number"></span><span class="unit">د.ع</span></div>${amountField(p?.amount ?? '', 'مبلغ التسديد')}${field('date', 'تاريخ التسديد', 'date', p?.date || selectedDate, 'required')}${expenseCategorySelect(p?.categoryId || supplierById(drawer.supplierId).categoryId)}${noteField(p?.note || '')}${fundingFields(p, 'مصدر التسديد')}${p ? deleteBlock() : ''}`;
  } else return null;
  return { title, subtitle, fields, saveLabel, wide: kind === 'invoice' };
}
function invoiceLine(line) {
  const key = ++invoiceRowId;
  return `<div class="invoice-line" data-key="${key}" data-material-id="${esc(line?.materialId || '')}" data-original-name="${esc(line?.name || '')}"><div class="invoice-line-fields"><div class="field line-name"><label for="line-name-${key}">المادة</label><input id="line-name-${key}" class="line-name-input" list="supplier-materials" value="${esc(line?.name || '')}" maxlength="100" required autocomplete="off" placeholder="اختار أو اكتب اسم المادة"></div><div class="field"><label for="line-qty-${key}">الكمية</label><input id="line-qty-${key}" class="line-quantity" inputmode="decimal" value="${esc(line?.quantity ?? 1)}" required maxlength="20"></div><div class="field"><label for="line-unit-${key}">الوحدة</label><input id="line-unit-${key}" class="line-unit" value="${esc(line?.unit || 'قطعة')}" required maxlength="30"></div><div class="field"><label for="line-price-${key}">سعر الوحدة</label><input id="line-price-${key}" class="line-price" inputmode="numeric" value="${esc(line?.price ?? '')}" required maxlength="24"></div></div><div class="invoice-line-footer"><span>مبلغ المادة: <strong class="number line-total">—</strong> د.ع</span><button type="button" class="text-link" data-action="invoice-line-remove" aria-label="إزالة المادة من القائمة">إزالة</button></div></div>`;
}
function readInvoiceLines(form, next = null, supplierId = drawer.supplierId) {
  const s = (next || state).suppliers.find(s => s.id === supplierId);
  return [...form.querySelectorAll('.invoice-line')].map(row => {
    const name = row.querySelector('.line-name-input').value.trim(), unit = row.querySelector('.line-unit').value.trim();
    if (!name || !unit) throw new Error('اكتب اسم كل مادة ووحدة قياسها.');
    const quantity = M.quantity(row.querySelector('.line-quantity').value), price = M.numeric(row.querySelector('.line-price').value);
    let m = (row.dataset.materialId && name === row.dataset.originalName ? s.materials.find(m => m.id === row.dataset.materialId) : null) || s.materials.find(m => m.name.toLowerCase() === name.toLowerCase());
    if (!m && next) { m = { id: crypto.randomUUID(), name, unit, price, archived: false }; s.materials.push(m); }
    return { materialId: m?.id || '', name, unit, quantity, price };
  });
}
function refreshInvoice() {
  if (drawer?.kind !== 'invoice') return;
  let total = 0, valid = true;
  for (const row of host.querySelectorAll('.invoice-line')) { try { const amount = M.lineTotal({ quantity: row.querySelector('.line-quantity').value, price: M.numeric(row.querySelector('.line-price').value) }); row.querySelector('.line-total').textContent = fmt(amount); total += amount; } catch { valid = false; row.querySelector('.line-total').textContent = '—'; } }
  const inv = invoiceById(drawer.id), date = document.getElementById('date').value; const old = M.validDate(date) ? M.balanceBefore(state, drawer.supplierId, date, drawer.createdAt, drawer.id) : 0;
  let paid = inv ? M.invoicePaid(state, inv.id) : 0; if (!inv) try { paid = M.numeric(document.getElementById('amount').value); } catch { valid = false; }
  document.getElementById('invoice-total').textContent = valid ? fmt(total) : '—'; document.getElementById('invoice-old-balance').textContent = fmt(old); document.getElementById('invoice-paid').textContent = fmt(paid); document.getElementById('invoice-current-balance').textContent = valid ? fmt(old + total - paid) : '—';
}
function refreshPaymentChoices(reset = false) {
  const s = supplierById(document.getElementById('payment-supplier').value), p = state.payments.find(p => p.id === drawer.id), select = document.getElementById('invoice-id'); drawer.supplierId = s.id;
  const old = !reset ? drawer.invoiceId : null;
  const choices = []; if (M.openingDue(state, s.id) > 0 || (p?.supplierId === s.id && p.invoiceId === null)) choices.push({ id: '', label: 'الرصيد القديم' });
  for (const i of state.invoices.filter(i => i.supplierId === s.id && (M.invoiceDue(state, i.id) > 0 || p?.invoiceId === i.id))) choices.push({ id: i.id, label: `قائمة ${i.number} · ${shortDate(i.date)}` });
  select.innerHTML = choices.length ? choices.map(i => `<option value="${i.id}" ${i.id === (old || '') ? 'selected' : ''}>${esc(i.label)}</option>`).join('') : '<option value="">ماكو دين متبقي لهذا المورد</option>';
  if (reset) document.getElementById('expense-category').value = s.categoryId;
  refreshPaymentAvailable(reset || !p);
}
function refreshPaymentAvailable(fillAmount = false) {
  const supplierId = document.getElementById('payment-supplier').value, invoiceId = document.getElementById('invoice-id').value || null, p = state.payments.find(p => p.id === drawer.id);
  let available = invoiceId ? M.invoiceDue(state, invoiceId) : M.openingDue(state, supplierId);
  if (p?.supplierId === supplierId && p.invoiceId === invoiceId) available += p.amount;
  document.getElementById('payment-available').textContent = fmt(available || 0);
  if (fillAmount) { document.getElementById('amount').value = Math.max(0, available || 0); refreshFundingTotal(); }
}
function supplierSubmit(next, context, values, form) {
  const now = new Date().toISOString();
  if (context.kind === 'supplier') {
    const old = next.suppliers.find(s => s.id === context.id);
    const s = { id: context.id || crypto.randomUUID(), name: String(values.get('supplier-name')).trim(), phone: String(values.get('phone')).trim(), note: String(values.get('note')).trim(), openingBalance: M.numeric(values.get('amount')), categoryId: values.get('categoryId'), materials: old?.materials || [] };
    next.suppliers = next.suppliers.filter(x => x.id !== context.id); next.suppliers.push(s); context.resultSupplier = s.id; return 'تم حفظ المورد';
  }
  if (context.kind === 'material') {
    const s = next.suppliers.find(s => s.id === context.supplierId), m = { id: context.id || crypto.randomUUID(), name: String(values.get('material-name')).trim(), unit: String(values.get('unit')).trim(), price: M.numeric(values.get('amount')), archived: values.has('archived') };
    s.materials = s.materials.filter(x => x.id !== context.id); s.materials.push(m); return 'تم حفظ المادة للمورد';
  }
  if (context.kind === 'invoice') {
    const inv = { id: context.id || crypto.randomUUID(), supplierId: context.supplierId, number: String(values.get('invoice-number')).trim(), date: values.get('date'), createdAt: context.createdAt, lines: readInvoiceLines(form, next, context.supplierId), note: String(values.get('note')).trim() };
    next.invoices = next.invoices.filter(i => i.id !== context.id); next.invoices.push(inv);
    if (!context.id) { const paid = M.numeric(values.get('amount')); if (paid > 0) { if (paid > M.invoiceTotal(inv)) throw new Error('التسديد الآن أكبر من قيمة القائمة. لتسديد دين قديم، سجّل له دفعة مستقلة.'); const s = next.suppliers.find(s => s.id === inv.supplierId); next.payments.push({ id: crypto.randomUUID(), supplierId: inv.supplierId, invoiceId: inv.id, categoryId: s.categoryId, date: inv.date, amount: paid, funding: readPaymentFunding(values, paid), note: '', createdAt: now }); } }
    return context.id ? 'تم تعديل القائمة' : 'تم حفظ القائمة وموادها';
  }
  const old = next.payments.find(p => p.id === context.id), amount = M.numeric(values.get('amount'), { positive: true });
  const p = { id: context.id || crypto.randomUUID(), supplierId: values.get('supplierId'), invoiceId: values.get('invoiceId') || null, date: values.get('date'), categoryId: values.get('categoryId'), amount, funding: readPaymentFunding(values, amount), note: String(values.get('note')).trim(), createdAt: old?.createdAt || now };
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
  if (action === 'material-new' || action === 'material-edit') { openDrawer('material', action === 'material-edit' ? el.dataset.id : null); return true; }
  if (action === 'invoice-new' || action === 'invoice-edit') { openDrawer('invoice', action === 'invoice-edit' ? el.dataset.id : null); return true; }
  if (action === 'payment-new' || action === 'payment-edit' || action === 'invoice-pay') { const inv = action === 'invoice-pay' ? invoiceById(el.dataset.id) : null; openDrawer('payment', action === 'payment-edit' ? el.dataset.id : null, inv ? { supplierId: inv.supplierId, invoiceId: inv.id } : {}); return true; }
  if (action === 'invoice-line-add') { if (host.querySelectorAll('.invoice-line').length >= 200) { formError('وصلت للحد الأقصى: 200 مادة بالقائمة.'); return true; } document.getElementById('invoice-lines').insertAdjacentHTML('beforeend', invoiceLine(null)); refreshInvoice(); document.getElementById('invoice-lines').lastElementChild.querySelector('input').focus(); return true; }
  if (action === 'invoice-line-remove') { el.closest('.invoice-line').remove(); refreshInvoice(); return true; }
  if (action === 'confirm-delete' && ['invoice', 'payment'].includes(drawer?.kind)) return (async () => {
    const next = structuredClone(state);
    if (drawer.kind === 'invoice') { if (next.payments.some(p => p.invoiceId === drawer.id)) { formError('القائمة بيها تسديدات. احذف تسديداتها أولاً حتى ترجع مبالغها لأرصدة الدفع.'); return true; } next.invoices = next.invoices.filter(i => i.id !== drawer.id); }
    else next.payments = next.payments.filter(p => p.id !== drawer.id);
    if (await commit(next, 'تم حذف السجل وتحديث الأرصدة · تگدر تتراجع بـ ⌘Z')) closeDrawer(); return true;
  })();
  return false;
}
document.addEventListener('input', event => {
  if (event.target.id === 'supplier-search') { supplierQuery = event.target.value; document.getElementById('supplier-list').innerHTML = supplierList(); }
  if (drawer?.kind === 'invoice') refreshInvoice();
});
document.addEventListener('change', event => {
  if (drawer?.kind === 'invoice' && event.target.classList.contains('line-name-input')) { const s = supplierById(drawer.supplierId), m = s.materials.find(m => !m.archived && m.name.toLowerCase() === event.target.value.trim().toLowerCase()); if (m) { const row = event.target.closest('.invoice-line'); row.querySelector('.line-price').value = m.price; row.querySelector('.line-unit').value = m.unit; } refreshInvoice(); }
  if (drawer?.kind === 'invoice' && event.target.id === 'date') refreshInvoice();
  if (drawer?.kind === 'payment' && event.target.id === 'payment-supplier') refreshPaymentChoices(true);
  if (drawer?.kind === 'payment' && event.target.id === 'invoice-id') refreshPaymentAvailable(true);
});
