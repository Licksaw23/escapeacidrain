local module = {}

local function GetTintableParts(model)
	local parts = {}
	for _, obj in model:GetDescendants() do
		if (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("SurfaceAppearance") or obj:IsA("Decal") or obj:IsA("Texture")) and not obj:HasTag("NoTint") then
			table.insert(parts, obj)
		end
	end

	table.sort(parts, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	return parts
end

	module.Tint = function(model, color, exponent)
		if model and color then
			local brightnessExponent = exponent or 1.15
			local h, s, _ = color:ToHSV()
			local allParts = GetTintableParts(model)

			for _, part in ipairs(allParts) do
				if part:IsA("Decal") or part:IsA("Texture") then
					-- Handle Decals and Textures
					if not part:GetAttribute("BaseColor") then
						part:SetAttribute("BaseColor", part.Color3)
					end
					local _, _, vOriginal = (part:GetAttribute("BaseColor") or part.Color3):ToHSV()
					part.Color3 = Color3.fromHSV(h, s, vOriginal ^ brightnessExponent)
				else
					-- Handle BaseParts, MeshParts, and SurfaceAppearances
					if not part:GetAttribute("BaseColor") then
						part:SetAttribute("BaseColor", part.Color)
					end
					local _, _, vOriginal = (part:GetAttribute("BaseColor") or part.Color):ToHSV()
					part.Color = Color3.fromHSV(h, s, vOriginal ^ brightnessExponent)
				end
			end

			model:SetAttribute("TintedOnce", true)
		end
	end


module.TintPart = function(part, color, exponent)
	if part and color then
		local brightnessExponent = exponent or 1.15
		local h, s, _ = color:ToHSV()
		local allParts = {part}

		for _, part in ipairs(allParts) do
			if part:IsA("Decal") or part:IsA("Texture") then
				-- Handle Decals and Textures
				if not part:GetAttribute("BaseColor") then
					part:SetAttribute("BaseColor", part.Color3)
				end
				local _, _, vOriginal = (part:GetAttribute("BaseColor") or part.Color3):ToHSV()
				part.Color3 = Color3.fromHSV(h, s, vOriginal ^ brightnessExponent)
			else
				-- Handle BaseParts, MeshParts, and SurfaceAppearances
				if not part:GetAttribute("BaseColor") then
					part:SetAttribute("BaseColor", part.Color)
				end
				local _, _, vOriginal = (part:GetAttribute("BaseColor") or part.Color):ToHSV()
				part.Color = Color3.fromHSV(h, s, vOriginal ^ brightnessExponent)
			end
		end

		
	end
end

module.Material = function(model, material)
	if model then
		for _, obj in model:GetDescendants() do
			if obj:IsA("BasePart") or obj:IsA("MeshPart") then
				obj.Material = material
			end
		end
	end
end

module.ResizeParticle = function(particle,scale)
	local property = "Size"
	for _, target in pairs({ particle }) do
		local newKeypoints = {}
		for _, keypoint in pairs(target[property].Keypoints) do
			table.insert(newKeypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope))
		end
		target[property] = NumberSequence.new(newKeypoints)
	end
	return
end

module.ResizeAllParticles = function(object,scale)
	for _,particle in object:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			module.ResizeParticle(particle,scale)
		end
	end
end

module.GetExactBoundingBox = function(model)
	if model:IsA("Model") then
		local minBounds = Vector3.new(1, 1, 1) * (1 / 0)
		local maxBounds = -minBounds
		local descendants = model:GetDescendants()
		if #descendants ~= 0 then
			for _, descendant in descendants do
				if descendant:IsA("BasePart") then
					local partCFrame = descendant.CFrame
					local partSize = descendant.Size
					local halfWidth = partSize.X / 2
					local halfHeight = partSize.Y / 2
					local halfDepth = partSize.Z / 2
					local negHalfWidth = -halfWidth
					local negHalfHeight = -halfHeight
					local negHalfDepth = -halfDepth
					for _, cornerPosition in {
						partCFrame * Vector3.new(negHalfWidth, negHalfHeight, negHalfDepth),
						partCFrame * Vector3.new(halfWidth, negHalfHeight, negHalfDepth),
						partCFrame * Vector3.new(negHalfWidth, halfHeight, negHalfDepth),
						partCFrame * Vector3.new(halfWidth, halfHeight, negHalfDepth),
						partCFrame * Vector3.new(negHalfWidth, negHalfHeight, halfDepth),
						partCFrame * Vector3.new(halfWidth, negHalfHeight, halfDepth),
						partCFrame * Vector3.new(negHalfWidth, halfHeight, halfDepth),
						partCFrame * Vector3.new(halfWidth, halfHeight, halfDepth)
						} do
						local minX = minBounds.X
						local cornerX = cornerPosition.X
						local newMinX = math.min(minX, cornerX)
						local minY = minBounds.Y
						local cornerY = cornerPosition.Y
						local newMinY = math.min(minY, cornerY)
						local minZ = minBounds.Z
						local cornerZ = cornerPosition.Z
						local newMinZ = math.min(minZ, cornerZ)
						minBounds = Vector3.new(newMinX, newMinY, newMinZ)
						local maxX = maxBounds.X
						local cornerX2 = cornerPosition.X
						local newMaxX = math.max(maxX, cornerX2)
						local maxY = maxBounds.Y
						local cornerY2 = cornerPosition.Y
						local newMaxY = math.max(maxY, cornerY2)
						local maxZ = maxBounds.Z
						local cornerZ2 = cornerPosition.Z
						local newMaxZ = math.max(maxZ, cornerZ2)
						maxBounds = Vector3.new(newMaxX, newMaxY, newMaxZ)
					end
				end
			end
			return {
				["Position"] = (minBounds + maxBounds) / 2,
				["Size"] = maxBounds - minBounds
			}
		end
	else
		warn("Expected a Model, got:", model)
	end
end

module.ResizePart = function(part, object, scale)
	local cf, size = object:GetBoundingBox()

	-- Size the part to match bounding box
	part.Size = size * scale
	part.CFrame = cf -- Use the full CFrame to maintain orientation

	-- Find anchor part
	local anchorPart = object.PrimaryPart or object:FindFirstChildWhichIsA("Model").PrimaryPart

	if anchorPart then
		-- Calculate offset from anchor part to bounding box center
		local offset = cf.Position - anchorPart.Position

		-- Create weld
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = anchorPart
		weld.Parent = part

		-- Position part relative to anchor using the offset
		part.CFrame = CFrame.new(cf.Position)
	else
		warn("No anchor part found in model:", object.Name)
	end

	return part
end




return module