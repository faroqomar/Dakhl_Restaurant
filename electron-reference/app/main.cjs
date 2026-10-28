const { app, BrowserWindow, Menu, ipcMain, dialog, shell, screen } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { Storage } = require('./storage.cjs');
const model = require('./ui/model.js');
const { accountSummary } = require('./backup-info.cjs');
const { createReport } = require('./reports/pdf.cjs');
const { renderPDF, writePDF, printReport } = require('./reports/export.cjs');
app.setName('Daftar');
const directory = path.join(app.getPath('appData'), 'Daftar');
app.setPath('userData', directory);
const storage = new Storage(directory);
const page = pathToFileURL(path.join(__dirname, 'ui/index.html')).href;
let win; let data; let loadError;
const exportedFiles = new Set();
function backupInfo() { let info = {}; try { info = JSON.parse(fs.readFileSync(path.join(directory,'backup-meta.json'),'utf8')); } catch {} return { ...info, previousAvailable: fs.existsSync(storage.backup), previousModified: fs.existsSync(storage.backup) ? fs.statSync(storage.backup).mtime.toISOString() : null }; }
if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.show(); win.focus(); } });
  app.whenReady().then(() => {
    try { data = storage.load(); } catch (error) { loadError = error.message; }
    let bounds = {}; try { bounds = JSON.parse(fs.readFileSync(path.join(directory, 'window.json'), 'utf8')); } catch {}
    const area = screen.getPrimaryDisplay().workArea;
    const width = Math.min(Number.isFinite(bounds.width) ? Math.max(900, bounds.width) : 1380, area.width - 32);
    const height = Math.min(Number.isFinite(bounds.height) ? Math.max(580, bounds.height) : 950, area.height - 32);
    const x = Math.max(area.x, Math.min(Number.isFinite(bounds.x) ? bounds.x : area.x + (area.width - width) / 2, area.x + area.width - width));
    const y = Math.max(area.y, Math.min(Number.isFinite(bounds.y) ? bounds.y : area.y + (area.height - height) / 2, area.y + area.height - height));
    win = new BrowserWindow({ width, height, x: Math.round(x), y: Math.round(y), minWidth: 900, minHeight: 580, title: 'دفتر · حسابات المطعم', backgroundColor: '#F6F7F2', show: false, webPreferences: { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, nodeIntegration: false, sandbox: true, webSecurity: true } });
    win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    win.webContents.on('will-navigate', (event, url) => { if (url !== page) event.preventDefault(); });
    win.webContents.session.setPermissionRequestHandler((_wc, _permission, callback) => callback(false));
    win.webContents.session.webRequest.onBeforeRequest({ urls: ['http://*/*', 'https://*/*', 'ws://*/*', 'wss://*/*'] }, (_details, callback) => callback({ cancel: true }));
    const action = name => () => win.webContents.send('app:action', name);
    Menu.setApplicationMenu(Menu.buildFromTemplate([
      { label: 'دفتر', submenu: [{ role: 'about', label: 'حول دفتر' }, { label: 'إعدادات البيانات', accelerator: 'CmdOrCtrl+,', click: action('settings') }, { type: 'separator' }, { role: 'services' }, { role: 'hide' }, { role: 'hideOthers' }, { role: 'unhide' }, { type: 'separator' }, { role: 'quit', label: 'إنهاء دفتر' }] },
      { label: 'ملف', submenu: [{ label: 'إضافة مصروف', accelerator: 'CmdOrCtrl+N', click: action('expense') }, { label: 'تصدير فاتورة اليوم PDF', accelerator: 'CmdOrCtrl+Shift+P', click: action('daily-pdf') }, { label: 'تصدير نسخة احتياطية', accelerator: 'CmdOrCtrl+Shift+E', click: action('export') }, { label: 'استيراد نسخة احتياطية', accelerator: 'CmdOrCtrl+O', click: action('import') }, { type: 'separator' }, { role: 'close' }] },
      { label: 'تحرير', submenu: [{ label: 'تراجع', accelerator: 'CmdOrCtrl+Z', click: action('undo') }, { role: 'redo' }, { type: 'separator' }, { role: 'cut' }, { role: 'copy' }, { role: 'paste' }, { role: 'selectAll' }] },
      { label: 'عرض', submenu: [{ role: 'resetZoom' }, { role: 'zoomIn' }, { role: 'zoomOut' }, { role: 'togglefullscreen' }] },
      { label: 'نافذة', submenu: [{ role: 'minimize' }, { role: 'zoom' }, { role: 'front' }] },
      { label: 'مساعدة', submenu: [{ label: 'حول حفظ الحسابات', click: action('settings') }] }
    ]));
    function handle(channel, fn) {
      ipcMain.handle(channel, async (event, ...args) => {
        if (event.sender !== win.webContents || event.senderFrame?.url !== page) throw new Error('Unauthorized caller');
        try { return { ok: true, ...(await fn(...args)) }; } catch (error) { return { ok: false, error: error.message }; }
      });
    }
    handle('accounts:load', () => { if (loadError) throw new Error(loadError); return { data, directory, backupInfo: backupInfo() }; });
    handle('accounts:save', raw => { data = storage.save(raw); return { data }; });
    handle('accounts:folder', async () => { const error = await shell.openPath(directory); if (error) throw new Error(error); return {}; });
    let exportingPDF = false;
    handle('accounts:pdf', async request => {
      if (loadError) throw new Error(loadError);
      if (exportingPDF) throw new Error('التصدير الحالي بعده قيد التجهيز.');
      exportingPDF = true;
      try {
        // Render only canonical saved accounts; never accept HTML or financial values over IPC.
        const report = createReport(structuredClone(data), request);
        const result = await dialog.showSaveDialog(win, { title: 'تصدير ' + report.title + ' PDF', defaultPath: path.join(app.getPath('documents'), report.filename), filters: [{ name: 'PDF', extensions: ['pdf'] }] });
        if (result.canceled) return { canceled: true };
        const filePath = /\.pdf$/i.test(result.filePath) ? result.filePath : result.filePath + '.pdf';
        const bytes = await renderPDF(BrowserWindow, report);
        await writePDF(filePath, bytes);
        exportedFiles.add(filePath); return { filePath };
      } finally { exportingPDF = false; }
    });
    let printing=false;
    handle('accounts:print', async request => {
      if(loadError)throw new Error(loadError);
      if(printing)throw new Error('نافذة الطباعة مفتوحة حالياً.');
      if(!request||request.kind!=='sale')throw new Error('اختار وصل بيع محفوظاً.');
      printing=true;
      try { return await printReport(BrowserWindow,createReport(structuredClone(data),{kind:'sale',id:request.saleId})); }
      finally { printing=false; }
    });
    handle('accounts:export', async () => {
      if (loadError) throw new Error(loadError);
      const result = await dialog.showSaveDialog(win, { title: 'تصدير نسخة احتياطية', defaultPath: path.join(app.getPath('documents'), `Daftar-${model.dateKey()}.json`), filters: [{ name: 'Daftar backup', extensions: ['json'] }] });
      if (result.canceled) return { canceled: true };
      fs.writeFileSync(result.filePath, JSON.stringify(data, null, 2), { mode: 0o600 }); exportedFiles.add(result.filePath); storage.atomic(path.join(directory,'backup-meta.json'),JSON.stringify({lastExport:new Date().toISOString(),lastExportPath:result.filePath})); return { filePath:result.filePath, backupInfo:backupInfo() };
    });
    handle('accounts:import', async () => {
      const result = await dialog.showOpenDialog(win, { title: 'استيراد حسابات دفتر', properties: ['openFile'], filters: [{ name: 'Daftar backup', extensions: ['json'] }] });
      if (result.canceled) return { canceled: true };
      if (fs.statSync(result.filePaths[0]).size > 20 * 1024 * 1024) throw new Error('الملف أكبر من المسموح.');
      const source = JSON.parse(fs.readFileSync(result.filePaths[0], 'utf8')), imported = model.validate(source);
      const confirmation = await dialog.showMessageBox(win, { type: 'question', title: 'استيراد الحسابات', message: 'استبدال الحسابات الحالية بالنسخة المختارة؟', detail: `الملف المختار: ${result.filePaths[0]}\n\nالنسخة المختارة — صيغة الملف ${source.version}، بعد الترقية ${imported.version}:\n${accountSummary(imported)}\n\nالحسابات الحالية:\n${accountSummary(data)}\n\nقبل الاستبدال تُحفظ نسخة استرجاع باسم accounts-before-import داخل: ${directory}`, buttons: ['إلغاء', 'استيراد'], defaultId: 0, cancelId: 0 });
      if (confirmation.response !== 1) return { canceled: true };
      data = storage.save(imported, true); loadError = null; return { data, directory, backupInfo: backupInfo() };
    });
    handle('accounts:backup-info', () => ({ backupInfo: backupInfo() }));
    handle('accounts:open-export', async request => { if(!request || !exportedFiles.has(request.filePath)) throw new Error('هذا الملف ليس من صادرات هذه الجلسة.'); if(request.reveal) shell.showItemInFolder(request.filePath); else { const error=await shell.openPath(request.filePath); if(error)throw new Error(error); } return {}; });
    handle('accounts:restore', async () => {
      if(!fs.existsSync(storage.backup))throw new Error('ماكو نسخة سابقة متاحة. استورد نسخة احتياطية من ملف.');
      if(fs.statSync(storage.backup).size>20*1024*1024)throw new Error('النسخة أكبر من المسموح.');
      const source=JSON.parse(fs.readFileSync(storage.backup,'utf8')),imported=model.validate(source);
      const confirmation=await dialog.showMessageBox(win,{type:'question',title:'استعادة النسخة السابقة',message:'استبدال الحسابات بالنسخة السابقة؟',detail:`النسخة السابقة: ${storage.backup}\nصيغة الملف ${source.version}، بعد الترقية ${imported.version}\n${accountSummary(imported)}\n\nالحالية:\n${accountSummary(data)}\n\nنحفظ نسخة من الحالية قبل الاستبدال داخل ${directory}`,buttons:['إلغاء','استعادة'],defaultId:0,cancelId:0});
      if(confirmation.response!==1)return {canceled:true}; data=storage.save(imported,true);loadError=null;return {data,directory,backupInfo:backupInfo()};
    });
    win.webContents.on('will-prevent-unload', event => { const choice=dialog.showMessageBoxSync(win,{type:'question',title:'تغييرات غير محفوظة',message:'تغلق دفتر وتترك التغييرات غير المحفوظة؟',detail:'فاتورة البيع الحالية محفوظة كمسودة. التغييرات داخل النماذج والإعدادات تحتاج حفظاً.',buttons:['متابعة التعديل','إغلاق وتجاهل'],defaultId:0,cancelId:0}); if(choice===1)event.preventDefault(); });
    win.once('ready-to-show', () => { win.show(); win.focus(); });
    win.on('close', () => { try { fs.writeFileSync(path.join(directory, 'window.json'), JSON.stringify(win.getNormalBounds()), { mode: 0o600 }); } catch {} });
    win.loadURL(page);
    app.setAboutPanelOptions({ applicationName: 'دفتر · حسابات المطعم', applicationVersion: app.getVersion(), copyright: 'حساباتك محفوظة محلياً على جهازك' });
  });
  app.on('window-all-closed', () => app.quit());
}
