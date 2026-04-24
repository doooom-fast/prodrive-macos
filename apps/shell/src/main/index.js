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

  // Hosts that must be allowed to navigate within this window instead of
  // being handed off to the system browser. Discord OAuth in particular
  // MUST stay in this window: if the authorize URL opens in Safari, the
  // callback hits Safari's cookie jar, and the PKCE/state cookies that
  // NextAuth set in THIS window's session won't be there — producing the
  // `[auth][error] InvalidCheck` server error page in this window after
  // login. Cloudflare challenge pages can fire during Discord auth too,
  // so allow those as well. This mirrors the iOS shell's allowlist.
  const INTERNAL_NAV_HOSTS = new Set([
    'discord.com',
    'discordapp.com',
    'cdn.discordapp.com',
    'challenges.cloudflare.com',
  ]);
  function isInternalHost(hostname) {
    const main = new URL(RACECOR_URL).hostname;
    if (hostname === main) return true;
    if (INTERNAL_NAV_HOSTS.has(hostname)) return true;
    // Match any subdomain of an allowed host (e.g. foo.discord.com).
    for (const allowed of INTERNAL_NAV_HOSTS) {
      if (hostname.endsWith('.' + allowed)) return true;
    }
    return false;
  }

  // Handle navigation: keep same-origin + allowlisted auth hosts in the
  // window, everything else goes to the system browser.
  mainWindow.webContents.on('will-navigate', (event, url) => {
    const navUrl = new URL(url);
    if (isInternalHost(navUrl.hostname)) return;
    event.preventDefault();
    shell.openExternal(url);
  });

  // Handle window.open() calls: same policy — allowlisted hosts in a
  // child window, everything else externally.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    const openUrl = new URL(url);
    if (isInternalHost(openUrl.hostname)) {
      return { action: 'allow' };
    }
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
