-- QTE Auto Script для Roblox
-- Автоматическое выполнение QuickTimeEvent через эмуляцию нажатий клавиш

-- Получение сервисов
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

-- Локальный игрок
local LocalPlayer = Players.LocalPlayer

-- Маппинг клавиш для VirtualInputManager
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
    ["Space"] = Enum.KeyCode.Space,
    [" "] = Enum.KeyCode.Space,
    ["SPACE"] = Enum.KeyCode.Space,
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five
}

-- Главный класс QTEAuto
local QTEAuto = {}
QTEAuto.__index = QTEAuto

function QTEAuto.new()
    local self = setmetatable({}, QTEAuto)
    
    -- Состояние скрипта
    self.isActive = false
    self.connections = {}
    self.processedButtons = {}
    self.timingData = {}
    self.statistics = {
        detected = 0,
        pressed = 0,
        errors = 0,
        startTime = tick()
    }
    
    -- Оригинальная функция RemoteFunction
    self.originalCallback = nil
    
    return self
end

-- Логирование с временными метками
function QTEAuto:log(message, level)
    level = level or "INFO"
    local timestamp = string.format("%.3f", tick() - self.statistics.startTime)
    print(string.format("[QTE Auto][%s][%s] %s", level, timestamp, message))
end

-- Конвертация текста клавиши в KeyCode
function QTEAuto:getKeyCode(keyText)
    if not keyText then 
        self:log("keyText is nil", "ERROR")
        return nil 
    end
    
    -- Очистка текста от лишних символов
    keyText = string.upper(string.gsub(keyText, "[^%w%s]", ""))
    
    -- Попытка найти в маппинге
    local keyCode = KeyMapping[keyText]
    if keyCode then
        return keyCode
    end
    
    -- Попытка использовать первый символ
    local firstChar = string.sub(keyText, 1, 1)
    keyCode = KeyMapping[firstChar]
    if keyCode then
        return keyCode
    end
    
    self:log("Неизвестная клавиша: " .. tostring(keyText), "ERROR")
    return nil
end

-- Эмуляция нажатия клавиши
function QTEAuto:pressKey(keyCode)
    if not keyCode then 
        self:log("keyCode is nil", "ERROR")
        return false 
    end
    
    local success, errorMsg = pcall(function()
        self:log(string.format("Попытка отправки нажатия клавиши через VirtualInputManager: %s", tostring(keyCode)))
        VirtualInputManager:SendKeyEvent(true, keyCode, false, nil)
        wait(0.01) -- Небольшая задержка между нажатием и отпусканием
        VirtualInputManager:SendKeyEvent(false, keyCode, false, nil)
    end)
    
    if success then
        self:log(string.format("Успешное нажатие через VirtualInputManager: %s", tostring(keyCode)))
        return true
    else
        self:log("Ошибка в VirtualInputManager: " .. tostring(errorMsg), "ERROR")
        -- Попытка через UserInputService
        local uisSuccess, uisError = pcall(function()
            self:log(string.format("Попытка отправки нажатия через UserInputService: %s", tostring(keyCode)))
            UserInputService.InputBegan:Fire({KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard}, false)
            wait(0.01)
            UserInputService.InputEnded:Fire({KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard}, false)
        end)
        if uisSuccess then
            self:log(string.format("Успешное нажатие через UserInputService: %s", tostring(keyCode)))
            return true
        else
            self:log("Ошибка в UserInputService: " .. tostring(uisError), "ERROR")
            return false
        end
    end
end

-- Хук RemoteFunction для перехвата timing данных
function QTEAuto:hookRemoteFunction()
    local remoteFunction = ReplicatedStorage:FindFirstChild("QuickTimeEvent")
    if not remoteFunction then
        self:log("RemoteFunction 'QuickTimeEvent' не найдена", "ERROR")
        return false
    end
    
    -- Сохраняем оригинальный callback
    if not self.originalCallback then
        local success, callback = pcall(function()
            return getcallbackvalue(remoteFunction, "OnClientInvoke")
        end)
        
        if success and callback then
            self.originalCallback = callback
            self:log("Оригинальный callback сохранен")
        else
            self:log("Не удалось получить оригинальный callback", "WARN")
        end
    end
    
    -- Создаем новый callback для мониторинга
    local function monitoringCallback(key, timing)
        -- Сохраняем данные о тайминге
        if key and timing then
            self.timingData[key] = {
                timing = timing,
                timestamp = tick()
            }
            self:log(string.format("Перехвачен QTE: клавиша=%s, тайминг=%.3f", key, timing))
        end
        
        -- Вызываем оригинальный callback, если он есть
        if self.originalCallback then
            return self.originalCallback(key, timing)
        end
        
        return true
    end
    
    -- Устанавливаем новый callback
    pcall(function()
        remoteFunction.OnClientInvoke = monitoringCallback
    end)
    
    self:log("RemoteFunction hook установлен")
    return true
