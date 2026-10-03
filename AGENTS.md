# AGENTS.md

Native Swift/AppKit macOS menu bar app for SSH port forwards. No external dependencies, no SPM — everything runs through the Xcode project in `SSHTunnelManager/`.

## Build & Test

```bash
cd SSHTunnelManager
xcodebuild -scheme SSHTunnelManager -configuration Release        # build
xcodebuild -scheme SSHTunnelManager test                          # all XCTest
xcodebuild -scheme SSHTunnelManager test \
  -only-testing:SSHTunnelManagerTests/PortAllocatorTests          # one class
```

- Requires Xcode 15+ / macOS 14+ (CI pins `Xcode_15.2.app` on `macos-14`).
- Tests live in `SSHTunnelManager/Tests/SSHTunnelManagerTests.swift`. They install an ephemeral `UserDefaults` suite (`TestPreferences.install()`) so they never touch real prefs — new tests must do the same via `setUp`/`tearDown`.
- CI (`.github/workflows/release.yml`) only builds/releases on `v*` tags; it does **not** run tests. Run `xcodebuild test` locally before claiming done.
- No linter/formatter config exists; match the existing Swift style.

## Release flow

- Pushing a tag `v*` triggers: build → ad-hoc codesign → DMG via `dmgbuild` 1.6.7 with `packaging/dmg_settings.py` + `packaging/dmg-background.tiff` → GitHub Release.
- Tags containing `-` (e.g. `v1.9.1-rc1`) publish as **pre-releases**; the Homebrew tap only follows `releases/latest`, so rc tags never reach brew users.

## Specs are the contract (docs-first)

- `docs/control-socket.md` — spec for the Unix-socket IPC/JSONL protocol (`$HOME/Library/Application Support/SSHTunnelManager/tunnel-manager.sock`, 64 KiB frame cap).
- `docs/schemas/control-v1.jtd.json` — RFC 8927 JTD schema for that protocol. Keep it in sync with `Services/IPC/ControlProtocol.swift` when changing frames.
- `docs/preferences-and-port-frontier.md` — persistence keys (`UserDefaults.standard`) and the port-frontier allocation algorithm implemented in `Services/PortAllocator.swift`.
- Change the doc **before** the code when altering specified behaviour.

## Architecture map

- Entry: `SSHTunnelManagerApp.swift` → `Services/TunnelManager.swift` (spawns the system `ssh`, no bundled binaries; parsing ssh stderr for failure reasons).
- `Models/` — `Tunnel.swift`, `AppPreferences.swift` (UserDefaults keys), `PreferencesDraft.swift`.
- `Services/ConfigStore.swift` persists tunnels to `~/Library/Application Support/SSHTunnelManager/tunnels.json`.
- `Services/IPC/` — control socket server: `ControlSocketServer`, `ControlProtocol`, `LineFramer`.
- `Views/` — `MenuBar/` (popover), `MainWindow/` (settings + detail), `Preferences/`.

## GUX UI contracts

`gux/*.gux` + `gux/*.md` are machine-checkable visual contracts for the three screens, verified against screenshots by [gux-tool](https://github.com/simbo1905/gux-tool). They are never compiled. If you change a screen's layout/colours, update the matching `.gux` contract and re-verify against a fresh screenshot.

## Conventions

- `README.md` is the source of truth; `README.zh-CN.md` is a translation that may lag. User-facing strings are localized via `Localizable.xcstrings` (including service-layer strings).
- Repo-local scratch space is `.tmp/` (gitignored, may be wiped); don't write temp files elsewhere.
