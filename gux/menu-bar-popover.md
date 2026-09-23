# Screen: Menu Bar Popover (Tunnel Quick Toggle)

Source: screenshot of the macOS menu bar dropdown of
`0fuz/ssh-tunnel-manager` v1.10.0. Approximate capture size 594 × 345.

## Description

A compact dark-mode NSPopover / menu-style panel anchored below the menu bar
extra icon. It lists all tunnels from the app's store as rows, each with:

- a filled status dot (left, ~8px circle, white/light in dark mode)
- the tunnel name (white, regular weight): `vps0`, `vps2`, `New Tunnel`
- the local port string right-aligned before the switch: `:8080`
- a toggle switch (right edge). The first row (`vps0`) is ON: the switch is
  blue with the knob at the right; the other two are OFF: grey track, knob
  left.

A thin separator divides the tunnel list from two action rows:

- gear icon + `Settings…` with keyboard shortcut `⌘,` right-aligned
- power icon + `Quit` with keyboard shortcut `⌘Q` right-aligned

Row height is generous (~46px), text is macOS system font ~14px, and the
panel has the standard dark translucent menu background with rounded
corners. A sliver of another app window (green) is visible at the right
edge behind the panel — that is not part of the app.

## Behaviour notes

- Clicking a row's switch connects/disconnects that tunnel without opening
  the settings window.
- `Settings…` opens the main settings window (see settings-window.md).
- `Quit` terminates the app.
