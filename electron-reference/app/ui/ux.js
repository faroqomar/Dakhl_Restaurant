'use strict';
// Shared interaction rules: preserve context, make state visible, keep all entry forms in pop-out dialogs.
let saveMessage = 'محفوظ على جهازك', saveError = false, previousFocusKey = null, settingsBaseline = '', lastDraftDay = '', backupInfo = null;
let inventoryFilter = { status: 'active', group: '' }, materialsFilter = { query: '', status: 'active' }, paymentsFilter = { query: '', from: '', to: '', supplierId: '' }, cashFilter = { from: '', to: '', kind: '' };
const pageNumbers = {}, pageCounts = {}, pageSizes = {};
let retrySave = null;
let compactCatalog = false, invalidEntryField = null;
try { compactCatalog = localStorage.getItem('daftar.catalog-compact') === 'true'; } catch {}
function refreshListPager(list,key,count) {
  pageCounts[key]=count;
  let slot=document.getElementById(key+'-pagination');
  if(!slot){slot=document.createElement('div');slot.id=key+'-pagination';list.after(slot);}
  slot.innerHTML=pager(key);
}
function enhanceInvoiceLine(row) {
  if(row.querySelector('details'))return;
  const details=document.createElement('details');details.className='invoice-line-details';
  details.open=Number(row.querySelector('.line-cartons').value)>0;
  details.innerHTML='<summary>كارتون / وحدة القياس</summary><div class="field-row"></div>';
  for(const selector of ['.line-cartons','.line-carton-price','.line-unit'])details.querySelector('.field-row').append(row.querySelector(selector).closest('.field'));
  row.querySelector('.invoice-line-fields').after(details);
}
function validateEntryFields(form) {
  invalidEntryField=null;
  for(const el of form.querySelectorAll('input,textarea,select')) {
    if(el.disabled||el.type==='checkbox')continue;
    try {
      if(el.required&&!el.value.trim())throw Error('أكمل القيمة المطلوبة.');
      if(el.type==='date'&&el.value&&!M.validDate(el.value))throw Error('اختار تاريخاً صحيحاً.');
      if(el.value&&el.inputMode==='decimal')M.nonnegativeQuantity(el.value);
      if(el.value&&el.inputMode==='numeric')M.numeric(el.value);
    }catch(error){invalidEntryField=el;el.closest('details')?.setAttribute('open','');const label=host.querySelector(`label[for="${el.id}"]`)?.textContent||'القيمة';throw Error('راجع '+label+': '+error.message);}
  }
}
function preserveCorrectionTrail(next) {
  for(const [date,current] of Object.entries(state.days)) {
    if(!current.corrections?.length)continue;
    const target=editableDay(next,date), previous=target.corrections||[];
    target.corrections=structuredClone(current.corrections);
    if(JSON.stringify(previous)!==JSON.stringify(current.corrections))for(const [field,key] of [['balance','balance'],['total','totalOverride']]) {
      if(current[key]!==target[key])target.corrections.push({field,date,before:current[key],after:target[key],reason:'تراجع عن التصحيح السابق',createdAt:new Date().toISOString()});
    }
  }
  return next;
}
function replaceRecord(list, record) { const index = list.findIndex(x => x.id === record.id); if (index < 0) list.push(record); else list[index] = record; }
function arabicCount(n, one, two, many) { return n === 0 ? `0 ${many}` : n === 1 ? one : n === 2 ? two : `${fmt(n)} ${n < 11 ? many : one}`; }
function saleTime(value) { return new Intl.DateTimeFormat('ar-IQ-u-nu-latn', { hour: '2-digit', minute: '2-digit' }).format(new Date(value)); }
function formSignature(root) { return JSON.stringify([...root.querySelectorAll('input,select,textarea')].map(el => [el.id || el.name, el.type === 'checkbox' ? el.checked : el.value])); }
function isDirty() { return Boolean(drawer && !drawer.readonly && drawer.baseline && drawer.baseline !== formSignature(host)) || Boolean(view === 'settings' && settingsBaseline && settingsBaseline !== formSignature(main)); }
function allowLeave() { return !isDirty() || window.confirm('عندك تغييرات غير محفوظة. تتجاهلها؟ اختار إلغاء حتى تكمل التعديل.'); }
function focusKey(el) { if (!el) return null; return { id: el.id, action: el.dataset?.action, record: el.dataset?.id, quantity: el.dataset?.cartQuantity }; }
function restoreFocus(key) {
  if (!key) { main.focus(); return; }
  const target = key.id ? document.getElementById(key.id) : [...document.querySelectorAll('[data-action],[data-cart-quantity]')].find(el => key.quantity ? el.dataset.cartQuantity === key.quantity : el.dataset.action === key.action && el.dataset.id === key.record);
  if (target && !target.disabled && !target.closest('[hidden]')) target.focus(); else (document.getElementById('product-search') || main).focus();
}
function renderWithFocus(id) { const el = document.getElementById(id), start = el?.selectionStart; render(); const fresh = document.getElementById(id); fresh?.focus(); if (start !== null && start !== undefined) fresh?.setSelectionRange?.(start,start); }
function draftKey() { return 'daftar.active-sale:' + directory; }
let heldOrders = [], draftRestored = false, draftStorageUnavailable = false, saleWorkspaceRaw = null, draftStorageConflict = false, draftConflictNotified = false;
function freshSaleDraft(){return {id:crypto.randomUUID(),lines:[],discount:'',note:'',orderType:state.preferences.orderTypes[0],date:M.dateKey()};}
function writeSaleWorkspace(draft,held){try{if(localStorage.getItem(draftKey())!==saleWorkspaceRaw){draftStorageConflict=true;return false;}const raw=JSON.stringify({...draft,heldOrders:held});localStorage.setItem(draftKey(),raw);saleWorkspaceRaw=raw;draftStorageUnavailable=false;draftStorageConflict=false;return true;}catch{draftStorageUnavailable=true;return false;}}
function persistSaleDraft(){const saved=writeSaleWorkspace(saleDraft,heldOrders);if(!saved&&draftStorageConflict&&!draftConflictNotified){draftConflictNotified=true;toast('تغيّرت الطلبات بنافذة ثانية. أكمل من النافذة الثانية، أو أعد فتح هذه النافذة حتى تسترجع آخر نسخة.',true);}return saved;}
function validStoredDraft(draft){return Boolean(draft&&typeof draft.id==='string'&&Array.isArray(draft.lines)&&draft.lines.length<=200&&M.validDate(draft.date)&&draft.lines.every(l=>typeof l.productId==='string'&&Number.isFinite(l.quantity)&&l.quantity>0&&Number.isSafeInteger(l.price)&&l.price>=0));}
function restoreSaleDraft(){
  resetSaleDraftWithoutWrite();heldOrders=[];
  try{const raw=localStorage.getItem(draftKey());saleWorkspaceRaw=raw;if(!raw)return;const stored=JSON.parse(raw);
    if(Array.isArray(stored.heldOrders))heldOrders=stored.heldOrders.filter(o=>o&&typeof o.id==='string'&&typeof o.label==='string'&&typeof o.savedAt==='string'&&Number.isFinite(Date.parse(o.savedAt))&&validStoredDraft(o.draft)&&!state.sales.some(s=>s.id===o.draft.id)).slice(0,40).map(o=>({...o,label:o.label.slice(0,80)}));
    if(validStoredDraft(stored)&&!state.sales.some(s=>s.id===stored.id)){const {heldOrders:ignored,...draft}=stored;saleDraft=draft;draftRestored=Boolean(draft.lines.length);}else persistSaleDraft();
  }catch{draftStorageUnavailable=true;}
}
function resetSaleDraftWithoutWrite(){saleDraft=freshSaleDraft();lastDraftDay=M.dateKey();}
function clearSaleWorkspaceAfterReplacement(){heldOrders=[];resetSaleDraftWithoutWrite();draftRestored=false;draftConflictNotified=false;try{saleWorkspaceRaw=localStorage.getItem(draftKey());}catch{}if(!persistSaleDraft())toast('تم استبدال الحسابات؛ تعذّر مسح مسودات الطلبات القديمة من تخزين الجهاز.',true);}
function pageItems(items, key, size = 50) { pageCounts[key] = items.length; pageSizes[key] = size; const page = pageNumbers[key] = Math.min(Math.max(1, pageNumbers[key] || 1), Math.max(1, Math.ceil(items.length/size))); return items.slice((page-1)*size,page*size); }
function pager(key) { const count = pageCounts[key] || 0, size = pageSizes[key] || 50, page = pageNumbers[key] || 1; if (count <= size) return ''; return `<div class="pagination" role="group" aria-label="صفحات النتائج"><button class="button small" data-action="page-prev" data-key="${key}" ${page===1?'disabled':''}>السابق</button><span>صفحة ${page} من ${Math.ceil(count/size)} · ${fmt(count)} نتيجة</span><button class="button small" data-action="page-next" data-key="${key}" ${page*size>=count?'disabled':''}>التالي</button></div>`; }
function validRange(f) { if ((f.from && !M.validDate(f.from)) || (f.to && !M.validDate(f.to)) || (f.from && f.to && f.from > f.to)) { toast('تاريخ البداية لازم يكون صحيح وقبل تاريخ النهاية.', true); return false; } return true; }
function filterActions(key) { return `<div class="filter-actions"><button class="button primary small" data-action="apply-filter" data-key="${key}">تطبيق التصفية</button><button class="button small" data-action="filter-preset" data-key="${key}" data-period="today">اليوم</button><button class="button small" data-action="filter-preset" data-key="${key}" data-period="month">هذا الشهر</button><button class="button small" data-action="filter-preset" data-key="${key}" data-period="all">مسح / الكل</button></div>`; }
function dateFields(prefix, f) { return `<label>من تاريخ<input id="${prefix}-from" type="date" value="${esc(f.from)}"></label><label>إلى تاريخ<input id="${prefix}-to" type="date" value="${esc(f.to)}"></label>`; }
function inventoryMatches(p,balances) { const n = balances ? balances.get(p.id)||0 : M.stock(state,p.id,M.dateKey()), f = inventoryFilter; return (!f.group || p.group===f.group) && (f.status==='all' || f.status==='archived' ? (f.status==='all'||p.archived) : !p.archived && (f.status==='active'||p.trackStock && (f.status==='low'?n<=p.minStock:n===0))); }
function updateDateWarning() { const el = document.getElementById('sale-date-warning'); if (el) el.innerHTML = saleDraft.date && saleDraft.date !== M.dateKey() ? `<strong>بيع بتاريخ سابق / مختلف: ${esc(saleDraft.date)}</strong> <button class="text-link" data-action="sale-today">الرجوع لليوم</button>` : ''; }
function enhancePage() {
  const titles = { inventory:'المخزن', expenses:'المصاريف اليومية', suppliers:'الموردون', payments:'التسديدات', cash:'القاصة', categories:'الخانات', settings:'الإعدادات والنسخ', 'sale-history':'سجل المبيعات' };
  if (titles[view]) main.querySelector('h1').textContent = titles[view];
  const navigation = document.getElementById('navigation');
  if (!navigation.querySelector('.nav-group')) { for (const [label,keys] of [['البيع والمخزن',['sales','sale-history','inventory']],['المشتريات والموردون',['suppliers','invoices','materials','payments']],['الحسابات',['expenses','statement','cash']],['الإدارة',['categories','settings']]]) { const group=document.createElement('section'); group.className='nav-group'; const heading=document.createElement('h2'); heading.textContent=label; group.append(heading); keys.forEach(key=>group.append(navigation.querySelector(`[data-view="${key}"]`))); navigation.append(group); } }
  status(saveMessage, saveError);
  if (saveError && retrySave) main.querySelector('.shortcut-bar').insertAdjacentHTML('beforeend','<button class="button small" data-action="retry-save">إعادة الحفظ</button>');
  main.querySelectorAll('input[type="search"]').forEach(el=>{if(!el.getAttribute('aria-label')) el.setAttribute('aria-label',el.placeholder||'بحث');});
  const activeFilter=({payments:paymentsFilter,cash:cashFilter,'sale-history':saleFilter})[view];
  if(activeFilter)main.querySelector('.page-header')?.insertAdjacentHTML('afterend',`<p class="filter-summary">الفترة المعروضة: ${esc(activeFilter.from||'البداية')} — ${esc(activeFilter.to||'النهاية')} · ${Object.entries(activeFilter).filter(([k,v])=>!['from','to'].includes(k)&&v).map(([k,v])=>esc(k==='supplierId'?supplierById(v)?.name||v:({completed:'مكتملة',void:'ملغاة',cash:'حركة مباشرة',transfer:'تحويل يومي',expense:'مصروف','supplier-payment':'تسديد مورد'})[v]||v)).join(' · ')||'كل النتائج'} · التغيير بعد تطبيق التصفية</p>`);
  // Context panels become explicit pop-outs; they never compress the workspace.
  const rail = main.querySelector('.cash-rail'); if (rail) { rail.hidden=true; rail.id='cash-context'; main.querySelector('.header-actions').insertAdjacentHTML('beforeend',button('رصيد القاصة','cash-popout')); }
  const supplierIndex=main.querySelector('.supplier-index'); if(supplierIndex) { supplierIndex.hidden=true; main.querySelector('.supplier-detail-head .header-actions').insertAdjacentHTML('afterbegin',button('اختيار مورد','supplier-picker')); }
  if (view==='sales') {
    const date=main.querySelector('.bill-date'); date.insertAdjacentHTML('afterend','<div id="sale-date-warning" role="status"></div>'); updateDateWarning();
    const options=document.createElement('details'); options.className='sale-options'; options.open=Boolean(saleDraft.discount || saleDraft.date!==M.dateKey()); options.innerHTML='<summary>خصم أو تغيير التاريخ</summary>'; const discount=document.getElementById('sale-discount').closest('label'); main.querySelector('.bill-fields').after(options); options.append(date,discount);
    const lastSavedSale=state.sales.find(s=>s.id===lastSaleId);
    if (lastSavedSale) main.querySelector('.pos-heading').insertAdjacentHTML('afterend',`<div class="sale-success" role="status">${lastSavedSale.status==='void'?'تم إلغاء':'تم حفظ'} ${esc(lastSavedSale.number)} <button class="text-link" data-action="sale-receipt" data-id="${lastSaleId}">عرض الوصل</button><button class="text-link" data-action="sale-pdf" data-id="${lastSaleId}">حفظ PDF</button>${lastSavedSale.status==='completed'&&!(state.saleReturns||[]).some(r=>r.saleId===lastSaleId)?`<button class="text-link" data-action="sale-void" data-id="${lastSaleId}">إلغاء البيع</button>`:''}</div>`);
    if(draftRestored) { main.querySelector('.pos-heading').insertAdjacentHTML('afterend','<p class="notice">تمت استعادة فاتورتك غير المكتملة. راجع التاريخ والأسعار قبل تأكيد البيع.</p>'); draftRestored=false; }
    if(draftStorageUnavailable) main.querySelector('.bill-hint').textContent += ' حفظ المسودة غير متاح في هذه المعاينة.';
    main.querySelector('.pos-heading-actions').insertAdjacentHTML('afterbegin',`<button class="button" data-action="catalog-density" aria-pressed="${compactCatalog}">${compactCatalog?'عرض واسع':'عرض مدمج'}</button>`); document.getElementById('product-grid').classList.toggle('compact',compactCatalog);
  }
  if(view==='inventory') {
    main.querySelector('.inventory-filters').insertAdjacentHTML('beforeend',`<label>الحالة<select id="inventory-status">${[['active','النشطة'],['low','تحتاج تزويد'],['out','النافدة'],['archived','الموقوفة'],['all','الكل']].map(([v,l])=>`<option value="${v}" ${inventoryFilter.status===v?'selected':''}>${l}</option>`).join('')}</select></label><label>المجموعة<select id="inventory-group"><option value="">الكل</option>${[...new Set(state.products.map(p=>p.group).filter(Boolean))].map(g=>`<option ${g===inventoryFilter.group?'selected':''}>${esc(g)}</option>`).join('')}</select></label>`);
    const badge=main.querySelector('.inventory-heading .badge'); badge.outerHTML=`<button class="button inventory-low ${inventoryFilter.status==='low'?'active':''}" data-action="inventory-low" aria-pressed="${inventoryFilter.status==='low'}">${badge.textContent}</button>`;
    if(!document.querySelector('.inventory-table') && state.products.length) document.getElementById('inventory-list').innerHTML='<div class="empty-state"><h3>ماكو صنف مطابق</h3><p>غيّر البحث أو الحالة حتى تشوف الأصناف.</p><button class="button" data-action="inventory-reset">مسح التصفية</button></div>';

  }
  if(view==='sale-history') { const f=main.querySelector('.sales-filters'); f.insertAdjacentHTML('beforeend',`<label>الحالة<select id="sales-status"><option value="">الكل</option>${[['completed','مكتملة'],['void','ملغاة']].map(([v,l])=>`<option value="${v}" ${saleFilter.status===v?'selected':''}>${l}</option>`).join('')}</select></label><label>نوع الطلب<select id="sales-order-filter"><option value="">الكل</option>${[...new Set([...state.preferences.orderTypes,...state.sales.map(s=>s.orderType).filter(Boolean)])].map(t=>`<option ${saleFilter.orderType===t?'selected':''}>${esc(t)}</option>`).join('')}</select></label>`); f.insertAdjacentHTML('afterend',filterActions('sales')); f.querySelector('[data-action="sales-filter"]').hidden=true; main.querySelector('.panel').insertAdjacentHTML('beforeend',pager('sales')); addReportButton('sales'); }
  if(view==='statement'||view==='invoices') { main.querySelector('.invoice-filter-fields').insertAdjacentHTML('afterend',filterActions(view)); if(view==='statement') addReportButton('statement'); const f=view==='statement'?statementFilter:invoiceFilter; main.querySelector('.invoice-filters').insertAdjacentHTML('beforeend',`<p class="filter-summary">الفترة المعروضة: ${esc(f.from||'البداية')} — ${esc(f.to||'اليوم الأخير')} · التصفية تتغير بعد التطبيق</p>`); }
  if(view==='payments') { main.querySelector('.panel').insertAdjacentHTML('afterbegin',`<div class="filter-fields"><label>المورد أو الملاحظة<input id="payments-query" type="search" value="${esc(paymentsFilter.query)}"></label>${dateFields('payments',paymentsFilter)}<label>المورد<select id="payments-supplier"><option value="">الكل</option>${state.suppliers.map(s=>`<option value="${s.id}" ${paymentsFilter.supplierId===s.id?'selected':''}>${esc(s.name)}</option>`).join('')}</select></label></div>${filterActions('payments')}`); }
  if(view==='materials') { main.querySelector('.supplier-body').insertAdjacentHTML('afterbegin',`<div class="filter-fields"><label>بحث المواد<input type="search" id="materials-query" value="${esc(materialsFilter.query)}"></label><label>الحالة<select id="materials-status">${[['active','النشطة'],['archived','الموقوفة'],['all','الكل']].map(([v,l])=>`<option value="${v}" ${materialsFilter.status===v?'selected':''}>${l}</option>`).join('')}</select></label><button class="button" data-action="materials-apply">تطبيق</button><button class="button" data-action="materials-reset">مسح</button></div>`); }
  if(view==='expenses') main.querySelector('.header-actions').insertAdjacentHTML('afterbegin',button('مراجعة اليوم','day-review'));
  if(view==='cash') { const panel=main.querySelector('.cash-layout>.panel'); panel.insertAdjacentHTML('afterbegin',`<div class="cash-filter-toolbar"><div class="filter-fields">${dateFields('cash',cashFilter)}<label>نوع الحركة<select id="cash-kind">${[['','الكل'],['cash','حركة مباشرة'],['transfer','تحويل من اليومي'],['expense','مصروف'],['supplier-payment','تسديد مورد']].map(([v,l])=>`<option value="${v}" ${cashFilter.kind===v?'selected':''}>${l}</option>`).join('')}</select></label></div>${filterActions('cash')}</div>`); addReportButton('cash'); }
  if(view==='categories') main.querySelectorAll('.category-item').forEach((row,i)=>{const c=state.categories[i]; row.insertAdjacentHTML('beforeend',`<span>${c.archived?'موقوفة':''}</span>${['samoon','bread','falafel','market'].includes(c.id)?'<small>خانة أصلية محفوظة</small>':`<button class="button small" data-action="category-edit" data-id="${c.id}">تعديل / إيقاف</button>`}`);});
  if(view==='settings') { initializeSettings(); }
  for(const key of ({statement:['statement'],cash:['cash'],payments:['payments'],materials:['materials'],suppliers:['supplier-invoices','supplier-ledger','supplier-debts'],invoices:['price-history']}[view]||[])) main.insertAdjacentHTML('beforeend',pager(key));
  main.querySelectorAll('[data-pager-key]').forEach(el=>el.innerHTML=pager(el.dataset.pagerKey));
}
function enhanceDialog() {
  const contexts={product:'المخزن',stock:'المخزن','stock-history':'المخزن','sale-receipt':'المبيعات','sale-void':'المبيعات',supplier:'الموردون',invoice:'المشتريات',payment:'التسديدات',material:'المواد',debt:'الموردون'};
  host.querySelector('.drawer-top>span').textContent='دفتر / '+(contexts[drawer.kind]||'الحسابات');
  if(drawer.kind==='invoice') { host.querySelectorAll('.invoice-line').forEach(enhanceInvoiceLine); const content=host.querySelector('.form-content'), form=host.querySelector('form'), context=document.createElement('div'); context.className='invoice-context'; const supplier=content.querySelector('#invoice-supplier')?.closest('.field'), date=content.querySelector('.field-row'); if(supplier)context.append(supplier); if(date)context.append(date); form.prepend(context); const totals=content.querySelector('.invoice-totals'); if(totals)host.querySelector('.form-footer').prepend(totals); }
  if(drawer.kind==='product') { toggleStockFields(); }
  if(drawer.kind==='supplier' && drawer.id) { const s=supplierById(drawer.id); host.querySelector('.form-content').insertAdjacentHTML('beforeend',`<label class="checkline"><input name="archived" type="checkbox" ${s.archived?'checked':''}>إيقاف المورد مع الاحتفاظ بسجله</label><p class="hint">يبقى حسابه متاحاً للتسديد والمراجعة. الرصيد الحالي عليك: ${fmt(M.supplierBalance(state,s.id))} د.ع.</p>`); }
  if(['balance','total'].includes(drawer.kind)) { host.querySelector('.form-content').insertAdjacentHTML('beforeend',`${field('correction-reason','سبب التصحيح','text','','required maxlength="500"')}<div id="correction-preview" class="note-box"></div>${correctionHistory()}`); updateCorrectionPreview(); }
  if(['deposit','withdrawal','transaction','remaining-transfer','transfer','remaining'].includes(drawer.kind)) { host.querySelector('.form-content').insertAdjacentHTML('beforeend','<div id="movement-preview" class="note-box" role="status"></div>'); updateMovementPreview(); }
  host.querySelectorAll('input,select,textarea').forEach(el=>el.addEventListener('invalid',()=>{el.closest('details')?.setAttribute('open','');el.setAttribute('aria-invalid','true');el.setAttribute('aria-describedby','form-error');document.getElementById('form-error').textContent='راجع '+(host.querySelector(`label[for="${el.id}"]`)?.textContent||'الحقل المحدد')+'، وأكمل القيمة المطلوبة.';}));
}
function toggleStockFields() { const enabled=document.getElementById('track-stock')?.checked; for(const id of ['opening-quantity','stock-date','min-stock']) {const el=document.getElementById(id);if(el){el.closest('.field').hidden=!enabled;el.disabled=!enabled;el.required=enabled;}} }
function markInvalidField(message) {
  host.querySelectorAll('[aria-invalid]').forEach(el=>el.removeAttribute('aria-invalid'));
  let field = invalidEntryField?.isConnected ? invalidEntryField : [...host.querySelectorAll('input,select,textarea')].find(el=>!el.disabled && el.required && !el.value.trim()); invalidEntryField=null;
  const rules=[[/الخصم/,'sale-discount'],[/التاريخ|تاريخ/,'date'],[/حصة|الحصتين|يساوي/,'daily-amount'],[/كمية|المخزون/,'stock-quantity'],[/مبلغ|المبلغ|صفر|التسديد/,'amount'],[/اسم الصنف/,'product-name'],[/اسم المادة/,'material-name'],[/سبب/,'correction-reason']];
  if(!field) for(const [pattern,id] of rules) if(pattern.test(message) && document.getElementById(id)){field=document.getElementById(id);break;}
  if(field){field.setAttribute('aria-invalid','true');field.setAttribute('aria-describedby','form-error');field.focus();}
}
function correctionHistory() { const d=M.day(state,selectedDate);return `<details><summary>سجل التصحيحات (${(d.corrections||[]).length})</summary>${(d.corrections||[]).slice().reverse().map(c=>`<p>${esc(c.date)} · ${c.field==='total'?'المجموع':'الرصيد'}: ${c.before===null?'تلقائي / غير مسجل':fmt(c.before)} ← ${c.after===null?'تلقائي / غير مسجل':fmt(c.after)} · ${esc(c.reason)}</p>`).join('')||'<p>ماكو تصحيحات مسجلة بعد.</p>'}</details>`; }
function updateCorrectionPreview(){const el=document.getElementById('correction-preview');if(!el)return;try{const d=M.day(state,selectedDate),before=drawer.kind==='total'?M.total(state,selectedDate):d.balance,after=drawer.kind==='total'&&document.getElementById('automatic').checked?M.dailySpent(state,selectedDate):M.numeric(document.getElementById('amount').value,{signed:true});el.textContent=`الحالي ${before===null?'غير مسجل':fmt(before)} · الجديد ${fmt(after)} · الفرق ${fmt(after-(before||0))} د.ع`;}catch{el.textContent='أدخل مبلغاً صحيحاً لمعاينة الفرق.';}}
function recordCorrection(next,context,values){if(!['balance','total'].includes(context.kind))return;const reason=String(values.get('correction-reason')||'').trim();if(!reason)throw new Error('اكتب سبب التصحيح حتى يبقى واضح بالسجل.');const d=editableDay(next,selectedDate),key=context.kind==='total'?'totalOverride':'balance';d.corrections=d.corrections||[];d.corrections.push({field:context.kind,date:selectedDate,before:M.day(state,selectedDate)[key],after:d[key],reason,createdAt:new Date().toISOString()});}
function updateMovementPreview(){const el=document.getElementById('movement-preview');if(!el)return;try{const amount=M.numeric(document.getElementById('amount').value,{positive:false}),old=state.transactions.find(t=>t.id===drawer.id),transfer=state.transfers.find(t=>t.id===drawer.id);if(drawer.kind==='remaining'){el.textContent=`الرصيد الكلي بعد تسجيل الباقي: ${fmt(M.total(state,selectedDate)+amount+M.transferred(state,selectedDate))} د.ع. يشمل مجموع حصص اليومي فقط.`;}else if(['remaining-transfer','transfer'].includes(drawer.kind)){el.textContent=`من اليومي إلى القاصة · اليومي بعد التحويل ${fmt((M.remaining(state,drawer.originalDate)||0)+(transfer?.amount||0)-amount)} · القاصة بعده ${fmt(M.cash(state)-(transfer?.amount||0)+amount)} د.ع`;}else{const type=document.getElementById('type')?.value||drawer.type;el.textContent=`${type==='deposit'?'مصدر خارجي ← القاصة':'القاصة ← سحب خارجي'} · القاصة بعد الحفظ ${fmt(M.cash(state)-(old?(old.type==='deposit'?old.amount:-old.amount):0)+(type==='deposit'?amount:-amount))} د.ع. الرصيد اليومي ما يتغير.`;}}catch{el.textContent='أدخل المبلغ حتى تظهر معاينة الأرصدة.';}}
function restaurantSettings(){const r=state.preferences.restaurant;return `<section class="panel"><h2>هوية وصل المطعم</h2><form id="restaurant-form">${field('restaurant-name','اسم المطعم في الوصل','text',r.name,'maxlength="100"')}${field('restaurant-contact','رقم أو عنوان للتواصل · اختياري','text',r.contact,'maxlength="160"')}${field('restaurant-footer','عبارة أسفل الوصل · اختياري','text',r.footer,'maxlength="300"')}<button class="button primary">حفظ هوية الوصل</button></form></section>`;}
function backupHealth(){return `<section class="panel" id="backup-health"><div class="settings-action-row"><div><h2>حالة النسخ الاحتياطية</h2><p>آخر نسخة محفوظة، وتوفر نسخة الجهاز السابقة.</p></div>${button('تحديث الحالة','backup-health')}</div><dl class="settings-backup-status"><div><dt>آخر تصدير يدوي</dt><dd>${backupInfo?.lastExport ? esc(new Date(backupInfo.lastExport).toLocaleString('ar-IQ-u-nu-latn')):'ماكو تصدير خارجي مسجل بعد'}</dd></div><div><dt>النسخة المحلية السابقة</dt><dd>${backupInfo?.previousAvailable?`متاحة · ${esc(new Date(backupInfo.previousModified).toLocaleString('ar-IQ-u-nu-latn'))}`:backupInfo?'ماكو نسخة سابقة متاحة بعد':'حدّث الحالة من تطبيق دفتر'}</dd></div></dl><details class="settings-restore"><summary>استعادة النسخة المحلية السابقة</summary><p>ترجع للنسخة السابقة مع الاحتفاظ بنسخة من البيانات الحالية. راجع تفاصيل الاستعادة قبل التأكيد.</p>${button('استعادة النسخة السابقة','restore-backup')}</details>${typeof window.daftar.restore!=='function'?'<p class="settings-caption">هذه معاينة متصفح. تصدير النسخ واستعادتها وفتح المجلد متاح من تطبيق دفتر المثبّت.</p>':''}</section>`;}
function showExportResult(filePath){if(!filePath){toast('تم حفظ الملف');return;}const el=document.getElementById('toast');clearTimeout(toastTimer);el.className='visible export-result';el.innerHTML=`<span>تم حفظ ${esc(filePath.split(/[\\/]/).pop())}</span><button data-action="open-export">فتح</button><button data-action="reveal-export">إظهار بالمجلد</button><button data-action="dismiss-toast" aria-label="إغلاق التنبيه">×</button>`;lastExportPath=filePath;}
let lastExportPath='';
function addReportButton(kind){main.querySelector('.header-actions')?.insertAdjacentHTML('beforeend',`<button class="button" data-action="period-pdf" data-kind="${kind}">تصدير هذا العرض PDF</button>`);}
function enhanceShortcutSettings(){const form=document.getElementById('shortcut-form');form.querySelectorAll('label').forEach((label,i)=>label.insertAdjacentHTML('beforeend',`<button type="button" class="text-link" data-action="shortcut-swap" data-index="${i}" ${i===0?'disabled':''}>نقل لليمين</button>`));form.insertAdjacentHTML('beforeend','<div id="shortcut-preview" class="shortcut-preview" role="status"></div>');refreshShortcutPreview();}
function refreshShortcutPreview(){const values=[...document.querySelectorAll('#shortcut-form select')].map(el=>el.value),el=document.getElementById('shortcut-preview');if(!el)return;el.innerHTML='<p>معاينة ترتيب اختصاراتك</p>'+values.filter(Boolean).map(v=>`<span class="badge">${destinationLabels[v]}</span>`).join('')+(new Set(values.filter(Boolean)).size<values.filter(Boolean).length?'<p>بعض الوجهات مكررة. تگدر تختار وجهة ثانية أو تترك الخانة فارغة.</p>':'');}
function readFilter(key){const val=id=>document.getElementById(id)?.value||'';if(key==='sales')return{from:val('sales-from'),to:val('sales-to'),query:val('sales-query'),status:val('sales-status'),orderType:val('sales-order-filter')};if(key==='statement')return{from:val('statement-from'),to:val('statement-to'),categoryId:val('statement-category'),source:val('statement-source')};if(key==='invoices')return{from:val('invoice-filter-from'),to:val('invoice-filter-to'),material:val('invoice-filter-material'),supplierId:val('invoice-filter-supplier')};if(key==='payments')return{from:val('payments-from'),to:val('payments-to'),query:val('payments-query'),supplierId:val('payments-supplier')};return{from:val('cash-from'),to:val('cash-to'),kind:val('cash-kind')};}
function setFilter(key,f){if(key==='sales')saleFilter=f;else if(key==='statement')statementFilter=f;else if(key==='invoices')invoiceFilter=f;else if(key==='payments')paymentsFilter=f;else cashFilter=f;pageNumbers[key]=1;render();}
function showReadOnly(title,body){if(!allowLeave())return;previousFocus=document.activeElement;previousFocusKey=focusKey(previousFocus);drawer={kind:'detail',readonly:true};host.innerHTML=`<button class="scrim" data-action="close-drawer" aria-label="إغلاق" tabindex="-1"></button><section class="drawer wide" role="dialog" aria-modal="true" aria-labelledby="drawer-title"><div class="drawer-top"><span>دفتر</span><button class="icon-button" data-action="close-drawer" aria-label="إغلاق">${icon('close')}</button></div><div class="drawer-intro"><h2 id="drawer-title">${esc(title)}</h2></div><div class="form-content">${body}</div></section>`;document.body.classList.add('drawer-open'); document.querySelector('.shell').inert=true;host.querySelector('.drawer-top button').focus();}
function stockHistory(productId){const p=state.products.find(x=>x.id===productId);let balance=0;const events=[...(state.saleReturns||[]).flatMap(r=>r.lines.filter(l=>l.productId===productId&&l.restock).map(l=>({id:r.id,saleId:r.saleId,date:r.date,createdAt:r.createdAt,quantity:l.quantity,source:'return',note:r.reason}))),...state.stockEntries.filter(e=>e.productId===productId).map(e=>({...e,source:'stock'})),...state.sales.filter(s=>s.status==='completed').flatMap(s=>s.lines.filter(l=>l.productId===productId&&l.trackStock).map(l=>({id:s.id,date:s.date,createdAt:s.createdAt,quantity:-l.quantity,source:'sale',number:s.number})))].sort((a,b)=>a.date.localeCompare(b.date)||a.createdAt.localeCompare(b.createdAt)||a.id.localeCompare(b.id)).map(e=>({...e,balance:(balance+=Math.round(e.quantity*1000))/1000}));return `<p>المتوفر حتى ${M.dateKey()}: <strong>${qtyFmt(M.stock(state,productId,M.dateKey()))} ${esc(p.unit)}</strong></p><p class="hint">الترتيب بتاريخ الحركة ثم وقت تسجيلها. الحركات المستقبلية موضحة؛ البيع الملغي ما ينخصم، والمرتجع يرجع فقط الكمية المختارة للمخزن.</p><div class="table-scroll"><table><thead><tr><th>التاريخ</th><th>الحركة</th><th>الرصيد بعدها</th><th>المصدر / التصحيح</th></tr></thead><tbody>${pageItems(events.reverse(),'stock:'+productId).map(e=>`<tr><td>${e.date}${e.date>M.dateKey()?' · مستقبلية':''}</td><td>${qtyFmt(e.quantity)}</td><td>${qtyFmt(e.balance)}</td><td>${e.source==='return'?`مرتجع · <button class="text-link" data-action="sale-receipt" data-id="${e.saleId}">${esc(state.sales.find(s=>s.id===e.saleId)?.number||'الوصل')}</button> · ${esc(e.note)}`:e.source==='sale'?`<button class="text-link" data-action="sale-receipt" data-id="${e.id}">${esc(e.number)}</button>`:e.reversesId?`تصحيح حركة ${esc(state.stockEntries.find(x=>x.id===e.reversesId)?.date||'')} · ${esc(e.note)}`:`${esc(e.kind==='opening'?'افتتاحي':e.kind==='restock'?'تزويد':'نقص / تلف')} · ${esc(e.note)} ${state.stockEntries.some(x=>x.reversesId===e.id)?' · مصححة':`<button class="text-link" data-action="stock-reverse" data-id="${e.id}">تصحيح الحركة</button>`}`}</td></tr>`).join('')}</tbody></table></div>${pager('stock:'+productId)}`;}
function dayReview(){const remaining=M.remaining(state,selectedDate), refunds=(state.saleReturns||[]).filter(r=>r.date===selectedDate).reduce((n,r)=>n+r.amount,0);showReadOnly('مراجعة اليوم',`<p>${prettyDate(selectedDate)}</p><p class="hint">مراجعة سريعة للسجل، بدون إقفال اليوم أو تغيير الحسابات. علامات المراجعة مؤقتة لهذه النافذة.</p><ol class="day-review"><li><label class="review-check"><input type="checkbox">راجعت المبيعات والمصاريف</label><div class="review-facts"><span>صافي حركة المبيعات <strong>${fmt(M.salesTotal(state,selectedDate))} د.ع</strong></span><span>المرتجعات بتاريخ اليوم <strong>${fmt(refunds)} د.ع</strong></span><span>مصروف اليومي <strong>${fmt(M.dailySpent(state,selectedDate))} د.ع</strong></span><span>مصروف القاصة <strong>${fmt(M.expenses(state,selectedDate).reduce((n,e)=>n+M.funding(e).cashAmount,0))} د.ع</strong></span></div><p class="hint">هذه مبالغ السجل، مو صافي الربح.</p></li><li><label class="review-check"><input type="checkbox">عدّيت الباقي الفعلي</label><p>${remaining===null?'الباقي غير مسجّل بعد':fmt(remaining)+' د.ع مسجّل'} · لا تضيف المبيعات مرة ثانية إلى العد الفعلي.</p>${button('تسجيل الباقي ومعاينة الإجمالي','remaining',true)}</li><li><h3>تحويل للقاصة · اختياري</h3><p>يخصم من اليومي ويضيف للقاصة مرة واحدة.</p><button class="button" data-action="remaining-transfer" ${remaining>0?'':'disabled'}>تحويل من رصيد اليوم</button></li><li><h3>احتفظ بالتقرير</h3>${button('تصدير مصاريف اليوم PDF','daily-pdf')}</li></ol>`);}

