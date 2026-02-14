local TweenService = game:GetService("TweenService")
local Spring = require(script:WaitForChild("Spring"))
local module = {}

function module:Tween(obj : Instance, tweeninfo : TweenInfo, goal : {}, yield : boolean)
	if obj and tweeninfo and goal then
		local tween = TweenService:Create(obj, tweeninfo, goal)
		tween:Play()
		if not yield then
			tween.Completed:Connect(function()
				tween:Destroy()
				tween = nil
			end)
		else
			tween.Completed:Wait()
			tween:Destroy()
			tween = nil
		end
		return tween
	end
end

function module:TweenBounce(obj : Instance, goal : {}, damping : number, frequency : number)
	if obj and goal then
		local finalDamping = damping or 0.375
		local finalFrequency = frequency or 4

		-- Calculate effective settling time (99% completion)
		-- Formula: t = 4.6 / (dampingRatio * frequency * 2π)
		local tweenTime = 4.6 / (finalDamping * finalFrequency * 2 * math.pi)

		-- Start the spring animation
		Spring.target(obj, finalDamping, finalFrequency, goal)

		-- Return both the spring reference and the tween time
		return tweenTime, obj
	end
end

return module