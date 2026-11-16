-- Kindouse Tweaks: unit frames (formerly the Thick Player Health addon)
-- Merges the name box and health bar into one thick, class-coloured health bar on
-- the player and target frames, and moves the names above the frames.
-- These changes hook Blizzard's frames, so switching them needs a UI reload.

local ADDON, ns = ...

ns.Register({
	key = "thickFrames",
	category = "Unit Frames",
	label = "Thick class-coloured health bars",
	tooltip = "Merges the name box and health bar of the player and target frames into one thick, class-coloured health bar and moves the names above the frames.",
	default = false,
	reload = true,
})

-- what the health bars show, same choices as the game's Display Health Text
local HEALTH_MODES = {
	{ "none", "None" },
	{ "remaining", "Remaining" },        -- 200
	{ "full", "Numeric Value" },         -- 200 / 200
	{ "percent", "Percentage" },         -- 100%
	{ "fullpercent", "Both" },           -- 100% on the left, 200 on the right
}
local modeText

local function ModeIndex()
	local mode = ns.db.healthTextMode or "remaining"
	for i, m in ipairs(HEALTH_MODES) do
		if m[1] == mode then return i end
	end
	return 2
end

local function RefreshMode()
	if modeText then modeText:SetText(HEALTH_MODES[ModeIndex()][2]) end
end

local function StepMode(step)
	local i = (ModeIndex() - 1 + step) % #HEALTH_MODES + 1
	ns.db.healthTextMode = HEALTH_MODES[i][1]
	RefreshMode()
	if ns.RefreshBarTexts then ns.RefreshBarTexts() end
end

-- "Health text:  [<]  Remaining  [>]" under the checkbox
local function BuildModePicker(parent, x, y)
	local title = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	title:SetPoint("TOPLEFT", x, y - 5)
	title:SetText("Bar text:")
	local function Arrow(text, offset, step)
		local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		b:SetSize(24, 20)
		b:SetPoint("TOPLEFT", x + offset, y - 1)
		b:SetText(text)
		b:SetScript("OnClick", function() StepMode(step) end)
	end
	Arrow("<", 76, -1)
	modeText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	modeText:SetPoint("TOPLEFT", x + 104, y - 5)
	modeText:SetWidth(156)
	modeText:SetJustifyH("CENTER")
	Arrow(">", 264, 1)
	return y - 24
end

ns.Register({
	key = "currentValueText",
	category = "Unit Frames",
	label = "Custom text on health and power bars",
	tooltip = "Health and power bars on the player and target frames show what you pick below. The choice changes straight away.",
	default = false,
	reload = true,
	build = BuildModePicker,
	refresh = RefreshMode,
})
ns.Register({
	key = "barFont",
	category = "Unit Frames",
	label = "Expressway font on bar numbers",
	tooltip = "Health and power numbers use the Expressway font with a thin black outline.",
	default = false,
	reload = true,
})
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local FRAME_ART = MEDIA .. "PlayerFrame-Thick.png"
local COMBAT_ART = MEDIA .. "PlayerFrame-Thick-InCombat.png"
local FILL = "Interface\\TargetingFrame\\UI-StatusBar"

-- the merged window inside the 198x71 player art (the target uses it mirrored)
local WIN_LEFT, WIN_RIGHT = 72, 192
local WIN_TOP, WIN_BOTTOM = 14.5, 45.5
-- the power bar's window in the same art (same left and right as the health window)
local POW_TOP, POW_BOTTOM = 48, 57
local NAME_RAISE = 20

----------------------------------------------------------------------
-- colours: class colour for players, reaction colour for NPCs
----------------------------------------------------------------------
local function UnitColor(unit)
	if not UnitExists(unit) then return 0.1, 0.8, 0.1 end
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or RAID_CLASS_COLORS[class])
		if c then return c.r, c.g, c.b end
	end
	if UnitIsTapDenied and UnitIsTapDenied(unit) and not UnitPlayerControlled(unit) then
		return 0.5, 0.5, 0.5
	end
	local reaction = UnitReaction(unit, "player")
	local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
	if c then return c.r, c.g, c.b end
	return 0.1, 0.8, 0.1
end

