-- Kindouse Tweaks: action bars
-- Colours action button icons when the action is out of range, when you lack the
-- mana/energy/rage for it, or when it is unusable. The method is tullaRange's
-- (MIT licence, Copyright (c) 2010 Jason Greer): re-tint the icon after
-- Blizzard's own usable/range updates, which are event driven on this client.

local ADDON, ns = ...

-- r, g, b, opacity, desaturate
local DEFAULTS = {
	oor = { 1, 0.3, 0.1, 1, desaturate = true },
	oom = { 0.1, 0.3, 1, 1, desaturate = true },
	unusable = { 0.4, 0.4, 0.4, 1, desaturate = false },
}
local NORMAL = { 1, 1, 1, 1, desaturate = false }

local colors

local function Colors()
	if colors then return colors end
	if type(ns.db.rangeColors) ~= "table" then ns.db.rangeColors = {} end
	colors = ns.db.rangeColors
	for state, d in pairs(DEFAULTS) do
		if type(colors[state]) ~= "table" then
			colors[state] = { d[1], d[2], d[3], d[4], desaturate = d.desaturate }
		end
	end
	return colors
end

local function Tint(icon, state)
	local c = state == "normal" and NORMAL or colors[state]
	icon:SetVertexColor(c[1], c[2], c[3], c[4])
	icon:SetDesaturated(c.desaturate)
end

----------------------------------------------------------------------
-- what state is an action in
----------------------------------------------------------------------
local function ActionState(slot)
	local actionType, id = GetActionInfo(slot)
	local usable, noMana
	-- macros named with a leading "#": judge by the spell the macro would cast
	if actionType == "macro" and C_Spell and C_Spell.IsSpellUsable then
		local name = GetMacroInfo(id)
		if name and name:sub(1, 1) == "#" then
			local spellID = GetMacroSpell(id)
			if spellID then usable, noMana = C_Spell.IsSpellUsable(spellID) end
		end
	end
	if usable == nil then usable, noMana = IsUsableAction(slot) end
	local outOfRange = IsActionInRange(slot) == false
	if usable then return outOfRange and "oor" or "normal", outOfRange end
	return noMana and "oom" or "unusable", outOfRange
end

local function PetActionState(index)
	local _, _, _, _, _, _, spellID, checksRange, inRange = GetPetActionInfo(index)
	local outOfRange = checksRange and not inRange
	local usable, noMana
	if spellID and C_Spell and C_Spell.IsSpellUsable then
		usable, noMana = C_Spell.IsSpellUsable(spellID)
	else
		usable, noMana = GetPetActionSlotUsable(index), false
	end
	if usable then return outOfRange and "oor" or "normal" end
	return noMana and "oom" or "unusable"
end

----------------------------------------------------------------------
-- buttons
----------------------------------------------------------------------
local active = false
local states = {}     -- icon / hotkey -> current state
local registered = {}

local function UpdateButton(button)
	if not (button.action and button.icon) then return end
	local state, outOfRange = ActionState(button.action)
	states[button.icon] = state
	Tint(button.icon, state)
	local hotkey = button.HotKey
	if hotkey then
		local hk = outOfRange and "oor" or "normal"
		states[hotkey] = hk
		local c = hk == "normal" and NORMAL or colors[hk]
		hotkey:SetVertexColor(c[1], c[2], c[3])
	end
end

-- Blizzard tells us when a slot goes in or out of range
local function UpdateRange(button, checksRange, inRange)
	if not registered[button] then return end
	local oor = checksRange and not inRange
	local icon = button.icon
	local s = icon and states[icon]
	if s == "normal" and oor then
		states[icon] = "oor"
		Tint(icon, "oor")
	elseif s == "oor" and not oor then
		states[icon] = "normal"
		Tint(icon, "normal")
	end
	local hotkey = button.HotKey
	local hs = hotkey and states[hotkey]
	if hs == "normal" and oor then
		states[hotkey] = "oor"
		hotkey:SetVertexColor(colors.oor[1], colors.oor[2], colors.oor[3])
	elseif hs == "oor" and not oor then
		states[hotkey] = "normal"
		hotkey:SetVertexColor(1, 1, 1)
	end
end

local function Register(button)
	if registered[button] or not button.UpdateUsable then return end
	registered[button] = true
	hooksecurefunc(button, "UpdateUsable", UpdateButton)
end

local function UpdatePetBar(bar)
	if not (PetHasActionBar and PetHasActionBar()) then return end
	for index, button in pairs(bar.actionButtons) do
		if button.icon and button.icon:IsVisible() then
			Tint(button.icon, PetActionState(index))
		end
	end
end

local updateQueued = false
local function RequestUpdate()
	if not active or updateQueued then return end
	updateQueued = true
	C_Timer.After(1 / 30, function()
		updateQueued = false
		ActionBarButtonEventsFrame:ForEachFrame(UpdateButton)
		if PetActionBar and PetActionBar.actionButtons then UpdatePetBar(PetActionBar) end
	end)
end

local function Enable()
	if active then return end
	if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("tullaRange") then
		ns.Print("tullaRange is also enabled, so the built-in range colouring is switched off. Disable tullaRange to use this one.")
		return
	end
	if not (ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.ForEachFrame and ActionButton_UpdateRangeIndicator) then
		ns.Print("range colouring isn't supported on this game version.")
		return
	end
	active = true
	ActionBarButtonEventsFrame:ForEachFrame(Register)
	hooksecurefunc(ActionBarButtonEventsFrame, "RegisterFrame", function(_, button) Register(button) end)
	hooksecurefunc("ActionButton_UpdateRangeIndicator", UpdateRange)

	if PetActionBar and PetActionBar.actionButtons and PetActionBar.Update then
		hooksecurefunc(PetActionBar, "Update", UpdatePetBar)
		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_POWER_UPDATE", "pet")
		f:SetScript("OnEvent", function() UpdatePetBar(PetActionBar) end)
	end
	RequestUpdate()
