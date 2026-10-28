const {app,BrowserWindow,ipcMain}=require('electron');
const path=require('node:path'),fs=require('node:fs');
const root=path.resolve(__dirname,'../..');
app.setPath('userData',path.join(__dirname,'profile'));
const state=require(path.join(root,'tests/commerce-fixture.cjs')).fixture();
ipcMain.handle('accounts:load',()=>({ok:true,data:state,directory:'isolated-preview'}));
ipcMain.handle('accounts:save',()=>{throw Error('Read-only layout review');});
app.whenReady().then(async()=>{try{
 const w=new BrowserWindow({show:false,width:1512,height:960,webPreferences:{preload:path.join(root,'app/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});
 await w.loadFile(path.join(root,'app/ui/index.html'));
 const results=[];
 for(const width of [1512,1024,390]){
  w.setSize(width,960);
  for(const view of ['expenses','sales','sale-history','inventory','statement','suppliers','invoices','materials','payments','cash','categories','settings']){
   await w.webContents.executeJavaScript(`document.querySelector('#navigation [data-view="${view}"]').click()`);
   await new Promise(r=>setTimeout(r,60));
   const result=await w.webContents.executeJavaScript(`(()=>{const m=document.querySelector('main'),r=m.getBoundingClientRect();return {width:innerWidth,mainWidth:r.width,overflow:document.documentElement.scrollWidth>innerWidth,heading:!!m.querySelector('h1')}})()`);
   results.push({view,...result});
   if(width===1512&&view==='expenses')fs.writeFileSync(path.join(__dirname,'expenses.png'),(await w.webContents.capturePage()).toPNG());
  }
 }
 fs.writeFileSync(path.join(__dirname,'results.json'),JSON.stringify(results,null,2));
 console.log(JSON.stringify({screens:results.length,failures:results.filter(x=>x.overflow||!x.heading),wideWidths:[...new Set(results.filter(x=>x.width===1512).map(x=>x.mainWidth))]}));
 app.quit();
}catch(e){console.error(e);app.exit(1)}});
