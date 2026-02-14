-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera

-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local PolicyService = game:GetService("PolicyService")

-- folders --
local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Models = GameFolder.Models.Brainrot3D
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local UI = GameFolder.UI
local Libraries = Modules.Libraries

-- remotes --
local orderRemote = RS.Remotes.Order
local spawnRemote = RS.Remotes.Spawn
local adminRemote = RS.Remotes.Admin
local codesRemote = RS.Remotes.Code
local UpdateSetting = RS.Remotes.Setting

-- ui --
local MainUI = PlayerGui:WaitForChild("MainUI")
local RewardsUI = MainUI.Rewards

local norm = 0.531
local under13 = 0.675

-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data

-- module --
local module = {}

RewardsUI.Claim.Button.MouseButton1Click:Connect(function()
	codesRemote:FireServer("ClaimGroupRewards")
end)

return module