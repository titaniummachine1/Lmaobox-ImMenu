
-- Unload the module if it's already loaded
if package.loaded["ImMenu"] then
    package.loaded["ImMenu"] = nil
end

if UnloadLib ~= nil then UnloadLib() end

local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")

-- Store the state of each element in a table
local menuState = {
    enableAdvancedFeatures = false,
    sliderValue = 50,
    inputText = "Enter text",
    selectedOption = 1,
    comboSelection = 1,
    currentTab = 1,
    colorSelection = {255, 0, 0, 255},
    buttonClickCount = 0,
    showExtraWindow = false,
    showPopupContent = false,
    animationProgress = 0,
    pulsateTextColor = {255, 255, 255, 255},
    rainbowText = false,
    rainbowColor = {255, 0, 0, 255}
}

-- Function to load a custom font
local function loadCustomFont()
    menuState.customFont = draw.CreateFont("Verdana", 16, 800)
end
loadCustomFont()

-- Function to handle basic elements
local function basicElements()
    ImMenu.Text("Basic Elements:")
    if ImMenu.Button("Click Counter") then
        menuState.buttonClickCount = menuState.buttonClickCount + 1
        print("Button clicked! Total clicks: " .. menuState.buttonClickCount)
    end
    ImMenu.Text("Button click count: " .. menuState.buttonClickCount)
    ImMenu.Space(10)

    ImMenu.Text("Sliders and Progress:")
    menuState.sliderValue = ImMenu.Slider("Adjust Value", menuState.sliderValue, 0, 100)
    ImMenu.Progress(menuState.sliderValue, 0, 100, true, 0.5)
    ImMenu.Space(10)

    menuState.inputText = ImMenu.TextInput("Input", menuState.inputText)
    ImMenu.Text("You entered: " .. menuState.inputText)
    ImMenu.Space(10)
end


-- Function to handle nested frames and toggles
local function nestedFramesAndToggles()
    ImMenu.Text("Nested Frames:")
    ImMenu.BeginFrame()
    ImMenu.Text("Frame 1")
    ImMenu.BeginFrame()
    ImMenu.Text("Nested Frame")
    if ImMenu.Button(menuState.showPopupContent and "Hide Content" or "Show Content") then
        menuState.showPopupContent = not menuState.showPopupContent
    end
    if menuState.showPopupContent then
        ImMenu.Text("This is toggle-able content!")
        ImMenu.Text("Slider value: " .. menuState.sliderValue)
    end
    ImMenu.EndFrame()
    ImMenu.EndFrame()
    ImMenu.Space(10)
end

-- Function to handle advanced elements
local function advancedElements()
    local options = {"Red", "Green", "Blue"}
    menuState.selectedOption = ImMenu.Option(menuState.selectedOption, options)
    menuState.comboSelection = ImMenu.Combo("Choose Color", menuState.comboSelection, options)
    

    local selectedColor = options[menuState.selectedOption]
    ImMenu.Text("Selected color: " .. selectedColor)

    -- Change color based on selection
    if selectedColor == "Red" then
        ImMenu.PushColor("Text", {255, 0, 0, 255})
    elseif selectedColor == "Green" then
        ImMenu.PushColor("Text", {0, 255, 0, 255})
    elseif selectedColor == "Blue" then
        ImMenu.PushColor("Text", {0, 0, 255, 255})
    end
    ImMenu.Text("This text changes color!")
    ImMenu.PopColor()

    ImMenu.Space(10)

    nestedFramesAndToggles()

    ImMenu.List("Dynamic List", {
        "Item " .. menuState.sliderValue,
        menuState.inputText,
        "Clicks: " .. menuState.buttonClickCount
    })
    ImMenu.Space(10)
end

-- Function to handle color adjustment elements
local function colorAdjustment()
    ImMenu.Text("Color Adjustment:")
    menuState.colorSelection[1] = ImMenu.Slider("Red", menuState.colorSelection[1], 0, 255)
    menuState.colorSelection[2] = ImMenu.Slider("Green", menuState.colorSelection[2], 0, 255)
    menuState.colorSelection[3] = ImMenu.Slider("Blue", menuState.colorSelection[3], 0, 255)
    menuState.colorSelection[4] = ImMenu.Slider("Alpha", menuState.colorSelection[4], 0, 255)
    
    ImMenu.PushColor("Text", menuState.colorSelection)
    ImMenu.Text("Custom colored text!")
    ImMenu.PopColor()
    ImMenu.Space(10)
