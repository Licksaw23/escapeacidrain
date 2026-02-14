-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")

-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

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
local UpdateSetting = RS.Remotes.Setting

-- modules --
local NewTS = require(Utilities.Tweener)
local Spring = require(Utilities.Tweener.Spring)
local ItemLibrary = require(Libraries.ItemsData)
local flowUtil = require(Utilities.flowUtil)
local ViewportFitter = require(Utilities.ViewportFitter)
local LerpMover = require(Utilities.LerpMover)
local MutationsData = require(Libraries.MutationsData)
local CalculateMoney = require(Utilities.Calculator)
local GetScale = require(script.Parent.Parent.Parent.Handlers.VFX.Scale)
local BrainrotLibrary = require(Libraries.BrainrotsData)
local VFX = require(script.Parent.Parent.Parent.Handlers.VFX)
local Zone = require(Utilities.Zone)
local NumberShortener = require(Utilities.NumberShortener)
local Icon = require(Utilities.Satchel.Packages.topbarplus)

-- ui --
local MainUI = PlayerGui:WaitForChild("MainUI")
local AdminUI = MainUI:WaitForChild("Admin")
local CommandList = AdminUI.Main.ScrollingFrame

local function moveObjectsOfTypeToParent(currentParent, currType, newParent, attribs)
	for _, child in currentParent:GetChildren() do
		if child:IsA(currType) and child.Name ~= "padding" then
			child.Parent = newParent
			for a,b in attribs do child[a] = b end
		end
	end
end

-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data

-- module --
local module = {}

-- settings icon setup --
local adminIcon = Icon.new()
adminIcon:setImage(1158779256)
adminIcon:oneClick()

local isVisible = false
AdminUI.Position = UDim2.fromScale(0.5, 0.6)
AdminUI.Visible = false

adminIcon.selected:Connect(function()
	isVisible = not isVisible
	AdminUI.Visible = isVisible

	NewTS:TweenBounce(AdminUI, {
		["Position"] = isVisible and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.5, 0.6)
	}, 0.5, 3)
end)

local currentCategory = "Server"

for _, button in AdminUI.Main.Type:GetChildren() do
	if button:IsA("Frame") then
		button.Button.MouseButton1Click:Connect(function()
			local getFolder = CommandList[button.Name]
			moveObjectsOfTypeToParent(CommandList, "Frame", CommandList[currentCategory], {Visible = false})
			moveObjectsOfTypeToParent(CommandList[button.Name], "Frame", CommandList, {Visible = true})
			currentCategory = button.Name
		end)
	end
end

module.CurrentTarget = nil

for _, frame in CommandList:GetDescendants() do
	if frame:IsA("Frame") and frame.Parent:IsA("Folder") and frame:FindFirstChild("Garden") then
		if frame.Name == "Target (Player)" then
			frame.Garden.Button.MouseButton1Click:Connect(function()
				local getTB = frame.Target.Text
				if game.Players:FindFirstChild(getTB) then
					module.CurrentTarget = getTB
					frame.Parent["Player (Player)"].Display.Text = "Current Player: "..module.CurrentTarget
				end
			end)
		else
			frame.Garden.Button.MouseButton1Click:Connect(function()
				local textBoxArray = {}

				for _, child in frame:GetChildren() do
					if child:IsA("TextBox") then
						textBoxArray[child.Name] = child.Text
					end
				end

				if string.find(frame.Name, "Player") and module.CurrentTarget ~= nil then
					warn("adding to client list")
					textBoxArray["Target"] = module.CurrentTarget
				end
				
				adminRemote:FireServer(frame.Name, textBoxArray)
			end)
		end
	end
end

return module