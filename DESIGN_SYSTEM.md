# RaceCor Native Design System

Loadbearing guide for the RaceCor Pro Drive native macOS + iOS SwiftUI apps. Consult this before adding UI; it's the canonical answer to "what should this look like". Everything in here is earned — we iterated extensively on each decision.

## Visual language

Dark-first analytics tool, not a marketing site. Data-dense, utility-first, compact. Reference: the web app's `/drive/dashboard` (the signed-in product) — NOT the marketing pages.

### Palette (`BrandKit.swift::Palette`)

All views reference `Palette.*` — never hardcode hex.

- Backgrounds: `bgBase` `#0a0a14` · `bgSurface` (10,10,32,.9) · `bgPanel` (10,10,20,.95) · `bgElevated` `#14142a`
- Brand: `brand` `#e53935` · `brandMid` `#b02020` · `brandDark` `#700010`
- Text: `textPrimary` `#e8e8f0` · `textSecondary` (white @ 69%) · `textDim` (48%) · `textMuted` (32%)
- Borders: `borderSubtle` (white @ 14%) · `borderAccent` (red @ 35%)
- Semantic: `success` `#34c759` · `warning` `#ff9f0a`

### Typography

System fonts only — `SF Pro` on Apple. Never embed licensed typefaces in native.

- Section labels: 10pt bold, letter-spacing 1.2–2.0 — "SECTION LABEL" uppercase
- Stat numbers: `.rounded` design, `.monospacedDigit()` always — 18–30pt
- Body: 12–14pt regular/medium, `Palette.textSecondary`
- Captions/footnotes: 10–11pt, `Palette.textDim`

### Iconography

SF Symbols only. **Verify symbol names exist** — there is no `dna` or `chat.left.quote`. Common aliases to remember:
- Driver DNA → `atom`
- Debrief → `quote.bubble`
- Dashboard → `square.grid.2x2` (not `gauge.*`, those look overweight on macOS)

## Layout patterns

### App shell (macOS)

- **Custom HStack root**, not `NavigationSplitView`. The system split-view applies an NSVisualEffectView backdrop we can't override — it blocks the themed background photo from showing behind the sidebar. Build your own HStack with a floating-panel sidebar + detail view.
- `.windowStyle(.hiddenTitleBar)` + `.windowToolbarStyle(.unifiedCompact)` — traffic lights float over content.
- `.preferredColorScheme(.dark)` at Window scene level.
- `Window` scene (not `WindowGroup`) — single-instance, URL events deliver via `onOpenURL` to the running instance.

### Floating sidebar

Inset ~38pt top / 10pt left+bottom. `bgBase.opacity(0.55)` fill, 14pt rounded corners, hairline border (`borderSubtle`), soft drop-shadow. Panel hovers over the themed background.

Sidebar content:
1. 28pt clearance for traffic-light cluster
2. Sidebar-style `List` of primary destinations (see Destination enum — **6 items max, matches web top-nav**)
3. Hairline divider
4. Footer: `SidebarMenuRow` × 2 (theme picker + account)

### Detail layout

`VStack(spacing: 0)` with three bands:
1. Header row (44pt fixed): `DashboardTabs` + spacer + toolbar actions (Import / Download as text+icon)
2. Divider (`borderSubtle`)
3. Scrollable content area, 20pt horizontal padding, 14pt top padding
4. Footer: `DataStrip` pinned bottom (56pt)

Detail content is multi-column on wide screens:
- Main column 3fr (tabs, panels, viz cards)
- Divider (1pt `borderSubtle`)
- Right sidebar 320pt fixed width (tracks/cars tabs)

## Component catalog

All in `Sources/DesignSystem/BrandKit.swift` or `Sources/UI/Dashboard/DashboardComponents.swift`.

- **`Logomark(height:tone:)`** — RaceCor mark rendered as pure SwiftUI Paths from SVG coordinates. Do NOT use asset catalogs for logos; the pipeline has silent failure modes.
- **`Sparkline(values:trend:)`** — SwiftUI `Canvas` line chart. Trend drives color: up=success, down=brand, flat=textDim.
- **`.panel()` / `.panelAccent()`** — `ultraThinMaterial` + subtle dark tint + hairline border. The card treatment used everywhere.
- **`BrandGlow(intensity:)`** — red radial gradient for accent lighting behind logomarks. Do not use on login/authenticating — user-visible red is reserved for actual alerts.
- **`ThemedBackgroundView`** — root-of-window backdrop. Fetches livery from `themeSets` via `ThemeStore`, falls back to neutral dark gradient. Full-bleed `.ignoresSafeArea()`.
- **`LicenseBadge(label:tint:)`** — license class pill. `A=#7cdff0` · `B=#6fcf69` · `C=#ffcf4a` · `D=#ff8c42` · `R=brand`.
- **`SidebarMenuRow(title:systemImage:menu:)`** — 1-line dropdown row for sidebar footer. Both theme + account use this — never hand-build new footer rows.
- **`DashboardTabs(selection:)`** / **`SidebarTabs`** — segmented-style tab rows with red underline active state.
- **`SectionHeader(_:)`** — small-caps label with trailing hairline rule.
- **`StatTile` / `IRatingCard` / `MomentRow` / `TrackSidebarCard` / `CarSidebarCard` / `VizPlaceholder`** — dashboard building blocks.
- **`DataStrip(dashboard:safetyRating:)`** — horizontal stat ticker. iRating columns embed `Sparkline` + `LicenseBadge` inline.

