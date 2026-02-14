----// Important Variables
local Data_Key = workspace:GetAttribute("DataKey")
----//

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataModules = ReplicatedStorage.Game.Modules.Data
local Remotes = ReplicatedStorage.Remotes

local ProfileStore = require(DataModules.ProfileStore)
local ReplicaService = require(DataModules.ReplicaService.ReplicaService)

local PlayerStore = ProfileStore.New(Data_Key,require(script.StarterData))
local PlayerReplicas = require(ReplicatedStorage.ServerPlayerData)

--local PlayerFunctions = require(script.PlayerFunctions) --// Functions that run when the player joins/leaves
local DataClassToken = ReplicaService.NewClassToken("PlayerData")

local Profiles = {}
Players.PlayerAdded:Connect(function(plr)
	task.spawn(MiscPlayerThings,plr) --// Miscellaneous things for the player (get player's face image, etc), found at the bottom of the script

	local Profile = PlayerStore:StartSessionAsync(`{plr.UserId}`, {
		Cancel = function()
			return plr.Parent ~= Players
		end
	})
			
	if Profile then
		Profile:AddUserId(plr.UserId)
		Profile:Reconcile()
		
		local Replica
		Profile.OnSessionEnd:Connect(function()
			Replica:Destroy()
			
			Profiles[plr] = nil
			PlayerReplicas[plr] = nil
			
			plr:Kick()
		end)
		
		if plr:IsDescendantOf(Players) then
			Profiles[plr] = Profile
			
			Replica = ReplicaService.NewReplica({
				ClassToken = DataClassToken;
				Data = Profile.Data;
				Tags = {ID = plr.UserId};
				Replication = plr; -- plr
			})
			
			PlayerReplicas[plr] = Replica
			
	
			--task.spawn(PlayerFunctions.PlayerJoined,plr) --// Function that runs when player joins
			plr:SetAttribute("DataLoaded",true)
			
			Profile:MessageHandler(function(incomingData, processed)
			--	print("data recieved", incomingData)
				Replica:SetValue(incomingData[1], incomingData[2])
				processed()
			end)
		else
			Profile:EndSession()
		end
	else
		plr:Kick("Unable to load data, please rejoin!")
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	--task.spawn(PlayerFunctions.PlayerLeft,plr) --// Function that runs when player leaves
	
	local Profile = Profiles[plr]
	
	if Profile then
		Profile:EndSession()
	end
end)

--------------//

function MiscPlayerThings(plr)
	plr:SetAttribute("Face", `rbxthumb://type=AvatarHeadShot&id={plr.UserId}&w=180&h=180`)
end
