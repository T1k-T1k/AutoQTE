-- QuickTimeEvent Auto Script (улучшенная версия)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

-- Переменные для отслеживания
local isMonitoring = false
local currentConnection = nil
local hookedFunction = nil
local originalCallback = nil

-- Данные для анализа паттернов
local timingHistory = {}
local keySequence = {}

-- Функция для перехвата и анализа RemoteFunction
local function hookRemoteFunction()
    local Event = ReplicatedStorage:WaitForChild("QuickTimeEvent", 10)
    
    if not Event or not Event:IsA("RemoteFunction") then
        warn("[QTE Auto] QuickTimeEvent RemoteFunction не найдена")
        return false
    end
    
    -- Сохраняем оригинальный callback
    local success, callback = pcall(function()
        return getcallbackvalue(Event, "OnClientInvoke")
    end)
    
    if not success or not callback then
        warn("[QTE Auto] Не удалось получить оригинальный callback")
        return false
    end
    
    originalCallback = callback
    
    -- Создаем наш hook
    Event.OnClientInvoke = function(...)
        local args = {...}
        local key = args[1]
        local timing = args[2]
        
        print("[QTE Hook] Перехвачен вызов:")
        print("  Клавиша:", key)
        print("  Тайминг:", timing)
        print("  Все аргументы:", unpack(args))
        
        -- Сохраняем данные для анализа
        table.insert(timingHistory, {
            key = key,
            timing = timing,
            timestamp = tick(),
            args = args
        })
        
        -- Ограничиваем историю
        if #timingHistory > 50 then
            table.remove(timingHistory, 1)
        end
        
        -- Вызываем оригинальный callback
        if originalCallback then
            return originalCallback(unpack(args))
        end
    end
    
    print("[QTE Auto] RemoteFunction успешно захукана")
    return true
end

