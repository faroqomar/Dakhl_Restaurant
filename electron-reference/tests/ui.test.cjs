const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const M = require('../app/ui/model.js');
async function setup(t, { data = M.empty(), failSave = false, pdfResult = { ok: true } } = {}) {
  const root = path.join(__dirname, '../app/ui'); const dom = new JSDOM(fs.readFileSync(path.join(root, 'index.html'), 'utf8'), { url: 'file:///app/index.html', runScripts: 'outside-only' }); t.after(() => dom.window.close());
  const { window: w } = dom; w.structuredClone = structuredClone; w.confirm = () => true; w.HTMLElement.prototype.scrollIntoView = () => {}; let stored = data, action, pdfRequests = [];
  w.daftar = { load: async () => ({ ok: true, data: stored, directory: '/test/data' }), save: async d => { if (failSave) return { ok: false, error: 'لا توجد مساحة كافية' }; stored = M.validate(structuredClone(d)); return { ok: true, data: stored }; }, pdf: async request => { pdfRequests.push(structuredClone(request)); return pdfResult; }, onAction: cb => action = cb };
  w.eval(fs.readFileSync(path.join(root, 'model.js'), 'utf8')); w.eval(fs.readFileSync(path.join(root, 'numbers.js'), 'utf8')); w.eval(fs.readFileSync(path.join(root, 'suppliers.js'), 'utf8') + '\n' + fs.readFileSync(path.join(root, 'commerce.js'), 'utf8') + '\n' + fs.readFileSync(path.join(root, 'ux.js'), 'utf8') + '\n' + fs.readFileSync(path.join(root, 'renderer.js'), 'utf8')); await tick();
  function click(selector) { const el = w.document.querySelector(selector); assert.ok(el, selector); el.click(); }
  function value(id, val, change = false) { const el = w.document.getElementById(id); assert.ok(el, id); el.value = val; if (change) el.dispatchEvent(new w.Event('change', { bubbles: true })); }
  async function submit() { const reason=w.document.getElementById('correction-reason'); if(reason && !reason.value) reason.value='تصحيح اختبار موثق'; w.document.querySelector('form').dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true })); await tick(); }
  return { w, click, value, submit, stored: () => stored, pdfRequests, action: name => action(name) };
}
const tick = () => new Promise(resolve => setTimeout(resolve, 5));
test('expense with a new Arabic category persists, notes render safely, edit can move to another day', async t => {
  const ui = await setup(t); ui.click('[data-action="expense"]'); ui.value('category', '__new', true); ui.value('new-category', 'الغاز'); ui.value('amount', '٣٥٬٠٠٠'); ui.value('note', '<img src=x onerror=alert(1)>'); await ui.submit();
  const date = M.dateKey(); assert.equal(ui.stored().days[date].expenses[0].amount, 35000); assert.equal(ui.stored().categories.at(-1).name, 'الغاز'); assert.equal(ui.w.document.querySelector('.note img'), null); assert.equal(ui.w.document.querySelector('.drawer'), null);
  ui.click('[data-action="edit-expense"]'); ui.value('date', '2026-10-04'); ui.value('amount', '40000'); await ui.submit(); assert.equal(ui.stored().days[date].expenses.length, date === '2026-10-04' ? 1 : 0); assert.equal(ui.stored().days['2026-10-04'].expenses[0].amount, 40000);
});
test('save failure keeps the form and input, does not claim saved or mutate current totals', async t => {
  const ui = await setup(t, { failSave: true }); ui.click('[data-action="expense"]'); ui.value('amount', '1000'); await ui.submit();
  assert.equal(ui.w.document.getElementById('amount').value, '1,000'); assert.match(ui.w.document.getElementById('form-error').textContent, /مساحة/); assert.match(ui.w.document.getElementById('save-status').textContent, /تعذّر/); assert.deepEqual(ui.stored(), M.empty());
});
test('cash deposit and withdrawal update total, delete is undoable, and chicken does not affect either total', async t => {
  const ui = await setup(t); ui.click('[data-action="deposit"]'); ui.value('amount', '100000'); await ui.submit(); ui.click('[data-action="withdrawal"]'); ui.value('amount', '25000'); await ui.submit(); assert.equal(M.cash(ui.stored()), 75000);
  ui.click('[data-action="chicken"]'); ui.value('used', '85'); ui.value('left', '206'); await ui.submit(); assert.equal(M.cash(ui.stored()), 75000); assert.equal(M.total(ui.stored(), M.dateKey()), 0);
  ui.click('[data-view="cash"]'); ui.click('[data-action="edit-transaction"]'); ui.click('[data-action="ask-delete"]'); ui.click('[data-action="confirm-delete"]'); await tick(); assert.equal(ui.stored().transactions.length, 1); ui.action('undo'); await tick(); assert.equal(ui.stored().transactions.length, 2); assert.equal(M.cash(ui.stored()), 75000);
});
test('manual total and balance persist; restoring automatic total is explicit', async t => {
  const ui = await setup(t); ui.click('[data-action="total"]'); const checkbox = ui.w.document.getElementById('automatic'); checkbox.checked = false; checkbox.dispatchEvent(new ui.w.Event('change', { bubbles: true })); ui.value('amount', '12000'); await ui.submit(); assert.equal(M.total(ui.stored(), M.dateKey()), 12000);
  ui.click('[data-action="balance"]'); ui.value('amount', '50000'); await ui.submit(); assert.equal(ui.stored().days[M.dateKey()].balance, 50000); assert.equal(M.cash(ui.stored()), 0);
  ui.click('[data-action="total"]'); const automatic = ui.w.document.getElementById('automatic'); automatic.checked = true; automatic.dispatchEvent(new ui.w.Event('change', { bubbles: true })); await ui.submit(); assert.equal(M.total(ui.stored(), M.dateKey()), 0);
});
test('new expenses default to daily; shared allocation must match and cash-linked edits correct both balances', async t => {
  const data = M.empty(), date = M.dateKey(); M.recordRemaining(data, date, 50000);
  data.transactions.push({ id: 'opening', type: 'deposit', date, amount: 100000, note: '', createdAt: new Date().toISOString() });
  const ui = await setup(t, { data }); ui.click('[data-action="expense"]'); assert.equal(ui.w.document.getElementById('payment-source').value, 'daily'); assert.equal(ui.w.document.getElementById('daily-amount').disabled, true);
  ui.value('amount', '30000'); ui.value('payment-source', 'shared', true); assert.equal(ui.w.document.getElementById('cash-amount').disabled, false); ui.value('daily-amount', '18000'); ui.value('cash-amount', '10000'); await ui.submit();
  assert.match(ui.w.document.getElementById('form-error').textContent, /يساوي/); assert.equal(ui.stored().days[date].expenses.length, 0);
  ui.value('cash-amount', '12000'); await ui.submit(); assert.equal(M.remaining(ui.stored(), date), 32000); assert.equal(M.balanceFromRemaining(ui.stored(),date),50000); assert.equal(M.cash(ui.stored()), 88000); assert.equal(M.total(ui.stored(), date), 18000); assert.match(ui.w.document.querySelector('.funding-note').textContent, /مشترك/);
  ui.click('[data-view="cash"]'); ui.click('[data-action="edit-transaction"][data-kind="expense"]'); ui.value('payment-source', 'daily', true); await ui.submit(); assert.equal(M.cash(ui.stored()), 100000); assert.equal(M.remaining(ui.stored(), date), 20000);
});
test('remaining is actual after existing expenses; partial/full deposits affect both balances without double counting', async t => {
  const ui = await setup(t), date = M.dateKey(); ui.click('[data-action="expense"]'); ui.value('amount', '10000'); await ui.submit();
  assert.equal(ui.w.document.querySelector('[data-action="remaining-transfer"]').disabled, true);
  ui.click('[data-action="remaining"]'); ui.value('amount', '50000'); await ui.submit(); assert.equal(M.remaining(ui.stored(), date), 50000); assert.equal(ui.stored().days[date].balance,60000);
  ui.click('[data-action="remaining-transfer"]'); assert.equal(ui.w.document.getElementById('amount').value, '50,000'); ui.value('amount', '50001'); await ui.submit(); assert.match(ui.w.document.getElementById('form-error').textContent, /أكبر/); assert.equal(M.cash(ui.stored()), 0);
  ui.value('amount', '20000'); await ui.submit(); assert.equal(M.cash(ui.stored()), 20000); assert.equal(M.remaining(ui.stored(), date), 30000);
  ui.click('[data-action="remaining-transfer"]'); await ui.submit(); assert.equal(M.cash(ui.stored()), 50000); assert.equal(M.remaining(ui.stored(), date), 0); assert.equal(ui.stored().days[date].balance,60000); assert.equal(M.total(ui.stored(), date), 10000); assert.equal(ui.w.document.querySelector('[data-action="remaining-transfer"]').disabled, true);
});
test('transfer edits and deletion refund daily balance and safe; undo restores the entire movement', async t => {
  const data = M.empty(), date = M.dateKey(); M.recordRemaining(data, date, 50000); M.transferRemaining(data, date, 50000, 'transfer', new Date().toISOString());
  const ui = await setup(t, { data }); ui.click('[data-view="cash"]'); ui.click('[data-action="edit-transaction"][data-kind="transfer"]'); ui.value('amount', '20000'); await ui.submit(); assert.equal(M.cash(ui.stored()), 20000); assert.equal(M.remaining(ui.stored(), date), 30000);
  ui.click('[data-action="edit-transaction"][data-kind="transfer"]'); ui.click('[data-action="ask-delete"]'); ui.click('[data-action="confirm-delete"]'); await tick(); assert.equal(M.cash(ui.stored()), 0); assert.equal(M.remaining(ui.stored(), date), 50000);
  ui.action('undo'); await tick(); assert.equal(M.cash(ui.stored()), 20000); assert.equal(M.remaining(ui.stored(), date), 30000);
});
test('failed transfer save preserves both balances and keeps the input available for retry', async t => {
  const data = M.empty(), date = M.dateKey(); M.recordRemaining(data, date, 50000);
  const ui = await setup(t, { data, failSave: true }); ui.click('[data-action="remaining-transfer"]'); ui.value('amount', '20000'); await ui.submit();
  assert.match(ui.w.document.getElementById('form-error').textContent, /مساحة/); assert.equal(M.cash(ui.stored()), 0); assert.equal(M.remaining(ui.stored(), date), 50000); assert.equal(ui.stored().transfers.length, 0); assert.equal(ui.w.document.getElementById('amount').value, '20,000');
});
async function addSupplier(ui, opening = '100000') {
  ui.click('[data-view="suppliers"]'); ui.click('[data-action="supplier-new"]'); ui.value('supplier-name','مورد المواد'); ui.value('amount',opening); await ui.submit(); return ui.stored().suppliers[0];
}
function lineValue(ui, cls, value, change = false, index = 0) { ui.value(ui.w.document.querySelectorAll(cls)[index].id, value, change); }
async function addInvoice(ui, { number = 'A-1', price = '5000', qty = '2.5', paid = '0' } = {}) {
  ui.click('[data-action="invoice-new"]'); ui.value('invoice-number',number); lineValue(ui,'.line-name-input','رز',true); lineValue(ui,'.line-unit','كيلو'); lineValue(ui,'.line-quantity',qty); lineValue(ui,'.line-price',price); ui.value('amount',paid); await ui.submit();
}
test('supplier, permanent material, invoice and shared payment are saved together; opening and current balances remain distinct', async t => {
  const data = M.empty(), date = M.dateKey(); M.recordRemaining(data,date,50000); data.transactions.push({ id:'cash',date,type:'deposit',amount:200000,note:'',createdAt:new Date().toISOString() });
  const ui = await setup(t,{data}); const supplier = await addSupplier(ui);
  ui.click('[data-action="supplier-tab"][data-tab="materials"]'); ui.click('[data-action="material-new"]'); ui.value('material-name','رز'); ui.value('unit','كيلو'); ui.value('amount','40000'); ui.value('piece-price','5000'); await ui.submit(); assert.equal(ui.stored().materials.length,1);
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-new"]'); ui.value('invoice-number','A-1'); lineValue(ui,'.line-name-input','رز',true); assert.equal(ui.w.document.querySelector('.line-price').value,'5,000'); lineValue(ui,'.line-quantity','2.5'); ui.value('amount','2500'); ui.value('payment-source','shared',true); ui.value('daily-amount','1500'); ui.value('cash-amount','1000'); await ui.submit();
  assert.equal(ui.stored().invoices.length,1); assert.equal(M.invoiceTotal(ui.stored().invoices[0]),12500); assert.equal(M.supplierBalance(ui.stored(),supplier.id),110000); assert.equal(M.total(ui.stored(),date),1500); assert.equal(M.cash(ui.stored()),199000); assert.equal(M.remaining(ui.stored(),date),48500);
  ui.click('[data-view="expenses"]'); assert.equal(ui.w.document.querySelectorAll('[data-action="payment-edit"]').length,2); assert.match(ui.w.document.querySelector('.note').textContent,/مورد المواد/);
  ui.click('[data-view="cash"]'); assert.ok(ui.w.document.querySelector('[data-kind="supplier-payment"]')); ui.click('[data-kind="supplier-payment"]'); assert.equal(ui.w.document.getElementById('amount').value,'2,500');
});
test('daily expenses keep cash purchases separate and account statement filters category, dates, and source', async t => {
  const ui=await setup(t); ui.click('[data-action="expense"]'); ui.value('category','bread'); ui.value('amount','30000'); ui.value('payment-source','shared',true); ui.value('daily-amount','18000'); ui.value('cash-amount','12000'); await ui.submit();
  assert.equal(M.total(ui.stored(),M.dateKey()),18000); assert.equal(M.dailySpent(ui.stored(),M.dateKey()),18000);
  ui.click('[data-view="expenses"]'); const body=ui.w.document.querySelector('main').textContent; assert.match(body,/مجموع مصاريف القاصة/); assert.match(body,/18,000/); assert.match(body,/12,000/);
  ui.click('[data-view="statement"]'); ui.value('statement-category','bread',true); ui.value('statement-source','cash',true); const statement=ui.w.document.querySelector('main').textContent; assert.match(statement,/12,000/); assert.match(statement,/حصة اليومي/); assert.match(statement,/أعلى المصاريف حسب الخانة/);
});
test('new invoice materials become reusable; template edits do not rewrite saved invoice details', async t => {
  const ui=await setup(t); await addSupplier(ui); await addInvoice(ui); assert.equal(ui.stored().materials[0].name,'رز'); assert.equal(ui.stored().payments.length,0); assert.equal(M.total(ui.stored(),M.dateKey()),0);
  ui.click('[data-action="supplier-tab"][data-tab="materials"]'); ui.click('[data-action="material-edit"]'); ui.value('amount','70000'); ui.value('piece-price','7000'); ui.value('material-name','رز جديد'); await ui.submit(); assert.equal(ui.stored().invoices[0].lines[0].price,5000);
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-edit"]'); await ui.submit(); assert.equal(ui.stored().materials.length,2); assert.equal(ui.stored().invoices[0].lines[0].name,'رز');
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-new"]'); lineValue(ui,'.line-name-input','رز جديد',true); assert.equal(ui.w.document.querySelector('.line-price').value,'7,000'); assert.equal(ui.w.document.querySelector('.line-carton-price').value,'70,000'); assert.equal(ui.w.document.querySelector('.line-unit').value,'كيلو');
});
test('shared catalog fills carton and piece prices for invoices across suppliers', async t => {
  const ui=await setup(t); await addSupplier(ui); ui.click('[data-view="materials"]'); ui.click('[data-action="material-new"]'); ui.value('material-name','دجاج'); ui.value('unit','كارتون'); ui.value('amount','60000'); ui.value('piece-price','5000'); await ui.submit();
  ui.click('[data-view="suppliers"]'); ui.click('[data-action="supplier-new"]'); ui.value('supplier-name','مورد ثاني'); ui.value('amount','0'); await ui.submit();
  ui.click('[data-view="invoices"]'); ui.click('[data-action="invoice-new"]'); ui.value('invoice-number','C-1'); lineValue(ui,'.line-name-input','دجاج',true);
  assert.equal(ui.w.document.querySelector('.line-carton-price').value,'60,000'); assert.equal(ui.w.document.querySelector('.line-piece-price').value,'5,000'); assert.equal(ui.w.document.querySelector('.line-unit').value,'كارتون');
});
test('duplicate invoice and overpayment keep all input and never partly add materials or payments', async t => {
  const ui=await setup(t); await addSupplier(ui); await addInvoice(ui); const before=structuredClone(ui.stored());
  await addInvoice(ui,{number:'A-1',paid:'100'}); assert.match(ui.w.document.getElementById('form-error').textContent,/رقم القائمة/); assert.deepEqual(ui.stored(),before);
  ui.value('invoice-number','A-2'); ui.value('amount','120000'); await ui.submit(); assert.match(ui.w.document.getElementById('form-error').textContent,/يتجاوز/); assert.deepEqual(ui.stored(),before);
});
test('invoice settlements can be partial or full, opening debt is a separate target, and deleting a payment refunds funding', async t => {
  const ui=await setup(t); const supplier=await addSupplier(ui); await addInvoice(ui); const invoice=ui.stored().invoices[0];
  ui.click('[data-action="invoice-pay"]'); assert.equal(ui.w.document.getElementById('invoice-id').value,invoice.id); assert.equal(ui.w.document.getElementById('amount').value,'12,500'); ui.value('amount','5000'); ui.value('payment-source','cash',true); await ui.submit(); assert.equal(M.invoiceDue(ui.stored(),invoice.id),7500); assert.equal(M.cash(ui.stored()),-5000);
  ui.click('[data-action="invoice-pay"]'); await ui.submit(); assert.equal(M.invoiceDue(ui.stored(),invoice.id),0); assert.equal(M.supplierBalance(ui.stored(),supplier.id),100000);
  ui.click('[data-view="payments"]'); ui.click('[data-action="payment-edit"]'); ui.click('[data-action="ask-delete"]'); ui.click('[data-action="confirm-delete"]'); await tick(); assert.equal(ui.stored().payments.length,1); assert.equal(M.invoiceDue(ui.stored(),invoice.id),7500);
  ui.click('[data-action="payment-new"]'); assert.equal(ui.w.document.getElementById('invoice-id').value,''); ui.value('amount','20000'); await ui.submit(); assert.equal(M.openingDue(ui.stored(),supplier.id),80000);
});
test('paid invoice deletion is blocked; removing settlement first allows deletion and undo restores consistent records', async t => {
  const ui=await setup(t); await addSupplier(ui); await addInvoice(ui,{paid:'5000'}); ui.click('[data-action="invoice-edit"]'); ui.click('[data-action="ask-delete"]'); ui.click('[data-action="confirm-delete"]'); await tick(); assert.match(ui.w.document.getElementById('form-error').textContent,/تسديدات/); assert.equal(ui.stored().invoices.length,1);
  ui.click('[data-action="close-drawer"]'); ui.click('[data-view="payments"]'); ui.click('[data-action="payment-edit"]'); ui.click('[data-action="ask-delete"]'); ui.click('[data-action="confirm-delete"]'); await tick(); assert.equal(ui.stored().payments.length,0);
  ui.click('[data-view="suppliers"]'); ui.click('[data-action="invoice-edit"]'); ui.click('[data-action="ask-delete"]'); ui.click('[data-action="confirm-delete"]'); await tick(); assert.equal(ui.stored().invoices.length,0); ui.action('undo'); await tick(); assert.equal(ui.stored().invoices.length,1);
});
test('failed invoice save preserves supplier, catalog, expenses and balances together', async t => {
  const data=M.empty(); data.suppliers.push({id:'supplier',name:'المورد',phone:'',note:'',categoryId:'market',openingBalance:0,materials:[]}); const ui=await setup(t,{data,failSave:true}); ui.click('[data-view="suppliers"]'); await addInvoice(ui,{paid:'5000'}); assert.match(ui.w.document.getElementById('form-error').textContent,/مساحة/); assert.deepEqual(ui.stored(),data); assert.equal(ui.w.document.querySelector('.line-name-input').value,'رز'); assert.equal(ui.w.document.getElementById('amount').value,'5,000');
});
test('category creation chooses a type and existing categories can switch type with undo and reload', async t => {
  const ui = await setup(t); ui.click('[data-view="categories"]'); ui.click('[data-action="category"]');
  assert.equal(ui.w.document.getElementById('category-type').value, 'additional');
  ui.value('name', 'الغاز'); ui.value('category-type', 'primary'); await ui.submit();
  const gas = ui.stored().categories.at(-1); assert.equal(gas.type, 'primary');
  const select = ui.w.document.querySelector('[data-category-id="samoon"]'); select.focus(); select.value = 'additional'; select.dispatchEvent(new ui.w.Event('change', { bubbles: true })); await tick();
  assert.equal(ui.stored().categories[0].type, 'additional'); assert.equal(ui.w.document.activeElement.dataset.categoryId, 'samoon');
  const reloaded = await setup(t, { data: structuredClone(ui.stored()) }); reloaded.click('[data-view="categories"]');
  assert.equal(reloaded.w.document.querySelector('[data-category-id="samoon"]').value, 'additional'); assert.equal(reloaded.w.document.querySelector(`[data-category-id="${gas.id}"]`).value, 'primary');
  ui.action('undo'); await tick(); assert.equal(ui.stored().categories[0].type, 'primary');
});
test('failed category type save restores the selection and preserves the saved data', async t => {
  const ui = await setup(t, { failSave: true }); ui.click('[data-view="categories"]');
  const select = ui.w.document.querySelector('[data-category-id="bread"]'); select.value = 'additional'; select.dispatchEvent(new ui.w.Event('change', { bubbles: true })); await tick();
  assert.equal(select.value, 'primary'); assert.equal(select.disabled, false); assert.equal(ui.stored().categories[1].type, 'primary'); assert.match(ui.w.document.getElementById('save-status').textContent, /تعذّر/);
});
test('excess settlement shows live split, reduces debts, and editing/deleting restores the correct amounts and source', async t => {
  const data = M.empty(), date = M.dateKey(); M.recordRemaining(data, date, 100000);
  const ui = await setup(t, { data }); const supplier = await addSupplier(ui); await addInvoice(ui); const invoice = ui.stored().invoices[0];
  ui.click('[data-action="invoice-pay"]'); ui.value('amount', '32500'); ui.w.document.getElementById('amount').dispatchEvent(new ui.w.Event('input', { bubbles: true }));
  assert.match(ui.w.document.getElementById('payment-split').textContent, /12,500.*20,000.*80,000/);
  ui.value('payment-source', 'shared', true); ui.value('daily-amount', '20000'); ui.value('cash-amount', '12500'); await ui.submit();
  assert.equal(M.invoiceDue(ui.stored(), invoice.id), 0); assert.equal(M.debtAvailable(ui.stored(), supplier.id), 80000); assert.equal(M.total(ui.stored(), date), 20000); assert.equal(M.cash(ui.stored()), -12500); assert.equal(M.remaining(ui.stored(), date), 80000);
  assert.match(ui.w.document.querySelector('.supplier-summary').textContent, /الديون الباقية عليك.*80,000/); assert.doesNotMatch(ui.w.document.querySelector('main').textContent, /الرصيد الافتتاحي/);
  ui.click('[data-view="payments"]'); assert.match(ui.w.document.querySelector('.payments-table').textContent, /للقائمة 12,500.*للديون 20,000/);
  ui.click('[data-action="payment-edit"]'); ui.value('amount', '10000'); ui.value('payment-source', 'daily', true); await ui.submit();
  assert.equal(M.invoiceDue(ui.stored(), invoice.id), 2500); assert.equal(M.debtAvailable(ui.stored(), supplier.id), 100000); assert.equal(M.cash(ui.stored()), 0); assert.equal(M.remaining(ui.stored(), date), 90000);
  ui.click('[data-action="payment-edit"]'); ui.click('[data-action="ask-delete"]'); ui.click('[data-action="confirm-delete"]'); await tick(); assert.equal(M.invoiceDue(ui.stored(), invoice.id), 12500); assert.equal(M.total(ui.stored(), date), 0); assert.equal(M.remaining(ui.stored(), date), 100000);
  ui.action('undo'); await tick(); assert.equal(M.total(ui.stored(), date), 10000);
});
test('new invoice accepts extra debt payment atomically, and added debt is editable until its repayment would exceed it', async t => {
  const ui = await setup(t); const supplier = await addSupplier(ui, '100000'); await addInvoice(ui, { paid: '32500' });
  assert.equal(ui.stored().payments.length, 1); assert.equal(ui.stored().payments[0].invoiceAmount, 12500); assert.equal(ui.stored().payments[0].debtAmount, 20000); assert.equal(M.debtAvailable(ui.stored(), supplier.id), 80000);
  ui.click('[data-action="supplier-tab"][data-tab="debts"]'); ui.click('[data-action="debt-new"]'); ui.value('amount', '50000'); ui.value('note', 'باقي سابق'); await ui.submit(); assert.equal(M.debtAvailable(ui.stored(), supplier.id), 130000); assert.equal(M.total(ui.stored(), M.dateKey()), 32500);
  ui.click('[data-action="debt-edit"]'); ui.value('amount', '40000'); await ui.submit(); assert.equal(M.debtAvailable(ui.stored(), supplier.id), 120000);
  ui.click('[data-action="payment-new"]'); ui.value('amount', '120000'); await ui.submit(); assert.equal(M.debtAvailable(ui.stored(), supplier.id), 0);
  ui.click('[data-action="debt-edit"]'); ui.click('[data-action="ask-delete"]'); ui.click('[data-action="confirm-delete"]'); await tick(); assert.match(ui.w.document.getElementById('form-error').textContent, /الديون/); assert.equal(ui.stored().debts.length, 1);
});
test('excess payment save failure never partly pays the bill, debt, or source and keeps the input', async t => {
  const data = M.empty(), date = M.dateKey(); data.suppliers.push({ id: 'supplier', name: 'المورد', phone: '', note: '', categoryId: 'market', openingBalance: 100000, materials: [] });
  const ui = await setup(t, { data, failSave: true }); ui.click('[data-view="suppliers"]'); await addInvoice(ui, { paid: '32500' });
  assert.match(ui.w.document.getElementById('form-error').textContent, /مساحة/); assert.deepEqual(ui.stored(), data); assert.equal(ui.w.document.getElementById('amount').value, '32,500'); assert.equal(M.total(ui.stored(), date), 0);
});
test('all numeric forms group English digits immediately, preserve live calculations, and save numeric values', async t => {
  const ui = await setup(t);
  function input(id, value) { ui.value(id, value); ui.w.document.getElementById(id).dispatchEvent(new ui.w.InputEvent('input', { bubbles: true })); }
  ui.click('[data-action="expense"]'); input('amount', '٥٠٠٠٠٠'); assert.equal(ui.w.document.getElementById('amount').value, '500,000');
  ui.value('payment-source', 'shared', true); assert.equal(ui.w.document.getElementById('daily-amount').value, '500,000');
  input('daily-amount', '٣٠٠٠٠٠'); input('cash-amount', '۲۰۰۰۰۰'); assert.match(ui.w.document.getElementById('funding-total').textContent, /500,000 من 500,000/); await ui.submit();
  assert.equal(ui.stored().days[M.dateKey()].expenses[0].amount, 500000); assert.equal(M.cash(ui.stored()), -200000);
  ui.click('[data-action="edit-expense"]'); assert.equal(ui.w.document.getElementById('amount').value, '500,000'); assert.equal(ui.w.document.getElementById('daily-amount').value, '300,000'); ui.click('[data-action="close-drawer"]');
  ui.click('[data-action="chicken"]'); input('used', '١٢٣٤'); assert.equal(ui.w.document.getElementById('used').value, '1,234'); await ui.submit(); assert.equal(ui.stored().days[M.dateKey()].chickenUsed, 1234);
  ui.click('[data-action="balance"]'); input('amount', '-٥٠٠٠'); assert.equal(ui.w.document.getElementById('amount').value, '-5,000'); await ui.submit(); assert.equal(ui.stored().days[M.dateKey()].balance, -5000);
  await addSupplier(ui); ui.click('[data-action="supplier-edit"]'); input('phone', '٠٧٧٠١٢٣٤٥٦٧'); assert.equal(ui.w.document.getElementById('phone').value, '07701234567'); await ui.submit();
  ui.click('[data-action="invoice-new"]'); input('invoice-number', 'A-٠٠١٢'); lineValue(ui, '.line-name-input', 'رز', true); input(ui.w.document.querySelector('.line-quantity').id, '١٢٣٤٫٥٠٠'); input(ui.w.document.querySelector('.line-price').id, '۵۰۰۰');
  assert.equal(ui.w.document.querySelector('.line-quantity').value, '1,234.500'); assert.equal(ui.w.document.querySelector('.line-price').value, '5,000'); assert.equal(ui.w.document.getElementById('invoice-total').textContent, '6,172,500'); await ui.submit();
  assert.equal(ui.stored().invoices[0].number, 'A-0012'); assert.equal(ui.stored().invoices[0].lines[0].quantity, 1234.5);
  ui.click('[data-action="supplier-tab"][data-tab="debts"]'); ui.click('[data-action="debt-new"]'); input('amount', '٥٠٠٠٠٠'); await ui.submit(); assert.equal(ui.stored().debts[0].amount, 500000);
});
test('normalizing a legacy Arabic invoice number does not create a second invoice with the same visible number', async t => {
  const data = M.empty(), date = M.dateKey(); data.suppliers.push({ id: 'supplier', name: 'المورد', phone: '', note: '', categoryId: 'market', openingBalance: 0, materials: [{ id: 'rice', name: 'رز ١', unit: 'كيلو', price: 5000, archived: false }] });
  data.invoices.push({ id: 'invoice', supplierId: 'supplier', number: '٠٠١٢', date, lines: [{ materialId: 'rice', name: 'رز ١', unit: 'كيلو', quantity: 1, price: 5000 }], note: '', createdAt: new Date().toISOString() });
  const ui = await setup(t, { data }); ui.click('[data-view="suppliers"]'); assert.match(ui.w.document.querySelector('.supplier-table').textContent, /0012/);
  ui.click('[data-view="materials"]'); ui.click('[data-action="material-new"]'); ui.value('material-name','رز ١'); ui.value('unit','كيلو'); ui.value('amount','0'); ui.value('piece-price','5000'); await ui.submit();
  ui.click('[data-view="suppliers"]'); ui.click('[data-action="invoice-new"]'); ui.value('invoice-number', '0012'); lineValue(ui, '.line-name-input', 'رز ١', true); assert.equal(ui.w.document.querySelector('.line-price').value, '5,000'); await ui.submit();
  assert.match(ui.w.document.getElementById('form-error').textContent, /رقم القائمة/); assert.equal(ui.stored().invoices.length, 1);
});
test('daily invoice date correction previews a range, blocks overlaps, preserves records and is undoable', async t => {
  const data = M.empty();
  for (const [date, amount] of [['2026-10-02', 10000], ['2026-10-03', 20000], ['2026-10-04', 30000]]) data.days[date] = { ...M.day(data, date), chickenUsed: amount / 1000, expenses: [{ id: 'e-' + date, categoryId: 'bread', amount, note: '', funding: { source: 'daily', dailyAmount: amount, cashAmount: 0 } }] };
  const ui = await setup(t, { data }); ui.value('selected-date', '2026-10-02', true); ui.click('[data-action="day-date"]'); ui.value('correct-date', '2026-10-03', true);
  assert.match(ui.w.document.getElementById('date-preview').textContent, /بيه سجل آخر/); assert.equal(ui.w.document.querySelector('[type=submit]').disabled, true);
  const check = ui.w.document.getElementById('shift-following'); check.checked = true; check.dispatchEvent(new ui.w.Event('change', { bubbles: true }));
  assert.equal(ui.w.document.getElementById('range-end').value, '2026-10-04'); assert.match(ui.w.document.getElementById('date-preview').textContent, /3 يوم/); assert.equal(ui.w.document.querySelector('[type=submit]').disabled, false);
  assert.equal(ui.w.document.querySelectorAll('#date-preview tbody tr').length, 3); await ui.submit();
  assert.equal(ui.stored().days['2026-10-02'], undefined); assert.equal(ui.stored().days['2026-10-03'].expenses[0].amount, 10000); assert.equal(ui.stored().days['2026-10-05'].expenses[0].amount, 30000); assert.equal(ui.w.document.getElementById('selected-date').value, '2026-10-03');
  ui.action('undo'); await tick(); assert.deepEqual(ui.stored(), M.validate(data));
});
test('failed date correction preserves the complete original day and keeps the chosen dates available', async t => {
  const data = M.empty(); data.days['2026-10-02'] = { ...M.day(data, '2026-10-02'), chickenUsed: 85, balance: 500000 };
  const ui = await setup(t, { data, failSave: true }); ui.value('selected-date', '2026-10-02', true); ui.click('[data-action="day-date"]'); ui.value('correct-date', '2026-10-03', true); await ui.submit();
  assert.match(ui.w.document.getElementById('form-error').textContent, /مساحة/); assert.equal(ui.w.document.getElementById('correct-date').value, '2026-10-03'); assert.deepEqual(ui.stored(), data);
});

