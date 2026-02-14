local GearsPlacement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlotRemote = ReplicatedStorage.Remotes.Plot
local GearsData = require(ReplicatedStorage.Game.Modules.Libraries.GearsData)

local CurrentPlacement = {
	Active = false,
	Connections = {},
	PreviewModel = nil,
	RangeIndicator = nil,
	Position = nil,
	GearData = nil,
	RotationTween = nil
}

local function getPlayerPlot()
	repeat task.wait() until Player:GetAttribute("Plot")
	local plotName = Player:GetAttribute("Plot")
	return workspace.Plots[plotName]
end

local function setupRaycastParams(farmPlot)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local instances = {}
	for _, child in ipairs(farmPlot.Farm1:GetChildren()) do
		table.insert(instances, child)
	end
	for _, child in ipairs(farmPlot.Farm2:GetChildren()) do
		table.insert(instances, child)
	end

	raycastParams.FilterDescendantsInstances = instances
	return raycastParams
end

local function getGroundHit(screenX, screenY, raycastParams)
	local unitRay = Camera:ScreenPointToRay(screenX, screenY)
	local rayOrigin = unitRay.Origin
	local rayDirection = unitRay.Direction * 1000

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if result and result.Instance then
		return result.Position
	end
	return nil
end

local function createPreviewModel(gearModel)
	local previewModel = gearModel:Clone()

	for _, descendant in ipairs(previewModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			
			if  descendant.Transparency ~= 1 then
				descendant.Transparency = 0.5
			end
			
	
			descendant.CanCollide = false
			descendant.Anchored = true
		end
	end

	previewModel.Parent = workspace
	previewModel.Name = "PreviewModel"

	if not previewModel.PrimaryPart then
		previewModel.PrimaryPart = previewModel:FindFirstChildWhichIsA("BasePart")
	end

	return previewModel
end

local function createRangeIndicator(radius)
	local rangeIndicatorPart = ReplicatedStorage.Game.UI.Range:Clone()
	rangeIndicatorPart.Parent = workspace
	rangeIndicatorPart.Size = Vector3.new(radius * 2, 0.1, radius * 2)
	rangeIndicatorPart.CanCollide = false
	rangeIndicatorPart.CanQuery = false
	rangeIndicatorPart.Anchored = true

	local ringImageLabel = rangeIndicatorPart:FindFirstChild("Range")
		and rangeIndicatorPart.Range:FindFirstChild("Holder")
		and rangeIndicatorPart.Range.Holder:FindFirstChild("InnerRing")
		and rangeIndicatorPart.Range.Holder.InnerRing:FindFirstChild("Ring")

	local rotationTween = nil
	if ringImageLabel and ringImageLabel:IsA("ImageLabel") then
		rotationTween = TweenService:Create(
			ringImageLabel,
			TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0),
			{Rotation = 360}
		)
		rotationTween:Play()
	end

	return rangeIndicatorPart, rotationTween
end

function GearsPlacement:StopPlacing()
	for _, conn in pairs(CurrentPlacement.Connections) do
		if conn then
			conn:Disconnect()
		end
	end
	CurrentPlacement.Connections = {}

	if CurrentPlacement.RotationTween then
		CurrentPlacement.RotationTween:Cancel()
		CurrentPlacement.RotationTween = nil
	end

	if CurrentPlacement.PreviewModel then
		CurrentPlacement.PreviewModel:Destroy()
		CurrentPlacement.PreviewModel = nil
	end

	if CurrentPlacement.RangeIndicator then
		CurrentPlacement.RangeIndicator:Destroy()
		CurrentPlacement.RangeIndicator = nil
	end

	CurrentPlacement.Active = false
	CurrentPlacement.Position = nil
	CurrentPlacement.GearData = nil
end

function GearsPlacement:StartPlacing(gearTool)
	if CurrentPlacement.Active then
		self:StopPlacing()
	end

	local gearID = gearTool:GetAttribute("ID")
	local gearName = gearTool.Name:match("%]%s*(.+)")
	local gearData = GearsData[gearName]

	if not gearData then
		warn("GearsPlacement: No data found for gear '" .. tostring(gearName) .. "'")
		return false
	end

	CurrentPlacement.GearData = gearData

	local gearModel = ReplicatedStorage.Game.Models.Gears:FindFirstChild(gearName)
	if not gearModel then
		warn("GearsPlacement: No model found for " .. gearName)
		return false
	end

	local plot = getPlayerPlot()
	local farmPlot = plot.All
	local raycastParams = setupRaycastParams(farmPlot)

	local previewModel = createPreviewModel(gearModel)
	CurrentPlacement.PreviewModel = previewModel

	local radius = gearData.PlaceableData and gearData.PlaceableData.Radius or 25
	local rangeIndicator, rotationTween = createRangeIndicator(radius)
	CurrentPlacement.RangeIndicator = rangeIndicator
	CurrentPlacement.RotationTween = rotationTween

	CurrentPlacement.Active = true

	CurrentPlacement.Connections.UpdatePosition = RunService.RenderStepped:Connect(function()
		local mouse = Player:GetMouse()
		local hitPos = getGroundHit(mouse.X, mouse.Y, raycastParams)

		if hitPos and previewModel.PrimaryPart then
			CurrentPlacement.Position = hitPos

			local rootPart = previewModel.PrimaryPart
			local groundY = hitPos.Y

			local targetCFrame = CFrame.new(
				hitPos.X,
				groundY + (rootPart.Size.Y / 2) + (gearData and gearData.ManualOffset or 0),
				hitPos.Z
			) * CFrame.Angles(math.rad(90), 0, 0)

			previewModel:PivotTo(targetCFrame)

			rangeIndicator.CFrame = CFrame.new(
				hitPos.X,
				groundY + 0.05,
				hitPos.Z
			)
		else
			CurrentPlacement.Position = nil
			if previewModel.PrimaryPart then
				previewModel:PivotTo(CFrame.new(0, -1000, 0))
				rangeIndicator.CFrame = CFrame.new(0, -1000, 0)
			end
		end
	end)

	CurrentPlacement.Connections.Input = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then

			local mouse = Player:GetMouse()
			local hitPos = getGroundHit(mouse.X, mouse.Y, raycastParams)

			if hitPos then
				local infoTable = {
					RawPosition = hitPos,
					ID = gearID,
				}

				-- Validate we still have the gear before placing
				local PlayerReplica = require(ReplicatedStorage:WaitForChild("PlayerData")):GetData()
				if not PlayerReplica.Data.Inventory[gearID] then
					self:StopPlacing()
					return
				end

				if gearTool:GetAttribute("Quantity") <= 1 then
					self:StopPlacing()
				end

				PlotRemote:FireServer("PlaceGear", {RawPosition = hitPos,ID = gearID})

				local flowutil = require(ReplicatedStorage.Game.Modules.Utilities.flowUtil)
				flowutil:PlaySound(ReplicatedStorage.Game.Sounds.GameSounds.PlaceGear,workspace,true)
			end
		end
	end)

	return true
end

function GearsPlacement:IsPlacing()
	return CurrentPlacement.Active
end

function GearsPlacement:GetPosition()
	return CurrentPlacement.Position
end

function GearsPlacement:SetupTool(tool)
	local equipped = tool.Equipped:Connect(function()
		self:StartPlacing(tool)
	end)

	local unequipped = tool.Unequipped:Connect(function()
		self:StopPlacing()
	end)

	return {equipped, unequipped}
end

return GearsPlacement
