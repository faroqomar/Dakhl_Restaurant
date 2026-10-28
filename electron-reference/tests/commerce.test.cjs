const { test } = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const M = require('../app/ui/model.js'), { Storage } = require('../app/storage.cjs'), { createReport } = require('../app/reports/pdf.cjs'), { fixture } = require('./commerce-fixture.cjs');
const date='2026-10-26', timestamp=date+'T10:00:00Z';
function sell(state=fixture(), overrides={}) { return M.completeSale(state, { date, lines:[{productId:'p0',quantity:2}], discount:1000, paid:25000, note:'سفري', ...overrides }, 'sale-1', timestamp); }
test('schema 9 migrates old data without rewriting balances and persists complete commerce data atomically',t=>{
 const original=fixture(); original.version=7; delete original.products; delete original.stockEntries; delete original.sales; delete original.preferences; M.recordRemaining(original,date,12000);
 const migrated=M.validate(original); assert.equal(migrated.version,11); assert.deepEqual(migrated.days,original.days); assert.deepEqual(migrated.products,[]); assert.deepEqual(migrated.preferences.shortcuts,M.defaultShortcuts);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'daftar-sales-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true})); const store=new Storage(dir);fs.writeFileSync(store.file,JSON.stringify(original));store.load();assert.deepEqual(JSON.parse(fs.readFileSync(store.backup)),original);
 const next=sell(); next.preferences.shortcuts=['inventory','sales','','cash','settings','materials'];store.save(next);assert.deepEqual(new Storage(dir).load(),next);
 const bad=structuredClone(next);bad.stockEntries[0].quantity=1;assert.throws(()=>store.save(bad),/المخزون/);assert.deepEqual(new Storage(dir).load(),next);
});
test('cash sale snapshots price, applies discount, derives exact inventory and never counts cash twice',()=>{
 const state=fixture();M.recordRemaining(state,date,50000);const next=sell(state);assert.equal(M.stock(next,'p0'),18);assert.equal(M.salesTotal(next,date),23000);assert.equal(M.remaining(next,date),73000);assert.equal(M.cash(next),0);assert.equal(M.total(next,date),0);
 next.products[0].name='اسم جديد';next.products[0].price=15000;assert.equal(M.saleTotal(M.validate(next).sales[0]),23000);assert.equal(next.sales[0].lines[0].name,'كباب لحم');
 M.recordRemaining(next,date,73000);assert.equal(M.remaining(next,date),73000);const voided=M.voidSale(next,'sale-1','أعيد المبلغ للزبون',timestamp);assert.equal(M.stock(voided,'p0'),20);assert.equal(M.salesTotal(voided,date),0);assert.equal(M.remaining(voided,date),50000);assert.equal(M.cash(voided),0);assert.equal(voided.sales.length,1);assert.throws(()=>M.voidSale(voided,'sale-1','مرة ثانية',timestamp));
});
test('overselling, backdated negative inventory, invalid amounts, duplicates and changing tracked mode are rejected',()=>{
 assert.throws(()=>sell(fixture(),{lines:[{productId:'p6',quantity:3}]}),/المخزون/);
 assert.throws(()=>sell(fixture(),{date:'2026-10-25'}),/المخزون/);
 assert.throws(()=>sell(fixture(),{discount:25000}),/الخصم/);assert.throws(()=>sell(fixture(),{paid:10}),/المستلم/);
 assert.throws(()=>sell(fixture(),{lines:[{productId:'p0',quantity:1},{productId:'p0',quantity:1}]}),/مكرر/);
 assert.throws(()=>sell(fixture(),{lines:[{productId:'p0',quantity:-1}]}));
 const next=sell();next.products[0].trackStock=false;assert.throws(()=>M.validate(next));
 const bad=fixture();bad.products[1].code=bad.products[0].code;assert.throws(()=>M.validate(bad),/رمز/);
 const future=sell();future.stockEntries.push({id:'loss',productId:'p0',date:'2026-10-27',quantity:-18,kind:'adjustment',note:'',createdAt:timestamp});assert.equal(M.stock(M.validate(future),'p0'),0);assert.throws(()=>sell(future,{lines:[{productId:'p0',quantity:1}]}));
});
test('fractional stock stays exact, untracked dishes sell, archived products and invalid shortcuts are blocked',()=>{
 const data=fixture();data.stockEntries[0].quantity=0.3;const next=sell(data,{lines:[{productId:'p0',quantity:0.1}],discount:0,paid:1200});assert.equal(M.stock(next,'p0'),0.2);
 const dish=fixture();dish.stockEntries=[];dish.products.forEach(p=>p.trackStock=false);const sale=sell(dish);assert.equal(M.salesTotal(sale,date),23000);assert.equal(M.stock(sale,'p0'),0);
 dish.products[0].archived=true;assert.throws(()=>sell(dish),/متاح/);
 const wrong=fixture();wrong.preferences.shortcuts[0]='https://example.com';assert.throws(()=>M.validate(wrong),/اختصارات/);
});
test('sale PDF reports saved snapshots, discount, cash, change and void reason with escaped user text',()=>{
 const next=sell();next.sales[0].note='<img src=x onerror=alert(1)>';const report=createReport(next,{kind:'sale',id:'sale-1'});assert.match(report.html,/23,000/);assert.match(report.html,/25,000/);assert.match(report.html,/2,000/);assert.match(report.html,/&lt;img/);assert.doesNotMatch(report.html,/<img/);assert.match(report.filename,/S-000001/);
 const voided=M.voidSale(next,'sale-1','تجربة إلغاء',timestamp);assert.match(createReport(voided,{kind:'sale',id:'sale-1'}).html,/فاتورة ملغاة/);assert.throws(()=>createReport(next,{kind:'sale',id:'missing'}));
});
test('correcting daily dates leaves sales and stock dates independent and preserves the actual daily remainder',()=>{
 const s=fixture();M.recordRemaining(s,date,50000);const next=sell(s),remaining=M.remaining(next,date);const moved=M.correctDayDates(next,date,'2026-10-27');assert.equal(M.remaining(moved,'2026-10-27'),remaining);assert.equal(moved.sales[0].date,date);assert.deepEqual(moved.stockEntries,next.stockEntries);assert.equal(M.salesTotal(moved,date),23000);
});
test('daily date correction preserves an overdrawn remainder after a sale cancellation',()=>{
 const s=sell();M.recordRemaining(s,date,0);s.days[date].expenses.push({id:'late-expense',categoryId:'bread',amount:1000,note:''});assert.equal(M.remaining(M.correctDayDates(s,date,'2026-10-27'),'2026-10-27'),-1000);s.days[date].expenses=[];const voided=M.voidSale(s,'sale-1','إرجاع النقد',timestamp);assert.equal(M.remaining(voided,date),-23000);
 const moved=M.correctDayDates(voided,date,'2026-10-27');assert.equal(M.remaining(moved,'2026-10-27'),-23000);
});
test('version 8 data gains editable order types without changing old invoices; photo choices are validated',()=>{
 const old=sell();old.version=8;delete old.preferences.orderTypes;delete old.sales[0].orderType;const upgraded=M.validate(old);assert.equal(upgraded.version,11);assert.deepEqual(upgraded.sales,old.sales);assert.deepEqual(upgraded.preferences.orderTypes,['صالة','سفري','توصيل']);assert.deepEqual(upgraded.products,old.products);
 const bad=fixture();bad.products[0].photo='../../private';assert.throws(()=>M.validate(bad),/صورة/);bad.products[0].photo='beef-kebab';assert.equal(M.validate(bad).products[0].photo,'beef-kebab');
 const invalid=fixture();invalid.preferences.orderTypes=['سفري','سفري'];assert.throws(()=>M.validate(invalid),/مكررة/);invalid.preferences.orderTypes=[];assert.throws(()=>M.validate(invalid),/نوع طلب/);
});
test('exact-total checkout requires no cash entry and preserves historical order types after settings edits',()=>{
 const s=fixture(),next=M.completeSale(s,{date,lines:[{productId:'p0',quantity:1}],discount:2000,orderType:'سفري'},'exact',timestamp);assert.equal(next.sales[0].paid,10000);assert.equal(next.sales[0].orderType,'سفري');assert.equal(M.salesTotal(next,date),10000);assert.equal(M.stock(next,'p0'),19);
 next.preferences.orderTypes=['خارجي'];assert.equal(M.validate(next).sales[0].orderType,'سفري');assert.match(createReport(next,{kind:'sale',id:'exact'}).html,/سفري/);assert.throws(()=>M.completeSale(next,{date,lines:[{productId:'p0',quantity:1}],discount:0,orderType:'سفري'},'invalid',timestamp),/نوع طلب/);
});

