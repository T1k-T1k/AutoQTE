-- Simple QTE Auto Script for Roblox
-- Automatically detects and presses QTE keys with timing

-- Services
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Local player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Key mapping
local KeyMapping = {
    ["E"] = Enum.KeyCode.E,
    ["Q"] = Enum.KeyCode.Q,
    ["W"] = Enum.KeyCode.W,
    ["A"] = Enum.KeyCode.A,
    ["S"] = Enum.KeyCode.S,
    ["D"] = Enum.KeyCode.D,
    ["X"] = Enum.KeyCode.X,
    ["Z"] = Enum.KeyCode.Z,
    ["C"] = Enum.KeyCode.C,
    ["F"] = Enum.KeyCode.F,
    ["R"] = Enum.KeyCode.R,
    ["T"] = Enum.KeyCode.T,
    ["SPACE"] = Enum.KeyCode.Space,
    [" "] = Enum.KeyCode.Space,
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five
}

-- Configurable delay (adjust this based on your game's QTE timing)
local PRESS_DELAY = 0.1 -- Delay in seconds before pressing the key

-- Logging function
local function log(message)
    print(string.format("[Simple QTE Auto][%.3f] %s", tick(), message))
end

-- Convert text to KeyCode
local function getKeyCode(keyText)
    if not keyText then
        log("Key text is nil")
        return nil
    end

    keyText = string.upper(string.gsub(keyText, "[^%w%s]", ""))
    local keyCode = KeyMapping[keyText] or KeyMapping[string.sub(keyText, 1, 1)]
    
    if not keyCode then
        log("Unknown key: " .. tostring(keyText))
        return nil
    end
    return keyCode
end

-- Simulate key press
local function pressKey(keyCode)
    if not keyCode then
        log("KeyCode is nil")
        return false
    end

    local success, errorMsg = pcall(function()
        log("Pressing key: " .. tostring(keyCode))
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    end)

    if success then
        log("Successfully pressed key: " .. tostring(keyCode))
        return true
    else
        log("Error pressing key: " .. tostring(errorMsg))
        return false
    end
end

-- Process QTE GUI
local function processQTEGui(qteGui)
    if not qteGui or not qteGui.Parent then
        log("Invalid QTE GUI")
        return
    end

    -- Find button or text label
    local button = qteGui:FindFirstChild("Button")
    if not button then
        for _, child in pairs(qteGui:GetDescendants()) do
            if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text and child.Text ~= "" then
                button = child
                break
            end
        end
    end

    if not button then
        log("No button or text label found in QTE GUI")
        return
    end

    local keyText = button.Text
    if not keyText or keyText == "" then
        log("Button text is empty")
        return
    end

    local keyCode = getKeyCode(keyText)
    if not keyCode then
        log("Failed to get KeyCode for: " .. tostring(keyText))
        return
    end

    log("Detected QTE key: " .. keyText)
    
    -- Schedule key press with delay
    coroutine.wrap(function()
        wait(PRESS_DELAY)
        if qteGui.Parent then -- Check if QTE GUI is still valid
            pressKey(keyCode)
        else
            log("QTE GUI disappeared before key press")
        end
    end)()
end

-- Monitor GUI for QTEs
local function monitorGUI()
    log("Starting QTE monitoring...")

    -- Handle new QTE GUI elements
    local function onQTEAdded(child)
        if child.Name == "QuickTimeEvent" then
            log("QTE GUI detected")
            wait(0.05) -- Brief delay to ensure GUI is fully loaded
            processQTEGui(child)
        end
    end

    -- Connect to ChildAdded event
    local connection = PlayerGui.ChildAdded:Connect(onQTEAdded)

    -- Check for existing QTE GUI
    local existingQTE = PlayerGui:FindFirstChild("QuickTimeEvent")
    if existingQTE then
        processQTEGui(existingQTE)
    end

    log("QTE monitoring active")
end

-- Start the script
monitorGUI()
print("[Simple QTE Auto] Script loaded and running!")
