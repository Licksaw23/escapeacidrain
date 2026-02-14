local module = {}
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local colors = {}
module.Gradient = script.UIGradient
for i=1, #script.UIGradient.Color.Keypoints do
	colors[i] = script.UIGradient.Color.Keypoints[i].Value
end

function module:Init()
	RunService.RenderStepped:Connect(function()
		local num_colors = #colors
		local color_length = 1 / num_colors
		local period = 6
		local progress = (tick() % period) / period 
		local newColors = {}
		local wrapColor = false

		for i = 1, num_colors + 1 do 
			local color = colors[i] or colors[i-num_colors]
			local position = progress + (i-1)/num_colors 

			if position > 1 then position = position - 1 end 
			if position == 0 or position == 1 then wrapColor = true end 

			table.insert(newColors, ColorSequenceKeypoint.new(position, color))
		end

		if not wrapColor then 
			local indexProgress = ((1 - progress) / color_length) + 1
			local col1 = colors[math.floor(indexProgress)]
			local col2 = colors[math.ceil(indexProgress)] or colors[1]
			local finalCol = col1:Lerp(col2, indexProgress % 1) 

			table.insert(newColors, ColorSequenceKeypoint.new(0, finalCol))
			table.insert(newColors, ColorSequenceKeypoint.new(1, finalCol))
		end

		table.sort(newColors, function(a, b)
			return a.Time < b.Time
		end)
		newColors[1]= ColorSequenceKeypoint.new(0, newColors[1].Value) 
		newColors[#newColors]= ColorSequenceKeypoint.new(1, newColors[#newColors].Value) 
		
		for _, gradient in CollectionService:GetTagged(script.Name) do
			gradient.Color = ColorSequence.new(newColors)
		end
	end)
end

return module
