# Connection Control Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire ConnectBtn, Connected, PollBtn, and PollRate controls into live connection and polling logic via NovaStar.connect()/disconnect() helpers.

**Architecture:** Add `NovaStar.connect()` and `NovaStar.disconnect()` helpers to centralise what is currently duplicated inline across Model/IPAddress event handlers, error recovery, and startup. All connection triggers delegate to these helpers. ConnectBtn gates all reconnect attempts. Connected LED tracks socket state. PollBtn and PollRate drive TU polling lifecycle.

**Tech Stack:** Lua 5.3, Q-SYS plugin runtime (TcpSocket, Timer, Controls), no test framework — verification steps describe expected Q-SYS Designer behaviour.

---

### Task 1: Fix PollRate minimum (controls.lua)

**Files:**
- Modify: `controls.lua:57`

- [ ] **Step 1: Change Min=1 to Min=0**

In `controls.lua` line 57, change:
```lua
table.insert(controls, {Name="PollRate", ControlType="Knob", ControlUnit="Seconds", Min=1, Max=300, MajorDivisions=10, Count=1, DefaultValue=30, UserPin=false, PinStyle="None"})
```
to:
```lua
table.insert(controls, {Name="PollRate", ControlType="Knob", ControlUnit="Seconds", Min=0, Max=300, MajorDivisions=10, Count=1, DefaultValue=30, UserPin=false, PinStyle="None"})
```

- [ ] **Step 2: Commit**

```bash
git add controls.lua
git commit -m "feat: allow PollRate=0 to disable polling"
```

---

### Task 2: Add NovaStar.connect() and NovaStar.disconnect()

**Files:**
- Modify: `runtime.lua:124` (insert after)

- [ ] **Step 1: Add helpers after the socket timeout block**

After `runtime.lua` line 124 (`NovaStar.socket.ReconnectTimeout = 0`), insert:

```lua
	NovaStar.connect = function()
		local ip = Controls["IPAddress"].String
		if ip == "" then
			NovaStar.setStatus(3, "Please set IP address")
			return
		end
		local port = (Controls["Model"].String == "TU") and 5201 or 5200
		NovaStar.setStatus(5, "Connecting to NovaStar")
		NovaStar.socket:Connect(ip, port)
	end

	NovaStar.disconnect = function()
		NovaStar.socket:Disconnect()
		Controls["Connected"].Boolean = false
		NovaStar.setStatus(2, "Disconnected")
	end
```

- [ ] **Step 2: Commit**

```bash
git add runtime.lua
git commit -m "feat: add NovaStar.connect() and NovaStar.disconnect() helpers"
```

---

### Task 3: Drive Connected LED from socket events

**Files:**
- Modify: `runtime.lua:392-403` (socket.Connected)
- Modify: `runtime.lua:459-463` (socket.Closed)

- [ ] **Step 1: Set Connected=true in socket.Connected**

In `runtime.lua`, replace the `socket.Connected` handler (lines 392–403):

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

- [ ] **Step 2: Set Connected=false in socket.Closed**

Replace the `socket.Closed` handler (lines 459–463):

```lua
	NovaStar.socket.Closed = function()
		if DebugFunction then print("Closed() called") end
		pollToken = pollToken + 1
		Controls["Connected"].Boolean = false
		NovaStar.setStatus(2, "Connection closed")
	end
```

- [ ] **Step 3: Commit**

```bash
git add runtime.lua
git commit -m "feat: drive Connected LED from socket.Connected and socket.Closed"
```

---

### Task 4: Gate Error/Timeout reconnect on ConnectBtn; set Connected=false

**Files:**
- Modify: `runtime.lua:465-472` (socket.Error)
- Modify: `runtime.lua:474-480` (socket.Timeout)

- [ ] **Step 1: Update socket.Error**

Replace the `socket.Error` handler (lines 465–472):

```lua
	NovaStar.socket.Error = function(_, err)
		if DebugFunction then print("Error() called: " .. tostring(err)) end
		print("TCP Socket Error: ")
		print(err)
		pollToken = pollToken + 1
		Controls["Connected"].Boolean = false
		NovaStar.setStatus(2, "Communication error with NovaStar")
		if Controls["ConnectBtn"].Boolean then
			NovaStar.connect()
		end
	end
```

- [ ] **Step 2: Update socket.Timeout**

Replace the `socket.Timeout` handler (lines 474–480):

```lua
	NovaStar.socket.Timeout = function(_)
		if DebugFunction then print("Timeout() called") end
		print("TCP Socket Timeout")
		pollToken = pollToken + 1
		Controls["Connected"].Boolean = false
		NovaStar.setStatus(2, "Timeout in connection to NovaStar")
		if Controls["ConnectBtn"].Boolean then
			NovaStar.connect()
		end
	end
```

- [ ] **Step 3: Commit**

```bash
git add runtime.lua
git commit -m "feat: gate Error/Timeout reconnect on ConnectBtn; set Connected=false"
```

---

### Task 5: Update Model.EventHandler to use NovaStar.connect()

**Files:**
- Modify: `runtime.lua:482-494`

- [ ] **Step 1: Replace inline connect block**

Replace the `Model.EventHandler` (lines 482–494):

```lua
	Controls["Model"].EventHandler = function()
		local model = Controls["Model"].String
		if DebugFunction then print("Model changed to: " .. tostring(model)) end
		applyModelLayout(model)
		pollToken = pollToken + 1
		NovaStar.socket:Disconnect()
		if Controls["ConnectBtn"].Boolean then
			NovaStar.connect()
		end
		rewireVXButtons(model)
	end
```

