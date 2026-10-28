// Offline rendering check using illustrative data only; never opens the user's accounts.
const { app, BrowserWindow } = require('electron'), fs = require('node:fs/promises'), path = require('node:path');
const { createReport } = require('../app/reports/pdf.cjs'), { renderPDF,writePDF } = require('../app/reports/export.cjs'), { fixture } = require('../tests/pdf-fixture.cjs');
app.setName('Daftar PDF Check'); app.setPath('userData',path.resolve('dist/pdf-qa/profile'));
app.whenReady().then(async()=>{
  try {
    const dir=path.resolve('dist/pdf-qa'); await fs.mkdir(dir,{recursive:true});
    for (const [name,state,request] of [['day',fixture(),{kind:'daily',date:'2026-10-04'}],['invoice',fixture(),{kind:'invoice',id:'invoice'}],['long-invoice',fixture(true),{kind:'invoice',id:'invoice'}]]) {
      const report=createReport(state,request),bytes=await renderPDF(BrowserWindow,report);await writePDF(path.join(dir,name+'.pdf'),bytes);console.log(name+': '+bytes.length+' bytes');
    }
    app.quit();
  }catch(error){console.error(error);app.exit(1);}
});
app.on('window-all-closed',()=>{});