test('PDF controls export the selected saved day and supplier invoice without saving or mutating account records', async t => {
  const { fixture } = require('./pdf-fixture.cjs'), data = fixture(), ui = await setup(t, { data });
  ui.value('selected-date', '2026-10-04', true); ui.click('[data-action="daily-pdf"]'); await tick();
  assert.deepEqual(ui.pdfRequests[0], { kind: 'daily', date: '2026-10-04' }); assert.match(ui.w.document.getElementById('toast').textContent, /تم حفظ الملف/);
  ui.click('[data-view="suppliers"]'); ui.click('[data-action="invoice-pdf"]'); await tick(); assert.deepEqual(ui.pdfRequests[1], { kind: 'invoice', id: 'invoice' }); assert.deepEqual(ui.stored(), data);
});
test('PDF cancellation is quiet and failure leaves account data intact and the export button ready to retry', async t => {
  for (const pdfResult of [{ ok: true, canceled: true }, { ok: false, error: 'لا توجد مساحة للحفظ' }]) {
    const ui = await setup(t, { pdfResult }); ui.click('[data-action="daily-pdf"]'); await tick();
    assert.equal(ui.w.document.querySelector('[data-action="daily-pdf"]').disabled, false); assert.deepEqual(ui.stored(), M.empty());
    const toast = ui.w.document.getElementById('toast').textContent;
    if (pdfResult.canceled) assert.equal(toast, ''); else assert.match(toast, /تعذّر تصدير PDF.*مساحة/);
  }
});

