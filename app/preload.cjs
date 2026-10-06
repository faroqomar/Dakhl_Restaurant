const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('daftar', {
  load: () => ipcRenderer.invoke('accounts:load'),
  save: data => ipcRenderer.invoke('accounts:save', data),
  pdf: request => ipcRenderer.invoke('accounts:pdf', request),
  export: () => ipcRenderer.invoke('accounts:export'),
  import: () => ipcRenderer.invoke('accounts:import'),
  folder: () => ipcRenderer.invoke('accounts:folder'),
  onAction: callback => ipcRenderer.on('app:action', (_event, action) => callback(action))
});
