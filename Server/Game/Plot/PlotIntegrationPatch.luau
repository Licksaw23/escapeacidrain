--[[
    PlotIntegrationPatch.luau - Integration patch for Server/Game/Plot/init.luau
    
    This file contains the modifications needed to integrate PlantService
    with the existing Plot system. Apply these changes to Plot/init.luau
    
    INTEGRATION INSTRUCTIONS:
    1. Add PlantService require near top of file
    2. Replace PlacePlant function body
    3. Replace ActivePlants loop
    4. Add PlantService initialization in plot.new()
--]]

-- ============================================================================
-- CHANGE 1: Add this require at the top of Plot/init.luau
-- (After other requires, around line 25)
-- ============================================================================

--[[ ADD THIS: ]]
local PlantService = require(script.Parent.PlantService)

-- ============================================================================
-- CHANGE 2: Modify the plot.new() function to initialize PlantService
-- (At the end of plot.new(), before return newPlot)
-- ============================================================================

--[[ FIND THIS SECTION in plot.new() (around line 1300): ]]
-- AFTER existing plot setup code...

--[[ ADD THIS: ]]
-- Initialize PlantService for this player
PlantService:HandlePlayerJoin(Player)

-- ============================================================================
-- CHANGE 3: Replace the entire ActivePlants loop 
-- (Lines 1886-1930 approximately)
-- ============================================================================

--[[ REPLACE THIS: ]]
-- Track all active plants in a centralized system
plot.ActivePlants = {} -- {plant = {...}, player = player, module = module, ...}
task.spawn(function()
	while true do
		task.wait(1)
		for i = #plot.ActivePlants, 1, -1 do
			local plantData = plot.ActivePlants[i]
			-- Check if player left
			if not plantData.player or not plantData.player.Parent then
				table.remove(plot.ActivePlants, i)
				continue
			end
			-- Check if plant still exists
			if not plantData.plant or not plantData.plant.Parent then
				table.remove(plot.ActivePlants, i)
				continue
			end
			-- ... rest of growth logic ...
		end
	end
end)

--[[ WITH THIS: ]]
-- Plant growth is now handled client-side via timestamp calculations
-- PlantService manages fruit spawning when plants mature
plot.ActivePlants = {} -- DEPRECATED: Kept for backward compatibility, unused

-- ============================================================================
-- CHANGE 4: Replace the PlacePlant function
-- (Lines 2290-2500 approximately)
-- ============================================================================

--[[ REPLACE THE ENTIRE PlacePlant FUNCTION with: ]]

function plot:PlacePlant(UniqueID, RawPosition, ItemID)
	local PlayerReplica = Data[self.Owner]
	
	-- This is a new plant placement
	if RawPosition then
		-- Use PlantService for placement
		local success, result = PlantService:RequestPlacePlant(self.Owner, ItemID, RawPosition)
		
		if not success then
			warn("[Plot] Plant placement failed:", result)
			UIRemote:FireClient(self.Owner, "TopNotification", {
				Text = "Failed to place plant: " .. tostring(result);
				Duration = 3;
				["ShadowColor"] = Color3.fromRGB(241, 0, 0);
				["ShadowTransparency"] = 0.35;
			})
		end
		
		return success, result
	end
	
	-- Loading existing plant from data
	local GetPlantInData = self.OwnerData.Plot[tostring(UniqueID)]
	if not GetPlantInData then
		warn("No plant data found for:", UniqueID)
		return
	end
	
	-- Plant visual will be created client-side via Replica
	-- Server only manages data
	
	-- Schedule fruit spawn if plant is mature
	task.spawn(function()
		PlantService:SpawnFruitWhenMature(self.Owner, UniqueID)
	end)
end

-- ============================================================================
-- CHANGE 5: Add PlantService initialization at module load
-- (At the very end of the file)
-- ============================================================================

--[[ ADD THIS at end of file: ]]

-- Initialize PlantService
PlantService:Initialize()

-- ============================================================================
-- CHANGE 6: Update RemoteEvent handlers for plants
-- (Find PlotRemote handlers around line 1030)
-- ============================================================================

--[[ MODIFY EXISTING handlers: ]]

--[[ FIND: ]]
newPlot.Connections[1] = PlotRemote.OnServerEvent:Connect(function(user, call, info)
	if user ~= newPlot.Owner then return end
	
	if call == "PlacePlant" then
		-- ... existing code ...
	elseif call == "RemovePlant" then
		-- ... existing code ...
	end
end)

--[[ REPLACE WITH: ]]
newPlot.Connections[1] = PlotRemote.OnServerEvent:Connect(function(user, action, data)
	if user ~= newPlot.Owner then return end
	
	-- Handle PlantService actions
	if action == "RequestPlacePlant" or action == "RequestHarvest" or action == "RequestRemovePlant" then
		-- These are handled by PlantService's remote handler
		return
	end
	
	-- Legacy handlers (for backward compatibility)
	if action == "PlacePlant" and data then
		-- Legacy support - redirect to PlantService
		PlantService:RequestPlacePlant(user, data.ID, data.RawPosition)
	elseif action == "RemovePlant" and data then
		-- Legacy plant removal
		local plantID = typeof(data) == "string" and data or (data and data.PlantID)
		if plantID then
			-- Remove plant data
			local PlayerReplica = Data[user]
			PlayerReplica:SetValue({"Plot", plantID}, nil)
		end
	end
end)

-- ============================================================================
-- NOTES ON REMOVING SERVER-SIDE MODEL CREATION:
-- ============================================================================

--[[
The following server-side model creation has been REMOVED and moved to client:

1. Plant model instantiation (now in PlantController.luau)
2. Plant growth TweenService calls (now client-side timestamp-based)
3. Fruit model instantiation with ProximityPrompts (now in PlantController.luau)
4. ActivePlants 1-second tick loop (now client-side Heartbeat)

Server now ONLY manages:
- Plant data storage in PlayerReplica.Data.Plot
- Fruit spawn scheduling via task.delay (timestamp-based)
- Harvest validation
- Inventory management

Client now handles:
- Plant model cloning from ReplicatedStorage
- Growth animation tweens
- Fruit visual creation
- ProximityPrompt creation
- Harvest request sending
--]]

-- ============================================================================
-- DATA STRUCTURE COMPATIBILITY:
-- ============================================================================

--[[
The existing data structure is preserved for backward compatibility:

PlayerReplica.Data.Plot[plantID] = {
    Name = "Strawberry Seed";
    OffsetPosition = "base64-encoded-bitbuffer";
    TimePlaced = "base64-encoded-timestamp";
    RandomScale = 1.15;
    RandomRotation = "base64-encoded-rotation";
    ["1"] = { -- Fruit data at index
        Weight = 0.35;
        Mutations = {"Gold"};
        Favorited = false;
    };
}

No data migration needed - existing player data works immediately.
--]]
