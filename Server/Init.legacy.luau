local PlayerService = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TextChatService = game:GetService("TextChatService")

local Data = require(Replicated:WaitForChild("ServerPlayerData"))

local ModulesCache = {}

-- this is scuffed but this just turns off collisions for all brainrot models --

local brainrotModels = game.ReplicatedStorage.Game.Models.Brainrot3D

local function SetupCategory(parent)
	for _, mdl in parent:GetChildren() do
		if mdl:IsA("Model") then
			for _, part in mdl:GetDescendants() do
				if part:IsA("Part") or part:IsA("MeshPart") or part:IsA("BasePart") then
					part.CanCollide = false
					part.Massless = true
					part.CollisionGroup = "Brainrots"
				end
			end
		end
	end
end

SetupCategory(brainrotModels)
SetupCategory(game.ReplicatedStorage.Game.Models.Tools)

-- israel stuff --

local function getLastWeekdayOfMonth(year, month, weekday)
	local date = os.time({year = year, month = month + 1, day = 0})
	while os.date("!*t", date).wday ~= weekday do
		date -= 86400
	end
	return os.date("!*t", date).day
end

-- Check if Israel is in DST
local function isIsraelDST(utc)
	local year = utc.year

	-- DST starts: Friday before last Sunday of March
	local lastSundayMarch = getLastWeekdayOfMonth(year, 3, 1)
	local dstStart = os.time({
		year = year, month = 3, day = lastSundayMarch - 2,
		hour = 2, min = 0, sec = 0
	})

	-- DST ends: Last Sunday of October
	local lastSundayOctober = getLastWeekdayOfMonth(year, 10, 1)
	local dstEnd = os.time({
		year = year, month = 10, day = lastSundayOctober,
		hour = 2, min = 0, sec = 0
	})

	local now = os.time(utc)
	return now >= dstStart and now < dstEnd
end

-- Convert UTC → Israel time (returns table + unix time)
local function getIsraelTime()
	local utc = os.date("!*t")
	local offset = isIsraelDST(utc) and 3 or 2
	local israelUnix = os.time(utc) + offset * 3600
	return os.date("*t", israelUnix), israelUnix
end

-- setup all tools --

for _, model in Replicated.Game.Models.Plants:GetChildren() do
	if not string.find(model.Name, "Seed") then
		local newTool = Instance.new("Tool", Replicated.Game.Models.Tools)
		newTool.Name = model.Name
		
		local newHandle = Instance.new("Part", newTool)
		newHandle.Size = Vector3.new(0.1,0.1,0.1)
		newHandle.CanCollide = false
		newHandle.Anchored = false
		newHandle.Transparency = 0.5
		newHandle.Name = "Handle"
		
		local newM6D = Instance.new("Motor6D", newTool)
		newM6D.Part0 = newHandle
		
		local newModel = model:Clone()
		newModel.Parent = newTool

		-- newm6d is the one that needs to be changed to move stuff in the tool --
		if model:GetAttribute("ToolOffset") then 
			newM6D.C0 = model:GetAttribute("ToolOffset")
		end

		for _, desc in newModel:GetDescendants() do
			if desc:IsA("BasePart") or desc:IsA("MeshPart") then
				desc.CanCollide = false
				desc.Anchored = false
				desc.Massless = true

				if desc.Name == "RootPart" then
					newM6D.Part1 = desc
				end
			end
		end

		newTool.CanBeDropped = false
		newTool.RequiresHandle = true
	end
end

for _, model in Replicated.Game.Models.Gears:GetChildren() do
	local newTool = Instance.new("Tool", Replicated.Game.Models.Tools)
	newTool.Name = model.Name

	local newHandle = Instance.new("Part", newTool)
	newHandle.Size = Vector3.new(0.1,0.1,0.1)
	newHandle.CanCollide = false
	newHandle.Anchored = false
	newHandle.Transparency = 0.5
	newHandle.Name = "Handle"

	local newM6D = Instance.new("Motor6D", newTool)
	newM6D.Part0 = newHandle

	local newModel = model:Clone()
	newModel.Parent = newTool

	for _, desc in newModel:GetDescendants() do
		if desc:IsA("BasePart") or desc:IsA("MeshPart") then
			desc.CanCollide = false
			desc.Anchored = false
			desc.Massless = true

			if desc.Name == "RootPart" then
				newM6D.Part1 = desc
			end
		end
	end

	newTool.CanBeDropped = false
	newTool.RequiresHandle = true
end

for _, model in Replicated.Game.Models.Brainrot3D:GetChildren() do
	if model:GetAttribute("Rarity") then
		local newTool = Instance.new("Tool", Replicated.Game.Models.Tools)
		newTool.Name = model.Name

		local newHandle = Instance.new("Part", newTool)
		newHandle.Size = Vector3.new(0.1,0.1,0.1)
		newHandle.CanCollide = false
		newHandle.Anchored = false
		newHandle.Transparency = 0.5
		newHandle.Name = "Handle"

		local newAttachment = Instance.new("Attachment", newHandle)
		newAttachment.Position = Vector3.new(0, 8.829, 0.621)

		local newM6D = Instance.new("Motor6D", newTool)
		newM6D.Part0 = newHandle

		local newModel = model:Clone()
		newModel.Parent = newTool

		for _, desc in newModel:GetDescendants() do
			if desc:IsA("BasePart") or desc:IsA("MeshPart") then
				desc.CanCollide = false
				desc.Anchored = false
				desc.Massless = true

				if desc.Name == "RootPart" then
					newM6D.Part1 = desc
				end
			end
		end

		newTool.CanBeDropped = false
		newTool.RequiresHandle = true
	end
