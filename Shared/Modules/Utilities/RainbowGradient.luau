local module = {}

local CollectionService = game:GetService("CollectionService")

function module:Init()
	local t = 4
	local range = 10

	task.spawn(function()
		while task.wait() do
			local loop = tick() % t / t
			local colors = {}

			for i = 1, range + 1, 1 do
				local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)

				if loop - ((i - 1) / range) < 0 then
					z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
				end

				local d = ColorSequenceKeypoint.new((i - 1) / range, z)
				table.insert(colors, d)
			end

			local newColor = ColorSequence.new(colors)
			for i, grad in (CollectionService:GetTagged("RainbowGradient")) do
				grad.Color = newColor
			end
		end
	end)
end

return module
