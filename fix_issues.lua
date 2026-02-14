-- Fix script for OrderRemote validation
-- Run this with: lua fix_orderremote.lua (or manually apply)

local file = io.open("Server/Game/Plot/init.luau", "r")
if not file then error("Could not open file") end
local content = file:read("*all")
file:close()

-- Fix 1: Replace the simple GiveFruit handler with validated version
local oldHandler = [[		if call == "GiveFruit" then
				local path, itemID = ...
				if not path or not itemID then return end
				
				-- Get the current order at this desk
				local currentOrder = newPlot.CurrentOrder[path]
				if not currentOrder or not currentOrder.BrainrotID then return end
				
				local brainrotID = currentOrder.BrainrotID
				
				-- Call the function to give fruit
				if newPlot.Functions[brainrotID] then
					newPlot.Functions[brainrotID](user, itemID)
				end]]

local newHandler = [[		if call == "GiveFruit" then
				local path, itemID = ...
				
				-- CRITICAL FIX: Added comprehensive validation (Issue #2)
				-- Validate path is a number between 1-3
				if type(path) ~= "number" and type(path) ~= "string" then
					warn("[OrderRemote] Invalid path type: " .. type(path))
					return
				end
				
				local pathNum = tonumber(path)
				if not pathNum or pathNum < 1 or pathNum > 3 then
					warn("[OrderRemote] Invalid path number: " .. tostring(path))
					return
				end
				
				-- Validate itemID is a string and exists in inventory
				if type(itemID) ~= "string" then
					warn("[OrderRemote] Invalid itemID type: " .. type(itemID))
					return
				end
				
				-- Check item exists in player's inventory
				if not newPlot.OwnerData.Inventory[itemID] then
					warn("[OrderRemote] Item not in inventory: " .. itemID)
					return
				end
				
				-- Get the current order at this desk
				local currentOrder = newPlot.CurrentOrder[pathNum]
				if not currentOrder or not currentOrder.BrainrotID then 
					warn("[OrderRemote] No active order at path: " .. tostring(pathNum))
					return 
				end
				
				-- Validate the brainrot is still active
				if not newPlot.Active[currentOrder.BrainrotID] then
					warn("[OrderRemote] Brainrot no longer active: " .. currentOrder.BrainrotID)
					return
				end
				
				local brainrotID = currentOrder.BrainrotID
				
				-- Call the function to give fruit
				if newPlot.Functions[brainrotID] then
					newPlot.Functions[brainrotID](user, itemID)
				end]]

if content:find(oldHandler, 1, true) then
    content = content:gsub(oldHandler, newHandler, 1)
    print("Successfully patched OrderRemote handler")
else
    print("WARNING: Could not find exact match for OrderRemote handler")
    print("The code may have already been patched or the format changed")
end

-- Write back
file = io.open("Server/Game/Plot/init.luau", "w")
file:write(content)
file:close()
print("Done!")