test('failed remainder save keeps the old daily total and cash intact; retry inputs and undo restore the complete record', async t => {
  const data=M.empty(),date=M.dateKey();data.days[date]={...M.day(data,date),balance:123000};
  const failed=await setup(t,{data,failSave:true});failed.click('[data-action="remaining"]');failed.value('amount','50000');await failed.submit();
  assert.equal(failed.stored().days[date].balance,123000);assert.equal(M.remaining(failed.stored(),date),null);assert.equal(M.cash(failed.stored()),0);assert.equal(failed.w.document.getElementById('amount').value,'50,000');
  const ui=await setup(t,{data});ui.click('[data-action="remaining"]');ui.value('amount','50000');await ui.submit();assert.equal(ui.stored().days[date].balance,50000);
  ui.action('undo');await tick();assert.deepEqual(ui.stored(),M.validate(data));
});

async function addSaleProduct(ui) {
 ui.click('[data-view="inventory"]');ui.click('[data-action="product-new"]');ui.value('product-name','صنف تجريبي');ui.value('amount','٥٠٠٠');ui.value('opening-quantity','١٠');await ui.submit();return ui.stored().products[0];
}
function saleInput(ui,id,value) { ui.value(id,value);ui.w.document.getElementById(id).dispatchEvent(new ui.w.Event('input',{bubbles:true})); }
test('inventory and sales UI complete a cash sale, preserve draft on navigation, export receipt, void and undo',async t=>{
 const ui=await setup(t),product=await addSaleProduct(ui);assert.equal(M.stock(ui.stored(),product.id),10);
 ui.click('[data-view="sales"]');ui.click(`[data-action="sale-add"][data-id="${product.id}"]`);ui.click('[data-view="expenses"]');ui.click('[data-view="sales"]');assert.match(ui.w.document.getElementById('cart-lines').textContent,/صنف تجريبي/);
 ui.click(`[data-action="sale-add"][data-id="${product.id}"]`);saleInput(ui,'sale-discount','١٠٠٠');ui.value('sale-order-type','سفري',true);assert.equal(ui.w.document.getElementById('sale-paid'),null);assert.equal(ui.w.document.getElementById('checkout-button').disabled,false);ui.click('[data-action="sale-complete"]');await tick();
 assert.equal(ui.stored().sales.length,1);assert.equal(M.stock(ui.stored(),product.id),8);assert.equal(M.salesTotal(ui.stored(),M.dateKey()),9000);assert.ok(ui.w.document.querySelector('.sale-success')); ui.click('[data-action="sale-receipt"]'); assert.match(ui.w.document.querySelector('.sale-receipt').textContent,/9,000/);
 ui.click('[data-action="sale-pdf"]');await tick();assert.deepEqual(ui.pdfRequests[0],{kind:'sale',id:ui.stored().sales[0].id});ui.click('[data-action="sale-void"]');ui.value('void-reason','رجع الزبون الطلب');await ui.submit();assert.equal(M.stock(ui.stored(),product.id),10);assert.equal(ui.stored().sales[0].status,'void');
 ui.action('undo');await tick();assert.equal(M.stock(ui.stored(),product.id),10);assert.equal(ui.stored().sales[0].status,'void');
 ui.click('[data-view="sale-history"]');assert.match(ui.w.document.getElementById('main').textContent,/9,000/);ui.click('[data-action="sale-receipt"]');assert.match(ui.w.document.querySelector('.sale-receipt').textContent,/صنف تجريبي/);
});
test('failed sale keeps stock and all entered quantities, discount, payment and note for retry',async t=>{
 const {fixture}=require('./commerce-fixture.cjs');const data=fixture(),ui=await setup(t,{data,failSave:true});ui.click('[data-view="sales"]');ui.value('sale-date','2026-10-26',true);ui.click('[data-action="sale-add"][data-id="p0"]');saleInput(ui,'sale-discount','1000');ui.value('sale-order-type','توصيل',true);ui.click('[data-action="sale-complete"]');await tick();assert.deepEqual(ui.stored(),data);assert.equal(M.stock(ui.stored(),'p0'),20);assert.equal(ui.w.document.getElementById('sale-discount').value,'1,000');assert.equal(ui.w.document.getElementById('sale-order-type').value,'توصيل');assert.match(ui.w.document.getElementById('toast').textContent,/مساحة/);
});
test('stock adjustments reject shortages, product archive preserves history, shortcut choices persist after reload',async t=>{
 const ui=await setup(t),p=await addSaleProduct(ui);ui.click('[data-action="stock-new"]');ui.value('stock-kind','adjustment');ui.value('stock-quantity','11');await ui.submit();assert.match(ui.w.document.getElementById('form-error').textContent,/المخزون/);assert.equal(M.stock(ui.stored(),p.id),10);ui.value('stock-quantity','3');await ui.submit();assert.equal(M.stock(ui.stored(),p.id),7);
 ui.click('[data-action="product-edit"]');ui.w.document.querySelector('[name="archived"]').checked=true;await ui.submit();ui.click('[data-view="sales"]');assert.equal(ui.w.document.querySelector('[data-action="sale-add"]'),null);
 ui.click('[data-view="settings"]');['inventory','cash','materials','sales','settings',''].forEach((v,i)=>ui.value('shortcut-'+i,v));ui.w.document.getElementById('shortcut-form').dispatchEvent(new ui.w.Event('submit',{bubbles:true,cancelable:true}));await tick();assert.deepEqual(Array.from(ui.stored().preferences.shortcuts),['inventory','cash','materials','sales','settings','']);
 const reload=await setup(t,{data:structuredClone(ui.stored())});reload.click('.shortcut-links [data-view="materials"]');assert.match(reload.w.document.getElementById('main').textContent,/المواد والأسعار/);assert.equal(reload.w.document.querySelectorAll('.shortcut-links .shortcut').length,5);
});
test('order-type settings validate duplicates, persist custom choices and leave saved sales unchanged',async t=>{
 const {fixture}=require('./commerce-fixture.cjs');const ui=await setup(t,{data:fixture()});ui.click('[data-view="settings"]');ui.value('order-types-list','محلي\nمحلي');ui.w.document.getElementById('order-types-form').dispatchEvent(new ui.w.Event('submit',{bubbles:true,cancelable:true}));await tick();assert.deepEqual(Array.from(ui.stored().preferences.orderTypes),['صالة','سفري','توصيل']);assert.match(ui.w.document.getElementById('toast').textContent,/مكررة/);
 ui.value('order-types-list','صالة\nسفري\nتوصيل خاص');ui.w.document.getElementById('order-types-form').dispatchEvent(new ui.w.Event('submit',{bubbles:true,cancelable:true}));await tick();ui.click('[data-view="sales"]');ui.value('sale-date','2026-10-26',true);ui.value('sale-order-type','توصيل خاص',true);ui.click('[data-action="sale-add"][data-id="p0"]');assert.equal(ui.w.document.getElementById('checkout-button').disabled,false);ui.click('[data-action="sale-complete"]');await tick();assert.equal(ui.stored().sales[0].paid,12000);assert.equal(ui.stored().sales[0].orderType,'توصيل خاص');ui.click('[data-action="sale-receipt"]');assert.match(ui.w.document.querySelector('.sale-receipt').textContent,/توصيل خاص/);ui.click('[data-action="close-drawer"]');
 ui.click('[data-view="settings"]');ui.value('order-types-list','طلبات');ui.w.document.getElementById('order-types-form').dispatchEvent(new ui.w.Event('submit',{bubbles:true,cancelable:true}));await tick();assert.equal(ui.stored().sales[0].orderType,'توصيل خاص');ui.click('[data-view="sales"]');assert.equal(ui.w.document.getElementById('sale-order-type').value,'طلبات');
});

