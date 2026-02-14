local Calculator = require(game.ReplicatedStorage.Game.Modules.Utilities.Calculator)
local Lightning = require(game.ReplicatedStorage.Game.Modules.Utilities.ShinsLightning)

local function createP(pos)
	local newP = Instance.new("Part", workspace.Visuals)
	newP.Anchored = true
	newP.CanCollide = false
	newP.Transparency = 1
	newP.CFrame = pos
	return newP
end

return function(info)
	if info.Event == "Strike" then
		local initial = CFrame.new(info.CFrame.X, info.CFrame.Y, info.CFrame.Z)
		local top = createP(initial * CFrame.new(0, 1000, 0))
		local bottom = createP(initial)
		
		Lightning.new(
			"cylinder",				--Block Usage (can be set to cylinder or cube/box shape)
			ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 251, 255)),
			},					--BlockColor (lighting color)
			0,					--ColorOffset Howfast u want the color to travel through the lightning
			false,				--ColorJuggle turn on if u want to juggle the colors of the color squence
			top,		--Start Point
			bottom,	--End Point
			true,				--Focused or Spread (will spread to the part depending on what u set it to)
			math.random(1,2),	--Size (lightning size)
			150,					--Main Segments (basically how many segments u want the lighting to have going above 600 can lag the game)
			2,					--OffSet (set to higher number to make more zigzag effect)
			nil,				--Fade effect (set to nil if u want the lightning to strike imidielty)
			1.5,					--Aniamtion Speed (basically how long it would take for the lightning to disapear)
			0,				--FadeMovement (set to 0 to make it fade to the middle the higher it is the more it fade's to the side)
			100					--Sparks set to nil to disable		
		)
	end
end