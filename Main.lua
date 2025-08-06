-- QuickTimeEvent Auto Script (VirtualInputManager версия)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

-- Переменные для отслеживания
local isMonitoring = false
local currentConnection = nil
local qteStartTimes = {} -- Время начала QTE
local processedButtons = {} -- Чтобы избежать дубликатов

-- Функция для перехвата RemoteFunction и анализа тайминга
local function hookRemoteFunction()
    local Event = ReplicatedStorage:WaitForChild("QuickTimeEvent", 10)
    
    if not Event or not Event:IsA("RemoteFunction") then
        warn("[QTE Auto] QuickTimeEvent RemoteFunction не найдена")
        return false
    end
    
    -- Перехватываем вызовы для анализа тайминга
    local originalCallback = getcallbackvalue(Event, "OnClientInvoke")
    
    if not originalCallback then
        warn("[QTE Auto] Не удалось получить оригинальный callback")
        return false
    end
    
    -- Хукаем только для мониторинга тайминга, НЕ заменяем функцию
    local hookedCallback = function(...)
        local args = {...}
        local key = args[1]
        local timing = args[2]
        
        print("[QTE Hook] Игра отправила:")
        print("  Клавиша:", key)  
        print("  Требуемый тайминг:", timing)
        print("  Время события:", tick())
        
        -- Сохраняем информацию о тайминге для анализа
        if key and timing then
            qteStartTimes[key] = {
                requiredTiming = timing,
                eventTime = tick(),
                processed = false
            }
        end
        
        -- Вызываем оригинальную функцию
        return originalCallback(...)
    end
    
    -- Мониторим сетевые вызовы (не заменяем основную функцию)
    local mt = getrawmetatable(Event)
    local oldNewIndex = mt.__newindex
    
    setrawmetatable(Event, setmetatable({}, {
        __index = mt,
        __newindex = function(self, key, value)
            if key == "OnClientInvoke" and value ~= hookedCallback then
                print("[QTE Hook] Обнаружен новый callback, обновляем hook...")
                -- Обновляем наш hook
                originalCallback = value
            end
            return oldNewIndex(self, key, value)
        end
    }))
    
    print("[QTE Auto] RemoteFunction hook установлен для мониторинга")
    return true
end

