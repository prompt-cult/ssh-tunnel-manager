# Specifications: Port Frontier & Preferences

## 1. Scope

This document specifies the persistence model, port frontier allocation algorithm, and transient lock-step user interaction model for `SSHTunnelManager`.

## 2. Configuration & Persistence

All app-level preferences persist to `UserDefaults.standard` using the following keys and invariants:

| Key | Type | Default | Domain / Constraints | Description |
|---|---|---|---|---|
| `findNextHighPort` | Boolean | `true` | `{true, false}` | Enables monotonic high-port frontier allocation for local forwards. |
| `defaultServicePort` | Integer | `4096` | `1024 <= n <= 65535` | Default target service/remote port for new tunnel forwards. |
| `maxAllocatedPort` | Integer | `4096` | `1024 <= n <= 65535` | High-water mark (frontier) of allocated local ports. |
| `hasCompletedFirstLaunch` | Boolean | `false` | `{true, false}` | Set to `true` when the first-run preferences setup has been completed or dismissed. |
| `tunnelSoundsEnabled` | Boolean | `true` | `{true, false}` | Audio feedback on tunnel connect/disconnect. |
| `tunnelNotificationsEnabled` | Boolean | `false` | `{true, false}` | Notification feedback on tunnel connect/disconnect. |

## 3. Port Frontier Allocation Algorithm

When a new tunnel or port mapping is added, local port assignment follows the deterministic function:

```text
Input:
  service_port in [1024, 65535]
  find_next_high_port in {true, false}
  frontier in [1024, 65535]
  occupied_local_ports in Set<Integer>

Output:
  allocated_port in [1024, 65535] or nil
  candidate_frontier in [1024, 65535]

Algorithm:
  if find_next_high_port is false:
    return (allocated_port: service_port, candidate_frontier: frontier)

  // Only ports this Mac binds count as occupied. Remote forwards (-R) bind on
  // the server, so their localPort values are excluded from
  // occupied_local_ports (see Tunnel.locallyBoundPorts).

  candidate = max(frontier, max(occupied_local_ports) ?? frontier) + 1
  while candidate <= 65535 and candidate in occupied_local_ports:
    candidate = candidate + 1

  if candidate <= 65535:
    return (allocated_port: candidate, candidate_frontier: candidate)

  // Primary scan exhausted: wrap to the lowest available port at or above
  // 1024. The scan is inclusive, so an occupied frontier is never returned.
  fallback = 1024
  while fallback <= 65535 and fallback in occupied_local_ports:
    fallback = fallback + 1

  if fallback <= 65535:
    return (allocated_port: fallback, candidate_frontier: frontier)
  return nil
```

The frontier in persistent storage (`maxAllocatedPort`) updates **only** when the user saves the tunnel or mapping. Discarded tunnel drafts do not advance the persistent frontier.

On exhaustion (`nil`), callers fall back to `defaultServicePort`; the existing port-conflict guard reports any collision at connect time.

`hasCompletedFirstLaunch` is set to `true` when the first-run Preferences dialog is closed by **any** path — Save or Cancel/dismiss — so the dialog never reopens on every menu-bar interaction.

## 4. Transient Lock-Step UI Dynamics

In the Preferences dialog, `Default Service Port` and `High Port Frontier` are coupled by a link state:

1. **Initialization**: Whenever the Preferences dialog is opened, `isLocked` resets to `true`. This state is transient and never saved to persistent storage.
2. **Synchronized Editing**: While `isLocked == true`, editing either `defaultServicePort` or `maxAllocatedPort` immediately updates the other to match.
3. **Decoupled Editing**: Clicking the link icon toggles `isLocked` to `false`. Both numeric inputs may be modified independently.
4. **Re-linking**: Toggling `isLocked` back to `true` reconciles the values by taking `max(defaultServicePort, maxAllocatedPort)` and setting both fields to this value.
5. **Commit / Discard**:
   - `Save`: Persists valid integer values to `UserDefaults.standard` and closes dialog.
   - `Cancel`: Discards all edits in the draft session and closes dialog.
