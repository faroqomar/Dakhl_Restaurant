const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const M = require('../app/ui/model.js');
async function setup(t, { data = M.empty(), failSave = false } = {}) {
  const root = path.join(__dirname, '../app/ui'); const dom = new JSDOM(fs.readFileSync(path.join(root, 'index.html'), 'utf8'), { url: 'file:///app/index.html', runScripts: 'outside-only' }); t.after(() => dom.window.close());
  const { window: w } = dom; w.structuredClone = structuredClone; w.HTMLElement.prototype.scrollIntoView = () => {}; let stored = data, action;
  w.daftar = { load: async () => ({ ok: true, data: stored, directory: '/test/data' }), save: async d => { if (failSave) return { ok: false, error: 'لا توجد مساحة كافية' }; stored = M.validate(structuredClone(d)); return { ok: true, data: stored }; }, onAction: cb => action = cb };
  w.eval(fs.readFileSync(path.join(root, 'model.js'), 'utf8')); w.eval(fs.readFileSync(path.join(root, 'numbers.js'), 'utf8')); w.eval(fs.readFileSync(path.join(root, 'suppliers.js'), 'utf8') + '\n' + fs.readFileSync(path.join(root, 'renderer.js'), 'utf8')); await tick();
  function click(selector) { const el = w.document.querySelector(selector); assert.ok(el, selector); el.click(); }
  function value(id, val, change = false) { const el = w.document.getElementById(id); assert.ok(el, id); el.value = val; if (change) el.dispatchEvent(new w.Event('change', { bubbles: true })); }
  async function submit() { w.document.querySelector('form').dispatchEvent(new w.Event('submit', { bubbles: true, cancelable: true })); await tick(); }
  return { w, click, value, submit, stored: () => stored, action: name => action(name) };
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
  ui.value('cash-amount', '12000'); await ui.submit(); assert.equal(M.remaining(ui.stored(), date), 32000); assert.equal(M.cash(ui.stored()), 88000); assert.equal(M.total(ui.stored(), date), 30000); assert.match(ui.w.document.querySelector('.funding-note').textContent, /مشترك/);
  ui.click('[data-view="cash"]'); ui.click('[data-action="edit-transaction"][data-kind="expense"]'); ui.value('payment-source', 'daily', true); await ui.submit(); assert.equal(M.cash(ui.stored()), 100000); assert.equal(M.remaining(ui.stored(), date), 20000);
});
test('remaining is actual after existing expenses; partial/full deposits affect both balances without double counting', async t => {
  const ui = await setup(t), date = M.dateKey(); ui.click('[data-action="expense"]'); ui.value('amount', '10000'); await ui.submit();
  assert.equal(ui.w.document.querySelector('[data-action="remaining-transfer"]').disabled, true);
  ui.click('[data-action="remaining"]'); ui.value('amount', '50000'); await ui.submit(); assert.equal(M.remaining(ui.stored(), date), 50000);
  ui.click('[data-action="remaining-transfer"]'); assert.equal(ui.w.document.getElementById('amount').value, '50,000'); ui.value('amount', '50001'); await ui.submit(); assert.match(ui.w.document.getElementById('form-error').textContent, /أكبر/); assert.equal(M.cash(ui.stored()), 0);
  ui.value('amount', '20000'); await ui.submit(); assert.equal(M.cash(ui.stored()), 20000); assert.equal(M.remaining(ui.stored(), date), 30000);
  ui.click('[data-action="remaining-transfer"]'); await ui.submit(); assert.equal(M.cash(ui.stored()), 50000); assert.equal(M.remaining(ui.stored(), date), 0); assert.equal(M.total(ui.stored(), date), 10000); assert.equal(ui.w.document.querySelector('[data-action="remaining-transfer"]').disabled, true);
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
  ui.click('[data-action="supplier-tab"][data-tab="materials"]'); ui.click('[data-action="material-new"]'); ui.value('material-name','رز'); ui.value('unit','كيلو'); ui.value('amount','5000'); await ui.submit(); assert.equal(ui.stored().suppliers[0].materials.length,1);
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-new"]'); ui.value('invoice-number','A-1'); lineValue(ui,'.line-name-input','رز',true); assert.equal(ui.w.document.querySelector('.line-price').value,'5,000'); lineValue(ui,'.line-quantity','2.5'); ui.value('amount','2500'); ui.value('payment-source','shared',true); ui.value('daily-amount','1500'); ui.value('cash-amount','1000'); await ui.submit();
  assert.equal(ui.stored().invoices.length,1); assert.equal(M.invoiceTotal(ui.stored().invoices[0]),12500); assert.equal(M.supplierBalance(ui.stored(),supplier.id),110000); assert.equal(M.total(ui.stored(),date),2500); assert.equal(M.cash(ui.stored()),199000); assert.equal(M.remaining(ui.stored(),date),48500);
  ui.click('[data-view="expenses"]'); assert.equal(ui.w.document.querySelectorAll('[data-action="payment-edit"]').length,1); assert.match(ui.w.document.querySelector('.note').textContent,/مورد المواد/);
  ui.click('[data-view="cash"]'); assert.ok(ui.w.document.querySelector('[data-kind="supplier-payment"]')); ui.click('[data-kind="supplier-payment"]'); assert.equal(ui.w.document.getElementById('amount').value,'2,500');
});
test('new invoice materials become reusable; template edits do not rewrite saved invoice details', async t => {
  const ui=await setup(t); await addSupplier(ui); await addInvoice(ui); assert.equal(ui.stored().suppliers[0].materials[0].name,'رز'); assert.equal(ui.stored().payments.length,0); assert.equal(M.total(ui.stored(),M.dateKey()),0);
  ui.click('[data-action="supplier-tab"][data-tab="materials"]'); ui.click('[data-action="material-edit"]'); ui.value('amount','7000'); ui.value('material-name','رز جديد'); await ui.submit(); assert.equal(ui.stored().invoices[0].lines[0].price,5000);
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-edit"]'); await ui.submit(); assert.equal(ui.stored().suppliers[0].materials.length,1); assert.equal(ui.stored().invoices[0].lines[0].name,'رز');
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-new"]'); lineValue(ui,'.line-name-input','رز جديد',true); assert.equal(ui.w.document.querySelector('.line-price').value,'7,000'); assert.equal(ui.w.document.querySelector('.line-unit').value,'كيلو');
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
  assert.equal(M.invoiceDue(ui.stored(), invoice.id), 0); assert.equal(M.debtAvailable(ui.stored(), supplier.id), 80000); assert.equal(M.total(ui.stored(), date), 32500); assert.equal(M.cash(ui.stored()), -12500); assert.equal(M.remaining(ui.stored(), date), 80000);
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
  ui.click('[data-action="invoice-new"]'); ui.value('invoice-number', '0012'); lineValue(ui, '.line-name-input', 'رز 1', true); assert.equal(ui.w.document.querySelector('.line-price').value, '5,000'); await ui.submit();
  assert.match(ui.w.document.getElementById('form-error').textContent, /رقم القائمة/); assert.equal(ui.stored().invoices.length, 1);
});
