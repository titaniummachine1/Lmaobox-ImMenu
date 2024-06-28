# ImMenu for Lmaobox

![image](https://github.com/titaniummachine1/Lmaobox-ImMenu/assets/78664175/fecf054e-625d-4a76-a0ba-bd2802881c51)


ImMenu is an immediate mode menu library for Lmaobox. The syntax is similar to ImGui and is very easy to use. You can easily customize menu styles and colors using the style stack.

ImMenu requires [lnxLib](https://github.com/lnx00/Lmaobox-Library).

## Installation

1. Make sure [lnxLib](https://github.com/lnx00/Lmaobox-Library) is installed.
2. Download the latest release.
3. Extract `ImMenu.lua` to your `%localappdata%` folder.

## Components

- Text
- Button
- Checkbox
- Slider
- Progress Bar
- Text Input
- Option Selector
- List
- Combo Box
- Tab Control

## Example Usage

```lua
local ImMenu = require("ImMenu")

local menuState = {
    enableAdvancedFeatures = false,
    sliderValue = 50,
    inputText = "Enter text",
    selectedOption = 1,
    comboSelection = 1,
    currentTab = 1,
}

callbacks.Register("Draw", "ImMenuExample", function()
    if ImMenu.Begin("Example Menu") then
        ImMenu.Text("Basic Elements:")
        menuState.enableAdvancedFeatures = ImMenu.Checkbox("Enable Advanced Features", menuState.enableAdvancedFeatures)

        ImMenu.Text("Slider:")
        menuState.sliderValue = ImMenu.Slider("Adjust Value", menuState.sliderValue, 0, 100)

        ImMenu.Text("Text Input:")
        menuState.inputText = ImMenu.TextInput("Input", menuState.inputText)

        local options = {"Option 1", "Option 2", "Option 3"}
        menuState.selectedOption = ImMenu.Option(menuState.selectedOption, options)

        local tabs = {"Tab 1", "Tab 2", "Tab 3"}
        menuState.currentTab = ImMenu.TabControl(tabs, menuState.currentTab)

        ImMenu.End()
    end
end)

client.ChatPrintf("\x01[\x03ImMenu Example\x01] Loaded successfully!")
