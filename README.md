# RaceCor Pro Drive — macOS

Two macOS apps for [RaceCor Pro Drive](https://prodrive.racecor.io). One repo, two `apps/*` entries.

| App | Path | Stack |
|---|---|---|
| Shell | `apps/shell/` | Electron — wraps `prodrive.racecor.io` in a signed `.app` with its own dock icon. Fastest path to distribution, least feature drift. Auth is the standard web Discord flow running inside a `BrowserWindow`. |
| Native | `apps/native/` | SwiftUI + AppKit, macOS 14+. Fully native chrome, Keychain tokens, PKCE Discord via `ASWebAuthenticationSession`. Better experience long-term; takes longer to reach feature parity. |

Each app has its own `README.md`, `CLAUDE.md`, and `next-steps.md` inside its directory.

## Why both?

They're built in parallel. The shell ships sooner — zero feature drift from the web app. The native app earns its keep over time through widgets, menu-bar presence, Continuity, and keyboard-driven workflows. You don't have to choose between them; the shell is the bridge until the native is ready, and the fallback for anything native hasn't ported yet.

## Repo layout

```
racecor-prodrive-macos/
├── apps/
│   ├── shell/               Electron mac app
│   └── native/              SwiftUI/AppKit mac app
├── README.md                (this file)
└── CLAUDE.md                architecture notes for future Claude sessions
```

Cross-cutting docs for the whole native-apps program live one directory up:

- `../native-apps-plan.md` — the master plan (7 apps, 3 OS monorepos)
- `../native-apps-api-contract.md` — `/api/v1/*` endpoint catalogue

## Working on one vs both

- Start a given app with `cd apps/<shell|native>` and follow the inner `README.md`.
- Nothing is shared at the package level yet — each app has its own `package.json` / `project.yml`.
- If a common package emerges (e.g. a shared token-loader, or a native-auth Swift package), add `packages/*` at the root and move the shared code there.

## Apple Developer setup

Both apps will eventually need:
- A macOS Developer ID certificate (for the shell — distributed outside the App Store via DMG)
- A Mac App Store Distribution certificate (for the native app — TestFlight + Store)
- Notarization via `xcrun notarytool` (both)

You mentioned you'll handle cert generation. Bundle IDs baked in:
- Shell: `racing.k10motorsports.prodrive.racecor.macshell`
- Native: `racing.k10motorsports.prodrive.racecor.mac`
