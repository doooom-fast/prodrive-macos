# Next Steps — RaceCor Pro Drive macOS Shell

## Immediate (Before Distribution)

- [ ] **Sign Developer ID certificate**
  - Obtain Apple Developer ID code signing certificate
  - Add to Keychain
  - Run `npm run build:mac` with `APPLE_TEAM_ID`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD` env vars
  - Verify notarization succeeded (check Apple's notarization email or use `spctl` command)

- [ ] **Replace icon**
  - Design or source a 1024x1024 PNG icon for RaceCor Pro Drive
  - Save as `assets/icon.png`
  - electron-builder will auto-convert to `.icns` for macOS

- [ ] **Test build locally**
  - `npm run build:mac`
  - Verify `.dmg` and `.zip` are generated in `dist/`
  - Mount `.dmg`, install `.app`, launch from Applications
  - Confirm prodrive.racecor.io loads
  - Test keyboard shortcuts (Cmd+R, Cmd+Q)
  - Test external link handling

## Short Term (Next Sprint)

- [ ] **Auto-update server**
  - Decide on update hosting: GitHub Releases (free, simplest) or custom server
  - If GitHub Releases:
    - Tag releases as `v0.1.0`, etc.
    - Upload `.dmg` and `.zip` as release assets
    - electron-updater will auto-fetch from `latest` release
  - If custom:
    - Implement a JSON file (`releases.json`) with `version`, `url`, `sha512` checksums
    - Point `autoUpdater.setFeedURL()` to that endpoint
  - Uncomment `autoUpdater.checkForUpdatesAndNotify()` in `src/main/index.js`

- [ ] **CI/CD pipeline**
  - Set up GitHub Actions workflow for `.github/workflows/macos-shell-ci.yml`
  - Build, sign, notarize, and upload to releases on tag
  - Requires storing Apple credentials securely (GitHub Secrets)

## Medium Term (Future Releases)

- [ ] **File system integration**
  - If the Edit tool needs to open local MP4 replay files:
    - Add file picker dialog in main process (`dialog.showOpenDialog`)
    - Implement IPC message to renderer (e.g., `open-replay-file`)
    - Pass file path or stream to the web app

- [ ] **Native notifications**
  - When prodrive.racecor.io wires up web-push (Service Worker):
    - Request `Notification` permission in preload
    - Implement IPC to show native macOS notification (`new Notification()`)
    - Hook into race start, pit strategy, proximity alerts, etc.

- [ ] **Ambient light screen capture**
  - If overlay integration becomes relevant:
    - Use `desktopCapturer.getSources()` to sample screen color during races
    - Return color to web app for UI feedback or light-mapping integration

- [ ] **Menu bar agent mode**
  - Add Preferences toggle: "Run in menu bar only"
  - Hide dock icon and create NSStatusBar menu item
  - Always-on-top, click-through or focused depending on context
  - Requires `Electron.Menu.buildFromTemplate()` for status bar

## Design & Product Decisions Pending

1. **App Store submission** — macOS App Store vs. direct distribution?
   - App Store requires macOS Catalyst (web view restriction)
   - Direct (dmg/zip) is simpler, no review, more control
   - Current plan: direct distribution only

2. **Windows & Linux variants** — out of scope; other teams
   - Windows: Inno Setup-based installer (see `racecor-plugin/installer/`)
   - Linux: AppImage or Snap (tbd)

3. **iOS & Android wrappers** — separate React Native / Flutter apps
   - Not part of this scaffold

## Reference Checklist

- `npm install` — all dependencies (electron, electron-updater, electron-builder)
- `npm run dev` — launches without errors
- `npm run build:mac` — produces unsigned `.dmg` and `.zip`
- Code signing & notarization — env vars set, cert in Keychain
- Window state persistence — tested by resizing, quitting, relaunching
- External link handling — GitHub link opens in system browser
- Menu bar — all shortcuts responsive (Cmd+R, Cmd+Q, Cmd+Shift+I)
