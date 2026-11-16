-- Kindouse Tweaks: core
-- Every tweak registers one on/off setting here. The options window (Options.lua)
-- is built from this list, so a new tweak only needs an ns.Register{} call.

local ADDON, ns = ...

ns.title = "|cff33bbffKindouse|r Tweaks"
ns.settings = {} -- in registration order (this is the order shown in the menu)
ns.byKey = {}
ns.loaded = {}   -- values at login, to tell when a reload is needed

-- def = {
--   key      = saved variable name,
--   category = heading it is listed under,
--   label    = checkbox text,
--   tooltip  = longer description,
--   default  = true/false,
--   reload   = true if the change only takes effect after /reload,
--   apply    = function(enabled, isLogin): called at login and on every change
--              (not called on change for reload-only settings),
--   build    = optional function(parent, x, y) adding extra controls under the
--              checkbox in the options window; returns the y below them,
--   refresh  = optional function() updating those controls when the window opens,
-- }
function ns.Register(def)
	ns.settings[#ns.settings + 1] = def
	ns.byKey[def.key] = def
end

-- run fn once the saved variables are loaded (before PLAYER_LOGIN)
local onLoad = {}
function ns.OnLoad(fn)
	onLoad[#onLoad + 1] = fn
end

-- opens the game's colour picker (no opacity); callback(r, g, b) on every change,
-- and with the starting colour again if the picker is cancelled
function ns.PickColor(r, g, b, callback)
	local function pick() callback(ColorPickerFrame:GetColorRGB()) end
	local function cancel() callback(r, g, b) end
	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r, g = g, b = b, hasOpacity = false,
			swatchFunc = pick, cancelFunc = cancel,
		})
	else
		ColorPickerFrame:Hide()
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = pick, nil, cancel
		ColorPickerFrame:SetColorRGB(r, g, b)
		ColorPickerFrame:Show()
	end
end

function ns.Get(key)
	return ns.db and ns.db[key]
end

function ns.Set(key, value)
	local def = ns.byKey[key]
	if not (def and ns.db) then return end
	value = value and true or false
	if ns.db[key] == value then return end
	ns.db[key] = value
	if def.apply and not def.reload then def.apply(value, false) end
end

-- true when a reload-only setting differs from what was loaded
function ns.NeedsReload()
	for _, def in ipairs(ns.settings) do
		if def.reload and ns.db[def.key] ~= ns.loaded[def.key] then return true end
	end
	return false
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(ns.title .. ": " .. tostring(msg))
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if name ~= ADDON then return end
		self:UnregisterEvent("ADDON_LOADED")
		KindouseTweaksDB = KindouseTweaksDB or {}
		ns.db = KindouseTweaksDB
		for _, def in ipairs(ns.settings) do
			if ns.db[def.key] == nil then ns.db[def.key] = def.default and true or false end
			ns.loaded[def.key] = ns.db[def.key]
		end
		for _, fn in ipairs(onLoad) do fn() end
	else
		for _, def in ipairs(ns.settings) do
			if def.apply then def.apply(ns.db[def.key], true) end
		end
	end
end)
