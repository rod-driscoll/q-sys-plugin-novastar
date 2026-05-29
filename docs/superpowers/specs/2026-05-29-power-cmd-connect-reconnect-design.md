# Power Command Connect / Reconnect Design

**Date:** 2026-05-29  
**Scope:** `runtime.lua` — power button event handlers, socket callbacks

---

## Problem

When a power button is pressed while the socket is disconnected, the command is silently dropped (`sendPacket` guards on `IsConnected`).

When the socket is connected but the device stops responding (connection appears alive, no data returned), subsequent power commands are lost with no recovery.

---

## Requirements

1. **Disconnected + power command:** attempt to connect; send the queued command once connected. Queue persists across retry attempts until the connection succeeds.
2. **Connected + no response to TU power command:** after a timeout, disconnect then reconnect. The timeout is `Controls["PollRate"].Value` if > 0, otherwise 30 seconds. No command is queued for resend after this reconnect.
3. **Response timeout applies to TU models only** (STANDBY, WAKE, SCREEN_ON, SCREEN_OFF). VX power commands (Normal, Freeze, Black) have no ACK mechanism and are not timed.
4. **No extra reconnect loops:** the queue simply rides the existing `Error`/`Timeout` retry behaviour (`NovaStar.connect()` when `ConnectBtn` is true). No additional retry logic is introduced.

---

## Design

### New state variables

```lua
local pendingPowerCmd = nil   -- packet to send on next successful connect
local powerCmdToken   = 0     -- incremented on any received data; used to cancel response timer
```

### `sendPowerCmd(pkt)` helper

Replaces direct `sendPacket(...)` calls in all power-button event handlers.

```
if not IsConnected:
    pendingPowerCmd = pkt          -- overwrites any previous queued command (only most recent is kept)
    NovaStar.connect()
    return

sendPacket(pkt)

if model == "TU":
    local token = powerCmdToken
    local timeout = (PollRate > 0) and PollRate or 30
    Timer.CallAfter(timeout, function()
        if powerCmdToken ~= token then return end   -- data was received; all good
        -- Device unresponsive: reconnect unconditionally (user pressed a power button, so connectivity is desired)
        -- pendingPowerCmd is NOT set here; the failed command is not re-queued
        NovaStar.disconnect()
        NovaStar.connect()
    end)
```

### `Connected` callback — addition

After the existing connect logic, append:

```lua
if pendingPowerCmd then
    local pkt = pendingPowerCmd
    pendingPowerCmd = nil
    sendPowerCmd(pkt)
end
```

`pendingPowerCmd` is cleared before the call so that `sendPowerCmd` (which is now connected) does not re-queue. `sendPowerCmd` is used rather than `sendPacket` so the TU response timer starts correctly for the deferred send.

### `Data` callback — addition

First line of the data handler body:

```lua
powerCmdToken = powerCmdToken + 1
```

Any received data (ACK, poll response, anything) cancels the in-flight response timer.

### `Error` / `Timeout` callbacks — no change

`pendingPowerCmd` is intentionally left intact. The existing logic retries `NovaStar.connect()` when `ConnectBtn` is true; once the connection succeeds the `Connected` callback will deliver the queued command.

### Event handler wiring changes

| Control | Model | Change |
|---------|-------|--------|
| `Normal` | VX | `sendPacket` → `sendPowerCmd` |
| `Freeze` | VX | `sendPacket` → `sendPowerCmd` |
| `Black` | VX | `sendPacket` → `sendPowerCmd` |
| `STANDBY` | TU | `sendPacket` → `sendPowerCmd` |
| `WAKE` | TU | `sendPacket` → `sendPowerCmd` |
| `SCREEN_ON` | TU | `sendPacket` → `sendPowerCmd` |
| `SCREEN_OFF` | TU | `sendPacket` → `sendPowerCmd` |

All other commands (input select, presets, brightness, volume, mute, test patterns) remain on `sendPacket`.

---

## Files affected

- `runtime.lua` only

---

## Out of scope

- VX response timeouts (no ACK protocol)
- Retry limits / backoff (existing behaviour unchanged)
- Queuing multiple commands (only the most recent power command is retained)
