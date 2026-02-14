local Sandstorm = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Plot = require(game.ServerScriptService.Server.Game.Plot)
local Plots = Plot.Plots
local ServerUtil = require(game.ServerScriptService.Server.Game.ServerUtility)

-- Constants
local MUTATION_CHANCE = 0.05 -- 0.05% chance per check (averages 1-4 fruits total over 2 minutes)
local CHECK_INTERVAL = 1 -- Check every 2 seconds (reduces server load)

-- State
local ActiveConnections = {}

-- Utility function
local function chance(percent)
	return math.random(1, 100) <= percent
end

function Sandstorm:StartWeather()
	print("[Sandstorm] Starting sandstorm weather event")

	-- Use a separate thread with proper wait timing
	local running = true
	table.insert(ActiveConnections, {Disconnect = function() running = false end})

	task.spawn(function()
		while running do
			task.wait(CHECK_INTERVAL)

			if not running then break end -- Double check before processing

			for _, plotSelf in pairs(Plots) do
				-- Skip if plot doesn't have necessary components
				if not plotSelf.Folder or not plotSelf.Folder:FindFirstChild("Plants") then
					continue
				end

				-- Get all plants in the plot
				for _, plant in ipairs(plotSelf.Folder.Plants:GetChildren()) do
					if not plant:IsA("Model") or not plant.PrimaryPart then
						continue
					end

					local plantID = plant:GetAttribute("ID")
					if not plantID then
						continue
					end

					-- Get all ready-to-harvest fruits from this plant
					local fruits = {}
					for _, fruit in ipairs(plant:GetDescendants()) do
						if fruit:GetAttribute("ReadyToHarvest") then
							local dataIndex = fruit:GetAttribute("DataIndex")
							if dataIndex then
								table.insert(fruits, dataIndex)
							end
						end
					end

					-- Apply sandy mutation with 5% chance to each fruit
					for _, fruitIndex in ipairs(fruits) do
						if chance(MUTATION_CHANCE) then
							-- Apply Sandy mutation
							local success, err = pcall(function()
								if ServerUtil.ActiveFruit[plantID..fruitIndex] then
									ServerUtil.ActiveFruit[plantID..fruitIndex](nil, "UpdateMutations", "Sandy")
								end
							end)

							if not success then
						
							end
						end
					end
				end
			end
			end
		end)

	print("[Sandstorm] Sandstorm event loop started")
end

function Sandstorm:CleanupWeather()
	print("[Sandstorm] Cleaning up sandstorm weather event")

	-- Disconnect all active connections
	for _, connection in ipairs(ActiveConnections) do
		connection:Disconnect()
	end

	table.clear(ActiveConnections)
	print("[Sandstorm] Sandstorm event cleaned up")
end

return Sandstorm