-- Kindouse Tweaks: options window, Options > AddOns page, minimap button and
-- slash command

local ADDON, ns = ...

local ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local WIDTH, PAD, ROW = 430, 16, 26
local TOP, BOTTOM, MAX_HEIGHT = 44, 46, 560 -- title strip, footer strip, tallest the window gets
local PANEL_TOP = 50 -- title strip of the page in the game's Options window

----------------------------------------------------------------------
-- The settings list (scroll, checkboxes, reload footer) is built once, from
-- the registered settings, and shown in whichever of the two places is open:
-- our own window, or the Kindouse Tweaks page under Options > AddOns.
----------------------------------------------------------------------
local frame, body, panel

local function Refresh()
	if not body then return end
	for _, cb in ipairs(body.checks) do
		cb:SetChecked(ns.Get(cb.key))
		if cb.parent then
			-- a sub-option only does something while its parent is on
			local on = ns.Get(cb.parent) and true or false
			cb:SetEnabled(on)
			if on then cb.label:SetTextColor(1, 1, 1) else cb.label:SetTextColor(0.5, 0.5, 0.5) end
		end
	end
	for _, def in ipairs(ns.settings) do
		if def.refresh then def.refresh() end
	end
	local need = ns.NeedsReload()
	body.reload:SetEnabled(need)
	body.note:SetText(need and "|cffff5555Reload the UI to apply your changes.|r" or "|cff808080* needs a UI reload|r")
end

