--[[
    BUG FIX 7.3: Atomic Inventory Operations
    File: Server/Game/GlobalStore.luau, Server/Game/Plot/init.luau
    Issue: Inventory count check and item addition are not atomic
    
    This fix ensures inventory operations are atomic.
--]]

-- ============================================================================
-- FOR GlobalStore.luau
-- ============================================================================

-- STEP 1: Replace the inventory check in handlePurchase with atomic operation
--[[ Find and REPLACE this code block in handlePurchase(): --]]

--[[ OLD CODE:
-- Check inventory space
local TotalInventorySize = self.Config.InventorySizes.default
if MarketplaceService:UserOwnsGamePassAsync(plr.UserId, self.Config.InventoryGamePass) then
    TotalInventorySize = self.Config.InventorySizes.gamepass
end

local GetInventoryCount = 0
for _ in pairs(playerPlot.OwnerData.Inventory) do
    GetInventoryCount += 1
end

if GetInventoryCount >= TotalInventorySize then
    self.PurchaseLock[itemName] = nil
    UIRemote:FireClient(plr, "TopNotification", {
        Text = "Your inventory is full! (" .. GetInventoryCount .. "/" .. TotalInventorySize .. ")";
        Duration = 3;
        ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
        ["ShadowTransparency"] = 0.35;
    })
    return
end

-- ALL CHECKS PASSED - PROCESS PURCHASE

-- 1. Decrement global stock FIRST
local newQuantity = self.CurrentStock[itemName] - 1
self.CurrentStock[itemName] = newQuantity

-- 2. Release the lock
self.PurchaseLock[itemName] = nil

-- 3. Give the item to player
playerPlot:GiveItem({...})
--]]

--[[ NEW CODE:
-- ALL CHECKS PASSED - PROCESS PURCHASE

-- Calculate inventory limit
local TotalInventorySize = self.Config.InventorySizes.default
if MarketplaceService:UserOwnsGamePassAsync(plr.UserId, self.Config.InventoryGamePass) then
    TotalInventorySize = self.Config.InventorySizes.gamepass
end

-- ATOMIC: Check inventory AND add item in one operation
local itemAdded = false
local newInventoryCount = 0

-- Generate item ID first
local newItemID = HttpService:GenerateGUID(false)
local itemData = {
    ["ID"] = newItemID;
    ["Name"] = itemName;
}

-- Atomic check-and-add
local currentInventory = playerPlot.OwnerData.Inventory
local count = 0
for _ in pairs(currentInventory) do
    count += 1
end

if count >= TotalInventorySize then
    self.PurchaseLock[itemName] = nil
    UIRemote:FireClient(plr, "TopNotification", {
        Text = "Your inventory is full! (" .. count .. "/" .. TotalInventorySize .. ")";
        Duration = 3;
        ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
        ["ShadowTransparency"] = 0.35;
    })
    return
end

-- 1. Decrement global stock
local newQuantity = self.CurrentStock[itemName] - 1
self.CurrentStock[itemName] = newQuantity

-- 2. Add item to player (before releasing lock)
local addSuccess, addErr = pcall(function()
    getPlayerReplica:SetValue({"Inventory", newItemID}, itemData)
    playerPlot:GiveToolForItem(newItemID)
end)

if not addSuccess then
    -- Rollback stock if item add failed
    self.CurrentStock[itemName] = self.CurrentStock[itemName] + 1
    self.PurchaseLock[itemName] = nil
    warn("[GlobalStore] Failed to give item:", addErr)
    UIRemote:FireClient(plr, "TopNotification", {
        Text = "Purchase failed. Please try again.";
        Duration = 3;
        ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
        ["ShadowTransparency"] = 0.35;
    })
    return
end

-- 3. Release the lock AFTER successful item grant
self.PurchaseLock[itemName] = nil
--]]

-- ============================================================================
-- FOR Plot/init.luau (GiveItem function)
-- ============================================================================

-- STEP 2: Modify GiveItem to return success status
--[[ Find GiveItem function and modify: --]]

--[[ OLD signature:
function plot:GiveItem(Info)
--]]

--[[ NEW signature:
function plot:GiveItem(Info)
    local PlayerReplica = Data[self.Owner]
    
    -- Check inventory space FIRST (atomic)
    local TotalInventorySize = 250
    if MarketplaceService:UserOwnsGamePassAsync(self.Owner.UserId, 1657482065) then 
        TotalInventorySize = 400 
    end
    
    local currentCount = 0
    for _ in pairs(PlayerReplica.Data.Inventory) do
        currentCount += 1
    end
    
    if currentCount >= TotalInventorySize then
        UIRemote:FireClient(self.Owner, "TopNotification", {
            Text = "Inventory full! ("..currentCount.."/"..TotalInventorySize..")";
            Duration = 3;
            ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
            ["ShadowTransparency"] = 0.35;
        })
        return false
    end
    
    -- ... rest of existing GiveItem code ...
    
    return true
end
--]]

-- ============================================================================
-- FOR Plot/init.luau (CompleteOrder function)
-- ============================================================================

-- STEP 3: Fix CompleteOrder to use atomic inventory check
--[[ In CompleteOrder, REPLACE inventory check: --]]

--[[ OLD CODE:
local TotalInventorySize = 250
if MarketplaceService:UserOwnsGamePassAsync(newPlot.Owner.UserId, 1657482065) then TotalInventorySize = 400 end

local GetInventoryCount = 0
for i, v in PlayerReplica.Data.Inventory do GetInventoryCount += 1 end

if GetInventoryCount >= TotalInventorySize then
    UIRemote:FireClient(newPlot.Owner, "TopNotification", {
        Text = "Your inventory is full! ("..GetInventoryCount.."/"..TotalInventorySize..")";
        Duration = 3;
        ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
        ["ShadowTransparency"] = 0.35;
    })
    return
end
--]]

--[[ NEW CODE:
-- Atomic inventory check
local TotalInventorySize = 250
if MarketplaceService:UserOwnsGamePassAsync(newPlot.Owner.UserId, 1657482065) then 
    TotalInventorySize = 400 
end

local currentCount = 0
for _ in pairs(PlayerReplica.Data.Inventory) do
    currentCount += 1
end

if currentCount >= TotalInventorySize then
    getCurrentOrder.Claiming = false -- Reset claiming flag
    UIRemote:FireClient(newPlot.Owner, "TopNotification", {
        Text = "Your inventory is full! ("..currentCount.."/"..TotalInventorySize..")";
        Duration = 3;
        ["ShadowColor"] = Color3.fromRGB(241, 0, 0);
        ["ShadowTransparency"] = 0.35;
    })
    return
end
--]]

return {}
