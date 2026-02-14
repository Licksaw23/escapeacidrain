-- Player --

local Player = game.Players.LocalPlayer
local PlayerScripts = Player.PlayerScripts	
local PlayerGui = Player.PlayerGui

-- UI --

local UI = PlayerGui.MainUI

-- Services --

local ReplicatedService = game:GetService('ReplicatedStorage')

-- Folders --

-- Modules --

local Calculator = require(ReplicatedService.Game.Modules.Utilities.Calculator)
local HUD = require(PlayerScripts.Framework.UI.HUD)

local PlayerReplica = require(ReplicatedService:WaitForChild("PlayerData")):GetData()
local PlayerData = PlayerReplica.Data

local ItemsData = require(ReplicatedService.Game.Modules.Libraries.ItemsData)
local BrainrotsData = require(ReplicatedService.Game.Modules.Libraries.BrainrotsData)

-- Remotes --

local UIRemote = ReplicatedService.Remotes.UI

-- Objects --

local Dialogue_Table = {
	['Merchant'] = {
		['Title'] = 'Merchant';

		[1] = {
			Text = 'Hey there.. What you looking for?';

			Responses = {
				["I want to sell the item I'm holding."] = "SellCurrentItem";
				["How much is this item worth?"] = "EvaluateItem";
				["I want to sell all my fruits."] = "SellFruits";
				["I want to sell all my brainrots."] = "SellRots";
			};

			ResponseFunctions = {
				["EvaluateItem"] = function()
					local dialogue = require(PlayerScripts.Framework.Handlers.DialogueController)
					
					local getItem
					
					for _, tool in Player.Character:GetChildren() do
						if tool:IsA("Tool") then
							getItem = tool
						end
					end
					
					if not getItem then
						dialogue:Talk({
							["NPC"] = "Merchant";
							["Text"] = "Please hold an item out for me to evaluate.";
							["Duration"] = 3;
						})
						
						return
					end
					
					local getData = PlayerData.Inventory[getItem:GetAttribute("ID")]
					local libraryData = ItemsData[getData.Name]
					
					if not getData.Mutations or not getData.Weight then
						dialogue:Talk({
							["NPC"] = "Merchant";
							["Text"] = "I can't evaluate the price of this item..";
							["Duration"] = 3;
						})
						
						return
					end
					
					if not libraryData.SellPrice then libraryData = BrainrotsData[getData.Name] end
					
					local itemWorth = Calculator.CalculateWorth(libraryData.SellPrice or (libraryData.MoneyPerSecond and libraryData.MoneyPerSecond * 60), getData.Weight, getData.Mutations)
					
					dialogue:Talk({
						["NPC"] = "Merchant";
						["Text"] = "This item is worth $"..itemWorth.."!";
						["Duration"] = 3;
					})
				end,
				
				["SellCurrentItem"] = function()
					local dialogue = require(PlayerScripts.Framework.Handlers.DialogueController)

					local getItem

					for _, tool in Player.Character:GetChildren() do
						if tool:IsA("Tool") then
							getItem = tool
						end
					end

					if not getItem then
						dialogue:Talk({
							["NPC"] = "Merchant";
							["Text"] = "Please hold an item out for me to buy from you.";
							["Duration"] = 3;
						})

						return
					end
						
						
						
					UIRemote:FireServer("SellCurrentItem")
				end,
				
				["SellFruits"] = function()
					UIRemote:FireServer("SellFruits")
				end,
				
				["SellRots"] = function()
					UIRemote:FireServer("SellRots")
				end,
			};
		};
	};
	
	['Seed Merchant'] = {
		['Title'] = 'Merchant';

		[1] = {
			Text = 'Wanna see what we got?';

			Responses = {
				["Nevermind."] = "Decline";
				["Open Store"] = "OpenStore";
			};

			ResponseFunctions = {
				
				
				
				["OpenStore"] = function()
					
					
					local dialogue = require(PlayerScripts.Framework.Handlers.DialogueController)
					dialogue:Talk({
						["NPC"] = "Seed Merchant";
						["Text"] = "Here's what I have in stock";
						["Duration"] = 3;
					})
					
					wait(0.3)
					
					HUD.OpenFrame(UI.SeedShop)
				end,
			};
		};
	};
	
	
	['Gear Merchant'] = {
		['Title'] = 'Merchant';

		[1] = {
			Text = 'Wanna see what we got?';

			Responses = {
				["Nevermind."] = "Decline";
				["Open Store"] = "OpenStore";
			};

			ResponseFunctions = {
				["OpenStore"] = function()
					HUD.OpenFrame(UI.SeedShop)
				end,
			};
		};
	};
}

return Dialogue_Table