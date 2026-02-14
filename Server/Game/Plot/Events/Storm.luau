local event = {}
local TweenService = game:GetService("TweenService")

local UIRemote = game.ReplicatedStorage.Remotes.UI
local FXRemote = game.ReplicatedStorage.Remotes.FX
local SpawnRemote = game.ReplicatedStorage.Remotes.Spawn

local ServerUtil = require(script.Parent.Parent.Parent.ServerUtility)
local PlotModule = require(script.Parent.Parent)

event.EVENT_TIME = 60
event.Connections = {}
event.Objects = {}
event.Threads = {}
event.Tweens = {}

local function chance(percentage)
	return math.random(1, 100) <= percentage
end

event.Start = function(callback) -- start it all --
	UIRemote:FireAllClients("TopNotification", {
		["Text"] = 'A <font color="#0000FF">storm</font> is approaching..';
		["Duration"] = 5;
		["RichText"] = true;
		["TextColor"] = Color3.fromRGB(255, 255, 255);
	})
	
	UIRemote:FireAllClients("Timer", {
		["Text"] = "Storm Event";
		["Gradient"] = "Storm";
		["Time"] = 60;
	})

	event.Tweens[1] = TweenService:Create(workspace.Terrain.Clouds, TweenInfo.new(3), {Cover = 1; Density = 1}):Play()
	event.Tweens[2] = TweenService:Create(game.Lighting, TweenInfo.new(3), {
		Brightness = 0;
		OutdoorAmbient = Color3.fromRGB(10,49,220);
		ExposureCompensation = -1;
	}):Play()

	event.Threads["End"] = task.delay(event.EVENT_TIME, function()
		event.Threads["End"] = nil
		event.End(callback)
	end)

	event.Threads["Lightning"] = task.spawn(function()
		while event.Threads["End"] do
			if chance(100) then
				warn("1")
				for _, plotSelf in PlotModule.Plots do
					local Hittables = {}

					for _, plant in plotSelf.Folder.Plants:GetChildren() do
						if plant:IsA("Model") and plant.PrimaryPart then
							table.insert(Hittables, {
								["Object"] = plant:GetAttribute("ID");
								["CFrame"] = plant.PrimaryPart.CFrame;
								["Type"] = "Plant"
							})
						end
					end

					for ID, cache in plotSelf.Active do
						if not table.find(cache.Mutations, "Shocked") then
							table.insert(Hittables, {
								["Object"] = ID;
								["CFrame"] = cache.Position;
								["Type"] = "Customer"
							})
						end
					end

					if chance(20) and #Hittables > 0 then
						-- Strike a random hittable object
						local target = Hittables[math.random(1, #Hittables)]
						FXRemote:FireAllClients("Replicate", {["Call"] = "StormEvent", ["Event"] = "Strike"; ["CFrame"] = target.CFrame})
						
						if target.Type == "Plant" then
							local function SetAndApply(path, index, effect)
								-- DATA --
								if not index then return end
								if not effect then return end
								ServerUtil.ActiveFruit[target.Object..index](nil, "UpdateMutations", effect)
								-- EFFECT & OVERHEAD --
							end
							
							local getPlantInData = plotSelf.OwnerData.Plot[target.Object]
							local fruits = {}
							
							for _, fruit in plotSelf.Folder.Plants:FindFirstChild(target.Object):GetDescendants() do
								if fruit:GetAttribute("ReadyToHarvest") then
									table.insert(fruits, fruit:GetAttribute("DataIndex"))
								end
							end
							
							-- guaranteed to hit 1 fruit --
							SetAndApply("Plot", fruits[1], "Shocked")
							
							if #fruits > 1 then
								for i, v in fruits do
									if i > 1 then
										if chance(25) then
											warn("DOUBLE STRIKE.")
											SetAndApply("Plot", fruits[i], "Shocked")
										end
									end
								end
							end
						elseif target.Type == "Customer" then
							local brainrotCache = plotSelf.Active[target.Object]
							table.insert(brainrotCache.Mutations, "Shocked")
							SpawnRemote:FireAllClients("MutateBrainrot", {["ID"] = target.Object, ["Mutation"] = "Shocked"})
						end
					else
						-- Strike random location on plot instead
						local plotCFrame = plotSelf.Folder.Plate.CFrame
						local plotSize = plotSelf.Folder.Plate.Size
						local randomOffset = Vector3.new(
							math.random(-plotSize.X/2, plotSize.X/2),
							0,
							math.random(-plotSize.Z/2, plotSize.Z/2)
						)
						local strikePosition = plotCFrame.Position + randomOffset
						FXRemote:FireAllClients("Replicate", {["Call"] = "StormEvent", ["Event"] = "Strike"; ["CFrame"] = CFrame.new(randomOffset)})
				
					end
				end
			end

			task.wait(math.random(2, 5)) -- Random interval between potential strikes
		end
	end)
end

event.End = function(callback) -- clear it all --
	for _, Conn in event.Connections do
		Conn:Disconnect()
	end
	for _, Object in event.Objects do
		Object:Destroy()
	end
	for _, Thread in event.Threads do
		task.cancel(Thread)
	end
	for _, Tween in event.Tweens do
		Tween:Cancel()
	end
	event.Connections = {}; event.Objects = {}; event.Threads = {}; event.Tweens = {}
	TweenService:Create(workspace.Terrain.Clouds, TweenInfo.new(3), {Cover = 0.5; Density = 0.7}):Play()
	TweenService:Create(game.Lighting, TweenInfo.new(3), {
		Brightness = 2.75;
		OutdoorAmbient = Color3.fromRGB(220,130,65);
		ExposureCompensation = 0;
	}):Play()
end

return event