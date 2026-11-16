-- Kindouse Tweaks: world

local ADDON, ns = ...

----------------------------------------------------------------------
-- quest item sparkles: the game's own loot sparkle on lootable quest items.
-- Graphics presets switch it off, so it is put back at login and after any
-- graphics change (same approach as the Forever Loot Sparkles addon).
----------------------------------------------------------------------
local CVAR = "outlineModeShowLootEffectWhenDisabled"
local WATCHED = { graphicsquality = true, raidgraphicsquality = true, [CVAR:lower()] = true }

local applying, pending = false, false

local function Apply()
	if not ns.Get("lootSparkles") then return end
	if InCombatLockdown() then pending = true return end
	local current = C_CVar.GetCVar(CVAR)
	if current ~= nil and current ~= "1" then
		applying = true
		pcall(C_CVar.SetCVar, CVAR, "1")
		applying = false
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(f.RegisterEvent, f, "CVAR_UPDATE")
f:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then
			pending = false
			Apply()
		end
	elseif not applying and type(name) == "string" and WATCHED[name:lower()] then
		C_Timer.After(1, Apply)
	end
end)

ns.Register({
	key = "lootSparkles",
	category = "World",
	label = "Sparkles on lootable quest items",
	tooltip = "Keeps the game's loot sparkle on quest items switched on, even after a graphics preset turns it off. Switching this off only takes effect after restarting the game.",
	default = true,
	apply = function(enabled, isLogin)
		if enabled then
			Apply()
			if isLogin then C_Timer.After(5, Apply) end -- settings synced from the server can arrive late
		elseif not isLogin then
			pending = false
			applying = true
			pcall(C_CVar.SetCVar, CVAR, "0")
			applying = false
			ns.Print("restart the game to remove the sparkles. /reload is not enough.")
		end
	end,
})
