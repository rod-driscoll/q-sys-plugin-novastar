local CurrentPage=PageNames[props["page_index"].Value]

controls["code"]={PrettyName="code",Style="None"}

-- ── Setup page ──────────────────────────────────────────────────────
if CurrentPage == "Setup" then
  local W=420

  -- Connect group box
  table.insert(graphics, { Type="GroupBox", Text="Connect",                   Position={   5,  5 }, Size={ W - 10, 115 }, Fill=Colors.Background, StrokeWidth=1, CornerRadius=4, HTextAlign="Left" })
  table.insert(graphics, { Type="Text", Text="IP Address",                    Position={  15, 35 }, Size={ 100, 16 }, FontSize=14, HTextAlign="Right" })
  table.insert(graphics, { Type="Text", Text="Model",                         Position={  15, 56 }, Size={ 100, 16 }, FontSize=14, HTextAlign="Right" })
  table.insert(graphics, { Type="Text", Text="Port",                          Position={  15, 77 }, Size={ 100, 16 }, FontSize=14, HTextAlign="Right" })
  table.insert(graphics, { Type="Text", Text="(auto)",                        Position={ 178, 77 }, Size={  42, 16 }, FontSize=12, HTextAlign="Center" })
  table.insert(graphics, { Type="Text", Text="Connected",                     Position={ 224, 35 }, Size={ 100, 16 }, FontSize=14, HTextAlign="Right"})
  table.insert(graphics, { Type="Text", Text="Poll Rate",                     Position={ 224, 77 }, Size={ 100, 16 }, FontSize=14, HTextAlign="Right"})
  
  controls["IPAddress"] = { PrettyName="Setup~IP Address",  Style="Text",     Position={ 120, 35 }, Size={ 100, 16 }, FontSize=12 }
  controls["Model"]     = { PrettyName="Setup~Model",       Style="ComboBox", Position={ 120, 56 }, Size={ 100, 16 }, FontSize=12 }
  controls["Port"]      = { PrettyName="Setup~Port",        Style="Text",     Position={ 120, 77 }, Size={  58, 16 }, IsReadOnly=true, Color=Colors.DarkGrey, FontSize=12 }
  controls["Connected"] = { PrettyName="Status~Connected",  Style="Led",      Position={ 324, 35 }, Size={  16, 16 }, Color=Colors.Green}
  controls["ConnectBtn"]= { PrettyName="Settings~Connect Toggle", Style="Button",Position={346,35}, Size={  52, 20 }, Legend="Connect", Color=Colors.Button, FontSize=11}
  controls["PollBtn"]   = { PrettyName="Settings~Poll Now", Style="Button",   Position={ 346, 54 }, Size={  52, 20 }, Legend="Poll", Color=Colors.Button, FontSize=11}
  controls["PollRate"]  = { PrettyName="Settings~Poll Rate (s)", Style="Text", Position={346, 77 }, Size={  52, 20 }, Min=1, Max=300, FontSize=11}

  -- Status group box
  table.insert(graphics, { Type="GroupBox", Text="Status",                          Position={ 5, 130 }, Size={ W - 10, 140 }, Fill=Colors.Background, StrokeColor=Colors.Header, StrokeWidth=1, CornerRadius=4, HTextAlign="Left" })
  table.insert(graphics, { Type="Text",     Text="System Status",                   Position={ 15, 193 }, Size={ 110, 16 }, FontSize=12, HTextAlign="Right" })
  table.insert(graphics, { Type="Text",     Text="Current Source",                  Position={ 15, 216 }, Size={ 110, 16 }, FontSize=12, HTextAlign="Right" })
  controls["Status"]          = { PrettyName="Status~Connection Status",            Position={ 15, 155 }, Size={ W - 30, 28 }, Padding=4 }
  controls["SYSTEM_STATUS"]   = { PrettyName="Status~System Status",  Style="Text", Position={ 130, 192 }, Size={ W - 145, 16 }, HTextAlign="Left", IsReadOnly=true, StrokeWidth=0, FontSize=13, IsBold=true }
  controls["CURRENT_SOURCE"]  = { PrettyName="Status~Current Source", Style="Text", Position={ 130, 215 }, Size={ W - 145, 16 }, HTextAlign="Left", IsReadOnly=true, StrokeWidth=0, FontSize=13, IsBold=true }

  table.insert(graphics, { Type="Text", Text=GetPrettyName(),                       Position={ 20, 250 }, Size={ 380, 14 }, FontSize=10, HTextAlign="Right", Color=Colors.Gray })

  -- ── Control page ────────────────────────────────────────────────────