test('audit regression: first purchase guides through supplier creation and opens invoice',async t=>{
 const ui=await setup(t);ui.click('[data-view="invoices"]');ui.click('[data-action="invoice-new"]');assert.equal(ui.w.document.getElementById('drawer-title').textContent,'إضافة مورد');ui.value('supplier-name','المورد الأول');await ui.submit();assert.ok(ui.w.document.getElementById('invoice-number'));assert.equal(ui.stored().suppliers.length,1);
});
test('audit regression: statement shares are correct and old expense opens at its original date',async t=>{
 const data=M.empty();data.days['2026-10-25']={...M.day(data,'2026-10-25'),expenses:[{id:'old-shared',categoryId:'bread',amount:30000,note:'',funding:{source:'shared',dailyAmount:18000,cashAmount:12000}}]};const ui=await setup(t,{data});ui.click('[data-view="statement"]');ui.value('statement-from','2026-10-01');ui.value('statement-to','2026-10-26');ui.value('statement-source','cash');ui.click('[data-action="apply-filter"]');const stats=ui.w.document.querySelector('.invoice-analysis-summary').textContent;assert.match(stats,/حصة اليومي0/);assert.match(stats,/حصة القاصة12,000/);ui.click('[data-action="edit-expense"]');assert.equal(ui.w.document.getElementById('amount').value,'30,000');assert.equal(ui.w.document.getElementById('date').value,'2026-10-25');ui.value('amount','40000');ui.value('daily-amount','28000');await ui.submit();assert.equal(ui.stored().days['2026-10-25'].expenses[0].amount,40000);assert.ok(!ui.stored().days['2026-10-26']);
});
test('audit regression: dirty form Escape can be cancelled and completed sale undo preserves issued record',async t=>{
 const {fixture}=require('./commerce-fixture.cjs');const ui=await setup(t,{data:fixture()});ui.click('[data-action="expense"]');ui.value('amount','1000');ui.w.confirm=()=>false;ui.w.document.dispatchEvent(new ui.w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));assert.equal(ui.w.document.getElementById('amount').value,'1000');ui.w.confirm=()=>true;ui.click('[data-action="close-drawer"]');ui.click('[data-view="sales"]');ui.click('[data-action="sale-add"][data-id="p0"]');ui.click('[data-action="sale-complete"]');await tick();assert.equal(ui.stored().sales.length,1);assert.ok(ui.w.document.querySelector('.paid-receipt'));ui.click('[data-action="close-drawer"]');ui.w.document.getElementById('main').focus();ui.action('undo');assert.ok(ui.w.document.getElementById('void-reason'));assert.equal(ui.stored().sales.length,1);ui.value('void-reason','إلغاء صريح');await ui.submit();assert.equal(ui.stored().sales[0].status,'void');assert.equal(ui.stored().sales[0].number,'S-000001');
});
test('audit regression: blank sale date blocks checkout and fractional inventory is sellable',async t=>{
 const {fixture}=require('./commerce-fixture.cjs');const data=fixture();data.stockEntries.find(e=>e.productId==='p0').quantity=.5;const ui=await setup(t,{data});ui.click('[data-view="sales"]');ui.value('sale-date','2026-10-26',true);ui.click('[data-action="sale-add"][data-id="p0"]');assert.equal(ui.w.document.querySelector('[data-cart-quantity="p0"]').value,'0.5');ui.value('sale-date','',true);assert.equal(ui.w.document.getElementById('checkout-button').disabled,true);assert.equal(ui.stored().sales.length,0);
});
test('audit regression: current bill retains quoted price and archived line remains removable',async t=>{
 const {fixture}=require('./commerce-fixture.cjs');const ui=await setup(t,{data:fixture()});ui.click('[data-view="sales"]');ui.click('[data-action="sale-add"][data-id="p0"]');ui.click('[data-view="inventory"]');ui.click('[data-action="product-edit"][data-id="p0"]');ui.value('amount','15000');await ui.submit();ui.click('[data-view="sales"]');assert.equal(ui.w.document.getElementById('sale-total').textContent,'12,000');ui.click('[data-action="sale-complete"]');await tick();assert.equal(ui.stored().sales[0].lines[0].price,12000);ui.click('[data-action="close-drawer"]');ui.click('[data-action="sale-add"][data-id="p0"]');ui.click('[data-view="inventory"]');ui.click('[data-action="product-edit"][data-id="p0"]');ui.w.document.querySelector('[name="archived"]').checked=true;await ui.submit();ui.click('[data-view="sales"]');assert.equal(ui.w.document.getElementById('checkout-button').disabled,true);ui.click('[data-action="sale-remove"][data-id="p0"]');assert.equal(ui.w.document.querySelectorAll('.cart-line').length,0);
});
test('audit regression: invalid filter ranges retain current results and custom categories archive safely',async t=>{
 const data=M.empty();data.categories.push({id:'custom',name:'غاز',type:'additional'});const ui=await setup(t,{data});ui.click('[data-view="statement"]');ui.value('statement-from','2026-10-30');ui.value('statement-to','2026-10-01');ui.click('[data-action="apply-filter"]');assert.match(ui.w.document.getElementById('toast').textContent,/قبل/);ui.click('[data-view="categories"]');ui.click('[data-action="category-edit"]');ui.value('name','الغاز الجديد');ui.w.document.querySelector('[name="archived"]').checked=true;await ui.submit();assert.equal(ui.stored().categories.at(-1).name,'الغاز الجديد');assert.equal(ui.stored().categories.at(-1).archived,true);ui.click('[data-view="expenses"]');ui.click('[data-action="expense"]');assert.ok(![...ui.w.document.getElementById('category').options].some(o=>o.value==='custom'));
});
test('audit regression: corrections require a reason and retain before/after history',async t=>{
 const ui=await setup(t);ui.click('[data-action="total"]');const automatic=ui.w.document.getElementById('automatic');automatic.checked=false;automatic.dispatchEvent(new ui.w.Event('change',{bubbles:true}));ui.value('amount','1234');ui.w.document.querySelector('form').dispatchEvent(new ui.w.Event('submit',{bubbles:true,cancelable:true}));await tick();assert.match(ui.w.document.getElementById('form-error').textContent,/سبب/);ui.value('correction-reason','مطابقة دفتر ورقي');await ui.submit();const c=ui.stored().days[M.dateKey()].corrections[0];assert.equal(c.before,null);assert.equal(c.after,1234);assert.equal(c.reason,'مطابقة دفتر ورقي');
});
test('correction undo retains original reason and records the reversal',async t=>{
 const ui=await setup(t);ui.click('[data-action="balance"]');ui.value('amount','5000');ui.value('correction-reason','تصحيح العد');await ui.submit();ui.action('undo');await tick();
 const d=ui.stored().days[M.dateKey()];assert.equal(d.balance,null);assert.equal(d.corrections.length,2);assert.equal(d.corrections[0].reason,'تصحيح العد');assert.equal(d.corrections[1].before,5000);assert.equal(d.corrections[1].after,null);
});
test('inventory no matches is recoverable and compact catalog preserves photos',async t=>{
 const {fixture}=require('./commerce-fixture.cjs');const ui=await setup(t,{data:fixture()});ui.click('[data-view="inventory"]');ui.value('inventory-search','no matching name');ui.w.document.getElementById('inventory-search').dispatchEvent(new ui.w.Event('input',{bubbles:true}));assert.match(ui.w.document.getElementById('inventory-list').textContent,/ماكو صنف مطابق/);ui.click('[data-action="inventory-reset"]');assert.ok(ui.w.document.querySelector('.inventory-table'));ui.click('[data-view="sales"]');ui.click('[data-action="catalog-density"]');assert.ok(ui.w.document.querySelector('.product-grid.compact'));assert.equal(ui.w.document.querySelectorAll('.product-photo').length,fixture().products.length);
});
test('numeric validation locates the exact invoice field and expands its details',async t=>{
 const ui=await setup(t);await addSupplier(ui);ui.click('[data-action="invoice-new"]');ui.value('invoice-number','I-1');lineValue(ui,'.line-name-input','مادة');lineValue(ui,'.line-pieces','1');lineValue(ui,'.line-price','1000');lineValue(ui,'.line-carton-price','bad');await ui.submit();const field=ui.w.document.querySelector('.line-carton-price');assert.equal(field.getAttribute('aria-invalid'),'true');assert.equal(field.closest('details').open,true);assert.equal(ui.stored().invoices.length,0);
});

