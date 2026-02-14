-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")
-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
-- folders --
local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Models = GameFolder.Models.Brainrot3D
local Plants = GameFolder.Models.Plants
local Utilities = Modules.Utilities
local UI = GameFolder.UI
local Libraries = Modules.Libraries
local orderRemote = RS.Remotes.Order
local spawnRemote = RS.Remotes.Spawn
local NewTS = require(Utilities.Tweener)
-- modules --
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
-- ui --
local MainUI = PlayerGui:WaitForChild("MainUI")
-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data
local module = {}
repeat task.wait() until Player:GetAttribute("CPS")
local Plot = Player:GetAttribute("Plot")
local PlotFolder = workspace.Plots[Plot]
local CPSUI = Player.PlayerGui.MainUI:WaitForChild("CashPerSecond")
local brainrotZone = Zone.new(PlotFolder.CPSZone)


local function makeVisible(visible)
	local yPosition = 0.9

	-- Tween from left to center when visible, or from center to left when hiding
	if visible then CPSUI.Position =  UDim2.fromScale(0.2, yPosition) end
	
	NewTS:TweenBounce(CPSUI, {
		["Position"] = visible and UDim2.fromScale(0.5, yPosition) or UDim2.fromScale(0.775, yPosition)
	}, 1, 6)

	for _, child in CPSUI:GetChildren() do
		if child:IsA("TextLabel") then
			NewTS:TweenBounce(child, {
				["TextTransparency"] = visible and 0 or 1
			}, 1, 6)

			local stroke = child:FindFirstChild("UIStroke")
			if stroke then
				NewTS:TweenBounce(stroke, {
					["Transparency"] = visible and 0 or 1
				}, 1, 6)
			end
		end
	end
end

brainrotZone.localPlayerEntered:Connect(function()
	makeVisible(true)
end)

brainrotZone.localPlayerExited:Connect(function()
	makeVisible(false)
end)

makeVisible(false)

local CPS = Player:GetAttribute("CPS")
Player:GetAttributeChangedSignal("CPS"):Connect(function()
	CPSUI.Money.Text = ("$%s/s"):format(NumberShortener.comma(Player:GetAttribute("CPS")))
end)

CPSUI.Money.Text = ("$%s/s"):format(NumberShortener.comma(CPS))

return module