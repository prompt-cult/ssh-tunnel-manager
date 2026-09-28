# Screen: Menu Bar Popover (Tunnel Quick Toggle)

Source: UI design spec for `0fuz/ssh-tunnel-manager`.
Approximate capture size 594 × 390.

## Description

A compact dark-mode NSPopover / menu-style panel anchored below the menu bar
extra icon. It lists all tunnels from the app's store as rows, each with:

- a filled status dot (left, ~8px circle, white/light in dark mode)
- the tunnel name (white, regular weight): `vps0`, `vps2`, `New Tunnel`
- the local port string right-aligned before the switch: `:4096`
- a toggle switch (right edge). The first row (`vps0`) is ON: the switch is
  blue with the knob at the right; the other two are OFF: grey track, knob
  left.

A thin separator divides the tunnel list from three action rows:

- gear icon + `Settings…` with keyboard shortcut `⌘,` right-aligned
- checklist/checkbox icon + `Preferences…`
- power icon + `Quit` with keyboard shortcut `⌘Q` right-aligned

Row height is generous (~46px), text is macOS system font ~14px, and the
panel has the standard dark translucent menu background with rounded
corners.

## Behaviour notes

- Clicking a row's switch connects/disconnects that tunnel without opening
  the settings window.
- `Settings…` opens the main settings window (see settings-window.md).
- `Preferences…` opens the preferences dialog directly.
- `Quit` terminates the app.