test('sales category tabs filter products while keeping the current ticket and search', async t => {
 const {fixture}=require('./commerce-fixture.cjs'); const data=fixture(), ui=await setup(t,{data});
 ui.click('[data-view="sales"]');
 const product=data.products.find(p=>!p.archived && p.group);
 ui.click(`[data-action="sale-add"][data-id="${product.id}"]`);
 const group=Array.from(ui.w.document.querySelectorAll('.catalog-group')).find(b=>b.dataset.group===product.group);
 group.click();
 assert.equal(ui.w.document.activeElement.dataset.group,product.group);
 assert.equal(ui.w.document.querySelector('.catalog-group.active').getAttribute('aria-pressed'),'true');
 const ids=Array.from(ui.w.document.querySelectorAll('#product-grid .product-tile')).map(b=>b.dataset.id);
 assert.ok(ids.length); assert.ok(ids.every(id=>data.products.find(p=>p.id===id).group===product.group));
 assert.match(ui.w.document.getElementById('cart-lines').textContent,new RegExp(product.name));
 ui.value('product-search','no-match-test'); ui.w.document.getElementById('product-search').dispatchEvent(new ui.w.Event('input',{bubbles:true}));
 assert.equal(ui.w.document.querySelectorAll('#product-grid .product-tile').length,0);
 ui.click('[data-action="catalog-reset"]'); assert.ok(ui.w.document.querySelectorAll('#product-grid .product-tile').length>0);
 assert.match(ui.w.document.getElementById('cart-lines').textContent,new RegExp(product.name));
 assert.deepEqual(ui.stored(),data);
});

