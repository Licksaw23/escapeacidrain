local Calculator = require(game.ReplicatedStorage.Game.Modules.Utilities.Calculator)
local WeightPool = require(game.ReplicatedStorage.Game.Modules.Libraries.BrainrotsData)
local ItemsData = require(game.ReplicatedStorage.Game.Modules.Libraries.ItemsData)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModelsFolder = ReplicatedStorage.Game.Models

return function(info)
	for index, list in info.Array do
		-- Get model name
	

		local modelName = list.Model:GetAttribute("Name") or list.Model:GetAttribute("Product") or list.Model.Name
		local isItem = ItemsData[modelName] ~= nil
		local weightPoolData = WeightPool[modelName] and WeightPool[modelName].WeightPool or ItemsData[modelName] and ItemsData[modelName].WeightPool

		if not weightPoolData then
			warn("No weight pool data for:", modelName)
			return
		end

		local modelFolder = isItem and ModelsFolder.Plants or ModelsFolder.Brainrot3D
		local originalModel = modelFolder:FindFirstChild(modelName)

		if not originalModel then
			warn("Original model not found:", modelName)
			return
		end

		local finalScale = Calculator.CalculateScaleFromWeight(list.Scale, weightPoolData, originalModel)

		if not finalScale then
			warn("Failed to calculate scale for:", modelName)
			return
		end

		list.Model:ScaleTo(finalScale)

		-- Update overhead UI size if it exists
		local primaryPart = list.Model.PrimaryPart
		if primaryPart then
			local attachment = primaryPart:FindFirstChild("Attachment")
			if attachment then
				local overhead = attachment:FindFirstChild("CustomerOverhead")
				if overhead then
					overhead.Size = UDim2.new(10.2, 0, 3.4, 0)
				end
			end
		end
	end
end