end

-- setup all plots --

local initialPlot = workspace.Plots["1"]

local originalCFrame = initialPlot.Spawn.CFrame

for i = 1, 5 do
	local newPlot = Instance.new("Model", workspace.Plots)
	local plotClone = initialPlot:Clone()
	plotClone.Parent = newPlot
	newPlot.PrimaryPart = plotClone.Spawn
	newPlot:PivotTo(originalCFrame * CFrame.new(i * -129, 0, 0))
	plotClone.Name = i+1 
	plotClone.Parent = workspace.Plots
	newPlot:Destroy()
end

--initialPlot.All.BRIDGE:Destroy()
--initialPlot.All.EXTRA:Destroy()

-- Initialize all server modules. --
for _, folder in script.Parent:GetChildren() do
	if folder:IsA("Folder") then
		for _, mod in folder:GetChildren() do
			pcall(function()
				ModulesCache[mod.Name] = require(mod)
			end)
		end
	end
end

-- [[ FIXED: Initialize GlobalStore for global seed/gear shop ]] --
local GlobalStore = require(script.Parent.Game.GlobalStore)
ModulesCache["GlobalStore"] = GlobalStore
--- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

local stockRemote = Replicated.Remotes.UpdateSeedStore
local UIRemote = Replicated.Remotes.UI
local FXRemote = Replicated.Remotes.FX
local SpawnRemote = Replicated.Remotes.Spawn

local tempDelays = {}

