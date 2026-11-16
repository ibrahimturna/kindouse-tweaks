-- Kindouse Tweaks: options window, minimap button and slash command

local ADDON, ns = ...

local ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local WIDTH, PAD, ROW = 430, 16, 26
local TOP, BOTTOM, MAX_HEIGHT = 44, 46, 560 -- title strip, footer strip, tallest the window gets

----------------------------------------------------------------------
-- options window (built on first open, from the registered settings)
----------------------------------------------------------------------
local frame

local function Refresh()
	if not frame then return end
	for _, cb in ipairs(frame.checks) do cb:SetChecked(ns.Get(cb.key)) end
	for _, def in ipairs(ns.settings) do
		if def.refresh then def.refresh() end
	end
	local need = ns.NeedsReload()
	frame.reload:SetEnabled(need)
	frame.note:SetText(need and "|cffff5555Reload the UI to apply your changes.|r" or "|cff808080* needs a UI reload|r")
end

local function Build()
	frame = CreateFrame("Frame", "KindouseTweaksOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH") -- below the colour picker, which is a dialog
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

	-- the settings scroll, so the window stays a sensible height as tweaks are added
	local scroll = CreateFrame("ScrollFrame", "KindouseTweaksOptionsScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -TOP)
	scroll:SetPoint("BOTTOMRIGHT", -30, BOTTOM)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH - 30, 1)
	scroll:SetScrollChild(content)

	frame.checks = {}
	local y = -4
	local category
	for _, def in ipairs(ns.settings) do
		if def.category ~= category then
			category = def.category
			if #frame.checks > 0 then y = y - 8 end
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
		cb:SetPoint("TOPLEFT", PAD, y)
		cb.key = def.key
		local label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		label:SetText(def.label .. (def.reload and " |cff808080*|r" or ""))
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
		frame.checks[#frame.checks + 1] = cb
		y = y - ROW
		-- a setting can add its own controls under its checkbox
		if def.build then y = def.build(content, PAD + 28, y - 2) - 4 end
	end
	content:SetHeight(-y + 4)

	frame.note = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.note:SetPoint("BOTTOMLEFT", PAD, PAD + 5)

	frame.reload = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.reload:SetSize(96, 22)
	frame.reload:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	frame.reload:SetText("Reload UI")
	frame.reload:SetScript("OnClick", ReloadUI)

	frame:SetSize(WIDTH, math.min(-y + 4 + TOP + BOTTOM, MAX_HEIGHT))
	frame:Hide()
end

function ns.ToggleOptions()
	if not ns.db then return end
	if not frame then Build() end
	if frame:IsShown() then
		frame:Hide()
	else
		Refresh()
		frame:Show()
	end
end

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
SlashCmdList.KINDOUSETWEAKS = function() ns.ToggleOptions() end

function KindouseTweaks_OnAddonCompartmentClick()
	ns.ToggleOptions()
end
