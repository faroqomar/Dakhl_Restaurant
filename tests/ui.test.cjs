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
  w.eval(fs.readFileSync(path.join(root, 'model.js'), 'utf8')); w.eval(fs.readFileSync(path.join(root, 'suppliers.js'), 'utf8') + '\n' + fs.readFileSync(path.join(root, 'renderer.js'), 'utf8')); await tick();
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
  assert.equal(ui.w.document.getElementById('amount').value, '1000'); assert.match(ui.w.document.getElementById('form-error').textContent, /مساحة/); assert.match(ui.w.document.getElementById('save-status').textContent, /تعذّر/); assert.deepEqual(ui.stored(), M.empty());
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
  ui.click('[data-action="remaining-transfer"]'); assert.equal(ui.w.document.getElementById('amount').value, '50000'); ui.value('amount', '50001'); await ui.submit(); assert.match(ui.w.document.getElementById('form-error').textContent, /أكبر/); assert.equal(M.cash(ui.stored()), 0);
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
  assert.match(ui.w.document.getElementById('form-error').textContent, /مساحة/); assert.equal(M.cash(ui.stored()), 0); assert.equal(M.remaining(ui.stored(), date), 50000); assert.equal(ui.stored().transfers.length, 0); assert.equal(ui.w.document.getElementById('amount').value, '20000');
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
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-new"]'); ui.value('invoice-number','A-1'); lineValue(ui,'.line-name-input','رز',true); assert.equal(ui.w.document.querySelector('.line-price').value,'5000'); lineValue(ui,'.line-quantity','2.5'); ui.value('amount','2500'); ui.value('payment-source','shared',true); ui.value('daily-amount','1500'); ui.value('cash-amount','1000'); await ui.submit();
  assert.equal(ui.stored().invoices.length,1); assert.equal(M.invoiceTotal(ui.stored().invoices[0]),12500); assert.equal(M.supplierBalance(ui.stored(),supplier.id),110000); assert.equal(M.total(ui.stored(),date),2500); assert.equal(M.cash(ui.stored()),199000); assert.equal(M.remaining(ui.stored(),date),48500);
  ui.click('[data-view="expenses"]'); assert.equal(ui.w.document.querySelectorAll('[data-action="payment-edit"]').length,1); assert.match(ui.w.document.querySelector('.note').textContent,/مورد المواد/);
  ui.click('[data-view="cash"]'); assert.ok(ui.w.document.querySelector('[data-kind="supplier-payment"]')); ui.click('[data-kind="supplier-payment"]'); assert.equal(ui.w.document.getElementById('amount').value,'2500');
});
test('new invoice materials become reusable; template edits do not rewrite saved invoice details', async t => {
  const ui=await setup(t); await addSupplier(ui); await addInvoice(ui); assert.equal(ui.stored().suppliers[0].materials[0].name,'رز'); assert.equal(ui.stored().payments.length,0); assert.equal(M.total(ui.stored(),M.dateKey()),0);
  ui.click('[data-action="supplier-tab"][data-tab="materials"]'); ui.click('[data-action="material-edit"]'); ui.value('amount','7000'); ui.value('material-name','رز جديد'); await ui.submit(); assert.equal(ui.stored().invoices[0].lines[0].price,5000);
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-edit"]'); await ui.submit(); assert.equal(ui.stored().suppliers[0].materials.length,1); assert.equal(ui.stored().invoices[0].lines[0].name,'رز');
  ui.click('[data-action="supplier-tab"][data-tab="invoices"]'); ui.click('[data-action="invoice-new"]'); lineValue(ui,'.line-name-input','رز جديد',true); assert.equal(ui.w.document.querySelector('.line-price').value,'7000'); assert.equal(ui.w.document.querySelector('.line-unit').value,'كيلو');
});
test('duplicate invoice and overpayment keep all input and never partly add materials or payments', async t => {
  const ui=await setup(t); await addSupplier(ui); await addInvoice(ui); const before=structuredClone(ui.stored());
  await addInvoice(ui,{number:'A-1',paid:'100'}); assert.match(ui.w.document.getElementById('form-error').textContent,/رقم القائمة/); assert.deepEqual(ui.stored(),before);
  ui.value('invoice-number','A-2'); ui.value('amount','20000'); await ui.submit(); assert.match(ui.w.document.getElementById('form-error').textContent,/أكبر/); assert.deepEqual(ui.stored(),before);
});
test('invoice settlements can be partial or full, opening debt is a separate target, and deleting a payment refunds funding', async t => {
  const ui=await setup(t); const supplier=await addSupplier(ui); await addInvoice(ui); const invoice=ui.stored().invoices[0];
  ui.click('[data-action="invoice-pay"]'); assert.equal(ui.w.document.getElementById('invoice-id').value,invoice.id); assert.equal(ui.w.document.getElementById('amount').value,'12500'); ui.value('amount','5000'); ui.value('payment-source','cash',true); await ui.submit(); assert.equal(M.invoiceDue(ui.stored(),invoice.id),7500); assert.equal(M.cash(ui.stored()),-5000);
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
  const data=M.empty(); data.suppliers.push({id:'supplier',name:'المورد',phone:'',note:'',categoryId:'market',openingBalance:0,materials:[]}); const ui=await setup(t,{data,failSave:true}); ui.click('[data-view="suppliers"]'); await addInvoice(ui,{paid:'5000'}); assert.match(ui.w.document.getElementById('form-error').textContent,/مساحة/); assert.deepEqual(ui.stored(),data); assert.equal(ui.w.document.querySelector('.line-name-input').value,'رز'); assert.equal(ui.w.document.getElementById('amount').value,'5000');
});
