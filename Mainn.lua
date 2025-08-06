local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- Логгер
local function log(msg)
	print(string.format("[QTE Auto] %.3f | %s", tick(), msg))
end

-- Получить Enum.KeyCode по строке
local function toKeyCode(key)
	local success, keyCode = pcall(function()
		return Enum.KeyCode[key:upper()]
	end)
	return success and keyCode or nil
end

-- Нажатие клавиши
local function pressKey(rawKey)
	local keyCode = toKeyCode(rawKey)
	if not keyCode then
		log("Неизвестная клавиша: " .. tostring(rawKey))
		return
	end

	log("НАЖАТИЕ: " .. tostring(keyCode))
	VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
	task.wait(0.02)
	VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

-- Основной хук
local function hookQTE()
	local remote = ReplicatedStorage:WaitForChild("QuickTimeEvent")

	local originalCallback = nil
	pcall(function()
		originalCallback = getcallbackvalue(remote, "OnClientInvoke")
	end)

	remote.OnClientInvoke = function(key, timing)
		if key and timing then
			local triggerTime = tick() + timing
			log(string.format("Ожидание %.3f сек до нажатия %s", timing, key))

			-- Подождать до нужного момента
			task.delay(timing, function()
				log("НАЖАТИЕ В ИДЕАЛЬНЫЙ МОМЕНТ!")
				pressKey(key)
			end)
		end

		if originalCallback then
			return originalCallback(key, timing)
		end
		return true
	end

	log("QTE перехвачен.")
end

hookQTE()
log("Скрипт запущен.")
