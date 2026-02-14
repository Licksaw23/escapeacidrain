--[[ made by Shin#7031
local Strike = require(module.path)

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
