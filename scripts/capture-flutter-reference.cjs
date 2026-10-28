// Reference capture only: original Electron UI, synthetic records, isolated profile.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const referenceRoot = path.join(root, 'electron-reference');
const referenceRequire = require('node:module').createRequire(path.join(referenceRoot, 'package.json'));
const { app, BrowserWindow, ipcMain } = referenceRequire('electron');
const out = path.join(root, 'docs/planning/flutter-rebuild/screenshots');
const M = referenceRequire('./app/ui/model.js');
const { previewFixture } = referenceRequire('./scripts/preview-fixture.cjs');
const date = '2026-10-27', stamp = date + 'T10:00:00.000Z';
app.setName('Daftar Reference Capture');
app.setPath('userData', path.join(root, 'dist/flutter-reference-profile'));
app.commandLine.appendSwitch('force-device-scale-factor', '1');
fs.mkdirSync(out, { recursive: true });
function fixture() {
  let s = previewFixture();
  s.preferences.restaurant = { name: 'مطعم توضيحي', contact: '', footer: 'شكراً لزيارتكم · بيانات توضيحية' };
  s.categories.push({ id:'gas', name:'الغاز', type:'additional' });
  s.days[date] = structuredClone(M.day(s, date));
  s.days[date].expenses = [
    {id:'expense-daily',categoryId:'bread',amount:15000,note:'مثال مصروف يومي',createdAt:stamp,funding:{source:'daily',dailyAmount:15000,cashAmount:0}},
    {id:'expense-shared',categoryId:'gas',amount:30000,note:'مثال دفع مشترك',createdAt:stamp,funding:{source:'shared',dailyAmount:20000,cashAmount:10000}},
    {id:'expense-cash',categoryId:'market',amount:10000,note:'مثال من القاصة',createdAt:stamp,funding:{source:'cash',dailyAmount:0,cashAmount:10000}}
  ];
  s.days[date].chickenUsed=12;s.days[date].chickenLeft=8;
  s.transactions.push({id:'deposit',date,type:'deposit',amount:300000,note:'رصيد توضيحي',createdAt:stamp},{id:'withdrawal',date,type:'withdrawal',amount:10000,note:'سحب توضيحي',createdAt:stamp});
  s.suppliers.push({id:'supplier',name:'مورد توضيحي',phone:'',note:'بيانات مصطنعة للمرجع فقط',categoryId:'market',openingBalance:50000,archived:false});
  s.materials.push({id:'rice',name:'رز توضيحي',unit:'كيلو',price:2500,priceCarton:40000,pricePiece:2500,archived:false});
  s.invoices.push({id:'invoice',supplierId:'supplier',number:'DEMO-001',date,lines:[{materialId:'rice',name:'رز توضيحي',unit:'كيلو',quantityCartons:2,quantityPieces:3,priceCarton:40000,pricePiece:2500}],note:'فاتورة توضيحية',createdAt:stamp});
  s.debts.push({id:'debt',supplierId:'supplier',date,amount:20000,note:'دين توضيحي',createdAt:stamp});
  s.payments.push({id:'payment',supplierId:'supplier',invoiceId:'invoice',date,amount:20000,invoiceAmount:20000,debtAmount:0,categoryId:'market',funding:{source:'shared',dailyAmount:15000,cashAmount:5000},note:'تسديد توضيحي',createdAt:stamp});
  s=M.validate(s);
  s=M.completeSale(s,{date,lines:[{productId:'p0',quantity:3},{productId:'p1',quantity:2}],discount:1001,orderType:'صالة',note:'بيع توضيحي'},'sale',stamp);
  s=M.returnSale(s,'sale',{date,reason:'مرتجع توضيحي',lines:[{productId:'p0',quantity:1,restock:true}]},'return',date+'T11:00:00.000Z');
  s=M.completeSale(s,{date,lines:[{productId:'p4',quantity:2}],discount:0,orderType:'سفري'},'sale-void',stamp);
  s=M.voidSale(s,'sale-void','تصحيح توضيحي',stamp);
  s=M.completeSale(s,{date,lines:[{productId:'p2',quantity:1}],discount:0,orderType:'توصيل'},'sale-paid',stamp);
  M.recordRemaining(s,date,100000);M.transferRemaining(s,date,20000,'transfer',stamp);
  return M.validate(s);
}
let stored=fixture(), failSave=false;
const manifest={capturedAt:new Date().toISOString(),date,appVersion:referenceRequire('./package.json').version,schema:stored.version,source:'electron-reference/ Electron UI; synthetic in-memory accounts only',screenshots:[],errors:[]};
const pages=['sales','sale-history','inventory','expenses','statement','suppliers','invoices','materials','payments','cash','categories','settings'];
app.whenReady().then(async()=>{
  ipcMain.handle('accounts:load',()=>({ok:true,data:stored,directory:'Isolated synthetic reference data'}));
  ipcMain.handle('accounts:save',(_e,d)=>failSave?{ok:false,error:'فشل حفظ توضيحي؛ السجلات لم تتغير'}:{ok:true,data:stored=M.validate(d)});
  ipcMain.handle('accounts:backup-info',()=>({ok:true,backupInfo:{lastExport:null,previousAvailable:true}}));
  for(const channel of ['pdf','export','import','folder','restore','print','open-export'])ipcMain.handle('accounts:'+channel,()=>({ok:true,canceled:true}));
  const win=new BrowserWindow({width:1440,height:1000,useContentSize:true,show:false,webPreferences:{preload:path.join(referenceRoot,'app/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false}});
  const run=code=>win.webContents.executeJavaScript(code);
  const settle=()=>run('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
  async function capture(id,title,phase,code='',mobile=false){
    try{
      if(code)await run(code);
      await settle();await new Promise(r=>setTimeout(r,190));
      const file=id+'.png';const img=await win.webContents.capturePage();fs.writeFileSync(path.join(out,file),img.toPNG());
      const meta=await run(`({view:typeof view==='undefined'?'report':view,title:document.querySelector('#drawer-title')?.textContent||document.querySelector('h1')?.textContent,width:innerWidth,height:innerHeight,scrollHeight:document.documentElement.scrollHeight,dialog:!!document.querySelector('.drawer')})`);
      manifest.screenshots.push({id,file,title,phase,mobile,...meta,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(out,file))).digest('hex')});
      console.log(id);
    }catch(e){manifest.errors.push({id,error:e.message});console.error(id,e.message);}
  }
  async function page(view){await run(`closeDrawer(true);sidebarCollapsed=true;selectedDate='${date}';view=${JSON.stringify(view)};render();window.scrollTo(0,0);`);await settle();}
  await win.loadFile(path.join(referenceRoot,'app/ui/index.html'));await new Promise(r=>setTimeout(r,500));
  win.webContents.debugger.attach('1.3');
  await run(`selectedDate='${date}';saleFilter={from:'${date}',to:'${date}',query:'',status:''};statementFilter={from:'${date}',to:'${date}',categoryId:'',source:'all'};selectedSupplier='supplier';`);
  const phases={sales:'06', 'sale-history':'08',inventory:'05',expenses:'09',statement:'10',suppliers:'11',invoices:'13',materials:'12',payments:'14',cash:'15',categories:'04',settings:'16'};
  for(const p of pages){await page(p);if(p==='sale-history'&&!await run(`document.querySelector('main').textContent.includes('S-000001')`))throw new Error('Populated sales history fixture not visible');await capture('desktop-'+p,p,phases[p]);
    const h=await run('document.documentElement.scrollHeight');if(h>1000)await capture('desktop-'+p+'-bottom',p+' — bottom',phases[p],'window.scrollTo(0,document.documentElement.scrollHeight)');
  }
  await page('sales');await capture('desktop-navigation','Navigation popover','03',`sidebarCollapsed=false;applySidebarState()`);await run('sidebarCollapsed=true;applySidebarState()');
  await capture('desktop-sales-cart','Active ticket','06',`saleDraft={...freshSaleDraft(),date:'${date}',lines:[{productId:'p0',quantity:2,price:12000,name:'كباب لحم',unit:'قطعة'},{productId:'p4',quantity:1,price:2000,name:'تمن أحمر',unit:'قطعة'}],discount:'1000'};persistSaleDraft();render()`);
  await capture('desktop-sales-compact','Compact product grid','06','compactCatalog=true;render()');await run('compactCatalog=false;render()');
  await capture('desktop-hold-order','Hold current order','07','holdOrderDialog()');await run('closeDrawer(true)');
  await capture('desktop-held-orders','Held orders','07',`heldOrders=[{id:'held-demo',label:'طلب توضيحي',savedAt:'${stamp}',draft:structuredClone(saleDraft)}];heldOrdersDialog()`);await run('closeDrawer(true)');
  const dialogs=[
    ['product-new','inventory','product',null,'05'],['product-edit','inventory','product','p0','05'],['stock','inventory','stock','p0','05'],['stock-history','inventory','stock-history','p0','05'],['stock-reverse','inventory','stock-reverse','opening0','05'],
    ['sale-paid','sale-history','sale-paid','sale-paid','06'],['receipt','sale-history','sale-receipt','sale','08'],['sale-return','sale-history','sale-return','sale','08'],['sale-void','sale-history','sale-void','sale-paid','08'],['void-receipt','sale-history','sale-receipt','sale-void','08'],
    ['expense-new','expenses','expense',null,'09'],['expense-edit','expenses','expense','expense-shared','09'],['remaining','expenses','remaining',null,'09'],['daily-transfer','expenses','remaining-transfer',null,'15'],['chicken','expenses','chicken',null,'09'],['balance','expenses','balance',null,'09'],['total','expenses','total',null,'09'],['day-date','expenses','day-date',null,'09'],
    ['supplier-new','suppliers','supplier',null,'11'],['supplier-edit','suppliers','supplier','supplier','11'],['debt','suppliers','debt','debt','11'],['material-new','materials','material',null,'12'],['material-edit','materials','material','rice','12'],['invoice-new','invoices','invoice',null,'13'],['invoice-edit','invoices','invoice','invoice','13'],['payment-new','payments','payment',null,'14'],['payment-edit','payments','payment','payment','14'],['cash-deposit','cash','deposit',null,'15'],['cash-withdrawal','cash','withdrawal',null,'15'],['cash-edit','cash','transaction','withdrawal','15'],['category-new','categories','category',null,'04'],['category-edit','categories','category','gas','04']
  ];
  for(const [id,p,kind,record,phase] of dialogs){await page(p);await capture('desktop-'+id,id,phase,`openDrawer(${JSON.stringify(kind)},${JSON.stringify(record)});${kind==='sale-return'?'refreshReturnQuote();':''}`);
    const overflow=await run(`Array.from(document.querySelectorAll('.drawer .form-content')).some(e=>e.scrollHeight>e.clientHeight+2)`);if(overflow)await capture('desktop-'+id+'-bottom',id+' — lower fields',phase,`document.querySelectorAll('.drawer .form-content').forEach(e=>e.scrollTop=e.scrollHeight)`);
  }
  for(const tab of ['debts','ledger']){await page('suppliers');await capture('desktop-supplier-'+tab,'Supplier '+tab,'11',`supplierTab='${tab}';render()`);}await run(`supplierTab='invoices'`);
  for(const section of ['restaurant','workflow','data','about']){await page('settings');await capture('desktop-settings-'+section,'Settings '+section,'16',`activateSettingsSection('${section}')`);await capture('desktop-settings-'+section+'-bottom','Settings '+section+' — bottom','16','window.scrollTo(0,document.documentElement.scrollHeight)');}
  await page('invoices');await capture('desktop-invoice-cartons','Invoice carton details expanded','13',`openDrawer('invoice','invoice');document.querySelectorAll('.invoice-line-details').forEach(e=>e.open=true)`);
  await page('sales');await capture('desktop-sales-catalog-bottom','Catalog lower items','06',`document.querySelectorAll('*').forEach(e=>{if(e.scrollHeight>e.clientHeight+20&&getComputedStyle(e).overflowY==='auto')e.scrollTop=e.scrollHeight;})`);
  await capture('desktop-sales-no-results','Catalog search empty state','06',`productSearch='NO-MATCH-DEMO';renderProducts()`);await run(`productSearch=''`);
  await page('expenses');await capture('desktop-validation','Invalid split expense','09',`openDrawer('expense','expense-shared');formError('مجموع حصة اليومي والقاصة لازم يساوي مبلغ المصروف.')`);
  await page('expenses');await capture('desktop-day-review','Day review','10','dayReview()');
  await page('expenses');await capture('desktop-cash-popout','Cash context','15',`document.querySelector('[data-action="cash-popout"]').click()`);
  await page('suppliers');await capture('desktop-supplier-picker','Supplier picker','11',`document.querySelector('[data-action="supplier-picker"]').click()`);
  await run('closeDrawer(true);window.captureSavedState=structuredClone(state);state=M.empty();selectedSupplier=null;resetSaleDraftWithoutWrite()');
  for(const p of pages){await page(p);await capture('empty-'+p,p+' — empty data',phases[p]);}
  await run(`state=window.captureSavedState;selectedSupplier='supplier';delete window.captureSavedState`);
  await page('sales');await capture('desktop-save-error','Save failed with ticket retained','02',`status('تعذر الحفظ — مثال توضيحي',true);toast('تعذر الحفظ. الفاتورة الحالية محفوظة كمسودة.',true)`);await run(`status('محفوظ على جهازك')`);
  // Narrow references are the current web UI, not approved native phone designs.
  win.setContentSize(390,844);await settle();
  for(const p of pages){await page(p);await capture('phone-'+p,p+' — narrow current UI',phases[p],'',true);const h=await run('document.documentElement.scrollHeight');if(h>844)await capture('phone-'+p+'-bottom',p+' — bottom',phases[p],'window.scrollTo(0,document.documentElement.scrollHeight)',true);}
  await page('sales');await capture('phone-sales-cart','Active ticket — narrow','06',`saleDraft={...freshSaleDraft(),date:'${date}',lines:[{productId:'p0',quantity:2,price:12000,name:'كباب لحم',unit:'قطعة'},{productId:'p4',quantity:1,price:2000,name:'تمن أحمر',unit:'قطعة'}],discount:'1000'};persistSaleDraft();render()`,true);
  await capture('phone-sales-cart-bottom','Active ticket checkout — narrow','06','window.scrollTo(0,document.documentElement.scrollHeight)',true);
  for(const section of ['restaurant','workflow','data','about']){await page('settings');await capture('phone-settings-'+section,'Settings '+section+' — narrow','16',`activateSettingsSection('${section}')`,true);await capture('phone-settings-'+section+'-bottom','Settings '+section+' — lower','16','window.scrollTo(0,document.documentElement.scrollHeight)',true);}
  for(const [id,p,kind,record,phase] of dialogs.filter(d=>['product-new','invoice-new','payment-new','expense-new','sale-return','receipt'].includes(d[0]))){await page(p);await capture('phone-'+id,id+' — narrow dialog',phase,`openDrawer(${JSON.stringify(kind)},${JSON.stringify(record)});${kind==='sale-return'?'refreshReturnQuote();':''}`,true);await capture('phone-'+id+'-bottom',id+' — lower fields',phase,`document.querySelectorAll('.drawer .form-content').forEach(e=>e.scrollTop=e.scrollHeight)`,true);}
  // Capture full natural document content through Chromium, without altering CSS.
  await run('closeDrawer(true)');
  for(const p of pages){await page(p);await settle();const metrics=await win.webContents.debugger.sendCommand('Page.getLayoutMetrics');const size=metrics.cssContentSize||metrics.contentSize;const file='full-phone-'+p+'.png';const data=await win.webContents.debugger.sendCommand('Page.captureScreenshot',{format:'png',captureBeyondViewport:true,clip:{x:0,y:0,width:390,height:Math.max(844,Math.ceil(size.height)),scale:1}});fs.writeFileSync(path.join(out,file),Buffer.from(data.data,'base64'));manifest.screenshots.push({id:'full-phone-'+p,file,title:p+' — narrow full document',phase:phases[p],width:390,height:Math.max(844,Math.ceil(size.height)),fullDocument:true,mobile:true});}
  win.setContentSize(1440,1000);await settle();
  for(const p of pages){await page(p);await settle();const metrics=await win.webContents.debugger.sendCommand('Page.getLayoutMetrics');const size=metrics.cssContentSize||metrics.contentSize;const file='full-'+p+'.png';const data=await win.webContents.debugger.sendCommand('Page.captureScreenshot',{format:'png',captureBeyondViewport:true,clip:{x:0,y:0,width:1440,height:Math.max(1000,Math.ceil(size.height)),scale:1}});fs.writeFileSync(path.join(out,file),Buffer.from(data.data,'base64'));manifest.screenshots.push({id:'full-'+p,file,title:p+' — full document',phase:phases[p],width:1440,height:Math.max(1000,Math.ceil(size.height)),fullDocument:true});}
  const tokens=await run(`(()=>{const cs=getComputedStyle(document.documentElement);return {tokens:Object.fromEntries(['--bg','--paper','--ink','--muted','--line','--green','--lime','--soft','--red','--radius','--focus','--control-height','--page-gutter','--panel-padding'].map(k=>[k,cs.getPropertyValue(k).trim()])),body:{font:getComputedStyle(document.body).fontFamily,fontSize:getComputedStyle(document.body).fontSize},components:Object.fromEntries(['h1','.button','.panel','.shortcut-bar'].map(k=>{const el=document.querySelector(k);if(!el)return[k,null];const s=getComputedStyle(el);return[k,{fontSize:s.fontSize,lineHeight:s.lineHeight,padding:s.padding,borderRadius:s.borderRadius,gap:s.gap}]}))}})()`);
  fs.writeFileSync(path.join(out,'../design-tokens.json'),JSON.stringify(tokens,null,2)+'\n');
  const {createReport}=referenceRequire('./app/reports/pdf.cjs');
  for(const [kind,request] of Object.entries({daily:{kind:'daily',date},invoice:{kind:'invoice',id:'invoice'},sale:{kind:'sale',id:'sale'},sales:{kind:'sales',filter:{from:date,to:date}},statement:{kind:'statement',filter:{from:date,to:date}},cash:{kind:'cash',filter:{from:date,to:date}},payment:{kind:'payment',id:'payment'}})){
    const report=createReport(fixture(),request);const file=path.join(root,'dist','flutter-report-'+kind+'.html');fs.writeFileSync(file,report.html);await win.loadFile(file);win.setContentSize(794,1123);await settle();await capture('report-'+kind,'Current report HTML — '+kind,'17');
    const metrics=await win.webContents.debugger.sendCommand('Page.getLayoutMetrics');const size=metrics.cssContentSize||metrics.contentSize;const png=await win.webContents.debugger.sendCommand('Page.captureScreenshot',{format:'png',captureBeyondViewport:true,clip:{x:0,y:0,width:794,height:Math.max(1123,Math.ceil(size.height)),scale:1}});const full='report-'+kind+'-full.png';fs.writeFileSync(path.join(out,full),Buffer.from(png.data,'base64'));manifest.screenshots.push({id:'report-'+kind+'-full',file:full,title:'Report HTML full document — '+kind,phase:'17',width:794,height:Math.max(1123,Math.ceil(size.height)),fullDocument:true});
  }
  const board=path.join(out,'../design-system.html');
  if(fs.existsSync(board)){await win.loadFile(board);win.setContentSize(1440,1200);await settle();await capture('design-system','Extracted current design system reference board','01');}
  for(const file of ['index.html','styles.css','commerce.css','ux.css','commerce.js','renderer.js','suppliers.js','ux.js','model.js'])manifest.sourceHashes={...manifest.sourceHashes,[file]:crypto.createHash('sha256').update(fs.readFileSync(path.join(referenceRoot,'app/ui',file))).digest('hex')};
  for(const item of manifest.screenshots){const bytes=fs.readFileSync(path.join(out,item.file));item.pixelWidth=bytes.readUInt32BE(16);item.pixelHeight=bytes.readUInt32BE(20);item.sha256=crypto.createHash('sha256').update(bytes).digest('hex');}
  fs.writeFileSync(path.join(out,'../screenshot-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  console.log(JSON.stringify({screenshots:manifest.screenshots.length,errors:manifest.errors}));app.quit();
}).catch(e=>{console.error(e);app.exit(1)});
