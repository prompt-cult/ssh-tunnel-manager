# Screen: Settings Window — Tunnel Editor (light theme)

Source: screenshot of the main settings window of
`0fuz/ssh-tunnel-manager` v1.10.0. Approximate capture size 1280 × 975.

## Description

A single light-mode macOS window (~1120 × 830 inside the capture) with the
standard traffic lights (red/yellow/green) in the top-left.

### Left sidebar (grey, ~280px)

- Toolbar row under the traffic lights: a sidebar-toggle icon, a
  dashed-selection (Presentation Mode) icon, and a `+` button.
- Tunnel list; each entry is two lines:
  - `vps0` / `:8080 → 8080`
  - `vps2` / `:8080 → 8080`
  - `New Tunnel` / `:8080 → 8080` — currently selected, shown with a blue
    highlight (#2563eb) and white text; a white status dot sits left of the
    name. Unselected entries show a dark grey dot and black text.
- Bottom toolbar above the footer: move-up arrow, move-down arrow, duplicate
  icon (left group) and a trash/delete icon (right group).
- Footer: gear icon + `Preferences` on the left, `v1.10.0` on the right.

### Right detail pane (white, header bar light grey)

- Header bar: title `SSH Tunnel Manager` (left, bold ~17px); `Save` button
  (right, light grey rounded rect, grey text — disabled/needs-change state).
- **Status** section (bold heading): a card containing a status row — grey
  dot + `Disconnected` label (left) and a green `Connect` button (right,
  #34c759-ish rounded rect, white text).
  Below it, a monospace `SSH` preview card: the label `SSH` rotated/placed
  left of a copy-icon on the right, and the generated command in ~13px
  monospace:

  `ssh -N -L 127.0.0.1:8080:127.0.0.1:8080 -L 127.0.0.1:8081:127.0.0.1:8081 -o RequestTTY=no -o RemoteCommand=none -o ControlMaster=no -o ControlPath=none -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ConnectionAttempts=2 -o BatchMode=yes user@example.com`

- **General** section: a form group with one row — `Name` label (left) and
  text field (right) containing `New Tunnel`, right-aligned text.
- **SSH Connection** section: a form group with rows:
  - `Mode` — segmented control with segments `Host` (selected, white raised)
    and `SSH Alias` (grey).
  - `Host` — text field `user@example.com` plus a narrow port field `22`,
    separated by a colon label.
  - `Identity File (optional)` — empty text field.

  The window continues below the capture edge (more fields exist: forwards,
  etc. — not visible here).

## Behaviour notes

- Selecting a tunnel in the sidebar loads its editor in the detail pane.
- `Save` persists edits; it appears inert until a change is made.
- `Connect`/`Disconnect` toggles the tunnel from this pane; the status dot
  and label update accordingly.
- `+` adds a tunnel (defaults to `New Tunnel`); trash deletes the selected
  one; arrows reorder; duplicate copies.
