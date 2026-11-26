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

----------------------------------------------------------------------
-- names hidden with the UI (Alt+Z): Alt+Z hides only the interface, the
-- names over characters are drawn by the game world and stay. While the UI
-- is hidden, the game's name options are switched off; they go back to what
-- they were when the UI comes back. The old values are kept in the saved
-- variables, so a logout or crash with the UI hidden can't leave names off.
----------------------------------------------------------------------
local OWN = { "UnitNameOwn" }
local OTHERS = {
	"UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName",
	"UnitNameFriendlyPetName", "UnitNameEnemyPetName",
	"UnitNameFriendlyGuardianName", "UnitNameEnemyGuardianName",
	"UnitNameFriendlyTotemName", "UnitNameEnemyTotemName",
	"UnitNameNPC", "UnitNameNonCombatCreatureName",
}

local function GetValue(name)
	local ok, value = pcall(C_CVar.GetCVar, name)
	if ok then return value end
end

-- only writes when the value changes (every write runs the game's handlers)
local function SetValue(name, value)
	local current = GetValue(name)
	if current == nil or current == value then return end
	pcall(C_CVar.SetCVar, name, value)
end

local waitingForCombat = false

local function RestoreNames()
	local saved = ns.db and ns.db.hiddenNames
	if not saved then return end
	if InCombatLockdown() then waitingForCombat = true return end
	for name, value in pairs(saved) do SetValue(name, value) end
	ns.db.hiddenNames = nil
end

local function HideNames()
	if not (ns.Get("hideNamesWithUI") or ns.Get("hideOtherNamesWithUI")) then return end
	if InCombatLockdown() then waitingForCombat = true return end
	ns.db.hiddenNames = ns.db.hiddenNames or {}
	local saved = ns.db.hiddenNames
	local function hide(list)
		for _, name in ipairs(list) do
			local value = GetValue(name)
			if value ~= nil then
				if saved[name] == nil then saved[name] = value end
				SetValue(name, "0")
			end
		end
	end
	if ns.Get("hideNamesWithUI") then hide(OWN) end
	if ns.Get("hideOtherNamesWithUI") then hide(OTHERS) end
end

-- a setting switched on or off while the interface is hidden takes effect at once
local function ApplyNames(_, isLogin)
	if isLogin then
		RestoreNames() -- left from a logout with the interface hidden
		return
	end
	RestoreNames()
	if not UIParent:IsShown() then HideNames() end
end

local function Update()
	if UIParent:IsShown() then RestoreNames() else HideNames() end
end

UIParent:HookScript("OnHide", Update)
UIParent:HookScript("OnShow", Update)

local names = CreateFrame("Frame")
names:RegisterEvent("PLAYER_REGEN_ENABLED")
names:SetScript("OnEvent", function()
	if waitingForCombat then
		waitingForCombat = false
		Update()
	end
end)

ns.Register({
	key = "hideNamesWithUI",
	category = "Hide UI (Alt+Z)",
	new = true,
	label = "Hide my name too",
	tooltip = "When you hide the interface with Alt+Z, the name over your character is hidden as well, and it comes back with the interface. In combat this waits until the fight is over.",
	default = false,
	apply = ApplyNames,
})

ns.Register({
	key = "hideOtherNamesWithUI",
	category = "Hide UI (Alt+Z)",
	new = true,
	label = "Hide other names too",
	tooltip = "When you hide the interface with Alt+Z, the names of other players, pets and NPCs are hidden as well, and they come back with the interface. In combat this waits until the fight is over.",
	default = false,
	apply = ApplyNames,
})
