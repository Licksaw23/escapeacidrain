local ModulesHolder = script.Parent

local Registry = require(script.Parent.Registry)

local MarketplaceService = game:GetService("MarketplaceService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

require(script.Parent.UIStrokeAdjuster)


-- Load data. --
Registry.Register(game.ReplicatedStorage:WaitForChild("PlayerData")):Init()
Registry.Register(ModulesHolder.Handlers.CustomPrompt).Init()

-- Load hotbar. --
local Satchel = require(game:GetService("ReplicatedStorage"):WaitForChild("Game").Modules.Utilities.Satchel)

for _, Folder in ModulesHolder:GetChildren() do
	if Folder:IsA("Folder") then
		for _, module in Folder:GetChildren() do
			if module:IsA("ModuleScript") then
				Registry.Register(module)
			end
		end
	end
end


-- Delete unnecessaries in other plots --

for _, otherPlot in workspace.Plots:GetChildren() do
	if tonumber(otherPlot.Name) ~= game.Players.LocalPlayer:GetAttribute("Plot") then
		for _, otherDeletes in otherPlot.OtherDeletes:GetChildren() do
			otherDeletes:Destroy()
		end
		
		for _, deletable in otherPlot.NPC:GetChildren() do
			deletable:Destroy()
		end
		
		otherPlot.Leaderboard:Destroy()
	end
end

local Tags = {
	-- Example tags with colors
	["VIP"] = {
		TagText = "[VIP]",
		TagColor = Color3.fromRGB(255, 215, 0) -- Gold
	},
	["iamroads"] = {
		TagText = "[OWNER]",
		TagColor = Color3.fromRGB(255, 0, 0) -- Red
	},
	["Moderator456"] = {
		TagText = "[MOD]",
		TagColor = Color3.fromRGB(0, 170, 255) -- Blue
	}
}

local generalChannel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")

generalChannel.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")

	-- Get the player who sent the message
	local player = Players:GetPlayerByUserId(message.TextSource.UserId)
	if not player then
		return properties
	end

	-- Check if player has a tag by username
	local tag = Tags[player.Name]

	-- If no username tag, check group rank
	if not tag then
		if MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1666032504) then
			tag = Tags.VIP
		end
	end

	-- Apply the tag if one exists
	if tag then
		-- Create the colored tag
		local tagText = string.format(
			'<font color="rgb(%d,%d,%d)">%s</font> ',
			tag.TagColor.R * 255,
			tag.TagColor.G * 255,
			tag.TagColor.B * 255,
			tag.TagText
		)

		-- Prepend the tag to the message
		properties.PrefixText = tagText .. message.PrefixText
	end

	return properties
end