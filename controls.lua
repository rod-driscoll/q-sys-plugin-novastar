-- Reveal code pin for testing --
table.insert(controls, {
  Name         = "code",
  ControlType  = "Text",
  Count        = 1,
  UserPin      = true,
  PinStyle     = "Input"
})

-- Source Inputs
for _, n in ipairs({"IN1","IN2","IN3","IN4","IN5","IN6","IN7","IN8","IN9","IN0"}) do
  table.insert(controls, {Name=n, ControlType="Button", ButtonType="Momentary", PinStyle="Input", UserPin=true})
end

-- Brightness
table.insert(controls, {
  Name        = "Brightness",
  ControlType = "Knob",
  ControlUnit = "Integer",
  Min         = 0,
  Max         = 255,
  PinStyle    = "Both",
  UserPin     = true
})

-- Test Patterns
for _, n in ipairs({"TEST_RED","TEST_GREEN","TEST_BLUE","TEST_WHITE","TEST_HORIZ","TEST_VERT","TEST_DIAG","TEST_GRAY","TEST_AGING"}) do
  table.insert(controls, {Name=n, ControlType="Button", ButtonType="Momentary"})
end

-- Presets
for _, n in ipairs({"PRESET1","PRESET2","PRESET3","PRESET4","PRESET5","PRESET6","PRESET7","PRESET8","PRESET9","PRESET10"}) do
  table.insert(controls, {Name=n, ControlType="Button", ButtonType="Momentary", PinStyle="Input", UserPin=true})
end

-- Status and display mode
table.insert(controls, {Name="Status", ControlType="Indicator", IndicatorType="Status", PinStyle="Output", UserPin=true})
table.insert(controls, {Name="Normal", ControlType="Button", ButtonType="Momentary", PinStyle="Input", UserPin=true})
table.insert(controls, {Name="Freeze", ControlType="Button", ButtonType="Momentary", PinStyle="Input", UserPin=true})
table.insert(controls, {Name="Black",  ControlType="Button", ButtonType="Momentary", PinStyle="Input", UserPin=true})

-- Setup controls
table.insert(controls, {Name="IPAddress", ControlType="Text", DefaultValue="", UserPin=true, PinStyle="Both"})
table.insert(controls, {Name="ConnectBtn", ControlType ="Button", ButtonType="Toggle", Count=1, UserPin=true, PinStyle="Input"})
table.insert(controls, {Name="Connected", ControlType="Indicator", IndicatorType="Led", Count=1, UserPin=true, PinStyle="Output"})
table.insert(controls, {
  Name         = "Model",
  ControlType  = "Text",
  TextType     = "ComboBox",
  Choices      = {"VX4S","VX4S_N","VX6S","VX1000","PROHD","PROUHDJR","MCTRL4K","TU"},
  DefaultValue = "VX4S",
  UserPin      = true,
  PinStyle     = "Both"
})
table.insert(controls, {Name="Port", ControlType="Text", DefaultValue="5200", UserPin=false})
table.insert(controls, {Name="PollBtn", ControlType="Button", ButtonType="Momentary", Count=1, UserPin=true, PinStyle="Input"})
table.insert(controls, {Name="PollRate", ControlType="Knob", ControlUnit="Seconds", Min=0, Max=300, MajorDivisions=10, Count=1, DefaultValue=30, UserPin=false, PinStyle="None"})
-- TU: source selection
for _, n in ipairs({"INPUT_ANDROID","INPUT_HDMI1","INPUT_HDMI2","INPUT_HDMI3"}) do
  table.insert(controls, {Name=n, ControlType="Button", ButtonType="Momentary", UserPin=true, PinStyle="Input"})
end

-- TU: display control
for _, n in ipairs({"SCREEN_ON","SCREEN_OFF","STANDBY","WAKE"}) do
  table.insert(controls, {Name=n, ControlType="Button", ButtonType="Momentary", UserPin=true, PinStyle="Input"})
end

-- TU: audio
table.insert(controls, {Name="VOLUME", ControlType="Knob", ControlUnit="Integer", Min=0, Max=100, UserPin=true, PinStyle="Both"})
table.insert(controls, {Name="MUTE",   ControlType="Button", ButtonType="Toggle", UserPin=true, PinStyle="Both"})

-- TU: status readbacks
table.insert(controls, {Name="CURRENT_SOURCE", ControlType="Text", UserPin=true, PinStyle="Output"})
table.insert(controls, {Name="SYSTEM_STATUS",  ControlType="Text", UserPin=true, PinStyle="Output"})
