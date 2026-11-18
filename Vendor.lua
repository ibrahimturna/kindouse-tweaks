-- Kindouse Tweaks: vendors
-- When a merchant window opens: repair everything, and sell grey (poor quality) items.

local ADDON, ns = ...

local function Money(copper)
	if GetMoneyString then return GetMoneyString(copper, true) end
	if GetCoinTextureString then return GetCoinTextureString(copper) end
	return ("%dg %ds %dc"):format(copper / 10000, (copper / 100) % 100, copper % 100)
end

----------------------------------------------------------------------
-- repair
----------------------------------------------------------------------
local function Repair()
	if not (CanMerchantRepair and CanMerchantRepair()) then return end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or not cost or cost <= 0 then return end
	if cost > GetMoney() then
		ns.Print("not enough money to repair (" .. Money(cost) .. ").")
		return
	end
	RepairAllItems()
	ns.Print("repaired for " .. Money(cost) .. ".")
end

----------------------------------------------------------------------
-- junk
----------------------------------------------------------------------
local Container = C_Container or {}
local NumSlots = Container.GetContainerNumSlots or GetContainerNumSlots
local UseItem = Container.UseContainerItem or UseContainerItem

-- returns the item's link, quality and stack size (both container APIs)
local function SlotInfo(bag, slot)
	if Container.GetContainerItemInfo then
		local info = Container.GetContainerItemInfo(bag, slot)
		if info then return info.hyperlink, info.quality, info.stackCount, info.hasNoValue end
	elseif GetContainerItemInfo then
		local _, count, _, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
		return link, quality, count, noValue
	end
end

local function SellPrice(link)
	local price
	if C_Item and C_Item.GetItemInfo then
		price = select(11, C_Item.GetItemInfo(link))
	elseif GetItemInfo then
		price = select(11, GetItemInfo(link))
	end
	return price or 0
end

local selling = false
-- Tracked from the merchant events. The merchant window itself can't be asked:
-- when MERCHANT_SHOW fires it isn't on screen yet, so a check on it stopped the
-- selling before the first item.
local merchantOpen = false

local function SellJunk()
	if selling or not (NumSlots and UseItem) then return end
	local queue, total = {}, 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, NumSlots(bag) or 0 do
			local link, quality, count, noValue = SlotInfo(bag, slot)
			if link and quality == 0 and not noValue then
				local price = SellPrice(link)
				if price > 0 then
					queue[#queue + 1] = { bag, slot, link }
					total = total + price * (count or 1)
				end
			end
		end
	end
	if #queue == 0 then return end

	-- one item at a time with a short gap: selling a whole bag in one go gets
	-- throttled by the server and some items are skipped
	selling = true
	local index = 0
	local function Next()
		index = index + 1
		local item = queue[index]
		if not item or not merchantOpen then
			selling = false
			if not item then
				ns.Print(("sold %d junk item%s for %s."):format(#queue, #queue == 1 and "" or "s", Money(total)))
			elseif index > 1 then
				ns.Print("merchant closed before all junk was sold.")
			end
			return
		end
		-- only if the slot still holds the same item
		if SlotInfo(item[1], item[2]) == item[3] then
			UseItem(item[1], item[2])
		end
		C_Timer.After(0.15, Next)
	end
	C_Timer.After(0.2, Next)
end

----------------------------------------------------------------------
-- settings
----------------------------------------------------------------------
ns.Register({
	key = "autoRepair",
	category = "Vendors",
	label = "Auto repair",
	tooltip = "Repairs all your gear when you open a merchant that can repair, and says what it cost in chat.",
	default = false,
})
ns.Register({
	key = "autoSellJunk",
	category = "Vendors",
	label = "Auto sell junk",
	tooltip = "Sells all grey (poor quality) items in your bags when you open a merchant, and says what you got in chat. Hold Shift while opening the merchant to skip it once.",
	default = false,
})

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")
f:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_CLOSED" then
		merchantOpen = false
		return
	end
	merchantOpen = true
	if IsShiftKeyDown() then return end -- hold Shift to skip both this time
	if ns.Get("autoRepair") then Repair() end
	if ns.Get("autoSellJunk") then SellJunk() end
end)
