local MutationsModule = require(game.ReplicatedStorage.Game.Modules.Libraries.MutationsData)
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local hasPreloaded

return function(info)
	if true == true then
		return
	end
	local Tool = info.Tool
	local BrainrotID = info.BrainrotID
	local PlotFolder = workspace.Plots[info.PlotNumber]
	local Brainrot = PlotFolder.Customers:FindFirstChild(BrainrotID)

	if not Brainrot then
		warn("Brainrot not found!")
		return
	end

	-- Clone the tool for visual effect
	local ToolClone = Tool:Clone()
	ToolClone.Parent = workspace

	local startPos = info.HandlePos

	-- Get target position (Brainrot's center using bounding box)
	local brainrotCenter, df = Brainrot:GetBoundingBox()
	local targetPos = brainrotCenter.Position

	-- Quadratic Bezier curve function
	local function quadraticBezier(p0, p1, p2, t)
		local l1 = p0:Lerp(p1, t)
		local l2 = p1:Lerp(p2, t)
		return l1:Lerp(l2, t)
	end

	-- Create control point above and to the side for nice curve
	local midPoint = (startPos + targetPos) / 2
	local controlPoint = midPoint + Vector3.new(
		math.random(-5, 5),
		math.random(8, 15),
		math.random(-5, 5)
	)

	-- Make ALL parts non-collidable
	for _, part in ToolClone:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	-- Position the tool at start using PivotTo
	ToolClone:PivotTo(CFrame.new(startPos))

	-- Animate tool along bezier curve to Brainrot using PivotTo
	local startTime = tick()
	local duration = 0.5
	local toolConnection
	toolConnection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local alpha = math.min(elapsed / duration, 1)
		local easedAlpha = 1 - math.cos(alpha * math.pi / 2)

		-- Calculate position on bezier curve
		local currentPos = quadraticBezier(startPos, controlPoint, targetPos, easedAlpha)

		-- Move the tool using PivotTo (keeps all welded parts together)
		ToolClone:PivotTo(CFrame.new(currentPos))

		if alpha >= 1 then
			toolConnection:Disconnect()
			ToolClone:Destroy()
		end
	end)
end