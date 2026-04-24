const { Menu, app, BrowserWindow } = require('electron');

function createMenu(mainWindow) {
  const template = [
    {
      label: 'RaceCor Pro Drive',
      submenu: [
        {
          label: 'About RaceCor Pro Drive',
          click: () => {
            app.showAboutPanel();
          },
        },
        { type: 'separator' },
        {
          label: 'Preferences...',
          accelerator: 'Cmd+,',
          click: () => {
            if (mainWindow) {
              mainWindow.webContents.send('open-preferences');
            }
          },
        },
        { type: 'separator' },
        {
          label: 'Quit RaceCor Pro Drive',
          accelerator: 'Cmd+Q',
          click: () => {
            app.quit();
          },
        },
      ],
    },
    {
      label: 'File',
      submenu: [
        {
          label: 'New Window',
          accelerator: 'Cmd+N',
          click: () => {
            // Reuse the main window if closed, otherwise just focus
            if (!mainWindow) {
              // This should be handled by app.on('activate')
              return;
            }
            mainWindow.focus();
          },
        },
        {
          label: 'Close',
          accelerator: 'Cmd+W',
          click: () => {
            if (mainWindow) {
              mainWindow.close();
            }
          },
        },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { label: 'Undo', accelerator: 'Cmd+Z', selector: 'undo:' },
        { label: 'Redo', accelerator: 'Shift+Cmd+Z', selector: 'redo:' },
        { type: 'separator' },
        { label: 'Cut', accelerator: 'Cmd+X', selector: 'cut:' },
        { label: 'Copy', accelerator: 'Cmd+C', selector: 'copy:' },
        { label: 'Paste', accelerator: 'Cmd+V', selector: 'paste:' },
        { label: 'Select All', accelerator: 'Cmd+A', selector: 'selectAll:' },
      ],
    },
    {
      label: 'View',
      submenu: [
        {
          label: 'Reload',
          accelerator: 'Cmd+R',
          click: () => {
            if (mainWindow) {
              mainWindow.webContents.reload();
            }
          },
        },
        {
          label: 'Force Reload',
          accelerator: 'Cmd+Shift+R',
          click: () => {
            if (mainWindow) {
              mainWindow.webContents.reloadIgnoringCache();
            }
          },
        },
        { type: 'separator' },
        {
          label: 'Toggle Developer Tools',
          accelerator: 'Cmd+Option+I',
          click: () => {
            if (mainWindow) {
              mainWindow.webContents.toggleDevTools();
            }
          },
        },
        { type: 'separator' },
        {
          label: 'Toggle Fullscreen',
          accelerator: 'Ctrl+Cmd+F',
          click: () => {
            if (mainWindow) {
              mainWindow.setFullScreen(!mainWindow.isFullScreen());
            }
          },
        },
      ],
    },
    {
      label: 'Window',
      submenu: [
        {
          label: 'Minimize',
          accelerator: 'Cmd+M',
          selector: 'performMiniaturize:',
        },
        {
          label: 'Zoom',
          selector: 'performZoom:',
        },
        { type: 'separator' },
        {
          label: 'Bring All to Front',
          selector: 'arrangeInFront:',
        },
      ],
    },
    {
      label: 'Help',
      submenu: [
        {
          label: 'Documentation',
          click: () => {
            require('electron').shell.openExternal('https://prodrive.racecor.io/docs');
          },
        },
        {
          label: 'Report Issue',
          click: () => {
            require('electron').shell.openExternal('https://github.com/alternatekev/racecor-prodrive-mac-shell/issues');
          },
        },
      ],
    },
  ];

  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

module.exports = { createMenu };
