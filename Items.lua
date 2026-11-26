-- Kindouse Tweaks: items
-- * Item level in the item tooltip, right below the name (like Wowhead).
-- * Quality-colored borders on items in the bags, bank, character panel and
--   inspect window: green items get a green border, blue a blue one and so on.
--   Same technique as Tae's Item Quality Glow / GearBorderColor: the action
--   button border texture, tinted by quality and drawn additively.

local ADDON, ns = ...

local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetDetailedLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local QualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor

----------------------------------------------------------------------
-- item level in tooltips
----------------------------------------------------------------------
-- gear that is worn, apart from shirts and tabards
local SKIP = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true }

local function IsGear(link)
	if not GetInstant then return false end
	local _, _, _, equipLoc, _, classID = GetInstant(link)
	return (classID == 2 or classID == 4) and type(equipLoc) == "string" and equipLoc ~= "" and not SKIP[equipLoc]
end

local function ItemLevel(link)
	local level = GetDetailedLevel and GetDetailedLevel(link)
	if not level and GetInfo then level = select(4, GetInfo(link)) end
	return level
end

local LEVEL_FORMAT = ITEM_LEVEL or "Item Level %d"
local LEVEL_COLOR = "|cffffd100" -- the game's yellow, as in the game's own item level line

local function AddLevel(tooltip)
	if not (ns.Get("itemLevels") and tooltip and tooltip.GetItem) then return end
	local ok, _, link = pcall(tooltip.GetItem, tooltip)
	if not (ok and type(link) == "string" and IsGear(link)) then return end
	local level = ItemLevel(link)
	if not level or level <= 1 then return end
	local text = LEVEL_FORMAT:format(level)

	local name = tooltip:GetName()
	local second = name and _G[name .. "TextLeft2"]
	if second and tooltip:NumLines() >= 2 then
		local old = second:GetText() or ""
		if old:find(text, 1, true) then return end -- already there (the game's own, or ours)
		-- the line under the name gets the item level on top of it, so the
		-- level sits right below the name
		second:SetText(LEVEL_COLOR .. text .. "|r\n" .. old)
	else
		tooltip:AddLine(text, 1, 0.82, 0)
	end
	tooltip:Show() -- resize to fit
end

local function HookTooltips()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddLevel)
		return
	end
	for _, tip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
		if tip and tip.HasScript and tip:HasScript("OnTooltipSetItem") then
			tip:HookScript("OnTooltipSetItem", AddLevel)
		end
	end
end

----------------------------------------------------------------------
-- quality borders
----------------------------------------------------------------------
local borders = {} -- button -> border texture

local function Border(button, quality)
	if not button then return end
	local border = borders[button]
	-- items of uncommon (green) quality and up. Drawn also where the game has
	-- its own thin quality border: that one alone is hard to notice.
	if not (ns.Get("qualityBorders") and quality and quality >= 2 and QualityColor) then
		if border then border:Hide() end
		return
	end
	if not border then
		border = button:CreateTexture(nil, "OVERLAY")
		border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		border:SetBlendMode("ADD")
		border:SetAlpha(1)
		local w = button:GetWidth()
		if not w or w <= 0 then w = 37 end
		border:SetSize(w * 1.85, w * 1.85)
		border:SetPoint("CENTER", button, "CENTER")
		borders[button] = border
	end
	local r, g, b = QualityColor(quality)
	border:SetVertexColor(r, g, b)
	border:Show()
end

-- bags and bank
local Container = C_Container or {}

local function BagQuality(bag, slot)
	if Container.GetContainerItemInfo then
		local info = Container.GetContainerItemInfo(bag, slot)
		return info and info.quality
	elseif GetContainerItemInfo then
		return select(4, GetContainerItemInfo(bag, slot))
	end
end

local function BagLink(bag, slot)
	if Container.GetContainerItemLink then return Container.GetContainerItemLink(bag, slot) end
	if GetContainerItemLink then return GetContainerItemLink(bag, slot) end
end

-- weapons and armor (anything you can wear)
local function IsEquipment(link)
	if not (link and GetInstant) then return false end
	local _, _, _, equipLoc, _, classID = GetInstant(link)
	return (classID == 2 or classID == 4) and type(equipLoc) == "string" and equipLoc ~= ""
		and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

local function BorderSlot(button, bag, slot)
	local quality = bag and slot and BagQuality(bag, slot)
	if quality and ns.Get("qualityBordersGearOnly") and not IsEquipment(BagLink(bag, slot)) then
		quality = nil
	end
	Border(button, quality)
end

-- every item button of a bag window, whichever bag frame layout the game uses
local function UpdateBagFrame(frame)
	if not (frame and frame:IsShown()) then return end
	if frame.EnumerateValidItems then
		for _, button in frame:EnumerateValidItems() do
			local bag = button.GetBagID and button:GetBagID() or button:GetParent():GetID()
			BorderSlot(button, bag, button:GetID())
		end
	elseif frame:GetName() then
		local name, bag = frame:GetName(), frame:GetID()
		for i = 1, frame.size or 36 do
			local button = _G[name .. "Item" .. i]
			if button and button:IsShown() then BorderSlot(button, bag, button:GetID()) end
		end
	end
