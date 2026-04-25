# Roadmap — RaceCor Pro Drive macOS

## v1.0 (Current)

- [x] Authentication (OAuth + PKCE)
- [x] Dashboard with recent sessions
- [x] Sessions list & detail view
- [x] Settings & sign out
- [x] Design system baseline

## v1.1 (Next)

- [ ] **Richer Dashboard**: Aggregate stats from `/api/v1/dashboard` (career stats, streaks, recent milestones)
- [ ] **Moments**: Session replay clips with AI detection (requires backend segment API)
- [ ] **DNA**: Driving style analysis, weakness identification, behavioral patterns
- [ ] **When**: Historical trends, performance by time-of-day, seasonal analysis
- [ ] **Safety & Composure**: Safety rating trends, incident analysis, mental performance metrics
- [ ] **Debrief**: AI-powered post-race analysis, voice memo integration
- [ ] **Tracks**: Track library with PBs, heat maps, sector analysis
- [ ] **Cars**: Car-by-car statistics, comparison tools

## v1.2 (Experience)

- [ ] **MenuBarExtra**: Live race data in menu bar (if actively racing)
- [ ] **Widgets**: macOS Sonoma lock screen widgets, dashboard widgets
- [ ] **Spotlight Integration**: Search sessions by track/car/date
- [ ] **Keyboard Shortcuts**: Global hotkeys (Cmd+K for command palette, Cmd+Shift+R for recent race)
- [ ] **Share Extensions**: Export session data as PDF, share to Discord/Twitter

## v1.3 (Continuity)

- [ ] **Handoff to iOS**: Seamless app switch if iOS app exists
- [ ] **iCloud Sync**: Sync favorites, custom filters across devices
- [ ] **AirDrop Sessions**: Share replays with other iRacers

## Blocking Decisions

1. **Backend dashboard aggregate**: `/api/v1/dashboard` currently returns stub data. Need real aggregates: best lap time ever, podium count, incident trends, etc.
2. **Design token publishing**: Style Dictionary pipeline lives in closed repo. Need to publish `@racecor/tokens` npm package so overlay + native app both pull from same source.
3. **Moments segment API**: Requires new backend endpoint for video segment detection. Scope TBD.
4. **iOS app**: May want to scaffold iOS app (SwiftUI + same API client) in parallel to share code.

## Notes

- All screens under Destinations (except Dashboard, Races, Settings) are currently PlaceholderViews
- Pull-to-refresh works on all screens via `.refreshable {}`
- TokenLoader on startup will eventually load Style Dictionary tokens from `/api/v1/tokens/native?format=swift`
