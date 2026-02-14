-- Services --

local Replicated = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Remotes --

local RemotesFolder = Replicated.Remotes
local UpdateRemote = RemotesFolder.Update

-- Modules --

local BezierPath = require(Replicated.Game.Modules.Utilities.BezierPath)

-- // Code \\ --

local updateModule = {}
updateModule.activeLoops = updateModule.activeLoops or {}

UpdateRemote.OnClientEvent:Connect(function(call, model, spawnPos, targetPos, line, duration, movementId)
	if not model or not model.PrimaryPart then return end

	if call == "start" then
		-- Check if there's an existing movement
		local old = updateModule.activeLoops[model]

		-- If we already have a movement, update its path smoothly instead of restarting
		if old and not old.Cancelled then
			-- Calculate how far along we are in the current movement
			local currentT = (tick() - old.StartTime) / old.Duration

			-- Get current position from the model
			local currentPos = model.PrimaryPart.Position

			-- Create new path from current position to new target
			local newPath = BezierPath.new({currentPos, targetPos}, 1)

			-- Update the existing info object (don't replace it)
			old.Path = newPath
			old.StartTime = tick()
			old.Duration = duration
			old.TargetPos = targetPos

			return -- Don't start a new loop, just updated the existing one
		end

		-- No existing movement, create new one
		local Path = BezierPath.new({spawnPos, targetPos}, 1)
		local info = {
			Path = Path,
			StartTime = tick(),
			Duration = duration,
			Cancelled = false,
			MovementId = movementId,
			TargetPos = targetPos,
		}
		updateModule.activeLoops[model] = info

		local offset = model:GetAttribute("CustomerOffset") or 0

		task.spawn(function()
			while true do
				-- Get fresh info from dictionary
				local currentInfo = updateModule.activeLoops[model]

				-- Stop if cancelled or this isn't our movement anymore
				if not currentInfo or currentInfo.Cancelled then 
					return 
				end

				if not model.Parent then 
					updateModule.activeLoops[model] = nil
					return 
				end

				local t = (tick() - currentInfo.StartTime) / currentInfo.Duration

				if t >= 1 then break end

				local cf = currentInfo.Path:CalculateUniformCFrame(math.clamp(t, 0, 1)) * CFrame.new(0, offset, 0)
				model:SetPrimaryPartCFrame(cf)

				task.wait(0.016)
			end

			-- Movement finished
			local finalInfo = updateModule.activeLoops[model]
			if finalInfo and not finalInfo.Cancelled then
				updateModule.activeLoops[model] = nil

				-- Face the desk AFTER movement ends
				if model.Parent and model.Parent.Parent and model.Parent.Parent.Path and model.Parent.Parent.Path[line] then
					local toLookAt = model.Parent.Parent.Path[line].CFrame * CFrame.new(0, offset, 3)
					local lookCFrame = CFrame.lookAt(model.PrimaryPart.Position, toLookAt.Position)
					--TweenService:Create(model.PrimaryPart, TweenInfo.new(1), {CFrame = lookCFrame}):Play()
				end
			end
		end)

	elseif call == "update" then
		-- Server sends position updates as backup
		local info = updateModule.activeLoops[model]
		if info then
			-- Only apply server correction if we're significantly off
			local currentPos = model.PrimaryPart.Position
			local distance = (currentPos - spawnPos).Magnitude

			if distance > 5 then -- Only correct if more than 5 studs off
				model:SetPrimaryPartCFrame(CFrame.new(spawnPos))
			end
		end
	end
end)


return updateModule