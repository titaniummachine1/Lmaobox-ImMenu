--[[
    Immediate mode menu library for Lmaobox
    Author: github.com/lnx00
]]

-- Unload the module if it's already loaded fixes all posible bullshit that happens when immenu glitches out
-- put in your lua if imenu breakes alot
if package.loaded["ImMenu"] then
    package.loaded["ImMenu"] = nil
end

if UnloadLib ~= nil then UnloadLib() end

-- Import lnxLib
---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.94, "lnxLib version is too old, please update it!")

local Fonts, Notify = lnxLib.UI.Fonts, lnxLib.UI.Notify
local KeyHelper, Input, Timer = lnxLib.Utils.KeyHelper, lnxLib.Utils.Input, lnxLib.Utils.Timer

-- Annotation aliases
---@alias ImItemID string
---@alias ImPos { X : integer, Y : integer }
---@alias ImWindow { X : integer, Y : integer, W : integer, H : integer }
---@alias ImFrame { X : integer, Y : integer, W : integer, H : integer, A : integer }
---@alias ImColor table<integer, integer, integer, integer?>
---@alias ImStyle any

--[[ Globals ]]
---@enum ImAlign
ImAlign = { Vertical = 0, Horizontal = 1 }

---@class ImMenu
---@field public Cursor ImPos
---@field public ActiveItem ImItemID|nil
ImMenu = {
    Cursor = { X = 0, Y = 0 },
    ActiveItem = nil,
    ActivePopup = nil
}

--[[ Variables ]]
local screenWidth, screenHeight = draw.GetScreenSize()
local dragPos = { X = 0, Y = 0 }
local lastKey = { Key = 0, Time = 0 }
local inPopup = false

-- Input Helpers
MouseHelper = KeyHelper.new(MOUSE_LEFT)
EnterHelper = KeyHelper.new(KEY_ENTER)
LeftArrow = KeyHelper.new(KEY_LEFT)
RightArrow = KeyHelper.new(KEY_RIGHT)

---@type table<string, ImWindow>
Windows = {}

---@type function[]
LateDrawList = {}

---@type ImColor[]
Colors = {
    Title = { 55, 100, 215, 255 },
    Text = { 255, 255, 255, 255 },
    Window = { 30, 30, 30, 255 },
    Item = { 50, 50, 50, 255 },
    ItemHover = { 60, 60, 60, 255 },
    ItemActive = { 70, 70, 70, 255 },
    Highlight = { 180, 180, 180, 100 },
    HighlightActive = { 240, 240, 240, 140 },
    WindowBorder = { 55, 100, 215, 255 },
    FrameBorder = { 0, 0, 0, 200 },
    Border = { 0, 0, 0, 200 }
}

---@type ImStyle[]
Style = {
    Font = Fonts.Verdana,
    ItemPadding = 5,
    ItemMargin = 5,
    FramePadding = 5,
    ItemSize = nil,
    WindowBorder = true,
    FrameBorder = false,
    ButtonBorder = false,
    CheckboxBorder = false,
    SliderBorder = false,
    Border = false,
    Popup = false
}

-- Stacks
WindowStack = Stack.new()
FrameStack = Stack.new()
ColorStack = Stack.new()
StyleStack = Stack.new()

--[[ Private Functions ]]
---@param color ImColor
local function UnpackColor(color)
    return color[1], color[2], color[3], color[4] or 255
end

-- Returns a pressed key suitable for operations (function keys, arrows, etc.)
---@return integer?
function GetOperationKey()
    for i = KEY_F1, KEY_F12 do
        if input.IsButtonDown(i) then
            return i
        end
    end
    for _, key in ipairs({
        KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, 
        KEY_PAGEUP, KEY_PAGEDOWN, KEY_INSERT, KEY_DELETE, KEY_ESCAPE
    }) do
        if input.IsButtonDown(key) then
            return key
        end
    end
    return nil
end

---@return integer?
local function GetInput()
    local key = Input.GetPressedKey() or GetOperationKey()
    if not key then
        lastKey.Key = 0
        return nil
    end

    if key == lastKey.Key then
        if lastKey.Time + 0.5 < globals.RealTime() then
            return key
        else
            return nil
        end
    end

    lastKey.Key = key
    lastKey.Time = globals.RealTime()
    return key
end

--[[ Public Getters ]]