const uxActions=new Set(['order-type-add','order-type-toggle','order-type-delete','settings-section','settings-save','settings-discard','catalog-density','catalog-reset','page-prev','page-next','apply-filter','filter-preset','inventory-low','inventory-reset','materials-apply','materials-reset','cash-popout','supplier-picker','day-review','sales-help','sale-today','shortcut-swap','backup-health','restore-backup','open-export','reveal-export','dismiss-toast','period-pdf','payment-pdf','category-edit','stock-reverse','retry-save']);
document.addEventListener('click',async event=>{
 const el=event.target.closest('[data-action]');if(!el||busy)return;const a=el.dataset.action;
 if(a==='supplier-select' && drawer?.kind==='detail')closeDrawer(true);
 if(!uxActions.has(a))return;event.preventDefault();event.stopImmediatePropagation();
 try {
 if(a.startsWith('order-type-'))editOrderType(a,el);
 else if(a==='settings-section')activateSettingsSection(el.dataset.section);
 else if(a==='settings-save')await saveSettings();
 else if(a==='settings-discard'){if(allowLeave())render();}
 else if(a==='catalog-density'){compactCatalog=!compactCatalog;try{localStorage.setItem('daftar.catalog-compact',String(compactCatalog));}catch{}render();}
 else if(a==='catalog-reset'){productSearch='';productGroup='';pageNumbers.catalog=1;render();}
 else if(a==='page-prev'||a==='page-next'){pageNumbers[el.dataset.key]=(pageNumbers[el.dataset.key]||1)+(a==='page-next'?1:-1);if(el.dataset.key.startsWith('stock:')){host.querySelector('.form-content').innerHTML=stockHistory(el.dataset.key.slice(6));host.querySelector('.pagination button:not(:disabled)')?.focus();}else{render();main.querySelector('.pagination button:not(:disabled)')?.focus();}}
 else if(a==='apply-filter'){const f=readFilter(el.dataset.key);if(validRange(f))setFilter(el.dataset.key,f);}
 else if(a==='filter-preset'){const key=el.dataset.key,period=el.dataset.period,f=readFilter(key);if(period==='all')Object.keys(f).forEach(k=>f[k]=k==='source'?'all':'');else{f.from=period==='today'?M.dateKey():M.dateKey().slice(0,8)+'01';f.to=M.dateKey();}setFilter(key,f);}
 else if(a==='inventory-low'||a==='inventory-reset'){inventoryFilter={status:a==='inventory-low'?'low':'active',group:''};inventorySearch='';pageNumbers.inventory=1;render();}
 else if(a==='materials-apply'||a==='materials-reset'){materialsFilter=a==='materials-reset'?{query:'',status:'active'}:{query:document.getElementById('materials-query').value,status:document.getElementById('materials-status').value};pageNumbers.materials=1;render();}
 else if(a==='cash-popout')showReadOnly('القاصة',cashCard()+activity());
 else if(a==='supplier-picker')showReadOnly('اختيار المورد',`<label for="supplier-search-pop">بحث المورد<input type="search" id="supplier-search-pop" value="${esc(supplierQuery)}"></label><div id="supplier-picker-list">${supplierList()}</div>`);
 else if(a==='day-review')dayReview();
 else if(a==='sales-help')showReadOnly('اختصارات البيع','<p>⌘ / Ctrl + K: البحث · رمز صنف مطابق ثم Enter: إضافة · ⌘ / Ctrl + Enter: تأكيد البيع النقدي.</p><p>⌘ / Ctrl + 1–6: اختصاراتك العلوية · Escape: إغلاق النافذة. أثناء الكتابة تبقى الأرقام للنص.</p>');
 else if(a==='sale-today'){saleDraft.date=M.dateKey();persistSaleDraft();render();}
 else if(a==='shortcut-swap'){const i=Number(el.dataset.index),prev=document.getElementById('shortcut-'+(i-1)),next=document.getElementById('shortcut-'+i);[prev.value,next.value]=[next.value,prev.value];refreshShortcutPreview();updateSettingsSaveState();}
 else if(a==='backup-health'){const result=await window.daftar.backupInfo?.();if(result?.ok){backupInfo=result.backupInfo;document.getElementById('backup-health').outerHTML=backupHealth();}else toast(result?.error||'حالة النسخ متاحة من تطبيق دفتر.',true);}
 else if(a==='restore-backup'){if(!allowLeave())return;const result=await window.daftar.restore?.();if(!result?.ok){toast(result?.error||'الاستعادة متاحة من تطبيق دفتر.',true);return;}if(!result.canceled){state=M.validate(result.data);directory=result.directory||directory;backupInfo=result.backupInfo||null;history=[];clearSaleWorkspaceAfterReplacement();status('محفوظ على جهازك');render();toast('تمت استعادة النسخة السابقة مع الاحتفاظ بنسخة من الحالية');}}
 else if(a==='open-export'||a==='reveal-export'){const result=await window.daftar.openExport?.({filePath:lastExportPath,reveal:a==='reveal-export'});if(result&&!result.ok)toast(result.error,true);}
 else if(a==='dismiss-toast')document.getElementById('toast').className='';
 else if(a==='period-pdf'){const kind=el.dataset.kind,filter=kind==='sales'?saleFilter:kind==='statement'?statementFilter:kind==='cash'?cashFilter:{};await exportPDF({kind,filter},el);}
 else if(a==='payment-pdf')await exportPDF({kind:'payment',id:el.dataset.id},el);
 else if(a==='category-edit')openDrawer('category',el.dataset.id);
 else if(a==='stock-reverse')openDrawer('stock-reverse',el.dataset.id);
 else if(a==='retry-save'&&retrySave){const pending=retrySave,form=document.getElementById(pending.formId);if(form){form.requestSubmit();return;}if(pending.saleId===saleDraft.id&&view==='sales'){await commerceAction('sale-complete',el);return;}if(await commit(pending.next,pending.message,pending.options)){retrySave=null;if(drawer)closeDrawer(true);if(state.sales.some(s=>s.id===saleDraft.id)){lastSaleId=saleDraft.id;resetSaleDraft();render();openDrawer('sale-paid',lastSaleId);}}}
 }catch(error){if(drawer&&document.getElementById('form-error'))formError(error.message);else toast(error.message,true);}
},true);
document.addEventListener('input',e=>{if(e.target.id==='supplier-search-pop'){supplierQuery=e.target.value;document.getElementById('supplier-picker-list').innerHTML=supplierList();}if(e.target.closest('#shortcut-form'))refreshShortcutPreview();if(view==='settings'){updateSettingsReceipt();updateSettingsSaveState();}if(drawer){updateCorrectionPreview();updateMovementPreview();}});
document.addEventListener('change',e=>{if(e.target.id==='track-stock')toggleStockFields();if(e.target.id==='inventory-status'||e.target.id==='inventory-group'){inventoryFilter={status:document.getElementById('inventory-status').value,group:document.getElementById('inventory-group').value};pageNumbers.inventory=1;render();document.getElementById(e.target.id)?.focus();}if(e.target.closest('#shortcut-form'))refreshShortcutPreview();if(view==='settings'){updateSettingsReceipt();updateSettingsSaveState();}if(drawer){updateCorrectionPreview();updateMovementPreview();}});
document.addEventListener('submit',async e=>{if(e.target.id!=='restaurant-form')return;e.preventDefault();if(!busy)await saveSettings();});
document.addEventListener('keydown',e=>{
 if(!state||busy)return;
 if(!sidebarCollapsed&&!drawer&&e.key==='Tab'){const nodes=[...document.querySelectorAll('#main-sidebar button')].filter(x=>!x.disabled),first=nodes[0],last=nodes.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}return;}
 if(drawer)return;
 if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='k'){e.preventDefault();if(view!=='sales'){if(!allowLeave())return;view='sales';render();}document.getElementById('product-search')?.focus();}
 else if((e.metaKey||e.ctrlKey)&&e.key==='Enter'&&view==='sales'&&!drawer){e.preventDefault();document.getElementById('checkout-button')?.click();}
 else if((e.metaKey||e.ctrlKey)&&/^[1-6]$/.test(e.key)&&!e.target.matches('input,textarea,select')){e.preventDefault();const dest=state.preferences.shortcuts[Number(e.key)-1];if(dest&&allowLeave()){settingsBaseline='';view=dest;sidebarCollapsed=true;render();}}
 else if(e.key==='Enter'&&e.target.id==='product-search'){e.preventDefault();const code=N.latin(e.target.value).trim().toLowerCase(),p=state.products.find(p=>!p.archived&&p.code&&p.code.toLowerCase()===code);if(p){commerceAction('sale-add',{dataset:{id:p.id}});e.target.select();}else toast('ماكو رمز مطابق. اختار الصنف من النتائج.');}
});
window.addEventListener('beforeunload',e=>{persistSaleDraft();if(isDirty()){e.preventDefault();e.returnValue='';}});
// Only refresh an empty draft on day rollover; never silently redate an order.
setInterval(()=>{if(typeof state!=='undefined'&&state&&!saleDraft.lines.length&&saleDraft.date===lastDraftDay&&lastDraftDay!==M.dateKey()){saleDraft.date=M.dateKey();lastDraftDay=M.dateKey();persistSaleDraft();if(view==='sales'&&!drawer)render();}},30000);
function purchaseUnitTotals(lines){const groups=new Map();for(const {line:l} of lines){const key=l.name+' · '+l.unit,g=groups.get(key)||{cartons:0,pieces:0};g.cartons+=l.quantityCartons||0;g.pieces+=l.quantityPieces??l.quantity??0;groups.set(key,g);}return [...groups].map(([key,g])=>`<span>${esc(key)}: ${qtyFmt(g.cartons)} كارتون · ${qtyFmt(g.pieces)} ${esc(key.split(' · ').at(-1))}</span>`).join('')||'ماكو كميات';}
function purchaseGroups(invoices,selected){return invoices.length?pageItems([...invoices].reverse(),'invoices').map(i=>`<details class="purchase-group" ${selected?'open':''}><summary><strong>${esc(i.number)} · ${esc(shortDate(i.date))} · ${esc(supplierById(i.supplierId)?.name)}</strong><span>قيمة القائمة ${fmt(M.invoiceTotal(i))} · المتبقي من القائمة ${fmt(M.invoiceDue(state,i.id))} د.ع</span></summary><div class="table-scroll"><table><thead><tr><th>المادة / الوحدة</th><th>كارتون</th><th>كمية الوحدة</th><th>سعر الكارتون / الوحدة</th><th>المبلغ</th></tr></thead><tbody>${i.lines.filter(l=>!selected||N.latin(l.name).toLowerCase()===N.latin(selected).toLowerCase()).map(l=>`<tr><td>${esc(l.name)} · ${esc(l.unit)}</td><td>${qtyFmt(l.quantityCartons||0)}</td><td>${qtyFmt(l.quantityPieces??l.quantity??0)}</td><td>${fmt(l.priceCarton||0)} / ${fmt(l.pricePiece??l.price??0)}</td><td>${fmt(M.lineTotal(l))}</td></tr>`).join('')}</tbody></table></div><button class="button small" data-action="invoice-edit" data-id="${i.id}">تعديل الفاتورة</button></details>`).join('')+pager('invoices'):'<p class="empty-help">ماكو فواتير مطابقة. غيّر الاختيارات أو امسح التصفية.</p>';}

