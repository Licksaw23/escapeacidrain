local mUtil = require(script.Parent.MutationsData.MutationUtil)

return {
	["Chilled"] = {
		Multiplier = 1.3;
		Gradient = script.Diamond;
		Chance = 10;
		
		Apply = function(model)
			mUtil.Tint(model,Color3.fromRGB(99, 250, 224))
		end,
	};
}