- [ ] **Step 2: Commit**

```bash
git add runtime.lua
git commit -m "refactor: Model.EventHandler uses NovaStar.connect()"
```

---

### Task 6: Update IPAddress.EventHandler to use NovaStar.connect()

**Files:**
- Modify: `runtime.lua:496-504`

- [ ] **Step 1: Replace inline connect block**

Replace the `IPAddress.EventHandler` (lines 496–504):

```lua
	Controls["IPAddress"].EventHandler = function()
		local ip = Controls["IPAddress"].String
		if DebugFunction then print("IPAddress changed to: " .. tostring(ip)) end
		NovaStar.socket:Disconnect()
		if Controls["ConnectBtn"].Boolean then
			NovaStar.connect()
		end
	end
```

- [ ] **Step 2: Commit**

```bash
git add runtime.lua
git commit -m "refactor: IPAddress.EventHandler uses NovaStar.connect()"
```

---

### Task 7: Add ConnectBtn.EventHandler and update startup block

**Files:**
- Modify: `runtime.lua` (add handler after IPAddress.EventHandler ~line 504)
- Modify: `runtime.lua:545-552` (startup block)

- [ ] **Step 1: Add ConnectBtn.EventHandler**

After the `IPAddress.EventHandler` block (after line 504), insert:

```lua
	Controls["ConnectBtn"].EventHandler = function(ctl)
		if ctl.Boolean then
			NovaStar.connect()
		else
			NovaStar.disconnect()
		end
	end
```

- [ ] **Step 2: Replace startup connect block**

Replace the startup block (lines 545–552):

```lua
	-- Connect on load if ConnectBtn is already set
	if Controls["ConnectBtn"].Boolean then
		NovaStar.connect()
	else
		NovaStar.setStatus(3, "Not connected")
	end
```

- [ ] **Step 3: Verify in Q-SYS Designer**

Reload the plugin in Q-SYS Designer emulation:
- Set IP, enable ConnectBtn → Status shows "Connecting to NovaStar", Connected LED turns on when socket connects.
- Disable ConnectBtn → Status shows "Disconnected", Connected LED turns off.
- With ConnectBtn on, change IP or Model → plugin disconnects and reconnects.
- With ConnectBtn off, change IP or Model → plugin stays disconnected.
- Save design with ConnectBtn=true, reload → plugin auto-connects on load.

- [ ] **Step 4: Commit**

```bash
git add runtime.lua
git commit -m "feat: wire ConnectBtn and gate startup connect on ConnectBtn state"
```

---

### Task 8: Guard startTUPolling against PollRate=0

**Files:**
- Modify: `runtime.lua:339-348`

- [ ] **Step 1: Add PollRate==0 guard**

Replace the `startTUPolling` function (lines 339–348):

```lua
	local function startTUPolling(token)
		if Controls.PollRate.Value == 0 then return end
		Timer.CallAfter(function()
			if token ~= pollToken then return end
			if Controls["PollRate"].Value == 0 then return end
			if Controls["Model"].String == "TU" and NovaStar.socket.IsConnected then
				pendingRead = "CurrentSource"
				sendPacket(TuRead.CurrentSource)
				startTUPolling(token)
			end
		end, Controls.PollRate.Value)
	end
```

The outer guard prevents scheduling when PollRate=0. The inner guard stops the cycle from rescheduling if PollRate was set to 0 while a timer was already queued.

- [ ] **Step 2: Commit**

```bash
git add runtime.lua
git commit -m "feat: stop TU polling when PollRate=0"
```

---

### Task 9: Add PollRate.EventHandler

**Files:**
- Modify: `runtime.lua` (add after ConnectBtn.EventHandler ~line 513)

- [ ] **Step 1: Add handler**

After the `ConnectBtn.EventHandler` block, insert:

```lua
	Controls["PollRate"].EventHandler = function()
		pollToken = pollToken + 1
		if Controls["PollRate"].Value > 0
				and Controls["Model"].String == "TU"
				and NovaStar.socket.IsConnected then
			startTUPolling(pollToken)
		end
	end
```

- [ ] **Step 2: Verify in Q-SYS Designer (TU model, connected)**

- Set PollRate to a value >0 → polling restarts immediately at the new interval.
- Set PollRate to 0 → polling stops (CURRENT_SOURCE and SYSTEM_STATUS stop updating).
- Set PollRate back to >0 → polling resumes.

- [ ] **Step 3: Commit**

```bash
git add runtime.lua
git commit -m "feat: PollRate.EventHandler restarts or stops TU polling"
```

---

### Task 10: Add PollBtn.EventHandler

**Files:**
- Modify: `runtime.lua` (add after PollRate.EventHandler)

- [ ] **Step 1: Add handler**

After the `PollRate.EventHandler` block, insert:

```lua
	Controls["PollBtn"].EventHandler = function(ctl)
		if not ctl.Boolean then return end
		if Controls["Model"].String ~= "TU" then return end
		if not NovaStar.socket.IsConnected then return end
		pendingRead = "CurrentSource"
		sendPacket(TuRead.CurrentSource)
	end
```

- [ ] **Step 2: Verify in Q-SYS Designer (TU model, connected)**

- Press PollBtn → CURRENT_SOURCE and SYSTEM_STATUS update immediately.
- Press PollBtn with non-TU model or while disconnected → nothing happens, no error.

- [ ] **Step 3: Commit**

```bash
git add runtime.lua
git commit -m "feat: PollBtn triggers immediate TU poll"
```
