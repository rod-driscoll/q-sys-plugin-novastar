# Power Command Connect / Reconnect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a power button is pressed while disconnected, connect and send the command once connected; when a TU power command gets no response within a timeout, disconnect and reconnect.

**Architecture:** A single `sendPowerCmd(pkt)` helper wraps all power-button sends. It gates on `IsConnected`: if disconnected it queues the packet and connects; if connected (TU only) it also arms a response-watchdog timer using a token pattern identical to `pollToken`. Any received data cancels the timer by incrementing `powerCmdToken`. Two new local state variables (`pendingPowerCmd`, `powerCmdToken`) are added alongside the existing `pollToken` / `voluntaryDisconnect` block.

**Tech Stack:** Lua 5.3, Q-SYS TcpSocket API, Q-SYS Timer API — all already in use.

---

## File map

| File | Change |
|------|--------|
| `runtime.lua:372-375` | Add two new state variables after existing state block |
| `runtime.lua:375` | Add `sendPowerCmd` function after state block, before `startTUPolling` |
| `runtime.lua:447-459` | Extend `Connected` callback to dispatch `pendingPowerCmd` |
| `runtime.lua:467` | Extend `Data` callback to cancel response timer |
| `runtime.lua:425-439` | Rewire `Normal`/`Freeze`/`Black` in `rewireVXButtons` |
| `runtime.lua:614-617` | Rewire `STANDBY`/`WAKE`/`SCREEN_ON`/`SCREEN_OFF` event handlers |

---

> **Note on testing:** Q-SYS plugins have no unit-test framework. Verification steps below describe observable behaviour in Q-SYS Designer (emulator or live Core). Each task ends with a commit so the change is independently revertable.

---

### Task 1: Add state variables

**Files:**
- Modify: `runtime.lua:372-375`

Current block (lines 372–375):

```lua
	local pendingRead        = nil
	local pendingTuSource    = nil
	local pollToken          = 0
	local voluntaryDisconnect = false
```

- [ ] **Step 1: Add two new variables after the existing block**

Replace the block with:

```lua
	local pendingRead        = nil
	local pendingTuSource    = nil
	local pollToken          = 0
	local voluntaryDisconnect = false
	local pendingPowerCmd    = nil
	local powerCmdToken      = 0
```

- [ ] **Step 2: Verify the plugin still loads**

Open Q-SYS Designer, load the plugin. Status should initialise normally — no Lua errors in the debug console.

- [ ] **Step 3: Commit**

```
git add runtime.lua
git commit -m "feat: add pendingPowerCmd and powerCmdToken state variables"
```

---

### Task 2: Add `sendPowerCmd` helper

**Files:**
- Modify: `runtime.lua` — insert after line 375 (after state variables, before `applyTuSourceFeedback`)

- [ ] **Step 1: Insert `sendPowerCmd` after the state variable block (after line 375)**

Add the following function between the state variables and `applyTuSourceFeedback`:

```lua
	local function sendPowerCmd(pkt)
		if not NovaStar.socket.IsConnected then
			pendingPowerCmd = pkt
			NovaStar.connect()
			return
		end
		sendPacket(pkt)
		if Controls["Model"].String == "TU" then
			local token = powerCmdToken
			local timeout = Controls["PollRate"].Value > 0 and Controls["PollRate"].Value or 30
			Timer.CallAfter(function()
				if powerCmdToken ~= token then return end
				voluntaryDisconnect = true
				NovaStar.socket:Disconnect()
				Controls["Connected"].Boolean = false
				NovaStar.setStatus(2, "No response to power command - reconnecting")
				if Controls["ConnectBtn"].Boolean then
					NovaStar.connect()
				end
			end, timeout)
		end
	end

```

- [ ] **Step 2: Verify the plugin loads**

Reload in Q-SYS Designer. No Lua errors. Existing behaviour (connect, poll, source switch) unchanged.

- [ ] **Step 3: Commit**

