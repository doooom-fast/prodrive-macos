#!/usr/bin/env bash
# One-shot bootstrap for the racecor-prodrive-macos private repo.
#
# Creates the GitHub repo under alternatekev/, makes the initial commit,
# and pushes main. Run from this directory: `bash setup-repo.sh`.
#
# Requires: `gh` CLI (https://cli.github.com) authenticated as alternatekev.
# After running, you can safely delete this script.

set -e

cd "$(dirname "$0")"

REPO_NAME="racecor-prodrive-macos"
REPO_OWNER="alternatekev"
DESCRIPTION="RaceCor Pro Drive — macOS apps (Electron shell + SwiftUI/AppKit native)"

# Sanity
if ! command -v gh >/dev/null; then
  echo "gh CLI not found. Install: https://cli.github.com/"
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh not authenticated. Run: gh auth login"
  exit 1
fi

# Init if not already a repo
if [ ! -d .git ]; then
  git init -b main
fi

git add -A
if git diff --cached --quiet; then
  echo "Nothing to commit."
else
  git commit -m "Initial scaffold: Electron shell + SwiftUI/AppKit native

Two macOS apps for RaceCor Pro Drive:
- apps/shell: Electron wrapper around prodrive.racecor.io with signed
  .app bundle, dock icon, native macOS menu bar
- apps/native: SwiftUI + AppKit, macOS 14+, PKCE Discord auth via
  ASWebAuthenticationSession, NavigationSplitView shell, first-screen
  dashboard hitting /api/v1/dashboard

Scaffolded with full auth flow, API client, design token bridge.
Bundle IDs: racing.k10motorsports.prodrive.racecor.{macshell,mac}

See README.md, CLAUDE.md, and each apps/*/next-steps.md for the
punch list to TestFlight / DMG distribution."
fi

# Create GitHub repo if it doesn't exist
if gh repo view "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1; then
  echo "GitHub repo $REPO_OWNER/$REPO_NAME already exists."
else
  gh repo create "$REPO_OWNER/$REPO_NAME" --private --description "$DESCRIPTION" --source . --remote origin
fi

# Push
git push -u origin main

echo ""
echo "Done. https://github.com/$REPO_OWNER/$REPO_NAME"
echo "You can delete this script now: rm setup-repo.sh"