end

----------------------------------------------------------------------
-- colour settings, shown under the checkbox in the options window:
-- one row per state with a live preview, quick presets and a full picker
----------------------------------------------------------------------
local ROWS = {
	{ state = "oor", label = "Out of range", icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
	{ state = "oom", label = "Not enough mana", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
	{ state = "unusable", label = "Unusable", icon = "Interface\\Icons\\Ability_Warrior_Charge" },
}

local PRESETS = {
	{ 1, 0.3, 0.1 }, { 1, 0.1, 0.1 }, { 1, 0.8, 0.1 }, { 0.2, 0.9, 0.2 },
	{ 0.1, 0.3, 1 }, { 0.6, 0.3, 1 }, { 0.4, 0.4, 0.4 },
}

local rows = {}

local function RefreshRows()
	Colors()
	for _, row in ipairs(rows) do
		local c = colors[row.state]
		row.tex:SetVertexColor(c[1], c[2], c[3], c[4])
		row.tex:SetDesaturated(c.desaturate)
		row.desat:SetChecked(c.desaturate)
	end
end

local function Changed()
	RefreshRows()
	RequestUpdate()
end

local function OpenPicker(state)
	local c = colors[state]
	local pr, pg, pb, pa = c[1], c[2], c[3], c[4]
	local function set(r, g, b, a)
		c[1], c[2], c[3], c[4] = r, g, b, a
		Changed()
	end
	local function cancel() set(pr, pg, pb, pa) end
	if ColorPickerFrame.SetupColorPickerAndShow then
		local function pick()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			set(r, g, b, ColorPickerFrame:GetColorAlpha())
		end
		ColorPickerFrame:SetupColorPickerAndShow({
			r = pr, g = pg, b = pb, opacity = pa, hasOpacity = true,
			swatchFunc = pick, opacityFunc = pick, cancelFunc = cancel,
		})
	else
		local function pick()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			set(r, g, b, 1 - OpacitySliderFrame:GetValue())
		end
		ColorPickerFrame:Hide()
		ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = true, 1 - pa
		ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = pick, pick, cancel
		ColorPickerFrame:SetColorRGB(pr, pg, pb)
		ColorPickerFrame:Show()
	end
end

local function Tip(widget, title, text)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- returns the y below what it added
local function BuildColors(parent, x, y)
	Colors()
	for _, info in ipairs(ROWS) do
		local row = { state = info.state }

		local preview = CreateFrame("Button", nil, parent)
		preview:SetSize(26, 26)
		preview:SetPoint("TOPLEFT", x, y)
		row.tex = preview:CreateTexture(nil, "ARTWORK")
		row.tex:SetAllPoints()
		row.tex:SetTexture(info.icon)
		row.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		preview:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		preview:SetScript("OnClick", function() OpenPicker(info.state) end)
		Tip(preview, info.label, "This is how the button will look. Click to pick any colour and opacity.")

		local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", preview, "RIGHT", 8, 0)
		label:SetText(info.label)

		for i, p in ipairs(PRESETS) do
			local chip = CreateFrame("Button", nil, parent)
			chip:SetSize(14, 14)
			chip:SetPoint("LEFT", preview, "RIGHT", 108 + (i - 1) * 17, 0)
			local edge = chip:CreateTexture(nil, "BACKGROUND")
			edge:SetAllPoints()
			edge:SetColorTexture(0, 0, 0, 1)
			local fill = chip:CreateTexture(nil, "ARTWORK")
			fill:SetPoint("TOPLEFT", 1, -1)
			fill:SetPoint("BOTTOMRIGHT", -1, 1)
			fill:SetColorTexture(p[1], p[2], p[3], 1)
			chip:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			chip:SetScript("OnClick", function()
				local c = colors[info.state]
				c[1], c[2], c[3] = p[1], p[2], p[3]
				Changed()
			end)
		end

		row.desat = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		row.desat:SetSize(22, 22)
		row.desat:SetPoint("LEFT", preview, "RIGHT", 108 + #PRESETS * 17 + 6, 0)
		local dl = row.desat:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		dl:SetPoint("LEFT", row.desat, "RIGHT", 0, 0)
		dl:SetText("Grey")
		row.desat:SetHitRectInsets(0, -dl:GetStringWidth(), 0, 0)
		row.desat:SetScript("OnClick", function(self)
			colors[info.state].desaturate = self:GetChecked() and true or false
			Changed()
		end)
		Tip(row.desat, "Grey out the icon", "Removes the icon's own colours before tinting it, so the tint reads clearly on any icon.")

		rows[#rows + 1] = row
		y = y - 31
	end

	local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	reset:SetSize(110, 20)
	reset:SetPoint("TOPLEFT", x, y - 1)
	reset:SetText("Reset colours")
	reset:SetScript("OnClick", function()
		for state, d in pairs(DEFAULTS) do
			local c = colors[state]
			c[1], c[2], c[3], c[4], c.desaturate = d[1], d[2], d[3], d[4], d.desaturate
		end
		Changed()
	end)
	return y - 28
end

ns.Register({
	key = "buttonRange",
	category = "Action Bars",
	label = "Colour buttons by range, mana and usability",
	tooltip = "Tints action button icons when the action is out of range, when you don't have the mana, energy or rage for it, or when it can't be used. Colour changes below apply straight away.",
	default = true,
	reload = true,
	apply = function(enabled)
		Colors()
		if enabled then Enable() end
	end,
	build = BuildColors,
	refresh = RefreshRows,
})
