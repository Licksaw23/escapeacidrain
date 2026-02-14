local PlayersService = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local AdminRemote = game.ReplicatedStorage.Remotes.Admin
local UIRemote = game.ReplicatedStorage.Remotes.UI

local ServerUtility = require(script.Parent.ServerUtility)
local Plot = require(script.Parent.Plot)
local ServerData = require(game.ReplicatedStorage.ServerPlayerData)

local admin = {}

local GlobalMessageChannel = "AdminNotifications"
local function showNotification(message, color, playerID)
	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size100x100
	local content, isReady = PlayersService:GetUserThumbnailAsync(playerID, thumbType, thumbSize)

	UIRemote:FireAllClients("TopNotification", {
		["Text"] = message;
		["Duration"] = 5;
		["TextColor"] = color;
		["Icon"] = content;
	})
end

local function broadcast(plrID, TBL)
	MessagingService:PublishAsync(GlobalMessageChannel, TBL)
end

MessagingService:SubscribeAsync(GlobalMessageChannel, function(messageData)
	-- Validate message data
	if not messageData or not messageData.Data then
		warn("[Admin] Invalid message data received from MessagingService")
		return
	end
	
	local command = messageData.Data.Command
	
	if not command then
		warn("[Admin] Message received without Command field")
		return
	end

	if admin.Commands[command] then
		local success, result = pcall(function()
			admin.Commands[command](messageData.Data)
		end)
		
		if not success then
			warn("[Admin] Global command '" .. tostring(command) .. "' failed: " .. tostring(result))
		end
	else
		warn("[Admin] Unknown global command received: " .. tostring(command))
	end
end)

function spawnRot(user, name, mutation, weight)
	-- Validate inputs
	if not name or name == "" then
		warn("[Admin] spawnRot failed: Invalid brainrot name provided")
		return false, "Invalid brainrot name"
	end
	
	-- Load brainrot data to validate the name exists
	local BrainrotData = require(game.ReplicatedStorage.Game.Modules.Libraries.BrainrotsData)
	if not BrainrotData[name] then
		warn("[Admin] spawnRot failed: Brainrot '" .. tostring(name) .. "' does not exist in BrainrotsData")
		return false, "Brainrot does not exist: " .. tostring(name)
	end
	
	-- Validate mutation if provided
	if mutation and mutation ~= "" then
		local MutationsData = require(game.ReplicatedStorage.Game.Modules.Libraries.MutationsData)
		if not MutationsData[mutation] then
			warn("[Admin] spawnRot warning: Mutation '" .. tostring(mutation) .. "' does not exist, spawning without mutation")
			mutation = nil
		end
	end
	
	-- Validate weight
	local validWeight = tonumber(weight) or 1
	if validWeight <= 0 then
		warn("[Admin] spawnRot warning: Invalid weight '" .. tostring(weight) .. "', defaulting to 1")
		validWeight = 1
	end
	
	local successCount = 0
	local errorCount = 0
	
	for _, plotSelf in Plot.Plots do
		if user then 
			if plotSelf.Owner ~= user then 
				continue 
			end 
		end
		
		-- Validate plot exists and has required data
		if not plotSelf or not plotSelf.Owner or not plotSelf.OwnerData then
			warn("[Admin] spawnRot failed: Invalid plot data for plot", plotSelf and plotSelf.PlotNumber or "unknown")
			errorCount += 1
			continue
		end

		-- Blacklist paths based on rebirth level
		local BlacklistPaths = {[2] = true; [3] = true}
		
		-- Check for unlocks
		if plotSelf.OwnerData.Unlocks and plotSelf.OwnerData.Unlocks["Path2"] then 
			BlacklistPaths[2] = false 
		end
		if plotSelf.OwnerData.Unlocks and plotSelf.OwnerData.Unlocks["Path3"] then 
			BlacklistPaths[3] = false 
		end
		
		-- Also check rebirth level (same logic as main spawn)
		if plotSelf.OwnerData.Rebirths and plotSelf.OwnerData.Rebirths >= 2 then 
			BlacklistPaths[2] = false 
		end
		if plotSelf.OwnerData.Rebirths and plotSelf.OwnerData.Rebirths >= 3 then 
			BlacklistPaths[3] = false 
		end
		
		-- Validate that we have at least one available path
		if not plotSelf.Lines then
			warn("[Admin] spawnRot failed: Plot has no Lines table")
			errorCount += 1
			continue
		end
		
		local success, result = pcall(function()
			local ChosenPathIndex = ServerUtility.PickLowestNumberedArray(plotSelf.Lines, BlacklistPaths)
			
			if not ChosenPathIndex then
				error("No available paths for brainrot spawn")
			end

			plotSelf:SpawnBrainrot(HttpService:GenerateGUID(false), {
				Name = name,
				Weight = validWeight,
				Mutations = mutation and {[1] = mutation} or {},
				Path = ChosenPathIndex,
				Bypass = true,
			})
		end)
		
		if success then
			successCount += 1
		else
			warn("[Admin] spawnRot failed for plot " .. tostring(plotSelf.PlotNumber) .. ": " .. tostring(result))
			errorCount += 1
		end
	end
	
	if errorCount > 0 then
		warn("[Admin] spawnRot completed with errors: " .. successCount .. " succeeded, " .. errorCount .. " failed")
	end
	
	return successCount > 0, successCount .. " brainrot(s) spawned, " .. errorCount .. " failed"
