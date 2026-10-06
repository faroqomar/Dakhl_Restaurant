'use strict';
let savingsDate = window.DaftarModel.dateKey(), savingsTab = 'contribution', savingsQuery = '';
const savingsFrequency = { daily: 'يومي', weekly: 'أسبوعي', monthly: 'شهري' };
function savingsWorker(id) { return state.workers.find(w => w.id === id); }
function savingsRoster() {
  const workers = state.workers.filter(w => !savingsQuery || N.latin(w.name).toLowerCase().includes(savingsQuery.toLowerCase()));
  return workers.map(w => {
    const status = M.savingsStatus(state, w, savingsDate), receipts = state.savingsEntries.filter(e => e.workerId === w.id && e.type === 'receipt' && e.date <= savingsDate), received = receipts.reduce((sum, e) => sum + e.amount, 0);
    return `<tr class="${w.archived ? 'worker-paused' : ''}"><td><strong>${esc(w.name)}</strong>${w.archived ? '<small>اشتراك موقوف</small>' : ''}${w.note ? `<small>${esc(w.note)}</small>` : ''}</td><td>${num(status.due)}<small>${savingsFrequency[w.frequency]}</small></td><td><span class="badge ${status.period && status.remaining === 0 ? 'savings-paid' : ''}">${!status.period ? 'يبدأ لاحقاً' : status.paid === 0 ? 'لم يدفع' : status.remaining ? 'دفع جزء' : 'دفع كامل'}</span>${status.period ? `<small>${num(status.paid)} مدفوع · ${num(status.remaining)} باقي</small><small class="number">${status.period.start} — ${status.period.end}</small>` : `<small>يبدأ ${esc(shortDate(w.startDate))}</small>`}</td><td><span class="badge ${receipts.length ? 'savings-paid' : ''}">${receipts.length ? 'سبق واستلم' : 'بعده ما استلم'}</span>${receipts.length ? `<small>${num(received)} د.ع · ${num(receipts.length)} مرة</small>` : ''}</td><td><div class="row-actions"><button class="button small" data-action="savings-pay" data-id="${w.id}" ${w.archived || !status.period || !status.remaining ? 'disabled' : ''}>تسجيل دفعة</button><button class="text-link" data-action="savings-receive" data-id="${w.id}" ${M.savingsBalance(state, savingsDate) <= 0 ? 'disabled' : ''}>استلام</button><button class="icon-button" data-action="worker-edit" data-id="${w.id}" aria-label="تعديل العامل ${esc(w.name)}">${icon('edit')}</button></div></td></tr>`;
  }).join('') || '<tr><td colspan="5" class="note">ماكو عامل بهذا الاسم.</td></tr>';
}
function savingsPage() {
  const entries = state.savingsEntries.filter(e => e.date <= savingsDate), paid = entries.filter(e => e.type === 'contribution').reduce((s, e) => s + e.amount, 0), received = entries.filter(e => e.type === 'receipt').reduce((s, e) => s + e.amount, 0);
  const logs = [...state.savingsEntries].filter(e => e.type === savingsTab).sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
  return header('سلفة العمال، واضحة.', 'اشتراكات يومية أو أسبوعية أو شهرية، ومتابعة الدفعات والاستلام.', button('إضافة عامل', 'worker-new', true, 'plus'), 'العمال / السلفة') + `<div class="savings-date"><label for="savings-date">المتابعة لغاية</label><input type="date" id="savings-date" value="${savingsDate}"><span>سجل مستقل عن المصاريف والقاصة</span></div><section class="summary" aria-label="ملخص السلفة"><div><p class="summary-label">المتجمع المتاح</p>${num(M.savingsBalance(state, savingsDate), 'summary-value')}<span class="unit">د.ع</span></div><div><p class="summary-label">مجموع دفعات العمال</p>${num(paid, 'summary-value')}<span class="unit">د.ع</span></div><div><p class="summary-label">مجموع الاستلام</p>${num(received, 'summary-value')}<span class="unit">د.ع</span></div></section><section class="panel savings-panel"><div class="section-head"><div><h2>العمال والاشتراكات</h2><p class="muted">حالة الدفع للفترة اللي بيها التاريخ المختار. الاستلام يوضح كل ما استلمه العامل لغاية هذا التاريخ.</p></div>${state.workers.length ? `<input type="search" id="worker-search" placeholder="ابحث عن عامل…" aria-label="ابحث عن عامل" value="${esc(savingsQuery)}">` : ''}</div>${state.workers.length ? `<div class="table-scroll"><table class="supplier-table savings-table"><thead><tr><th>العامل</th><th>مبلغ الاشتراك · د.ع</th><th>دفع هذه الفترة</th><th>الاستلام</th><th>الإجراءات</th></tr></thead><tbody id="savings-roster">${savingsRoster()}</tbody></table></div>` : supplierEmpty('ابدأ بأسماء العمال.', 'لكل عامل مبلغ اشتراك وفترة. سجّل دفعاتهم، وبعدها سجّل منو استلم من المبلغ المتجمع.', 'إضافة أول عامل', 'worker-new')}</section><section class="panel savings-panel"><div class="section-head"><h2>سجل السلفة</h2><div class="savings-tabs" role="group" aria-label="نوع سجل السلفة"><button class="button small ${savingsTab === 'contribution' ? 'primary' : ''}" data-action="savings-tab" data-tab="contribution" aria-pressed="${savingsTab === 'contribution'}">دفعات العمال</button><button class="button small ${savingsTab === 'receipt' ? 'primary' : ''}" data-action="savings-tab" data-tab="receipt" aria-pressed="${savingsTab === 'receipt'}">الاستلام</button></div></div>${logs.length ? `<div class="table-scroll"><table class="supplier-table"><thead><tr><th>التاريخ</th><th>العامل</th><th>المبلغ · د.ع</th><th>الملاحظات / الفترة</th><th>تعديل</th></tr></thead><tbody>${logs.slice(0, savingsLogLimit).map(e => `<tr><td class="number">${e.date}</td><td>${esc(savingsWorker(e.workerId).name)}</td><td>${num(e.amount)}</td><td class="note">${esc(e.note || '—')}${e.type === 'contribution' ? `<small class="number">${e.periodStart} — ${e.periodEnd}</small>` : ''}</td><td><button class="icon-button" data-action="savings-entry-edit" data-id="${e.id}" aria-label="تعديل ${e.type === 'receipt' ? 'استلام' : 'دفعة'} ${esc(savingsWorker(e.workerId).name)}">${icon('edit')}</button></td></tr>`).join('')}</tbody></table></div>${logs.length > savingsLogLimit ? button('عرض سجلات أكثر', 'savings-more') : ''}` : '<p class="savings-empty">ماكو حركات مسجّلة هنا بعد.</p>'}</section>`;
}
let savingsLogLimit = 100;
function savingsDrawer(kind, id, options) {
  if (kind === 'worker') {
    const w = savingsWorker(id), locked = w && state.savingsEntries.some(e => e.workerId === id && e.type === 'contribution');
    return { title: w ? 'تعديل العامل' : 'إضافة عامل للسلفة', subtitle: 'حدد مبلغ اشتراكه ومتى يدفع.', saveLabel: 'حفظ العامل', fields: `${field('worker-name', 'اسم العامل', 'text', w?.name || '', 'required maxlength="100"')}${amountField(w?.amount ?? '', 'مبلغ الاشتراك لكل فترة')}<div class="field"><label for="worker-frequency">يدفع كل</label><select id="worker-frequency" name="frequency" ${locked ? 'disabled' : ''}>${Object.entries(savingsFrequency).map(([value, label]) => `<option value="${value}" ${value === (w?.frequency || 'daily') ? 'selected' : ''}>${label}</option>`).join('')}</select></div>${field('worker-start', 'تاريخ بداية الاشتراك', 'date', w?.startDate || savingsDate, locked ? 'disabled' : 'required')}${locked ? '<p class="note-box">الفترة والبداية ثابتة بعد تسجيل الدفعات حتى يبقى سجل العامل صحيح. تعديل المبلغ ينطبق على الفترات الجديدة؛ الفترة اللي بيها دفعات تحتفظ بمبلغها.</p>' : '<p class="note-box">الأسبوع يبدأ من تاريخ الاشتراك. الشهر يبدأ بنفس يوم البداية، أو آخر يوم بالشهر إذا الشهر أقصر.</p>'}${noteField(w?.note || '')}${w ? `<label class="checkline"><input type="checkbox" name="archived" ${w.archived ? 'checked' : ''}>إيقاف اشتراك العامل مع الاحتفاظ بسجله</label>` : ''}` };
  }
  const entry = id ? state.savingsEntries.find(e => e.id === id) : null;
  drawer.workerId = entry?.workerId || options.workerId;
  drawer.entryType = entry?.type || options.type;
  const worker = savingsWorker(drawer.workerId); if (!worker) throw new Error('اختار العامل أولاً.');
  const date = entry?.date || savingsDate;
  return { title: drawer.entryType === 'receipt' ? 'تسجيل استلام السلفة' : 'تسجيل دفعة العامل', subtitle: worker.name, saveLabel: entry ? 'حفظ التعديل' : 'حفظ الحركة', fields: `${field('savings-entry-date', 'تاريخ الحركة', 'date', date, 'required')}${amountField(entry?.amount ?? (drawer.entryType === 'receipt' ? Math.min(1e12, M.savingsBalance(state, date)) : M.savingsStatus(state, worker, date).remaining), drawer.entryType === 'receipt' ? 'المبلغ اللي استلمه العامل' : 'المبلغ اللي دفعه العامل')}<div id="savings-entry-summary" class="note-box" role="status" aria-live="polite"></div>${noteField(entry?.note || '')}${entry ? deleteBlock() : ''}` };
}
function refreshSavingsEntry() {
  if (drawer?.kind !== 'savings-entry') return;
  const date = document.getElementById('savings-entry-date').value, summary = document.getElementById('savings-entry-summary');
  if (!M.validDate(date)) { summary.textContent = 'اختار تاريخ صحيح.'; return; }
  const other = { ...state, savingsEntries: state.savingsEntries.filter(e => e.id !== drawer.id) };
  if (drawer.entryType === 'receipt') summary.textContent = `المتجمع المتاح بهذا التاريخ: ${fmt(M.savingsBalance(other, date))} د.ع. الاستلام ينخصم من سجل السلفة فقط.`;
  else { const status = M.savingsStatus(other, savingsWorker(drawer.workerId), date), old = state.savingsEntries.find(e => e.id === drawer.id); if (old && old.periodStart === status.period?.start) { status.due = old.dueAmount; status.remaining = Math.max(0, status.due - status.paid); } summary.textContent = status.period ? `اشتراك هذه الفترة: ${fmt(status.due)} د.ع · الباقي: ${fmt(status.remaining)} د.ع. من ${status.period.start} لغاية ${status.period.end}. تگدر تسجّل دفعة جزئية.` : 'هذا التاريخ يسبق بداية اشتراك العامل.'; }
}
function savingsSubmit(next, context, values) {
  if (context.kind === 'worker') {
    const old = next.workers.find(w => w.id === context.id), locked = old && next.savingsEntries.some(e => e.workerId === old.id && e.type === 'contribution');
    const worker = { id: old?.id || crypto.randomUUID(), name: values.get('worker-name').trim(), amount: M.numeric(values.get('amount'), { positive: true }), frequency: locked ? old.frequency : values.get('frequency'), startDate: locked ? old.startDate : values.get('worker-start'), note: values.get('note').trim(), archived: values.has('archived') };
    next.workers = next.workers.filter(w => w.id !== context.id); next.workers.push(worker); return 'تم حفظ العامل واشتراكه';
  }
  const old = next.savingsEntries.find(e => e.id === context.id), date = values.get('savings-entry-date');
  if (!M.validDate(date)) throw new Error('اختار تاريخ صحيح.');
  const worker = next.workers.find(w => w.id === context.workerId);
  if (!old && worker.archived && context.entryType === 'contribution') throw new Error('اشتراك العامل موقوف. فعّله أولاً.');
  const entry = { id: old?.id || crypto.randomUUID(), workerId: context.workerId, type: context.entryType, date, amount: M.numeric(values.get('amount'), { positive: true }), note: values.get('note').trim(), createdAt: old?.createdAt || new Date().toISOString() };
  const status = M.savingsStatus(next, worker, date);
  if (entry.type === 'contribution') { if (!status.period) throw new Error('تاريخ الدفعة يسبق بداية اشتراك العامل.'); Object.assign(entry, { periodStart: status.period.start, periodEnd: status.period.end, dueAmount: old?.periodStart === status.period.start ? old.dueAmount : status.due }); }
  next.savingsEntries = next.savingsEntries.filter(e => e.id !== context.id); next.savingsEntries.push(entry);
  context.resultSavingsTab = entry.type;
  return entry.type === 'receipt' ? 'تم تسجيل استلام السلفة' : 'تم تسجيل دفعة العامل';
}
function savingsAction(action, el) {
  if (action === 'worker-new' || action === 'worker-edit') { openDrawer('worker', action === 'worker-edit' ? el.dataset.id : null); return true; }
  if (action === 'savings-tab') { savingsTab = el.dataset.tab; savingsLogLimit = 100; render(); return true; }
  if (action === 'savings-more') { savingsLogLimit += 100; render(); return true; }
  if (action === 'savings-pay' || action === 'savings-receive') { openDrawer('savings-entry', null, { workerId: el.dataset.id, type: action === 'savings-pay' ? 'contribution' : 'receipt' }); return true; }
  if (action === 'savings-entry-edit') { openDrawer('savings-entry', el.dataset.id); return true; }
  if (action === 'confirm-delete' && drawer?.kind === 'savings-entry') return (async () => { const next = structuredClone(state); next.savingsEntries = next.savingsEntries.filter(e => e.id !== drawer.id); if (await commit(next, 'تم حذف الحركة من السلفة · تگدر تتراجع بـ ⌘Z')) closeDrawer(); return true; })();
  return false;
}
document.addEventListener('change', event => {
  if (event.target.id === 'savings-date' && M.validDate(event.target.value)) { savingsDate = event.target.value; render(); }
  if (event.target.id === 'savings-entry-date') refreshSavingsEntry();
});
document.addEventListener('input', event => {
  if (event.target.id === 'worker-search') { savingsQuery = event.target.value; document.getElementById('savings-roster').innerHTML = savingsRoster(); }
});
