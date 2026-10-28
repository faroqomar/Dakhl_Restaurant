const {app,BrowserWindow}=require('electron');
global.auditRequire=require;
app.setName('Daftar UX Audit');
app.setPath('userData','/Users/eros/Dev/Eros_Projects/ResturanetAccounting/outputs/ux-audit-2026-10-26/electron-profile');
app.whenReady().then(()=>new BrowserWindow({width:1440,height:1000,show:false,webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true}}).loadURL('about:blank'));
app.on('window-all-closed',()=>app.quit());