-- Функция для получения текста кнопки
local function getButtonText(button)
    if not button or not button:IsA("GuiObject") then
        return nil
    end
    
    -- Проверяем все возможные места хранения текста
    local textSources = {
        button.Text,
        button:FindFirstChild("TextLabel") and button.TextLabel.Text,
        button:FindFirstChild("Text") and button.Text.Text
    }
    
    for _, text in ipairs(textSources) do
        if text and text ~= "" and string.len(text) == 1 then
            return string.upper(text)
        end
    end
    
    -- Ищем в дочерних элементах
    for _, child in ipairs(button:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            local text = child.Text
            if text and text ~= "" and string.len(text) == 1 then
                return string.upper(text)
            end
        end
    end
    
    return nil
end

-- Функция для нажатия клавиши через VirtualInputManager
local function pressKey(key, delay)
    spawn(function()
        if delay and delay > 0 then
            wait(delay)
        end
        
        print("[QTE Auto] 🎯 Нажимаем клавишу:", key, "через", delay or 0, "секунд")
        
        -- Конвертируем клавишу в KeyCode
        local keyCode = Enum.KeyCode[key]
        if not keyCode then
            -- Пытаемся с альтернативными названиями
            local keyMappings = {
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
                [" "] = Enum.KeyCode.Space
            }
            keyCode = keyMappings[key]
        end
        
        if keyCode then
            -- Нажимаем клавишу
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            wait(0.05) -- Короткая задержка между нажатием и отпусканием
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            
            print("[QTE Auto] ✅ Клавиша", key, "нажата успешно")
        else
            warn("[QTE Auto] ❌ Неизвестная клавиша:", key)
        end
    end)
end

-- Функция для создания уникального ID кнопки
local function getButtonId(button, text)
    return tostring(button) .. "_" .. text .. "_" .. tick()
end

-- Функция мониторинга кнопок
local function monitorQTEGui(qteGui)
    if currentConnection then
        currentConnection:Disconnect()
    end
    
    local lastProcessedId = ""
    
    currentConnection = RunService.Heartbeat:Connect(function()
        local button = qteGui:FindFirstChild("Button")
        
        if button and button.Visible then
            local buttonText = getButtonText(button)
            
            if buttonText and buttonText ~= "" then
                local buttonId = getButtonId(button, buttonText)
                
                -- Проверяем, не обрабатывали ли мы уже эту кнопку
                if buttonId ~= lastProcessedId and not processedButtons[buttonId] then
                    lastProcessedId = buttonId
                    processedButtons[buttonId] = true
                    
                    print("[QTE Monitor] 🔍 Новая кнопка обнаружена:", buttonText)
                    
                    -- Получаем информацию о тайминге
                    local qteInfo = qteStartTimes[buttonText]
                    local currentTime = tick()
                    
                    if qteInfo and not qteInfo.processed then
                        local requiredTiming = qteInfo.requiredTiming
                        local eventStartTime = qteInfo.eventTime
                        local timeSinceStart = currentTime - eventStartTime
                        
                        -- Вычисляем когда нужно нажать (учитываем уже прошедшее время)
                        local pressDelay = math.max(0, requiredTiming - timeSinceStart - 0.05) -- -0.05 для компенсации задержек
                        
                        print("[QTE Auto] ⏱️ Расчет тайминга:")
                        print("  Требуемый тайминг:", requiredTiming)
                        print("  Время с начала события:", timeSinceStart)
                        print("  Задержка до нажатия:", pressDelay)
                        
                        -- Помечаем как обработанное
                        qteInfo.processed = true
                        
                        -- Нажимаем клавишу с рассчитанной задержкой
                        pressKey(buttonText, pressDelay)
                    else
                        -- Если нет информации о тайминге, используем стандартную задержку
                        local defaultDelay = 1.0
                        print("[QTE Auto] ⚠️ Нет информации о тайминге, используем задержку:", defaultDelay)
                        pressKey(buttonText, defaultDelay)
                    end
                    
                    -- Очищаем обработанные кнопки через некоторое время
                    spawn(function()
                        wait(5)
                        processedButtons[buttonId] = nil
                    end)
                end
            end
        end
    end)
    
    print("[QTE Auto] 👀 Мониторинг GUI активирован")
end

-- Основная функция запуска
local function startMonitoring()
    if isMonitoring then
        print("[QTE Auto] ⚠️ Мониторинг уже запущен")
        return
    end
    
    print("[QTE Auto] 🚀 Запуск системы автоматического нажатия клавиш...")
    
    -- Устанавливаем hook для мониторинга RemoteFunction
    if not hookRemoteFunction() then
        warn("[QTE Auto] ❌ Не удалось установить hook")
        return
    end
    
    isMonitoring = true
    
    -- Очищаем предыдущие данные
    qteStartTimes = {}
    processedButtons = {}
    
    -- Мониторим существующий GUI
    local qteGui = PlayerGui:FindFirstChild("QuickTimeEvent")
    if qteGui then
        print("[QTE Auto] 📱 Найден существующий QuickTimeEvent GUI")
        monitorQTEGui(qteGui)
    end
    
    -- Мониторим новые GUI
    PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "QuickTimeEvent" and isMonitoring then
            print("[QTE Auto] 📥 Новый QuickTimeEvent GUI появился")
            wait(0.1) -- Небольшая задержка для стабилизации
            monitorQTEGui(child)
        end
    end)
    
    print("[QTE Auto] ✅ Система готова! Будет нажимать клавиши в нужный момент")
end

-- Функция остановки
local function stopMonitoring()
    isMonitoring = false
    
    if currentConnection then
        currentConnection:Disconnect()
        currentConnection = nil
    end
    
    -- Очищаем данные
    qteStartTimes = {}
    processedButtons = {}
    
    print("[QTE Auto] 🛑 Мониторинг остановлен")
end

-- Функция для ручного тестирования
local function testKeyPress(key)
    print("[QTE Test] 🧪 Тестируем нажатие клавиши:", key)
    pressKey(key, 0)
end

-- Функция статистики
local function getStats()
    print("[QTE Stats] 📊 Текущее состояние:")
    print("  Активен:", isMonitoring)
    print("  Отслеживаемых событий:", #qteStartTimes)
    print("  Обработанных кнопок:", #processedButtons)
    
    if next(qteStartTimes) then
        print("  Последние события:")
        for key, info in pairs(qteStartTimes) do
            print(string.format("    %s: тайминг=%.2f, обработано=%s", 
                key, info.requiredTiming, tostring(info.processed)))
        end
    end
end

-- Экспорт функций
_G.QTEAuto = {
    start = startMonitoring,
    stop = stopMonitoring,
    isRunning = function() return isMonitoring end,
    testKey = testKeyPress,
    getStats = getStats
}

-- Инструкции
print("=== QuickTimeEvent Auto Clicker ===")
print("🎮 Автоматически нажимает клавиши в нужный момент")
print("")
print("📋 Команды:")
print("  _G.QTEAuto.start() - запустить автонажатие")
print("  _G.QTEAuto.stop() - остановить") 
print("  _G.QTEAuto.testKey('E') - протестировать клавишу")
print("  _G.QTEAuto.getStats() - показать статистику")
print("")

-- Автозапуск
startMonitoring()