test('settings keep cross-section drafts, preview text safely and save all preferences together',async t=>{
 const ui=await setup(t);ui.click('[data-view="settings"]');
 ui.value('restaurant-name','<img src=x onerror=alert(1)>');
 ui.w.document.getElementById('restaurant-name').dispatchEvent(new ui.w.Event('input',{bubbles:true}));
 assert.equal(ui.w.document.getElementById('settings-preview-name').textContent,'<img src=x onerror=alert(1)>');
 assert.equal(ui.w.document.querySelector('#settings-preview-name img'),null);
 ui.click('[data-action="settings-section"][data-section="workflow"]');
 assert.equal(ui.w.document.getElementById('settings-panel-restaurant').hidden,true);
 assert.equal(ui.w.document.getElementById('settings-panel-workflow').hidden,false);
 ui.value('shortcut-0','cash',true);ui.value('order-types-list','محلي\nتوصيل خاص');
 ui.click('[data-action="settings-section"][data-section="restaurant"]');
 assert.equal(ui.w.document.getElementById('restaurant-name').value,'<img src=x onerror=alert(1)>');
 ui.click('[data-action="settings-save"]');await tick();
 assert.equal(ui.stored().preferences.restaurant.name,'<img src=x onerror=alert(1)>');
 assert.equal(ui.stored().preferences.shortcuts[0],'cash');
 assert.deepEqual(Array.from(ui.stored().preferences.orderTypes),['محلي','توصيل خاص']);
 assert.equal(ui.w.document.querySelector('[data-action="settings-save"]').disabled,true);
});
test('settings validation and failed saves retain drafts in every section without changing stored accounts',async t=>{
 const ui=await setup(t,{failSave:true});ui.click('[data-view="settings"]');
 ui.value('restaurant-name','مطعم اختبار');ui.value('order-types-list','محلي\nمحلي');
 ui.w.document.getElementById('restaurant-form').dispatchEvent(new ui.w.Event('submit',{bubbles:true,cancelable:true}));await tick();
 assert.match(ui.w.document.getElementById('settings-error').textContent,/مكررة/);
 assert.deepEqual(ui.stored(),M.empty());ui.value('order-types-list','محلي');
 ui.w.document.getElementById('restaurant-form').dispatchEvent(new ui.w.Event('submit',{bubbles:true,cancelable:true}));await tick();
 assert.match(ui.w.document.getElementById('settings-error').textContent,/تعذّر/);
 assert.equal(ui.w.document.getElementById('restaurant-name').value,'مطعم اختبار');
 assert.equal(ui.w.document.getElementById('order-types-list').value,'محلي');
 assert.deepEqual(ui.stored(),M.empty());
});
test('settings tabs follow RTL keyboard navigation and discard restores saved values',async t=>{
 const ui=await setup(t);ui.click('[data-view="settings"]');
 const first=ui.w.document.getElementById('settings-tab-restaurant');first.focus();
 first.dispatchEvent(new ui.w.KeyboardEvent('keydown',{key:'ArrowLeft',bubbles:true,cancelable:true}));
 assert.equal(ui.w.document.activeElement.id,'settings-tab-workflow');
 assert.equal(ui.w.document.querySelectorAll('.settings-tabs [tabindex="0"]').length,1);
 ui.value('restaurant-name','تعديل غير محفوظ');
 ui.w.document.getElementById('restaurant-name').dispatchEvent(new ui.w.Event('input',{bubbles:true}));
 ui.click('[data-action="settings-discard"]');
 assert.equal(ui.w.document.getElementById('restaurant-name').value,'');
 assert.equal(ui.w.document.querySelector('[data-action="settings-save"]').disabled,true);
});

