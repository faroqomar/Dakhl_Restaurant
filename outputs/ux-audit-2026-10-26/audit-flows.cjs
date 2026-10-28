const {_electron}=require('/Users/eros/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root='/Users/eros/Dev/Eros_Projects/ResturanetAccounting', out=path.join(root,'outputs/ux-audit-2026-10-26');
fs.mkdirSync(out,{recursive:true});
const M=require(root+'/app/ui/model.js'),{fixture}=require(root+'/tests/commerce-fixture.cjs');
const date='2026-10-26', yesterday='2026-10-25',stamp=d=>d+'T10:00:00Z';
function seed(){
 let s=fixture();
 s.transactions.push({id:'cash-opening',date:yesterday,type:'deposit',amount:500000,note:'Audit sample',createdAt:stamp(yesterday)});
 s.days[date]={...M.day(s,date),expenses:[{id:'shared-exp',categoryId:'bread',amount:30000,note:'Audit shared expense',funding:{source:'shared',dailyAmount:18000,cashAmount:12000},createdAt:stamp(date)},{id:'cash-exp',categoryId:'market',amount:10000,note:'Audit cash expense',funding:{source:'cash',dailyAmount:0,cashAmount:10000},createdAt:stamp(date)}]};
 s.days[yesterday]={...M.day(s,yesterday),expenses:[{id:'older-exp',categoryId:'samoon',amount:7000,note:'Audit older expense',createdAt:stamp(yesterday)}]};
 M.recordRemaining(s,date,100000);
 s.suppliers.push({id:'supplier1',name:'مورد تجريبي أ',phone:'',note:'بيانات مراجعة فقط',categoryId:'market',openingBalance:50000,materials:[]},{id:'supplier2',name:'مورد تجريبي ب',phone:'',note:'',categoryId:'market',openingBalance:0,materials:[]});
 s.materials.push({id:'mat1',name:'رز تجريبي',unit:'كيلو',priceCarton:60000,pricePiece:5000,archived:false});
 s.invoices.push({id:'invoice1',supplierId:'supplier1',number:'QA-001',date:yesterday,createdAt:stamp(yesterday),note:'',lines:[{materialId:'mat1',name:'رز تجريبي',unit:'كيلو',quantityCartons:0,quantityPieces:2.5,priceCarton:60000,pricePiece:5000}]});
 s.payments.push({id:'payment1',supplierId:'supplier1',invoiceId:'invoice1',categoryId:'market',date,amount:2500,invoiceAmount:2500,debtAmount:0,funding:{source:'daily',dailyAmount:2500,cashAmount:0},note:'',createdAt:stamp(date)});
 s.workers.push({id:'worker1',name:'عامل تجريبي',amount:1000,frequency:'daily',startDate:yesterday,archived:false,note:''});
 s.savingsEntries.push({id:'saving1',workerId:'worker1',type:'contribution',date:yesterday,amount:1000,dueAmount:1000,periodStart:yesterday,periodEnd:yesterday,note:'',createdAt:stamp(yesterday)},{id:'saving2',workerId:'worker1',type:'contribution',date,amount:1000,dueAmount:1000,periodStart:date,periodEnd:date,note:'',createdAt:stamp(date)});
 return M.completeSale(M.validate(s),{date,lines:[{productId:'p0',quantity:1}],discount:0,paid:12000,orderType:'صالة',note:''},'sale1',stamp(date));
}
(async()=>{
 const browser=await _electron.launch({executablePath:root+'/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron',args:[root+'/outputs/ux-audit-2026-10-26/audit-shell.cjs']});
 const page=await browser.firstWindow();const context=page.context();await page.setViewportSize({width:1440,height:1000});
 let initial=seed();
 await context.route('**/bridge.js',route=>route.fulfill({contentType:'application/javascript',body:`window.auditSaved=${JSON.stringify(initial)};window.auditFail=false;window.auditDelay=0;window.daftar={load:async()=>({ok:true,data:structuredClone(window.auditSaved),directory:'Isolated UX audit sample data'}),save:async data=>{await new Promise(r=>setTimeout(r,window.auditDelay));if(window.auditFail)return {ok:false,error:'اختبار: تعذّر الحفظ'};window.auditSaved=DaftarModel.validate(data);return {ok:true,data:structuredClone(window.auditSaved)};},pdf:async r=>{window.auditPDF=r;return {ok:true,filePath:'/audit/sample.pdf'}},export:async()=>({ok:true}),import:async()=>({ok:true,canceled:true}),folder:async()=>({ok:true}),onAction:cb=>window.auditMenu=cb};`}));
 page.setDefaultTimeout(5000);
 const errors=[], evidence={pages:[],flows:[],bugs:{},geometry:[],accessibility:{}};
 page.on('pageerror',e=>errors.push(e.message));
 const nav=async v=>{await page.locator('#navigation [data-view="'+v+'"]').click();};
 const click=async s=>{await page.locator(s).first().click();await page.waitForTimeout(100);};
 const close=async()=>{if(await page.locator('.drawer').count())await page.locator('.drawer-top [data-action="close-drawer"]').click();};
 const submit=async()=>{await page.locator('.drawer-form [type="submit"]').click();await page.waitForTimeout(80);};
 const shot=async name=>page.screenshot({path:path.join(out,name+'.png'),fullPage:true});
 const reset=async s=>{initial=s||seed();await page.goto('http://127.0.0.1:4317/');await page.locator('#navigation').waitFor();await page.locator('.page-header').waitFor();};
 try{
  await reset();
  for(const v of M.destinations){await nav(v);await page.waitForTimeout(100);await shot(v);evidence.pages.push({view:v,title:await page.locator('h1').innerText(),buttons:await page.locator('main button').count(),overflow:await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)});}
  // Prove funding summary and cross-date editing behavior.
  await nav('statement');await page.locator('#statement-category').selectOption('bread');await page.locator('#statement-source').selectOption('cash');
  evidence.bugs.cashFilteredSummary=await page.locator('.invoice-analysis-summary').innerText();await shot('bug-statement-cash');
  await page.locator('#statement-category').selectOption('');await page.locator('#statement-source').selectOption('all');
  await click('[data-action="edit-expense"][data-id="older-exp"]');
  evidence.bugs.oldExpenseForm={title:await page.locator('#drawer-title').innerText(),amount:await page.locator('#amount').inputValue(),date:await page.locator('#date').inputValue()};await shot('bug-edit-older-expense');await close();
  await nav('expenses');await click('[data-action="total"]');evidence.bugs.dailyTotalDialog=await page.locator('.drawer-summary').innerText();await close();
  // Draft form loss.
  await click('[data-action="expense"]');await page.locator('#amount').fill('12345');await page.keyboard.press('Escape');await click('[data-action="expense"]');evidence.bugs.drawerDraftAfterEscape=await page.locator('#amount').inputValue();await close();
  // Sale flow, cart discard, focus, failure/retry, cancellation.
  await nav('sales');await click('[data-action="sale-add"][data-id="p1"]');
  evidence.bugs.focusAfterAdd=await page.evaluate(()=>({tag:document.activeElement.tagName,id:document.activeElement.id}));
  await nav('cash');await nav('sales');assert.equal(await page.locator('.cart-line').count(),1);evidence.flows.push('Sale draft survives navigation');
  await click('[data-action="sale-clear"]');evidence.bugs.clearWithoutConfirm=await page.locator('.cart-line').count();
  await click('[data-action="sale-add"][data-id="p1"]');await page.evaluate(()=>window.auditFail=true);await click('#checkout-button');
  evidence.flows.push({saveFailurePreservesCart:await page.locator('.cart-line').count(),error:await page.locator('#toast').innerText()});
  await page.evaluate(()=>window.auditFail=false);await click('#checkout-button');await page.locator('.sale-receipt').waitFor();evidence.flows.push('Sale saved after retry; receipt shown');
  await click('[data-action="sale-void"]');await page.locator('#void-reason').fill('إلغاء تجريبي للمراجعة');await submit();assert.equal(await page.evaluate(()=>window.auditSaved.sales.at(-1).status),'void');evidence.flows.push('Sale cancellation with reason succeeds');
  await nav('sales');await click('[data-action="sale-add"][data-id="p0"]');await page.reload();await nav('sales');evidence.bugs.cartAfterReload=await page.locator('.cart-line').count();
  // Product identity collision and order drift on edit.
  await page.locator('#product-search').fill('no-match-audit');await click('[data-action="product-new"]');evidence.bugs.duplicateGroupIDs=await page.locator('#product-group').count();await close();await page.locator('#product-search').fill('');
  await nav('inventory');await click('[data-action="product-edit"][data-id="p0"]');await submit();evidence.bugs.productOrderAfterEdit=await page.evaluate(()=>window.auditSaved.products.map(p=>p.id));
  await page.locator('#inventory-search').fill('no-match-audit');evidence.bugs.inventoryNoMatch=await page.locator('#inventory-list').innerText();
  // History and worker dates.
  await nav('savings');await page.locator('#savings-date').fill(yesterday);await page.locator('#savings-date').dispatchEvent('change');
  evidence.bugs.savingsAsOf={summary:await page.locator('.summary').innerText(),log:await page.locator('.savings-panel').last().innerText()};
  await nav('invoices');evidence.bugs.purchaseFractionDisplay=await page.locator('.invoice-analysis-summary').innerText();
  await click('[data-action="invoice-new"]');await page.locator('#invoice-number').fill('QA-NEW');await page.locator('.line-name-input').fill('رز تجريبي');await page.locator('.line-name-input').dispatchEvent('change');await page.locator('.line-pieces').fill('1');await page.locator('#amount').fill('5000');await page.locator('#amount').dispatchEvent('input');
  evidence.bugs.newInvoicePreview={before:await page.locator('#invoice-old-balance').innerText(),after:await page.locator('#invoice-current-balance').innerText(),paymentText:await page.locator('#invoice-payment-split').innerText()};await shot('invoice-form');await close();
  // Successful primary workflows, using only the isolated bridge.
  await nav('expenses');await click('[data-action="expense"]');await page.locator('#amount').fill('١٢٣٤');await submit();assert.equal(await page.evaluate(()=>window.auditSaved.days['2026-10-26'].expenses.at(-1).amount),1234);evidence.flows.push('Arabic-number expense create');
  await click('[data-action="remaining"]');await page.locator('#amount').fill('50000');await submit();await click('[data-action="remaining-transfer"]');await page.locator('#amount').fill('10000');await submit();evidence.flows.push('Remaining balance then partial cash transfer');
  await nav('cash');await click('[data-action="edit-transaction"][data-kind="transfer"]');await click('[data-action="ask-delete"]');await click('[data-action="confirm-delete"]');await page.waitForTimeout(80);await page.evaluate(()=>window.auditMenu('undo'));await page.waitForTimeout(80);evidence.flows.push('Transfer delete then session undo');
  await nav('suppliers');await click('[data-action="supplier-new"]');await page.locator('#supplier-name').fill('مورد تدفق المراجعة');await submit();evidence.flows.push('Supplier creation');
  await nav('invoices');await click('[data-action="invoice-new"]');await page.locator('#invoice-number').fill('QA-FLOW');await page.locator('.line-name-input').fill('مادة تدفق');await page.locator('.line-pieces').fill('2.5');await page.locator('.line-piece-price').fill('5000');await page.locator('#amount').fill('2500');await submit();assert.equal(await page.locator('.drawer').count(),0);evidence.flows.push('Purchase invoice with fractional quantity and partial payment');
  await nav('payments');await click('[data-action="payment-edit"]');await page.locator('#amount').fill('3000');await submit();evidence.flows.push('Payment edit');
  await nav('savings');await page.locator('#savings-date').fill(date);await page.locator('#savings-date').dispatchEvent('change');await click('[data-action="savings-receive"]');await page.locator('#amount').fill('500');await submit();evidence.flows.push('Worker pool receipt');
  await nav('inventory');await page.locator('#inventory-search').fill('');await click('[data-action="stock-new"][data-id="p1"]');await page.locator('#stock-quantity').fill('2');await submit();evidence.flows.push('Stock restock');
  await nav('settings');await page.locator('#shortcut-0').selectOption('statement');await page.locator('#shortcut-form [type="submit"]').click();await page.waitForTimeout(80);await page.locator('#order-types-list').fill('صالة\nسفري\nتوصيل خاص');await page.locator('#order-types-form [type="submit"]').click();await page.waitForTimeout(80);evidence.flows.push('Shortcut and order type settings save');
  // Additional edge cases in selling and recovery.
  await reset();await nav('sales');await click('[data-action="sale-add"][data-id="p0"]');await page.locator('#sale-date').fill('');await page.locator('#sale-date').dispatchEvent('change');
  evidence.bugs.blankSaleDate={visible:await page.locator('#sale-date').inputValue(),draft:await page.evaluate(()=>saleDraft.date),checkoutEnabled:await page.locator('#checkout-button').isEnabled()};
  await click('#checkout-button');await close();await page.evaluate(()=>window.auditMenu('undo'));await page.waitForTimeout(100);evidence.bugs.undoSale={salesAfterUndo:await page.evaluate(()=>window.auditSaved.sales.length),originalSales:1};
  await click('[data-action="sale-add"][data-id="p0"]');await nav('inventory');await click('[data-action="product-edit"][data-id="p0"]');await page.locator('input[name="archived"]').check();await submit();await nav('sales');await click('[data-action="sale-remove"][data-id="p0"]');evidence.bugs.archivedCartLineAfterRemove=await page.locator('.cart-line').count();
  let fractional=seed();fractional.stockEntries.find(e=>e.productId==='p1').quantity=0.5;await reset(fractional);await nav('sales');await click('[data-action="sale-add"][data-id="p1"]');evidence.bugs.fractionalStock={stock:0.5,cartLines:await page.locator('.cart-line').count(),message:await page.locator('#toast').innerText()};
  let future=seed();future.stockEntries.push({id:'future-stock',productId:'p1',date:'2026-10-27',quantity:10,kind:'restock',note:'',createdAt:stamp(date)});await reset(future);await nav('inventory');evidence.bugs.futureStockInventory=await page.locator('tr').filter({has:page.locator('[data-action="product-edit"][data-id="p1"]')}).innerText();await nav('sales');evidence.bugs.futureStockSales=await page.locator('.product-tile[data-id="p1"]').innerText();
  await reset();await nav('inventory');await click('[data-action="product-new"]');await page.locator('#product-name').fill('صنف مراجعة');await page.locator('#amount').fill('2500');await page.locator('#opening-quantity').fill('5');await submit();evidence.flows.push('Product creation with opening stock');
  const newProduct=await page.evaluate(()=>window.auditSaved.products.at(-1).id);await click('[data-action="stock-new"][data-id="'+newProduct+'"]');await page.locator('#stock-kind').selectOption('adjustment');await page.locator('#stock-quantity').fill('1');await submit();evidence.flows.push('Stock damage adjustment');
  await nav('categories');await click('[data-action="category"]');await page.locator('#name').fill('خانة مراجعة');await submit();evidence.flows.push('Category creation');
  await nav('savings');await click('[data-action="worker-new"]');await page.locator('#worker-name').fill('عامل تدفق');await page.locator('#amount').fill('2000');await submit();const wid=await page.evaluate(()=>window.auditSaved.workers.at(-1).id);await click('[data-action="savings-pay"][data-id="'+wid+'"]');await page.locator('#amount').fill('1000');await submit();evidence.flows.push('Worker creation and partial contribution');
  await nav('invoices');await click('[data-action="invoice-edit"][data-id="invoice1"]');await click('[data-action="ask-delete"]');await click('[data-action="confirm-delete"]');evidence.flows.push({paidInvoiceDeleteBlocked:await page.locator('#form-error').innerText()});await close();
  // Keyboard semantics, label naming, target and layout measurements.
  await reset();await nav('sales');await click('[data-action="sale-add"][data-id="p0"]');
  evidence.accessibility.smallTargets=await page.locator('button,input,select').evaluateAll(es=>es.filter(e=>e.getClientRects().length).map(e=>({label:e.getAttribute('aria-label')||e.textContent.trim()||e.id,w:Math.round(e.getBoundingClientRect().width),h:Math.round(e.getBoundingClientRect().height)})).filter(e=>e.w<24||e.h<24));
  evidence.accessibility.searchNames=await page.locator('#product-search').evaluate(e=>({labels:[...e.labels].map(l=>l.textContent),aria:e.getAttribute('aria-label'),placeholder:e.placeholder}));
  for(const [width,height]of [[1440,1000],[1252,943],[1000,700],[900,580],[760,844],[390,844],[390,640]]){
   await page.setViewportSize({width,height});
   for(const collapsed of [false,true]){
    await page.evaluate(c=>{sidebarCollapsed=c;applySidebarState();},collapsed);
    evidence.geometry.push(await page.evaluate(({width,height,collapsed})=>{const box=s=>{const e=document.querySelector(s),r=e.getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height,bottom:r.bottom,scroll:e.scrollHeight,client:e.clientHeight}};return{width,height,collapsed,horizontal:document.documentElement.scrollWidth>innerWidth,grid:box('#product-grid'),cart:box('#cart-lines'),checkout:box('#checkout-button'),bill:box('.pos-bill'),sidebar:box('.sidebar')}},{width,height,collapsed}));
    if(width===900||width===390)await shot(`sales-${width}-${height}-${collapsed?'closed':'open'}`);
   }
  }
  await page.setViewportSize({width:900,height:580});await page.evaluate(()=>{sidebarCollapsed=false;applySidebarState();});
  for(const v of ['expenses','statement','suppliers','invoices','cash','savings','settings']){await nav(v);await shot(v+'-900');evidence.geometry.push({view:v,width:900,height:580,...await page.evaluate(()=>({horizontal:document.documentElement.scrollWidth>innerWidth,scrollWidth:document.documentElement.scrollWidth}))});}
  // Empty-start dependency failure. Keep it last as failed drawer state blocks normal nav.
  await page.setViewportSize({width:1440,height:1000});await reset(M.empty());await nav('invoices');await click('[data-action="invoice-new"]');await page.waitForTimeout(100);await nav('inventory');
  evidence.bugs.noSupplierInvoice={errors:[...errors],drawerCount:await page.locator('.drawer').count(),title:await page.locator('h1').innerText(),drawerState:await page.evaluate(()=>drawer)};
  await shot('bug-empty-invoice');
  evidence.errors=errors;fs.writeFileSync(out+'/evidence.json',JSON.stringify(evidence,null,2));console.log(JSON.stringify({completed:true,pages:evidence.pages.length,flows:evidence.flows,bugs:evidence.bugs,errors},null,2));
 }finally{fs.writeFileSync(out+'/evidence.json',JSON.stringify(evidence,null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
