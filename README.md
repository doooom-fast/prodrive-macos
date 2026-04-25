# RaceCor Pro Drive — macOS

The macOS native app for [RaceCor Pro Drive](https://prodrive.racecor.io). Lives under `apps/native/` so a future second target can sit alongside it without a restructure.

| App | Path | Stack |
|---|---|---|
| Native | `apps/native/` | SwiftUI + AppKit, macOS 14+. Fully native chrome, Keychain tokens, PKCE Discord via `ASWebAuthenticationSession`. |

The app has its own `README.md`, `CLAUDE.md`, and `next-steps.md` inside its directory.

## Repo layout

```
racecor-prodrive-macos/
├── apps/
│   └── native/              SwiftUI/AppKit mac app
├── README.md                (this file)
└── CLAUDE.md                architecture notes for future Claude sessions
```

Cross-cutting docs for the whole native-apps program live one directory up:

- `../native-apps-plan.md` — the master plan
- `../native-apps-api-contract.md` — `/api/v1/*` endpoint catalogue

## Working on the app

- `cd apps/native` and follow the inner `README.md`.
- Nothing is shared at the package level yet. If a shared dependency emerges (e.g. a native-auth Swift package), add `packages/<name>/` at the root and move shared code there.

## Apple Developer setup

- A Mac App Store Distribution certificate (TestFlight + Store)
- Notarization via `xcrun notarytool`

You mentioned you'll handle cert generation. Bundle ID baked in:
- Native: `racing.k10motorsports.prodrive.racecor.mac`