test('disabled order types survive storage and validation while historical sales and old preferences remain valid',t=>{
 const original=sell(fixture(),{orderType:'سفري'}),saved=structuredClone(original);
 saved.preferences.orderTypes=['صالة','توصيل'];saved.preferences.disabledOrderTypes=['سفري'];
 const clean=M.validate(saved);assert.deepEqual(clean.sales,original.sales);assert.deepEqual(clean.days,original.days);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'daftar-order-types-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
 new Storage(dir).save(clean);assert.deepEqual(new Storage(dir).load(),clean);
 assert.deepEqual(M.validate(JSON.parse(JSON.stringify(clean))),clean);
 assert.equal(M.validate(original).preferences.disabledOrderTypes,undefined);
 assert.throws(()=>M.completeSale(clean,{date,lines:[{productId:'p0',quantity:1}],discount:0,orderType:'سفري'},'disabled',timestamp),/نوع طلب/);
 const duplicate=structuredClone(clean);duplicate.preferences.disabledOrderTypes=['صالة'];assert.throws(()=>M.validate(duplicate),/مكررة/);
 const allDisabled=structuredClone(clean);allDisabled.preferences.orderTypes=[];assert.throws(()=>M.validate(allDisabled),/نوع طلب/);
});

test('legacy worker records and old shortcuts survive validation and storage after the screen is retired',t=>{
 const data=fixture(),date='2026-10-01';data.preferences.shortcuts=['savings','sales','inventory','expenses','cash','settings'];
 data.workers.push({id:'legacy-worker',name:'عامل اختبار قديم',amount:10000,frequency:'daily',startDate:date,archived:false,note:''});
 data.savingsEntries.push({id:'legacy-contribution',workerId:'legacy-worker',type:'contribution',date,amount:10000,periodStart:date,periodEnd:date,dueAmount:10000,note:'',createdAt:date+'T12:00:00Z'});
 const clean=M.validate(data);assert.ok(!M.destinations.includes('savings'));assert.equal(clean.preferences.shortcuts[0],'');
 assert.deepEqual(clean.workers,data.workers);assert.deepEqual(clean.savingsEntries,data.savingsEntries);
 for(const key of ['days','transactions','transfers','sales','invoices','payments'])assert.deepEqual(clean[key],data[key]);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'daftar-retired-workers-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
 const store=new Storage(dir);store.save(clean);const restored=new Storage(dir).load();assert.deepEqual(restored,clean);assert.deepEqual(M.validate(JSON.parse(JSON.stringify(restored))),clean);
});