end

function startEvent(user, event)
	local EventsManager = require(game.ServerScriptService.Server.Events2.EventsManager)
	
	EventsManager:BeginEvent(event,20)-- make 30 duraiton time later
	
	return true, "Event started successfully"
end

function forceSeed(user, seedName, stock)
	-- Validate inputs
	if not seedName or seedName == "" then
		warn("[Admin] forceSeed failed: Invalid seed name provided")
		return false, "Invalid seed name"
	end
	
	-- Validate stock
	local validStock = tonumber(stock)
	if not validStock or validStock < 0 then
		warn("[Admin] forceSeed warning: Invalid stock '" .. tostring(stock) .. "', defaulting to 1")
		validStock = 1
	end
	
	-- Validate seed exists
	local ItemsData = require(game.ReplicatedStorage.Game.Modules.Libraries.ItemsData)
	local GearsData = require(game.ReplicatedStorage.Game.Modules.Libraries.GearsData)
	
	if not ItemsData[seedName] and not GearsData[seedName] then
		warn("[Admin] forceSeed failed: Item '" .. tostring(seedName) .. "' does not exist in ItemsData or GearsData")
		return false, "Item does not exist: " .. tostring(seedName)
	end
	
	local successCount = 0
	local errorCount = 0
	
	for _, plotSelf in Plot.Plots do
		if user then 
			if plotSelf.Owner ~= user then 
				continue 
			end 
		end
		
		-- Validate plot
		if not plotSelf or not plotSelf.ForceSeed then
			warn("[Admin] forceSeed failed: Invalid plot or missing ForceSeed function")
			errorCount += 1
			continue
		end
		
		local success, result = pcall(function()
			plotSelf.ForceSeed(seedName, validStock, true)
		end)
		
		if success then
			successCount += 1
		else
			warn("[Admin] forceSeed failed for plot: " .. tostring(result))
			errorCount += 1
		end
	end
	
	if errorCount > 0 then
		warn("[Admin] forceSeed completed with errors: " .. successCount .. " succeeded, " .. errorCount .. " failed")
	end
	
	return successCount > 0, successCount .. " plot(s) updated, " .. errorCount .. " failed"
end

admin.GlobalCommands = {
	["Global Message (Global)"] = function(user, data)
		broadcast(user.UserId, {["Command"] = "Global Message (Global)"; ["Message"] = data.Message;
			['ColorR'] = 255;
			['ColorG'] = 255;
			['ColorB'] = 255;
			['AdminID'] = user.UserId
		})
	end,

	["Global Luck (Global)"] = function(user, data)
		broadcast(user.UserId, {["Command"] = "Global Luck (Global)"; ["Luck"] = data.Luck;
			['AdminID'] = user.UserId;
			["Time"] = data.Time;
		})
	end,

	["Spawn Brainrot (Global)"] = function(user, data)
		broadcast(user.UserId, {["Command"] = "Spawn Brainrot (Global)"; ["BrainrotName"] = data.BrainrotName;
			['AdminID'] = user.UserId;
			["BrainrotMutation"] = data.BrainrotMutation;
		})
	end,

	["Start Event (Global)"] = function(user, data)
		broadcast(user.UserId, {["Command"] = "Start Event (Global)"; ["Event"] = data.Event; ['AdminID'] = user.UserId})
	end,
	
	["Force Stock (Global)"] = function(user, data)
		broadcast(user.UserId, {["Command"] = "Force Stock (Global)"; ["Seed"] = data.Seed; ["Stock"] = data.Stock; ['AdminID'] = user.UserId})
	end,
}

