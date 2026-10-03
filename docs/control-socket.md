# Specification: Control Socket Interface (IPC / MCP)

## 1. Overview

`SSHTunnelManager` exposes a Unix Domain Socket (UDS) interface for headless inspection, CLI interaction, and MCP tool integrations without rendering GUI views.

## 2. Transport

- **Socket Family**: POSIX `AF_UNIX` / `SOCK_STREAM`.
- **Filesystem Location**:
  `$HOME/Library/Application Support/SSHTunnelManager/tunnel-manager.sock`
- **File Permissions**: `0600` (read/write by owner only).
- **Framing**: Line-delimited JSON (JSONL). Each request and response payload terminates with `\n` (`0x0A`).
- **Maximum Frame Size**: 65,536 bytes (64 KiB). Connections exceeding this buffer limit without a trailing newline are terminated with an error frame.

## 3. Protocol & Schema (RFC 8927)

Payloads follow the schema specified in `docs/schemas/control-v1.jtd.json`.

### 3.1 Request Frame Format

```json
{"id": "<string>", "method": "<method_name>", "params": { ... }}
```

### 3.2 Response Frame Format

Success:
```json
{"id": "<string>", "result": { ... }}
```

Error:
```json
{"id": "<string>", "error": {"code": -32600, "message": "Detailed description"}}
```

## 4. Standard Methods

### `describe`
Returns server capabilities and protocol version.
- Request: `{"id": "1", "method": "describe"}`
- Response:
  ```json
  {
    "id": "1",
    "result": {
      "version": "1.0.0",
      "methods": ["describe", "get_status", "list_tunnels"],
      "schema": "control-v1.jtd.json"
    }
  }
  ```

### `get_status`
Returns high-level daemon and system metrics.
- Request: `{"id": "2", "method": "get_status"}`
- Response:
  ```json
  {
    "id": "2",
    "result": {
      "version": "1.10.0",
      "totalTunnels": 3,
      "activeTunnels": 1,
      "defaultServicePort": 4096,
      "maxAllocatedPort": 4098,
      "findNextHighPort": true
    }
  }
  ```

### `list_tunnels`
Returns array of all configured tunnels, their port forwards, and connection statuses.
- Request: `{"id": "3", "method": "list_tunnels"}`
- Response:
  ```json
  {
    "id": "3",
    "result": {
      "tunnels": [
        {
          "id": "87642D0E-C182-4DA4-9A47-1B7A0DC9505F",
          "name": "vps0",
          "host": "root@vps0.stenographer.cloud",
          "port": 22,
          "status": "connected",
          "pid": 34821,
          "portMappings": [
            {
              "id": "1E2833FB-2234-4C2E-8E5A-348FA32BB2AA",
              "forward": "local",
              "localHost": "127.0.0.1",
              "localPort": 4096,
              "remoteHost": "127.0.0.1",
              "remotePort": 4096
            }
          ]
        }
      ]
    }
  }
  ```