end

-- Function to handle animations and effects
local function animationsAndEffects()
    ImMenu.Text("Animations and Effects:")
    
    -- Animated progress bar
    menuState.animationProgress = (menuState.animationProgress + 0.5) % 100
    ImMenu.Progress(menuState.animationProgress, 0, 100)
    
    -- Pulsating text
    local pulseFactor = (math.sin(globals.RealTime() * 5) + 1) / 2
    menuState.pulsateTextColor = {
        255 * pulseFactor,
        0,
        255 * (1 - pulseFactor),
        255
    }
    ImMenu.PushColor("Text", menuState.pulsateTextColor)
    ImMenu.Text("Pulsating Text")
    ImMenu.PopColor()

    -- Rainbow text effect
    menuState.rainbowText = ImMenu.Checkbox("Enable Rainbow Text", menuState.rainbowText)

    if menuState.rainbowText then
        local time = globals.RealTime() * 2
        menuState.rainbowColor = {
            math.floor(math.sin(time) * 127 + 128),
            math.floor(math.sin(time + 2) * 127 + 128),
            math.floor(math.sin(time + 4) * 127 + 128),
            255
        }
        ImMenu.PushColor("Text", menuState.rainbowColor)
        ImMenu.Text("Rainbow Text")
        ImMenu.PopColor()
    end

    -- Custom font
    ImMenu.Text("Custom Text")

    ImMenu.Space(10)
end

-- Function to test all elements
local function testAllElements()
    if ImMenu.Begin("ImMenu Interactive Test Suite") then
        ImMenu.Text("Welcome to the ImMenu Test Suite!")
        ImMenu.Separator()

        local tabs = {"Basic", "Advanced", "Color", "Animations"}
        menuState.currentTab = ImMenu.TabControl(tabs, menuState.currentTab)
        
        if menuState.currentTab == 1 then
            basicElements()
        elseif menuState.currentTab == 2 and menuState.enableAdvancedFeatures then
            advancedElements()
        elseif menuState.currentTab == 2 and not menuState.enableAdvancedFeatures then
            ImMenu.Text("Enable Advanced Features to see this tab!")
            if ImMenu.Button("Click to enable") then
                menuState.enableAdvancedFeatures = not menuState.enableAdvancedFeatures
            end
        elseif menuState.currentTab == 3 then
            colorAdjustment()
        elseif menuState.currentTab == 4 then
            animationsAndEffects()
        end

        if ImMenu.Button("Toggle Extra Window") then
            menuState.showExtraWindow = not menuState.showExtraWindow
        end

        ImMenu.End()
    end

    if menuState.showExtraWindow then
        if ImMenu.Begin("Extra Window") then
            ImMenu.Text("This is an extra window!")
            ImMenu.Text("Slider value: " .. menuState.sliderValue)
            ImMenu.Text("Input text: " .. menuState.inputText)
            ImMenu.End()
        end
    end
end

-- Function to change menu colors dynamically
local function changeMenuColors()
    local time = globals.RealTime() * 0.5
    local r = math.floor(math.sin(time) * 127 + 128)
    local g = math.floor(math.sin(time + 2) * 127 + 128)
    local b = math.floor(math.sin(time + 4) * 127 + 128)
    
    ImMenu.PushColor("Title", {r, g, b, 255})
    ImMenu.PushColor("WindowBorder", {r, g, b, 255})
end

-- Function to handle drawing
local function doDraw()
    changeMenuColors()
    testAllElements()

    ImMenu.PopColor(2)

    if ImMenu.Begin("Stats Window") then
        ImMenu.Text(string.format("FPS: %.1f", 1 / globals.FrameTime()))
        ImMenu.Text(string.format("Time: %.1f", globals.RealTime()))
        ImMenu.End()
    end
end

callbacks.Unregister("Draw", "ImMenu_TestSuite")
callbacks.Register("Draw", "ImMenu_TestSuite", doDraw)

client.ChatPrintf("\x01[\x03ImMenu Interactive Test Suite\x01] Loaded successfully!")