---@return number
function ImMenu.GetVersion() return 0.66 end

---@return ImStyle[]
function ImMenu.GetStyle() return table.readOnly(Style) end

---@return ImColor[]
function ImMenu.GetColors() return table.readOnly(Colors) end

---@return ImWindow
function ImMenu.GetCurrentWindow() return WindowStack:peek() end

---@return ImFrame
function ImMenu.GetCurrentFrame() return FrameStack:peek() end

--[[ Public Setters ]]
-- Push a color to the stack
---@param key string
---@param color ImColor
function ImMenu.PushColor(key, color)
    ColorStack:push({ Key = key, Value = Colors[key] })
    Colors[key] = color
end

-- Pop the last color from the stack
---@param amount? integer
function ImMenu.PopColor(amount)
    amount = amount or 1
    for _ = 1, amount do
        local color = ColorStack:pop()
        Colors[color.Key] = color.Value
    end
end

-- Push a style to the stack
---@param key string
---@param style ImStyle
function ImMenu.PushStyle(key, style)
    StyleStack:push({ Key = key, Value = Style[key] })
    Style[key] = style
end

-- Pop the last style from the stack
---@param amount? integer
function ImMenu.PopStyle(amount)
    amount = amount or 1
    for _ = 1, amount do
        local style = StyleStack:pop()
        Style[style.Key] = style.Value
    end
end

--[[ Public Functions ]]
-- Creates a new color attribute
---@param key string
---@param value any
function ImMenu.AddColor(key, value)
    Colors[key] = value
end

-- Creates a new style attribute
---@param key string
---@param value any
function ImMenu.AddStyle(key, value)
    Style[key] = value
end

-- Runs all late draw functions
function ImMenu.LateDraw()
    draw.Color(255, 255, 255, 255)

    -- Run all late draw functions
    for _, func in ipairs(LateDrawList) do
        func()
    end

    LateDrawList = {}
end

-- Updates the cursor and current frame size
---@param w integer
---@param h integer
function ImMenu.UpdateCursor(w, h)
    local frame = ImMenu.GetCurrentFrame()
    if frame then
        if frame.A == 0 then
            -- Horizontal
            ImMenu.Cursor.Y = ImMenu.Cursor.Y + h + Style.ItemMargin
            frame.W = math.max(frame.W, w)
            frame.H = math.max(frame.H, ImMenu.Cursor.Y - frame.Y)
        elseif frame.A == 1 then
            -- Vertical
            ImMenu.Cursor.X = ImMenu.Cursor.X + w + Style.ItemMargin
            frame.W = math.max(frame.W, ImMenu.Cursor.X - frame.X)
            frame.H = math.max(frame.H, h)
        end
    else
        -- TODO: It shouldn't be allowed to draw outside of a frame
        ImMenu.Cursor.Y = ImMenu.Cursor.Y + h + Style.ItemMargin
    end
end

-- Updates the next color depending on the interaction state
---@param hovered boolean
---@param active boolean
function ImMenu.InteractionColor(hovered, active)
    if active then
        draw.Color(UnpackColor(Colors.ItemActive))
    elseif hovered then
        draw.Color(UnpackColor(Colors.ItemHover))
    else
        draw.Color(UnpackColor(Colors.Item))
    end
end

---@param width integer
---@param height integer
---@return integer width, integer height
function ImMenu.GetSize(width, height)
    if Style.ItemSize ~= nil then
        width, height = Style.ItemSize[1], Style.ItemSize[2]
    end

    return width, height
end

-- Returns whether the element is clicked or active
---@param x number
---@param y number
---@param width number
---@param height number
---@param id string
---@return boolean hovered, boolean clicked, boolean active
function ImMenu.GetInteraction(x, y, width, height, id)
    -- Is a different element active?
    if ImMenu.ActiveItem ~= nil and ImMenu.ActiveItem ~= id then
        return false, false, false
    end

    -- Is a popup active?
    if ImMenu.ActivePopup ~= nil and not inPopup then
        return false, false, false
    end

    local hovered = Input.MouseInBounds(x, y, x + width, y + height) or id == ImMenu.ActiveItem
    local clicked = hovered and (MouseHelper:Pressed() or EnterHelper:Pressed())
    local active = hovered and (MouseHelper:Down() or EnterHelper:Down())

    -- Should this element be active?
    if active and ImMenu.ActiveItem == nil then
        ImMenu.ActiveItem = id
    end

    -- Is this element no longer active?
    if ImMenu.ActiveItem == id and not active then
        ImMenu.ActiveItem = nil
    end

    return hovered, clicked, active
