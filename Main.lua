local PLRS = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local VIM = game:GetService("VirtualInputManager"); local LP = PLRS.LocalPlayer

local function log(msg)
	print(string.format("[Auto AS (Anubis Requiem)] %.3f | %s", tick(), msg))
end

local function toKeyCode(key)
	local success, keyCode = pcall(function()
		return Enum.KeyCode[key:upper()]
	end)
	return success and keyCode or nil
end

local function pressKey(rawKey)
	local keyCode = toKeyCode(rawKey)
	if not keyCode then
		log("Unknown key: " .. tostring(rawKey))
		return
	end

	log("Clicked" .. tostring(keyCode))
	VIM:SendKeyEvent(true, keyCode, false, game)
	task.wait(0.02)
	VIM:SendKeyEvent(false, keyCode, false, game)
end

local function hookQTE()
	local remote = RS:WaitForChild("QuickTimeEvent")

	local originalCallback = nil
	pcall(function()
		originalCallback = getcallbackvalue(remote, "OnClientInvoke")
	end)

	remote.OnClientInvoke = function(key, timing)
		if key and timing then
			local triggerTime = tick() + timing
			log(string.format("Wait %.3f sec before pressing %s", timing, key))

			task.delay(timing, function()
				pressKey(key)
			end)
		end

		if originalCallback then
			return originalCallback(key, timing)
		end
		return true
	end

	log("QTE intercepted.")
end

hookQTE()
log("Script Injected.")
