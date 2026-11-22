-- Kindouse Tweaks: minimap clock
-- Bigger text on the minimap clock, without changing the minimap's size. The
-- size is set with a slider in the options and shows while you drag it.

local ADDON, ns = ...

local MIN_SIZE, MAX_SIZE, DEFAULT_SIZE = 10, 24, 16
local MARGIN = 4 -- gap between the time and the right edge of its box

local original -- the game's own font, box width and text anchor, to put back

local function Size()
	local size = ns.db and tonumber(ns.db.clockSize) or DEFAULT_SIZE
	return math.max(MIN_SIZE, math.min(MAX_SIZE, math.floor(size + 0.5)))
end

local function Remember(text, button)
	if original then return end
	local font, size, flags = text:GetFont()
	original = {
		font = font, size = size, flags = flags,
		width = button:GetWidth(),
		point = text:GetNumPoints() > 0 and { text:GetPoint(1) } or nil,
	}
end

local function Apply()
	local text, button = TimeManagerClockTicker, TimeManagerClockButton
	if not (text and button) then return end -- the clock isn't loaded yet
	if ns.Get("bigClock") then
		Remember(text, button)
		text:SetFont(original.font or STANDARD_TEXT_FONT, Size(), original.flags or "")
		-- the box grows to the left with the text, the time keeps a gap on the right
		button:SetWidth(math.max(original.width, text:GetStringWidth() + MARGIN * 2 + 4))
		text:ClearAllPoints()
		text:SetPoint("RIGHT", button, "RIGHT", -MARGIN, 0)
	elseif original then
		text:SetFont(original.font, original.size, original.flags or "")
		button:SetWidth(original.width)
		if original.point then
			text:ClearAllPoints()
			text:SetPoint(unpack(original.point))
		end
	end
end

-- the time gets wider or narrower as it changes (9:59 to 10:00)
local hooked = false
local function Hook()
	if hooked or not TimeManagerClockButton_Update then return end
	hooked = true
	hooksecurefunc("TimeManagerClockButton_Update", function()
		if ns.Get("bigClock") then Apply() end
	end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name ~= "Blizzard_TimeManager" then return end
	if not ns.Get("bigClock") then return end
	Hook()
	Apply()
end)

----------------------------------------------------------------------
-- size slider under the checkbox
----------------------------------------------------------------------
local slider, valueText, sliderLabel

local function BuildSlider(parent, x, y)
	sliderLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sliderLabel:SetPoint("TOPLEFT", x, y)
	sliderLabel:SetText("Clock text size")

	slider = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(200, 17)
	slider:SetPoint("TOPLEFT", x, y - 16)
	if slider.SetBackdrop then
		slider:SetBackdrop({
			bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
			edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
			tile = true, tileSize = 8, edgeSize = 8,
			insets = { left = 3, right = 3, top = 6, bottom = 6 },
		})
	end
	slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	slider:SetMinMaxValues(MIN_SIZE, MAX_SIZE)
	slider:SetValueStep(1)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	slider:EnableMouseWheel(true)

	valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)

	slider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		valueText:SetText(value)
		if not ns.db or ns.db.clockSize == value then return end
		ns.db.clockSize = value
		Apply() -- the clock changes while you drag
	end)
	slider:SetScript("OnMouseWheel", function(self, delta)
		if self:IsEnabled() then self:SetValue(self:GetValue() + delta) end
	end)
	return y - 40
end

local function RefreshSlider()
	if not slider then return end
	slider:SetValue(Size())
	valueText:SetText(Size())
	local on = ns.Get("bigClock") and true or false
	if on then slider:Enable() else slider:Disable() end
	slider:SetAlpha(on and 1 or 0.5)
	local shade = on and 1 or 0.5
	sliderLabel:SetTextColor(shade, shade, shade)
	valueText:SetTextColor(shade, shade, shade)
end

ns.Register({
	key = "bigClock",
	category = "Minimap",
	new = true,
	label = "Bigger minimap clock",
	tooltip = "Makes the time on the minimap bigger without making the minimap bigger. Pick the size with the slider below; the clock changes as you drag it.",
	default = false,
	apply = function(enabled, isLogin)
		if isLogin then return end -- done when the clock loads
		if enabled then Hook() end
		Apply()
	end,
	build = BuildSlider,
	refresh = RefreshSlider,
})
