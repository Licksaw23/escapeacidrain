local MutationsModule = require(game.ReplicatedStorage.Game.Modules.Libraries.MutationsData)

local hasPreloaded
return function(info)
	--repeat wait() until game:IsLoaded()
	--repeat wait() until game.Players.LocalPlayer:GetAttribute("PlotLoaded")
	local worked,nowrk = pcall(function()
		for index, list in info.Array do
			--game:GetService("ContentProvider"):PreloadAsync(list.Model:GetDescendants())
			MutationsModule[list.Mutation].Apply(list.Model)
		end
	end)
	
	if not worked then
		warn(nowrk)
		print(info.Array)
	end
	
end