test('order-type manager adds, disables, re-enables and chooses a default before saving',async t=>{
 const ui=await setup(t);ui.click('[data-view="settings"]');ui.click('[data-section="workflow"]');
 assert.equal(ui.w.document.getElementById('order-types-list').hidden,true);
 ui.value('order-type-new','استلام');ui.click('[data-action="order-type-add"]');
 assert.equal(ui.w.document.querySelectorAll('.order-type-row').length,4);
 ui.value('order-type-default','استلام',true);
 ui.click('[data-action="order-type-toggle"][data-index="1"][data-disabled="false"]');
 assert.match(ui.w.document.querySelector('.order-type-row.is-disabled').textContent,/صالة/);
 assert.deepEqual(ui.stored().preferences.orderTypes,M.empty().preferences.orderTypes);
 ui.click('[data-action="settings-save"]');await tick();
 assert.deepEqual(Array.from(ui.stored().preferences.orderTypes),['استلام','سفري','توصيل']);
 assert.deepEqual(Array.from(ui.stored().preferences.disabledOrderTypes),['صالة']);
 ui.click('[data-action="order-type-toggle"][data-index="0"][data-disabled="true"]');
 ui.click('[data-action="settings-save"]');await tick();
 assert.ok(ui.stored().preferences.orderTypes.includes('صالة'));
 assert.equal(ui.stored().preferences.disabledOrderTypes,undefined);
 ui.click('[data-view="sales"]');assert.equal(ui.w.document.getElementById('sale-order-type').value,'استلام');
});
test('order types reject duplicates and the last active removal; deletion leaves saved sales intact',async t=>{
 const {fixture}=require('./commerce-fixture.cjs');const data=M.completeSale(fixture(),{date:'2026-10-26',lines:[{productId:'p0',quantity:1}],discount:0,orderType:'صالة'},'historical','2026-10-26T10:00:00Z');
 const ui=await setup(t,{data});ui.click('[data-view="settings"]');ui.click('[data-section="workflow"]');
 ui.value('order-type-new','صالة');ui.click('[data-action="order-type-add"]');
 assert.match(ui.w.document.getElementById('order-type-error').textContent,/موجود/);
 ui.value('order-type-new','');
 ui.click('[data-action="order-type-delete"][data-index="0"][data-disabled="false"]');
 ui.click('[data-action="order-type-delete"][data-index="0"][data-disabled="false"]');
 ui.click('[data-action="order-type-toggle"][data-index="0"][data-disabled="false"]');
 assert.match(ui.w.document.getElementById('order-type-error').textContent,/واحد على الأقل/);
 ui.click('[data-action="settings-save"]');await tick();
 assert.deepEqual(Array.from(ui.stored().preferences.orderTypes),['توصيل']);
 assert.equal(ui.stored().sales[0].orderType,'صالة');assert.deepEqual(ui.stored().sales,data.sales);
});

