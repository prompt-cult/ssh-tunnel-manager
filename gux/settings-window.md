# Screen: Settings Window — Tunnel Editor (settings_ng)

Source: UI design spec for `0fuz/ssh-tunnel-manager`.
Approximate capture size 1280 × 975.

## Description

A single light-mode macOS window (~1120 × 830 inside the capture) with the
standard traffic lights (red/yellow/green) in the top-left.

### Left sidebar (grey, ~280px)

- Toolbar row under the traffic lights: a sidebar-toggle icon, a
  dashed-selection (Presentation Mode) icon, and a `+` button.
- Tunnel list; each entry is two lines:
  - `vps0` / `:4096 → 4096`
  - `vps2` / `:4097 → 4096`
  - `New Tunnel` / `:4098 → 4096` — currently selected, shown with a blue
    highlight (#2563eb) and white text; a white status dot sits left of the
    name. Unselected entries show a dark grey dot and black text.
- Bottom toolbar above the footer: move-up arrow, move-down arrow, duplicate
  icon (left group) and a trash/delete icon (right group).
- Footer: gear icon + `Preferences` on the left, `v1.10.0` on the right.

### Right detail pane (service-first hierarchy)

- Header bar: title `SSH Tunnel Manager` (left, bold ~17px); `Save` button
  (right, light grey rounded rect, grey text — disabled/needs-change state).
- **Tunnel** section (formerly General):
  - Form group with one row — `Name` label (left) and text field (right)
    containing `New Tunnel`.
- **SSH Connection** section:
  - `Mode` — segmented control with segments `Host` (selected, white raised)
    and `SSH Alias` (grey).
  - `Host` — text field `user@example.com` plus a narrow port field `22`,
    separated by a colon label.
  - `Identity File (optional)` — empty text field.
- **Port Forwarding** section:
  - Mappings list and `Add Port Mapping` button. Local port defaults via
    the port frontier allocator.
- **Status** section:
  - A card containing a status row — grey dot + `Disconnected` label (left)
    and a green `Connect` button (right).
  - Below it, a monospace `SSH` preview card with copy button.

## Behaviour notes

- Selecting a tunnel in the sidebar loads its editor in the detail pane.
- `Save` persists edits; it appears inert until a change is made.
- `Connect`/`Disconnect` toggles the tunnel from this pane; the status dot
  and label update accordingly.
- `+` adds a tunnel (allocating ports starting from the configured high-port frontier).
