# Screen: Settings Window with Preferences Popup

Source: UI design spec for `0fuz/ssh-tunnel-manager`.
Approximate capture size 1280 × 921. This is the main settings window
with the **Preferences** panel opened.

## Description

### Preferences popover / dialog (bottom-left, ~420 × 340)

- Rounded rect, light grey (#ececed) translucent macOS popover with a small
  down-arrow tail pointing at the `Preferences` footer button.
- Title `Preferences` bold, left-aligned at the top.
- Checkbox rows (blue #2563eb filled checkboxes with white ticks when on):
  1. `Launch at Login` — checked.
  - A horizontal divider line separates system integrations from feedback.
  2. `Play a sound on connect / disconnect` — checked.
  3. `Show a notification on connect / disconnect` — checked; the label
     wraps onto a second line (`connect / disconnect`).
  - A horizontal divider separates feedback from port defaults.
- Port allocation controls:
  4. `Find next high port` — checked (default on).
  5. Port inputs row with lock-step link:
     - `Default Service Port` (default: `4096`), right-aligned numeric field (~80px).
     - Lock toggle button with link icon between fields (defaults to locked state).
     - `High Port Frontier` (default: `4096`), right-aligned numeric field (~80px).
- Footer action row:
  - `Cancel` button (bordered standard button, left-aligned).
  - `Save` button (blue #2563eb bordered prominent button, right-aligned).

### Sidebar differences vs settings-window.md

- The list-tools row (arrows/duplicate) is visible above the footer.
- Footer reads gear + `Preferences` (left) and `v1.10.0` (right).

### Detail pane

Service-first layout ("settings_ng"):
- Header with `SSH Tunnel Manager` title and `Save` button.
- `Tunnel` section at the top: `Name` field (`New Tunnel`).
- `SSH Connection` section: `Mode` segmented control (`Host` selected), `Host` field (`user@example.com` : `22`), and `Identity File (optional)`.
- `Port Forwarding` section: port mappings list.
- `Status` card with `Disconnected` + green `Connect` button, and monospace `SSH` command preview card.

## Behaviour notes

- The popover is toggled by clicking `Preferences` in the sidebar footer or selecting `Preferences…` from the menu bar extra.
- First application launch automatically presents Preferences to allow configuring port defaults before tunnel setup.
- Lock toggle synchronizes `Default Service Port` and `High Port Frontier` in lock-step while locked. Opening Preferences always resets the lock to enabled (transient).
- `Save` persists the preferences to defaults; `Cancel` discards all uncommitted changes.
