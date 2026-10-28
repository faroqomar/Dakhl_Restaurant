const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),vm=require('node:vm'),{createRequire}=require('node:module');
const M=require('../app/ui/model.js'),main=path.resolve(__dirname,'../app/main.cjs');
async function harness(t,corrupt=false){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'daftar-recovery-test-'));t.after(()=>fs.rmSync(temp,{recursive:true,force:true}));const directory=path.join(temp,'Daftar');fs.mkdirSync(directory);
 const previous=M.empty();previous.preferences.restaurant.name='السابقة';fs.writeFileSync(path.join(directory,'accounts.backup.json'),JSON.stringify(previous));const current=M.empty();current.preferences.restaurant.name='الحالية';fs.writeFileSync(path.join(directory,'accounts.json'),corrupt?'corrupt':JSON.stringify(current));
 const handlers={},dialogs=[],opened=[],queue=[];let window;
 const app={setName(){},setPath(){},getPath:()=>temp,requestSingleInstanceLock:()=>true,on(){},whenReady:()=>Promise.resolve(),setAboutPanelOptions(){},getVersion:()=> 'test'};
 class BrowserWindow{constructor(){window=this;this.webContents={setWindowOpenHandler(){},on(){},session:{setPermissionRequestHandler(){},webRequest:{onBeforeRequest(){}}}};}on(){}once(){}loadURL(url){this.url=url;}}
 const electron={app,BrowserWindow,Menu:{setApplicationMenu(){},buildFromTemplate:x=>x},ipcMain:{handle:(name,fn)=>handlers[name]=fn},screen:{getPrimaryDisplay:()=>({workArea:{x:0,y:0,width:1440,height:1000}})},dialog:{showOpenDialog:async()=>queue.shift(),showSaveDialog:async()=>queue.shift(),showMessageBox:async(_w,options)=>{dialogs.push(options);return queue.shift();}},shell:{openPath:async p=>{opened.push(p);return '';},showItemInFolder:p=>opened.push(p)}};
 const req=createRequire(main);vm.runInNewContext(fs.readFileSync(main,'utf8'),{require:n=>n==='electron'?electron:req(n),__dirname:path.dirname(main),structuredClone,Buffer},{filename:main});await new Promise(r=>setImmediate(r));
 return{temp,directory,dialogs,opened,queue,current,previous,call:(key,...args)=>handlers['accounts:'+key]({sender:window.webContents,senderFrame:{url:window.url}},...args)};
}
test('native import previews both datasets, cancel preserves records, confirm saves recovery copy',async t=>{
 const h=await harness(t),imported=M.empty();imported.preferences.restaurant.name='مستوردة';imported.version=9;const file=path.join(h.temp,'chosen.json');fs.writeFileSync(file,JSON.stringify(imported));
 h.queue.push({filePaths:[file],canceled:false},{response:0});assert.equal((await h.call('import')).canceled,true);assert.equal((await h.call('load')).data.preferences.restaurant.name,'الحالية');assert.match(h.dialogs[0].detail,/chosen.json/);assert.match(h.dialogs[0].detail,/صيغة الملف 9، بعد الترقية 11/);assert.equal(h.dialogs[0].defaultId,0);
 h.queue.push({filePaths:[file],canceled:false},{response:1});assert.equal((await h.call('import')).data.preferences.restaurant.name,'مستوردة');const recovery=fs.readdirSync(h.directory).find(x=>x.startsWith('accounts-before-import'));assert.deepEqual(JSON.parse(fs.readFileSync(path.join(h.directory,recovery))),h.current);
});
test('native previous backup restores a corrupt account and preserves the unreadable original',async t=>{
 const h=await harness(t,true);assert.equal((await h.call('load')).ok,false);h.queue.push({response:1});const result=await h.call('restore');assert.equal(result.ok,true);assert.equal(result.data.preferences.restaurant.name,'السابقة');assert.equal(result.backupInfo.previousAvailable,true);assert.equal((await h.call('load')).ok,true);const recovery=fs.readdirSync(h.directory).find(x=>x.startsWith('accounts-before-import'));assert.equal(fs.readFileSync(path.join(h.directory,recovery),'utf8'),'corrupt');
});
test('native export records health and permits opening only files exported this session',async t=>{
 const h=await harness(t),file=path.join(h.temp,'export.json');h.queue.push({filePath:file,canceled:false});const result=await h.call('export');assert.equal(result.ok,true);assert.ok(result.backupInfo.lastExport);assert.equal((await h.call('open-export',{filePath:file})).ok,true);assert.deepEqual(h.opened,[file]);assert.equal((await h.call('open-export',{filePath:path.join(h.directory,'accounts.json')})).ok,false);
});