----------------------------------------------------------------------
-- the two frames
----------------------------------------------------------------------
local units = {
	player = {
		mirrored = false,
		parts = function()
			if not (PlayerFrame and PlayerFrame.PlayerFrameContainer and PlayerFrame_GetHealthBarContainer) then return end
			local c = PlayerFrame.PlayerFrameContainer
			local hp = PlayerFrame_GetHealthBarContainer()
			if not (hp and hp.HealthBar) then return end
			return {
				container = c, art = c.FrameTexture, flash = c.FrameFlash,
				hp = hp, bar = hp.HealthBar, mask = hp.HealthBarMask,
				name = PlayerName or PlayerFrame.name,
			}
		end,
		skip = function() return PlayerFrame.state == "vehicle" end,
	},
	target = {
		mirrored = true,
		useMirror = true, -- Blizzard moves the target bar on target change, even in combat
		parts = function()
			local f = TargetFrame
			if not (f and f.TargetFrameContainer and f.TargetFrameContent) then return end
			local main = f.TargetFrameContent.TargetFrameContentMain
			local hp = main and main.HealthBarsContainer
			if not (hp and hp.HealthBar) then return end
			local c = f.TargetFrameContainer
			return {
				container = c, art = c.FrameTexture, flash = c.Flash, portrait = c.Portrait,
				hp = hp, bar = hp.HealthBar, mask = hp.HealthBarMask,
				name = main.Name, nameBg = main.ReputationColor,
			}
		end,
		skip = function() return false end,
	},
}
for unit, u in pairs(units) do u.unit = unit end

----------------------------------------------------------------------
-- art
----------------------------------------------------------------------
local function SetArt(u, p)
	local art = p.art
	if art.tphBusy then return end
	art.tphBusy = true
	art:SetTexture(FRAME_ART)
	if u.mirrored then
		-- the target frame uses the same art flipped, like BetterBlizzFrames does
		art:SetTexCoord(1, 0, 0, 1)
		art:SetSize(198, 71)
		art:ClearAllPoints()
		art:SetPoint("CENTER", p.container, "CENTER", 0.5, 2)
		if p.portrait then
			p.portrait:SetSize(60, 60)
			p.portrait:ClearAllPoints()
			p.portrait:SetPoint("TOPRIGHT", p.container, "TOPRIGHT", -24, -16.5)
		end
	else
		art:SetTexCoord(0, 1, 0, 1)
	end
	art.tphBusy = false
end

local function SetCombatArt(u, p)
	local flash = p.flash
	if not flash or flash.tphBusy or u.skip() then return end
	local alt = p.container.AlternatePowerFrameTexture
	if alt and alt:IsShown() then return end -- class-resource layout keeps its own glow
	flash.tphBusy = true
	flash:SetTexture(COMBAT_ART)
	if u.mirrored then flash:SetTexCoord(1, 0, 0, 1) else flash:SetTexCoord(0, 1, 0, 1) end
	flash:ClearAllPoints()
	flash:SetAllPoints(p.art)
	flash.tphBusy = false
end

----------------------------------------------------------------------
-- bar fill and colour
----------------------------------------------------------------------
local function SetFill(u, p)
	local bar = p.bar
	if bar.tphBusy then return end
	bar.tphBusy = true
	bar:SetStatusBarTexture(FILL)
	bar:SetStatusBarColor(UnitColor(u.unit))
	local fill = bar:GetStatusBarTexture()
	if fill then
		fill:SetHorizTile(false)
		fill:SetVertTile(false)
		if fill.GetNumMaskTextures then
			for i = fill:GetNumMaskTextures(), 1, -1 do
				local m = fill:GetMaskTexture(i)
				if m then fill:RemoveMaskTexture(m) end
			end
		end
	end
	bar.tphBusy = false
end

----------------------------------------------------------------------
-- layout (the bars are protected: only out of combat)
----------------------------------------------------------------------
local pending = false

