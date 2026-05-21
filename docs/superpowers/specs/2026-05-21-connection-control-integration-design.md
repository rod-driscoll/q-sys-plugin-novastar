# Design: Connection Control Integration

**Date:** 2026-05-21  
**Branch:** feature/tu-series  
**Files affected:** `runtime.lua`, `controls.lua`

---

## Overview

Wire up four controls that are defined but have no event handlers: `ConnectBtn`, `Connected`, `PollBtn`, and `PollRate`. Introduce `NovaStar.connect()` and `NovaStar.disconnect()` helpers to centralise connection logic that is currently duplicated across multiple triggers.

---

## Architecture

### New helpers on `NovaStar` table

**`NovaStar.connect()`**
- Guards against empty `IPAddress` (returns early).
- Derives port from model (`TU` → 5201, otherwise 5200).
- Calls `NovaStar.setStatus(5, "Connecting to NovaStar")`.
- Calls `NovaStar.socket:Connect(ip, port)`.

**`NovaStar.disconnect()`**
- Calls `NovaStar.socket:Disconnect()`.
- Sets `Controls["Connected"].Boolean = false`.
- Calls `NovaStar.setStatus(2, "Disconnected")`.

---

## Control Wiring

### `ConnectBtn` (Toggle)

Event handler:
- `ctl.Boolean == true` → call `NovaStar.connect()`
- `ctl.Boolean == false` → call `NovaStar.disconnect()`

**On load:** replace the current unconditional `socket:Connect(...)` block with `if Controls["ConnectBtn"].Boolean then NovaStar.connect() end`.

### `Connected` (LED Indicator)

- Set `true` inside `socket.Connected` handler.
- Set `false` inside `socket.Closed`, `socket.Error`, and `socket.Timeout` handlers.

### `IPAddress`, `Model`, `Port` change handlers

Replace any inline `socket:Connect(...)` calls with:
```lua
if Controls["ConnectBtn"].Boolean then
    NovaStar.connect()
end
```

### Error / Timeout / Closed reconnect gating

Current code reconnects unconditionally on `Error` and `Timeout`. Change to reconnect only when `Controls["ConnectBtn"].Boolean == true`. `Closed` handler does not reconnect (it already doesn't).

### `PollBtn` (Momentary)

Event handler:
- Returns immediately if `ctl.Boolean == false` (release event).
- Returns if `Model ~= "TU"` or socket not connected.
- Otherwise sets `pendingRead = "CurrentSource"` and sends `TuRead.CurrentSource`.
- Does **not** restart the poll timer — the periodic cycle continues unaffected.

### `PollRate` (Knob, Min → 0)

**`controls.lua`:** Change `Min=1` to `Min=0`.

**Event handler in `runtime.lua`:**
- Increments `pollToken` (cancels any in-flight timer).
- If `PollRate.Value > 0` and model is `TU` and socket is connected: calls `startTUPolling(pollToken)` with the new token value.
- If `PollRate.Value == 0`: does nothing further — polling stops.

**Inside `startTUPolling` timer callback:** add guard at top:
```lua
if Controls["PollRate"].Value == 0 then return end
```
This prevents the cycle from rescheduling when rate is zero.

---

## Error Handling

| Event | `ConnectBtn.Boolean` | Action |
|---|---|---|
| `socket.Error` | true | call `NovaStar.connect()` |
| `socket.Error` | false | update status only |
| `socket.Timeout` | true | call `NovaStar.connect()` |
| `socket.Timeout` | false | update status only |
| `socket.Closed` | either | update status, set `Connected` false, no reconnect |

---

## Out of Scope

- No change to VX connection handshake or TU polling data parsing.
- No new controls added.
- `PollBtn` and `PollRate` are TU-only by convention (guarded in handler); no model enforcement needed in `controls.lua`.
