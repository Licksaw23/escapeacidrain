-- Variables --
local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local camera = workspace.CurrentCamera
local PlotRemote = game.ReplicatedStorage.Remotes.Plot
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

repeat wait() until Player:GetAttribute("Plot")
local GetPlot = workspace.Plots[Player:GetAttribute("Plot")]
local FarmPlot = GetPlot.All
local NewTS = require(game.ReplicatedStorage.Game.Modules.Utilities.Tweener)

-- Raycast --
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.FilterDescendantsInstances = {FarmPlot.Farm1:GetChildren(), FarmPlot.Farm2:GetChildren()}

local function getGroundHit(screenX, screenY)
	local unitRay = camera:ScreenPointToRay(screenX, screenY)
	local rayOrigin = unitRay.Origin
	local rayDirection = unitRay.Direction * 1000 -- max distance
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if result and result.Instance then
		return result.Position
	end
	return nil
end

-- // Code \\ --
local placement = {}
placement.CurrentPlacing = {
	["Active"] = nil;
	["Connections"] = {};
	["Objects"] = {};
	["Position"] = nil;
}

local FlowUtil = require(game.ReplicatedStorage.Game.Modules.Utilities.flowUtil)
local randomSeed = Random.new()

local function randomInt(min, max)
	return randomSeed:NextNumber(min, max)
end



function placement.StartPlacing(info)
	if placement.CurrentPlacing.Active ~= nil then
		placement.StopPlacing(placement.CurrentPlacing.Active)
	end

	local previewPart = Instance.new("Part")
	previewPart.Anchored = true
	previewPart.CanCollide = false
	previewPart.Color = Color3.fromRGB(0, 255, 0)
	previewPart.Size = Vector3.new(2, 1, 2)
	previewPart.Material = Enum.Material.Neon
	previewPart.Transparency = 0.5
	--previewPart.Parent = workspace
	previewPart.Name = "PreviewPart"

	placement.CurrentPlacing.Objects[1] = previewPart
	placement.CurrentPlacing.Active = info.ItemID

	-- Update preview position (works for both PC and mobile)
	placement.CurrentPlacing.Connections["Mouse"] = RunService.RenderStepped:Connect(function()
		local hitPos = getGroundHit(Mouse.X, Mouse.Y)
		if hitPos then
			placement.CurrentPlacing.Position = hitPos
			previewPart.Position = Vector3.new(hitPos.X, hitPos.Y + previewPart.Size.Y / 2, hitPos.Z)
			previewPart.Color = Color3.fromRGB(0, 255, 0)
		else
			placement.CurrentPlacing.Position = nil
			previewPart.Position = Vector3.new(0, -1000, 0)
		end
	end)

	-- Handle both mouse clicks AND touch taps
	placement.CurrentPlacing.Connections["Input"] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Check if it's a mouse click or touch tap
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			-- Get the position where user clicked/tapped
			local screenPos = input.Position
			local hitPos = getGroundHit(screenPos.X, screenPos.Y)

			if hitPos then
				local infoTable = {
					["RawPosition"] = hitPos;
					["ID"] = info.ItemID; 
				}
				
				PlotRemote:FireServer("PlacePlant", infoTable)
				
				task.spawn(function()
					local PlantPart = game.ReplicatedStorage.Game.Models.Plants.GrowPart:Clone()
					PlantPart.CFrame = CFrame.new(hitPos.X, hitPos.Y, hitPos.Z) * CFrame.Angles(0, math.rad(math.random(1, 90)), math.rad(90))
					PlantPart.Parent = workspace

					FlowUtil:PlaySound(game.ReplicatedStorage.Game.Sounds.GameSounds.Plant, PlantPart)
					NewTS:TweenBounce(PlantPart, {Transparency = 1}, 0.95, 1.25)

					game:GetService("Debris"):AddItem(PlantPart,5)
				end)
			
				
				
				
				
				placement.StopPlacing(info.ItemID)
			end
		end
	end)
end

function placement.StopPlacing(ID)
	for _, conn in placement.CurrentPlacing.Connections do
		conn:Disconnect()
	end
	for _, obj in placement.CurrentPlacing.Objects do
		obj:Destroy()
	end
	placement.CurrentPlacing.Objects = {}
	placement.CurrentPlacing.Connections = {}
	placement.CurrentPlacing.Active = nil
	placement.CurrentPlacing.Position = nil
end

return placement