local function BuildBody()
	body = CreateFrame("Frame", nil, UIParent)
	body:Hide()

	-- the settings scroll, so the list stays a sensible height as tweaks are added
	local scroll = CreateFrame("ScrollFrame", "KindouseTweaksOptionsScroll", body, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT")
	scroll:SetPoint("BOTTOMRIGHT", -30, BOTTOM)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH - 30, 1)
	scroll:SetScrollChild(content)

	-- settings flagged new = true that haven't been seen yet go first, under
	-- "New", with a NEW badge. They count as seen once shown, and from the next
	-- login or /reload they sit in their own section like the rest.
	ns.db.seen = ns.db.seen or {}
	local fresh, rest = {}, {}
	for _, def in ipairs(ns.settings) do
		if def.new and not ns.db.seen[def.key] then
			fresh[#fresh + 1] = { def = def, section = "New", isNew = true }
			ns.db.seen[def.key] = true
		else
			rest[#rest + 1] = { def = def, section = def.category }
		end
	end
	-- the rest by section, sections in the order they first appear, so one
	-- section's settings stay together even when they come from different files
	local order, sections = {}, {}
	for _, entry in ipairs(rest) do
		if not sections[entry.section] then
			sections[entry.section] = {}
			order[#order + 1] = entry.section
		end
		table.insert(sections[entry.section], entry)
	end
	for _, section in ipairs(order) do
		for _, entry in ipairs(sections[section]) do fresh[#fresh + 1] = entry end
	end

	body.checks = {}
	local y = -4
	local category
	local placed = {} -- key -> section it is listed in
	for _, entry in ipairs(fresh) do
		local def = entry.def
		if entry.section ~= category then
			category = entry.section
			if #body.checks > 0 then y = y - 8 end
			local head = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			head:SetPoint("TOPLEFT", PAD, y)
			head:SetText(category)
			local line = content:CreateTexture(nil, "ARTWORK")
			line:SetColorTexture(1, 0.82, 0, 0.25)
			line:SetHeight(1)
			line:SetPoint("TOPLEFT", PAD, y - 15)
			line:SetPoint("RIGHT", content, "RIGHT", -4, 0)
			y = y - 20
		end

		local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
		cb:SetSize(24, 24)
		-- indented under its parent when listed right with it
		local x = PAD + (entry.isNew and 30 or 0)
		if def.parent and placed[def.parent] == entry.section then x = x + 22 end
		placed[def.key] = entry.section
		cb:SetPoint("TOPLEFT", x, y)
		cb.key = def.key
		cb.parent = def.parent
		if entry.isNew then
			local badge = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			badge:SetPoint("RIGHT", cb, "LEFT", -2, 0)
			badge:SetText("NEW")
			badge:SetTextColor(0.45, 0.8, 1)
			badge:SetShadowColor(0.1, 0.5, 1, 0.9)
			badge:SetShadowOffset(0, 0)
		end
		local label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		cb.label = label
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		label:SetText(def.label .. (def.reload and " |cff808080*|r" or "")
			.. (entry.isNew and "  |cff707070(" .. def.category .. ")|r" or ""))
		cb:SetHitRectInsets(0, -label:GetStringWidth() - 4, 0, 0)
		cb:SetScript("OnClick", function(self)
			ns.Set(self.key, self:GetChecked())
			Refresh()
		end)
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(def.label, 1, 1, 1)
			if def.tooltip then GameTooltip:AddLine(def.tooltip, nil, nil, nil, true) end
			if def.reload then GameTooltip:AddLine("Needs a UI reload.", 1, 0.3, 0.3) end
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
		body.checks[#body.checks + 1] = cb
		y = y - ROW
		-- a setting can add its own controls under its checkbox
		if def.build then y = def.build(content, PAD + 28, y - 2) - 4 end
	end
	content:SetHeight(-y + 4)
	body.listHeight = -y + 4

	body.note = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	body.note:SetPoint("BOTTOMLEFT", PAD, PAD + 5)

	body.reload = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
	body.reload:SetSize(96, 22)
	body.reload:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	body.reload:SetText("Reload UI")
	body.reload:SetScript("OnClick", ReloadUI)
end

-- moves the settings list into host, below its title strip
local function Attach(host, top)
	if not body then BuildBody() end
	body:SetParent(host)
	body:SetFrameStrata(host:GetFrameStrata())
	body:SetFrameLevel(host:GetFrameLevel() + 2)
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", 0, -top)
	body:SetPoint("BOTTOMRIGHT")
	body:Show()
	Refresh()
end

----------------------------------------------------------------------
-- our own window (/ktw, minimap button)
----------------------------------------------------------------------
local function BuildWindow()
	if not body then BuildBody() end
	frame = CreateFrame("Frame", "KindouseTweaksOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH") -- below the color picker, which is a dialog
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		frame:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
		frame:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
	end
	tinsert(UISpecialFrames, "KindouseTweaksOptions") -- Escape closes it

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", PAD, -PAD)
	title:SetText(ns.title)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	frame:SetSize(WIDTH, math.min(body.listHeight + TOP + BOTTOM, MAX_HEIGHT))
	frame:Hide()
	frame:SetScript("OnShow", function() Attach(frame, TOP) end)
	-- hand the list back to the Options page if that is still open
	frame:SetScript("OnHide", function()
		if panel and panel:IsVisible() then Attach(panel, PANEL_TOP) end
	end)
end

function ns.ToggleOptions()
	if not ns.db then return end
	if not frame then BuildWindow() end
	frame:SetShown(not frame:IsShown())
end

----------------------------------------------------------------------
-- page under Esc > Options > AddOns
----------------------------------------------------------------------
local function RegisterPanel()
	if panel then return end
	panel = CreateFrame("Frame")
	panel.name = "Kindouse Tweaks"

	local title = panel:CreateFontString(nil, "ARTWORK", GameFontHighlightHuge and "GameFontHighlightHuge" or "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", PAD, -PAD)
	title:SetText(ns.title)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPRIGHT", -PAD, -PAD - 6)
	hint:SetText("|cff808080Also on /ktw and the minimap button|r")

	panel:SetScript("OnShow", function()
		if frame and frame:IsShown() then frame:Hide() end
		Attach(panel, PANEL_TOP)
	end)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end
ns.OnLoad(RegisterPanel)

----------------------------------------------------------------------
-- minimap button: click opens the menu, drag moves it around the minimap
----------------------------------------------------------------------
local button

local function PlaceButton()
	local a = math.rad(ns.db.minimapAngle or 215)
	local r = Minimap:GetWidth() / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function DragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	PlaceButton()
end

local function BuildButton()
	button = CreateFrame("Button", "KindouseTweaksMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", ns.ToggleOptions)
	button:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", DragUpdate)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(ns.title)
		GameTooltip:AddLine("Click to open the settings.", 1, 1, 1)
		GameTooltip:AddLine("Drag to move this button.", 1, 1, 1)
		GameTooltip:AddLine("/ktw", 0.5, 0.5, 0.5)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	PlaceButton()
end

ns.Register({
	key = "minimapButton",
	category = "General",
	label = "Show minimap button",
	tooltip = "The settings stay reachable with /ktw when the button is hidden.",
	default = true,
	apply = function(enabled)
		if enabled and not button then BuildButton() end
		if button then button:SetShown(enabled) end
	end,
})

----------------------------------------------------------------------
-- slash command and addon compartment
----------------------------------------------------------------------
SLASH_KINDOUSETWEAKS1 = "/ktw"
SLASH_KINDOUSETWEAKS2 = "/kindouse"
SLASH_KINDOUSETWEAKS3 = "/kindousetweaks"
SlashCmdList.KINDOUSETWEAKS = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "sparkle" or msg == "sparkles" then
		if ns.SparkleReport then ns.SparkleReport() end
	else
		ns.ToggleOptions()
	end
end

function KindouseTweaks_OnAddonCompartmentClick()
	ns.ToggleOptions()
end
