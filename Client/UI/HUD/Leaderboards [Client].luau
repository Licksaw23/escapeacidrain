local ViewportModelCFrame = CFrame.new(0, -4, -9) * CFrame.Angles(math.rad(8), math.rad(-13), math.rad(0))
local ViewportPlantCFrame = CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(90), math.rad(20), math.rad(20))

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
local UI = GameFolder.UI

-- modules --

local NewTS = require(Utilities.Tweener)
local ItemLibrary = require(Libraries.ItemsData)
local ViewportFitter = require(Utilities.ViewportFitter)
local NumberShortener = require(Utilities.NumberShortener)

-- ui --

local MainUI = PlayerGui:WaitForChild("MainUI")
local SeedScroll = MainUI.SeedShop.Scrolls.MainScroll

-- data --

local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data
local IndexData = PlayerData.Unlocks

-- remotes --

local RestockRemote = RS.Remotes.UpdateSeedStore
local UpdateLeaderboard = RS.Remotes.UpdateLeaderboard

-- // Code \\ --

local module = {}

-- Load leaderboard UI. --
repeat wait() until Player:GetAttribute("Plot")
local plotFolder = workspace.Plots:WaitForChild(Player:GetAttribute("Plot"))

local newLeaderboardUI = Player.PlayerGui.LeaderboardUI
newLeaderboardUI.Adornee = plotFolder.Leaderboard

local leaderboardList = newLeaderboardUI.Frame.ScrollingFrame

local currentCategory = "Playtime" -- default categ

-- Client Leaderboard Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpdateLeaderboardRemote = ReplicatedStorage.Remotes.UpdateLeaderboard

local module = {}

-- Store current category
local currentCategory = "Playtime" -- default category

local flowUtil = require(Utilities.flowUtil)
local function playSound(Name)
	local SoundPath = Sounds.GameSounds[Name]
	flowUtil:PlaySound(SoundPath,workspace)
end

local function surfaceHover(button)
	if button:GetAttribute("HoverParent") then
		if not button.Parent:FindFirstChild("UIScale") then
			local newScale = Instance.new("UIScale", button.Parent)
			newScale.Scale = 1
		end

		button.MouseEnter:Connect(function()
			NewTS:TweenBounce(button.Parent.UIScale, {
				Scale = 0.95;
			})

			playSound("hover2")
		end)

		button.MouseLeave:Connect(function()
			NewTS:TweenBounce(button.Parent.UIScale, {
				Scale = 1;
			})
			
			playSound("hover2")
		end)

		button.MouseButton1Down:Connect(function()
			NewTS:TweenBounce(button.Parent.UIScale, {
				Scale = 0.8;
			})
		end)

		button.MouseButton1Up:Connect(function()
			NewTS:TweenBounce(button.Parent.UIScale, {
				Scale = 1;
			})
			
			playSound("hover1")
		end)
	end
end

surfaceHover(newLeaderboardUI.Frame.Buttons.Cash.Button)
surfaceHover(newLeaderboardUI.Frame.Buttons.Playtime.Button)
surfaceHover(newLeaderboardUI.Frame.Buttons.Orders.Button)

-- Refresh all the leaderboards when server sends leaderboard data
module.RefreshLeaderboards = function(category, data)
	-- Clear existing frames (only if this is the current category being viewed)
	if category == currentCategory then
		for _, child in ipairs(leaderboardList:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "LeaderboardTemplate" then
				child:Destroy()
			end
		end

		-- Create new frames for each player in the leaderboard
		for _, playerData in ipairs(data) do
			module.CreatePlayerFrame(playerData, currentCategory)
		end
	end
end

local prefix = {["Cash"] = "$"};

module.CreatePlayerFrame = function(data, cat)
	local newTemplate = script.LeaderboardTemplate:Clone()
	newTemplate.Parent = leaderboardList
	newTemplate.PlayerName.Text = data.Name
	newTemplate.Name = "NotTemplate"
	newTemplate.PlayerIcon.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..data.ID.."&width=420&height=420&format=png"
	newTemplate.Amount.Text = NumberShortener.roundNumber(data.Amount)
	if prefix[cat] then
		newTemplate.Amount.Text = prefix[cat]..NumberShortener.roundNumber(data.Amount)
	end
	newTemplate.PlayerIcon.PlayerName.Text = "#"..data.Place

	if newTemplate.PlayerIcon.PlayerName:FindFirstChild(tostring(data.Place)) then 
		newTemplate.PlayerIcon.PlayerName:FindFirstChild(tostring(data.Place)).Enabled = true 
	end

	local newGradient = newLeaderboardUI.Frame.Title:FindFirstChild(cat):Clone()
	newGradient.Enabled = true
	newGradient.Parent = newTemplate.Amount
end

-- Function to switch between leaderboard categories
module.SwitchCategory = function(category)
	currentCategory = category
	newLeaderboardUI.Frame.Title.Text = "Most "..category
	for _, grad in newLeaderboardUI.Frame.Title:GetChildren() do if grad:IsA("UIGradient") then grad.Enabled = false end end
	newLeaderboardUI.Frame.Title[category].Enabled = true
	-- Request updated data for this category from server
	UpdateLeaderboardRemote:FireServer(category)
end

-- Function to get current category
module.GetCurrentCategory = function()
	return currentCategory
end

-- Listen for leaderboard updates from server
UpdateLeaderboardRemote.OnClientEvent:Connect(function(category, data)
	module.RefreshLeaderboards(category, data)
end)

task.delay(0.5, function()
	UpdateLeaderboardRemote:FireServer(currentCategory)
end)

for _, button in newLeaderboardUI.Frame.Buttons:GetChildren() do
	if button:IsA("Frame") then
		button.Button.MouseButton1Click:Connect(function()
			module.SwitchCategory(button.Name)
		end)
	end
end

module.SwitchCategory("Playtime")

return module