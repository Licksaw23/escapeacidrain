-- thank you for using my module -- made by Shin#7031
-- plss give proper creadit dont just claim the module for ur self --

-------------------------
--Verison 1.1
-------------------------


local clock = os.clock
local box = script.B
local cylinder = script.C

local tweenS = game:GetService("TweenService")
local FastWait = require(script:WaitForChild("FastWait"))
local stuff = Instance.new("Folder")
stuff.Name = "LightningDebri"
stuff.Parent = workspace

--[[
	Strike.new(
		"cylinder",				--Block Usage (can be set to cylinder or cube/box shape)
		ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255,50,50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0,255,255)),
		},					--BlockColor (lighting color)
		3,					--ColorOffset Howfast u want the color to travel through the lightning
		false,				--ColorJuggle turn on if u want to juggle the colors of the color squence
		script.Parent,		--Start Point
		workspace.Part2,	--End Point
		false,				--Focused or Spread (will spread to the part depending on what u set it to)
		math.random(1,2),	--Size (lightning size)
		15,					--Main Segments (basically how many segments u want the lighting to have going above 600 can lag the game)
		2.5,					--OffSet (set to higher number to make more zigzag effect)
		nil,				--Fade effect (set to nil if u want the lightning to strike imidielty)
		1,					--Aniamtion Speed (basically how long it would take for the lightning to disapear)
		2.5,				--FadeMovement (set to 0 to make it fade to the middle the higher it is the more it fade's to the side)
		0					--Sparks set to nil to disable		
	)
]]
local Strike = {}
function Strike.new(leblock,Bcolor,ColorOffsetSpeed,ColorJ,start,endto,spot,size,segments,off,speed,fadespeed,FadeMovement,extra)
	if leblock == "box" then
		leblock = box
	elseif leblock == "cylinder" then
		leblock = cylinder
	end
	local from
	if start:IsA("BasePart") then
		from = start.Position
	else
		from = start.WorldPosition
	end
	local too
	if endto:IsA("BasePart") then
		too = endto.Position
	else
		too = endto.WorldPosition
	end
	local StartT = clock()
	local RanNum = math.random()*100
	if not spot then
		if start:IsA("BasePart") then
			from = Vector3.new(
				(start.Position.X + math.random(-start.Size.x,start.Size.x)/2),
				(start.Position.Y + math.random(-start.Size.y,start.Size.y)/2),
				(start.Position.Z + math.random(-start.Size.z,start.Size.z)/2)
			)
		end

		if endto:IsA("BasePart") then
			too = Vector3.new(
				(endto.Position.X + math.random(-endto.Size.x,endto.Size.x)/2),
				(endto.Position.Y + math.random(-endto.Size.y,endto.Size.y)/2),
				(endto.Position.Z + math.random(-endto.Size.z,endto.Size.z)/2)
			)
		end
	end
	local Model = Instance.new("Model",stuff)
	Model.Name = "LightningDebris"
	local points = {}
	local points2 = {}
	for i  = 0,segments do

		local offset = Vector3.new(math.random(-off,off),math.random(-off,off),math.random(-off,off))
		local pos = from + (too - from).Unit *i* (too - from).Magnitude / segments
		if i == 0 or i == segments then
			offset = Vector3.new(0, 0, 0)
		end
		points[#points + 1] = pos + offset
		points2[#points2 + 1] = pos + offset * FadeMovement
	end
	local num = 0.8/segments
	local num2 = 0
	local timePassed = clock() - StartT
	spawn(function()
		for i = 1,#points do
			if points[i+1] ~= nil and points2[i+1] ~= nil then
				if speed then
					FastWait(speed/segments)
				end
				local t1 = i/#points
				local p = leblock:Clone()
				if typeof(Bcolor) == "Color3" then
					p.Color = Bcolor
				else --ColorSequence
					if ColorJ == true then
						local keypoints = Bcolor.Keypoints
						t1 = (RanNum + t1 - timePassed*ColorOffsetSpeed)%1
						for i = 1, #keypoints - 1 do --convert colorsequence onto lightning
							if keypoints[i].Time < t1 and t1 < keypoints[i+1].Time then
								p.Color = keypoints[i].Value:lerp(keypoints[i+1].Value, (t1 - keypoints[i].Time)/(keypoints[i+1].Time - keypoints[i].Time))
								break
							end
						end
					else
						local keypoints = Bcolor.Keypoints
						for i = 1, #keypoints - 1 do --convert colorsequence onto lightning
							p.Color = keypoints[i].Value:lerp(keypoints[i+1].Value, num2)
							break
						end
					end
				end
				num2 = num2 + num
				--num2 = num2 + num
				p.Parent = Model
				p.Size = Vector3.new(size,size,(points[i] - points[i + 1]).Magnitude)
				p.CFrame = CFrame.new((points[i] + points[i +1])/2, points[i +1])
					--[[spawn(function()
						if extra then
							for t = 0, extra do
								local semipoints = {}
								local semipoints2 = {}

								for i  = 0,5 do
									local offset = Vector3.new(math.random(-0.25,0.25),math.random(-0.25,0.25),math.random(-0.25,0.25))
									local pos = p.Position + (p.Position+Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5)) - p.Position).Unit *i* (p.Position+Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5)) - p.Position).Magnitude / 5
									if i == 0 or i == 2 then
										offset = Vector3.new(0, 0, 0)
									end
									semipoints[#semipoints + 1] = pos + offset
									semipoints2[#semipoints2 + 1] = pos + offset * 12
								end
								for i = 1,#semipoints do
									if semipoints[i+1] ~= nil and semipoints2[i+1] ~= nil then
										if speed then
											FastWait(speed/segments)
										end

										local sp = leblock:Clone()
										sp.Parent = Model
										sp.Size = Vector3.new((size/5),(size/5),(semipoints[i] - semipoints[i + 1]).Magnitude)
										sp.CFrame = CFrame.new((semipoints[i] + semipoints[i +1])/2, semipoints[i +1])
										local goal = {}
										goal.CFrame = CFrame.new((semipoints2[i] + semipoints2[i +1])/2, semipoints2[i +1])
										goal.Size = Vector3.new(0,0,(semipoints2[i] - semipoints2[i + 1]).Magnitude)
										goal.Transparency = 1
										local control = tweenS:Create(sp, TweenInfo.new(fadespeed,Enum.EasingStyle.Linear),goal)
										control:Play()
										game.Debris:AddItem(sp,1.5)
									end
								end
							end
						end
					end)]]
				local goal = {}
				goal.CFrame = CFrame.new((points2[i] + points2[i +1])/2, points2[i +1])
				goal.Size = Vector3.new(0,0,(points2[i] - points2[i + 1]).Magnitude)
				goal.Transparency = 1
				local control = tweenS:Create(p, TweenInfo.new(fadespeed,Enum.EasingStyle.Linear),goal)
				local Tfade = tweenS:Create(p, TweenInfo.new(5,Enum.EasingStyle.Elastic), {Transparency = 1})
				--Tfade:Play()
				control:Play()
				game.Debris:AddItem(p,fadespeed*1.5)
			end
		end
	end)
	return Model
end
return Strike