## Data model

- `APIClient.shared` (macOS) / `APIClient` actor (iOS) — Bearer-token REST client. Base URL: `https://prodrive.racecor.io`.
- `JSONDecoder.racecor` — custom ISO8601 strategy that accepts fractional seconds (server emits via `JSON.stringify(Date)`). All decoding goes through this.
- `Dashboard` model — decode everything the server emits (iRating, safetyRating, moments, recentMoments, topTracks, topCars, when, pluginConnected). Don't invent fields the server doesn't send. Don't drop fields the server does send.
- Category keys: internal DB uses `road / oval / formula / dirt_road / dirt_oval`. Display via `RaceCategoryLabels.display`: `road → "Sports Car"`, rest capitalized.

## Theming

- `ThemeStore.shared` (ObservableObject) fetches `/api/theme-sets` on app launch.
- Auto-rotation by default (`selectedSlug == "__auto__"`, 5-min interval).
- User can pin a theme via `ThemePicker`.
- Active image URL published via `store.activeImageURL` — resolved from either DB `liveryImage` or `/api/unsplash/background?brand=<slug>&theme=dark`.

## Auth

- Flow: native → `/api/plugin-auth/authorize` (NOT `/native-init`, which was removed). Server's existing web Discord callback handles the OAuth; server issues a plugin code that redirects to `racecor-native://auth?code=…`.
- PKCE verifier mirrored to UserDefaults (cross-process fallback for Launch Services edge cases).
- Custom URL scheme **`racecor-native://`** for native apps; shells use `racecor-prodrive://` — they MUST be distinct to avoid Launch Services collisions.
- Tokens persisted in a JSON file under Application Support (`tokens.json`, 0600 perms). Keychain requires signing entitlements dev builds don't have.

## Do-not-invent list (lessons)

- **No "Good evening, <name>" hero** — the web product has no hero. It has a compact DataStrip.
- **No big iRating cards with sparklines as their main feature** — iRating lives inline in the DataStrip.
- **No marketing-style card-with-icon career stats strip** — those values go into the DataStrip.
- **No orange/tinted List selection pills in the sidebar footer** — the `List` style leaks selection highlights. Use plain `Menu` with custom row.
- **No asset catalog for brand logos** — use SwiftUI Paths. The catalog pipeline has too many silent failure modes (16-bit PNGs, missing root Contents.json, @3x-on-macOS, xcodegen recursion). Valid only for AppIcon (which requires compiled .icns).
- **No `NavigationSplitView` if the theme photo needs to extend behind the sidebar** — its sidebar chrome masks out the image.

## Web-to-native deltas

- Web icon nav at top → Mac sidebar list (Mac idiom) via custom HStack.
- Web `/drive/dashboard` DataStrip at top → macOS DataStrip at **bottom** (read as status-bar-style footer).
- Web 3-tab dashboard switcher → same in native.
- Web right sidebar with Tracks/Cars → same in native, 320pt fixed width.
- Web auto-fetch Unsplash background → native mirrors through same endpoint + same cache semantics.

## Refresh strategy

There's no manual refresh button. Data freshness comes from:
- **Polling**: `DashboardPoller` (see `Sources/Support/DashboardPoller.swift`) hits `/api/v1/dashboard` every 60s while authenticated; diffs against last-seen state to detect new moments/sessions/nextRaceIdeas.
- **Desktop notifications**: new moments, completed races, and imminent race windows fire `UNUserNotificationCenter` notifications via `NotificationCoordinator`.

## Adding a new destination

1. Add case to `Destination` enum in `ContentView.swift` + SF Symbol in `icon`
2. Add a render case in `detailView(for:)` — dashed a placeholder if data model isn't ready yet
3. If the web has a route for it, the label in the sidebar matches the web's top-nav label exactly
4. If the web doesn't have it, you're probably inventing a feature — reconsider
