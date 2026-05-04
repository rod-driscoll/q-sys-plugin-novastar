-- controls
function GetControls(props)
	local controls = {
		-- Source Inputs
		{
			Name = "IN1",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN2",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN3",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN4",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN5",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN6",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN7",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN8",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN9",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "IN0",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		--Brightness Knob
		{
			Name = "Brightness",
			ControlType = "Knob",
			ControlUnit = "Integer",
			Min = 0,
			Max = 255,
			PinStyle = "Both",
			UserPin = true
		},

		-- Test Pattern Buttons
		{
			Name = "TEST_RED",
			ControlType = "Button",
			ButtonType = "Trigger"
		},

		{
			Name = "TEST_GREEN",
			ControlType = "Button",
			ButtonType = "Trigger"
		},
		{
			Name = "TEST_BLUE",
			ControlType = "Button",
			ButtonType = "Trigger"
		},
		{
			Name = "TEST_WHITE",
			ControlType = "Button",
			ButtonType = "Trigger"
		},
		{
			Name = "TEST_HORIZ",
			ControlType = "Button",
			ButtonType = "Trigger"
		},
		{
			Name = "TEST_VERT",
			ControlType = "Button",
			ButtonType = "Trigger"
		},
		{
			Name = "TEST_DIAG",
			ControlType = "Button",
			ButtonType = "Trigger"
		},
		{
			Name = "TEST_GRAY",
			ControlType = "Button",
			ButtonType = "Trigger"
		},
		{
			Name = "TEST_AGING",
			ControlType = "Button",
			ButtonType = "Trigger"
		},

		{
			Name = "PRESET1",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET2",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET3",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET4",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET5",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET6",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET7",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET8",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET9",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "PRESET10",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},

		{
			Name = "Status",
			ControlType = "Indicator",
			IndicatorType = "Status",
			PinStyle = "Output",
			UserPin = true
		},

		{
			Name = "Normal",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "Freeze",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
		{
			Name = "Black",
			ControlType = "Button",
			ButtonType = "Trigger",
			PinStyle = "Input",
			UserPin = true
		},
	}

    -- IP Address (replaces property)
    table.insert(controls, {
        Name         = "IPAddress",
        ControlType  = "Text",
        DefaultValue = "",
        UserPin      = true,
        PinStyle     = "Both"
    })

    -- Model combo (replaces property)
    table.insert(controls, {
        Name         = "Model",
        ControlType  = "Text",
        TextType     = "ComboBox",
        Choices      = {"VX4S","VX4S_N","VX6S","VX1000","PROHD","PROUHDJR","MCTRL4K","TU"},
        DefaultValue = "VX4S",
        UserPin      = true,
        PinStyle     = "Both"
    })

    -- Port display (read-only, auto-set by runtime)
    table.insert(controls, {
        Name         = "Port",
        ControlType  = "Text",
        DefaultValue = "5200",
        UserPin      = false
    })

    -- TU: source selection
    for _, name in ipairs({"INPUT_ANDROID","INPUT_HDMI1","INPUT_HDMI2","INPUT_HDMI3"}) do
        table.insert(controls, {
            Name        = name,
            ControlType = "Button",
            ButtonType  = "Trigger",
            UserPin     = true,
            PinStyle    = "Input"
        })
    end

    -- TU: display control
    for _, name in ipairs({"SCREEN_ON","SCREEN_OFF","STANDBY","WAKE"}) do
        table.insert(controls, {
            Name        = name,
            ControlType = "Button",
            ButtonType  = "Trigger",
            UserPin     = true,
            PinStyle    = "Input"
        })
    end

    -- TU: audio
    table.insert(controls, {
        Name        = "VOLUME",
        ControlType = "Knob",
        ControlUnit = "Integer",
        Min         = 0,
        Max         = 100,
        UserPin     = true,
        PinStyle    = "Both"
    })
    table.insert(controls, {
        Name        = "MUTE",
        ControlType = "Button",
        ButtonType  = "Toggle",
        UserPin     = true,
        PinStyle    = "Both"
    })

    -- TU: status readbacks
    table.insert(controls, {
        Name        = "CURRENT_SOURCE",
        ControlType = "Text",
        UserPin     = true,
        PinStyle    = "Output"
    })
    table.insert(controls, {
        Name        = "SYSTEM_STATUS",
        ControlType = "Text",
        UserPin     = true,
        PinStyle    = "Output"
    })

    return controls
end
