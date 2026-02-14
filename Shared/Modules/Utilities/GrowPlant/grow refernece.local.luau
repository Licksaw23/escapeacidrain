task.wait(3)
math.randomseed(script.Parent.Parent.Item_Seed.Value)
local MOD = require(game.ReplicatedStorage.Item_Module)
local Info = MOD.Return_Data(script.Parent.Parent.Name)
local Weight_MOD = require(game.ReplicatedStorage.Calculate_Weight)
local weight = Weight_MOD.Calculate_Weight(script.Parent.Parent.Item_Seed.Value, script.Parent.Parent.Name)
local Variant_MOD = require(game.ReplicatedStorage.Item_Module)
local Variant = Variant_MOD.Return_Random_Rarity(script.Parent.Parent.Item_Seed.Value)
script.Parent.Parent.Weight.Value = weight
local Scale_MOD = require(game.ReplicatedStorage.Scale_Module)
if Info then
	local Percent = script.Parent.Parent.Weight.Value/Info[2]
	script.Parent.Parent:ScaleTo(Percent)
	script.Parent.Parent:AddTag("PlantScaled")
end

local Parts = {}
local Base = script.Parent.Parent.PrimaryPart
for i, v in pairs(script.Parent.Parent:GetDescendants()) do
	if v:IsA("BasePart") and v ~= Base then
		table.insert(Parts, v)
	end
end

local StillGrowing = {}
-- Track all parts, as they need to grow
if not script:GetAttribute("NotRan") then
	script:SetAttribute("NotRan",true)
	for i,v in pairs(Parts) do
		local ObjectOffset = Base.CFrame:ToObjectSpace(v.CFrame) -- Get's the offset from the base cframe

		if false then -- if not v:GetAttribute("Size") and not v:GetAttribute("CFrame") then
			v:SetAttribute("Size",v.Size)
			v:SetAttribute("CFrame",ObjectOffset)
		end

	end
end -- only the parts that need to grow -- only the parts that need to grow




for i, v in pairs(Parts) do
	if v.Parent.Name ~= "Fruit_Spawn" then
		--table.insert(StillGrowing, {v, v:GetAttribute("Size"), v:GetAttribute("CFrame")})
		table.insert(StillGrowing, {v, v.Size, Base.CFrame:ToObjectSpace(v.CFrame)})
	end
end


local TS = game:GetService("TweenService")
local TI = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0)
local MAX_Age = 0
for i,v in pairs(script.Parent.Parent:GetDescendants()) do
	if v:IsA("BasePart") then
		if v.Parent.Name ~= "Fruit_Spawn" then
			if tonumber(v.Name) ~= nil then
				if tonumber(v.Name) and tonumber(v.Name) >= MAX_Age then
					MAX_Age = tonumber(v.Name)
				end
			end
		end
	end
end


function UPD()
	local Current_Age = script.Parent.Age.Value+1


	for i, e in StillGrowing do
		local v = e[1]
		local baseAge = tonumber(v.Name)
		if not baseAge then
			-- Skip parts that don't have a numeric name.
			continue
		end
		local Percent_Grown = Current_Age - baseAge

		Percent_Grown = math.clamp(Percent_Grown, 0, 1)

		local newCFrame = Base.CFrame * e[3]

		if Percent_Grown >= 1 then
			v.Size = e[2]
			v.CFrame = newCFrame
			if v:GetAttribute("DontShow") == nil then
				if v:GetAttribute("Leaf") == nil then
					v.Transparency = 0
				else
					v.Transparency = 0.25
				end
			end
			if v:GetAttribute("CanCollideVal") == nil then
				v.CanCollide = true
			end

			-- mark for removal
			--v:SetAttribute("DoneGrowing", true)
		else
			if Percent_Grown <= 0.025 then
				v.Transparency = 1

				v.Size = Vector3.new(e[2].X, e[2].Y * Percent_Grown, e[2].Z)
				v.CFrame = newCFrame * CFrame.new(0, (v.Size.Y - e[2].Y) / 2, 0)
				v.CanCollide = false
			else
				v.CFrame = newCFrame * CFrame.new(0, (v.Size.Y - e[2].Y) / 2, 0)
				v.Size = Vector3.new(e[2].X, e[2].Y * Percent_Grown, e[2].Z)
				if 	v:GetAttribute("Leaf") then
					v.Transparency = math.clamp(0.1 - Percent_Grown, 0, 1)*0.25+0.5
				else
					v.Transparency = math.clamp(0.1 - Percent_Grown, 0, 1)
				end
				v.CanCollide = false
			end
		end
	end
end

UPD()

script.Parent.Age:GetPropertyChangedSignal("Value"):Connect(UPD)