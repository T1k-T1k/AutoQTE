local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- Карта клавиш
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
    ["T"] = Enum.KeyCode.T
}

-- Сохраняем тайминги
local timingData = {}

-- Логгер
local function log(msg)
    print(string.format("[QTE Auto] %.3f | %s", tick(), msg))
end

-- Получить KeyCode по тексту
local function getKeyCode(text)
    if not text then return nil end
    text = string.upper(string.gsub(text, "[^%w%s]", ""))
    return KeyMapping[text] or KeyMapping[string.sub(text, 1, 1)]
end

-- Нажать клавишу
local function pressKey(keyCode)
    if not keyCode then return end
    log("НАЖАТИЕ КЛАВИШИ: " .. tostring(keyCode))
    VirtualInputManager:SendKeyEvent(true, keyCode, false, nil)
    task.wait(0.02)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, nil)
end

-- Перехватываем RemoteFunction
local function hookRemoteFunction()
    local remoteFunction = ReplicatedStorage:WaitForChild("QuickTimeEvent")

    local success, originalCallback = pcall(function()
        return getcallbackvalue(remoteFunction, "OnClientInvoke")
    end)

    remoteFunction.OnClientInvoke = function(key, timing)
        if key and timing then
            timingData[key] = {
                idealTime = tick() + timing,
                timingOffset = timing
            }

            log(string.format("Пойман QTE: %s, идеальное время через %.3f сек", key, timing))

            local keyCode = getKeyCode(key)
            if keyCode then
                -- Нажимаем за 0.2 секунды до нужного тайминга
                local delay = math.max(0, timing + 0)
                task.delay(delay, function()
                    log(string.format("Нажатие за %.3f сек ДО идеального момента", 0.2))
                    pressKey(keyCode)
                end)
            end
        end

        if success and originalCallback then
            return originalCallback(key, timing)
        end
        return true
    end

    log("RemoteFunction перехвачен.")
end

-- Запуск
hookRemoteFunction()
log("Скрипт запущен и ждёт QTE...")
