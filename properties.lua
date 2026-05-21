table.insert(props, {
  Name  = "Default Brightness",
  Type  = "integer",
  Min   = 0,
  Max   = 255,
  Value = 128
})
table.insert(props, {
  Name    = "Debug Print",
  Type    = "enum",
  Choices = {"None", "Tx/Rx", "Tx", "Rx", "Function Calls", "All"},
  Value   = "None"
})