local function HandlePlayer(User)
	tempDelays[User] = {}

	User:SetAttribute("JoinTick", tick())
	local newPlot = ModulesCache["Plot"].new(User)
	local PlayerReplica = Data[User]
	local Data = PlayerReplica.Data

	-- [[ FIXED: Use GlobalStore for global stock management ]] --
	-- Only set the timestamp in player data - stock is now global!
	if Data.CurrentStock ~= GlobalStore.nextResetTime then
		PlayerReplica:SetValue({"CurrentStock"}, GlobalStore.nextResetTime)
		-- NOTE: We no longer store Stock in player data - it's global!
	end
	
	-- Rebirth luck. --
	local totalMult = 0.5 * (Data.Rebirths or 0)
	if totalMult > 0 then
		warn('giving: '..totalMult)
		newPlot:GiveTotalLuck(totalMult)
		newPlot:GiveCashMultiplier(totalMult)
		newPlot:GiveSpeed(totalMult)
	end
	
	-- Update boost timers. --
	for boostID, boostData in Data.Boosts do
		local currentTime = tick()
		local pastTime = boostData.Start
		local timeRequired = pastTime + boostData.Time
		local calculatedTime = timeRequired - currentTime

		if calculatedTime <= 0 then
			PlayerReplica:SetValue({"Boosts", boostID}, nil)
		else
			if boostData.Type == "Mutation" or boostData.Type == "Brainrot" or boostData.Type == "Size" then
				newPlot["Give"..boostData.Type.."Luck"](newPlot, boostData.Amount, calculatedTime)
			else
				newPlot["Give"..boostData.Type](newPlot, boostData.Amount, calculatedTime)
			end

			UIRemote:FireClient(User, "Timer", {
				["Text"] = boostData.Amount.."x "..boostData.Type.." Multiplier";
				["Time"] = calculatedTime;
				["Gradient"] = boostData.Type;
			})
		end
	end

	-- [[ FIXED: Send global stock to player ]] --
	stockRemote:FireClient(User, GlobalStore.CurrentStock, GlobalStore.nextResetTime)

	if not ModulesCache["Leaderboards"].IsPlayerInLeaderboard(User.UserId, "Playtime") then
		-- Add player to LBs. --
		ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", 1)
		ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Orders", 15)
		ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Cash", 3000000)
	end

	local sessionStart = os.time()

	-- 2x Weekend --

	if ModulesCache["Plot"].RarityWeekend then
		if not User:GetAttribute("2xWeekend") then
			User:SetAttribute("2xWeekend", true)
			
			local t, nowUnix = getIsraelTime()
			local endUnix = ModulesCache["Plot"].RarityWeekendEnd
			local timeLeft = math.max(0, endUnix - nowUnix)

			UIRemote:FireClient(User, "Timer", {
				["Text"] = "2x Brainrot Weekend";
				["Gradient"] = "Luck";
				["Time"] = math.max(0, endUnix - nowUnix);
			})
		end
	end
	
	-- Event Multipliers --
	
	if ModulesCache["Plot"].EventMultipliers then
		for Type, MultiplierData in ModulesCache["Plot"].EventMultipliers do
			if MultiplierData.NoFire then continue end
			
			local currentTime = tick()
			local pastTime = MultiplierData.Start
			local timeRequired = pastTime + MultiplierData.Time
			local calculatedTime = timeRequired - currentTime
			
			if MultiplierData.Type ~= "Luck" then
				UIRemote:FireClient(User, "Timer", {
					["Text"] = MultiplierData.Amount.."x "..MultiplierData.Type.." Luck Multiplier";
					["Time"] = calculatedTime;
					["Gradient"] = MultiplierData.Type;
				})
			else
				UIRemote:FireClient(User, "Timer", {
					["Text"] = MultiplierData.Amount.."x Luck Multiplier";
					["Time"] = calculatedTime;
					["Gradient"] = MultiplierData.Type;
				})
			end
			
		end
	end

	-- VIP --

	if MarketplaceService:UserOwnsGamePassAsync(User.UserId, 1666032504) then
		newPlot:GiveTotalLuck(0.25)		
		User:SetAttribute("VIP", true)
	end
	
	-- Scale / Mutate --
	--[[
	task.delay(3, function()
		-- Load all client related things.. --
		local mutateArray = {}
		local scaleArray = {}

		for plot, spawnsList in ModulesCache["ServerUtility"].Spawns do
			for _, ID in spawnsList do
				local getCache = ModulesCache["Plot"].Plots[plot].Brainrots[ID]
				SpawnRemote:FireClient(User, "SpawnPlatformBrainrot", getCache)
			end
		end

		for model, scale in ModulesCache["ServerUtility"].Scales do
			table.insert(scaleArray, {["Model"] = model; ["Scale"] = scale})
		end

		for model, mutationList in ModulesCache["ServerUtility"].Mutations do
			for _, mutation in mutationList do
				table.insert(mutateArray, {["Model"] = model; ["Mutation"] = mutation})
			end
		end

		warn(ModulesCache["ServerUtility"].CustomerSpawns)

		for plot, spawnsList in ModulesCache["ServerUtility"].CustomerSpawns do
			local plotCache = ModulesCache["Plot"].Plots[plot]

			for _, ID in spawnsList do
				if not plotCache then
					continue
					
				end
				
				local getCache = plotCache.Active[ID]
				local getOrderCache = plotCache.Orders[ID]

				if getCache then
					if getOrderCache then
						ModulesCache["ServerUtility"].ClientSpawnCustomerBrainrot(ID, getCache, plot, getOrderCache)
					else
						ModulesCache["ServerUtility"].ClientSpawnCustomerBrainrot(ID, getCache, plot)
					end
				end
			end
		end


		FXRemote:FireClient(User, "Replicate",{
			["Call"] = "Mutate";
			["Array"] = mutateArray;
		})

		FXRemote:FireClient(User, "Replicate",{
			["Call"] = "Scale";
			["Array"] = scaleArray;
		})
	end)]]

	-- Playtime Handler --

	task.spawn(function()
		while User.Parent do
			task.wait(60)
			if User.Parent then
				local savedPlaytime = Data.Stats.Playtime 
				local currentPlaytime = savedPlaytime + (os.time() - sessionStart)

				pcall(function()
					PlayerReplica:SetValue({"Stats", "Playtime"}, currentPlaytime)
					ModulesCache["Leaderboards"].UpdatePlayerStat(User.UserId, "Playtime", currentPlaytime)
				end)
			end
		end
	end)
end

function justCheck()
	for _, player in PlayerService:GetPlayers() do
		local boost = 0

		for _, other in PlayerService:GetPlayers() do
			if player ~= other then
				if player:IsFriendsWithAsync(other.UserId) then
					boost += 1
				end
			end
		end


		player:SetAttribute("FriendBoost", math.clamp(boost, 0, 5))
	end
end

for _, p in PlayerService:GetPlayers() do
	HandlePlayer(p)
	justCheck()
end

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(User)
	HandlePlayer(User)
	justCheck()

	User.Idled:Connect(function(Time)
		if Time >= 18*60 then -- Triggers after 20 seconds of being idle (adjustable)
			local placeId = game.PlaceId
			local privateServerId = game.PrivateServerId
			local privateServerCode = game.PrivateServerOwnerId

			-- Check if this is a private server
			if privateServerId ~= "" and privateServerCode ~= 0 then
				-- Teleport back to the same private server
				TeleportService:TeleportToPrivateServer(
					placeId,
					privateServerId,
					{User}
				)
			else
				-- Teleport back to a public server
				TeleportService:Teleport(placeId, User)
			end
		end
	end)
end)

PlayerService.PlayerRemoving:Connect(function(User)
	local PlayerReplica = Data[User]
	PlayerReplica:SetValue({"LastLeave"}, tick())

	if ModulesCache["Plot"].PlayerDelays and ModulesCache["Plot"].PlayerDelays[User] then
		for _, delayer in ModulesCache["Plot"].PlayerDelays[User] do
			task.cancel(delayer)
		end
	end
end)