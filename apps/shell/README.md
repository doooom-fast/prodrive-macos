# RaceCor Pro Drive — macOS Electron Shell

Native macOS Electron wrapper for [RaceCor Pro Drive](https://prodrive.racecor.io). Loads the web app in a BrowserWindow with native menu bar, dock integration, and OS-level features (keyboard shortcuts, window state persistence, external link handling).

## Getting Started

### Prerequisites

- macOS 11+
- Node.js 16+
- An Apple Developer ID certificate (for signing and notarization)

### Development

```bash
npm install
npm run dev
```

The app loads `https://prodrive.racecor.io` by default. To override:

```bash
RACECOR_URL=http://localhost:3000 npm run dev
```

### Building

Build an unsigned `.dmg` and `.zip` for local testing:

```bash
npm run build:mac
```

Output appears in `dist/`.

## Code Signing and Notarization

To build a signed, notarized app for distribution:

1. **Set environment variables** before building:
   ```bash
   export APPLE_ID=your-apple-id@example.com
   export APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
   export APPLE_TEAM_ID=XXXXXXXXXX
   ```

2. **Build:**
   ```bash
   npm run build:mac
   ```

The signing and notarization steps are configured in `package.json` under the `build.mac` block. electron-builder handles both automatically.

3. **Verify notarization** (optional):
   ```bash
   spctl -a -v -t install /Applications/RaceCor\ Pro\ Drive.app
   ```

## Architecture

- **Main process** (`src/main/index.js`) — window lifecycle, menu bar, IPC
- **Preload script** (`src/main/preload.js`) — context bridge exposing minimal API to the web app
- **Menu builder** (`src/main/menu.js`) — native macOS menu bar
- **Window state** (`src/main/window-state.js`) — persist window bounds across relaunch

The web app (prodrive.racecor.io) handles all auth via Discord OAuth and NextAuth. BrowserWindow has its own cookie jar, so the user logs in once within the app and stays logged in.

External links (e.g., support docs, GitHub issues) open in the system browser to avoid cookie/session confusion.

## Features

- Native macOS menu bar (File, Edit, View, Window, Help)
- Keyboard shortcuts (Cmd+R reload, Cmd+Shift+R force reload, Cmd+Q quit, etc.)
- Window state persistence (bounds saved to `{userData}/window-state.json`)
- Custom URL scheme support (`racecor-prodrive://`) for future deeplinks
- Auto-update skeleton (TODO: configure release server)
- Hardened runtime + code signing ready

## Next Steps

1. **Icon**: Replace `assets/icon.png` (placeholder) with a 1024x1024 production PNG
2. **Auto-update server**: Configure GitHub Releases or another update server; wire up `electron-updater`
3. **File system integration**: If the Edit tool needs to open local MP4 replay files, implement file picker + IPC
4. **Notifications**: When prodrive.racecor.io's web-push system is ready, hook up native notifications
5. **Menu bar mode**: Add a toggle to run the app as a menu bar agent (always-on-top, invisible dock icon)
6. **Ambient light integration**: If the overlay ever runs on the same machine, capture screen color for light mapping

## Testing

Currently no automated tests. To test manually:

- Launch dev mode: `npm run dev`
- Test menu items, keyboard shortcuts, window resizing
- Test external link handling (should open in system browser)
- Test window state persistence: resize/move the window, quit, relaunch, verify bounds are restored

## Troubleshooting

- **Build fails with "unknown error"**: Verify Xcode command-line tools are installed (`xcode-select --install`)
- **Notarization fails**: Check APPLE_ID and APPLE_APP_SPECIFIC_PASSWORD; ensure the certificate is valid
- **Window doesn't load**: Check `RACECOR_URL` env var; verify internet connection
- **Menu bar not responding**: Restart Electron dev server

## License

Copyright (c) 2026 K10 Motorsports. All rights reserved.