test('product corner icon adds once and remains available alongside the ticket quantity',async t=>{
 const {fixture}=require('./commerce-fixture.cjs');const ui=await setup(t,{data:fixture()});ui.click('[data-view="sales"]');
 ui.click('[data-action="sale-add"][data-id="p0"] .product-plus');
 assert.equal(ui.w.document.querySelector('[data-action="sale-add"][data-id="p0"] .product-count').textContent,'1');
 assert.match(ui.w.document.getElementById('sale-total').textContent,/12,000/);
 ui.click('[data-action="sale-add"][data-id="p0"] .product-plus');
 assert.equal(ui.w.document.querySelector('[data-action="sale-add"][data-id="p0"] .product-count').textContent,'2');
 assert.match(ui.w.document.getElementById('sale-total').textContent,/24,000/);
 assert.equal(ui.stored().sales.length,0);
});

test('retired worker feature is absent from navigation and shortcuts while settings saves preserve legacy records',async t=>{
 const data=M.empty(),date='2026-10-01';data.preferences.shortcuts=['savings','sales','inventory','expenses','cash','settings'];
 data.workers.push({id:'legacy-worker',name:'عامل اختبار قديم',amount:10000,frequency:'daily',startDate:date,archived:false,note:''});
 data.savingsEntries.push({id:'legacy-contribution',workerId:'legacy-worker',type:'contribution',date,amount:10000,periodStart:date,periodEnd:date,dueAmount:10000,note:'',createdAt:date+'T12:00:00Z'});
 const ui=await setup(t,{data});
 assert.equal(ui.w.document.querySelector('[data-view="savings"]'),null);
 assert.equal(ui.w.document.querySelector('script[src="savings.js"]'),null);
 ui.click('[data-view="settings"]');assert.equal(ui.w.document.querySelector('#shortcut-form option[value="savings"]'),null);
 assert.equal(ui.w.document.getElementById('shortcut-0').value,'');
 ui.value('restaurant-name','مطعم اختبار');ui.w.document.getElementById('restaurant-form').dispatchEvent(new ui.w.Event('submit',{bubbles:true,cancelable:true}));await tick();
 assert.deepEqual(ui.stored().workers,data.workers);assert.deepEqual(ui.stored().savingsEntries,data.savingsEntries);
 assert.deepEqual(ui.stored().days,data.days);assert.deepEqual(ui.stored().transactions,data.transactions);
 assert.equal(ui.stored().preferences.shortcuts[0],'');
});