-- Функция для анализа паттернов тайминга
local function analyzeTiming(key)
    local relevantTimings = {}
    
    -- Собираем все тайминги для данной клавиши
    for _, record in ipairs(timingHistory) do
        if record.key == key then
            table.insert(relevantTimings, record.timing)
        end
    end
    
    if #relevantTimings == 0 then
        -- Анализируем общие паттерны
        for _, record in ipairs(timingHistory) do
            table.insert(relevantTimings, record.timing)
        end
    end
    
    if #relevantTimings == 0 then
        return 1.5 -- Значение по умолчанию
    end
    
    -- Вычисляем среднее значение
    local sum = 0
    for _, timing in ipairs(relevantTimings) do
        sum = sum + timing
    end
    
    local average = sum / #relevantTimings
    print("[QTE Analysis] Проанализировано", #relevantTimings, "записей для клавиши", key)
    print("[QTE Analysis] Средний тайминг:", average)
    
    return average
end

-- Функция для программного определения тайминга через RemoteFunction
local function detectTiming(key)
    -- Метод 1: Анализ истории
    local predictedTiming = analyzeTiming(key)
    
    -- Метод 2: Попытка предсказания через паттерны игры
    local currentTime = tick()
    
    -- Ищем недавние активности
    local recentEvents = {}
    for _, record in ipairs(timingHistory) do
        if currentTime - record.timestamp < 10 then -- Последние 10 секунд
            table.insert(recentEvents, record)
        end
    end
    
    -- Анализируем интервалы между событиями
    if #recentEvents >= 2 then
        local intervals = {}
        for i = 2, #recentEvents do
            local interval = recentEvents[i].timestamp - recentEvents[i-1].timestamp
            table.insert(intervals, interval)
        end
        
        -- Среднее время между событиями может помочь предсказать следующий тайминг
        local avgInterval = 0
        for _, interval in ipairs(intervals) do
            avgInterval = avgInterval + interval
        end
        avgInterval = avgInterval / #intervals
        
        print("[QTE Analysis] Средний интервал между событиями:", avgInterval)
        
        -- Корректируем предсказание на основе интервала
        if avgInterval < 3 then
            predictedTiming = math.min(predictedTiming, avgInterval * 0.8)
        end
    end
    
    -- Метод 3: Мониторинг сетевого трафика для более точного предсказания
    local networkDelay = 0.05 -- Примерная задержка сети
    predictedTiming = math.max(0.1, predictedTiming - networkDelay)
    
    return predictedTiming
end

-- Функция для получения текста кнопки
local function getButtonText(button)
    if button and button:IsA("GuiObject") then
        -- Проверяем различные возможные места хранения текста
        if button:FindFirstChild("TextLabel") then
            return button.TextLabel.Text
        elseif button.Text and button.Text ~= "" then
            return button.Text
        elseif button:FindFirstChild("Text") then
            return button.Text.Text
        end
        
        -- Ищем в дочерних элементах
        for _, child in ipairs(button:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                if child.Text and child.Text ~= "" then
                    return child.Text
                end
            end
        end
    end
    return nil
end

-- Функция для автоматического выполнения QTE
local function executeQTE(key, customTiming)
    local Event = ReplicatedStorage:FindFirstChild("QuickTimeEvent")
    if not Event or not Event:IsA("RemoteFunction") then
        warn("[QTE Auto] RemoteFunction не найдена для выполнения")
        return false
    end
    
    local timing = customTiming or detectTiming(key)
    
    print("[QTE Auto] Выполнение QTE:")
    print("  Клавиша:", key)
    print("  Рассчитанный тайминг:", timing)
    
    -- Выполняем с небольшой задержкой для стабильности
    spawn(function()
        wait(0.02)
        
        local success, result = pcall(function()
            if originalCallback then
                return originalCallback(key, timing)
            else
                -- Fallback метод
                local Callback = getcallbackvalue(Event, "OnClientInvoke")
                return Callback(key, timing)
            end
        end)
        
        if success then
            print("[QTE Auto] ✅ Успешно выполнено QTE для клавиши:", key)
            
            -- Обновляем статистику успеха
            table.insert(keySequence, {
                key = key,
                timing = timing,
                success = true,
                timestamp = tick()
            })
        else
            warn("[QTE Auto] ❌ Ошибка выполнения QTE:", result)
        end
    end)
    
    return true
end

-- Функция мониторинга кнопок в GUI
local function monitorButton(qteGui)
    if currentConnection then
        currentConnection:Disconnect()
    end
    
    local lastButtonText = ""
    local buttonAppearTime = 0
    
    currentConnection = RunService.Heartbeat:Connect(function()
        local button = qteGui:FindFirstChild("Button")
        
        if button and button.Visible then
            local buttonText = getButtonText(button)
            
            if buttonText and buttonText ~= "" and buttonText ~= lastButtonText then
                lastButtonText = buttonText
                buttonAppearTime = tick()
                
                print("[QTE Monitor] 🔍 Обнаружена новая кнопка:", buttonText)
                
                -- Небольшая задержка для стабилизации GUI
                wait(0.1)
                
                -- Программно определяем тайминг и выполняем QTE
                executeQTE(buttonText)
                
                -- Ждем исчезновения кнопки перед следующим мониторингом
                spawn(function()
                    while button and button.Visible and button.Parent do
                        wait(0.1)
                    end
                    lastButtonText = ""
                end)
            end
        else
            lastButtonText = ""
        end
    end)
end

-- Основная функция запуска
local function startMonitoring()
    if isMonitoring then
        print("[QTE Auto] Мониторинг уже активен")
        return
    end
    
    print("[QTE Auto] 🚀 Запуск системы автоматического QTE...")
    
    -- Сначала хукаем RemoteFunction
    if not hookRemoteFunction() then
        warn("[QTE Auto] Не удалось захукать RemoteFunction")
        return
    end
    
    isMonitoring = true
    
    -- Мониторинг существующего GUI
    local qteGui = PlayerGui:FindFirstChild("QuickTimeEvent")
    if qteGui then
        print("[QTE Auto] Найден существующий QuickTimeEvent GUI")
        monitorButton(qteGui)
    end
    
    -- Мониторинг новых GUI
    PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "QuickTimeEvent" and isMonitoring then
            print("[QTE Auto] 📥 Новый QuickTimeEvent GUI добавлен")
            wait(0.2) -- Даем время GUI загрузиться
            monitorButton(child)
        end
    end)
    
    print("[QTE Auto] ✅ Система активирована и готова к работе")
end

-- Функция остановки
local function stopMonitoring()
    isMonitoring = false
    
    if currentConnection then
        currentConnection:Disconnect()
        currentConnection = nil
    end
    
    -- Восстанавливаем оригинальный callback если возможно
    if originalCallback then
        local Event = ReplicatedStorage:FindFirstChild("QuickTimeEvent")
        if Event and Event:IsA("RemoteFunction") then
            Event.OnClientInvoke = originalCallback
        end
    end
    
    print("[QTE Auto] 🛑 Мониторинг остановлен")
end

-- Функция для просмотра статистики
local function getStats()
    print("[QTE Stats] 📊 Статистика:")
    print("  Всего записей в истории:", #timingHistory)
    print("  Последние 5 событий:")
    
    for i = math.max(1, #timingHistory - 4), #timingHistory do
        local record = timingHistory[i]
        print(string.format("    %d. Клавиша: %s, Тайминг: %.2f", i, record.key, record.timing))
    end
end

-- Экспорт функций
_G.QTEAuto = {
    start = startMonitoring,
    stop = stopMonitoring,
    isRunning = function() return isMonitoring end,
    getStats = getStats,
    executeManual = executeQTE,
    getHistory = function() return timingHistory end
}

-- Инструкции
print("=== QuickTimeEvent Auto Script ===")
print("📋 Доступные команды:")
print("  _G.QTEAuto.start() - запустить автоматическое выполнение")
print("  _G.QTEAuto.stop() - остановить")
print("  _G.QTEAuto.getStats() - показать статистику")
print("  _G.QTEAuto.executeManual('E', 1.5) - ручное выполнение")

-- Автозапуск
startMonitoring()