```
git add runtime.lua
git commit -m "feat: add sendPowerCmd helper with queue-on-disconnect and TU response watchdog"
```

---

### Task 3: Dispatch pending command in `Connected` callback

**Files:**
- Modify: `runtime.lua:447-459`

Current `Connected` callback (lines 447–459):

```lua
	NovaStar.socket.Connected = function()
		if DebugFunction then print("Connected() called") end
		Controls["Connected"].Boolean = true
		NovaStar.setStatus(0, "Connected - " .. Controls["IPAddress"].String)
		if Controls["Model"].String == "TU" then
			pendingRead = "CurrentSource"
			sendPacket(TuRead.CurrentSource)
			pollToken = pollToken + 1
			startTUPolling(pollToken)
		else
			sendPacket(ConnectPacket)
		end
	end
```

- [ ] **Step 1: Append pending-command dispatch at the end of `Connected`**

Replace with:

```lua
	NovaStar.socket.Connected = function()
		if DebugFunction then print("Connected() called") end
		Controls["Connected"].Boolean = true
		NovaStar.setStatus(0, "Connected - " .. Controls["IPAddress"].String)
		if Controls["Model"].String == "TU" then
			pendingRead = "CurrentSource"
			sendPacket(TuRead.CurrentSource)
			pollToken = pollToken + 1
			startTUPolling(pollToken)
		else
			sendPacket(ConnectPacket)
		end
		if pendingPowerCmd then
			local pkt = pendingPowerCmd
			pendingPowerCmd = nil
			sendPowerCmd(pkt)
		end
	end
```

- [ ] **Step 2: Verify deferred-send path (disconnected → power button → connect)**

In Q-SYS Designer with ConnectBtn off:
1. Press `Normal` (VX model) or `WAKE` (TU model).
2. Observe: plugin attempts to connect (Status shows "Connecting to NovaStar").
3. Once connected: the queued command is sent (for TU, the WAKE ACK feedback appears within the PollRate timeout).

- [ ] **Step 3: Commit**

```
git add runtime.lua
git commit -m "feat: dispatch pendingPowerCmd in Connected callback"
```

---

### Task 4: Cancel response timer on any received data

**Files:**
- Modify: `runtime.lua:467` (`Data` callback)

Current first lines of `Data` (lines 467–470):

```lua
	NovaStar.socket.Data = function()
		local data = NovaStar.socket:Read(NovaStar.socket.BufferLength)
		if DebugRx then print("Rx (" .. #data .. "b): " .. hexDump({data:byte(1, #data)})) end
		NovaStar.setStatus(0, "Connected - " .. Controls["IPAddress"].String)
```

- [ ] **Step 1: Increment `powerCmdToken` as the very first line of the `Data` handler**

Replace with:

```lua
	NovaStar.socket.Data = function()
		powerCmdToken = powerCmdToken + 1
		local data = NovaStar.socket:Read(NovaStar.socket.BufferLength)
		if DebugRx then print("Rx (" .. #data .. "b): " .. hexDump({data:byte(1, #data)})) end
		NovaStar.setStatus(0, "Connected - " .. Controls["IPAddress"].String)
```

- [ ] **Step 2: Verify the watchdog timer is cancelled by normal data**

With TU model, PollRate > 0:
1. Press `WAKE`.
2. Confirm the device does NOT disconnect/reconnect (because the ACK or poll response arrives before the timer fires).

- [ ] **Step 3: Commit**

```
git add runtime.lua
git commit -m "feat: cancel power command response timer on any received data"
```

---

### Task 5: Rewire VX power buttons to use `sendPowerCmd`

**Files:**
- Modify: `runtime.lua:425-439` (inside `rewireVXButtons`)

Current VX display-mode button wiring (lines 422–439):

