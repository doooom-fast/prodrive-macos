# RaceCor Pro Drive — macOS

Native SwiftUI + AppKit application for RaceCor Pro Drive on macOS 14+.

## Getting Started

Install XcodeGen, generate the Xcode project, and open it:

```bash
brew install xcodegen
xcodegen generate
open RaceCorProDrive.xcodeproj
```

## Building

Build in Xcode:
- Scheme: `RaceCorProDrive-Debug` (development with local logging)
- Scheme: `RaceCorProDrive-Release` (release build)

Or via command line:

```bash
xcodebuild -scheme RaceCorProDrive-Debug -destination 'platform=macOS'
```

## Deployment

1. **Developer ID Certificate**: Register a Developer ID certificate in Apple Developer portal for code signing.
2. **Notarization**: Submit builds to Apple Notary Service:
   ```bash
   xcrun notarytool submit app.zip --apple-id user@example.com --team-id XXXXXXXXXX --password <app-specific-password>
   ```
3. **Distribution**: Submit via App Store Connect or distribute as a notarized DMG.

## Architecture

- **@Observable** pattern for AuthManager state
- **ASWebAuthenticationSession** for OAuth (shares Safari cookies, passes App Review)
- **PKCE** for secure authorization code flow
- **Keychain** for token storage (not UserDefaults)
- **Task-driven** data fetching with SwiftUI `.task {}`
- **NavigationSplitView** for sidebar navigation

## Configuration

Dev override for API endpoint via UserDefaults:

```swift
UserDefaults.standard.set("https://api.example.local", forKey: "racecor.dev.baseURL")
```

## Next Steps

See `next-steps.md` for roadmap (Moments, DNA, MenuBarExtra, widgets, Continuity).
