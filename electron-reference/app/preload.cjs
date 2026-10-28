const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('daftar', {
  load: () => ipcRenderer.invoke('accounts:load'),
  save: data => ipcRenderer.invoke('accounts:save', data),
  printReport: request => ipcRenderer.invoke('accounts:print', request),
  pdf: request => ipcRenderer.invoke('accounts:pdf', request),
  export: () => ipcRenderer.invoke('accounts:export'),
  import: () => ipcRenderer.invoke('accounts:import'),
  folder: () => ipcRenderer.invoke('accounts:folder'),
  backupInfo: () => ipcRenderer.invoke('accounts:backup-info'),
  restore: () => ipcRenderer.invoke('accounts:restore'),
  openExport: request => ipcRenderer.invoke('accounts:open-export', request),
  onAction: callback => ipcRenderer.on('app:action', (_event, action) => callback(action))
});