```lua
		-- Wire display mode buttons
		if Controls["Normal"] then
			Controls["Normal"].EventHandler = function(c)
				if not c.Boolean and DisplayNormal[model] then sendPacket(DisplayNormal[model]) end
			end
		end
		if Controls["Freeze"] then
			Controls["Freeze"].EventHandler = function(c)
				if not c.Boolean and DisplayFreeze[model] then sendPacket(DisplayFreeze[model]) end
			end
		end
		if Controls["Black"] then
			Controls["Black"].EventHandler = function(c)
				if not c.Boolean and DisplayBlack[model] then sendPacket(DisplayBlack[model]) end
			end
		end
```

- [ ] **Step 1: Replace `sendPacket` with `sendPowerCmd` in all three handlers**

```lua
		-- Wire display mode buttons
		if Controls["Normal"] then
			Controls["Normal"].EventHandler = function(c)
				if not c.Boolean and DisplayNormal[model] then sendPowerCmd(DisplayNormal[model]) end
			end
		end
		if Controls["Freeze"] then
			Controls["Freeze"].EventHandler = function(c)
				if not c.Boolean and DisplayFreeze[model] then sendPowerCmd(DisplayFreeze[model]) end
			end
		end
		if Controls["Black"] then
			Controls["Black"].EventHandler = function(c)
				if not c.Boolean and DisplayBlack[model] then sendPowerCmd(DisplayBlack[model]) end
			end
		end
```

- [ ] **Step 2: Verify VX power buttons with disconnected socket**

With a VX model and ConnectBtn off:
1. Press `Black`.
2. Observe: plugin attempts to connect.
3. On success: command is sent.

- [ ] **Step 3: Commit**

```
git add runtime.lua
git commit -m "feat: route VX Normal/Freeze/Black through sendPowerCmd"
```

---

### Task 6: Rewire TU power buttons to use `sendPowerCmd`

**Files:**
- Modify: `runtime.lua:614-617`

Current TU power button handlers (lines 614–617):

```lua
	Controls["STANDBY"].EventHandler       = function(c) if not c.Boolean then sendPacket(TuCmds.Standby) end end
	Controls["WAKE"].EventHandler          = function(c) if not c.Boolean then sendPacket(TuCmds.Wake) end end
	Controls["SCREEN_ON"].EventHandler     = function(c) if not c.Boolean then print('sending screen on') sendPacket(TuCmds.PowerOn) end end
	Controls["SCREEN_OFF"].EventHandler    = function(c) if not c.Boolean then sendPacket(TuCmds.PowerOff) end end
```

- [ ] **Step 1: Replace `sendPacket` with `sendPowerCmd` on all four handlers**

```lua
	Controls["STANDBY"].EventHandler       = function(c) if not c.Boolean then sendPowerCmd(TuCmds.Standby) end end
	Controls["WAKE"].EventHandler          = function(c) if not c.Boolean then sendPowerCmd(TuCmds.Wake) end end
	Controls["SCREEN_ON"].EventHandler     = function(c) if not c.Boolean then print('sending screen on') sendPowerCmd(TuCmds.PowerOn) end end
	Controls["SCREEN_OFF"].EventHandler    = function(c) if not c.Boolean then sendPowerCmd(TuCmds.PowerOff) end end
```

- [ ] **Step 2: Verify TU power buttons end-to-end**

Scenario A — disconnected queue:
1. ConnectBtn off, model = TU.
2. Press `STANDBY` → plugin connects → command sent → `STANDBY` LED goes true within PollRate period.

Scenario B — response watchdog (simulated):
1. ConnectBtn on, model = TU, device connected.
2. Temporarily block the device's response (e.g. firewall rule or emulator).
3. Press `WAKE`.
4. After `PollRate` seconds (or 30s if PollRate = 0): plugin disconnects then reconnects.
5. Remove the block: plugin reconnects successfully.

- [ ] **Step 3: Final commit**

```
git add runtime.lua
git commit -m "feat: route TU STANDBY/WAKE/SCREEN_ON/SCREEN_OFF through sendPowerCmd"
```