local function Layout(u, p)
	if InCombatLockdown() then pending = true return end
	local art, container = p.art, p.container
	local ax, ay = 0, 0
	if art:GetLeft() and container:GetLeft() then
		ax = art:GetLeft() - container:GetLeft()
		ay = art:GetTop() - container:GetTop()
	end
	local l, r = WIN_LEFT, WIN_RIGHT
	if u.mirrored then l, r = 198 - WIN_RIGHT, 198 - WIN_LEFT end
	-- anchored to the container frame (protected frames can't anchor to textures)
	p.bar:ClearAllPoints()
	p.bar:SetPoint("TOPLEFT", container, "TOPLEFT", ax + l, ay - WIN_TOP)
	p.bar:SetPoint("BOTTOMRIGHT", container, "TOPLEFT", ax + r, ay - WIN_BOTTOM)
	if p.hp.SetClipsChildren then p.hp:SetClipsChildren(false) end
end

local function Texts(u, p)
	local hp, bar = p.hp, u.mirror or p.bar
	local function place(fs, point, x)
		if not fs then return end
		if u.mirror and fs:GetParent() ~= u.mirror.text then fs:SetParent(u.mirror.text) end
		fs:ClearAllPoints()
		fs:SetPoint(point, bar, point, x, 0)
	end
	place(hp.HealthBarText, "CENTER", 0)
	place(hp.LeftText, "LEFT", 3)
	place(hp.RightText, "RIGHT", -3)
	place(hp.DeadText, "CENTER", 0)
	place(hp.UnconsciousText, "CENTER", 0)

	-- name above the frame
	local name = p.name
	if name and not name.tphBusy then
		if not u.nameOrig then
			local pt, rel, rp, x, y = name:GetPoint(1)
			if pt then u.nameOrig = { pt, rel, rp, x or 0, y or 0 } end
		end
		if u.nameOrig then
			name.tphBusy = true
			local o = u.nameOrig
			name:ClearAllPoints()
			name:SetPoint(o[1], o[2], o[3], o[4], o[5] + NAME_RAISE)
			name.tphBusy = false
		end
	end
	-- the target's coloured name background would sit on top of the bar
	if p.nameBg then p.nameBg:SetAlpha(0) end
end


----------------------------------------------------------------------
-- target: our own (unprotected) copy of the health bar, like BetterBlizzFrames'
-- "healthbar mirror". Blizzard re-anchors the real target bar on target changes,
-- and since it's protected we can't move it back in combat. Our copy can always
-- be placed, so the real one is just made invisible and its values forwarded.
----------------------------------------------------------------------
local function UpdateMirror(u, p)
	local m = u.mirror
	if not m then return end
	local mn, mx = p.bar:GetMinMaxValues()
	m:SetMinMaxValues(mn, mx)
	m:SetValue(p.bar:GetValue())
	m:SetStatusBarColor(UnitColor(u.unit))
end

local function HideSource(p)
	p.bar.tphHiding = true
	p.bar:SetAlpha(0)
	local loss = p.hp.TempMaxHealthLoss or p.hp.PlayerFrameTempMaxHealthLoss
	if loss then loss:SetAlpha(0) end
	p.bar.tphHiding = false
end

local function Mirror(u, p)
	local m = u.mirror
	if not m then
		m = CreateFrame("StatusBar", nil, p.hp:GetParent())
		m:SetStatusBarTexture(FILL)
		local fill = m:GetStatusBarTexture()
		fill:SetHorizTile(false)
		fill:SetVertTile(false)
		m:EnableMouse(false)
		m.text = CreateFrame("Frame", nil, m)
		m.text:SetAllPoints(m)
		u.mirror = m
		-- forward everything Blizzard does to the real bar
		hooksecurefunc(p.bar, "SetValue", function(_, v) m:SetValue(v) end)
		hooksecurefunc(p.bar, "SetMinMaxValues", function(_, a, b) m:SetMinMaxValues(a, b) end)
		hooksecurefunc(p.bar, "SetAlpha", function(self, a) if a ~= 0 and not self.tphHiding then HideSource(p) end end)
	end
	m:SetFrameStrata(p.bar:GetFrameStrata())
	m:SetFrameLevel(p.bar:GetFrameLevel() + 1)
	m.text:SetFrameLevel(m:GetFrameLevel() + 2)
	local l, r = 198 - WIN_RIGHT, 198 - WIN_LEFT
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", p.art, "TOPLEFT", l, -WIN_TOP)
	m:SetPoint("BOTTOMRIGHT", p.art, "TOPLEFT", r, -WIN_BOTTOM)
	HideSource(p)
	UpdateMirror(u, p)
end

----------------------------------------------------------------------
-- apply + hooks
----------------------------------------------------------------------
local function Apply(u)
	local p = u.parts()
	if not p or u.skip() then return end
	SetArt(u, p)
	SetCombatArt(u, p)
	if u.useMirror then
		Mirror(u, p)
		Texts(u, p)
		return
	end
	if p.mask then p.mask:Hide() end
	SetFill(u, p)
	Texts(u, p)
	Layout(u, p)
end

local function Hook(u)
	if u.hooked then return end
	local p = u.parts()
	if not p then return end
	u.hooked = true
	-- whenever Blizzard puts its own art, fill, colour or positions back, redo ours
	hooksecurefunc(p.art, "SetAtlas", function() SetArt(u, p) end)
	if p.flash then hooksecurefunc(p.flash, "SetAtlas", function() SetCombatArt(u, p) end) end
	if not u.useMirror then
		hooksecurefunc(p.bar, "SetStatusBarTexture", function(_, t) if t ~= FILL then SetFill(u, p) end end)
		if p.bar.SetStatusBarAtlas then hooksecurefunc(p.bar, "SetStatusBarAtlas", function() SetFill(u, p) end) end
		hooksecurefunc(p.bar, "SetStatusBarColor", function() SetFill(u, p) end)
		if p.mask then hooksecurefunc(p.mask, "Show", function(m) m:Hide() end) end
	end
	if p.name then hooksecurefunc(p.name, "SetPoint", function() Texts(u, p) end) end
	if p.nameBg then
		hooksecurefunc(p.nameBg, "SetAlpha", function(t, a) if a ~= 0 then t:SetAlpha(0) end end)
	end
	if u.unit == "player" then
		local again = function() Apply(u) end
		if PlayerFrame_ToPlayerArt then hooksecurefunc("PlayerFrame_ToPlayerArt", again) end
		if PlayerFrame_UpdateHealthBarVisuals then hooksecurefunc("PlayerFrame_UpdateHealthBarVisuals", again) end
	end
end


----------------------------------------------------------------------
-- bar text: what the health and power bars show, by the mode picked in the
-- options. Values can be "secret" on this client: they are never tested or
-- compared here, only handed to the font strings inside pcall.
----------------------------------------------------------------------
local textBars = {} -- bar -> { unit = "player"/"target", health = true for health bars }

local function Values(info)
	local unit = info.unit
	if info.health then return UnitHealth(unit), UnitHealthMax(unit) end
	return UnitPower(unit), UnitPowerMax(unit)
end

-- returns whether it worked, and the bar's fill as 0-100
local function Percent(info)
	local unit = info.unit
	local curve = CurveConstants and CurveConstants.ScaleTo100
	local ok, v = false, nil
	if curve then
		if info.health and UnitHealthPercent then
			ok, v = pcall(UnitHealthPercent, unit, true, curve)
		elseif not info.health and UnitPowerPercent then
			ok, v = pcall(UnitPowerPercent, unit, nil, false, curve)
		end
	end
	if not ok then
		ok, v = pcall(function()
			local cur, max = Values(info)
			return max > 0 and cur / max * 100 or 0
		end)
	end
	return ok, v
end

local function Put(fs, fmt, ...)
	return (pcall(fs.SetFormattedText, fs, fmt, ...))
end

local function ShowText(bar)
	local info, centre = textBars[bar], bar.TextString
	if not (info and centre) then return end
	local left, right = bar.LeftText, bar.RightText
	-- only when the game is showing text on this bar at all (always, or on mouseover)
	if not (centre:IsShown() or (left and left:IsShown()) or (right and right:IsShown())) then return end

	local mode = ns.db.healthTextMode or "remaining"
	local cur, max = Values(info)
	local wantPct = mode == "percent" or mode == "fullpercent"
	local okPct, pct = false, nil
	if wantPct then okPct, pct = Percent(info) end

	-- Both: percentage on the left, value on the right. Like the game, only
	-- health and mana get the percentage; rage, energy and the like show the value alone.
	if mode == "fullpercent" and left and right then
		local pctToo = info.health or UnitPowerType(info.unit) == 0
		if okPct or not pctToo then
			centre:Hide()
			right:Show()
			left:SetShown(pctToo)
			if (not pctToo or Put(left, "%.0f%%", pct)) and Put(right, "%d", cur) then return end
		end
	end

	-- everything else: one centred text
	if left then left:Hide() end
	if right then right:Hide() end
	centre:Show()
	if mode == "none" then
		centre:SetText("")
	elseif mode == "full" and Put(centre, "%d / %d", cur, max) then
		return
	elseif wantPct and okPct and Put(centre, "%.0f%%", pct) then
		return
	else
		Put(centre, "%d", cur)
	end
end

-- Blizzard writes "200 / 200" before our hook exists and doesn't touch the text
-- again until the value changes or the bar is moused over, so write ours directly.
-- Blizzard's own update is not called from here: run from addon code it hides the
-- left/right texts and then fails on the secret values, leaving the bar blank.
-- The power bars themselves are left exactly as the game makes them (size,
-- texture, colours), like BetterBlizzFrames does. Only their texts are placed:
-- with the thick art they are pinned to the power slot drawn in that art, a few
-- pixels in from each end, on both frames (the target's art is mirrored).
-- Without the thick art the game's own text positions are kept.
local TEXT_INSET = 4

local function AnchorPowerTexts(bar, info)
	if not ns.loaded.thickFrames then return end
	local u = units[info.unit]
	local p = u and u.parts()
	local art = p and p.art
	if not art then return end
	local l, r = WIN_LEFT, WIN_RIGHT
	if u.mirrored then l, r = 198 - WIN_RIGHT, 198 - WIN_LEFT end
	local mid = -(POW_TOP + POW_BOTTOM) / 2
	local function pin(fs, point, x)
		if not fs then return end
		fs:ClearAllPoints()
		fs:SetPoint(point, art, "TOPLEFT", x, mid)
	end
	pin(bar.TextString, "CENTER", (l + r) / 2)
	pin(bar.LeftText, "LEFT", l + TEXT_INSET)
	pin(bar.RightText, "RIGHT", r - TEXT_INSET)
end

local function RefreshTexts()
	for bar, info in pairs(textBars) do
		if not info.health then AnchorPowerTexts(bar, info) end
		ShowText(bar)
	end
end
ns.RefreshBarTexts = RefreshTexts

local function HookText(bar, unit, health)
	if not bar or bar.tphTextHooked then return end
	bar.tphTextHooked = true
	textBars[bar] = { unit = unit, health = health }
	if bar.UpdateTextStringWithValues then
		hooksecurefunc(bar, "UpdateTextStringWithValues", ShowText)
	elseif bar.UpdateTextString then
		hooksecurefunc(bar, "UpdateTextString", ShowText)
	end
end

local function HookAllTexts()
	if PlayerFrame_GetHealthBarContainer then
		local hp = PlayerFrame_GetHealthBarContainer()
		HookText(hp and hp.HealthBar, "player", true)
	end
	if PlayerFrame_GetManaBar then
		HookText(PlayerFrame_GetManaBar(), "player", false)
	end
	local main = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
	if main then
		HookText(main.HealthBarsContainer and main.HealthBarsContainer.HealthBar, "target", true)
		HookText(main.ManaBar, "target", false)
	end
	-- now, and again once the frames have finished their own login setup
	RefreshTexts()
	C_Timer.After(0.5, RefreshTexts)
	C_Timer.After(2, RefreshTexts)
end


----------------------------------------------------------------------
-- bar numbers: Expressway font with a thin black outline (like Details!/ElvUI).
-- If the font file is missing, the game's own font is used.
----------------------------------------------------------------------
local FONT = MEDIA .. "Expressway.ttf"
local HEALTH_SIZE, POWER_SIZE = 15, 11
local FLAGS = "OUTLINE"

local function Outline(fs)
	if not fs or fs.tphBusy or not fs.tphSize then return end
	local want = fs.tphSize
	local font, size, flags = fs:GetFont()
	if font == FONT and flags == FLAGS and size and math.abs(size - want) < 0.5 then return end
	fs.tphBusy = true
	local ok = fs:SetFont(FONT, want, FLAGS)
	if ok == false or (ok == nil and fs:GetFont() ~= FONT) then
		-- the font file isn't there: from now on use the game's font
		FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
		fs:SetFont(FONT, want, FLAGS)
	end
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs.tphBusy = false
end

local function OutlineBar(bar, size)
	if not bar then return end
	for _, fs in ipairs({ bar.TextString, bar.LeftText, bar.RightText }) do
		if fs then
			fs.tphSize = size
			Outline(fs)
			if not fs.tphFontHooked then
				fs.tphFontHooked = true
				hooksecurefunc(fs, "SetFontObject", Outline)
			end
		end
	end
end

local function OutlineAll()
	if PlayerFrame_GetHealthBarContainer then
		local hp = PlayerFrame_GetHealthBarContainer()
		OutlineBar(hp and hp.HealthBar, HEALTH_SIZE)
	end
	if PlayerFrame_GetManaBar then OutlineBar(PlayerFrame_GetManaBar(), POWER_SIZE) end
	local main = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
	if main then
		OutlineBar(main.HealthBarsContainer and main.HealthBarsContainer.HealthBar, HEALTH_SIZE)
		OutlineBar(main.ManaBar, POWER_SIZE)
	end
end
ns.RefreshBarFonts = function()
	if ns.loaded.barFont then OutlineAll() end
end

----------------------------------------------------------------------
-- resting / combat pulse: keep it on the portrait ring only, so no line
-- pulses across the health bar
----------------------------------------------------------------------
local function TrimStatusGlow()
	local main = PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
	local status = main and main.StatusTexture
	local art = PlayerFrame and PlayerFrame.PlayerFrameContainer and PlayerFrame.PlayerFrameContainer.FrameTexture
	if not (status and art) or status.tphMask then return end
	local mask = main:CreateMaskTexture()
	mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetPoint("TOPLEFT", art, "TOPLEFT", -40, 40)
	mask:SetPoint("BOTTOMRIGHT", art, "BOTTOMLEFT", 70, -40) -- portrait ring ends ~70 in
	status:AddMaskTexture(mask)
	status.tphMask = mask
end

----------------------------------------------------------------------
-- skull targets: the level number of the previous target could stay visible
-- on top of the skull, so it is hidden whenever the skull is showing
----------------------------------------------------------------------
local skullHooked = false

local function FixSkullLevel()
	local content = TargetFrame and TargetFrame.TargetFrameContent
	local main = content and content.TargetFrameContentMain
	local contextual = content and content.TargetFrameContentContextual
	local level = main and main.LevelText
	local skull = contextual and contextual.HighLevelTexture
	if not (level and skull) then return end
	if not skullHooked then
		skullHooked = true
		hooksecurefunc(skull, "Show", function() level:Hide() end)
		hooksecurefunc(level, "Show", function(self) if skull:IsShown() then self:Hide() end end)
	end
	if skull:IsShown() then level:Hide() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterUnitEvent("UNIT_FACTION", "target")
f:SetScript("OnEvent", function(self, event)
	-- only what was enabled at login runs; changes apply on the next reload
	if not ns.loaded.thickFrames then
		self:UnregisterAllEvents()
		if ns.loaded.currentValueText then HookAllTexts() end
		if ns.loaded.barFont then OutlineAll() end
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then
			pending = false
			for _, u in pairs(units) do Apply(u) end
		end
	elseif event == "PLAYER_TARGET_CHANGED" or event == "UNIT_FACTION" then
		Apply(units.target)
		FixSkullLevel()
		C_Timer.After(0, function()
			Apply(units.target)
			FixSkullLevel()
		end)
	else
		for _, u in pairs(units) do
			Hook(u)
			Apply(u)
		end
		if ns.loaded.currentValueText then HookAllTexts() end
		if ns.loaded.barFont then OutlineAll() end
		TrimStatusGlow()
		C_Timer.After(0.5, function() for _, u in pairs(units) do Apply(u) end end)
	end
end)