end

-- Мониторинг GUI элементов
function QTEAuto:monitorGUI()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        self:log("PlayerGui не найден", "ERROR")
        return
    end
    
    -- Функция обработки QTE GUI
    local function processQTEGui(qteGui)
        if not qteGui or not qteGui.Parent then return end
        
        -- Поиск кнопки
        local button = qteGui:FindFirstChild("Button")
        if not button then
            -- Попытка найти кнопку в дочерних элементах
            for _, child in pairs(qteGui:GetDescendants()) do
                if child.Name == "Button" or (child:IsA("TextLabel") and child.Text and child.Text ~= "") then
                    button = child
                    break
                end
            end
        end
        
        if not button then
            self:log("Кнопка не найдена в QTE GUI", "WARN")
            return
        end
        
        -- Генерация уникального ID для кнопки
        local buttonId = tostring(button) .. "_" .. tick()
        
        -- Проверка на дубликаты
        if self.processedButtons[buttonId] then
            return
        end
        self.processedButtons[buttonId] = true
        
        -- Извлечение текста клавиши
        local keyText = button.Text
        if not keyText or keyText == "" then
            self:log("Текст кнопки пуст", "WARN")
            return
        end
        
        self:log(string.format("Найдена QTE кнопка: %s", keyText))
        self.statistics.detected = self.statistics.detected + 1
        
        -- Обработка нажатия
        self:processQTEPress(keyText, buttonId)
    end
    
    -- Мониторинг появления QTE GUI
    local function onQTEAdded(qteGui)
        if qteGui.Name == "QuickTimeEvent" then
            self:log("QTE GUI появился")
            wait(0.05) -- Увеличенная задержка для загрузки элементов
            processQTEGui(qteGui)
        end
    end
    
    -- Подключение к событиям
    self.connections.guiAdded = playerGui.ChildAdded:Connect(onQTEAdded)
    
    -- Проверка уже существующих QTE GUI
    local existingQTE = playerGui:FindFirstChild("QuickTimeEvent")
    if existingQTE then
        processQTEGui(existingQTE)
    end
    
    self:log("GUI мониторинг активирован")
end

-- Обработка нажатия QTE
function QTEAuto:processQTEPress(keyText, buttonId)
    local keyCode = self:getKeyCode(keyText)
    if not keyCode then
        self:log(string.format("Ошибка: Не удалось определить keyCode для клавиши %s", tostring(keyText)), "ERROR")
        self.statistics.errors = self.statistics.errors + 1
        return
    end
    
    self:log(string.format("Запуск обработки нажатия для клавиши: %s, buttonId: %s", keyText, buttonId))
    
    -- Поиск timing данных
    local timingInfo = self.timingData[keyText]
    local pressDelay = 0.1 -- Фиксированная задержка 0.1 секунды по умолчанию
    
    if timingInfo then
        local timeSinceStart = tick() - timingInfo.timestamp
        local requiredTiming = timingInfo.timing
        
        -- Нажатие через 0.1 секунды после основного тайминга
        pressDelay = math.max(0, requiredTiming + 0.1 - timeSinceStart)
        
        self:log(string.format("Тайминг найден: требуется=%.3f, прошло=%.3f, задержка=%.3f", 
                 requiredTiming, timeSinceStart, pressDelay))
        
        -- Очистка использованных данных
        self.timingData[keyText] = nil
    else
        self:log("Timing данные не найдены, используется задержка 0.1с", "WARN")
    end
    
    -- Планирование нажатия с использованием coroutine
    coroutine.wrap(function()
        self:log(string.format("Ожидание задержки %.3f секунд для клавиши %s", pressDelay, keyText))
        if pressDelay > 0 then
            wait(pressDelay)
        end
        
        self:log(string.format("Проверка актуальности buttonId %s перед нажатием", buttonId))
        -- Проверка, что кнопка еще актуальна
        if not self.processedButtons[buttonId] then
            self:log(string.format("Нажатие отменено: buttonId %s уже неактуален", buttonId), "WARN")
            return
        end
        
        -- Нажатие клавиши
        local success = self:pressKey(keyCode)
        if success then
            self.statistics.pressed = self.statistics.pressed + 1
            self:log(string.format("Нажата клавиша: %s", keyText))
        else
            self.statistics.errors = self.statistics.errors + 1
            self:log(string.format("Ошибка нажатия клавиши: %s", keyText), "ERROR")
        end
        
        -- Очистка buttonId после нажатия
        self.processedButtons[buttonId] = nil
    end)()
