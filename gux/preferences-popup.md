# Screen: Settings Window with Preferences Popup

Source: screenshot of `0fuz/ssh-tunnel-manager` v1.10.0 with the Preferences
popover open. Approximate capture size 1280 × 921. This is the same settings
window as `settings-window.md` with two differences: (a) the window is
positioned slightly right/centered with a drop shadow on a white canvas, and
(b) a **Preferences** popover is anchored above the `Preferences` footer
button in the sidebar.

## Description

### Preferences popover (bottom-left, ~380 × 210)

- Rounded rect, light grey (#ececed) translucent macOS popover with a small
  down-arrow tail pointing at the `Preferences` footer button.
- Title `Preferences` bold, left-aligned at the top.
- Checkbox rows (blue #2563eb filled checkboxes with white ticks when on):
  1. `Launch at Login` — checked.
  - A horizontal divider line separates this first group from the next.
  2. `Play a sound on connect / disconnect` — checked.
  3. `Show a notification on connect / disconnect` — checked; the label
     wraps onto a second line (`connect / disconnect`).
- Row heights ~44px; system font ~14px; checkboxes ~18px, left-aligned with
  the label right of them.

### Sidebar differences vs settings-window.md

- The list-tools row (arrows/duplicate) is not visible in this capture; the
  trash icon appears alone at the right of the footer area just above the
  `Preferences` footer row.
- Footer reads gear + `Preferences` (left) and `v1.10.0` (right).

### Detail pane

Identical to `settings-window.md`: header with `SSH Tunnel Manager` title
and `Save` button; Status card with `Disconnected` + green `Connect`;
monospace SSH command preview with copy icon; `General` section with `Name`
field (`New Tunnel`); `SSH Connection` section with `Mode` segmented control
(`Host` selected), `Host` field (`user@example.com` : `22`), and `Identity
File (optional)` empty field.

## Behaviour notes

- The popover is toggled by clicking the `Preferences` footer button; it
  closes on outside click.
- The checkbox states persist to app defaults; `Launch at Login` registers
  the app as a login item, sound/notification flags control connect and
  disconnect feedback.
