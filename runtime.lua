if (Controls) then
	local DebugTx, DebugRx, DebugFunction = false, false, false
	local DebugPrint = Properties["Debug Print"].Value

	local function SetupDebugPrint()
		if     DebugPrint == "Tx/Rx"          then DebugTx,DebugRx = true,true
		elseif DebugPrint == "Tx"             then DebugTx = true
		elseif DebugPrint == "Rx"             then DebugRx = true
		elseif DebugPrint == "Function Calls" then DebugFunction = true
		elseif DebugPrint == "All"            then DebugTx,DebugRx,DebugFunction = true,true,true
		end
	end

	local VX_SRC, TU_SRC = 0xFE, 0xFC
	local READ, WRITE    = 0x00, 0x01

	local InputLabels = {
		VX4S    = {"DVI","HDMI","VGA1","VGA2","CVBS1","CVBS2","SDI","DP","",""},
		VX4S_N  = {"HDMI","DVI","VGA","","","CVBS","DP","SDI","",""},
		VX6S    = {"HDMI1","HDMI2","SDI1","SDI2","DVI1","DVI2","USB","","",""},
		VX1000  = {"HDMI1","HDMI2","DVI1","DVI2","SDI","OPT1","OPT2","MOSAIC","",""},
		PROHD   = {"SDI","DVI","HDMI","DP","VGA","CVBS","","","",""},
		PROUHDJR= {"DP","HDMI","SDI1","SDI2","","","","","",""},
		MCTRL4K = {"DVI","HDMI","DP","","","","","","",""},
		TU      = {},
	}

	local VX_MODELS = {VX4S=true,VX4S_N=true,VX6S=true,VX1000=true,PROHD=true,PROUHDJR=true,MCTRL4K=true}
	local TU_CONTROLS = {"INPUT_ANDROID","INPUT_HDMI1","INPUT_HDMI2","INPUT_HDMI3",
	                      "SCREEN_ON","SCREEN_OFF","STANDBY","WAKE","VOLUME","MUTE"}
	local VX_CONTROLS = {"IN1","IN2","IN3","IN4","IN5","IN6","IN7","IN8","IN9","IN0",
	                      "TEST_RED","TEST_GREEN","TEST_BLUE","TEST_WHITE","TEST_HORIZ",
	                      "TEST_VERT","TEST_DIAG","TEST_GRAY","TEST_AGING",
	                      "PRESET1","PRESET2","PRESET3","PRESET4","PRESET5",
	                      "PRESET6","PRESET7","PRESET8","PRESET9","PRESET10",
	                      "Normal","Freeze","Black"}

	local function applyModelLayout(model)
		if DebugFunction then print("applyModelLayout() called: " .. tostring(model)) end
		local isTU = (model == "TU")

		-- Show/hide VX controls
		for _, name in ipairs(VX_CONTROLS) do
			if Controls[name] then
				Controls[name].IsInvisible = isTU
				Controls[name].IsDisabled  = isTU
			end
		end

		-- Show/hide TU controls
		for _, name in ipairs(TU_CONTROLS) do
			if Controls[name] then
				Controls[name].IsInvisible = not isTU
				Controls[name].IsDisabled  = not isTU
			end
		end

		-- Update VX input button legends
		if not isTU then
			local labels = InputLabels[model] or {}
			local names  = {"IN1","IN2","IN3","IN4","IN5","IN6","IN7","IN8","IN9","IN0"}
			for i, ctrlName in ipairs(names) do
				local lbl = labels[i]
				if Controls[ctrlName] then
					if lbl and lbl ~= "" then
						Controls[ctrlName].Legend = lbl
						Controls[ctrlName].IsDisabled  = false
						Controls[ctrlName].IsInvisible = false
					else
						Controls[ctrlName].IsDisabled  = true
						Controls[ctrlName].IsInvisible = true
					end
				end
			end
		end

		-- Update Port display
		Controls["Port"].String = isTU and "5201" or "5200"
	end

	local function buildPacket(label, src, dst, devType, port, boardLo, boardHi, code, reg, dataLen, data)
		local bytes = {
			0x00, label, src, dst, devType, port, boardLo, boardHi,
			code, 0x00,
			reg[1], reg[2], reg[3], reg[4],
			dataLen & 0xFF, (dataLen >> 8) & 0xFF
		}
		if data then
			for _, b in ipairs(data) do table.insert(bytes, b) end
		end
		local sum = 0x5555
		for _, b in ipairs(bytes) do sum = sum + b end
		local pkt = {0x55, 0xAA}
		for _, b in ipairs(bytes) do table.insert(pkt, b) end
		table.insert(pkt, sum & 0xFF)
		table.insert(pkt, (sum >> 8) & 0xFF)
		return pkt
	end

	local function hexDump(bytes)
		local s = ""
		for _, b in ipairs(bytes) do s = s .. string.format("%02X ", b) end
		return s
	end

	local NovaStar = {
		socket = TcpSocket.New(),
		setStatus = function (value, msg)
			if DebugFunction then print("setStatus() called: " .. tostring(value) .. " " .. tostring(msg)) end
			-- 0 = OK
			-- 1 = Compromised
			-- 2 = Fault
			-- 3 = Not Present
			-- 4 = Missing
			-- 5 = Initializing
			-- >5 = Fault
			Controls['Status'].Value = value;
			Controls['Status'].String = msg;
		end,
	}
	NovaStar.socket.ReadTimeout = 0
	NovaStar.socket.WriteTimeout = 0
	NovaStar.socket.ReconnectTimeout = 0

	local function sendPacket(pkt)
		if DebugTx then print("Tx: " .. hexDump(pkt)) end
		if NovaStar.socket.IsConnected then
			local s = ""
			for _, b in ipairs(pkt) do s = s .. string.pack("B", b) end
			NovaStar.socket:Write(s)
		end
	end

	local function makeTestPattern(patternId)
		local cmds, labels = {}, {0xe7, 0xe8, 0xe9, 0xea}
		for i, lbl in ipairs(labels) do
			table.insert(cmds, buildPacket(lbl, VX_SRC, 0x00, 0x01, i-1, 0xFF, 0xFF, WRITE,
			                               {0x01, 0x01, 0x00, 0x02}, 1, {patternId}))
		end
		return cmds
	end

	local TestPatterns = {
		RED   = makeTestPattern(0x02), GREEN = makeTestPattern(0x03),
		BLUE  = makeTestPattern(0x04), WHITE = makeTestPattern(0x05),
		HORIZ = makeTestPattern(0x06), VERT  = makeTestPattern(0x07),
		DIAG  = makeTestPattern(0x08), GRAY  = makeTestPattern(0x09),
		AGING = makeTestPattern(0x0A),
	}

	local ConnectPacket = buildPacket(0x00, VX_SRC, 0x00, 0x00, 0x00, 0x00, 0x00, READ,
	                                  {0x02, 0x00, 0x00, 0x00}, 2, nil)

	local function makeBrightnessPacket(value)
		return buildPacket(0x00, VX_SRC, 0xFF, 0x01, 0xFF, 0xFF, 0xFF, WRITE,
		                   {0x01, 0x00, 0x00, 0x02}, 1, {value & 0xFF})
	end

	local DisplayNormal = {
		VX4S    = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x00}),
		VX4S_N  = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x00}),
		VX6S    = buildPacket(0x38,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},1,{0x03}),
		VX1000  = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},2,{0x03,0x00}),
		PROHD   = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x00}),
		PROUHDJR= buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},2,{0x03,0x00}),
		MCTRL4K = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x00}),
	}
	local DisplayFreeze = {
		VX4S    = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x01}),
		VX4S_N  = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x01}),
		VX6S    = buildPacket(0x35,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},1,{0x03}),
		VX1000  = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},2,{0x04,0x00}),
		PROHD   = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x01}),
		PROUHDJR= buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},2,{0x04,0x00}),
		MCTRL4K = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x01}),
	}
	local DisplayBlack = {
		VX4S    = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x02}),
		VX4S_N  = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x02}),
		VX6S    = buildPacket(0x37,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},1,{0x03}),
		VX1000  = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},2,{0x05,0x00}),
		PROHD   = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x02}),
		PROUHDJR= buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x04,0x00,0x00,0x13},2,{0x05,0x00}),
		MCTRL4K = buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x50,0x00,0x20,0x02},1,{0x02}),
	}

	local Inputs = {
		VX4S = {
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x10}), --DVI
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0xA0}), --HDMI
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x01}), --VGA1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x02}), --VGA2
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x71}), --CVBS1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x72}), --CVBS2
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x40}), --SDI
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x90}), --DP
			{},
			{},
		},
		VX4S_N = {
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0xA0}), --HDMI
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x10}), --DVI
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x01}), --VGA
			{},
			{},
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x71}), --CVBS
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x90}), --DP
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x2D,0x00,0x20,0x02},1,{0x40}), --SDI
			{},
			{},
		},
		VX6S = {
			buildPacket(0x88,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x00,0x00,0x11}), --HDMI1
			buildPacket(0xA8,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x01,0x00,0x12}), --HDMI2
			buildPacket(0xC4,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x02,0x00,0x31}), --SDI1
			buildPacket(0xD4,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x03,0x00,0x32}), --SDI2
			buildPacket(0xD6,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x04,0x00,0x01}), --DVI1
			buildPacket(0xD7,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x06,0x00,0x02}), --DVI2
			buildPacket(0xD9,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x07,0x00,0xA0}), --USB
			{},
			{},
			{},
		},
		VX1000 = {
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x00,0x00,0x00}), --HDMI1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x01,0x00,0x00}), --HDMI2
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x02,0x00,0x00}), --DVI1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x03,0x00,0x00}), --DVI2
			-- TODO: verify register values for SDI1/OPT1/OPT2/MOSAIC against VX1000.Control.Protocol.V1.0.pdf
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x03,0x00,0x00}), --SDI1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x03,0x00,0x00}), --OPT1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x03,0x00,0x00}), --OPT1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x03,0x00,0x00}), --MOSAIC
			{},
			{},
		},
		PROHD = {
			buildPacket(0x2B,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x22,0x00,0x20,0x02},1,{0x1A}), --SDI
			buildPacket(0x34,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x22,0x00,0x20,0x02},1,{0x1C}), --DVI
			buildPacket(0x3F,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x22,0x00,0x20,0x02},1,{0x1B}), --HDMI
			buildPacket(0x51,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x22,0x00,0x20,0x02},1,{0x1E}), --DP
			buildPacket(0x48,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x22,0x00,0x20,0x02},1,{0x17}), --VGA
			buildPacket(0x5A,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x22,0x00,0x20,0x02},1,{0x02}), --CVBS
			{},
			{},
			{},
			{},
		},
		PROUHDJR = {
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x00,0x00,0x00}), --DP
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x01,0x00,0x00}), --HDMI2
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x02,0x00,0x00}), --SDI1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x03,0x00,0x00}), --SDI2
			{},
			{},
			{},
			{},
			{},
			{},
		},
		MCTRL4K = {
			buildPacket(0x3E,VX_SRC,0xFF,0x00,0x00,0x00,0x00,WRITE,{0x23,0x00,0x00,0x02},1,{0x61}), --DVI
			buildPacket(0x8A,VX_SRC,0xFF,0x00,0x00,0x00,0x00,WRITE,{0x23,0x00,0x00,0x02},1,{0x05}), --HDMI
			buildPacket(0x9D,VX_SRC,0xFF,0x00,0x00,0x00,0x00,WRITE,{0x23,0x00,0x00,0x02},1,{0x5F}), --DP
			{},
			{},
			{},
			{},
			{},
			{},
			{},
		},
	}

	local function makePresetsVX4S()
		local p = {}
		for i = 0, 4 do
			table.insert(p, buildPacket(0x2e,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x70,0x00,0x20,0x02},1,{i}))
		end
		for i = 5, 9 do
			table.insert(p, buildPacket(0x95,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x70,0x00,0x20,0x02},1,{i}))
		end
		return p
	end
	local function makePresets(reg)
		local p = {}
		for i = 0, 9 do
			table.insert(p, buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,reg,1,{i}))
		end
		return p
	end
	local Presets = {
		VX4S    = makePresetsVX4S(),
		VX6S    = makePresets({0x00,0x01,0x51,0x13}),
		VX1000  = makePresets({0x00,0x01,0x51,0x13}),
		PROUHDJR= makePresets({0x00,0x01,0x51,0x13}),
	}

	local function rewireVXButtons(model)
		-- Wire input buttons for the current VX model
		if VX_MODELS[model] then
			local inputList = Inputs[model] or {}
			for k, v in ipairs(inputList) do
				local ctrlName = (k == 10) and "IN0" or ("IN" .. k)
				if Controls[ctrlName] and v and #v > 0 then
					Controls[ctrlName].EventHandler = function() sendPacket(v) end
				end
			end
		end
		-- Wire preset buttons for the current VX model
		local presetTable = Presets[model]
		if presetTable then
			for k, v in ipairs(presetTable) do
				if Controls["PRESET" .. k] then
					Controls["PRESET" .. k].EventHandler = function() sendPacket(v) end
				end
			end
		end
		-- Wire display mode buttons
		if Controls["Normal"] then
			Controls["Normal"].EventHandler = function()
				if DisplayNormal[model] then sendPacket(DisplayNormal[model]) end
			end
		end
		if Controls["Freeze"] then
			Controls["Freeze"].EventHandler = function()
				if DisplayFreeze[model] then sendPacket(DisplayFreeze[model]) end
			end
		end
		if Controls["Black"] then
			Controls["Black"].EventHandler = function()
				if DisplayBlack[model] then sendPacket(DisplayBlack[model]) end
			end
		end
	end

	local function sendBrightness(value)
		if DebugFunction then print("sendBrightness() called: " .. tostring(value)) end
		sendPacket(makeBrightnessPacket(math.floor(value)))
	end

	NovaStar.socket.Connected = function()
		if DebugFunction then print("Connected() called") end
		print("TCP Connection Established to NovaStar @ " .. Controls["IPAddress"].String)
		sendPacket(ConnectPacket)
	end

	NovaStar.socket.Reconnect = function()
		if DebugFunction then print("Reconnect() called") end
		print("TCP Socket Reconnecting?")
		NovaStar.setStatus(5,"Attempting to reconnect")
	end

	NovaStar.socket.Data = function()
		local data = NovaStar.socket:Read(NovaStar.socket.BufferLength)
		if DebugRx then print("Rx (" .. #data .. "b): " .. hexDump({data:byte(1, #data)})) end
		NovaStar.setStatus(0, "Connected - " .. Controls["IPAddress"].String)
	end

	NovaStar.socket.Closed = function()
		if DebugFunction then print("Closed() called") end
		print("TCP Socket Closed?")
		NovaStar.setStatus(2,"Connection closed by NovaStar")
	end

	NovaStar.socket.Error = function(sock, err)
		if DebugFunction then print("Error() called: " .. tostring(err)) end
		print("TCP Socket Error: ")
		print(err)
		NovaStar.setStatus(2,"Communication error with NovaStar")
		NovaStar.socket:Connect(Controls["IPAddress"].String, (Controls["Model"].String == "TU") and 5201 or 5200)
	end

	NovaStar.socket.Timeout = function(sock)
		if DebugFunction then print("Timeout() called") end
		print("TCP Socket Timeout" )
		NovaStar.setStatus(2,"Timeout in connection to NovaStar")
		NovaStar.socket:Connect(Controls["IPAddress"].String, (Controls["Model"].String == "TU") and 5201 or 5200)
	end

	Controls["Model"].EventHandler = function()
		local model = Controls["Model"].String
		if DebugFunction then print("Model changed to: " .. tostring(model)) end
		applyModelLayout(model)
		NovaStar.socket:Disconnect()
		local ip = Controls["IPAddress"].String
		if ip ~= "" then
			local port = (model == "TU") and 5201 or 5200
			NovaStar.socket:Connect(ip, port)
		end
		rewireVXButtons(model)
	end

	Controls["IPAddress"].EventHandler = function()
		local ip = Controls["IPAddress"].String
		if DebugFunction then print("IPAddress changed to: " .. tostring(ip)) end
		NovaStar.socket:Disconnect()
		if ip ~= "" then
			local port = (Controls["Model"].String == "TU") and 5201 or 5200
			NovaStar.socket:Connect(ip, port)
		end
	end

	for k, v in pairs(TestPatterns) do
		Controls['TEST_' .. k].EventHandler = function()
			for _, pkt in ipairs(v) do
				sendPacket(pkt)
			end
		end
	end

	Controls['Brightness'].EventHandler = function()
		sendBrightness(Controls['Brightness'].Value)
	end

	-- Apply initial model layout (show/hide correct controls for initial model)
	applyModelLayout(Controls["Model"].String)
	rewireVXButtons(Controls["Model"].String)

	-- Connect if IP address is already set
	if Controls["IPAddress"].String ~= "" then
		NovaStar.setStatus(5, "Connecting to NovaStar")
		local port = (Controls["Model"].String == "TU") and 5201 or 5200
		NovaStar.socket:Connect(Controls["IPAddress"].String, port)
	else
		NovaStar.setStatus(3, "Please set IP address")
	end

	-- Apply default brightness
	if Properties["Default Brightness"].Value ~= nil then
		Controls["Brightness"].Value = Properties["Default Brightness"].Value
		sendBrightness(Properties["Default Brightness"].Value)
	end

	SetupDebugPrint()

end
