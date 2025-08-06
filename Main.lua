-- QuickTimeEvent Auto Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

-- Переменные для отслеживания
local isMonitoring = false
local currentConnection = nil
local remoteConnection = nil

-- Функция для получения текста кнопки
local function getButtonText(button)
    if button and button:IsA("GuiObject") then
        if button:FindFirstChild("TextLabel") then
            return button.TextLabel.Text
        elseif button.Text then
            return button.Text
        end
    end
    return nil
end

-- Функция для отслеживания RemoteFunction и получения тайминга
local function hookRemoteFunction()
    local Event = ReplicatedStorage:WaitForChild("QuickTimeEvent")
    
    -- Хукаем RemoteFunction для отслеживания тайминга
    local originalCallback = nil
    
    -- Метод для перехвата вызовов
    local function hookCallback()
        if Event and Event:IsA("RemoteFunction") then
            -- Сохраняем оригинальный callback
            originalCallback = getcallbackvalue(Event, "OnClientInvoke")
            
            -- Устанавливаем наш hook
            Event.OnClientInvoke = function(key, timing)
                print("[QTE Hook] Получен вызов: клавиша =", key, "тайминг =", timing)
                
                -- Вызываем оригинальный callback
                if originalCallback then
                    return originalCallback(key, timing)
                end
            end
        end
    end
    
    -- Пытаемся захукать
    pcall(hookCallback)
end

-- Функция для автоматического нажатия
local function autoPress(key, timing)
    local Event = ReplicatedStorage:FindFirstChild("QuickTimeEvent")
    if Event and Event:IsA("RemoteFunction") then
        local Callback = getcallbackvalue(Event, "OnClientInvoke")
        
        if Callback then
            -- Небольшая задержка для более точного тайминга
            wait(0.01)
            
            local success, result = pcall(function()
                return Callback(key, timing)
            end)
            
            if success then
                print("[QTE Auto] Успешно нажата клавиша:", key, "с таймингом:", timing)
            else
                warn("[QTE Auto] Ошибка при нажатии:", result)
            end
        end
    end
end

-- Функция для отслеживания появления кнопки
local function monitorButton(qteGui)
    if currentConnection then
        currentConnection:Disconnect()
    end
    
    currentConnection = RunService.Heartbeat:Connect(function()
        local button = qteGui:FindFirstChild("Button")
        
        if button and button.Visible then
            local buttonText = getButtonText(button)
            
            if buttonText and buttonText ~= "" then
                print("[QTE Monitor] Найдена кнопка с текстом:", buttonText)
                
                -- Пытаемся определить тайминг
                -- Можно попробовать несколько методов:
                
                -- Метод 1: Анализ времени появления кнопки
                local startTime = tick()
                
                -- Метод 2: Поиск информации о тайминге в GUI
                local timing = 1.5 -- Значение по умолчанию
                
                -- Проверяем другие элементы GUI на наличие информации о тайминге
                for _, child in pairs(qteGui:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextBox") then
                        local text = child.Text
                        local timeMatch = string.match(text, "(%d+%.?%d*)")
                        if timeMatch then
                            local parsedTime = tonumber(timeMatch)
                            if parsedTime and parsedTime > 0 and parsedTime < 10 then
                                timing = parsedTime
                                break
                            end
                        end
                    end
                end
                
                -- Метод 3: Мониторинг изменений в GUI для определения тайминга
                spawn(function()
                    local monitorStart = tick()
                    local lastCheck = tick()
                    
                    while button.Visible and tick() - monitorStart < 5 do
                        wait(0.01)
                        
                        -- Проверяем изменения каждые 0.1 секунды
                        if tick() - lastCheck >= 0.1 then
                            lastCheck = tick()
                            
                            -- Если кнопка все еще видима, пытаемся определить оптимальный момент
                            local currentTiming = tick() - startTime
                            
                            -- Адаптивный тайминг на основе времени жизни кнопки
                            if currentTiming > 0.5 and currentTiming < 3.0 then
                                timing = currentTiming + 0.1
                            end
                        end
                    end
                    
                    -- Выполняем автонажатие
                    autoPress(buttonText, timing)
                end)
                
                -- Останавливаем мониторинг этой кнопки
                if currentConnection then
                    currentConnection:Disconnect()
                    currentConnection = nil
                end
            end
        end
    end)
end

-- Основная функция мониторинга
local function startMonitoring()
    if isMonitoring then
        print("[QTE Auto] Мониторинг уже запущен")
        return
    end
    
    isMonitoring = true
    print("[QTE Auto] Запуск мониторинга QuickTimeEvent...")
    
    -- Хукаем RemoteFunction
    hookRemoteFunction()
    
    -- Ждем появления QuickTimeEvent GUI
    local function checkForQTE()
        local qteGui = PlayerGui:FindFirstChild("QuickTimeEvent")
        
        if qteGui then
            print("[QTE Auto] Найден QuickTimeEvent GUI")
            monitorButton(qteGui)
        else
            -- Продолжаем ждать
            wait(0.1)
            checkForQTE()
        end
    end
    
    -- Запускаем в отдельном потоке
    spawn(checkForQTE)
    
    -- Также мониторим добавление новых GUI
    PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "QuickTimeEvent" then
            print("[QTE Auto] QuickTimeEvent GUI добавлен")
            wait(0.1) -- Даем время GUI полностью загрузиться
            monitorButton(child)
        end
    end)
end

-- Функция остановки мониторинга
local function stopMonitoring()
    isMonitoring = false
    
    if currentConnection then
        currentConnection:Disconnect()
        currentConnection = nil
    end
    
    if remoteConnection then
        remoteConnection:Disconnect()
        remoteConnection = nil
    end
    
    print("[QTE Auto] Мониторинг остановлен")
end

-- Экспортируем функции
_G.QTEAuto = {
    start = startMonitoring,
    stop = stopMonitoring,
    isRunning = function() return isMonitoring end
}

-- Автозапуск
print("[QTE Auto] Скрипт загружен. Используйте _G.QTEAuto.start() для запуска")
print("[QTE Auto] Команды:")
print("  _G.QTEAuto.start() - запустить мониторинг")
print("  _G.QTEAuto.stop() - остановить мониторинг")
print("  _G.QTEAuto.isRunning() - проверить статус")

-- Автоматический запуск
startMonitoring()
