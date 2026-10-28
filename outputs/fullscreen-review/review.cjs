const {app,BrowserWindow,ipcMain}=require('electron'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),stage=process.env.DAFTAR_REVIEW_STAGE||'before';
app.setPath('userData',path.join(__dirname,'isolated-profile'));
const state=require(path.join(root,'scripts/preview-fixture.cjs')).previewFixture();
if(process.env.DAFTAR_REVIEW_POPULATED==='1'){
 const M=require(path.join(root,'app/ui/model.js')),date=M.dateKey(),stamp=date+'T10:00:00.000Z';
 state.days[date]=M.day(state,date);
 state.transactions.push({id:'layout-opening',type:'deposit',date,amount:1000000,note:'عينة مراجعة معزولة',createdAt:stamp});
 for(let i=0;i<8;i++)state.days[date].expenses.push({id:'layout-expense-'+i,categoryId:state.categories[i%state.categories.length].id,amount:12000+i*3500,note:'ملاحظة توضيحية لمراجعة المحاذاة وعرض السطر',funding:{source:i<5?'daily':'cash',dailyAmount:i<5?12000+i*3500:0,cashAmount:i<5?0:12000+i*3500},createdAt:stamp});
 M.recordRemaining(state,date,200000);M.validate(state);
}
ipcMain.handle('accounts:load',()=>({ok:true,data:state,directory:'Isolated screenshot review · sample data only'}));
ipcMain.handle('accounts:save',()=>({ok:false,error:'Read-only screenshot review'}));
app.whenReady().then(async()=>{try{
const w=new BrowserWindow({show:false,width:1512,height:982,useContentSize:true,webPreferences:{preload:path.join(root,'app/preload.cjs'),sandbox:true,contextIsolation:true,nodeIntegration:false}});
await w.loadFile(path.join(root,'app/ui/index.html'));
fs.mkdirSync(path.join(__dirname,stage),{recursive:true});
const results=[];
for(const [width,height] of [[1512,982],[1920,1080],[1024,768],[390,844]]){
 w.setContentSize(width,height);
 for(const view of ['sales','expenses','sale-history','inventory','statement','suppliers','invoices','materials','payments','cash','categories','settings']){
 await w.webContents.executeJavaScript(`document.querySelector('#navigation [data-view="${view}"]').click()`);
 if(view==='settings')await w.webContents.executeJavaScript(`document.querySelector('#settings-tab-restaurant').click()`);
 if(view==='sales')await w.webContents.executeJavaScript(`if(!document.querySelectorAll('.cart-line').length)for(let i=0;i<15;i++)document.querySelectorAll('#product-grid [data-action="sale-add"]')[i].click();`);
 await new Promise(resolve=>setTimeout(resolve,120));
 await w.webContents.executeJavaScript(`Promise.all(Array.from(document.images).filter(img=>img.complete).map(img=>img.decode().catch(()=>{}))).then(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))))`);
 const info=await w.webContents.executeJavaScript(`(()=>{const rect=s=>{const r=document.querySelector(s)?.getBoundingClientRect();return r?{x:r.x,y:r.y,width:r.width,height:r.height}:null};return {view:'${view}',width:innerWidth,height:innerHeight,main:rect('main'),toolbar:rect('.shortcut-bar'),panel:rect('main .panel'),gutter:parseFloat(getComputedStyle(document.querySelector('main')).paddingInlineStart),header:rect('.page-header'),summary:rect('.summary'),offenders:Array.from(document.querySelectorAll('main *')).filter(e=>{const r=e.getBoundingClientRect();return r.width&& (r.left< -1||r.right>innerWidth+1)}).slice(0,15).map(e=>({tag:e.tagName,cls:e.className,width:e.getBoundingClientRect().width,x:e.getBoundingClientRect().x})),overflow:document.documentElement.scrollWidth>innerWidth,hasHeading:!!document.querySelector('main h1'),heading:document.querySelector('main h1')?.textContent,activeView:document.querySelector('.shortcut[aria-current=page]')?.dataset.view,pageHeight:document.documentElement.scrollHeight};})()`);
 results.push(info);
 if(width===1512||width===1920||view==='expenses'||view==='cash')fs.writeFileSync(path.join(__dirname,stage,`${width}-${view}.png`),(await w.webContents.capturePage()).toPNG());
 if(view==='settings')for(const section of ['workflow','data','about']){
  await w.webContents.executeJavaScript(`document.querySelector('#settings-tab-${section}').click()`);
  await new Promise(resolve=>setTimeout(resolve,80));
  results.push(await w.webContents.executeJavaScript(`({view:'settings-${section}',width:innerWidth,offenders:Array.from(document.querySelectorAll('main *')).filter(e=>{const r=e.getBoundingClientRect();return r.width&& (r.left< -1||r.right>innerWidth+1)}).slice(0,15).map(e=>({tag:e.tagName,cls:e.className,width:e.getBoundingClientRect().width,x:e.getBoundingClientRect().x})),overflow:document.documentElement.scrollWidth>innerWidth,hasHeading:!!document.querySelector('main h1')})`));
  if(width===1512||width===1920||view==='expenses'||view==='cash')fs.writeFileSync(path.join(__dirname,stage,`${width}-settings-${section}.png`),(await w.webContents.capturePage()).toPNG());
 }

 }
}
fs.writeFileSync(path.join(__dirname,stage,'results.json'),JSON.stringify(results,null,2));
console.log(JSON.stringify({cases:results.length,failures:results.filter(r=>r.overflow||!r.hasHeading),tallHeaders:results.filter(r=>r.header?.height>200).map(r=>({view:r.view,width:r.width,height:r.header.height}))}));app.quit();
}catch(e){console.error(e);app.exit(1)}});
