-- player --

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera

-- services --

local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")

-- folders --

local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local Libraries = Modules.Libraries
local Rarities = GameFolder.UI.Gradients

-- remotes --

local SettingRemote = RS.Remotes.Setting

-- modules --

local NewTS = require(Utilities.Tweener)
local ItemLibrary = require(Libraries.ItemsData)
local MutationsLibrary = require(Libraries.MutationsData)
local MutationsUtil = require(Libraries.MutationsData.MutationUtil)
local BrainrotLibrary = require(Libraries.BrainrotsData)

-- ui --

local MainUI = PlayerGui:WaitForChild("MainUI")
local Index = MainUI.Index
local IndexCategories = Index.Main.Categories
local BrainrotModels = RS.Game.Models.Brainrot3D
local AutoDeny = MainUI.AutoDeny.MainScroll

-- data --

local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data

-- // Code \\ --

local module = {}

module.RarityConverters = {
	["Rare"] = 1;
	["Epic"] = 2;
	["Legendary"] = 3;
	["Mythic"] = 4;
	["Godly"] = 5;
	["Secret"] = 6;
}

for _, rarity in Rarities:GetChildren() do
	local newTemplate = AutoDeny.Template:Clone()
	newTemplate.LayoutOrder = module.RarityConverters[rarity.Name]
	local newGrad1 = rarity:Clone()
	local newGrad2 = rarity:Clone()
	local newGrad3 = rarity:Clone()
	newTemplate.TextLabel.Text = rarity.Name
	newGrad1.Parent = newTemplate.Inner
	newGrad2.Parent = newTemplate.ImageLabel
	newGrad3.Parent = newTemplate.Shadow
	newGrad1.Name = "Gradient"
	newGrad2.Name = "Gradient"
	newTemplate.Visible = true
	newTemplate.Parent = AutoDeny
	
	local function adjustBool(bool)
		newGrad1.Enabled = not bool; newGrad2.Enabled = not bool
	end
	
	adjustBool(PlayerData.Settings.AutoSell[rarity.Name] or false)
	
	newTemplate.Button.MouseButton1Click:Connect(function()
		local SettingData = PlayerData.Settings.AutoSell[rarity.Name]
		
		local newValue = nil
		if not SettingData then newValue = false else newValue = SettingData end
		
		SettingRemote:FireServer("AutoSell", {
			["Rarity"] = rarity.Name;
			["Value"] = not newValue;
		})
		
		newValue = not newValue
		adjustBool(newValue)
	end)
end

return module