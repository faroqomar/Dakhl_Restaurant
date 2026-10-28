const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {JSDOM}=require('jsdom');
const M=require('../app/ui/model.js');
const {fixture}=require('./commerce-fixture.cjs');
const tick=()=>new Promise(r=>setTimeout(r,10));
async function setup(t,{data=fixture(),storage=new Map(),directory='/mvp/account',failSave=false,failStorage=false,printResult={ok:true}}={}){
 const root=path.join(__dirname,'../app/ui'),dom=new JSDOM(fs.readFileSync(path.join(root,'index.html'),'utf8'),{url:'https://daftar.test',runScripts:'outside-only'}),w=dom.window;t.after(()=>w.close());w.structuredClone=structuredClone;w.confirm=()=>true;w.HTMLElement.prototype.scrollIntoView=()=>{};
 let stored=M.validate(data),saveFails=failSave,storageFails=failStorage;const printRequests=[];
 Object.defineProperty(w,'localStorage',{value:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>{if(storageFails)throw Error('full');storage.set(k,v);},removeItem:k=>storage.delete(k)}});
 w.daftar={load:async()=>({ok:true,data:stored,directory}),save:async d=>saveFails?{ok:false,error:'فشل حفظ تجريبي'}:{ok:true,data:stored=M.validate(structuredClone(d))},printReport:async request=>{printRequests.push(request);return printResult;},pdf:async()=>({ok:true,canceled:true}),onAction:()=>{}};
 w.eval(fs.readFileSync(path.join(root,'model.js'),'utf8'));w.eval(fs.readFileSync(path.join(root,'numbers.js'),'utf8'));w.eval(['suppliers.js','commerce.js','ux.js','renderer.js'].map(f=>fs.readFileSync(path.join(root,f),'utf8')).join('\n'));await tick();
 const click=selector=>{const el=w.document.querySelector(selector);assert.ok(el,selector);el.click();};
 const input=(id,value)=>{const el=w.document.getElementById(id);assert.ok(el,id);el.value=value;el.dispatchEvent(new w.Event('input',{bubbles:true}));};
 const submit=async()=>{w.document.getElementById('entry-form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await tick();};
 return {w,click,input,submit,stored:()=>stored,storage,printRequests,failSave:v=>saveFails=v,failStorage:v=>storageFails=v};
}
function add(ui){ui.click('[data-view="sales"]');ui.click('[data-action="sale-add"][data-id="p0"]');}
async function sell(ui){add(ui);ui.click('[data-action="sale-complete"]');await tick();}
test('successful sale opens paid receipt; printing is explicit and cancellation preserves the sale',async t=>{
 const ui=await setup(t,{printResult:{ok:true,canceled:true}});await sell(ui);assert.equal(ui.stored().sales.length,1);assert.match(ui.w.document.getElementById('drawer-title').textContent,/تم البيع/);assert.equal(ui.printRequests.length,0);ui.click('.receipt-actions [data-action="sale-print"]');await tick();assert.equal(ui.printRequests[0].kind,'sale');assert.equal(ui.printRequests[0].saleId,ui.stored().sales[0].id);assert.equal(ui.stored().sales.length,1);ui.click('[data-action="close-drawer"]');assert.equal(ui.w.document.querySelector('.drawer'),null);
});
test('save failure preserves active draft and opens no paid receipt; retry opens it only once saved',async t=>{
 const ui=await setup(t,{failSave:true});await sell(ui);assert.equal(ui.stored().sales.length,0);assert.equal(ui.w.document.querySelector('.paid-receipt'),null);assert.match(ui.w.document.getElementById('cart-lines').textContent,/كباب/);ui.failSave(false);ui.click('[data-action="sale-complete"]');await tick();assert.equal(ui.stored().sales.length,1);assert.ok(ui.w.document.querySelector('.paid-receipt'));
});
test('held orders survive reload, stay account-scoped and reserve no stock',async t=>{
 const ui=await setup(t);add(ui);ui.click('[data-action="sale-hold"]');ui.input('held-label','طاولة 3 <script>');ui.click('[data-action="sale-hold-confirm"]');assert.equal(ui.stored().sales.length,0);assert.equal(M.stock(ui.stored(),'p0'),20);assert.equal(ui.w.document.getElementById('checkout-button').disabled,true);
 const reload=await setup(t,{storage:ui.storage});reload.click('[data-view="sales"]');reload.click('[data-action="held-orders"]');assert.match(reload.w.document.querySelector('.held-orders').textContent,/طاولة 3/);assert.equal(reload.w.document.querySelector('.held-orders script'),null);reload.click('[data-action="sale-resume"]');assert.match(reload.w.document.getElementById('cart-lines').textContent,/كباب/);
 const other=await setup(t,{storage:ui.storage,directory:'/mvp/other'});other.click('[data-view="sales"]');other.click('[data-action="held-orders"]');assert.ok(other.w.document.querySelector('.held-empty'));
});
test('storage failure cannot clear active draft when holding, and switching atomically preserves both orders',async t=>{
 const ui=await setup(t);add(ui);ui.click('[data-action="sale-hold"]');ui.failStorage(true);ui.click('[data-action="sale-hold-confirm"]');assert.match(ui.w.document.getElementById('held-error').textContent,/تعذّر/);assert.match(ui.w.document.getElementById('cart-lines').textContent,/كباب/);ui.failStorage(false);ui.click('[data-action="sale-hold-confirm"]');ui.click('[data-action="sale-add"][data-id="p1"]');ui.click('[data-action="held-orders"]');ui.click('[data-action="sale-resume"]');assert.match(ui.w.document.getElementById('cart-lines').textContent,/كباب لحم/);ui.click('[data-action="held-orders"]');assert.equal(ui.w.document.querySelectorAll('.held-order').length,1);ui.click('[data-action="sale-resume"]');assert.match(ui.w.document.getElementById('cart-lines').textContent,/كباب دجاج/);
});
test('partial return previews discount-adjusted refund and preserves form on save failure',async t=>{
 const ui=await setup(t);add(ui);ui.click('[data-action="sale-add"][data-id="p0"]');ui.input('sale-discount','2000');ui.click('[data-action="sale-complete"]');await tick();ui.click('.receipt-actions [data-action="sale-receipt"]');ui.click('[data-action="sale-return"]');ui.input('return-quantity-0','1');assert.match(ui.w.document.getElementById('return-preview').textContent,/11,000/);ui.input('return-reason','رجع صنف');ui.w.document.getElementById('return-confirm').checked=true;ui.w.document.querySelector('[data-return-restock]').checked=true;ui.failSave(true);await ui.submit();assert.equal(ui.stored().saleReturns.length,0);assert.equal(ui.w.document.getElementById('return-quantity-0').value,'1');ui.failSave(false);await ui.submit();assert.equal(ui.stored().saleReturns.length,1);assert.equal(ui.stored().saleReturns[0].amount,11000);assert.equal(M.stock(ui.stored(),'p0'),19);assert.equal(M.saleTotal(ui.stored().sales[0]),22000);
});
test('over-return is disabled and return requires refund confirmation',async t=>{
 const ui=await setup(t);await sell(ui);ui.click('.receipt-actions [data-action="sale-receipt"]');ui.click('[data-action="sale-return"]');ui.input('return-quantity-0','2');assert.equal(ui.w.document.querySelector('.form-footer [type="submit"]').disabled,true);ui.input('return-quantity-0','1');ui.input('return-reason','مرتجع');await ui.submit();assert.equal(ui.stored().saleReturns.length,0);assert.match(ui.w.document.getElementById('form-error').textContent,/أكد/);
});
test('a stale second window cannot overwrite held orders on edit or unload',async t=>{
 const storage=new Map(),first=await setup(t,{storage}),second=await setup(t,{storage});add(first);add(second);first.click('[data-action="sale-hold"]');first.input('held-label','طلب محفوظ');first.click('[data-action="sale-hold-confirm"]');const key='daftar.active-sale:/mvp/account',before=storage.get(key);second.w.dispatchEvent(new second.w.Event('beforeunload'));assert.equal(storage.get(key),before);second.click('[data-action="sale-hold"]');second.click('[data-action="sale-hold-confirm"]');assert.equal(storage.get(key),before);assert.equal(JSON.parse(before).heldOrders.length,1);assert.match(second.w.document.getElementById('held-error').textContent,/تعذّر/);
});
test('browser print fallback is explicit, isolates the saved receipt, and resets print mode',async t=>{
 const ui=await setup(t);delete ui.w.daftar.printReport;let prints=0;ui.w.print=()=>{prints++;assert.ok(ui.w.document.body.classList.contains('printing-sale'));assert.ok(ui.w.document.querySelector('.sale-receipt'));};await sell(ui);assert.equal(prints,0);ui.click('.receipt-actions [data-action="sale-print"]');await tick();assert.equal(prints,1);assert.equal(ui.w.document.body.classList.contains('printing-sale'),false);assert.equal(ui.stored().sales.length,1);
});
test('history reports refunds by return date and stock history identifies restocked returns',async t=>{
 let data=M.completeSale(fixture(),{date:'2026-10-26',lines:[{productId:'p0',quantity:2}],discount:2000,orderType:'صالة'},'sale-history-test','2026-10-26T10:00:00.000Z');data=M.returnSale(data,'sale-history-test',{date:'2026-10-27',reason:'مرتجع يوم لاحق',lines:[{productId:'p0',quantity:1,restock:true}]},'return-history-test','2026-10-27T10:00:00.000Z');
 const ui=await setup(t,{data});ui.click('[data-view="sale-history"]');ui.input('sales-from','2026-10-26');ui.input('sales-to','2026-10-26');ui.click('[data-action="apply-filter"][data-key="sales"]');assert.match(ui.w.document.querySelector('.sales-period-total>strong').textContent,/22,000/);ui.input('sales-from','2026-10-27');ui.input('sales-to','2026-10-27');ui.click('[data-action="apply-filter"][data-key="sales"]');assert.match(ui.w.document.querySelector('.sales-period-total>strong').textContent,/-11,000/);assert.match(ui.w.document.querySelector('.return-history-list').textContent,/مرتجع يوم لاحق/);ui.click('[data-view="inventory"]');ui.click('[data-action="stock-history"][data-id="p0"]');assert.match(ui.w.document.querySelector('.drawer').textContent,/مرتجع يوم لاحق/);
});
test('checkout detects a newer tab even before this tab has seen a storage conflict',async t=>{
 const storage=new Map(),first=await setup(t,{storage});add(first);const second=await setup(t,{storage});second.click('[data-view="sales"]');second.click('[data-action="sale-hold"]');second.click('[data-action="sale-hold-confirm"]');first.click('[data-action="sale-complete"]');await tick();assert.equal(first.stored().sales.length,0);assert.match(first.w.document.getElementById('sale-error').textContent,/نافذة ثانية/);assert.equal(JSON.parse(storage.get('daftar.active-sale:/mvp/account')).heldOrders.length,1);
});
