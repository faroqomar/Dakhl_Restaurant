// A separate review app. All accounts and illustrative data stay inside dist/commerce-qa.
const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('node:path'), fs = require('node:fs');
const { Storage } = require('../app/storage.cjs'), M = require('../app/ui/model.js');
const { fixture } = require('../tests/commerce-fixture.cjs');
const { createReport } = require('../app/reports/pdf.cjs'), { renderPDF, writePDF } = require('../app/reports/export.cjs');
const directory = path.resolve(__dirname, '../dist/commerce-qa');
app.setName('Daftar Sales Review');app.setPath('userData',path.join(directory,'profile'));
app.whenReady().then(async()=>{
 const storage = new Storage(path.join(directory,'isolated-accounts'));let state=storage.save(fixture());
 const win = new BrowserWindow({ width:1440,height:1000,show:true,title:'دفتر · معاينة ببيانات توضيحية',webPreferences:{preload:path.resolve(__dirname,'../app/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true} });
 ipcMain.handle('accounts:load',()=>({ok:true,data:state,directory:storage.directory}));
 ipcMain.handle('accounts:save',(_e,data)=>{try{state=storage.save(data);return {ok:true,data:state};}catch(e){return {ok:false,error:e.message};}});
 ipcMain.handle('accounts:pdf',async(_e,request)=>{try{const report=createReport(state,request),bytes=await renderPDF(BrowserWindow,report),filePath=path.join(directory,report.filename);await writePDF(filePath,bytes);return {ok:true,filePath};}catch(e){return {ok:false,error:e.message};}});
 await win.loadFile(path.resolve(__dirname,'../app/ui/index.html'));
});
app.on('window-all-closed',()=>app.quit());