end

---@param text string
function ImMenu.GetLabel(text)
    for label in text:gmatch("(.+)###(.+)") do
        return label
    end

    return text
end

---@param size? number
function ImMenu.Space(size)
    size = size or Style.ItemMargin
    ImMenu.UpdateCursor(size, size)
end

function ImMenu.Separator()
    local x, y = ImMenu.Cursor.X, ImMenu.Cursor.Y
    local currentWindow = ImMenu.GetCurrentWindow()
    local width = currentWindow.W - Style.FramePadding * 2
    local height = Style.ItemMargin * 2

    draw.Color(UnpackColor(Colors.WindowBorder))
    draw.Line(x, y + height // 2, x + width, y + height // 2)

    ImMenu.UpdateCursor(width, height)
end


-- Begins a new frame
---@param align? integer
function ImMenu.BeginFrame(align)
    align = align or 0

    FrameStack:push({ X = ImMenu.Cursor.X, Y = ImMenu.Cursor.Y, W = 0, H = 0, A = align })

    -- Apply padding
    ImMenu.Cursor.X = ImMenu.Cursor.X + Style.FramePadding
    ImMenu.Cursor.Y = ImMenu.Cursor.Y + Style.FramePadding
end

-- Ends the current frame
---@return ImFrame frame
function ImMenu.EndFrame()
    ---@type ImFrame
    local frame = FrameStack:pop()

    ImMenu.Cursor.X = frame.X
    ImMenu.Cursor.Y = frame.Y

    -- Apply padding
    if frame.A == 0 then
        -- Horizontal
        frame.W = frame.W + Style.FramePadding * 2
        frame.H = frame.H + Style.FramePadding - Style.ItemMargin
    elseif frame.A == 1 then
        -- Vertical
        frame.H = frame.H + Style.FramePadding * 2
        frame.W = frame.W + Style.FramePadding - Style.ItemMargin
    end

    -- Border
    if Style.FrameBorder then
        draw.Color(UnpackColor(Colors.FrameBorder))
        draw.OutlinedRect(frame.X, frame.Y, frame.X + frame.W, frame.Y + frame.H)
    end

    -- Update the cursor
    ImMenu.UpdateCursor(frame.W, frame.H)

    return frame
end

-- Load a bold font
local BoldFont = draw.CreateFont("Verdana Bold", 18, 800)

-- Begins a new window
---@param title string
---@param visible? boolean
---@return boolean visible
function ImMenu.Begin(title, visible)
    local isVisible = (visible == nil) or visible
    if not isVisible then return false end

    -- Create the window if it doesn't exist
    if not Windows[title] then
        Windows[title] = {
            X = 50,
            Y = 150,
            W = 100,
            H = 100
        }
    end

    -- Initialize the window
    local window = Windows[title]
    local titleText = ImMenu.GetLabel(title)
    local txtWidth, txtHeight = draw.GetTextSize(titleText)
    local titleHeight = txtHeight + Style.ItemPadding
    local hovered, clicked, active = ImMenu.GetInteraction(window.X, window.Y, window.W, titleHeight, title)

    -- Title bar
    draw.SetFont(BoldFont)
    draw.Color(table.unpack(Colors.Title))
    draw.OutlinedRect(window.X, window.Y, window.X + window.W, window.Y + window.H)
    draw.FilledRect(window.X, window.Y, window.X + window.W, window.Y + titleHeight)

    -- Title text with shadow and bold font
    local titleX = window.X + (window.W // 2) - (txtWidth // 2)
    local titleY = window.Y + (titleHeight // 2) - (txtHeight // 2)

    draw.TextShadow(titleX + 1, titleY + 1, titleText)  -- Draw shadow

    draw.Color(255, 255, 255, 255)  -- Dark text color
    draw.Text(titleX, titleY, titleText)

    -- Background
    draw.Color(table.unpack(Colors.Window))
    draw.FilledRect(window.X, window.Y + titleHeight, window.X + window.W, window.Y + window.H + titleHeight)

    -- Border
    if Style.WindowBorder then
        draw.Color(UnpackColor(Colors.WindowBorder))
        draw.OutlinedRect(window.X, window.Y, window.X + window.W, window.Y + window.H + titleHeight)
        draw.Line(window.X, window.Y + titleHeight, window.X + window.W, window.Y + titleHeight)
    end

    -- Mouse drag
    local mX, mY = table.unpack(input.GetMousePos())
    if clicked then
        window.DragPos = { X = mX - window.X, Y = mY - window.Y }
        window.IsDragging = true
    elseif not input.IsButtonDown(MOUSE_LEFT) and not clicked then
        window.IsDragging = false
    end

    if window.IsDragging then
        window.X = math.clamp(mX - window.DragPos.X, 0, screenWidth - window.W)
        window.Y = math.clamp(mY - window.DragPos.Y, 0, screenHeight - window.H - titleHeight)
    end

    -- Update the cursor
    ImMenu.Cursor.X = window.X
    ImMenu.Cursor.Y = window.Y + titleHeight

    ImMenu.BeginFrame()

    -- Store and push the window
    Windows[title] = window
    WindowStack:push(window)

    return true
end




-- Ends the current window
---@return ImWindow
function ImMenu.End()
    ---@type ImFrame
    local frame = ImMenu.EndFrame()
    local window = WindowStack:pop()

    -- Update the window size
    window.W = frame.W
    window.H = frame.H

    -- Draw late draw list
    ImMenu.LateDraw()

    return window
end

-- Runs the given function after the current window has been drawn
function ImMenu.DrawLate(func)
    table.insert(LateDrawList, func)
end

---@param x integer
---@param y integer
---@param func function
function ImMenu.Popup(x, y, func)
    ImMenu.DrawLate(function()
        inPopup = true

        -- Prepare cursor
        ImMenu.Cursor.X = x
        ImMenu.Cursor.Y = y

        -- Draw the popup | TODO: Add a popup frame background
        ImMenu.PushStyle("FramePadding", 0)
        ImMenu.PushStyle("ItemMargin", 0)
        ImMenu.BeginFrame()
        func()
        local frame = ImMenu.EndFrame()
        ImMenu.PopStyle(2)

        -- Close the popup if clicked outside of it
        if not Input.MouseInBounds(frame.X, frame.Y, frame.X + frame.W, frame.Y + frame.H) and MouseHelper:Pressed() then
            ImMenu.ActivePopup = nil
        end

        inPopup = false
    end)
end

-- Draw a label
---@param text string
function ImMenu.Text(text)
    local x, y = ImMenu.Cursor.X, ImMenu.Cursor.Y
    local label = ImMenu.GetLabel(text)
    local txtWidth, txtHeight = draw.GetTextSize(label)
    local width, height = ImMenu.GetSize(txtWidth, txtHeight)

    if type(Colors.Text) == "table" then
        draw.Color(math.floor(Colors.Text[1] or 0), math.floor(Colors.Text[2] or 0), math.floor(Colors.Text[3] or 0), math.floor(Colors.Text[4] or 255))
    end
    draw.Text(math.floor(x + (width - txtWidth) / 2), math.floor(y + (height - txtHeight) / 2), label)

    ImMenu.UpdateCursor(width, height)
end

---@param text string
---@param state boolean
---@return boolean state, boolean clicked
function ImMenu.Checkbox(text, state)
    local x, y = ImMenu.Cursor.X, ImMenu.Cursor.Y
    local label = ImMenu.GetLabel(text)
    local txtWidth, txtHeight = draw.GetTextSize(label)
    local boxSize = txtHeight + Style.ItemPadding * 2
    local width, height = ImMenu.GetSize(boxSize + Style.ItemMargin + txtWidth, boxSize)
    local hovered, clicked, active = ImMenu.GetInteraction(x, y, width, height, text)

    -- Box
    ImMenu.InteractionColor(hovered, active)
    draw.FilledRect(math.floor(x), math.floor(y), math.floor(x + boxSize), math.floor(y + boxSize))

    -- Border
    if Style.CheckboxBorder and type(Colors.Border) == "table" then
        draw.Color(math.floor(Colors.Border[1] or 0), math.floor(Colors.Border[2] or 0), math.floor(Colors.Border[3] or 0), math.floor(Colors.Border[4] or 255))
        draw.OutlinedRect(math.floor(x), math.floor(y), math.floor(x + boxSize), math.floor(y + boxSize))
    end

    -- Check
    if state then
        if type(Colors.Highlight) == "table" then
            draw.Color(math.floor(Colors.Highlight[1] or 0), math.floor(Colors.Highlight[2] or 0), math.floor(Colors.Highlight[3] or 0), math.floor(Colors.Highlight[4] or 255))
        end
        draw.FilledRect(math.floor(x + Style.ItemPadding), math.floor(y + Style.ItemPadding), math.floor(x + boxSize - Style.ItemPadding), math.floor(y + boxSize - Style.ItemPadding))
    end

    -- Text
    if type(Colors.Text) == "table" then
        draw.Color(math.floor(Colors.Text[1] or 0), math.floor(Colors.Text[2] or 0), math.floor(Colors.Text[3] or 0), math.floor(Colors.Text[4] or 255))
    end
    draw.Text(math.floor(x + boxSize + Style.ItemMargin), math.floor(y + (height - txtHeight) / 2), label)

    -- Update State
    if clicked then
        state = not state
    end

    ImMenu.UpdateCursor(width, height)
    return state, clicked
end

-- Draws a button
---@param text string
---@return boolean clicked, boolean active
function ImMenu.Button(text)
    local x, y = ImMenu.Cursor.X, ImMenu.Cursor.Y
    local label = ImMenu.GetLabel(text)
    local txtWidth, txtHeight = draw.GetTextSize(label)
    local width, height = ImMenu.GetSize(txtWidth + Style.ItemPadding * 2, txtHeight + Style.ItemPadding * 2)
    local hovered, clicked, active = ImMenu.GetInteraction(x, y, width, height, text)

    -- Background
    ImMenu.InteractionColor(hovered, active)
    draw.FilledRect(math.floor(x), math.floor(y), math.floor(x + width), math.floor(y + height))

    if Style.ButtonBorder and type(Colors.Border) == "table" then
        draw.Color(math.floor(Colors.Border[1] or 0), math.floor(Colors.Border[2] or 0), math.floor(Colors.Border[3] or 0), math.floor(Colors.Border[4] or 255))
        draw.OutlinedRect(math.floor(x), math.floor(y), math.floor(x + width), math.floor(y + height))
    end

    -- Text
    if type(Colors.Text) == "table" then
        draw.Color(math.floor(Colors.Text[1] or 0), math.floor(Colors.Text[2] or 0), math.floor(Colors.Text[3] or 0), math.floor(Colors.Text[4] or 255))
    end
    draw.Text(math.floor(x + (width - txtWidth) / 2), math.floor(y + (height - txtHeight) / 2), label)

    if clicked then
        ImMenu.ActiveItem = nil
    end

    ImMenu.UpdateCursor(width, height)
    return clicked, active
end


---@param id Texture
function ImMenu.Texture(id)
    local x, y = ImMenu.Cursor.X, ImMenu.Cursor.Y
    local width, height = ImMenu.GetSize(draw.GetTextureSize(id))

    draw.Color(255, 255, 255, 255)
    draw.TexturedRect(id, x, y, x + width, y + height)

    if Style.Border then
        draw.Color(UnpackColor(Colors.Border))
        draw.OutlinedRect(x, y, x + width, y + height)
    end

    ImMenu.UpdateCursor(width, height)
end

-- Draws a slider that changes a value with fancy visual effects and text shadow
---@param text string
---@param value number
---@param min number
---@param max number
---@param step? number
---@return number value, boolean clicked
function ImMenu.Slider(text, value, min, max, step)
    step = step or 1
    local x, y = ImMenu.Cursor.X, ImMenu.Cursor.Y
    local label = string.format("%s: %s", ImMenu.GetLabel(text), value)
    local txtWidth, txtHeight = draw.GetTextSize(label)
    local width, height = ImMenu.GetSize(250, txtHeight + Style.ItemPadding * 2)
    local sliderWidth = math.floor(width * (value - min) / (max - min))
    local hovered, clicked, active = ImMenu.GetInteraction(x, y, width, height, text)

    -- Ensure sliderWidth is within bounds
    sliderWidth = math.max(0, math.min(sliderWidth, width))

    -- Background
    ImMenu.InteractionColor(hovered, active)
    draw.FilledRect(x, y, x + width, y + height)

    -- Slider
    draw.Color(UnpackColor(Colors.Highlight))
    draw.FilledRect(x, y, x + sliderWidth, y + height)

    -- Border
    if Style.SliderBorder then
        draw.Color(UnpackColor(Colors.Border))
        draw.OutlinedRect(x, y, x + width, y + height)
    end

    -- Add a glow effect at the end of the slider
    if sliderWidth > 1 then
        draw.Color(255, 255, 255, 150)
        draw.FilledRect(x + sliderWidth - 2, y - 2, x + sliderWidth + 2, y + height + 2)
    end


    -- Text with shadow
    draw.Color(0, 0, 0, 150)  -- Shadow color
    draw.TextShadow(x + (width // 2) - (txtWidth // 2) + 1, y + (height // 2) - (txtHeight // 2) + 1, label)  -- Draw shadow

    -- Higher contrast text color
    draw.Color(255, 255, 255, 255)  -- White color for the text
    draw.Text(x + (width // 2) - (txtWidth // 2), y + (height // 2) - (txtHeight // 2), label)


    -- Update Value
    if active then
        -- Mouse drag
        local mX, mY = table.unpack(input.GetMousePos())
        local percent = math.clamp((mX - x) / width, 0, 1)
        value = math.round((min + (max - min) * percent) / step) * step
    elseif hovered then
        -- Arrow keys
        if LeftArrow:Pressed() then
            value = math.max(value - step, min)
        elseif RightArrow:Pressed() then
            value = math.min(value + step, max)
        end
    end

    ImMenu.UpdateCursor(width, height)
    return value, clicked
end










-- Quadratic easing function for interpolation
local function easeInOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

-- Unpack a color from table
local function UnpackColor(color)
    return math.floor(color[1]), math.floor(color[2]), math.floor(color[3]), math.floor(color[4] or 255)
end

-- Draws a progress bar with fancy visual effects
---@param value number
---@param min number
---@param max number
---@param interpolate boolean optional
function ImMenu.Progress(value, min, max, interpolate)
    interpolate = interpolate or false

    local x, y = math.floor(ImMenu.Cursor.X or 0), math.floor(ImMenu.Cursor.Y or 0)
    local width, height = ImMenu.GetSize(250, 15)

    -- Ensure width and height are integers and not nil
    width = math.floor(width or 250)
    height = math.floor(height or 15)

    -- Ensure progress value is within bounds
    value = math.max(min, math.min(max, value))
    local targetProgressWidth = math.floor(width * (value - min) / (max - min))

    -- Initialize progress tracking if needed
    if not ImMenu.ProgressState then
        ImMenu.ProgressState = {
            currentWidth = targetProgressWidth,
            lastTargetWidth = targetProgressWidth,
            lastTick = globals.TickCount()
        }
    end

    -- Interpolation logic
    if interpolate then
        local currentTick = globals.TickCount()
        local elapsedTicks = currentTick - ImMenu.ProgressState.lastTick

        -- Adjust speed based on the distance from the target
        local distance = math.abs(targetProgressWidth - ImMenu.ProgressState.currentWidth)
        local speed = math.max(0.5, distance / 10) -- Adjust the divisor for speed control

        -- Smooth interpolation to the target value
        ImMenu.ProgressState.currentWidth = ImMenu.ProgressState.currentWidth + (targetProgressWidth - ImMenu.ProgressState.currentWidth) * easeInOutQuad(math.min(elapsedTicks / 10, 1))

        -- Update last target width and last tick for continuous interpolation
        ImMenu.ProgressState.lastTargetWidth = targetProgressWidth
        ImMenu.ProgressState.lastTick = currentTick
    else
        ImMenu.ProgressState.currentWidth = targetProgressWidth
    end

    local progressWidth = math.floor(ImMenu.ProgressState.currentWidth)

    -- Ensure progressWidth is within bounds
    progressWidth = math.max(0, math.min(progressWidth, width))

    -- Background
    draw.Color(UnpackColor(Colors.Item))
    draw.FilledRect(x, y, x + width, y + height)

    -- Progress
    draw.Color(0, 255, 0, 255)  -- Solid green color
    draw.FilledRect(x, y, x + progressWidth, y + height)

    -- Border
    if Style.Border then
        draw.Color(UnpackColor(Colors.Border))
        draw.OutlinedRect(x, y, x + width, y + height)
    end

    -- Add a thinner glow effect at the end of the progress bar
    if progressWidth > 0 then
        draw.Color(255, 255, 255, 150)
        draw.FilledRect(x + progressWidth - 1, y - 1, x + progressWidth + 1, y + height + 1)
    end

    ImMenu.UpdateCursor(width, height)
end



---@param label string
---@param text string
---@param charLimit? integer
---@return string text
function ImMenu.TextInput(label, text, charLimit)
    charLimit = charLimit or 50  -- Set default character limit to 50

    -- Initialize static variables for cursor and writing mode
    if not ImMenu.TextInputState then
        ImMenu.TextInputState = {
            cursorPos = #text,
            blinkTimer = globals.RealTime(),
            isWriting = false
        }
    end

    local state = ImMenu.TextInputState
    local x, y = ImMenu.Cursor.X, ImMenu.Cursor.Y
    local txtWidth, txtHeight = draw.GetTextSize(text)
    local defaultWidth, defaultHeight = 250, txtHeight + Style.ItemPadding * 2
    local width = math.max(defaultWidth, txtWidth + Style.ItemPadding * 2)
    local height = defaultHeight
    local txtY = y + (height // 2) - (txtHeight // 2)
    local hovered, clicked, active = ImMenu.GetInteraction(x, y, width, height, label)

    -- Toggle writing mode
    if clicked then
        state.isWriting = not state.isWriting
    elseif MouseHelper:Pressed() and not hovered and state.isWriting then
        state.isWriting = false
    end

    -- Adjust the width dynamically based on text size
    txtWidth, txtHeight = draw.GetTextSize(text)
    width = math.max(defaultWidth, txtWidth + Style.ItemPadding * 2)

    -- Background
    ImMenu.InteractionColor(hovered, state.isWriting)
    draw.FilledRect(x, y, x + width, y + height)

    -- Border
    draw.Color(UnpackColor(Colors.Border))
    draw.OutlinedRect(x, y, x + width, y + height)

    -- Text rendering
    draw.Color(UnpackColor(Colors.Text))
    local displayText = text
    local cursorX = x + Style.ItemPadding + draw.GetTextSize(text:sub(1, state.cursorPos))
    draw.Text(x + Style.ItemPadding, txtY, displayText)

    -- Simple blinking cursor
    if state.isWriting then
        local blinkPeriod = 1.0
        local shouldShowCursor = (globals.RealTime() - state.blinkTimer) % blinkPeriod < blinkPeriod / 2
        if shouldShowCursor then
            draw.Color(UnpackColor(Colors.Highlight))
            draw.FilledRect(cursorX, txtY, cursorX + 2, txtY + txtHeight)
        end
    end

    -- Text Input
    if state.isWriting then
        local key = GetInput()
        if key then
            if key == KEY_BACKSPACE then
                if state.cursorPos > 0 then
                    text = text:sub(1, state.cursorPos - 1) .. text:sub(state.cursorPos + 1)
                    state.cursorPos = math.max(0, state.cursorPos - 1)
                end
            elseif key == KEY_LEFT then
                state.cursorPos = math.max(0, state.cursorPos - 1)
            elseif key == KEY_RIGHT then
                state.cursorPos = math.min(#text, state.cursorPos + 1)
            elseif key == KEY_DELETE then
                if state.cursorPos < #text then
                    text = text:sub(1, state.cursorPos) .. text:sub(state.cursorPos + 2)
                end
            elseif key == KEY_HOME then
                state.cursorPos = 0
            elseif key == KEY_END then
                state.cursorPos = #text
            elseif key == KEY_SPACE then
                if #text < charLimit then
                    text = text:sub(1, state.cursorPos) .. " " .. text:sub(state.cursorPos + 1)
                    state.cursorPos = state.cursorPos + 1
                end
            elseif key == KEY_TAB then
                if #text < charLimit then
                    text = text:sub(1, state.cursorPos) .. "\t" .. text:sub(state.cursorPos + 1)
                    state.cursorPos = state.cursorPos + 1
                end
            else
                local char = Input.KeyToChar(key)
                if char and #text < charLimit then
                    if input.IsButtonDown(KEY_LSHIFT) then
                        char = char:upper()
                    else
                        char = char:lower()
                    end
                    text = text:sub(1, state.cursorPos) .. char .. text:sub(state.cursorPos + 1)
                    state.cursorPos = state.cursorPos + 1
                end
            end
            state.blinkTimer = globals.RealTime()  -- Reset blink timer on input
        end
    end

    -- Adjust cursor for the next item
    ImMenu.UpdateCursor(width, height)
    return text
end


---@param selected integer
---@param options any[]
---@return integer selected
function ImMenu.Option(selected, options)
    -- Check if the inputs are of the correct type
    if type(selected) ~= "number" then
        error("Expected a number for 'selected', got " .. type(selected))
    end
    if type(options) ~= "table" then
        error("Expected a table for 'options', got " .. type(options))
    end

    -- Handle empty options
    if #options == 0 then
        error("Options table is empty")
    end

    local txtWidth, txtHeight = draw.GetTextSize("#")
    local btnSize = txtHeight + 2 * Style.ItemPadding
    local width, height = ImMenu.GetSize(250, txtHeight)

    -- Begin frame for the option control
    ImMenu.PushStyle("ItemSize", { btnSize, btnSize })
    ImMenu.PushStyle("FramePadding", 0)
    ImMenu.BeginFrame(ImAlign.Horizontal)

    -- Last Item button
    if ImMenu.Button("<###prev") then
        selected = ((selected - 2) % #options) + 1
        print("Selected previous option:", selected)
    end

    -- Current Item display
    ImMenu.PushStyle("ItemSize", { width - (2 * btnSize) - (2 * Style.ItemMargin), btnSize })
    if options[selected] then
        ImMenu.Text(tostring(options[selected]))
    else
        ImMenu.Text("Invalid selection")
    end
    ImMenu.PopStyle()

    -- Next Item button
    if ImMenu.Button(">###next") then
        selected = (selected % #options) + 1
        print("Selected next option:", selected)
    end

    -- End frame and pop styles
    ImMenu.EndFrame()
    ImMenu.PopStyle(2)

    return selected
end


---@param text string
---@param items string[]
function ImMenu.List(text, items)
    local txtWidth, txtHeight = draw.GetTextSize(text)
    local width, height = ImMenu.GetSize(250, txtHeight + Style.ItemPadding * 2)

    ImMenu.PushStyle("FramePadding", 0)
    ImMenu.PushStyle("ItemSize", { width, height })
    ImMenu.BeginFrame()

    -- Title
    ImMenu.Text(text)

    -- Items
    for _, item in ipairs(items) do
        ImMenu.Button(tostring(item))
    end

    ImMenu.EndFrame()
    ImMenu.PopStyle(2)
end

---@param text string
---@param selected integer
---@param options string[]
function ImMenu.Combo(text, selected, options)
    local txtWidth, txtHeight = draw.GetTextSize(text)
    local width, height = ImMenu.GetSize(250, txtHeight + Style.ItemPadding * 2)

    -- Dropdown button
    ImMenu.PushStyle("ItemSize", { width, height })
    if ImMenu.Button(text) then
        ImMenu.ActivePopup = text
    end

    -- Dropdown popup
    if ImMenu.ActivePopup == text then
        ImMenu.Popup(ImMenu.Cursor.X, ImMenu.Cursor.Y, function()
            ImMenu.PushStyle("ItemSize", { width, height })

            for i, option in ipairs(options) do
                if ImMenu.Button(tostring(option)) then
                    selected = i
                    ImMenu.ActivePopup = nil
                end
            end

            ImMenu.PopStyle(1)
        end)
    end

    ImMenu.PopStyle()

    return selected
end

---@param tabs string[]
---@param currentTab integer
---@return integer currentTab
function ImMenu.TabControl(tabs, currentTab)
    ImMenu.PushStyle("FramePadding", 0)
    ImMenu.PushStyle("ItemSize", { 100, 25 })
    ImMenu.PushStyle("Spacing", 0)
    ImMenu.BeginFrame(1)

    -- Items
    for i, item in ipairs(tabs) do
        if ImMenu.Button(tostring(item)) then
            currentTab = i
        end
    end

    ImMenu.EndFrame()
    ImMenu.PopStyle(3)

    return currentTab
end

lnxLib.UI.Notify.Simple("ImMenu loaded", string.format("Version: %.2f", ImMenu.GetVersion()))

return ImMenu