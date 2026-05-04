# q-sys-plugin-novastar

Q-SYS plugin for NovaStar video wall controllers and TU series meeting boards.

Originally by [Joel Wetzell](https://github.com/jwetzell/q-sys-plugin-novastar).

## Supported Models

| Model | Protocol Port | Type |
|---|---|---|
| VX4S, VX4S_N | 5200 | LED sending card |
| VX6S | 5200 | LED sending card |
| VX1000 | 5200 | LED sending card |
| PROHD | 5200 | LED sending card |
| PROUHDJR | 5200 | LED sending card |
| MCTRL4K | 5200 | LED sending card |
| TU | 5201 | Android meeting board |

## Building

**Prerequisites:** VS Code with the PluginCompile toolchain installed at `..\..\plugincompile\` relative to this project.

1. Open this folder in VS Code.
2. Press **Ctrl+Shift+B**.
3. Select a version increment: `ver_dev` (patch dev), `ver_fix` (patch), `ver_min` (minor), `ver_maj` (major), or `ver_none` (no change).
4. The compiled plugin is output to `content/novastar.qplug`.

**Never edit `plugin.lua` or `content/novastar.qplug` directly.** Edit the source `.lua` files; `plugin.lua` is a generated concatenation.

## Controls Reference

| Control | Type | Direction | Description |
|---|---|---|---|
| `IPAddress` | Text | In/Out | Device IP address |
| `Model` | ComboBox | In/Out | Controller model |
| `Port` | Text | Out | TCP port (auto-set) |
| `Status` | Indicator | Out | Connection status |
| `Brightness` | Knob 0–255 | In/Out | LED brightness (all models) |
| `IN1`–`IN0` | Button | In | Video input selection (VX/ProHD/MCTRL4K) |
| `PRESET1`–`PRESET10` | Button | In | Preset recall (VX/ProHD) |
| `TEST_RED` … `TEST_AGING` | Button | In | Test patterns (VX/ProHD) |
| `Normal`, `Freeze`, `Black` | Button | In | Display mode (VX/ProHD) |
| `INPUT_ANDROID` | Button | In | Android source (TU) |
| `INPUT_HDMI1/2/3` | Button | In | HDMI source selection (TU) |
| `SCREEN_ON`, `SCREEN_OFF` | Button | In | Screen power (TU) |
| `STANDBY`, `WAKE` | Button | In | Standby control (TU) |
| `VOLUME` | Knob 0–100 | In/Out | System volume (TU) |
| `MUTE` | Toggle | In/Out | Audio mute (TU) |
| `CURRENT_SOURCE` | Text | Out | Active source readback (TU) |
| `SYSTEM_STATUS` | Text | Out | Standby / Normal display (TU) |

## Debug Logging

Set the **Debug Print** property (visible when `plugin_show_debug` is enabled in Q-SYS):

| Value | Output |
|---|---|
| None | Silent |
| Tx | Outgoing packets |
| Rx | Incoming packets |
| Function Calls | Function entry traces |
| Tx/Rx | Both directions |
| All | Everything |
