'use strict';
const fs = require('node:fs/promises'), path = require('node:path'), { randomUUID } = require('node:crypto');
async function renderPDF(BrowserWindow, report) {
  const window = new BrowserWindow({ show:false, width:794, height:1123, webPreferences:{ contextIsolation:true, nodeIntegration:false, sandbox:true, webSecurity:true } });
  try {
    window.webContents.setWindowOpenHandler(() => ({ action:'deny' }));
    window.webContents.on('will-navigate', event => event.preventDefault());
    await window.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(report.html));
    await window.webContents.executeJavaScript('document.fonts.ready.then(() => true)');
    return await window.webContents.printToPDF({ pageSize:'A4', printBackground:true, preferCSSPageSize:true, displayHeaderFooter:true, generateTaggedPDF:true, generateDocumentOutline:true, headerTemplate:'<span></span>', footerTemplate:'<div style="font:9px system-ui;color:#647568;width:100%;margin:0 15mm;display:flex;justify-content:space-between"><span>DAFTAR / ACCOUNTS</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>' });
  } finally { if (!window.isDestroyed()) window.destroy(); }
}
async function writePDF(file, bytes) {
  const temporary = path.join(path.dirname(file), '.daftar-pdf-' + randomUUID());
  try { await fs.writeFile(temporary, bytes, { mode:0o600, flag:'wx' }); await fs.rename(temporary,file); }
  finally { await fs.rm(temporary,{ force:true }); }
}
module.exports = { renderPDF, writePDF };