elseif CurrentPage == "Control" then
  local rackSize={ 1000, 120 }

  local inputPosition={ rackSize[1] * 5 / 16 + 10, 5 }
  local testPosition={ rackSize[1] * 9 / 16 + 15, 5 }
  local presetPosition={ rackSize[1] * 13 / 16 + 20, 5 }

  table.insert(graphics, {       -- Outer box
    Type="GroupBox", StrokeWidth=1, CornerRadius=8, Fill=Colors.Background, Size=rackSize, Position={ 0, 0 } })
  -- Inputs box
  table.insert(graphics, { Type="GroupBox", Text="INPUTS", Color=Colors.Header, HTextAlign="CENTER", CornerRadius=3, Fill=Colors.Background, StrokeWidth=1, Size={ 250, rackSize[2] - 10 }, Position=inputPosition })
  -- Test box
  table.insert(graphics, { Type="GroupBox", Text="TEST", Color=Colors.Header, HTextAlign="CENTER", CornerRadius=3, Fill=Colors.Background, StrokeWidth=1, Size={ 250, rackSize[2] - 10 }, Position=testPosition })
  -- Preset box
  table.insert(graphics, { Type="GroupBox", Text="PRESET", Color=Colors.Header, HTextAlign="CENTER", CornerRadius=3, Fill=Colors.Background, StrokeWidth=1, Size={ 160, rackSize[2] - 10 }, Position=presetPosition })
  -- NovaStar Text
  table.insert(graphics, { Type="Label", Text="NovaStar", TextSize=16, HTextAlign="Center", IsBold=true, Size={ 150, 16 }, Position={ 60, rackSize[2] * 1 / 8 } })

  controls['Brightness']    = { Style="Knob", Color=Colors.DarkGrey, Fill=Colors.DarkGrey, Size={ rackSize[2] / 2, rackSize[2] / 2 }, Position={ 250, rackSize[2] * 1 / 4 } }

  local SourceButton        = { yStart=inputPosition[2] + 20, Padding=5 }
  local TestButton          = { yStart=testPosition[2] + 20, Padding=5 }
  local PresetButton        = { yStart=presetPosition[2] + 20, Padding=3 }
  local ModeButton          = { yStart=2, Padding=2 }

  SourceButton.Size         = { (rackSize[2] - 30 - (SourceButton.Padding * 2)) / 2, (rackSize[2] - 30 - (SourceButton.Padding * 2)) / 2 }
  TestButton.Size           = { (rackSize[2] - 30 - (TestButton.Padding * 2)) / 2, (rackSize[2] - 30 - (TestButton.Padding * 2)) / 2 }
  PresetButton.Size         = { (rackSize[2] - 30 - (PresetButton.Padding * 2)) / 3, (rackSize[2] - 30 - (PresetButton.Padding * 2)) / 3 }
  ModeButton.Size           = { (rackSize[2] / 3) - (ModeButton.Padding * 2), (rackSize[2] / 3) - (ModeButton.Padding * 2) }
  SourceButton.xStart       =inputPosition[1] + ((250 - (((SourceButton.Size[1] * 5) + (SourceButton.Padding * 4)))) / 2)
  TestButton.xStart         =testPosition[1] + ((250 - (((TestButton.Size[1] * 5) + (TestButton.Padding * 4)))) / 2)
  PresetButton.xStart       =presetPosition[1] +
  ((160 - (((PresetButton.Size[1] * 5) + (PresetButton.Padding * 4)))) / 2)
  ModeButton.xStart         =ModeButton.Padding * 6

  local TestLabels          = { "Red", "Green", "Blue", "White", "Horiz", "Vert", "Diag", "Gray", "Aging" }

  --First row of input buttons
  controls['IN1']           = { Style="Button", ButtonType="Momentary", Legend=tostring(1), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart, SourceButton.yStart }, Size=SourceButton.Size }
  controls['IN2']           = { Style="Button", ButtonType="Momentary", Legend=tostring(2), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart + ((SourceButton.Size[1] + SourceButton.Padding) * 1), SourceButton.yStart }, Size=SourceButton.Size }
  controls['IN3']           = { Style="Button", ButtonType="Momentary", Legend=tostring(3), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart + ((SourceButton.Size[1] + SourceButton.Padding) * 2), SourceButton.yStart }, Size=SourceButton.Size }
  controls['IN4']           = { Style="Button", ButtonType="Momentary", Legend=tostring(4), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart + ((SourceButton.Size[1] + SourceButton.Padding) * 3), SourceButton.yStart }, Size=SourceButton.Size }
  controls['IN5']           = { Style="Button", ButtonType="Momentary", Legend=tostring(5), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart + ((SourceButton.Size[1] + SourceButton.Padding) * 4), SourceButton.yStart }, Size=SourceButton.Size }

  --First row of test buttons
  controls['TEST_RED']      = { Style="Button", ButtonType="Momentary", Legend=TestLabels[1] ~= nil and TestLabels[1] or "1", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart, TestButton.yStart }, Size=TestButton.Size }
  controls['TEST_GREEN']    = { Style="Button", ButtonType="Momentary", Legend=TestLabels[2] ~= nil and TestLabels[2] or "2", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart + ((TestButton.Size[1] + TestButton.Padding) * 1), TestButton.yStart }, Size=TestButton.Size }
  controls['TEST_BLUE']     = { Style="Button", ButtonType="Momentary", Legend=TestLabels[3] ~= nil and TestLabels[3] or "3", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart + ((TestButton.Size[1] + TestButton.Padding) * 2), TestButton.yStart }, Size=TestButton.Size }
  controls['TEST_WHITE']    = { Style="Button", ButtonType="Momentary", Legend=TestLabels[4] ~= nil and TestLabels[4] or "4", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart + ((TestButton.Size[1] + TestButton.Padding) * 3), TestButton.yStart }, Size=TestButton.Size }
  controls['TEST_HORIZ']    = { Style="Button", ButtonType="Momentary", Legend=TestLabels[5] ~= nil and TestLabels[5] or "5", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart + ((TestButton.Size[1] + TestButton.Padding) * 4), TestButton.yStart }, Size=TestButton.Size }

  --First row of preset buttons
  controls['PRESET1']       = { Style="Button", ButtonType="Momentary", Legend="1", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart, PresetButton.yStart }, Size=PresetButton.Size }
  controls['PRESET2']       = { Style="Button", ButtonType="Momentary", Legend="2", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart + ((PresetButton.Size[1] + PresetButton.Padding) * 1), PresetButton.yStart }, Size=PresetButton.Size }
  controls['PRESET3']       = { Style="Button", ButtonType="Momentary", Legend="3", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart + ((PresetButton.Size[1] + PresetButton.Padding) * 2), PresetButton.yStart }, Size=PresetButton.Size }
  controls['PRESET4']       = { Style="Button", ButtonType="Momentary", Legend="4", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart + ((PresetButton.Size[1] + PresetButton.Padding) * 3), PresetButton.yStart }, Size=PresetButton.Size }
  controls['PRESET5']       = { Style="Button", ButtonType="Momentary", Legend="5", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart + ((PresetButton.Size[1] + PresetButton.Padding) * 4), PresetButton.yStart }, Size=PresetButton.Size }

  --bump down second row of buttons
  SourceButton.yStart       = SourceButton.yStart + SourceButton.Size[1] + (SourceButton.Padding / 2)
  TestButton.yStart         = TestButton.yStart + TestButton.Size[1] + (TestButton.Padding / 2)
  PresetButton.yStart       = PresetButton.yStart + PresetButton.Size[1] + (PresetButton.Padding / 2)

  --Second row of input buttons
  controls['IN6']           = { Style="Button", ButtonType="Momentary", Legend=tostring(6), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart, SourceButton.yStart }, Size=SourceButton.Size }
  controls['IN7']           = { Style="Button", ButtonType="Momentary", Legend=tostring(7), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart + ((SourceButton.Size[1] + SourceButton.Padding) * 1), SourceButton.yStart }, Size=SourceButton.Size }
  controls['IN8']           = { Style="Button", ButtonType="Momentary", Legend=tostring(8), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart + ((SourceButton.Size[1] + SourceButton.Padding) * 2), SourceButton.yStart }, Size=SourceButton.Size }
  controls['IN9']           = { Style="Button", ButtonType="Momentary", Legend=tostring(9), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart + ((SourceButton.Size[1] + SourceButton.Padding) * 3), SourceButton.yStart }, Size=SourceButton.Size }
  controls['IN0']           = { Style="Button", ButtonType="Momentary", Legend=tostring(0), OffColor=Colors.White, Color=Colors.Red, Position={ SourceButton.xStart + ((SourceButton.Size[1] + SourceButton.Padding) * 4), SourceButton.yStart }, Size=SourceButton.Size }

  --Second row of test buttons
  controls['TEST_VERT']     = { Style="Button", ButtonType="Momentary", Legend=TestLabels[6] ~= nil and TestLabels[6] or "6", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart, TestButton.yStart }, Size=TestButton.Size }
  controls['TEST_DIAG']     = { Style="Button", ButtonType="Momentary", Legend=TestLabels[7] ~= nil and TestLabels[7] or "7", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart + ((TestButton.Size[1] + TestButton.Padding) * 1), TestButton.yStart }, Size=TestButton.Size }
  controls['TEST_GRAY']     = { Style="Button", ButtonType="Momentary", Legend=TestLabels[8] ~= nil and TestLabels[8] or "8", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart + ((TestButton.Size[1] + TestButton.Padding) * 2), TestButton.yStart }, Size=TestButton.Size }
  controls['TEST_AGING']    = { Style="Button", ButtonType="Momentary", Legend=TestLabels[9] ~= nil and TestLabels[9] or "9", OffColor=Colors.White, Color=Colors.Red, Position={ TestButton.xStart + ((TestButton.Size[1] + TestButton.Padding) * 3), TestButton.yStart }, Size=TestButton.Size }
  --Second row of preset buttons
  controls['PRESET6']       = { Style="Button", ButtonType="Momentary", Legend="6", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart, PresetButton.yStart }, Size=PresetButton.Size }
  controls['PRESET7']       = { Style="Button", ButtonType="Momentary", Legend="7", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart + ((PresetButton.Size[1] + PresetButton.Padding) * 1), PresetButton.yStart }, Size=PresetButton.Size }
  controls['PRESET8']       = { Style="Button", ButtonType="Momentary", Legend="8", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart + ((PresetButton.Size[1] + PresetButton.Padding) * 2), PresetButton.yStart }, Size=PresetButton.Size }
  controls['PRESET9']       = { Style="Button", ButtonType="Momentary", Legend="9", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart + ((PresetButton.Size[1] + PresetButton.Padding) * 3), PresetButton.yStart }, Size=PresetButton.Size }
  controls['PRESET10']      = { Style="Button", ButtonType="Momentary", Legend="10", OffColor=Colors.White, Color=Colors.Red, Position={ PresetButton.xStart + ((PresetButton.Size[1] + PresetButton.Padding) * 4), PresetButton.yStart }, Size=PresetButton.Size }
  controls['Normal']        = { Style="Button", ButtonType="Momentary", Legend="Normal", OffColor=Colors.White, Color=Colors.Red, Position={ ModeButton.xStart, ModeButton.yStart }, Size=ModeButton.Size }
  controls['Freeze']        = { Style="Button", ButtonType="Momentary", Legend="Freeze", OffColor=Colors.White, Color=Colors.Red, Position={ ModeButton.xStart, ModeButton.yStart + ((ModeButton.Size[1] + ModeButton.Padding + ModeButton.Padding) * 1) }, Size=ModeButton.Size }
  controls['Black']         = { Style="Button", ButtonType="Momentary", Legend="Black", OffColor=Colors.White, Color=Colors.Red, Position={ ModeButton.xStart, ModeButton.yStart + ((ModeButton.Size[1] + ModeButton.Padding + ModeButton.Padding) * 2) }, Size=ModeButton.Size }
  controls['Status']        = { Style="Text", Color=Colors.LCD, TextSize=10, UserPin=true, PinStyle="Output", Size={ 150, rackSize[2] / 2 }, Position={ 60, rackSize[2] * 1 / 4 } }

  -- TU controls (hidden on the Control page; shown/hidden by runtime based on Model)
  local btnSize             = { 42, 42 }
  local tuY                 =rackSize[2]

  controls["INPUT_ANDROID"] = { Style="Button", ButtonType="Momentary", Legend="Android", OffColor=Colors.White, Color=Colors.Blue, Position={ 10, tuY }, Size=btnSize, IsInvisible=true }
  controls["INPUT_HDMI1"]   = { Style="Button", ButtonType="Momentary", Legend="HDMI1",   OffColor=Colors.White, Color=Colors.Blue, Position={ 60, tuY }, Size=btnSize, IsInvisible=true }
  controls["INPUT_HDMI2"]   = { Style="Button", ButtonType="Momentary", Legend="HDMI2",   OffColor=Colors.White, Color=Colors.Blue, Position={ 110, tuY }, Size=btnSize, IsInvisible=true }
  controls["INPUT_HDMI3"]   = { Style="Button", ButtonType="Momentary", Legend="HDMI3",   OffColor=Colors.White, Color=Colors.Blue, Position={ 160, tuY }, Size=btnSize, IsInvisible=true }

  controls["SCREEN_ON"]     = { Style="Button", ButtonType="Momentary", Legend="On",    OffColor=Colors.White, Color=Colors.Green, Position={ 210, tuY }, Size=btnSize, IsInvisible=true }
  controls["SCREEN_OFF"]    = { Style="Button", ButtonType="Momentary", Legend="Off",   OffColor=Colors.White, Color=Colors.Red, Position={ 260, tuY }, Size=btnSize, IsInvisible=true }
  controls["STANDBY"]       = { Style="Button", ButtonType="Momentary", Legend="Stby",  OffColor=Colors.White, Color=Colors.DarkGrey, Position={ 310, tuY }, Size=btnSize, IsInvisible=true }
  controls["WAKE"]          = { Style="Button", ButtonType="Momentary", Legend="Wake",  OffColor=Colors.White, Color=Colors.Green, Position={ 360, tuY }, Size=btnSize, IsInvisible=true }
 
  controls["VOLUME"]        = { Style="Knob", Color=Colors.DarkGrey, Fill=Colors.DarkGrey, Size={ 42, 42 }, Position={ 420, tuY }, IsInvisible=true }
  controls["MUTE"]          = { Style="Button", ButtonType="Toggle", Legend="Mute", UnlinkOffColor=true, OffColor=Colors.White, Color=Colors.Red, Position={ 470, tuY }, Size=btnSize, IsInvisible=true }
  controls["Model"]         = { Style="Text", IsReadOnly=true, Position={ 0, tuY + 50 }, Size={ 1, 1 }, IsInvisible=true }
  controls["IPAddress"]     = { Style="Text", IsReadOnly=true, Position={ 0, tuY + 50 }, Size={ 1, 1 }, IsInvisible=true }
  controls["Port"]          = { Style="Text", IsReadOnly=true, Position={ 0, tuY + 50 }, Size={ 1, 1 }, IsInvisible=true }
  controls["SYSTEM_STATUS"] = { Style="Text", IsReadOnly=true, Position={ 0, tuY + 50 }, Size={ 1, 1 }, IsInvisible=true }
  controls["CURRENT_SOURCE"]= { Style="Text", IsReadOnly=true, Position={ 0, tuY + 50 }, Size={ 1, 1 }, IsInvisible=true }
end
