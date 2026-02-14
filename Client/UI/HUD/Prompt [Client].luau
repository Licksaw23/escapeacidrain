local ViewportModelCFrame = CFrame.new(0, -4, -9) * CFrame.Angles(math.rad(8), math.rad(-13), math.rad(0))
-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local CurrentCamera = workspace.CurrentCamera
-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
-- folders --
local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local Utilities = Modules.Utilities
local Remotes = RS.Remotes
-- modules --
local NewTS = require(Utilities.Tweener)
-- remotes --
local UIRemote = Remotes.UI
local PlotRemote = Remotes.Plot -- Add this for plant removal
-- ui --
local MainUI = PlayerGui:WaitForChild("MainUI")
local PromptTemplate = GameFolder.UI.Prompt


-- // Code \\ --
local module = {}
module.ActiveConnections = {}
module.Prompts = {
	["PlatformPrompt"] = {
		["Accept"] = function(sentData)
			UIRemote:FireServer("UnlockPlatform", sentData.Platform)
		end,
	};

	["GiftPrompt"] = {
		["Accept"] = function(sentData)
			UIRemote:FireServer("SendBrainrotGift", {
				["ID"] = sentData.BrainrotID;
				["PlayerToSend"] = sentData.PlayerToSend
			})
		end,
	};

	["AcceptGiftPrompt"] = {
		["Accept"] = function(sentData)
			UIRemote:FireServer("AcceptBrainrotGift", {
				["ID"] = sentData.BrainrotID;
				["PlayerWhoSent"] = sentData.PlayerSent;
			})
		end,
	};

	-- NEW: Plant Removal Prompt
	["PlantRemovalPrompt"] = {
		["Accept"] = function(sentData)
			PlotRemote:FireServer("RemovePlant", sentData.PlantID)
		end,
	};
}

function module.CreatePrompt(text, promptType, extra, opener, closer)
	if promptType == "AcceptGiftPrompt" then
		if Player:GetAttribute("GiftNotifications") == false then return end 
	end

	local NewPrompt = PromptTemplate:Clone()
	NewPrompt.Parent = MainUI

	NewPrompt.PromptText.Text = text

	--NewTS:TweenBounce(NewPrompt.UIScale, {
	--	Scale = 1;
	--})

	opener(NewPrompt)

	local function close()
		if not NewPrompt.Parent then return end -- Prevent double-close

		NewPrompt:Destroy()

		for _, c in module.ActiveConnections do
			c:Disconnect()
		end

		module.ActiveConnections = {}
		closer(NewPrompt)
	end

	local inCache = module.Prompts[promptType]

	module.ActiveConnections["Accept"] = NewPrompt.Accept.Button.MouseButton1Click:Connect(function()
		inCache.Accept(extra)
		close()
	end)

	module.ActiveConnections["Decline"] = NewPrompt.Decline.Button.MouseButton1Click:Connect(close)
	module.ActiveConnections["Deleted"] = NewPrompt.AncestryChanged:Connect(function()
		close()
	end)

	-- Return the close function so it can be called externally
	return close
end

return module