const {app,BrowserWindow}=require('electron');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
global.auditRequire=require;
app.setName('Daftar UX verification');app.setPath('userData',fs.mkdtempSync(path.join(os.tmpdir(),'daftar-ux-verify-')));
app.whenReady().then(()=>new BrowserWindow({width:1440,height:1000,show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}}).loadURL('about:blank'));
app.on('window-all-closed',()=>app.quit());
