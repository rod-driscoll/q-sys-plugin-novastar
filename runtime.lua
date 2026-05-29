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
		TU      = {"Android","HDMI1","HDMI2","HDMI3","","","","","",""}
	}

	local VX_MODELS = {VX4S=true,VX4S_N=true,VX6S=true,VX1000=true,PROHD=true,PROUHDJR=true,MCTRL4K=true,TU=true}
	local TU_CONTROLS = {"INPUT_ANDROID","INPUT_HDMI1","INPUT_HDMI2","INPUT_HDMI3",
	                      "SCREEN_ON","SCREEN_OFF","STANDBY","WAKE","VOLUME","MUTE",
	                      "TEST_BLACK","TEST_VBARS","TEST_HBARS","TEST_CHESS"}
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
				Controls[name].IsInvisible = false --isTU
				Controls[name].IsDisabled  = false --isTU
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
		if true then --if not isTU then
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
		if Controls["Port"] then
			Controls["Port"].String = isTU and "5201" or "5200"
		end
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
		voluntaryDisconnect = true
		NovaStar.socket:Disconnect()
		Controls["Connected"].Boolean = false
		NovaStar.setStatus(2, "Disconnected")
	end

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
		BLACK = makeTestPattern(0x00), RED   = makeTestPattern(0x01),
		GREEN = makeTestPattern(0x02), BLUE  = makeTestPattern(0x03),
		WHITE = makeTestPattern(0x04), VBARS  = makeTestPattern(0x05),
		HBARS = makeTestPattern(0x06), CHESS = makeTestPattern(0x07),
		DIAG  = makeTestPattern(0x08), GRAY  = makeTestPattern(0x09),
		AGING = makeTestPattern(0x0A), HLINE = makeTestPattern(0x10),
		VLINE = makeTestPattern(0x11), BSLASH= makeTestPattern(0x12),
		FSLASH= makeTestPattern(0x13), GRID  = makeTestPattern(0x14),
		HATCH = makeTestPattern(0x15), RGRADH= makeTestPattern(0x20),
		GGRADH= makeTestPattern(0x21), BGRADH= makeTestPattern(0x22),
		WGRADH= makeTestPattern(0x23), RGRADV= makeTestPattern(0x24),
		GGRADV= makeTestPattern(0x25), BGRADV= makeTestPattern(0x26),
		WGRADV= makeTestPattern(0x27)

		-- RED   = makeTestPattern(0x02), GREEN = makeTestPattern(0x03),
		-- BLUE  = makeTestPattern(0x04), WHITE = makeTestPattern(0x05),
		-- HORIZ = makeTestPattern(0x06), VERT  = makeTestPattern(0x07),
		-- DIAG  = makeTestPattern(0x08), GRAY  = makeTestPattern(0x09),
		-- AGING = makeTestPattern(0x0A),
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
		TU      = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x02,0x00,0x00,0x00},0,nil),
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
		TU      = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x01,0x00,0x00,0x00},0,nil),
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
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x04,0x00,0x00}), --SDI1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x05,0x00,0x00}), --OPT1
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x06,0x00,0x00}), --OPT2
			buildPacket(0x00,VX_SRC,0x00,0x00,0x00,0x00,0x00,WRITE,{0x12,0x00,0x02,0x13},3,{0x07,0x00,0x00}), --MOSAIC
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
		TU = {
			buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x04,0x00,0x00,0x00},1,{0x03}), --ANDROID
			buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x04,0x00,0x00,0x00},1,{0x01}), --HDMI1
			buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x04,0x00,0x00,0x00},1,{0x02}), --HDMI2
			buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x04,0x00,0x00,0x00},1,{0x04}), --HDMI3
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

	-- TU Android Card Control commands (DevType=0x08, SrcAddr=TU_SRC=0xFC)
	local TuCmds = {
		Standby    = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x01,0x00,0x00,0x00},0,nil),
		Wake       = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x02,0x00,0x00,0x00},0,nil),
		PowerOn    = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x03,0x00,0x00,0x00},1,{0x01}),
		PowerOff   = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x03,0x00,0x00,0x00},1,{0x00}),
		ScreenOn   = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x0D,0x00,0x00,0x00},1,{0x01}), -- doesn't work
		ScreenOff  = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x0D,0x00,0x00,0x00},1,{0x00}), -- doesn't work
		SrcHDMI1   = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x04,0x00,0x00,0x00},1,{0x01}),
		SrcHDMI2   = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x04,0x00,0x00,0x00},1,{0x02}),
		SrcAndroid = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x04,0x00,0x00,0x00},1,{0x03}),
		SrcHDMI3   = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x04,0x00,0x00,0x00},1,{0x04}),
		Mute       = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x05,0x00,0x00,0x00},1,{0x15}),
		Unmute     = buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,{0x05,0x00,0x00,0x00},1,{0x05}),
	}
	-- TU read commands (Android Card Monitoring, DevType=0x06)
	local TuRead = {
		CurrentSource = buildPacket(0x01,TU_SRC,0x00,0x06,0x00,0xFF,0xFF,READ,{0x04,0x00,0x00,0x00},1,nil),
		PowerStatus  = buildPacket(0x01,TU_SRC,0x00,0x06,0x00,0xFF,0xFF,READ,{0x03,0x00,0x00,0x00},1,nil),
		SystemStatus  = buildPacket(0x01,TU_SRC,0x00,0x06,0x00,0xFF,0xFF,READ,{0x0D,0x00,0x00,0x00},1,nil), -- doesn't work
	}

	local TU_SOURCE_NAMES = {[0]="Android",[1]="HDMI1",[2]="HDMI2",[3]="HDMI3"}
	local TU_STATUS_NAMES = {[0]="Standby",[1]="Normal display"}

	local pendingRead        = nil
	local pendingTuSource    = nil
	local pollToken          = 0
	local voluntaryDisconnect = false
	local pendingPowerCmd    = nil
	local powerCmdToken      = 0

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

	local function applyTuSourceFeedback(src)
		Controls["CURRENT_SOURCE"].String = TU_SOURCE_NAMES[src] or ("Unknown("..src..")")
		local names = {"IN1","IN2","IN3","IN4","IN5","IN6","IN7","IN8","IN9","IN0"}
		for i, ctrlName in ipairs(names) do
			if Controls[ctrlName] then Controls[ctrlName].Boolean = src == (i-1) end
		end
		local labels = InputLabels["TU"]
		for i, ctrlLabel in ipairs(labels) do
			local label = TU_CONTROLS[i]
			if ctrlLabel ~= '' and Controls[label] then
				Controls[label].Boolean = src == (i-1)
			end
		end
	end

	local function startTUPolling(token)
		if Controls["PollRate"].Value == 0 then return end
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

	local function rewireVXButtons(model)
		if not VX_MODELS[model] then return end
		-- Wire input buttons for the current VX model
		local inputList = Inputs[model] or {}
		for k, v in ipairs(inputList) do
			local ctrlName = (k == 10) and "IN0" or ("IN" .. k)
			if Controls[ctrlName] and v and #v > 0 then
				Controls[ctrlName].EventHandler = function(c) if not c.Boolean then sendPacket(v) end end
			end
		end
		-- Wire preset buttons for the current VX model
		local presetTable = Presets[model]
		if presetTable then
			for k, v in ipairs(presetTable) do
				if Controls["PRESET" .. k] then
					Controls["PRESET" .. k].EventHandler = function(c) if not c.Boolean then sendPacket(v) end end
				end
			end
		end
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
	end

	local function sendBrightness(value)
		if DebugFunction then print("sendBrightness() called: " .. tostring(value)) end
		sendPacket(makeBrightnessPacket(math.floor(value)))
	end

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

	NovaStar.socket.Reconnect = function()
		if DebugFunction then print("Reconnect() called") end
		print("TCP Socket Reconnecting?")
		NovaStar.setStatus(5,"Attempting to reconnect")
	end

	NovaStar.socket.Data = function()
		powerCmdToken = powerCmdToken + 1
		local data = NovaStar.socket:Read(NovaStar.socket.BufferLength)
		if DebugRx then print("Rx (" .. #data .. "b): " .. hexDump({data:byte(1, #data)})) end
		NovaStar.setStatus(0, "Connected - " .. Controls["IPAddress"].String)

		-- Parse TU read responses
		if Controls["Model"].String == "TU" and #data >= 19 then
			local b1, b2, devType = data:byte(1), data:byte(2), data:byte(7)
			if b1 == 0xAA and b2 == 0x55 and devType == 0x06 then
				local dataByte = data:byte(19)
				if dataByte then
					if pendingRead == "CurrentSource" then
						if DebugFunction then print("CurrentSource["..tostring(dataByte).."]: "..(TU_SOURCE_NAMES[dataByte] or "Unknown")) end
						applyTuSourceFeedback(dataByte)
						-- SystemStatus doesn't work on TU series, not tested elsewhere
						-- pendingRead = "SystemStatus"
						-- sendPacket(TuRead.SystemStatus) 
						pendingRead = "PowerStatus"
						sendPacket(TuRead.PowerStatus)
					elseif pendingRead == "PowerStatus" then
						Controls["SYSTEM_STATUS"].String = TU_STATUS_NAMES[dataByte] or ("Unknown("..dataByte..")")
						-- update TU power buttons
						Controls["SCREEN_ON"].Boolean  = dataByte==1
						Controls["SCREEN_OFF"].Boolean = dataByte==0
 						pendingRead = nil
					elseif pendingRead == "SystemStatus" then
						Controls["SYSTEM_STATUS"].String = TU_STATUS_NAMES[dataByte] or ("Unknown("..dataByte..")")
						-- update VX power buttons
						Controls["Normal"].Boolean = dataByte==1
						Controls["Black"].Boolean = dataByte==0
						-- update TU power buttons
						Controls["WAKE"].Boolean = dataByte==1
						Controls["STANDBY"].Boolean = dataByte==0
 						pendingRead = nil
					end
				end
			elseif b1 == 0xAA and b2 == 0x55 and devType == 0x08 and data:byte(11) == WRITE then
				-- write-ack echo: byte(13) holds the command byte
				local cmdByte = data:byte(13)
				if cmdByte == 0x04 then      -- Source switch ack
					if pendingTuSource ~= nil then
						applyTuSourceFeedback(pendingTuSource)
						pendingTuSource = nil
					end
				elseif cmdByte == 0x02 then  -- Wake / Normal ack
					Controls["WAKE"].Boolean    = true
					Controls["STANDBY"].Boolean = false
					Controls["Normal"].Boolean  = true
					Controls["Black"].Boolean   = false
				elseif cmdByte == 0x01 then  -- Standby / Black ack
					Controls["WAKE"].Boolean    = false
					Controls["STANDBY"].Boolean = true
					Controls["Normal"].Boolean  = false
					Controls["Black"].Boolean   = true
				end
			end
		end
	end

	NovaStar.socket.Closed = function()
		if DebugFunction then print("Closed() called") end
		if voluntaryDisconnect then
			voluntaryDisconnect = false
			return
		end
		pollToken = pollToken + 1
		Controls["Connected"].Boolean = false
		NovaStar.setStatus(2, "Connection closed")
	end

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

	Controls["Model"].EventHandler = function()
		local model = Controls["Model"].String
		if DebugFunction then print("Model changed to: " .. tostring(model)) end
		applyModelLayout(model)
		pollToken = pollToken + 1
		voluntaryDisconnect = true
		NovaStar.socket:Disconnect()
		Controls["Connected"].Boolean = false
		if Controls["ConnectBtn"].Boolean then
			NovaStar.connect()
		end
		rewireVXButtons(model)
	end

	Controls["IPAddress"].EventHandler = function()
		local ip = Controls["IPAddress"].String
		if DebugFunction then print("IPAddress changed to: " .. tostring(ip)) end
		NovaStar.socket:Disconnect()
		if Controls["ConnectBtn"].Boolean then
			NovaStar.connect()
		end
	end

	Controls["ConnectBtn"].EventHandler = function(ctl)
		if ctl.Boolean then
			NovaStar.connect()
		else
			NovaStar.disconnect()
		end
	end

	Controls["PollRate"].EventHandler = function()
		pollToken = pollToken + 1
		if Controls["PollRate"].Value > 0
				and Controls["Model"].String == "TU"
				and NovaStar.socket.IsConnected then
			startTUPolling(pollToken)
		end
	end

	Controls["PollBtn"].EventHandler = function(ctl)
		if not ctl.Boolean then return end
		if Controls["Model"].String ~= "TU" then return end
		if not NovaStar.socket.IsConnected then return end
		if pendingRead ~= nil then return end
		pendingRead = "CurrentSource"
		sendPacket(TuRead.CurrentSource)
	end

	-- TU series control event handlers
	Controls["INPUT_HDMI1"].EventHandler   = function(c) if not c.Boolean then pendingTuSource = 1 sendPacket(TuCmds.SrcHDMI1) end end
	Controls["INPUT_HDMI2"].EventHandler   = function(c) if not c.Boolean then pendingTuSource = 2 sendPacket(TuCmds.SrcHDMI2) end end
	Controls["INPUT_HDMI3"].EventHandler   = function(c) if not c.Boolean then pendingTuSource = 3 sendPacket(TuCmds.SrcHDMI3) end end
	Controls["INPUT_ANDROID"].EventHandler = function(c) if not c.Boolean then pendingTuSource = 0 sendPacket(TuCmds.SrcAndroid) end end
	Controls["STANDBY"].EventHandler       = function(c) if not c.Boolean then sendPowerCmd(TuCmds.Standby) end end
	Controls["WAKE"].EventHandler          = function(c) if not c.Boolean then sendPowerCmd(TuCmds.Wake) end end
	Controls["SCREEN_ON"].EventHandler     = function(c) if not c.Boolean then sendPowerCmd(TuCmds.PowerOn) end end
	Controls["SCREEN_OFF"].EventHandler    = function(c) if not c.Boolean then sendPowerCmd(TuCmds.PowerOff) end end

	Controls["MUTE"].EventHandler = function()
		sendPacket(Controls["MUTE"].Boolean and TuCmds.Mute or TuCmds.Unmute)
	end

	Controls["VOLUME"].EventHandler = function()
		local vol = math.floor(Controls["VOLUME"].Value) & 0xFF
		sendPacket(buildPacket(0x01,TU_SRC,0x00,0x08,0x00,0xFF,0xFF,WRITE,
		                       {0x06,0x00,0x00,0x00},1,{vol}))
	end

	for k, v in pairs(TestPatterns) do
		if Controls['TEST_' .. k] then
			Controls['TEST_' .. k].EventHandler = function()
				for _, pkt in ipairs(v) do
					sendPacket(pkt)
				end
			end
		end
	end

	Controls['Brightness'].EventHandler = function()
		sendBrightness(Controls['Brightness'].Value)
	end

	-- Ensure combo choices are always correct at runtime (may differ from cached design-time value)
	Controls["Model"].Choices = {"VX4S","VX4S_N","VX6S","VX1000","PROHD","PROUHDJR","MCTRL4K","TU"}

	-- Apply initial model layout (show/hide correct controls for initial model)
	applyModelLayout(Controls["Model"].String)
	rewireVXButtons(Controls["Model"].String)

	-- Connect on load if ConnectBtn is already set
	if Controls["ConnectBtn"].Boolean then
		NovaStar.connect()
	else
		NovaStar.setStatus(3, "Not connected")
	end

	-- Apply default brightness
	if Properties["Default Brightness"].Value ~= nil then
		Controls["Brightness"].Value = Properties["Default Brightness"].Value
		sendBrightness(Properties["Default Brightness"].Value)
	end

	SetupDebugPrint()
