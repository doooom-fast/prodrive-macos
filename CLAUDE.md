# prodrive-macos

Canonical instructions live under [`agents/prodrive-macos/`](agents/prodrive-macos/) — pulled in via the [prodrive-agents](https://github.com/k10-motorsports/prodrive-agents) submodule.

The Swift app lives at the repo root (`Sources/`, `Resources/`, `project.yml`). There is no longer an `apps/` directory — the project was flattened once the Electron shell was removed.

Common entry points:
- Repo overview: [`agents/prodrive-macos/CLAUDE.md`](agents/prodrive-macos/CLAUDE.md)
- Cross-repo context: [`agents/prodrive-context/`](agents/prodrive-context/)
- App architecture: [`agents/prodrive-macos/apps/native/CLAUDE.md`](agents/prodrive-macos/apps/native/CLAUDE.md) — note the path inside the submodule still uses `apps/native/` until the submodule is reorganized to match.

To pull updates:
```bash
git submodule update --init --remote agents
```
