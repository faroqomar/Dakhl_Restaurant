from pathlib import Path
import subprocess,json
root=Path('/Users/eros/.codex/worktrees/phase01-scope-app/Dakhl_Restaurant')
out=root/'outputs/penpot/phase01/reference-data'
s=(root/'scripts/export-penpot-phase00.cjs').read_text()
s=s.replace("const root=path.resolve(__dirname,'..'),referenceRoot=path.join(root,'electron-reference');",f"const root={json.dumps(str(root))},referenceRoot=path.join(root,'electron-reference');")
s=s.replace("outputs/penpot/phase00/reference-data","outputs/penpot/phase01/reference-data")
s=s.replace("const {app,BrowserWindow,ipcMain,nativeImage}=runtimeRequire('electron');","const {app,BrowserWindow,ipcMain,nativeImage,session}=runtimeRequire('electron');")
s=s.replace("app.whenReady().then(async()=>{","app.whenReady().then(async()=>{\n const blockedRequests=[];session.defaultSession.webRequest.onBeforeRequest((details,callback)=>{const allowed=/^(file:|data:|about:|devtools:)/.test(details.url);if(!allowed)blockedRequests.push({scheme:details.url.split(':')[0],resourceType:details.resourceType});callback({cancel:!allowed});});")
s=s.replace("const run=code=>win.webContents.executeJavaScript(code);","win.webContents.setWindowOpenHandler(()=>({action:'deny'}));win.webContents.on('will-navigate',(event,url)=>{if(!url.startsWith('file:'))event.preventDefault()});win.webContents.on('will-attach-webview',event=>event.preventDefault());\n const run=code=>win.webContents.executeJavaScript(code);")
a=s.index(" for(const [id,view,extra]of[");b=s.index("  if(id==='desktop-settings-data')",a)
s=s[:a]+''' const cases=[
 ['desktop-sales','sales',"draftRestored=true;render()",1440,1000],
 ['desktop-navigation','sales',"draftRestored=false;render();sidebarCollapsed=false;applySidebarState()",1440,1000],
 ['desktop-invoice-new','invoices',"openDrawer('invoice',null)",1440,1000],
 ['phone-sales','sales',"draftRestored=false;render();status('محفوظ على جهازك');toast('تعذر الحفظ. الفاتورة الحالية محفوظة كمسودة.',true)",390,844],
 ['phone-invoice-new','invoices',"document.getElementById('toast').className='';openDrawer('invoice',null)",390,844],
 ['design-system','board','',1440,1200]
 ];
 for(const [id,view,extra,width,height] of cases){
  win.setContentSize(width,height);
  if(id==='design-system')await win.loadFile(path.join(out,'design-system-source.html'));
  else await run(`closeDrawer(true);sidebarCollapsed=true;selectedDate='${date}';view='${view}';render();window.scrollTo(0,0);${extra}`);
''' +s[b:]
s=s.replace("viewport:{width:1440,height:1000}","viewport:{width,height}")
s=s.replace("results},null,2)","results,blockedRequests},null,2)")
# The outer summary has no per-case width/height scope.
s=s.replace("syntheticOnly:true,viewport:{width,height},sourceHashChecks,results", "syntheticOnly:true,viewports:'per-screen',sourceHashChecks,results")
(out/'capture-phase01.cjs').write_text(s)
board=subprocess.check_output(['git','show','ecf692b:docs/planning/flutter-rebuild/design-system.html'],cwd=root,text=True)
board=board.replace('<meta charset="utf-8">','<meta charset="utf-8"><base href="'+(root/'docs/planning/flutter-rebuild').as_uri()+'/">')
(out/'design-system-source.html').write_text(board)
print('derived capture saved; original scripts/source unchanged')