end

-- Очистка устаревших данных
function QTEAuto:cleanupData()
    local currentTime = tick()
    
    -- Очистка timing данных старше 5 секунд
    for key, data in pairs(self.timingData) do
        if currentTime - data.timestamp > 5 then
            self.timingData[key] = nil
        end
    end
    
    -- Очистка обработанных кнопок (оставляем только последние 100)
    local buttonCount = 0
    for _ in pairs(self.processedButtons) do
        buttonCount = buttonCount + 1
    end
    
    if buttonCount > 100 then
        -- Простая очистка - удаляем все
        self.processedButtons = {}
    end
end

-- Запуск автоматизации
function QTEAuto:start()
    if self.isActive then
        self:log("Скрипт уже запущен", "WARN")
        return false
    end
    
    self:log("Запуск QTE Auto...")
    
    -- Сброс статистики
    self.statistics = {
        detected = 0,
        pressed = 0,
        errors = 0,
        startTime = tick()
    }
    
    -- Очистка данных
    self.processedButtons = {}
    self.timingData = {}
    
    -- Установка хука RemoteFunction
    local hookSuccess = self:hookRemoteFunction()
    if not hookSuccess then
        self:log("Не удалось установить hook", "ERROR")
        return false
    end
    
    -- Запуск мониторинга GUI
    self:monitorGUI()
    
    -- Периодическая очистка данных
    self.connections.cleanup = RunService.Heartbeat:Connect(function()
        if tick() % 10 < 0.1 then -- Каждые 10 секунд
            self:cleanupData()
        end
    end)
    
    self.isActive = true
    self:log("QTE Auto успешно запущен!")
    return true
end

-- Остановка автоматизации
function QTEAuto:stop()
    if not self.isActive then
        self:log("Скрипт уже остановлен", "WARN")
        return false
    end
    
    self:log("Остановка QTE Auto...")
    
    -- Отключение всех соединений
    for name, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Восстановление оригинального callback
    if self.originalCallback then
        local remoteFunction = ReplicatedStorage:FindFirstChild("QuickTimeEvent")
        if remoteFunction then
            pcall(function()
                remoteFunction.OnClientInvoke = self.originalCallback
            end)
        end
    end
    
    self.isActive = false
    self:log("QTE Auto остановлен!")
    return true
end

-- Проверка статуса
function QTEAuto:isRunning()
    return self.isActive
end

-- Получение статистики
function QTEAuto:getStats()
    local runtime = tick() - self.statistics.startTime
    local stats = {
        isRunning = self.isActive,
        runtime = runtime,
        detected = self.statistics.detected,
        pressed = self.statistics.pressed,
        errors = self.statistics.errors,
        successRate = self.statistics.detected > 0 and (self.statistics.pressed / self.statistics.detected * 100) or 0
    }
    
    return stats
end

-- Создание глобального экземпляра
local qteAutoInstance = QTEAuto.new()

-- Экспорт в _G
_G.QTEAuto = {
    start = function()
        return qteAutoInstance:start()
    end,
    
    stop = function()
        return qteAutoInstance:stop()
    end,
    
    isRunning = function()
        return qteAutoInstance:isRunning()
    end,
    
    getStats = function()
        return qteAutoInstance:getStats()
    end,
    
    -- Дополнительные функции для отладки
    debug = {
        getTimingData = function()
            return qteAutoInstance.timingData
        end,
        
        getProcessedButtons = function()
            local count = 0
            for _ in pairs(qteAutoInstance.processedButtons) do
                count = count + 1
            end
            return count
        end,
        
        clearData = function()
            qteAutoInstance.processedButtons = {}
            qteAutoInstance.timingData = {}
            print("[QTE Auto] Данные очищены")
        end
    }
}

-- Автозапуск
print("[QTE Auto] Скрипт загружен! Автоматический запуск...")
print("[QTE Auto] Доступные команды:")
print("  _G.QTEAuto.start() - запуск")
print("  _G.QTEAuto.stop() - остановка") 
print("  _G.QTEAuto.isRunning() - проверка статуса")
print("  _G.QTEAuto.getStats() - статистика")
_G.QTEAuto.start()