end

local bagFrames = {}

local function UpdateBags()
	for _, frame in ipairs(bagFrames) do pcall(UpdateBagFrame, frame) end
end

local function UpdateBank()
	if not (BankFrame and BankFrame:IsShown()) then return end
	for i = 1, NUM_BANKGENERIC_SLOTS or 28 do
		local button = _G["BankFrameItem" .. i]
		if button then BorderSlot(button, BANK_CONTAINER or -1, button:GetID()) end
	end
end

local function HookBags()
	for i = 1, NUM_CONTAINER_FRAMES or 13 do
		local frame = _G["ContainerFrame" .. i]
		if frame then bagFrames[#bagFrames + 1] = frame end
	end
	if ContainerFrameCombinedBags then bagFrames[#bagFrames + 1] = ContainerFrameCombinedBags end
	for _, frame in ipairs(bagFrames) do
		frame:HookScript("OnShow", function(self) pcall(UpdateBagFrame, self) end)
		if frame.UpdateItems then
			hooksecurefunc(frame, "UpdateItems", function(self) pcall(UpdateBagFrame, self) end)
		end
	end
	if ContainerFrame_Update then
		hooksecurefunc("ContainerFrame_Update", function(frame) pcall(UpdateBagFrame, frame) end)
	end
	if BankFrameItemButton_Update then
		hooksecurefunc("BankFrameItemButton_Update", function(button)
			if button and not button.isBag then
				BorderSlot(button, button:GetParent():GetID(), button:GetID())
			end
		end)
	end
end

-- character panel and inspect window
local function BorderWorn(button, unit)
	if not (button and unit) then return end
	local slot = button:GetID()
	Border(button, GetInventoryItemLink(unit, slot) and GetInventoryItemQuality(unit, slot))
end

local SLOTS = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
	"Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged",
}

local function UpdateCharacter()
	for _, name in ipairs(SLOTS) do BorderWorn(_G["Character" .. name .. "Slot"], "player") end
end

local function UpdateInspect()
	local unit = InspectFrame and InspectFrame:IsShown() and InspectFrame.unit
	if not unit then return end
	for _, name in ipairs(SLOTS) do BorderWorn(_G["Inspect" .. name .. "Slot"], unit) end
end

local function HookInspect()
	if not InspectPaperDollItemSlotButton_Update then return false end
	hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
		BorderWorn(button, InspectFrame and InspectFrame.unit)
	end)
	return true
end

local function UpdateAll()
	UpdateBags()
	UpdateBank()
	UpdateCharacter()
	UpdateInspect()
end

-- item data can arrive after the window is drawn: refresh once it is in
local pending = false
local function UpdateSoon()
	if pending then return end
	pending = true
	C_Timer.After(0.2, function()
		pending = false
		if ns.Get("qualityBorders") then UpdateAll() end
	end)
end

----------------------------------------------------------------------
-- events and settings
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:RegisterEvent("INSPECT_READY")
local inspectHooked = false
f:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_LOGIN" then
		HookTooltips()
		HookBags()
		if PaperDollItemSlotButton_Update then
			hooksecurefunc("PaperDollItemSlotButton_Update", function(button) BorderWorn(button, "player") end)
		end
		inspectHooked = HookInspect()
	elseif event == "ADDON_LOADED" then
		if name == "Blizzard_InspectUI" and not inspectHooked then inspectHooked = HookInspect() end
	elseif ns.Get("qualityBorders") then
		UpdateSoon()
	end
end)

ns.Register({
	key = "itemLevels",
	category = "Items",
	new = true,
	label = "Item level in item tooltips",
	tooltip = "Shows the item level of gear right below its name in the item tooltip, like Wowhead does.",
	default = false,
})

ns.Register({
	key = "qualityBorders",
	category = "Items",
	new = true,
	label = "Quality-colored borders on items",
	tooltip = "Puts a border in the item's quality color around items in your bags, bank, character panel and the inspect window: green for uncommon, blue for rare, purple for epic and so on.",
	default = false,
	apply = function(enabled, isLogin)
		if isLogin then return end
		if enabled then
			UpdateAll()
		else
			for _, border in pairs(borders) do border:Hide() end
		end
	end,
})

ns.Register({
	key = "qualityBordersGearOnly",
	category = "Items",
	new = true,
	parent = "qualityBorders",
	label = "Only on equipment",
	tooltip = "Borders only go on weapons and armor. Trade goods, consumables, quest items and the like are left without one.",
	default = false,
	apply = function(_, isLogin)
		if not isLogin and ns.Get("qualityBorders") then UpdateAll() end
	end,
})
