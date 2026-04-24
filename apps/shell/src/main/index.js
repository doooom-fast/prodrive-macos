const { app, BrowserWindow, shell, ipcMain } = require('electron');
const { autoUpdater } = require('electron-updater');
const path = require('path');
const WindowState = require('./window-state');
const menu = require('./menu');

const RACECOR_URL = process.env.RACECOR_URL || 'https://prodrive.racecor.io';
let mainWindow;

// Handle custom URL scheme (racecor-prodrive://)
if (process.defaultApp) {
  if (process.argv.length >= 2) {
    app.setAsDefaultProtocolClient('racecor-prodrive', process.execPath, [path.resolve(process.argv[1])]);
  }
} else {
  app.setAsDefaultProtocolClient('racecor-prodrive');
}

app.on('open-url', (event, url) => {
  event.preventDefault();
  if (mainWindow) {
    mainWindow.webContents.send('deeplink', url);
  }
});

function createWindow() {
  const windowState = new WindowState({
    defaultWidth: 1400,
    defaultHeight: 900,
  });

  mainWindow = new BrowserWindow({
    x: windowState.x,
    y: windowState.y,
    width: windowState.width,
    height: windowState.height,
    minWidth: 800,
    minHeight: 600,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      webSecurity: true,
      enableRemoteModule: false,
    },
  });

  mainWindow.loadURL(RACECOR_URL);

  // Open DevTools in dev mode
  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools();
  }

  // Handle navigation: keep same-origin in the window, external links in system browser
  mainWindow.webContents.on('will-navigate', (event, url) => {
    const mainUrl = new URL(RACECOR_URL);
    const navUrl = new URL(url);

    if (mainUrl.hostname === navUrl.hostname) {
      // Same origin: allow
      return;
    }

    // Different origin: open externally
    event.preventDefault();
    shell.openExternal(url);
  });

  // Handle window.open() calls: external links in system browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    const mainUrl = new URL(RACECOR_URL);
    const openUrl = new URL(url);

    if (mainUrl.hostname === openUrl.hostname) {
      // Same origin: allow in new window
      return { action: 'allow' };
    }

    // Different origin: open externally
    shell.openExternal(url);
    return { action: 'deny' };
  });

  windowState.track(mainWindow);

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.on('ready', () => {
  createWindow();
  menu.createMenu(mainWindow);

  // Auto-updater skeleton: TODO wire up with a release server
  // autoUpdater.checkForUpdatesAndNotify();
});

app.on('window-all-closed', () => {
  // On macOS, applications stay active until explicitly quit
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  // On macOS, re-creating a window in the app when the dock icon is clicked is common
  if (mainWindow === null) {
    createWindow();
  }
});

// IPC: expose app version and platform to renderer
ipcMain.handle('get-app-info', () => {
  return {
    version: app.getVersion(),
    platform: process.platform,
  };
});

// Set about panel for macOS
app.setAboutPanelOptions({
  applicationName: 'RaceCor Pro Drive',
  applicationVersion: app.getVersion(),
  copyright: 'Copyright (c) 2026 K10 Motorsports',
  website: 'https://prodrive.racecor.io',
});