admin.Commands = {
	-- GLOBALS --
	["Global Luck (Global)"] = function(List)
		if not List then
			warn("[Admin] Global Luck (Global) missing data")
			return
		end
		
		local luckAmount = tonumber(List.Luck) or 1
		local luckTime = tonumber(List.Time) or 60
		
		if luckAmount <= 0 then
			warn("[Admin] Global Luck (Global) invalid luck amount: " .. tostring(List.Luck))
			return
		end
		
		local success, result = pcall(function()
			Plot.GiveServerLuck(luckAmount, "Luck", luckTime)
		end)
		
		if not success then
			warn("[Admin] Global Luck (Global) failed: " .. tostring(result))
		end
	end,

	["Global Message (Global)"] = function(List)
		if not List or not List.Message then
			warn("[Admin] Global Message (Global) missing message")
			return
		end
		
		local success, result = pcall(function()
			local message = List.Message
			local color = Color3.fromRGB(
				tonumber(List.ColorR) or 255,
				tonumber(List.ColorG) or 255,
				tonumber(List.ColorB) or 255
			)
			local admin = List.AdminID or 0

			showNotification(message, color, admin)
		end)
		
		if not success then
			warn("[Admin] Global Message (Global) failed: " .. tostring(result))
		end
	end,

	["Spawn Brainrot (Global)"] = function(List)
		if not List then
			warn("[Admin] Spawn Brainrot (Global) missing data")
			return
		end
		
		local success, message = spawnRot(nil, List.BrainrotName, List.BrainrotMutation, List.BrainrotWeight)
		if not success then
			warn("[Admin] Spawn Brainrot (Global) failed: " .. tostring(message))
		end
	end,

	["Start Event (Global)"] = function(List)
		if not List then
			warn("[Admin] Start Event (Global) missing data")
			return
		end
		
		local success, message = startEvent(nil, List.Event)
		if not success then
			warn("[Admin] Start Event (Global) failed: " .. tostring(message))
		end
	end,
	
	["Force Stock (Global)"] = function(List)
		if not List then
			warn("[Admin] Force Stock (Global) missing data")
			return
		end
		
		local success, message = forceSeed(nil, List.Seed, List.Stock)
		if not success then
			warn("[Admin] Force Stock (Global) failed: " .. tostring(message))
		end
	end,

	-- PLAYER --

	["Server Luck (Player)"] = function(user, data)
		if not data or not data.Target then
			warn("[Admin] Server Luck (Player) missing target")
			return
		end
		
		local getUser = PlayersService:FindFirstChild(data.Target)
		if not getUser then 
			warn("[Admin] Server Luck (Player) target player not found: " .. tostring(data.Target))
			return 
		end
		
		local luckAmount = tonumber(data.Luck) or 1
		local luckTime = tonumber(data.Time) or 60
		
		if luckAmount <= 0 then
			warn("[Admin] Server Luck (Player) invalid luck amount: " .. tostring(data.Luck))
			return
		end
		
		local success, result = pcall(function()
			local currentLuck = getUser:GetAttribute("Luck") or 0
			local totalLuck = currentLuck + luckAmount
			getUser:SetAttribute("Luck", totalLuck)
			
			UIRemote:FireClient(getUser, "Timer", {
				["Text"] = luckAmount.."x Luck Multiplier";
				["Time"] = luckTime;
				["Gradient"] = "Luck";
			})
			
			-- add to their boosts data --
			local Replica = ServerData[user]
			if Replica then
				Replica:SetValue({"Boosts", HttpService:GenerateGUID(false)}, {
					["Type"] = "Luck";
					["Amount"] = luckAmount;
					["Start"] = tick();
					["Time"] = luckTime;
				})
			end
			
			task.delay(luckTime, function()
				if getUser and getUser.Parent then
					getUser:SetAttribute("Luck", (getUser:GetAttribute("Luck") or 0) - luckAmount)
				end
			end)
		end)
		
		if not success then
			warn("[Admin] Server Luck (Player) failed: " .. tostring(result))
		end
	end,

	["Spawn Brainrot (Player)"] = function(user, data)
		if not data or not data.Target then
			warn("[Admin] Spawn Brainrot (Player) missing target")
			return
		end
		
		local getUser = PlayersService:FindFirstChild(data.Target)
		if not getUser then 
			warn("[Admin] Spawn Brainrot (Player) target player not found: " .. tostring(data.Target))
			return 
		end
		
		local success, message = spawnRot(getUser, data.BrainrotName, data.BrainrotMutation, data.BrainrotWeight)
		if not success then
			warn("[Admin] Spawn Brainrot (Player) failed: " .. tostring(message))
		end
	end,

	["Start Event (Player)"] = function(user, data)
		if not data or not data.Target then
			warn("[Admin] Start Event (Player) missing target")
			return
		end
		
		local getUser = PlayersService:FindFirstChild(data.Target)
		if not getUser then 
			warn("[Admin] Start Event (Player) target player not found: " .. tostring(data.Target))
			return 
		end
		
		local success, message = startEvent(getUser, data.Event)
		if not success then
			warn("[Admin] Start Event (Player) failed: " .. tostring(message))
		end
	end,
	
	["Force Seed (Player)"] = function(user, data)
		if not data then
			warn("[Admin] Force Seed (Player) missing data")
			return
		end
		
		local success, message = forceSeed(user, data.Seed, data.Stock)
		if not success then
			warn("[Admin] Force Seed (Player) failed: " .. tostring(message))
		end
	end,
	
	-- SERVER --
	
	["Server Luck (Server)"] = function(user, data)
		if not data then
			warn("[Admin] Server Luck (Server) missing data")
			return
		end
		
		local luckAmount = tonumber(data.Luck) or 1
		local luckTime = tonumber(data.Time) or 60
		
		if luckAmount <= 0 then
			warn("[Admin] Server Luck (Server) invalid luck amount: " .. tostring(data.Luck))
			return
		end
		
		local success, result = pcall(function()
			Plot.GiveServerLuck(luckAmount, "Luck", luckTime)
		end)
		
		if not success then
			warn("[Admin] Server Luck (Server) failed: " .. tostring(result))
		end
	end,
	
	["Spawn Brainrot (Server)"] = function(user, data)
		if not data then
			warn("[Admin] Spawn Brainrot (Server) missing data")
			return
		end
		
		local success, message = spawnRot(nil, data.BrainrotName, data.BrainrotMutation, data.BrainrotWeight)
		if not success then
			warn("[Admin] Spawn Brainrot (Server) failed: " .. tostring(message))
		end
	end,
	
	["Server Message (Server)"] = function(user, data)
		if not data or not data.Message then
			warn("[Admin] Server Message (Server) missing message")
			return
		end
		
		local success, result = pcall(function()
			local color = data.Color or Color3.fromRGB(255, 255, 255)
			showNotification(data.Message, color, user.UserId)
		end)
		
		if not success then
			warn("[Admin] Server Message (Server) failed: " .. tostring(result))
		end
	end,
	
	["Start Event (Server)"] = function(user, data)
		if not data then
			warn("[Admin] Start Event (Server) missing data")
			return
		end
		
		local success, message = startEvent(nil, data.Event)
		if not success then
			warn("[Admin] Start Event (Server) failed: " .. tostring(message))
		end
	end,
	
	["Force Seed (Server)"] = function(user, data)
		if not data then
			warn("[Admin] Force Seed (Server) missing data")
			return
		end
		
		local success, message = forceSeed(nil, data.Seed, data.Stock)
		if not success then
			warn("[Admin] Force Seed (Server) failed: " .. tostring(message))
		end
	end,
}

AdminRemote.OnServerEvent:Connect(function(user, command, data)
	-- Validate user
	if not user or not user:IsA("Player") then
		warn("[Admin] Invalid user attempted to use admin command")
		return
	end
	
	-- Validate command exists
	if not admin.GlobalCommands[command] and not admin.Commands[command] then 
		warn("[Admin] Unknown command attempted: " .. tostring(command))
		return 
	end
	
	-- Validate data
	if not data then
		data = {}
	end

	-- Execute command with error handling
	local success, result = pcall(function()
		if string.find(command, "Global") then
			admin.GlobalCommands[command](user, data)
		else
			admin.Commands[command](user, data)
		end
	end)
	
	if not success then
		warn("[Admin] Command '" .. tostring(command) .. "' failed for user " .. user.Name .. ": " .. tostring(result))
		
		-- Notify the admin that the command failed
		UIRemote:FireClient(user, "TopNotification", {
			["Text"] = "Admin command failed: " .. tostring(command);
			["Duration"] = 5;
			["TextColor"] = Color3.fromRGB(255, 0, 0);
		})
	end
end)

return admin