local mUtil = require(script.MutationUtil)

local function applyParticle(model, particle)
	if model:IsA("Tool") then
		model.PrimaryPart = model:FindFirstChild("Handle")
	end

	if not model.PrimaryPart then
		if model:FindFirstChild("RootPart") then
			model.PrimaryPart = model.RootPart
		end
		return
	end

	local burningPart = script.MutationVFX[particle]:Clone()
	burningPart.Anchored = false
	burningPart.CanCollide = false
	burningPart.Massless = true
	burningPart.Name = "MUTATIONVFX"


	local boundingTable = mUtil.GetExactBoundingBox(model)
	local bboxSize = boundingTable.Size
	local pos = boundingTable.Position

	burningPart.Size = bboxSize / 1.5
	local root = model.PrimaryPart
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)


	burningPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	burningPart.Parent = model
	
	
	
	local weld = Instance.new("Motor6D") 
	weld.Part0 = burningPart 
	weld.Part1 = root 
	
	weld.C0 = burningPart.CFrame:ToObjectSpace(root.CFrame)

	
	weld.Parent = burningPart 
	mUtil.ResizeAllParticles(burningPart, bboxSize.Y / 10.8963)
end

return {
	-- // ROLLABLE (MUTATIONS) \\ --
	
	["Normal"] = {
		Multiplier = 1;
		Gradient = script.Normal;
		Chance = 100;
	};
	
	["Gold"] = {
		Multiplier = 2;
		Gradient = script.Gold;
		Chance = 25;
		
		Apply = function(model)
			mUtil.Tint(model,Color3.fromRGB(255, 221, 26))
		end,
	};
	
	["Petrified"] = {
		Multiplier = 1.5;
		Gradient = script.Petrified;
		Chance = 30;

		Apply = function(model)
			mUtil.Tint(model,Color3.fromRGB(138, 138, 138))
			mUtil.Material(model, Enum.Material.Concrete)
		end,
	};
	
	["Emerald"] = {
		Multiplier = 3.5;
		Gradient = script.Emerald;
		Chance = 8;

		Apply = function(model)
			mUtil.Tint(model,Color3.fromRGB(61, 252, 58))
			mUtil.Material(model, Enum.Material.Foil)
		end,
	};
	
	["Diamond"] = {
		Multiplier = 5;
		Gradient = script.Diamond;
		Chance = 5;

		Apply = function(model)
			mUtil.Tint(model,Color3.fromRGB(29, 214, 255))
		end,
	};
	
	["Rainbow"] = {
		Multiplier = 10;
		Gradient = script.Rainbow;
		Chance = 1.4; -- 0.8%
		Apply = function(model, requiredParent)
			local Gradient3 = {
				Color3.fromRGB(255, 0, 0),     -- Red
				Color3.fromRGB(255, 127, 0),   -- Orange
				Color3.fromRGB(255, 255, 0),   -- Yellow
				Color3.fromRGB(0, 255, 0),     -- Green
				Color3.fromRGB(0, 127, 255),   -- Blue
				Color3.fromRGB(75, 0, 130),    -- Indigo
				Color3.fromRGB(148, 0, 211)    -- Violet
			}

			task.spawn(function()
				local index = 1
				local progress = 0
				
				local neededParent = requiredParent or workspace 

				while model:IsDescendantOf(neededParent) do
					local currentColor = Gradient3[index]
					local nextIndex = index % #Gradient3 + 1
					local nextColor = Gradient3[nextIndex]

					local blendedColor = currentColor:Lerp(nextColor, progress)
					mUtil.Tint(model, blendedColor)

					progress = progress + 0.02

					if progress >= 1 then
						progress = 0
						index = nextIndex
					end
					
					task.wait()
				end
			end)
		end
	};
	
	-- // EVENT ONLY (EFFECTS) \\ --
	
	["Wet"] = {
		Multiplier = 1.5;
		Chance = 0;
		IsEffect = true;
		Gradient = script.Wet;
		Icon = "rbxassetid://89301420054411";
		Apply = function(model)
			applyParticle(model, "wet")
		end,
	};

	["Sandy"] = {
		Multiplier = 2;
		Chance = 0;
		IsEffect = true;
		Gradient = script.Sandy;
		Icon = "rbxassetid://119181217383917";
		Apply = function(model)
			applyParticle(model, "sand")
		end,
	};
	
	["Zombified"] = {
		Multiplier = 3;
		Chance = 0;
		IsEffect = true;
		Gradient = script.Zombified;
		Icon = "rbxassetid://89301420054411";
		Apply = function(model)
			applyParticle(model, "zombfied")
		end,
	};
	
	["Haunted"] = {
		Multiplier = 2.5;
		Chance = 0;
		IsEffect = true;
		Gradient = script.Haunted;
		Icon = "rbxassetid://89301420054411";
		Apply = function(model)
			applyParticle(model, "haunted")
		end,
	};
	
	["Burning"] = {
		Multiplier = 1.5;
		Chance = 0;
		IsEffect = true;
		Gradient = script.Burning;
		Icon = "rbxassetid://89301420054411";
		Apply = function(model)
			applyParticle(model, "burning")
		end,
	};
	
	["Chilled"] = {
		Multiplier = 1.5;
		Chance = 0;
		IsEffect = true;
		Gradient = script.Chilled;
		Icon = "rbxassetid://15740392348";
		Apply = function(model)
			applyParticle(model,"chilled")
		end,
	};
	
	["Shocked"] = {
		Multiplier = 1.5;
		Chance = 0;
		IsEffect = true;
		Gradient = script.Shocked;
		Icon = "rbxassetid://135340638057434";
		Apply = function(model)
			applyParticle(model,"shock")

		end,
	};
	
	["Corrupted"] = {
		Multiplier = 1.5;
		Chance = 0;
		IsEffect = true;
		Gradient = script.Corrupted;
		Icon = "rbxassetid://120769463257698";
		Apply = function(model)
		
			applyParticle(model,"corrupted")

		end,
	}
}