// Settings sections share one save operation, so saving never drops edits in another section.
let settingsSection = 'restaurant';
const settingsSections = [['restaurant','المطعم والوصل'],['workflow','البيع والاختصارات'],['data','النسخ والبيانات'],['about','عن دفتر']];
function settingsPanel(key, content) {
  return `<div id="settings-panel-${key}" class="settings-content" role="tabpanel" aria-labelledby="settings-tab-${key}" ${settingsSection===key?'':'hidden'}>${content}</div>`;
}
function organizedSettingsPage() {
  return header('الإعدادات', 'رتّب دفتر بالطريقة اللي تناسب شغلك.', '', 'مساحة العمل / الإعدادات') + `<div class="settings-workspace">
    <nav class="settings-tabs" role="tablist" aria-label="أقسام الإعدادات">${settingsSections.map(([key,label])=>`<button type="button" id="settings-tab-${key}" role="tab" aria-selected="${settingsSection===key}" aria-controls="settings-panel-${key}" tabindex="${settingsSection===key?'0':'-1'}" data-action="settings-section" data-section="${key}">${label}</button>`).join('')}</nav>
    <div id="settings-error" class="form-error settings-error" role="alert" tabindex="-1"></div>
    ${settingsPanel('restaurant',`<div class="settings-intro"><h2>اسم مطعمك على كل وصل</h2><p>عدّل معلومات الوصل، وشوف شكلها قبل الحفظ.</p></div><div class="settings-receipt-layout">${restaurantSettings()}<aside class="receipt-preview-wrap" aria-label="معاينة هوية الوصل"><p class="settings-kicker">معاينة مباشرة</p><div class="settings-receipt"><span class="receipt-preview-brand">دفتر / وصل بيع نقدي</span><h3 id="settings-preview-name"></h3><p id="settings-preview-contact"></p><div class="receipt-preview-body"><span>الصنف</span><span>الكمية · المبلغ</span><p>تفاصيل طلبك تظهر هنا عند البيع</p></div><p id="settings-preview-footer"></p></div><p class="settings-caption">معاينة توضيحية لهوية الوصل. تحفظ التغييرات للوصولات القادمة.</p></aside></div>`)}
    ${settingsPanel('workflow',`<div class="settings-intro"><h2>وصول أسرع، وبيع أوضح</h2><p>اختار صفحاتك المفضلة وأنواع طلباتك.</p></div>${shortcutSettings()}<div class="settings-two-column">${orderTypeSettings()}<section class="panel"><h2>تعديل قوائم التطبيق</h2><div class="settings-inline-links"><button class="button small" data-view="categories">خانات المصاريف</button><button class="button small" data-view="materials">المواد والأسعار</button><button class="button small" data-view="inventory">أصناف البيع</button></div></section></div>`)}
    ${settingsPanel('data',`<div class="settings-intro"><h2>نسخة إضافية، وراحة بال</h2><p>الحسابات تنحفظ تلقائياً على جهازك. احتفظ بنسخة إضافية بمكان مستقل.</p></div>${backupHealth()}<section class="panel settings-backup-panel"><div class="settings-action-row"><div><h2>تصدير نسخة احتياطية</h2><p>كل الحسابات والمبيعات والمخزن والإعدادات بملف واحد.</p></div>${button('تصدير نسخة','export',true,'download')}</div><div class="settings-action-row settings-recovery"><div><h3>استيراد نسخة محفوظة</h3><p>يستبدل الحسابات الحالية بعد معاينتها وتأكيدك. نحفظ نسخة من البيانات الحالية قبل الاستبدال.</p></div>${button('استيراد نسخة','import',false,'upload')}</div></section><section class="panel"><h2>مكان حفظ البيانات</h2><p>ملفاتك محفوظة خارج التطبيق حتى تبقى عند تحديثه.</p><div class="path">${esc(directory)}</div><div class="backup-actions">${button('فتح مجلد البيانات','folder',false,'folder')}</div></section>`)}
    ${settingsPanel('about',`<div class="settings-intro"><h2>دفتر، لحسابات مطعمك</h2><p>مساحة محلية خاصة لإدارة شغلك اليومي.</p></div><section class="panel settings-facts"><div><span>إصدار التطبيق</span><strong class="number">1.12.0</strong></div><div><span>اللغة والاتجاه</span><strong>العربية · من اليمين لليسار</strong></div><div><span>العملة</span><strong>الدينار العراقي · د.ع</strong></div><div><span>الحفظ</span><strong>محلي وتلقائي على الجهاز</strong></div></section><section class="panel"><h2>ملاحظات الحساب</h2><ul class="info-list"><li>اليومي والقاصة منفصلان<small>مصروف اليومي يحسب حصة اليومي فقط؛ حصة القاصة تخصم منها مرة واحدة.</small></li><li>الرصيد مو صافي الربح<small>الرصيد اليومي والقاصة مبالغ نقدية، وما تعتبر تقرير أرباح.</small></li><li>قائمة المورد تسجّل الدين<small>التسديد هو الحركة اللي تدخل بالمصاريف وتخصم من مصدر الدفع.</small></li></ul></section><section class="panel settings-action-row"><div><h2>التراجع عن آخر تغيير</h2><p>يرجع آخر تعديل قابل للتراجع خلال الجلسة. إلغاء المبيعات من سجل المبيعات.</p></div><button class="button" data-action="undo" ${history.length?'':'disabled'}>تراجع عن آخر تغيير</button></section>`)}
    <div class="settings-savebar"><div><strong id="settings-save-label">إعداداتك محفوظة</strong><p>الحفظ يشمل تعديلات كل الأقسام.</p></div><div><button type="button" class="button" data-action="settings-discard">إلغاء التعديلات</button><button type="button" class="button primary" data-action="settings-save">${icon('check')}حفظ التغييرات</button></div></div>
  </div>`;
}
function initializeSettings() {
  // The section forms retain their submit paths for Enter and keyboard access.
  main.querySelectorAll('.settings-content form button[type=submit], #restaurant-form>button').forEach(el=>el.remove());
  main.querySelectorAll('.settings-content form').forEach(form=>{const submit=document.createElement('button');submit.type='submit';submit.hidden=true;submit.textContent='حفظ التغييرات';form.append(submit);});
  enhanceShortcutSettings();
  renderOrderTypeRows();
  updateSettingsReceipt();
  settingsBaseline=formSignature(main);
  updateSettingsSaveState();
}
function activateSettingsSection(key, focus=false) {
  if(!settingsSections.some(([id])=>id===key))return;
  settingsSection=key;
  main.querySelectorAll('.settings-tabs [role=tab]').forEach(el=>{const active=el.dataset.section===key;el.setAttribute('aria-selected',String(active));el.tabIndex=active?0:-1;if(active&&focus)el.focus();});
  main.querySelectorAll('.settings-content').forEach(el=>el.hidden=el.id!=='settings-panel-'+key);
}
function updateSettingsReceipt() {
  for(const [key,fallback] of [['name','اسم المطعم'],['contact','رقم أو عنوان التواصل · اختياري'],['footer','عبارتك أسفل الوصل · اختياري']]) {
    const el=document.getElementById('settings-preview-'+key),input=document.getElementById('restaurant-'+key);
    if(el&&input){el.textContent=input.value.trim()||fallback;el.classList.toggle('is-placeholder',!input.value.trim());}
  }
}
function updateSettingsSaveState() {
  const label=document.getElementById('settings-save-label');if(!label)return;
  const dirty=Boolean(settingsBaseline&&settingsBaseline!==formSignature(main));
  label.textContent=dirty?'عندك تعديلات غير محفوظة':'إعداداتك محفوظة';
  for(const el of main.querySelectorAll('[data-action="settings-save"],[data-action="settings-discard"]'))el.disabled=!dirty;
}
async function saveSettings() {
  if(busy||view!=='settings')return;
  const error=document.getElementById('settings-error');error.textContent='';
  const next=structuredClone(state);
  next.preferences.restaurant=Object.fromEntries(['name','contact','footer'].map(k=>[k,document.getElementById('restaurant-'+k).value.trim()]));
  next.preferences.shortcuts=Array.from({length:6},(_,i)=>document.getElementById('shortcut-'+i).value);
  if(document.getElementById('order-type-new').value.trim()){orderTypeError('اضغط إضافة لتسجيل النوع الجديد، أو امسح الحقل قبل الحفظ.');activateSettingsSection('workflow');document.getElementById('order-type-new').focus();return;}
  const types=readOrderTypeDraft();next.preferences.orderTypes=types.active;next.preferences.disabledOrderTypes=types.disabled;
  try { M.validate(next); } catch(e) {error.textContent=e.message;error.focus();toast(e.message,true);return;}
  if(!await commit(next,'تم حفظ إعداداتك')){error.textContent='تعذّر الحفظ. تعديلاتك موجودة، حاول مرة ثانية.';return;}
  if(!saleDraft.lines.length){saleDraft.orderType=state.preferences.orderTypes[0];persistSaleDraft();}
  main.querySelector('[role=tab][aria-selected=true]')?.focus();
}
document.addEventListener('keydown',e=>{
  if(e.target.id==='order-type-new'&&e.key==='Enter'){e.preventDefault();editOrderType('order-type-add',e.target);return;}
  if(view==='settings'&&!drawer&&(e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='s'){e.preventDefault();saveSettings();return;}
  const tab=e.target.closest('.settings-tabs [role=tab]');if(!tab||!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;
  e.preventDefault();const i=settingsSections.findIndex(([key])=>key===tab.dataset.section);
  const next=e.key==='Home'?0:e.key==='End'?settingsSections.length-1:(i+(e.key==='ArrowLeft'?1:-1)+settingsSections.length)%settingsSections.length;
  activateSettingsSection(settingsSections[next][0],true);
});

function orderTypeManager() {
  return `<section class="panel order-type-settings"><h2>أنواع الطلبات</h2><p>أضف أنواع شغلك، وحدد النوع الافتراضي للبيع.</p><form id="order-types-form"><textarea id="order-types-list" hidden aria-hidden="true">${esc(state.preferences.orderTypes.join('\n'))}</textarea><input type="hidden" id="disabled-order-types" value="${esc(JSON.stringify(state.preferences.disabledOrderTypes||[]))}"><label class="settings-field" for="order-type-default">النوع الافتراضي<select id="order-type-default"></select></label><div id="order-type-rows" class="order-type-rows"></div><label for="order-type-new">إضافة نوع جديد</label><div class="order-type-add"><input id="order-type-new" type="text" maxlength="60" placeholder="مثلاً: استلام من المطعم" autocomplete="off"><button type="button" class="button" data-action="order-type-add">${icon('plus')}إضافة</button></div><p id="order-type-error" class="form-error" role="alert"></p><p class="settings-caption">التعطيل يخفي النوع من البيع وتگدر تفعّله لاحقاً. الحذف أو التعطيل ما يغيّر نوع الطلب في المبيعات السابقة.</p></form></section>`;
}
function readOrderTypeDraft() {
  return {active:document.getElementById('order-types-list').value.split(/\r?\n/).map(t=>t.trim()).filter(Boolean),disabled:JSON.parse(document.getElementById('disabled-order-types').value)};
}
function renderOrderTypeRows() {
  const {active,disabled}=readOrderTypeDraft(),select=document.getElementById('order-type-default');
  select.innerHTML=active.map((name,i)=>`<option value="${esc(name)}" ${i===0?'selected':''}>${esc(name)}</option>`).join('');
  document.getElementById('order-type-rows').innerHTML=[...active.map((name,i)=>({name,index:i,disabled:false})),...disabled.map((name,i)=>({name,index:i,disabled:true}))].map(row=>`<div class="order-type-row ${row.disabled?'is-disabled':''}"><div><strong>${esc(row.name)}</strong><small>${row.disabled?'معطّل':row.index===0?'افتراضي':'مفعّل'}</small></div><div><button type="button" class="text-link" data-action="order-type-toggle" data-index="${row.index}" data-disabled="${row.disabled}" aria-label="${row.disabled?'تفعيل':'تعطيل'} ${esc(row.name)}">${row.disabled?'تفعيل':'تعطيل'}</button><button type="button" class="text-link order-type-remove" data-action="order-type-delete" data-index="${row.index}" data-disabled="${row.disabled}" aria-label="حذف ${esc(row.name)}">حذف</button></div></div>`).join('');
}
function orderTypeError(message) { document.getElementById('order-type-error').textContent=message; }
function writeOrderTypeDraft(draft) {
  document.getElementById('order-types-list').value=draft.active.join('\n');
  document.getElementById('disabled-order-types').value=JSON.stringify(draft.disabled);
  renderOrderTypeRows();updateSettingsSaveState();
}
function editOrderType(action,el) {
  if(busy)return;
  const draft=readOrderTypeDraft();orderTypeError('');
  if(action==='order-type-add') {
    const input=document.getElementById('order-type-new'),name=input.value.trim();
    if(!name){orderTypeError('اكتب اسم نوع الطلب أولاً.');input.focus();return;}
    if([...draft.active,...draft.disabled].some(t=>t.toLocaleLowerCase()===name.toLocaleLowerCase())){orderTypeError('هذا النوع موجود مسبقاً. تگدر تفعّله إذا كان معطّل.');return;}
    if(draft.active.length+draft.disabled.length>=20){orderTypeError('الحد الأقصى 20 نوع طلب. احذف نوعاً قبل الإضافة.');return;}
    draft.active.push(name);input.value='';writeOrderTypeDraft(draft);input.focus();return;
  }
  const disabled=el.dataset.disabled==='true',list=disabled?draft.disabled:draft.active,index=Number(el.dataset.index);
  if(!Number.isInteger(index)||index<0||index>=list.length)return;
  if(!disabled&&draft.active.length===1){orderTypeError('خلي نوع طلب مفعّل واحد على الأقل. أضف أو فعّل نوعاً آخر أولاً.');return;}
  const [name]=list.splice(index,1);
  if(action==='order-type-toggle')(disabled?draft.active:draft.disabled).push(name);
  writeOrderTypeDraft(draft);
  document.getElementById('order-type-default').focus();
}
document.addEventListener('change',e=>{
  if(e.target.id!=='order-type-default')return;
  const draft=readOrderTypeDraft(),name=e.target.value;
  if(!draft.active.includes(name))return;
  draft.active=[name,...draft.active.filter(t=>t!==name)];writeOrderTypeDraft(draft);orderTypeError('');
});
