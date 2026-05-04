-- info
PluginInfo = {
    Name = "NovaStar~VX4S/VX6S/VX1000/ProHD/ProHDJr/MCTRL4K/TU",
    Version = "0.3.0-dev",
    Id = "novastar.plugin.0.3.0-dev",
    Description = "Plugin for controlling NovaStar video wall controllers",
    ShowDebug = true,
    Author = "Joel Wetzell"
}

function GetPrettyName(props)
    return "NovaStar Controller"
end

Colors = {
    White    = {255, 255, 255},
    Black    = {0, 0, 0},
    Red      = {255, 0, 0},
    Green    = {0, 255, 0},
    Blue     = {0, 0, 255},
    DarkGrey = {0x56, 0x56, 0x56},
    LCD      = {0x02, 0x33, 0xb2}
}

function GetProperties()
    return {
        {
            Name  = "Default Brightness",
            Type  = "integer",
            Min   = 0,
            Max   = 255,
            Value = 128
        },
        {
            Name    = "Debug Print",
            Type    = "enum",
            Choices = {"None", "Tx/Rx", "Tx", "Rx", "Function Calls", "All"},
            Value   = "None"
        },
    }
end

function RectifyProperties(props)
    if props.plugin_show_debug.Value == false then
        props["Debug Print"].IsHidden = true
    end
    return props
end
