const { contextBridge, ipcRenderer, shell } = require('electron');

contextBridge.exposeInMainWorld('racecor', {
  // App version and platform info
  version: null,
  platform: process.platform,

  // Helper to open URLs in system browser
  openExternal: (url) => {
    shell.openExternal(url);
  },

  // Listen for deeplinks
  onDeeplink: (callback) => {
    ipcRenderer.on('deeplink', (event, url) => callback(url));
  },
});

// Fetch and expose app info
ipcRenderer.invoke('get-app-info').then((info) => {
  window.racecor.version = info.version;
});
