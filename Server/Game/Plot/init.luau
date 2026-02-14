local PlayersService = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Data = require(Replicated:WaitForChild("ServerPlayerData"))
local Remotes = Replicated:WaitForChild("Remotes")
local Models = Replicated.Game.Models.Brainrot3D
local UI = Replicated.Game.UI
local PlantModels = Replicated.Game.Models.Plants
local Tools = Replicated.Game.Models.Tools
local PlantScripts = Replicated.Game.Modules.Utilities.GrowPlant

local ServerUtility = require(script.Parent.ServerUtility)
local BezierPath = require(Replicated.Game.Modules.Utilities.BezierPath)
-- CRITICAL FIX: Removed duplicate Data require (Issue #1)
local BrainrotData = require(Replicated.Game.Modules.Libraries.BrainrotsData)
local SprinklerSystem = require(script.SprinklerSystem)
local CodesData = require(Replicated.Game.Modules.Libraries.CodesData)
local ItemsData = require(Replicated.Game.Modules.Libraries.ItemsData)
local GearsData = require(Replicated.Game.Modules.Libraries.GearsData)
local Zone = require(Replicated.Game.Modules.Utilities.Zone)
local MutationsData = require(Replicated.Game.Modules.Libraries.MutationsData)
local mutationUTIL = require(Replicated.Game.Modules.Libraries.MutationsData.MutationUtil)
local Calculator = require(Replicated.Game.Modules.Utilities.Calculator)
local NumberShortener = require(Replicated.Game.Modules.Utilities.NumberShortener)
local BitBuffer = require(Replicated.Game.Modules.Utilities.BitBuffer)
local Mutations = require(Replicated.Game.Modules.Libraries.MutationsData)
local LerPmover = require(Replicated.Game.Modules.Utilities.LerpMover)
local PickMutations = require(Replicated.Game.Modules.Utilities.PickMutations)
local EventsLibrary = require(Replicated.Game.Modules.Libraries.EventsData)
local PickScale = require(Replicated.Game.Modules.Utilities.PickScale)
local Leaderboards = require(script.Parent.Leaderboards)
local RebirthsData = require(Replicated.Game.Modules.Libraries.RebirthsData)
local GlobalStore = require(script.Parent.GlobalStore)

local Gradients = Replicated.Game.UI.Gradients
local MutationTemplate = UI.MutationListTemplate

local PlotRemote = Remotes.Plot
local OrderRemote = Remotes.Order
local CodesRemote = Remotes.Code
local SpawnRemote = Remotes.Spawn
local SettingRemote = Remotes.Setting
local UpdateRemote = Remotes.Update
local UIRemote = Remotes.UI
local StockRemote = Remotes.UpdateSeedStore
local FXRemote = Remotes.FX

local plot = {}
plot.__index = plot
plot.Plots = {}

local PlotsFolder = workspace.Plots

local TotalBrainrots = 0
for _, v in BrainrotData do TotalBrainrots += 1 end 

-- Auto Complete Order Products --

plot.AutoCompletes = {
	["Rare"] = 3506035960;
	["Epic"] = 3506036121;
	["Legendary"] = 3506036292;
	["Mythic"] = 3506053155;
	["Godly"] = 3506036460;
	["Secret"] = 3506036689;
}

-- Plant Module Cache (for GrowthTime lookup) --
local PlantModules = {}
for itemName, itemTable in ItemsData do
	if itemTable.Type == "Plant" then
		local success, module = pcall(function()
			return require(script.Plants[itemName])
		end)
		if success and module then
			PlantModules[itemName] = module
		end
	end
end

-- Leave & Join stuff --


function plot.new(Player) -- assigns a vacant plot to new player --
	local newPlot = {}
	setmetatable(newPlot, plot)

	for i = 1, #PlotsFolder:GetChildren() do
		if PlotsFolder[i]:GetAttribute("Vacant") then
			Player:SetAttribute("Plot", i)
			PlotsFolder[i]:SetAttribute("Vacant", nil)

			-- Teleport player into plot. --
			repeat wait() until Player.Character or Player.CharacterAdded:Wait()
			Player.Character.PrimaryPart:PivotTo(PlotsFolder[i].Spawn.CFrame)
			Player:SetAttribute("CPS",0)
			repeat wait() until Data[Player]
			local PlayerReplica = Data[Player]
			repeat wait() until PlayerReplica.Data

			newPlot.Owner = Player
			newPlot.Owner:SetAttribute("Rebirths",PlayerReplica.Data.Rebirths)
			newPlot.OwnerReplica = PlayerReplica
			newPlot.OwnerData = PlayerReplica.Data
			newPlot.PlotNumber = i

			newPlot.Folder = PlotsFolder[i]

			newPlot.Active = {}
			newPlot.Objects = {}
			newPlot.Brainrots = {}
			newPlot.Connections = {}
			newPlot.Functions = {}
			newPlot.Orders = {}
			newPlot.Lines = {[1]={}; [2] = {}; [3] = {};}
			newPlot.CashPerSecondTable = {}
			newPlot.CurrentCustomer = {[1] = nil; [2] = nil; [3] = nil}
			newPlot.CurrentOrder = {[1] = nil; [2] = nil; [3] = nil}

			newPlot.Tick = 0 -- seconds passed. resets at 45 to spawn brainrot --
			newPlot.GlobalTick = 0 -- seconds passed. use to spawn guaranteed mythic, etc. --

			PlotRemote:FireClient(Player, "PlotLoaded", i)

			newPlot.Functions["Rebirth2"] = function()
				newPlot.Folder.Purchases["Lane2"]:Destroy()

				local savedEntrancePos = newPlot.Folder.Special.RebirthEntrance:GetPivot()
				newPlot.Folder.Special.RebirthEntrance:Destroy()
				local newEntrance = Replicated.Game.Models.Expansions["Rebirth2"]:Clone()
				newEntrance.Parent = newPlot.Folder.Special
				newEntrance.Name = "RebirthEntrance"
				newEntrance:PivotTo(savedEntrancePos)
			end

			newPlot.Functions["Rebirth3"] = function()
				newPlot.Folder.Purchases["Lane3"]:Destroy()

				local savedEntrancePos = newPlot.Folder.Special.RebirthEntrance:GetPivot()
				newPlot.Folder.Special.RebirthEntrance:Destroy()
				local newEntrance = Replicated.Game.Models.Expansions["Rebirth3"]:Clone()
				newEntrance.Parent = newPlot.Folder.Special
				newEntrance.Name = "RebirthEntrance"
				newEntrance:PivotTo(savedEntrancePos)
			end

			newPlot.Functions["Rebirth4"] = function()
				local savedEntrancePos = newPlot.Folder.Special.RebirthEntrance:GetPivot()
				newPlot.Folder.Special.RebirthEntrance:Destroy()
				local newEntrance = Replicated.Game.Models.Expansions["Rebirth4"]:Clone()
				newEntrance.Parent = newPlot.Folder.Special
				newEntrance.Name = "RebirthEntrance"
				newEntrance:PivotTo(savedEntrancePos)

				local newBackExtension = Replicated.Game.Models.Expansions["BackExtension"]:Clone()
				newBackExtension.Parent = newPlot.Folder.Special
				newBackExtension.Name = "BackExtension"
			end

			for i = 1, newPlot.OwnerData.Rebirths do
				if newPlot.Functions["Rebirth"..i] then
					newPlot.Functions["Rebirth"..i]()
				end
			end

			-- Check if index completed to update luck boosts. --
			newPlot.BoostsGiven = {}

			newPlot.Functions["IndexBoost"] = function()
				local totalLuckBoost = 0; local totalCashBoost = 0

				for MutationName, MutationInfo in MutationsData do
					if newPlot.BoostsGiven[MutationName] then continue end

					local TypeDiscovered = 0

					for unlock, unlockData in newPlot.OwnerData.Unlocks do
						if BrainrotData[unlock] and unlockData[MutationName] then
							TypeDiscovered += 1
						end
					end

					if TypeDiscovered == TotalBrainrots then
						newPlot.BoostsGiven[MutationName] = true
						totalCashBoost += 10; totalLuckBoost += 10
					end
				end

				if totalLuckBoost > 0 and totalCashBoost > 0 then
					newPlot:GiveTotalLuck(totalLuckBoost)
					newPlot:GiveCashMultiplier(totalCashBoost)
				else
				
				end
			end

			newPlot.Functions["IndexBoost"]()

			pcall(function()
				local Header = PlayersService:GetUserThumbnailAsync(Player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size420x420)
				local Headshot = PlotsFolder[i]:FindFirstChild("Headshot")

				Headshot.BillboardGui.ImageLabel.Image = Header
				Headshot.BillboardGui.Header.Text = Player.Name
			end)

			newPlot.Connections[1] = PlayersService.PlayerRemoving:Connect(function(user)
				if user == Player then
					newPlot:Terminate()
				end
			end) 

			newPlot.Connections[2] = OrderRemote.OnServerEvent:Connect(function(user, call, ...)
				if user ~= newPlot.Owner then return end
				
				if call == "GiveFruit" then
					local path, itemID = ...
					
					-- CRITICAL FIX: Added comprehensive validation (Issue #2)
					-- Validate path is a number between 1-3
					if type(path) ~= "number" and type(path) ~= "string" then
						warn("[OrderRemote] Invalid path type: " .. type(path))
						return
					end
					
					local pathNum = tonumber(path)
					if not pathNum or pathNum < 1 or pathNum > 3 then
						warn("[OrderRemote] Invalid path number: " .. tostring(path))
						return
					end
					
					-- Validate itemID is a string and exists in inventory
					if type(itemID) ~= "string" then
						warn("[OrderRemote] Invalid itemID type: " .. type(itemID))
						return
					end
					
					-- Check item exists in player's inventory
					if not newPlot.OwnerData.Inventory[itemID] then
						warn("[OrderRemote] Item not in inventory: " .. itemID)
						return
					end
					
					-- Get the current order at this desk
					local currentOrder = newPlot.CurrentOrder[pathNum]
					if not currentOrder or not currentOrder.BrainrotID then 
						warn("[OrderRemote] No active order at path: " .. tostring(pathNum))
						return 
					end
					
					-- Validate the brainrot is still active
					if not newPlot.Active[currentOrder.BrainrotID] then
						warn("[OrderRemote] Brainrot no longer active: " .. currentOrder.BrainrotID)
						return
					end
					
					local brainrotID = currentOrder.BrainrotID
					
					-- Call the function to give fruit
					if newPlot.Functions[brainrotID] then
						newPlot.Functions[brainrotID](user, itemID)
					end
				elseif type(call) == "number" then
					-- Legacy orderID handling
					local orderID = call
					if newPlot.Orders[orderID] then
						-- check if they have all the stuff, if they do then fulfill order --
						local PlayerReplica = Data[newPlot.Owner]
						local Data = PlayerReplica.Data

						-- everything they need --
						local OrderCache = newPlot.Orders[orderID]
						local OrderRequirements = OrderCache.Requirement
						local OrderDifficulty = OrderCache.Difficulty or 1

						-- check for all --
						local HasEverything = false
						local DoesntHave = ""

						for ingredientName, ingredientAmount in OrderRequirements do
							for itemID, itemTable in Data.Inventory do
								if itemTable.Name == ingredientName then
									if itemTable.Quantity >= ingredientAmount then
										HasEverything = true
									else
										HasEverything = false
									end
								end
							end
						end

						if HasEverything then
							-- Remove all ingredients from inventory. --
							-- Give rewards (brainrot, money, +1 order) --
							-- Play VFX --
						else
							-- Notify them what they are missing --
							-- Brainrot gets mad and leaves --
						end
					end
				end
			end)

			newPlot.Functions["CompleteOrder"] = function(number, passChecks)
				local getCurrentOrder = newPlot.CurrentOrder[number]
				
				-- CRITICAL FIX: Check nil BEFORE accessing .Cache (Issue #5)
				if not getCurrentOrder or getCurrentOrder.Claiming then
					return
				end
				
				local orderCache = getCurrentOrder.Cache
				getCurrentOrder.Claiming = true
					
				local TotalInventorySize = 250
				if MarketplaceService:UserOwnsGamePassAsync(newPlot.Owner.UserId, 1657482065) then TotalInventorySize = 400 end

				local GetInventoryCount = 0
				for i, v in PlayerReplica.Data.Inventory do GetInventoryCount += 1 end

				if GetInventoryCount >= TotalInventorySize then
					UIRemote:FireClient(newPlot.Owner, "TopNotification", {
						Text = "Your inventory is full! ("..GetInventoryCount.."/"..TotalInventorySize..")";
						Duration = 3;
						["ShadowColor"] = Color3.fromRGB(241, 0, 0);
						["ShadowTransparency"] = 0.35;
					})

					return
				end

				-- update leaderboard & stats --
				local currentOrders = PlayerReplica.Data.Stats.Orders
				PlayerReplica:SetValue({"Stats", "Orders"}, currentOrders + 1)
				Leaderboards.UpdatePlayerStat(newPlot.Owner.UserId, "Orders", currentOrders + 1)

				-- cancels and stuff --
				if orderCache.Delay then task.cancel(orderCache.Delay) end

				-- give brainrot --
				
				print(getCurrentOrder)
				newPlot:GiveItem({
					["ID"] = HttpService:GenerateGUID(false);
					["Name"] = getCurrentOrder.Brainrot;
					["Weight"] = getCurrentOrder.Weight;
					["Mutations"] = getCurrentOrder.Mutations or {};
				})

				-- destroy customer (only if still active)
				if newPlot.Active[getCurrentOrder.BrainrotID] then
					newPlot:DestroyBrainrot(getCurrentOrder.BrainrotID, number, getCurrentOrder.Index,passChecks)
				end
			end

			local function setupForDesk(number)
				-- Use ProximityPrompt for mobile compatibility
				local acceptPrompt = newPlot.Folder.Desks["Desk"..number].Accept.Button:FindFirstChild("ProximityPrompt")
				if not acceptPrompt then
					acceptPrompt = newPlot.Folder.Desks["Desk"..number].Accept.Button:FindFirstChild("ClickDetector")
				end

				if acceptPrompt then
					local eventName = acceptPrompt:IsA("ProximityPrompt") and "Triggered" or "MouseClick"
					newPlot.Connections["claimRot"..number] = acceptPrompt[eventName]:Connect(function(user)
						if newPlot.CurrentCustomer[number] ~= nil then
							if user == newPlot.Owner then
								local getCurrentOrder = newPlot.CurrentOrder[number]
								if getCurrentOrder and getCurrentOrder.Cache then
									local orderCache = getCurrentOrder.Cache

									local reqs = orderCache.Requirements
									local currents = orderCache.Currents

									local passChecks = true

									for fruit, count in reqs do
										if not next(currents[fruit] or {}) or currents[fruit] == nil then
											passChecks = false
											continue
										end

										if #currents[fruit] < count then
											passChecks = false
										end
									end

									if not passChecks then
										FXRemote:FireAllClients("Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.error,['norandom'] = true})

										UIRemote:FireClient(newPlot.Owner, "TopNotification", {
											["Text"] = "You have not finished this order!";
											["Duration"] = 5;
											["TextColor"] = Color3.fromRGB(255, 255, 255);
											["ShadowColor"] = Color3.fromRGB(255, 0, 0);
											["ShadowTransparency"] = 0.35;
										})

										local BrainrotModel = Models:FindFirstChild(getCurrentOrder.Brainrot)
										local BrainrotRarity = BrainrotModel:GetAttribute("Rarity")

										if plot.AutoCompletes[BrainrotRarity] then
											MarketplaceService:PromptProductPurchase(newPlot.Owner, plot.AutoCompletes[BrainrotRarity])
											Player:SetAttribute("CompletedPurchaseData", number)
										end

										return
									end

									if passChecks then
										newPlot.Functions["CompleteOrder"](number, passChecks)
									end
								end
							end
						end
					end)
				end

				-- Use ProximityPrompt for mobile compatibility
				local declinePrompt = newPlot.Folder.Desks["Desk"..number].Decline.Button:FindFirstChild("ProximityPrompt")
				if not declinePrompt then
					declinePrompt = newPlot.Folder.Desks["Desk"..number].Decline.Button:FindFirstChild("ClickDetector")
				end

				if declinePrompt then
					local eventName = declinePrompt:IsA("ProximityPrompt") and "Triggered" or "MouseClick"
					newPlot.Connections["denyRot"..number] = declinePrompt[eventName]:Connect(function(user)
						if user == newPlot.Owner then
							if not newPlot.CurrentCustomer[number] or not newPlot.CurrentCustomer[number].ID then
								return -- No customer at desk yet
							end

							local brainrotID = newPlot.CurrentCustomer[number].ID

							-- check if order exists (means they're done thinking and have placed order)
							--if not newPlot.Orders[brainrotID] then
							--	return 
							--end

							newPlot:DestroyBrainrot(brainrotID, newPlot.CurrentCustomer[number].Path, newPlot.CurrentCustomer[number].Index)
						end 
					end)
				end
			end

			setupForDesk(1); setupForDesk(2); setupForDesk(3)

			-- Load tools. --
			for itemID, itemTable in newPlot.OwnerData.Inventory do
				if Tools:FindFirstChild(itemTable.Name) then
					newPlot:GiveToolForItem(itemID)
				end
			end

			-- [SAB] Load Brainrots into plot.
			for BrainrotID, BrainrotCache in newPlot.OwnerData.Brainrots do
				newPlot:PlaceBrainrot(BrainrotID, BrainrotCache.Position, nil)
			end
			
			

			-- [SAB] Setup platform / button function.
			local function SetupPlatform(Platform)
				
				if Platform.Name == "Super" then
					if newPlot.OwnerData.Rebirths >= 3 then
						warn(' im giving you DIAMOND PLATFORM!!!')

						local baseColor = Color3.fromRGB(142, 200, 255)
						mutationUTIL.Tint(Platform,baseColor)
						
						local SurfaceGUI = Platform.Billboard.SurfaceGui
						local Title,Multi = SurfaceGUI.Title,SurfaceGUI.Multi
						Title.Text = "DIAMOND PAD"
						Title.TextColor3 = Color3.new(0, 123, 255)
						Multi.Text = "(2X MULTIPLIER)"
						
						

						for _, Particle in Platform:GetDescendants() do
							if Particle:IsA("ParticleEmitter") or Particle:IsA("Beam") or Particle:IsA("Trail") then
								if Particle.Color then
									-- Get the original color sequence
									local originalSeq = Particle.Color
									local newKeypoints = {}

									-- Loop through each keypoint and adjust the color while keeping brightness
									for i, keypoint in ipairs(originalSeq.Keypoints) do
										local originalColor = keypoint.Value
										local h, s, v = originalColor:ToHSV()
										local newH, newS, newV = baseColor:ToHSV()

										-- Keep original brightness (v) but use new hue and saturation
										local adjustedColor = Color3.fromHSV(newH, newS, v)
										table.insert(newKeypoints, ColorSequenceKeypoint.new(keypoint.Time, adjustedColor))
									end

									Particle.Color = ColorSequence.new(newKeypoints)
								end
							end
						end
					end
				end
				
				local newProximityPrompt = Instance.new("ProximityPrompt", Platform.Place)
				newProximityPrompt.Name = "PROMPT"..Platform.Name..newPlot.PlotNumber
				newProximityPrompt.ActionText = "Place Brainrot"
				newProximityPrompt:SetAttribute("PromptText", "Place")
				newProximityPrompt:SetAttribute("BoldText", "Brainrot")
				newProximityPrompt:SetAttribute("Offset", Vector3.new(0,5,0))
				newProximityPrompt.RequiresLineOfSight = false

				if Platform:GetAttribute("Occupied") then
					newProximityPrompt.Enabled = false
				end

				newPlot.Functions[newProximityPrompt.Name] = function(playerWhoTriggered)
					if playerWhoTriggered == newPlot.Owner then
						-- get brainrot their holding (cancel if not holding)
						if not newPlot.Owner:GetAttribute("BrainrotOut") then return end
						local RotID = newPlot.Owner:GetAttribute("Holding")

						-- place brainrot
						local findTool
						for _, child in newPlot.Owner.Character:GetChildren() do
							if child:IsA("Tool") and child:GetAttribute("ID") == RotID then
								findTool = child
							end
						end

						-- disable this prompt
						--newProximityPrompt.Enabled = false

						-- activate & place new prompt
						newPlot:PlaceBrainrot(RotID, Platform.Name, findTool, newProximityPrompt)
					end
				end

				newPlot.Connections["PlatformPlace"..Platform.Name] = newProximityPrompt.Triggered:Connect(function(playerWhoTriggered)
					newPlot.Functions[newProximityPrompt.Name](playerWhoTriggered)
				end)
			end

			local function SetupButton(Button)
				local newProximityPrompt = Instance.new("ProximityPrompt", Button.Green)
				newProximityPrompt.Name = "BUYPROMPT"..Button.Name..newPlot.PlotNumber
				newProximityPrompt.ActionText = "Buy Platform"
				newProximityPrompt.RequiresLineOfSight = false
				newProximityPrompt:SetAttribute("Offset", Vector3.new(0,5,0))
				newProximityPrompt:SetAttribute("PromptText", "Buy")
				newProximityPrompt:SetAttribute("BoldText", "Platform")

				newPlot.Functions[newProximityPrompt.Name] = function(playerWhoTriggered)
					if playerWhoTriggered == newPlot.Owner then
						UIRemote:FireClient(playerWhoTriggered, "Prompt", {
							["Type"] = "PlatformPrompt";
							["Platform"] = string.split(Button.Name,"Button")[1];
							["Text"] = "Are you sure you want to buy this platform for $"..NumberShortener.roundNumber(Button:GetAttribute("Price")).."?"
						})
					end
				end

				newPlot.Connections["BuyPlatform"..Button.Name] = newProximityPrompt.Triggered:Connect(function(playerWhoTriggered)
					newPlot.Functions[newProximityPrompt.Name](playerWhoTriggered)
				end)
			end

			-- [SAB] Helper function to get next platform number to unlock
			local function GetNextLockedPlatform()
				-- Find highest unlocked platform number
				local highestUnlocked = 2 -- Start with platform 2 (since 1 and 2 are default)
				for platformKey, _ in pairs(newPlot.OwnerData.Unlocks) do
					local platformNum = tonumber(platformKey:match("(%d+)Platform"))
					if platformNum and platformNum > highestUnlocked then
						highestUnlocked = platformNum
					end
				end
				return tostring(highestUnlocked + 1)
			end

			-- [SAB] Load if it should be a purchase button, or a platform prompt.
			local defaultUnlocks = {["1"] = true; ["2"] = true; ["Super"] = true}

			for _, Platform in newPlot.Folder.Platforms:GetChildren() do
				if Platform:GetAttribute("Button") == nil then
					-- Check if they own this platform (or if its unlocked by default.)
					local OwnsPlatform = false
					if defaultUnlocks[Platform.Name] then
						OwnsPlatform = true
					end
					if newPlot.OwnerData.Unlocks[Platform.Name.."Platform"] then
						OwnsPlatform = true
					end

					if not OwnsPlatform then
						-- move platform to storage. keep button.
						Platform.Parent = Replicated.PlotStorage[i]
						local Button = newPlot.Folder.Platforms:FindFirstChild(Platform.Name.."Button")

						if Button then
							local nextPlatform = GetNextLockedPlatform()

							if Platform.Name == nextPlatform then
								SetupButton(Button)
							else
								Button.Parent = Replicated.PlotStorage[i]
							end

							if Button:GetAttribute("Rebirth") and Button:GetAttribute("Rebirth") > newPlot.OwnerData.Rebirths then
								Button.Parent = Replicated.PlotStorage[i]
							end
						end
					else
						-- delete button.
						local getButton = newPlot.Folder.Platforms:FindFirstChild(i.."Button")
						if getButton then
							getButton:Destroy()
						end
					end
				end
			end

			-- [SAB] Load Platform Prompts
			for _, Platform in newPlot.Folder.Platforms:GetChildren() do
				if Platform:GetAttribute("Button") == nil then
					SetupPlatform(Platform)
				end
			end
			
			function newPlot:RevealNextPlatform()
				local nextPlatform = GetNextLockedPlatform()
				if nextPlatform then
					local nextButton = Replicated.PlotStorage[i]:FindFirstChild(nextPlatform.."Button")
					if nextButton then
						nextButton.Parent = self.Folder.Platforms
						SetupButton(nextButton)
					end
				end
			end


			-- UI Remote Stuff --
			newPlot.Connections[3] = UIRemote.OnServerEvent:Connect(function(user, call, data)
				if newPlot.Owner == user then
					if call == "UnlockPlatform" then
						local findPlatform = Replicated.PlotStorage[i]:FindFirstChild(data)
						local findButton = newPlot.Folder.Platforms:FindFirstChild(data.."Button")
						if findPlatform or findButton then
							local platformPrice = findButton:GetAttribute("Price")
							local totalCash = newPlot.OwnerData.Cash
							local rebirthPlatformRequirements = {
							}
							if totalCash >= platformPrice then
								-- remove cash --
								FXRemote:FireClient(newPlot.Owner,"Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.sold})
								PlayerReplica:SetValue({"Cash"}, totalCash-platformPrice)
								-- add to data --
								PlayerReplica:SetValue({"Unlocks", data.."Platform"}, true)
								-- initialize platform (get from rep storage) --
								findPlatform.Parent = newPlot.Folder.Platforms
								SetupPlatform(findPlatform)
								-- delete button --
								findButton:Destroy()
								-- reveal next platform button --
								newPlot:RevealNextPlatform()
							else
								local difference = platformPrice-totalCash
								FXRemote:FireAllClients("Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.error,['norandom'] = true})
								UIRemote:FireClient(newPlot.Owner, "TopNotification", {
									["Text"] = "You need $"..NumberShortener.roundNumber(difference).." more to buy this platform.";
									["Duration"] = 5;
									["ShadowColor"] = Color3.fromRGB(255, 0, 0);
									["ShadowTransparency"] = 0.35;
								})
							end
						end
					elseif call == "SellFruits" then
						local getFruitValue = 0
						local fruitIDs = {}

						-- get value of fruits --
						for itemID, itemCache in newPlot.OwnerData.Inventory do
							if ItemsData[itemCache.Name] and ItemsData[itemCache.Name].Type == "Fruit" and not itemCache.Favorited then
								table.insert(fruitIDs, itemID)
								getFruitValue += Calculator.CalculateWorth(ItemsData[itemCache.Name].SellPrice, itemCache.Weight, itemCache.Mutations)
							end
						end


						if #fruitIDs <= 0 then
							FXRemote:FireClient(newPlot.Owner,"Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.error})

							Remotes.SendDialogue:FireClient(newPlot.Owner, {
								["NPC"] = "Merchant";
								["Sentence"] = "You have no fruits to sell.";
								["Duration"] = 5;
							})
							return
						end

						local friendBoost = Player:GetAttribute("friendboost") or 0
						local boostMultiplier = 1 + (friendBoost * 0.1) -- Each friend = 10%, max 5 friends = 50%
						getFruitValue = math.floor(getFruitValue * boostMultiplier)

						-- remove items --
						for _, id in fruitIDs do
							-- delete data --
							PlayerReplica:SetValue({"Inventory", id}, nil)

							-- delete tool --
							local findTool
							for _, t in Player.Backpack:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ID") == id then findTool = t end end
							for _, t in Player.Character:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ID") == id then findTool = t end end
							if findTool then findTool:Destroy() end

							task.wait(0.05)
						end

						-- give money --
						newPlot:GiveCash(getFruitValue)
						FXRemote:FireClient(newPlot.Owner,"Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.sold})
						Remotes.SendDialogue:FireClient(newPlot.Owner, {
							["NPC"] = "Merchant";
							["Sentence"] = "You sold all your fruits for $"..getFruitValue.."!";
							["Duration"] = 5;
						})


					elseif call == "SellCurrentItem" then
						for _, t in Player.Character:GetChildren() do 
							if t:IsA("Tool") then
								local id = t:GetAttribute("ID")
								local invCache = newPlot.OwnerData.Inventory[id]

								if invCache then
									if BrainrotData[invCache.Name] then
										local val = Calculator.CalculateWorth(BrainrotData[invCache.Name].SellPrice, invCache.Weight, invCache.Mutations)

										-- delete data --
										PlayerReplica:SetValue({"Inventory", id}, nil)

										-- delete tool --
										local findTool
										for _, t in Player.Backpack:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ID") == id then findTool = t end end
										for _, t in Player.Character:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ID") == id then findTool = t end end
										if findTool then findTool:Destroy() end

										newPlot:GiveCash(val)
									elseif ItemsData[invCache.Name] then
										local val = Calculator.CalculateWorth(ItemsData[invCache.Name].SellPrice, invCache.Weight, invCache.Mutations)

										-- delete data --
										PlayerReplica:SetValue({"Inventory", id}, nil)

										-- delete tool --
										local findTool
										for _, t in Player.Backpack:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ID") == id then findTool = t end end
										for _, t in Player.Character:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ID") == id then findTool = t end end
										if findTool then findTool:Destroy() end

										newPlot:GiveCash(val)
									end
								end
							end
						end
					elseif call == "SellRots" then
						local getRotValue = 0
						local rotIDs = {}

						-- get value of fruits --
						for itemID, itemCache in newPlot.OwnerData.Inventory do
							if BrainrotData[itemCache.Name] and not itemCache.Favorited then
								table.insert(rotIDs, itemID)
								getRotValue += Calculator.CalculateWorth(BrainrotData[itemCache.Name].SellPrice, itemCache.Weight, itemCache.Mutations)
							end
						end

						if #rotIDs <= 0 then

							FXRemote:FireClient(newPlot.Owner,"Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.error})


							Remotes.SendDialogue:FireClient(newPlot.Owner, {
								["NPC"] = "Merchant";
								["Sentence"] = "You have no brainrots to sell.";
								["Duration"] = 5;
							})
							return
						end

						local friendBoost = Player:GetAttribute("friendboost") or 0
						local boostMultiplier = 1 + (friendBoost * 0.1) -- Each friend = 10%, max 5 friends = 50%
						getRotValue = math.floor(getRotValue * boostMultiplier)


						-- remove items --
						for _, id in rotIDs do
							-- delete data --
							PlayerReplica:SetValue({"Inventory", id}, nil)

							-- delete tool --
							local findTool
							for _, t in Player.Backpack:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ID") == id then findTool = t end end
							for _, t in Player.Character:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ID") == id then findTool = t end end
							if findTool then findTool:Destroy() end

							task.wait(0.05)
						end

						-- give money --
						newPlot:GiveCash(getRotValue)
						FXRemote:FireClient(newPlot.Owner,"Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.sold})

						Remotes.SendDialogue:FireClient(Player, {
							["NPC"] = "Merchant";
							["Sentence"] = "You sold all your brainrots for $"..getRotValue.."!";
							["Duration"] = 5;
						})
					elseif call == "SendBrainrotGift" then
						local brainrotID = data.ID
						local otherPlayer = PlayersService:FindFirstChild(data.PlayerToSend) 

						if newPlot.OwnerData.Inventory[brainrotID] and otherPlayer then
							UIRemote:FireClient(otherPlayer, "Prompt", {
								["Type"] = "AcceptGiftPrompt";
								["Text"] = "Would you like to accept "..newPlot.OwnerData.Inventory[brainrotID].Name.." from "..newPlot.Owner.Name.."?";
								["BrainrotID"] = brainrotID;
								["PlayerSent"] = newPlot.Owner.Name;
							})

							newPlot.Owner:SetAttribute("GiftID", brainrotID)
							newPlot.Owner:SetAttribute("GiftPlayer", data.PlayerToSend)
						end
					elseif call == "AcceptBrainrotGift" then
						local ID = data.ID
						local playerWhoSent = data.PlayerWhoSent

						local getPlayerWhoSent = PlayersService:FindFirstChild(playerWhoSent)

						if getPlayerWhoSent then
							if getPlayerWhoSent:GetAttribute("GiftPlayer") == newPlot.Owner.Name and getPlayerWhoSent:GetAttribute("GiftID") == ID then
								-- Remove the item & tool from the player. --
								local GetPlayerWhoSentPlot
								for _,p in plot.Plots do if p.Owner == getPlayerWhoSent then GetPlayerWhoSentPlot = p end end

								if GetPlayerWhoSentPlot then
									-- Save the data for the item from other player. --
									local savedData = {}
									for Index, Value in GetPlayerWhoSentPlot.OwnerData.Inventory[ID] do
										savedData[Index] = Value
									end
									savedData["ID"] = ID

									-- Remove the item from the other player. --
									GetPlayerWhoSentPlot.OwnerReplica:SetValue({"Inventory", ID}, nil)
									local getTool
									for _, backpackItem in GetPlayerWhoSentPlot.Owner.Backpack:GetChildren() do if backpackItem:IsA("Tool") then if backpackItem:GetAttribute("ID") == ID then getTool = backpackItem end end end
									for _, backpackItem in GetPlayerWhoSentPlot.Owner.Character:GetChildren() do if backpackItem:IsA("Tool") then if backpackItem:GetAttribute("ID") == ID then getTool = backpackItem end end end
									if getTool then getTool:Destroy() end

									-- Add item to this player. --
									newPlot:GiveItem(savedData)
								end
							end
						end
					elseif call == "Favorite" then
						if newPlot.OwnerData.Inventory[data] then
							newPlot.OwnerReplica:SetValue({"Inventory", data, "Favorited"}, true)
						end
					elseif call == "ActivatePrompt" then
						warn('Prompt tried.')
						if newPlot.Functions[data] then
							newPlot.Functions[data](user)

						end

						if ServerUtility.ActiveFruit[data] then
							ServerUtility.ActiveFruit[data](user, nil, nil)
						end
					elseif call == "Unfavorite" then
						if newPlot.OwnerData.Inventory[data] then
							newPlot.OwnerReplica:SetValue({"Inventory", data, "Favorited"}, false)
						end
					elseif call == "EquipBest" then
						-- make array to store the brainrots in order of greatest to least money --
						local OrderedBrainrotsList = {}
						local FullBrainrotsList = {}

						-- unequip all current brainrots & check them --
						for BrainrotID, BrainrotTable in newPlot.Brainrots do
							FullBrainrotsList[BrainrotID] = Calculator.CalculateMoneyPerSecond(BrainrotTable.Name, BrainrotTable.Weight, BrainrotTable.Mutations, user:GetAttribute("Rebirths"))
							newPlot:RemoveBrainrot(BrainrotID)
						end

						-- add all brainrots in inventory --
						for itemID, itemData in newPlot.OwnerData.Inventory do
							if itemData and BrainrotData[itemData.Name] then
								FullBrainrotsList[itemID] = Calculator.CalculateMoneyPerSecond(itemData.Name, itemData.Weight, itemData.Mutations, user:GetAttribute("Rebirths"))
							end
						end

						-- check how many available spots there are in plot --
						local AvailableSpots = 2 -- (automatically have 1,2, and super platforms) --
						for UnlockName, _ in newPlot.OwnerData.Unlocks do
							if string.find(UnlockName, "Platform") then
								AvailableSpots += 1
							end
						end

						local manualCount = 0
						for i,v in FullBrainrotsList do manualCount += 1 end

						-- No brainrots to equip
						if manualCount == 0 then return end

						-- take best brainrot out of the list, on last iteration of loop below it'll put the best brainrot on the super platform. --
						local BestBrainrot; local BestBrainrotValue
						for ID, value in FullBrainrotsList do
							if not BestBrainrotValue then BestBrainrot = ID; BestBrainrotValue = value else
								if BestBrainrotValue < value then
									BestBrainrot = ID; BestBrainrotValue = value;
								end
							end
						end

						if BestBrainrot then
							FullBrainrotsList[BestBrainrot] = nil
							manualCount -= 1
						end

						if manualCount <= AvailableSpots then
							-- Just place them all, only have enough brainrots for available slots. --
							local i = 1

							for RotID, _ in FullBrainrotsList do
								local getTool
								for _, c in user.Backpack:GetChildren() do
									if c:GetAttribute("ID") == RotID then
										getTool = c
									end
								end
								for _, c in user.Character:GetChildren() do
									if c:GetAttribute("ID") == RotID then
										getTool = c
									end
								end

								local index = i
								newPlot:PlaceBrainrot(RotID, index, getTool)

								i += 1
							end
						else
							-- Calculate greatest to smallest, pick the top (x=availablespots) to place down. --

							-- Convert dictionary to array for sorting --
							for RotID, MoneyPerSecond in FullBrainrotsList do
								table.insert(OrderedBrainrotsList, {
									ID = RotID,
									Value = MoneyPerSecond
								})
							end

							-- Sort by money per second (greatest to least) --
							table.sort(OrderedBrainrotsList, function(a, b)
								return a.Value > b.Value
							end)

							-- Place only the top brainrots up to AvailableSpots --
							for i = 1, math.min(AvailableSpots, #OrderedBrainrotsList) do
								local RotID = OrderedBrainrotsList[i].ID
								local getTool

								-- Find tool in Backpack --
								for _, c in user.Backpack:GetChildren() do
									if c:GetAttribute("ID") == RotID then
										getTool = c
										break
									end
								end

								-- Find tool in Character if not in Backpack --
								if not getTool then
									for _, c in user.Character:GetChildren() do
										if c:GetAttribute("ID") == RotID then
											getTool = c
											break
										end
									end
								end	

								-- Place the brainrot --
								if getTool then
									newPlot:PlaceBrainrot(RotID, i, getTool)
								end
							end
						end

						-- Place best brainrot on Super platform
						if BestBrainrot then
							local getTool
							for _, c in user.Backpack:GetChildren() do
								if c:GetAttribute("ID") == BestBrainrot then
									getTool = c
								end
							end
							for _, c in user.Character:GetChildren() do
								if c:GetAttribute("ID") == BestBrainrot then
									getTool = c
								end
							end

							newPlot:PlaceBrainrot(BestBrainrot, "Super", getTool)
						end
					end
				end
			end)



			newPlot.Connections[4] = PlotRemote.OnServerEvent:Connect(function(user, call, info)
				if newPlot.Owner == user then 
					if call == "PlacePlant" then
						local uniqueID = HttpService:GenerateGUID(false)
						newPlot:PlacePlant(uniqueID,info.RawPosition,info.ID)
					elseif call == "PlaceGear" then
						-- Validate placement before placing
						local success, result1, result2 = SprinklerSystem:ValidatePlacement(user, info.RawPosition, info.ID)
						if success then
							local uniqueID = HttpService:GenerateGUID(false)
							newPlot:PlaceGear(uniqueID, info.RawPosition, info.ID)
						else
							-- Send error to client
							UIRemote:FireClient(user, "TopNotification", {
								Text = result1 or "Cannot place gear here!";
								Duration = 3;
								ShadowColor = Color3.fromRGB(255, 0, 0);
								ShadowTransparency = 0.35;
							})
						end
					elseif call == "RemoveGear" then
						-- Handle gear removal request
						SprinklerSystem:HandleRemoveRequest(user, info)
					elseif call == "RemovePlant" then
						local PlantID = info
						newPlot:RemovePlant(PlantID)
					elseif call == "HarvestPlant" then
						-- Client requests to harvest a fruit from a plant
						local PlantID = info.PlantID
						local FruitIndex = info.FruitIndex
						newPlot:HarvestPlant(PlantID, FruitIndex)
					elseif call == "DeskButton" then
						-- Handle mobile/touch desk button clicks
						local buttonType = info.Type
						local deskNumber = info.DeskNumber

						if buttonType == "Accept" then
							-- Trigger the same logic as the Accept button ClickDetector
							if newPlot.CurrentCustomer[deskNumber] ~= nil then
								if user == newPlot.Owner then
									local getCurrentOrder = newPlot.CurrentOrder[deskNumber]
									if getCurrentOrder and getCurrentOrder.Cache then
										local orderCache = getCurrentOrder.Cache

										local reqs = orderCache.Requirements
										local currents = orderCache.Currents

										local passChecks = true

										for fruit, count in reqs do
											if not next(currents[fruit] or {}) or currents[fruit] == nil then
												passChecks = false
												continue
											end

											if #currents[fruit] < count then
												passChecks = false
											end
										end

										if not passChecks then
											FXRemote:FireAllClients("Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.error,['norandom'] = true})

											UIRemote:FireClient(newPlot.Owner, "TopNotification", {
												["Text"] = "You have not finished this order!";
												["Duration"] = 5;
												["TextColor"] = Color3.fromRGB(255, 255, 255);
												["ShadowColor"] = Color3.fromRGB(255, 0, 0);
												["ShadowTransparency"] = 0.35;
											})

											local BrainrotModel = Models:FindFirstChild(getCurrentOrder.Brainrot)
											local BrainrotRarity = BrainrotModel:GetAttribute("Rarity")

											if plot.AutoCompletes[BrainrotRarity] then
												MarketplaceService:PromptProductPurchase(newPlot.Owner, plot.AutoCompletes[BrainrotRarity])
												Player:SetAttribute("CompletedPurchaseData", deskNumber)
											end

											return
										end

										if passChecks then
											newPlot.Functions["CompleteOrder"](deskNumber, passChecks)
										end
									end
								end
							end
						elseif buttonType == "Decline" then
							-- Trigger the same logic as the Decline button ClickDetector
							if not newPlot.CurrentCustomer[deskNumber] or not newPlot.CurrentCustomer[deskNumber].ID then
								return -- No customer at desk yet
							end

							local brainrotID = newPlot.CurrentCustomer[deskNumber].ID
							newPlot:DestroyBrainrot(brainrotID, newPlot.CurrentCustomer[deskNumber].Path, newPlot.CurrentCustomer[deskNumber].Index)
						end
					end
				end
			)	

		newPlot.Connections[5] = SettingRemote.OnServerEvent:Connect(function(user, call, info)
			if newPlot.Owner == user then
					if call == "AutoSell" then
						PlayerReplica:SetValue({"Settings", "AutoSell", info.Rarity}, info.Value)
					elseif call == "UpdateSetting" then
						PlayerReplica:SetValue({"Settings", info.Setting}, info.Value)

						if info.Setting == "ShowBrainrots" then
							if info.Value then
								---- spawn other players brainrots --
								--for plotNum, spawnsList in ServerUtility.Spawns do
								--	--if plotNum == newPlot.PlotNumber then continue end
								--	for _, ID in spawnsList do
								--		local getCache = plot.Plots[plotNum].Brainrots[ID]
								--		SpawnRemote:FireClient(user, "SpawnPlatformBrainrot", getCache)
								--	end
								--end

								for plotNum, spawnsList in ServerUtility.CustomerSpawns do
									local plotCache = plot.Plots[plotNum]

									for _, ID in spawnsList do
										local getCache = plotCache.Active[ID]
										local getOrderCache = plotCache.Orders[ID]

										if getCache then
											if getOrderCache then
												ServerUtility.ClientSpawnCustomerBrainrot(ID, getCache, plotNum, getOrderCache, user)
											else
												ServerUtility.ClientSpawnCustomerBrainrot(ID, getCache, plotNum, nil, user)
											end
										end
									end
								end
							else
								-- despawn other players brainrots --
								--for plotNum, spawnsList in ServerUtility.Spawns do
								--	for _, ID in spawnsList do
								--		SpawnRemote:FireAllClients("DeleteBrainrot", {
								--			["ID"] = ID;
								--			["Platform"] = true;
								--			["Plot"] = plotNum;
								--		})
								--	end
								--end

								for plotNum, spawnsList in ServerUtility.CustomerSpawns do
									local plotCache = plot.Plots[plotNum]

									for _, ID in spawnsList do
										SpawnRemote:FireClient(user, "DeleteBrainrot", {
											["ID"] = ID;
											["Plot"] = plotNum;
											["Path"] = plotCache.Active[ID].Path;
										})
									end
								end
							end
						elseif info.Setting == "ShowPlants" then
							if info.Value then
								-- Tell client to show all plants
								PlotRemote:FireClient(user, "ShowAllPlants", newPlot.OwnerData.Plot)
							else
								-- Tell client to hide other players' plants
								PlotRemote:FireClient(user, "HideOtherPlants")
							end
						end
					end
				end
			end)

		newPlot.Connections[6] = CodesRemote.OnServerEvent:Connect(function(user, call, info)
			if call == "ClaimCode" then
				if newPlot.OwnerData.Codes[info] == nil then
					if CodesData[info] then
						-- Claim code. --
						newPlot.OwnerReplica:SetValue({"Codes", info}, true)

						for Reward, RewardData in CodesData[info] do
							if RewardData.Type == "Currency" then
								local currentAmount = newPlot.OwnerData[RewardData.Name]
								newPlot.OwnerReplica:SetValue({RewardData.Name}, currentAmount + RewardData.Amount)
							elseif RewardData.Type == "Misc" then
								local amountOfThing = RewardData.Amount
								local thingName = RewardData.Name

								for i =  1, amountOfThing do
									local mutationLuck = user:GetAttribute("MutationLuck") or 0
									local totalLuck = user:GetAttribute("Luck") or 0 

									local weightPool = BrainrotData[thingName].WeightPool
									local weight = RewardData.Weight or PickScale.RandomizeWeight(weightPool, newPlot.Owner:GetAttribute("SizeLuck"))
									local mutation = PickMutations.PickMutation(mutationLuck+totalLuck, plot.EventMultipliers)

									newPlot:GiveItem({
										["ID"] = HttpService:GenerateGUID(false);
										["Name"] = thingName;
										["Weight"] = weight;
										["Mutations"] = {mutation};
									})
								end
							end
						end

						UIRemote:FireClient(newPlot.Owner, "TopNotification", {
							Text = "Successfully claimed "..info.."!";
							["ShadowColor"] = Color3.fromRGB(0, 241, 108);
							["ShadowTransparency"] = 0.35;
						})
					else
						-- Invalid code. --
						UIRemote:FireClient(newPlot.Owner, "TopNotification", {
							Text = "Not a valid code!";
							["ShadowColor"] = Color3.fromRGB(241, 0, 0);
							["ShadowTransparency"] = 0.35;
						})
					end
				else
					-- Claimed code. --
					FXRemote:FireAllClients("Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.error,['norandom'] = true})

					UIRemote:FireClient(newPlot.Owner, "TopNotification", {
						Text = "You already claimed this code!";
						["ShadowColor"] = Color3.fromRGB(241, 0, 0);
						["ShadowTransparency"] = 0.35;
					})
				end
			elseif call == "ClaimGroupRewards" then
				if newPlot.OwnerData.Codes["GroupRewards"] == nil then
						-- Claim code. --
						newPlot.OwnerReplica:SetValue({"Codes", "GroupRewards"}, true)
						
						newPlot:GiveCash(10000)
						newPlot:GiveItem({
							["ID"] = HttpService:GenerateGUID(false);
							["Name"] = "Freeze Ray";
							["Quantity"] = 1;
						})

						UIRemote:FireClient(newPlot.Owner, "TopNotification", {
							Text = "You have claimed the group rewards!";
							["ShadowColor"] = Color3.fromRGB(222, 43, 186);
							["ShadowTransparency"] = 0.35;
						})
				else
					FXRemote:FireAllClients("Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.error,['norandom'] = true})

					UIRemote:FireClient(newPlot.Owner, "TopNotification", {
						Text = "You already claimed the group rewards!";
						["ShadowColor"] = Color3.fromRGB(222, 43, 186);
						["ShadowTransparency"] = 0.35;
					})
				end
			end
		end)


		newPlot.Connections[7] = Remotes.Rebirth.OnServerEvent:Connect(function(user)
			if newPlot.Owner ~= user then
				return
			end



			local Rebirth = PlayerReplica.Data.Rebirths
			local RebirthGoal = Rebirth + 1

			local Requirements = RebirthsData[RebirthGoal].Requirements -- these are requirements		
			local hasRequirements = false

			local function hasRequiredInventory()
				for brainrotName, requiredAmount in pairs(Requirements) do
					if brainrotName == "Money" then
						continue
					end

					local count = 0
					for _, itemData in pairs(PlayerReplica.Data.Inventory) do
						if itemData.Name == brainrotName then
							count += 1
						end
					end

					for _, itemData in pairs(PlayerReplica.Data.Brainrots) do
						if itemData.Name == brainrotName then
							count += 1
						end
					end

					if count < requiredAmount then
						return false
					end
				end

				return true
			end



			hasRequirements = hasRequiredInventory()

			if not hasRequirements then	
				UIRemote:FireClient(newPlot.Owner, "TopNotification", {
					Text = "You are missing requirements to rebirth!";
					Duration = 5;
					["ShadowColor"] = Color3.fromRGB(241, 0, 0);
					["ShadowTransparency"] = 0.35;
				})
				return
			end

			-- remove all brainrots from platforms --
			local FullBrainrotsList = {}

			for BrainrotID, BrainrotTable in newPlot.Brainrots do
				FullBrainrotsList[BrainrotID] = true
				newPlot:RemoveBrainrot(BrainrotID)
			end

			for BrainrotID, MPS in FullBrainrotsList do
				newPlot.OwnerReplica:SetValue({"Inventory", BrainrotID}, nil)
			end

			
			
			-- Build list of all brainrot tools to remove
			local FullToolsList = {}
			for _, tool in newPlot.Owner.Backpack:GetChildren() do
				if tool:IsA("Tool") then
					local toolID = tool:GetAttribute("ID")
					if toolID and newPlot.OwnerData.Inventory[toolID] then
						local invCache = newPlot.OwnerData.Inventory[toolID]
						if BrainrotData[invCache.Name] then  -- Check if it's a brainrot
							FullToolsList[tool] = toolID
						end
					end
				end
			end

			if newPlot.Owner.Character then
				for _, tool in newPlot.Owner.Character:GetChildren() do
					if tool:IsA("Tool") then
						local toolID = tool:GetAttribute("ID")
						if toolID and newPlot.OwnerData.Inventory[toolID] then
							local invCache = newPlot.OwnerData.Inventory[toolID]
							if BrainrotData[invCache.Name] then  -- Check if it's a brainrot
								FullToolsList[tool] = toolID
							end
						end
					end
				end
			end

			-- Destroy all brainrot tools
			for Tool, ToolID in FullToolsList do
				Tool:Destroy()
			end
			-- has requirements

			PlayerReplica:SetValue({"Rebirths"},RebirthGoal)
			Player:SetAttribute("Rebirths",RebirthGoal)
			
			PlayerReplica:SetValue({"Cash"},0)

			if newPlot.Functions["Rebirth"..RebirthGoal] then
				newPlot.Functions["Rebirth"..RebirthGoal]()
			end

			if RebirthGoal == 2 or RebirthGoal == 3 then
				UIRemote:FireClient(newPlot.Owner, "TopNotification", {
					Text = "You have unlocked a new line!";
					Duration = 5;
					["ShadowColor"] = Color3.fromRGB(187, 49, 227);
					["ShadowTransparency"] = 0.35;
				})
			end

			for _, StoredButton in Replicated.PlotStorage[i]:GetChildren() do
				if StoredButton:GetAttribute("Rebirth") and StoredButton:GetAttribute("Rebirth") <= newPlot.OwnerData.Rebirths then
					StoredButton.Parent = newPlot.Folder.Platforms
					SetupButton(StoredButton)
				end
			end
		end)

		-- NEW: PlotRemote handlers for client-side authority fruit system
		newPlot.Connections["PlotRemote"] = PlotRemote.OnServerEvent:Connect(function(Player, call, data)
			if newPlot.Owner ~= Player then return end
			
			if call == "RequestFruitHarvest" then
				-- Client requests to harvest a fruit
				local PlantID = data.PlantID
				local FruitIndex = data.FruitIndex
				
				local success, errorMsg = newPlot:RequestFruitHarvest(PlantID, FruitIndex)
				
				if not success then
					-- Send error to client
					PlotRemote:FireClient(Player, "FruitHarvestFailed", {
						PlantID = PlantID;
						FruitIndex = FruitIndex;
						Error = errorMsg;
					})
				end
				
			elseif call == "RequestInitializeFruits" then
				-- Client requests fruit initialization (when plant becomes fully grown)
				local PlantID = data.PlantID
				local BranchCount = data.BranchCount
				
				local plantData = PlayerReplica.Data.Plot[PlantID]
				if not plantData then return end
				
				local plantModule = PlantModules[plantData.Name]
				if not plantModule then return end
				
				if plantModule.Type == "Single" then
					-- Single plants don't need branch count
					newPlot:InitializePlantFruits(PlantID)
				else
					-- Spawner plants need branch count from client
					newPlot:InitializeSpawnerFruits(PlantID, BranchCount or 1)
				end
				
			elseif call == "ToggleFruitFavorite" then
				-- Client requests to toggle favorite status
				local PlantID = data.PlantID
				local FruitIndex = data.FruitIndex
				
				newPlot:ToggleFruitFavorite(PlantID, FruitIndex)
				
			elseif call == "RequestPlantGrowthCheck" then
				-- Client checking if plant is fully grown
				local PlantID = data.PlantID
				
				local plantData = PlayerReplica.Data.Plot[PlantID]
				if not plantData then return end
				
				local TimeBuffer = BitBuffer.Create()
				TimeBuffer:FromBase64(plantData.PlantTimestamp)
				local plantTime = TimeBuffer:ReadFloat64()
				local growthDuration = plantData.GrowthDuration or 60
				local percentCompleted = math.clamp((workspace:GetServerTimeNow() - plantTime) / growthDuration, 0, 1)
				
				if percentCompleted >= 1 then
					-- Plant is fully grown, initialize fruits if not already done
					if not plantData.Fruits or not next(plantData.Fruits) then
						PlotRemote:FireClient(Player, "PlantReadyForFruits", PlantID)
					end
				end
			end
		end)

		-- CRITICAL FIX: Changed from Connections[7] to Connections[8] to prevent overwrite (Issue #3)
		-- DEPRECATED: Use PlotRemote "ToggleFruitFavorite" instead
		newPlot.Connections[8] = Remotes.FavoriteFruit.OnServerEvent:Connect(function(Player, PlantID, FruitToFavorite)
			-- Redirect to new system
			newPlot:ToggleFruitFavorite(PlantID, FruitToFavorite)
		end)



			-- [GAG] Load plants to plot (tell client to spawn visuals) --
			for PlantID, PlantCache in newPlot.OwnerData.Plot do
				-- Fire to client to spawn plant visual
				PlotRemote:FireClient(newPlot.Owner, "SpawnPlant", PlantID, PlantCache)
			end
			
			
			for PlantID, PlantCache in newPlot.OwnerData.PlotGears do
				newPlot:PlaceGear(PlantID)
			end
			
			-- Trigger VFX for existing active sprinklers
			task.delay(2, function()
				for gearID, gearData in pairs(newPlot.OwnerData.PlotGears or {}) do
					local gearInfo = GearsData[gearData.Name]
					if gearInfo and gearInfo.PlaceableData and gearInfo.PlaceableData.Duration then
						-- Check if still active
						local isActive = true
						if gearData.ActivatedTime then
							local timeBuffer = BitBuffer.Create()
							timeBuffer:FromBase64(gearData.ActivatedTime)
							local activatedTime = timeBuffer:ReadFloat64()
							local endTime = activatedTime + gearInfo.PlaceableData.Duration
							isActive = workspace:GetServerTimeNow() <= endTime
						end
						
						if isActive and newPlot.Objects[gearID] then
							-- Trigger VFX for this sprinkler
							SprinklerSystem:OnSprinklerPlaced(newPlot, gearID, newPlot.Objects[gearID], gearData.Name)
						end
					end
				end
			end)
			
	
			

			plot.Plots[i] = newPlot
			newPlot.Owner:SetAttribute("PlotLoaded", true)
			return newPlot
		end
	end
end

function plot:Terminate() -- destroys all connections & objects tied to plot --
	-- remove all scales / mutates --
	-- remove all spawns --

	for model, _ in ServerUtility.Mutations or {} do
		if table.find(self.Objects, model) or self.Objects[model] then
			ServerUtility.Mutations[model] = nil
		end
	end

	for model, _ in ServerUtility.Scales or {} do
		if table.find(self.Objects, model) or self.Objects[model] then
			ServerUtility.Scales[model] = nil
		end
	end

	for _, spawnID in ServerUtility.CustomerSpawns[self.PlotNumber] or {} do
		-- despawn --
		-- CRITICAL FIX: Added nil check for self.Active[spawnID] (Issue #6)
		local activeData = self.Active[spawnID]
		if activeData then
			SpawnRemote:FireAllClients("DeleteBrainrot", {
				["ID"] = spawnID;
				["Plot"] = self.PlotNumber;
				["Path"] = activeData.Path;
			})
		end
	end

	for _, spawnID in ServerUtility.Spawns[self.PlotNumber] or {} do
		-- despawn --
		SpawnRemote:FireAllClients("DeleteBrainrot", {
			["ID"] = spawnID;
			["Platform"] = true;
			["Plot"] = self.PlotNumber;
		})
	end

	ServerUtility.Spawns[self.PlotNumber] = nil
	ServerUtility.CustomerSpawns[self.PlotNumber] = nil

	self.Folder.Headshot.BillboardGui.ImageLabel.Image = "rbxassetid://0"
	self.Folder.Headshot.BillboardGui.Header.Text = ""

	for _, d in self.Folder:GetDescendants() do
		if d:IsA("Script") then d:Destroy() end
	end

	for _, obj in self.Objects or {} do
		if typeof(obj) == "Instance" then
			obj:Destroy()
		end
	end

	for _, conn in self.Connections or {} do
		conn:Disconnect()
	end

	self.Folder:SetAttribute("Vacant", true)

	table.remove(plot.Plots, table.find(plot.Plots, self))
end

-- Main --
function plot:GiveCash(amount)
	local initialCash = amount 
	local multiplier = self.Owner:GetAttribute("MoneyMultiplier") or 0
	local finalCash = initialCash * (1 + multiplier)

	self.OwnerReplica:SetValue({"Cash"}, self.OwnerData.Cash + finalCash)
end

function plot:GiveTotalLuck(amount, Time)
	local currentLuck = self.Owner:GetAttribute("Luck") or 0
	local totalLuck = currentLuck + amount
	self.Owner:SetAttribute("Luck", totalLuck)

	if Time then
		if not plot.PlayerDelays then plot.PlayerDelays = {} end
		if not plot.PlayerDelays[self.Owner] then plot.PlayerDelays[self.Owner] = {} end

		plot.PlayerDelays[self.Owner][HttpService:GenerateGUID(false)] = task.delay(Time, function()
			self.Owner:SetAttribute("Luck", self.Owner:GetAttribute("Luck") - amount)
		end)
	end
end

function plot:GiveMutationLuck(amount, Time)
	local currentLuck = self.Owner:GetAttribute("MutationLuck") or 0
	local totalLuck = currentLuck + amount
	self.Owner:SetAttribute("MutationLuck", totalLuck)

	if Time then
		if not plot.PlayerDelays then plot.PlayerDelays = {} end
		if not plot.PlayerDelays[self.Owner] then plot.PlayerDelays[self.Owner] = {} end

		plot.PlayerDelays[self.Owner][HttpService:GenerateGUID(false)] = task.delay(Time, function()
			self.Owner:SetAttribute("MutationLuck", self.Owner:GetAttribute("MutationLuck") - amount)
		end)
	end
end

function plot:GiveBrainrotLuck(amount, Time)
	local currentLuck = self.Owner:GetAttribute("BrainrotLuck") or 0
	local totalLuck = currentLuck + amount
	self.Owner:SetAttribute("BrainrotLuck", totalLuck)

	if Time then
		if not plot.PlayerDelays then plot.PlayerDelays = {} end
		if not plot.PlayerDelays[self.Owner] then plot.PlayerDelays[self.Owner] = {} end

		plot.PlayerDelays[self.Owner][HttpService:GenerateGUID(false)] = task.delay(Time, function()
			self.Owner:SetAttribute("BrainrotLuck", self.Owner:GetAttribute("BrainrotLuck") - amount)
		end)
	end
end

function plot:GiveSizeLuck(amount, Time)
	local currentLuck = self.Owner:GetAttribute("SizeLuck") or 0
	local totalLuck = currentLuck + amount
	self.Owner:SetAttribute("SizeLuck", totalLuck)

	if Time then
		if not plot.PlayerDelays then plot.PlayerDelays = {} end
		if not plot.PlayerDelays[self.Owner] then plot.PlayerDelays[self.Owner] = {} end

		plot.PlayerDelays[self.Owner][HttpService:GenerateGUID(false)] = task.delay(Time, function()
			self.Owner:SetAttribute("SizeLuck", self.Owner:GetAttribute("SizeLuck") - amount)
		end)
	end
end

function plot:GiveSpeed(amount, Time)
	local currentLuck = self.Owner:GetAttribute("Speed") or 0
	local totalLuck = currentLuck + amount
	self.Owner:SetAttribute("Speed", totalLuck)

	if Time then
		if not plot.PlayerDelays then plot.PlayerDelays = {} end
		if not plot.PlayerDelays[self.Owner] then plot.PlayerDelays[self.Owner] = {} end

		plot.PlayerDelays[self.Owner][HttpService:GenerateGUID(false)] = task.delay(Time, function()
			self.Owner:SetAttribute("Speed", self.Owner:GetAttribute("Speed") - amount)
		end)
	end
end

function plot:GiveCashMultiplier(amount, Time)
	local currentMoneyMultiplier = self.Owner:GetAttribute("MoneyMultiplier") or 0
	local totalCurrentMoneyMultiplier = currentMoneyMultiplier + amount
	self.Owner:SetAttribute("MoneyMultiplier", totalCurrentMoneyMultiplier)

	if Time then
		if not plot.PlayerDelays then plot.PlayerDelays = {} end
		if not plot.PlayerDelays[self.Owner] then plot.PlayerDelays[self.Owner] = {} end

		plot.PlayerDelays[self.Owner][HttpService:GenerateGUID(false)] = task.delay(Time, function()
			self.Owner:SetAttribute("MoneyMultiplier", self.Owner:GetAttribute("MoneyMultiplier") - amount)
		end)
	end
end

function plot.GiveServerLuck(amount, Type, Time, noFire, resetTimer)
	if not plot.EventMultipliers[Type] then 
		plot.EventMultipliers[Type] = {
			["Start"] = tick();
			["Time"] = 0;
			["Amount"] = 0;
			["ExtraRemovals"] = 0;
		} 
	end

	plot.EventMultipliers[Type].Time = Time
	plot.EventMultipliers[Type].Start = tick()
	plot.EventMultipliers[Type].Amount += amount
	plot.EventMultipliers[Type].NoFire = noFire

	workspace:SetAttribute("ServerLuck", (workspace:GetAttribute("ServerLuck") or 0) + amount)

	if not noFire then
		if Type ~= "Luck" then
			UIRemote:FireAllClients("Timer", {
				["Text"] = plot.EventMultipliers[Type].Amount.."x "..Type.." Server Luck";
				["Gradient"] = Type;
				["Time"] = Time;
			})
		else
			UIRemote:FireAllClients("Timer", {
				["Text"] = plot.EventMultipliers[Type].Amount.."x Server Luck";
				["Gradient"] = Type;
				["Time"] = Time;
			})
		end
	end

	if resetTimer then
		if plot.EventMultipliers[Type].Delay then task.cancel(plot.EventMultipliers[Type].Delay); plot.EventMultipliers[Type].ExtraRemovals += plot.EventMultipliers[Type].Amount end
	end

	plot.EventMultipliers[Type].Delay = task.delay(Time, function()
		local subtracter = amount + plot.EventMultipliers[Type].ExtraRemovals
		plot.EventMultipliers[Type].Amount -= subtracter
		workspace:SetAttribute("ServerLuck", workspace:GetAttribute("ServerLuck") - subtracter)
	end)
end

-- [[ TOOLS / INVENTORY ]] --
function plot:GiveItem(Info)

	-- Add to data. --
	local PlayerReplica = Data[self.Owner]

	local getLibraryData = ItemsData[Info.Name] or GearsData[Info.Name]
	local addsItem = true
	if getLibraryData and (getLibraryData.Type == "Plant" or getLibraryData.Type == "Potion" or getLibraryData.Type == "Gear") then
		local getID

		for ID, array in PlayerReplica.Data.Inventory do
			if array.Name == Info.Name then
				getID = ID
			end
		end

		if getID then
			PlayerReplica:SetValue({"Inventory",getID,"Quantity"},PlayerReplica.Data.Inventory[getID].Quantity+1)

			addsItem = false
		else
			PlayerReplica:SetValue({"Inventory",Info.ID}, {
				["Name"] = Info.Name;
				["Mutations"] = Info.Mutations or nil;
				["Weight"] = Info.Weight or nil;
				["Quantity"] = 1;
			})
		end
	else
		PlayerReplica:SetValue({"Inventory",Info.ID}, {
			["Name"] = Info.Name;
			["Mutations"] = Info.Mutations or nil;
			["Weight"] = Info.Weight or nil;
		})
	end

	local chooseColor = Color3.fromRGB(255,255,255)

	if Models:FindFirstChild(Info.Name) then
		chooseColor = Gradients:FindFirstChild(Models[Info.Name]:GetAttribute("Rarity")).Color.Keypoints[1].Value
	end

	if Info.Weight then
		function roundNumber(num, numDecimalPlaces)
			return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
		end

		UIRemote:FireClient(self.Owner, "ItemNotification", {
			Text = "+"..Info.Name.." ["..roundNumber(Info.Weight, 1).."kg]";
			Color = chooseColor;
		})
	else
		UIRemote:FireClient(self.Owner, "ItemNotification", {
			Text = "+"..Info.Name;
			Color = chooseColor;
		})
	end

	if Info.Weight then
		-- brainrot or something, check for index. --
		local currentIndexData = PlayerReplica.Data.Unlocks[Info.Name]
		local array = {["Normal"] = true}

		for _, mu in Info.Mutations do
			array[mu] = true
		end

		for oldMutation,_ in currentIndexData or {} do
			array[oldMutation] = true
		end

		PlayerReplica:SetValue({"Unlocks",Info.Name}, array)
		self.Functions["IndexBoost"]()
	end

	if addsItem then 
		-- Add to actual inventory. --
		self:GiveToolForItem(Info.ID) 
	else
		-- Add quantity to item. --
		local getItem

		for _, tool in self.Owner.Backpack:GetChildren() do if tool:IsA("Tool") then if tool:GetAttribute("Name") == Info.Name then getItem = tool end end end
		for _, tool in self.Owner.Character:GetChildren() do if tool:IsA("Tool") then if tool:GetAttribute("Name") == Info.Name then getItem = tool end end end

	
		if getItem then
			warn('add quant')
			getItem:SetAttribute("Quantity", PlayerReplica.Data.Inventory[getItem:GetAttribute("ID")].Quantity)
		end
	end
end

function plot:GiveToolForItem(ItemID)
	local Info = self.OwnerData.Inventory[ItemID]

	local getTool = Tools[Info.Name]:Clone()
	getTool.Parent = self.Owner.Backpack
	getTool:SetAttribute("ID", ItemID)
	getTool:SetAttribute("Name", Info.Name)

	if Info.Quantity then
		getTool:SetAttribute("Quantity", Info.Quantity)
	end

	-- connections --
	self.Connections[ItemID.."equip"] = getTool.Equipped:Connect(function()
		-- set player holding id to item --
		self.Owner:SetAttribute("Holding", ItemID)

		if Info.Weight then
			self.Owner:SetAttribute("BrainrotOut", true)
		end

		if ItemsData[Info.Name] and ItemsData[Info.Name].Type == "Fruit" then
			UIRemote:FireClient(self.Owner, "GiftItemPrompt", {["ID"] = ItemID; ["Dependency"] = getTool; ["Brainrot"] = Info.Name})	
		end

		if BrainrotData[Info.Name] then
			-- check on equipped, and create prompts for other players. --
			UIRemote:FireClient(self.Owner, "GiftBrainrotPrompt", {["ID"] = ItemID; ["Dependency"] = getTool; ["Brainrot"] = Info.Name})	
		end
	end)

	self.Connections[ItemID.."unequip"] = getTool.Unequipped:Connect(function()
		-- set player holding id to nil --
		self.Owner:SetAttribute("Holding", nil)
		self.Owner:SetAttribute("BrainrotOut", nil)
	end)

	-- specifications --
	-- specifications --
	if Info.Weight then
		function roundNumber(num, numDecimalPlaces)
			return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
		end

		getTool.Name = " [" .. roundNumber(Info.Weight,1) .. " kg] " .. Info.Name

		ServerUtility.ClientScale(Info.Weight, getTool:FindFirstChildOfClass("Model"))

		if BrainrotData[Info.Name] then
			local newOverhead = UI.CustomerOverhead:Clone()
			newOverhead.Parent = getTool.Handle.Attachment
			newOverhead.TitleFrame.Brainrot.Text = Info.Name
			newOverhead.TitleFrame.MoneyPerSecond.Text = "$"..NumberShortener.roundNumber(Calculator.CalculateMoneyPerSecond(Info.Name, Info.Weight, Info.Mutations,self.Owner:GetAttribute("Rebirths"))).."/s"
			newOverhead.TitleFrame.Rarity.Text = Models[Info.Name]:GetAttribute("Rarity")

			if newOverhead.TitleFrame.Rarity:FindFirstChild(Models[Info.Name]:GetAttribute("Rarity")) then
				newOverhead.TitleFrame.Rarity:FindFirstChild(Models[Info.Name]:GetAttribute("Rarity")).Enabled = true
			end

			-- mutations --
			for _, mutation in Info.Mutations do
				local mutationCache = MutationsData[mutation]
				if not mutationCache then
					print(mutation)
					return
				end
				
				local isEffect = mutationCache.IsEffect
				local newTemplate = MutationTemplate:Clone()
				newTemplate.Parent = not isEffect and newOverhead.List.Mutations or newOverhead.List.Effects
				newTemplate.Name = mutation
				newTemplate.Text = mutation
				local mutationCache = MutationsData[mutation]

				if mutationCache.Gradient then
					mutationCache.Gradient:Clone().Parent = newTemplate
				end
			end

			newOverhead.Size = UDim2.new(10.2, 0,3.4, 0)
		end
	end

	if Info.Mutations then
		-- mutations
		-- TO DO: when threads are setup, make it so mutations are only active when tool is out, and deactivates when put away

		-- Collect all IsEffect mutations first
		local effectMutations = {}

		for _, mutation in Info.Mutations do
			if MutationsData[mutation] and MutationsData[mutation].IsEffect then
				table.insert(effectMutations, mutation)
				ServerUtility.ClientMutate(mutation, getTool:FindFirstChildOfClass("Model"))
			end
		end

		-- Only set the attribute if there are effect mutations
		if #effectMutations > 0 then
			getTool:SetAttribute("Mutations", HttpService:JSONEncode(effectMutations))
		end

		for _, mutation in Info.Mutations do
			-- Skip if already processed as effect
			if MutationsData[mutation] and MutationsData[mutation].IsEffect then
				continue
			end

			getTool.Name = "["..mutation.."] [" .. roundNumber(Info.Weight,1) .. " kg] " .. Info.Name

			if MutationsData[mutation] then
				ServerUtility.ClientMutate(mutation, getTool:FindFirstChildOfClass("Model"))
			end
		end
	end
end

function plot:RemoveItem(Info)

end

-- [[ PLANT SYSTEM - Timestamp-based, client-side visuals ]] --

function plot:PlacePlant(UniqueID, RawPosition, ItemID)
	local PlayerReplica = Data[self.Owner]

	-- This is a new plant, create the position and timeplaced
	if RawPosition then
		local Origin = self.Folder.All.Farm1.Origin
		local Offset = RawPosition - Origin.Position
		local GetItemCache = self.OwnerData.Inventory[ItemID]
		local BufferedPosition = BitBuffer.Create()
		local BufferedTime = BitBuffer.Create()

		local BufferedRotation = BitBuffer.Create()
		BufferedRotation:WriteFloat32(math.random(-180, 180))

		BufferedPosition:WriteFloat32(Offset.X)
		BufferedPosition:WriteFloat32(Offset.Y)
		BufferedPosition:WriteFloat32(Offset.Z)
		BufferedTime:WriteFloat64(workspace:GetServerTimeNow())

		local Random = Random.new()
		local RandomScale = Random:NextNumber(0.75,1.4)

		if math.random(1,100) <= 3 then
			-- Lucky huge plant
			RandomScale = Random:NextNumber(1.5,2.2)

			UIRemote:FireClient(self.Owner, "TopNotification", {
				Text = "You just grew a HUGE plant!";
				["ShadowColor"] = Color3.fromRGB(235, 0, 180);
				["ShadowTransparency"] = 0.35;
			})
		end

		-- Get plant module for growth time
		local plantModule = PlantModules[GetItemCache.Name]
		local growthTime = plantModule and plantModule.GrowthTime or 60

		PlayerReplica:SetValue({"Plot", UniqueID}, {
			["Name"] = GetItemCache.Name;
			["OffsetPosition"] = BufferedPosition:ToBase64();
			["PlantTimestamp"] = BufferedTime:ToBase64(); -- When the plant was placed
			["GrowthDuration"] = growthTime; -- How long it takes to grow
			["RandomScale"] = RandomScale;
			["RandomRotation"] = BufferedRotation:ToBase64();
			-- NEW: Fruit data structure using timestamps
			["Fruits"] = {};
		})

		-- Remove tool
		for _, child in self.Owner.Character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ID") == ItemID then
				local quantity = child:GetAttribute("Quantity")
				local newQuantity = quantity - 1
				if newQuantity <= 0 then
					PlayerReplica:SetValue({"Inventory", ItemID}, nil)
					child:Destroy()
				else
					PlayerReplica:SetValue({"Inventory", ItemID, "Quantity"}, newQuantity)
					child:SetAttribute("Quantity", newQuantity)
				end
				break
			end
		end

		-- Fire to client to spawn plant visual
		local plantData = self.OwnerData.Plot[UniqueID]
		PlotRemote:FireClient(self.Owner, "SpawnPlant", UniqueID, plantData)
	end
end

function plot:RemovePlant(PlantID)
	local PlayerReplica = Data[self.Owner]
	
	-- Verify plant exists in data
	if not PlayerReplica.Data.Plot[PlantID] then
		return
	end

	-- Clean up ActiveFruit handlers for this plant
	local plantData = PlayerReplica.Data.Plot[PlantID]
	if plantData and plantData.Fruits then
		for fruitIndex, _ in pairs(plantData.Fruits) do
			local fruitKey = PlantID .. tostring(fruitIndex)
			if ServerUtility.ActiveFruit[fruitKey] then
				ServerUtility.ActiveFruit[fruitKey] = nil
			end
		end
	end

	-- Remove from data only
	PlayerReplica:SetValue({"Plot", PlantID}, nil)

	-- Fire to client to destroy visual
	PlotRemote:FireClient(self.Owner, "DestroyPlant", PlantID)
end

--[[
	NEW TIMESTAMP-BASED FRUIT SYSTEM
	Fruit lifecycle is managed via timestamps, not physical instances.
	Client renders fruit visuals based on server timestamps.
--]]

-- Initialize fruits for a fully grown plant (called when plant reaches 100% growth)
function plot:InitializePlantFruits(PlantID)
	local PlayerReplica = Data[self.Owner]
	local plantData = PlayerReplica.Data.Plot[PlantID]
	
	if not plantData then return end
	if not plantData.Fruits then 
		plantData.Fruits = {}
	end

	local plantModule = PlantModules[plantData.Name]
	if not plantModule then return end

	local productName = plantModule.ProductName
	if not productName then return end

	local playerLuck = self.Owner:GetAttribute("Luck") or 0
	local playerMutationLuck = self.Owner:GetAttribute("MutationLuck") or 0

	if plantModule.Type == "Single" then
		-- Single plants: one fruit at index "1"
		if not plantData.Fruits["1"] then
			local fruitData = ServerUtility.GenerateFruitData(productName, playerLuck, playerMutationLuck, plot.EventMultipliers)
			plantData.Fruits["1"] = fruitData
			PlayerReplica:SetValue({"Plot", PlantID, "Fruits", "1"}, fruitData)
		end

		-- Setup the fruit handler
		ServerUtility.SetupFruit(self.Owner, PlantID, "1", PlayerReplica, self, productName, plantModule)

	elseif plantModule.Type == "Spawner" then
		-- Spawner plants: need to know branch count from client
		-- For now, we'll initialize when client requests via remote
		-- Store the plant as needing fruit initialization
		if not self.PendingFruitInit then
			self.PendingFruitInit = {}
		end
		self.PendingFruitInit[PlantID] = true
	end

	-- Notify client
	PlotRemote:FireClient(self.Owner, "PlantReadyForFruits", PlantID)
end

-- Initialize fruits for a spawner plant (called by client when it knows branch count)
function plot:InitializeSpawnerFruits(PlantID, BranchCount)
	local PlayerReplica = Data[self.Owner]
	local plantData = PlayerReplica.Data.Plot[PlantID]
	
	if not plantData then return end

	local plantModule = PlantModules[plantData.Name]
	if not plantModule or plantModule.Type ~= "Spawner" then return end

	local productName = plantModule.ProductName
	local playerLuck = self.Owner:GetAttribute("Luck") or 0
	local playerMutationLuck = self.Owner:GetAttribute("MutationLuck") or 0

	-- Ensure Fruits table exists
	if not plantData.Fruits then
		plantData.Fruits = {}
	end

	-- Initialize each branch's fruit
	for i = 1, BranchCount do
		local index = tostring(i)
		if not plantData.Fruits[index] then
			local fruitData = ServerUtility.GenerateFruitData(productName, playerLuck, playerMutationLuck, plot.EventMultipliers)
			plantData.Fruits[index] = fruitData
			PlayerReplica:SetValue({"Plot", PlantID, "Fruits", index}, fruitData)
		end

		-- Setup the fruit handler
		ServerUtility.SetupFruit(self.Owner, PlantID, i, PlayerReplica, self, productName, plantModule)
	end

	-- Clear pending flag
	if self.PendingFruitInit then
		self.PendingFruitInit[PlantID] = nil
	end

	-- Send all fruit data to client
	local clientFruitData = {}
	for index, fruitData in pairs(plantData.Fruits) do
		clientFruitData[index] = ServerUtility.GetClientFruitData(fruitData)
	end

	PlotRemote:FireClient(self.Owner, "FruitDataSync", {
		PlantID = PlantID;
		Fruits = clientFruitData;
	})
end

-- Request harvest of a fruit (validated server-side)
function plot:RequestFruitHarvest(PlantID, FruitIndex)
	local PlayerReplica = Data[self.Owner]
	local plantData = PlayerReplica.Data.Plot[PlantID]
	
	if not plantData then
		return false, "Plant not found"
	end

	if not plantData.Fruits then
		return false, "No fruits data"
	end

	local fruitData = plantData.Fruits[tostring(FruitIndex)]
	if not fruitData then
		return false, "Fruit not found"
	end

	-- Server-side validation using FruitSystem
	local isReady = ServerUtility.IsFruitReady(fruitData)
	if not isReady then
		return false, "Fruit not ready"
	end

	-- Check if on cooldown (already harvested)
	if fruitData.HarvestedAt then
		local isOnCooldown = ServerUtility.IsFruitOnCooldown(fruitData)
		if isOnCooldown then
			return false, "Fruit on cooldown"
		end
	end

	-- Check inventory space
	local TotalInventorySize = 250
	if MarketplaceService:UserOwnsGamePassAsync(self.Owner.UserId, 1657482065) then 
		TotalInventorySize = 400 
	end

	local GetInventoryCount = 0
	for _ in pairs(PlayerReplica.Data.Inventory) do 
		GetInventoryCount += 1 
	end

	if GetInventoryCount >= TotalInventorySize then
		UIRemote:FireClient(self.Owner, "TopNotification", {
			Text = "Your inventory is full! ("..GetInventoryCount.."/"..TotalInventorySize..")";
			Duration = 3;
			["ShadowColor"] = Color3.fromRGB(241, 0, 0);
			["ShadowTransparency"] = 0.35;
		})
		return false, "Inventory full"
	end

	-- Process harvest
	local currentTime = workspace:GetServerTimeNow()
	fruitData.HarvestedAt = currentTime
	PlayerReplica:SetValue({"Plot", PlantID, "Fruits", tostring(FruitIndex), "HarvestedAt"}, currentTime)

	-- Give item to player
	local plantModule = PlantModules[plantData.Name]
	local productName = plantModule and plantModule.ProductName or "Unknown Fruit"
	
	self:GiveItem({
		ID = HttpService:GenerateGUID(false);
		Name = productName;
		Weight = fruitData.Weight;
		Mutations = fruitData.Mutations;
	})

	-- Play sound effect
	FXRemote:FireClient(self.Owner, "Replicate", {
		["Call"] = "Sound";
		["Sound"] = Replicated.Game.Sounds.GameSounds.pickup;
	})

	-- Schedule respawn
	local respawnDelay = fruitData.RespawnTime or 17
	task.delay(respawnDelay, function()
		self:RespawnFruit(PlantID, FruitIndex)
	end)

	-- Notify client
	PlotRemote:FireClient(self.Owner, "FruitHarvested", {
		PlantID = PlantID;
		FruitIndex = FruitIndex;
		HarvestedAt = currentTime;
		RespawnTime = respawnDelay;
	})

	return true
end

-- Respawn a fruit after cooldown
function plot:RespawnFruit(PlantID, FruitIndex)
	local PlayerReplica = Data[self.Owner]
	local plantData = PlayerReplica.Data.Plot[PlantID]
	
	if not plantData or not plantData.Fruits then return end

	local plantModule = PlantModules[plantData.Name]
	if not plantModule then return end

	local productName = plantModule.ProductName
	local playerLuck = self.Owner:GetAttribute("Luck") or 0
	local playerMutationLuck = self.Owner:GetAttribute("MutationLuck") or 0

	-- Generate new fruit data
	local newFruitData = ServerUtility.GenerateFruitData(productName, playerLuck, playerMutationLuck, plot.EventMultipliers)
	plantData.Fruits[tostring(FruitIndex)] = newFruitData

	-- Update replica
	PlayerReplica:SetValue({"Plot", PlantID, "Fruits", tostring(FruitIndex)}, newFruitData)

	-- Notify client
	PlotRemote:FireClient(self.Owner, "FruitRespawned", {
		PlantID = PlantID;
		FruitIndex = FruitIndex;
		FruitData = ServerUtility.GetClientFruitData(newFruitData);
	})
end

-- Toggle favorite status for a fruit
function plot:ToggleFruitFavorite(PlantID, FruitIndex)
	local PlayerReplica = Data[self.Owner]
	local plantData = PlayerReplica.Data.Plot[PlantID]
	
	if not plantData or not plantData.Fruits then return end

	local fruitData = plantData.Fruits[tostring(FruitIndex)]
	if not fruitData then return end

	fruitData.Favorited = not fruitData.Favorited
	PlayerReplica:SetValue({"Plot", PlantID, "Fruits", tostring(FruitIndex), "Favorited"}, fruitData.Favorited)

	local plantModule = PlantModules[plantData.Name]
	local productName = plantModule and plantModule.ProductName or "Unknown Fruit"

	UIRemote:FireClient(self.Owner, "TopNotification", {
		Text = productName .. " was " .. (fruitData.Favorited and "favorited" or "unfavorited") .. "!";
		Duration = 3;
		["ShadowColor"] = Color3.fromRGB(63, 63, 63);
		["ShadowTransparency"] = 0.35;
	})

	-- Notify client
	PlotRemote:FireClient(self.Owner, "FruitFavoriteToggled", {
		PlantID = PlantID;
		FruitIndex = FruitIndex;
		Favorited = fruitData.Favorited;
	})

	return fruitData.Favorited
end

-- Legacy function: HarvestPlant (redirects to new system)
function plot:HarvestPlant(PlantID, FruitIndex)
	return self:RequestFruitHarvest(PlantID, FruitIndex)
end

-- [[ GEAR SYSTEM ]] --

function plot:PlaceGear(UniqueID, RawPosition, ItemID)
	local PlayerReplica = Data[self.Owner]

	if RawPosition then
		local Origin = self.Folder.All.Farm1.Origin
		local Offset = RawPosition - Origin.Position
		local GetItemCache = self.OwnerData.Inventory[ItemID]
		local BufferedPosition = BitBuffer.Create()
		BufferedPosition:WriteFloat32(Offset.X)
		BufferedPosition:WriteFloat32(Offset.Y)
		BufferedPosition:WriteFloat32(Offset.Z)

		local gearSetupData = {
			["Name"] = GetItemCache.Name;
			["OffsetPosition"] = BufferedPosition:ToBase64();
		}

		local gearData = GearsData[GetItemCache.Name]
		if gearData and gearData.PlaceableData and gearData.PlaceableData.Duration then
			local TimeBuffer = BitBuffer.Create()
			TimeBuffer:WriteFloat64(workspace:GetServerTimeNow())
			gearSetupData["ActivatedTime"] = TimeBuffer:ToBase64()
		end

		PlayerReplica:SetValue({"PlotGears", UniqueID}, gearSetupData)

		-- Remove tool
		for _, child in self.Owner.Character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ID") == ItemID then
				local quantity = child:GetAttribute("Quantity")
				local newQuantity = quantity - 1
				if newQuantity <= 0 then
					PlayerReplica:SetValue({"Inventory", ItemID}, nil)
					child:Destroy()
				else
					PlayerReplica:SetValue({"Inventory", ItemID, "Quantity"}, newQuantity)
					child:SetAttribute("Quantity", newQuantity)
				end
				break
			end
		end
	end

	-- Get the data for the gear
	local GetGearInData = self.OwnerData.PlotGears[tostring(UniqueID)]
	if not GetGearInData then
		warn("No gear data found for:", UniqueID)
		return
	end

	local gearData = GearsData[GetGearInData.Name]
	if not gearData then
		warn("No gear data found for:", GetGearInData.Name)
		return
	end

	-- Decode position
	local OriginPart = self.Folder.All.Farm1.Origin
	local PositionBuffer = BitBuffer.Create()
	PositionBuffer:FromBase64(GetGearInData.OffsetPosition)
	local x = PositionBuffer:ReadFloat32()
	local y = PositionBuffer:ReadFloat32()
	local z = PositionBuffer:ReadFloat32()
	local OffsetPosition = Vector3.new(x, y, z)
	local ActualPosition = OriginPart.Position + OffsetPosition

	-- Create model
	local GetNewGearModel = Replicated.Game.Models.Gears:FindFirstChild(GetGearInData.Name):Clone()
	GetNewGearModel.Name = UniqueID
	
	for _,children in GetNewGearModel:GetDescendants() do
		if children:IsA("ParticleEmitter") then
			children.Enabled = true
		end
	end
	
	local RootPart = GetNewGearModel.PrimaryPart
	local real = (RootPart.Size.Y / 2) + (gearData.ManualOffset or 0)
	ActualPosition = ActualPosition + Vector3.new(0, real, 0)
	local originalCFrame = GetNewGearModel:GetPivot()
	local originalRotation = originalCFrame - originalCFrame.Position
	GetNewGearModel.Parent = self.Folder.Gears
	GetNewGearModel:PivotTo(CFrame.new(ActualPosition) * originalRotation)
	GetNewGearModel:SetAttribute("ID", UniqueID)
	GetNewGearModel:SetAttribute("Owner", self.Owner.Name)

	self.Objects[UniqueID] = GetNewGearModel

	-- Handle sprinkler-specific functionality
	if gearData.PlaceableData and gearData.PlaceableData.Duration then
		-- This is a sprinkler - trigger VFX and setup removal
		SprinklerSystem:OnSprinklerPlaced(self, UniqueID, GetNewGearModel, GetGearInData.Name)
	end

	-- Schedule destruction for temporary gears (legacy cleanup, sprinklers handled by SprinklerSystem)
	if gearData.PlaceableData and gearData.PlaceableData.Duration and GetGearInData.ActivatedTime then
		local TimeBuffer = BitBuffer.Create()
		TimeBuffer:FromBase64(GetGearInData.ActivatedTime)
		local activatedTime = TimeBuffer:ReadFloat64()
		local endTime = activatedTime + gearData.PlaceableData.Duration
		local timeRemaining = endTime - workspace:GetServerTimeNow()

		if timeRemaining <= 0 then
			-- Already expired
			SprinklerSystem:OnSprinklerExpired(self, UniqueID)
		end
	end
end

--[[
	Get sprinkler growth boost multiplier for a position
	Returns: multiplier (number)
]]
function plot:GetSprinklerMultiplier(position)
	return SprinklerSystem:GetGrowthBoost(self, position)
end

-- Helper function to calculate total CPS
function plot:UpdatePlayerCPS()
	local totalCPS = 0
	for _, brainrotData in pairs(self.Brainrots) do
		local cps = Calculator.CalculateMoneyPerSecond(
			brainrotData.Name,
			brainrotData.Weight,
			brainrotData.Mutations,self.Owner:GetAttribute("Rebirths")
		)
		totalCPS = totalCPS + cps
	end
	self.Owner:SetAttribute("CPS", totalCPS)
end

local zones = {}

for _, plotFolder in workspace.Plots:GetChildren() do
	if plotFolder:IsA("Folder") then
		zones[tostring(plotFolder.Name)] = {}

		for _, platform in plotFolder.Platforms:GetChildren() do
			if platform:IsA("Model") and not string.find(platform.Name, "Button") then
				local zonePart = Instance.new("Part")
				zonePart.CFrame = platform.Place.CFrame * CFrame.new(0, 5, 0)
				zonePart.Size = Vector3.new(7, 10, 7)
				zonePart.CanCollide = false
				zonePart.Anchored = true
				zonePart.Transparency = 1
				zonePart.Parent = workspace.Visuals

				zones[tostring(plotFolder.Name)][platform.Name] = {
					["Zone"] = Zone.new(zonePart);
					["Callback"] = nil;
				}

				local cache = zones[tostring(plotFolder.Name)][tostring(platform.Name)]

				cache.Zone.playerEntered:Connect(function(playerWhoEntered)
					if cache.Callback ~= nil then
						cache.Callback(playerWhoEntered)
					end
				end)
			end
		end
	end
end

function plot:PlaceBrainrot(BrainrotID, Slot, tool) -- places a brainrot on one of the stands
	local brainrotCache = self.OwnerData.Inventory[BrainrotID] or self.OwnerData.Brainrots[BrainrotID] -- could be inv or brainrots, if they are placing or plot force placing
	local platform = Slot
	local name = brainrotCache.Name
	local weight = brainrotCache.Weight
	local mutations = brainrotCache.Mutations
	local money
	local lastLeave = self.OwnerData.LastLeave

	if Models:FindFirstChild(name) then -- model
		self.Folder.Platforms[platform]:SetAttribute("Occupied", true)

		local placePlatform = self.Folder.Platforms[platform].Place
		if placePlatform:FindFirstChild("PROMPT"..platform..self.PlotNumber) then
			placePlatform:FindFirstChild("PROMPT"..platform..self.PlotNumber).Enabled = false
		end

		-- data
		local PlayerReplica = Data[self.Owner]
		local OfflineMoneyEarned = 0

		if not self.OwnerData.Brainrots[BrainrotID] then
			PlayerReplica:SetValue({"Brainrots", BrainrotID}, {
				["Position"] = Slot;
				["Mutations"] = mutations or {};
				["Weight"] = weight or {};
				["Name"] = name;
				["Money"] = 0;
				["OfflineMoney"] = 0;
			})
			money = 0

			-- remove from inventory
			PlayerReplica:SetValue({"Inventory", BrainrotID}, nil)

			-- remove tool
			if tool then
				tool:Destroy()
			end
		else
			-- set table money
			money = PlayerReplica.Data.Brainrots[BrainrotID].Money

			-- give offline money + set offline table money
			local offlinePerSecond = Calculator.CalculateMoneyPerSecond(name,weight,mutations,self.Owner:GetAttribute("Rebirths"))
			local timeOffline = self.Owner:GetAttribute("JoinTick") - PlayerReplica.Data.LastLeave
			local prevOfflineMoney = PlayerReplica.Data.Brainrots[BrainrotID].OfflineMoney
			local offlineMulti = 0.10
			local totalOfflineMoney = prevOfflineMoney + (offlinePerSecond * timeOffline * offlineMulti)

			OfflineMoneyEarned = totalOfflineMoney
			PlayerReplica:SetValue({"Brainrots", BrainrotID, "OfflineMoney"}, totalOfflineMoney)
		end

		-- change proximity prompt to remove brainrot
		local newProximityPrompt = Instance.new("ProximityPrompt", self.Folder.Platforms[platform].Place)
		newProximityPrompt.Name = "PROMPT2"..platform..self.PlotNumber
		newProximityPrompt.ActionText = "Pickup Brainrot"
		newProximityPrompt:SetAttribute("PromptText", "Pickup")
		newProximityPrompt:SetAttribute("BoldText", "Brainrot")
		newProximityPrompt.RequiresLineOfSight = false
		newProximityPrompt:SetAttribute("Offset", Vector3.new(0,5,0))

		self.Functions[newProximityPrompt.Name] = function(playerWhoTriggered)
			if playerWhoTriggered == self.Owner then
				self:RemoveBrainrot(BrainrotID)
			end
		end

		self.Connections["PlatformRemove"..platform] = newProximityPrompt.Triggered:Connect(function(playerWhoTriggered)
			self.Functions[newProximityPrompt.Name](playerWhoTriggered)
		end)

		-- Calculate MPS for this brainrot
		local calculatedMPS = Calculator.CalculateMoneyPerSecond(name, weight, mutations, self.Owner:GetAttribute("Rebirths"))

		local Multi = 1.5
		if self.OwnerData.Rebirths >= 3 then
			Multi = 2						
		end
		if brainrotTable.Platform == "Super" then
			calculatedMPS *= Multi
		end

		self.Brainrots[BrainrotID] = {
			["ID"] = BrainrotID;
			["Platform"] = platform;
			["Money"] = money;
			["OfflineMoney"] = OfflineMoneyEarned;
			["Name"] = name;
			["Weight"] = weight;
			["Mutations"] = mutations;
			["MPS"] = calculatedMPS;
		}
		
		print(calculatedMPS)

		-- Update total CPS after adding brainrot
		self:UpdatePlayerCPS()

		-- touch to collect
		local cd = 1
		local db = false

		zones[tostring(self.PlotNumber)][tostring(platform)].Callback = function(player)
			-- Only allow plot owner to claim money
			if player ~= self.Owner then return end

			task.spawn(function()
				db = true
				task.wait(cd)
				db = false
			end)

			-- fx
			FXRemote:FireAllClients("Replicate", {["Call"] = "ClaimMoney"; ["Position"] = self.Folder.Platforms[platform].Place.CFrame * CFrame.new(0,5,0)})
			FXRemote:FireClient(self.Owner,"Replicate", {["Call"] = "Sound",["Sound"] = Replicated.Game.Sounds.GameSounds.kaching,["norandom"] = true})

			-- give money & update cache
			local brainCache = self.Brainrots[BrainrotID]
			local moneyToGive = self.Brainrots[BrainrotID].Money + self.Brainrots[BrainrotID].OfflineMoney
			local CurrentCash = PlayerReplica.Data.Cash
			self:GiveCash(moneyToGive)

			local getHighestCash = PlayerReplica.Data.Stats.MostCash

			if PlayerReplica.Data.Cash > getHighestCash then
				PlayerReplica:SetValue({"Stats", "MostCash"}, PlayerReplica.Data.Cash)
				Leaderboards.UpdatePlayerStat(self.Owner.UserId, "Cash", math.floor(PlayerReplica.Data.Cash))
			end

			-- set to 0
			PlayerReplica:SetValue({"Brainrots", BrainrotID, "OfflineMoney"}, 0)
			self.Brainrots[BrainrotID].Money = 0
			self.Brainrots[BrainrotID].OfflineMoney = 0

			-- update --
			SpawnRemote:FireAllClients("UpdateOverhead", {["ID"] = brainCache.ID; ["MPS"] = brainCache.MPS; ["Platform"] = brainCache.Platform; ["Money"] = 0; ["Plot"] = self.PlotNumber})
		end

		ServerUtility.ClientSpawnPlatformBrainrot(BrainrotID, self.Brainrots[BrainrotID], self.PlotNumber, self.Owner)
	end
end

function plot:RemoveBrainrot(BrainrotID) -- removes brainrot on one of the stands
	local Cache = self.Brainrots[BrainrotID]
	local PlayerReplica = Data[self.Owner]
	local BrainrotData = PlayerReplica.Data.Brainrots[BrainrotID]

	local getPlatform = self.Folder.Platforms[Cache.Platform].Place
	if getPlatform:FindFirstChild("PROMPT"..Cache.Platform..self.PlotNumber) then
		getPlatform:FindFirstChild("PROMPT"..Cache.Platform..self.PlotNumber).Enabled = true
	end
	if getPlatform:FindFirstChild("PROMPT2"..Cache.Platform..self.PlotNumber) then
		getPlatform:FindFirstChild("PROMPT2"..Cache.Platform..self.PlotNumber):Destroy()
	end

	self.Folder.Platforms[Cache.Platform]:SetAttribute("Occupied", false)

	-- give all the money inside of the brainrot + offline money
	local CurrentCash = PlayerReplica.Data.Cash
	local BrainrotMoney = BrainrotData.Money
	local BrainrotOfflineMoney = BrainrotData.OfflineMoney
	self:GiveCash(BrainrotMoney + BrainrotOfflineMoney)

	ServerUtility.HandleDestroy({
		["Plot"] = self.PlotNumber;
		["ID"] = BrainrotID;
	})

	zones[tostring(self.PlotNumber)][tostring(Cache.Platform)].Callback = nil

	-- add brainrot to tools inventory
	-- add brainrot to inventory data table
	local newData = BrainrotData;
	BrainrotData["ID"] = BrainrotID
	self:GiveItem(newData)

	-- remove brainrot from Brainrots data table
	PlayerReplica:SetValue({"Brainrots", BrainrotID}, nil)
	self.Brainrots[BrainrotID] = nil

	SpawnRemote:FireAllClients("DeleteBrainrot", {
		["ID"] = BrainrotID;
		["Platform"] = true;
		["Plot"] = self.PlotNumber;
	})

	-- Update total CPS after removing brainrot
	self:UpdatePlayerCPS()
end

plot.CurrentCount = 0

local FadeTime = 1.5
local StopFadeTime = 1.5

-- Customer/Order System --
function plot:ReachedDesk(BrainrotID, CurrentCFrame)
	local newcache = self.Active[BrainrotID]
	local FinalPosition = self.Folder.Path[self.Active[BrainrotID].Path].Position
	local updatedFinal = Vector3.new(FinalPosition.X, CurrentCFrame.Position.Y, FinalPosition.Z)

	local magnitude = (updatedFinal - CurrentCFrame.Position).Magnitude

	if magnitude <= 2 then
		local Rarity = Models[self.Active[BrainrotID].Name]:GetAttribute("Rarity")

		if self.OwnerData.Settings.AutoSell[Rarity] then
			self:DestroyBrainrot(BrainrotID, self.Active[BrainrotID].Path, self.Active[BrainrotID].Index)
			return
		end

		local ThinkTime = 1
		local BrainrotLibraryData = BrainrotData[self.Active[BrainrotID].Name]
		local RotCache = self.Active[BrainrotID]

		OrderRemote:FireAllClients("Thinking", {
			["ID"] = BrainrotID;
			["Path"] = RotCache.Path;
			["Plot"] = self.PlotNumber;
		})

		self.CurrentCustomer[self.Active[BrainrotID].Path] = {["ID"] = BrainrotID; ["Index"] = self.Active[BrainrotID].Index; ["Path"] = self.Active[BrainrotID].Path}

		task.delay(ThinkTime, function()
			if not self.Active[BrainrotID] then
				return
			end

			local FinalizedOrderArray = {}

			OrderRemote:FireAllClients("CreateOrderUI", {
				["ID"] = BrainrotID;
				["Path"] = RotCache.Path;
				["Plot"] = self.PlotNumber;
			})

			local OrderTime = 15

			if BrainrotLibraryData.CustomOrder then
				local finalList = {}

				for item, bounds in BrainrotLibraryData.CustomOrder do
					finalList[item] = math.random(bounds[1], bounds[2])

					OrderRemote:FireAllClients("AddOrder", {
						["ID"] = BrainrotID;
						["Item"] = {Name = item,Amount = finalList[item]},
						["Path"] = RotCache.Path;
						["Plot"] = self.PlotNumber;
					})
				end

				FinalizedOrderArray = finalList
			else
			local maxItems = {
				["Rare"] = 1;
				["Epic"] = 2;
				["Legendary"] = 2;
				["Mythic"] = 3;
				["Godly"] = 4;
				["Secret"] = 4;
			}

				local rarityTiers = {"Rare", "Epic", "Legendary", "Mythic", "Godly", "Secret"}
				local lowerTierChance = {
					["Rare"] = 0;
					["Epic"] = 60;
					["Legendary"] = 35;
					["Mythic"] = 50;
					["Godly"] = 50;
					["Secret"] = 50;
				}

				if not self.Active[BrainrotID] then
					OrderRemote:FireAllClients("Cleanup", {
						["ID"] = BrainrotID;
						["Plot"] = self.PlotNumber;
					})
					return
				end

				local brainrotRarity = Models[self.Active[BrainrotID].Name]:GetAttribute("Rarity")

				local requestRarities = {brainrotRarity}

				if math.random(1, 100) <= lowerTierChance[brainrotRarity] then
					local currentTierIndex = table.find(rarityTiers, brainrotRarity)
					if currentTierIndex and currentTierIndex > 1 then
						table.insert(requestRarities, rarityTiers[currentTierIndex - 1])
					end
				end

				local FruitsOfRarity = {}
				for i,v in ItemsData do
					if v.Type == "Fruit" and table.find(requestRarities, v.Rarity) then
						table.insert(FruitsOfRarity,i)
					end
				end

				local NumberOfItems = math.random(1, maxItems[brainrotRarity])
				local NumberOfIndividualItems = math.random(1, math.min(#FruitsOfRarity, NumberOfItems))
				local CountPerItem = math.floor(NumberOfItems/NumberOfIndividualItems)

				for i = 1, NumberOfIndividualItems do
					local pickItem = FruitsOfRarity[math.random(1, #FruitsOfRarity)]
					FinalizedOrderArray[pickItem] = CountPerItem
					OrderRemote:FireAllClients("AddOrder", {
						["ID"] = BrainrotID;
						["Item"] = {Name = pickItem,Amount = CountPerItem},
						["Path"] = RotCache.Path;
						["Plot"] = self.PlotNumber;
					})
					table.remove(FruitsOfRarity, table.find(FruitsOfRarity, pickItem))
				end
			end

			for Item, Amount in FinalizedOrderArray do
				OrderTime += (Amount * 2.5)
			end

			OrderRemote:FireAllClients("OrderVisible", {
				["ID"] = BrainrotID;
				["Path"] = RotCache.Path;
				["Plot"] = self.PlotNumber;
				["Time"] = OrderTime;
			})

			local rarityToDifficulty = {["Rare"] = 1; ["Epic"] = 1; ["Legendary"] = 2; ["Mythic"] = 3; ["Godly"] = 4; ["Secret"] = 5}
			local OrderDifficulty = rarityToDifficulty[Models:FindFirstChild(newcache.Name)]
			local OrderParts = 1
			local OrderIndex = BrainrotID

			if not self.Active[BrainrotID] then
				OrderRemote:FireAllClients("Cleanup", {
					["ID"] = BrainrotID;
					["Plot"] = self.PlotNumber;
				})
				return
			end

			self.Orders[OrderIndex] = {
				Requirements = FinalizedOrderArray;
				Currents = {};
				Mutations = {};
				Weight = 1.1;
				TimeRemaining = OrderTime;
				MaxTime = OrderTime;
			};

			self.CurrentOrder[self.Active[BrainrotID].Path] = {
				Brainrot = RotCache.Name;
				["BrainrotID"] = BrainrotID;
				Cache = self.Orders[OrderIndex];
				Index = RotCache.Index;
				Weight = RotCache.Weight;
				Mutations = RotCache.Mutations;
			}

			local function IsOrderComplete(orderCache) 
				for fruitName, requiredAmount in pairs(orderCache.Requirements) do
					local currentAmount = orderCache.Currents[fruitName] and #orderCache.Currents[fruitName] or 0
					if currentAmount < requiredAmount then
						return false
					end
				end
				return true
			end

			self.Functions[BrainrotID] = function(plr, itemID)
				local tempPlot
				for _, p in plot.Plots do if p.Owner == plr then tempPlot = p end end
				if not tempPlot then return end

				local orderCache = self.Orders[OrderIndex]
				local holdingItemData = tempPlot.OwnerData.Inventory[itemID]

				if not holdingItemData then
					return
				end

				local isOrderComplete = IsOrderComplete(orderCache)
				if isOrderComplete then
					return
				end

				if holdingItemData.Favorited then
					UIRemote:FireClient(plr, "TopNotification", {
						Text = "You cannot give a favorited fruit to a brainrot!";
						["ShadowColor"] = Color3.fromRGB(255, 0, 4);
						["ShadowTransparency"] = 0.35;
					})
					return
				end

				local itemName = holdingItemData.Name
				if not orderCache.Requirements[itemName] then
					return
				end

				local currentAmount = orderCache.Currents[itemName] and #orderCache.Currents[itemName] or 0
				local requiredAmount = orderCache.Requirements[itemName]

				if currentAmount >= requiredAmount then
					return
				end

				local givenFruitName = itemName

				if not orderCache.Currents[itemName] then
					orderCache.Currents[itemName] = {}
				end
				table.insert(orderCache.Currents[itemName], itemID)

				local brainrotstuff = self.Active[BrainrotID]

				if holdingItemData.Mutations then
					for index, Mutation in holdingItemData.Mutations do
						if table.find(brainrotstuff.Mutations, Mutation) then
							continue
						end

						local checkMutation = MutationsData[Mutation]
						if checkMutation.IsEffect then
							local effectCount = 0
							for _, existingMutation in brainrotstuff.Mutations do
								if MutationsData[existingMutation].IsEffect then
									effectCount += 1
								end
							end

							if effectCount < 6 then
								table.insert(brainrotstuff.Mutations, Mutation)
							end
						end
					end
				end

				local rawWeight = holdingItemData.Weight or 0
				local mutation = "Normal"

				if holdingItemData.Mutations then
					for index, Mutation in holdingItemData.Mutations do
						local mutationData = MutationsData[Mutation]
						if mutationData and not mutationData.IsEffect then
							mutation = Mutation
							break
						end
					end
				end

				local MutationBonuses = {
					["Normal"] = {
						TargetLarge = 1.2,
						Midpoint = 5
					},

					["Gold"] = {
						TargetLarge = 1.5,
						Midpoint = 6
					},

					["Petrified"] = {
						TargetLarge = 1.35,
						Midpoint = 5.5
					},

					["Emerald"] = {
						TargetLarge = 2.0,
						Midpoint = 9
					},

					["Diamond"] = {
						TargetLarge = 2.3,
						Midpoint = 10
					},

					["Rainbow"] = {
						TargetLarge = 3.0,
						Midpoint = 12
					}
				}

				local function CalculateWeightGain(fruitWeight, mutation)
					local targetSmall = 0.25
					local bonusData = MutationBonuses[mutation or "Normal"]

					if not bonusData then
						bonusData = MutationBonuses["Normal"]
					end

					local targetLarge = bonusData.TargetLarge
					local midpoint = bonusData.Midpoint

					local normalized = fruitWeight / midpoint
					local scaleFactor = math.log(1 + normalized * 9) / math.log(10)
					return targetSmall + (scaleFactor * (targetLarge - targetSmall))
				end

				local weightGain = CalculateWeightGain(rawWeight, mutation)
				self.Active[BrainrotID].Weight += weightGain

				-- Add 5 seconds to timer (capped at max)
				orderCache.TimeRemaining = math.min(orderCache.TimeRemaining + 5, orderCache.MaxTime)

				self.CurrentOrder[self.Active[BrainrotID].Path] = {
					Brainrot = brainrotstuff.Name;
					["BrainrotID"] = BrainrotID;
					Cache = self.Orders[OrderIndex];
					Index = RotCache.Index;
					Weight = brainrotstuff.Weight;
					Mutations = brainrotstuff.Mutations;
				}

				OrderRemote:FireAllClients("UpdateOrder", {
					["ID"] = BrainrotID;

					["Info"] = {
						Weight = brainrotstuff.Weight,
						Name = brainrotstuff.Name,
						Mutations = #holdingItemData.Mutations > 0 and brainrotstuff.Mutations or nil;
						allMutations = brainrotstuff.Mutations;
						Item = itemName,
						Current = #orderCache.Currents[itemName],
						TimeRemaining = orderCache.TimeRemaining,
						["Path"] = RotCache.Path,
						["Owner"] = self.Owner,
					},
					["Plot"] = self.PlotNumber;
				})

				local recoveryBasketID = nil
				for itemID, itemData in pairs(tempPlot.OwnerData.Inventory) do
					if itemData.Name == "Recovery Basket" then
						recoveryBasketID = itemID
						break
					end
				end

				local shouldSaveFruit = recoveryBasketID and math.random(1, 100) <= 40
				if shouldSaveFruit then
					local basketData = tempPlot.OwnerData.Inventory[recoveryBasketID]
					local newQuantity = basketData.Quantity - 1
					if newQuantity <= 0 then
						tempPlot.OwnerReplica:SetValue({"Inventory", recoveryBasketID}, nil)
					else
						tempPlot.OwnerReplica:SetValue({"Inventory", recoveryBasketID, "Quantity"}, newQuantity)
					end

					for _, child in tempPlot.Owner.Character:GetChildren() do
						if child:IsA("Tool") and child:GetAttribute("ID") == recoveryBasketID then
							if newQuantity <= 0 then
								child:Destroy()
							else
								child:SetAttribute("Quantity", newQuantity)
							end
							break
						end
					end
					for _, child in tempPlot.Owner.Backpack:GetChildren() do
						if child:IsA("Tool") and child:GetAttribute("ID") == recoveryBasketID then
							if newQuantity <= 0 then
								child:Destroy()
							else
								child:SetAttribute("Quantity", newQuantity)
							end
							break
						end
					end

					UIRemote:FireClient(plr, "TopNotification", {
						Text = "Recovery Basket used! You have kept your fruit";
						["ShadowColor"] = Color3.fromRGB(160, 7, 255);
						["ShadowTransparency"] = 0.35;
					})
				else
					tempPlot.OwnerReplica:SetValue({"Inventory", itemID}, nil)
					tempPlot:DestroyToolByID(itemID)
				end

				isOrderComplete = IsOrderComplete(orderCache)
			end

			-- Heartbeat timer system
			local timerConnection
			timerConnection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
				if not self.Active[BrainrotID] or not self.Orders[OrderIndex] then
					if timerConnection then
						timerConnection:Disconnect()
					end
					return
				end

				local orderCache = self.Orders[OrderIndex]
				orderCache.TimeRemaining -= deltaTime

				if orderCache.TimeRemaining <= 0 then
					timerConnection:Disconnect()

					if IsOrderComplete(orderCache) then
						self.Functions["CompleteOrder"](RotCache.Path, true)
					else
						self:DestroyBrainrot(BrainrotID, RotCache.Path, OrderIndex, nil, true)
					end
				end
			end)

			self.Connections[BrainrotID.."Timer"] = timerConnection
		end)
	end
end

function plot:DestroyToolByID(itemID)
	for _, child in self.Owner.Backpack:GetChildren() do
		if child:GetAttribute("ID") == itemID then
			child:Destroy()
		end
	end

	for _, child in self.Owner.Character:GetChildren() do
		if child:GetAttribute("ID") == itemID then
			child:Destroy()
		end
	end
end

local OffsetPerBrainrot = 2.5 -- padding aside from bounding box --

plot.EventMultipliers = {}

function plot:SpawnBrainrot(BrainrotID, Specifications)
	-- variables / shortcuts --
	local ID = BrainrotID
	local BrainrotName = Specifications.Name
	local TargetPath = Specifications.Path
	local Mutations = Specifications.Mutations or {}
	local BrainrotLibraryData = BrainrotData[BrainrotName]

	-- check for mutation --
	local mutationLuck = self.Owner:GetAttribute("MutationLuck") or 0
	local totalLuck = self.Owner:GetAttribute("Luck") or 0 



	local GetMutation = PickMutations.PickMutation(mutationLuck+totalLuck, plot.EventMultipliers)
	if GetMutation ~= nil then table.insert(Mutations, GetMutation) end

	-- max line count --
	local MaxPerLine = 6
	self.Lines[TargetPath] = self.Lines[TargetPath] or {}

	if #self.Lines[TargetPath] >= MaxPerLine then
		if not Specifications.Bypass then
			return
		end
	end

	-- line --
	plot.CurrentCount += 1
	local newIndex = #self.Lines[TargetPath] + 1
	table.insert(self.Lines[TargetPath], ID)

	local Weight = Specifications.Weight or PickScale.RandomizeWeight(BrainrotLibraryData.WeightPool, self.Owner:GetAttribute("SizeLuck"))

	local WeightPool = BrainrotLibraryData.WeightPool
	local Scale = Calculator.CalculateScaleFromWeight(Weight,WeightPool,Models[BrainrotName])
	local positionOffset = (BrainrotLibraryData.YOffset or 0.5) * Scale
	local SpawnPosition = self.Folder.Path.Spawn.CFrame * CFrame.new(math.random(-10, 10), positionOffset, math.random(-10, 10))
	local TargetCFrame =  self.Folder.Path[TargetPath].CFrame * CFrame.new(0, positionOffset, (newIndex - 1) * OffsetPerBrainrot)

	self.Active[ID] = {
		["Name"] = BrainrotName;
		["ID"] = ID;
		["Position"] = SpawnPosition;
		["Target"] = TargetCFrame;
		["Weight"] = Weight;
		["Mutations"] = Mutations;
		["Index"] = newIndex;
		["Path"] = TargetPath;
		["TestReached"] = false;
		["Owner"] = self.Owner;
		["Mover"] = LerPmover.new(SpawnPosition, 6, BrainrotName, self.Owner);
	}

	local getRot = self.Active[ID]

	local RotInFront = self.Lines[getRot.Path][newIndex - 1]

	if RotInFront then
		local frontCache = self.Active[RotInFront]

		local WeightPool = BrainrotData[frontCache.Name].WeightPool
		local frontScale = Calculator.CalculateScaleFromWeight(frontCache.Weight,WeightPool,Models[frontCache.Name])
		local frontBBox = ServerUtility.GetExactBoundingBox(Models[frontCache.Name]).Size
		local currentBBox = ServerUtility.GetExactBoundingBox(Models[BrainrotName]).Size
		local sizeAdjustment = (frontBBox.Z * frontScale / 2) + (currentBBox.Z * Scale / 2) + OffsetPerBrainrot
		local frontY = frontCache.Target.Y
		local currentY = (self.Folder.Path[getRot.Path].CFrame * CFrame.new(0, positionOffset, 0)).Y

		TargetCFrame = frontCache.Target * CFrame.new(0, currentY - frontY, sizeAdjustment)
		getRot.Target = TargetCFrame
	else
		local Base = self.Folder.Path[getRot.Path].CFrame * CFrame.new(0, positionOffset, 0)
		TargetCFrame = Base
		getRot.Target = TargetCFrame
	end

	-- Spawn the brainrot (client visual)
	ServerUtility.ClientSpawnCustomerBrainrot(ID, self.Active[ID], self.PlotNumber)

	-- Server-side movement (cache only)
	local function onMove(newPos)
		self.Active[ID].Position = newPos
	end

	local function onReach(finalPos)
		self.Active[ID].Position = finalPos
		self.Active[ID].TestReached = true
		self:ReachedDesk(ID, finalPos)
	end

	self.Active[ID].Mover:MoveTo(TargetCFrame, onMove, onReach)
end

function plot:DestroyBrainrot(BrainrotID, Line, LinePosition, passed,Orderfailed)
	-- cancel order --

	if not self.Active[BrainrotID] then
		return
	end

	if self.Orders[BrainrotID] then
		if self.Orders[BrainrotID].Delay then
			task.cancel(self.Orders[BrainrotID].Delay)
		end

		self.Orders[BrainrotID] = nil
	end
	local lineTable = self.Lines[Line]
	if not lineTable then return end
	-- remove from line --
	for i, id in ipairs(lineTable) do
		if id == BrainrotID then
			table.remove(lineTable, i)
			break
		end
	end

	-- Remove all scales, mutates, etc. from utility replicator. --
	ServerUtility.HandleDestroy({
		["Plot"] = self.PlotNumber;
		["ID"] = BrainrotID;
	})

	-- delete client visual
	SpawnRemote:FireAllClients("DeleteBrainrot", {
		["ID"] = BrainrotID;
		["Path"] = self.Active[BrainrotID].Path;
		["Fulfilled"] = passed and true or false;
		["Owner"] = self.Owner;
		["Plot"] = self.PlotNumber;
		["Orderfailed"] = Orderfailed or nil
	})

	local getPrompt = self.Folder.Desks["Desk"..self.Active[BrainrotID].Path]:FindFirstChild(BrainrotID)
	if getPrompt then getPrompt:Destroy() end
	-- move every other rot up the line
	task.spawn(function()
		for index, rotID in ipairs(lineTable) do
			local getRot = self.Active[rotID]
			if not getRot then continue end
			getRot.Index = index
			local brainrotdata = BrainrotData[getRot.Name]
			local scale = Calculator.CalculateScaleFromWeight(getRot.Weight,brainrotdata.WeightPool,Models[getRot.Name])
			local positionOffset = (brainrotdata.YOffset or 0.5) * scale

			-- get the brainrot in FRONT
			local RotInFront = self.Lines[getRot.Path][index - 1]

			local TargetCFrame

			if RotInFront then
				local frontCache = self.Active[RotInFront]
				local WeightPool = BrainrotData[frontCache.Name].WeightPool
				local frontScale = Calculator.CalculateScaleFromWeight(frontCache.Weight,WeightPool,Models[frontCache.Name])
				local frontBBox = ServerUtility.GetExactBoundingBox(Models[frontCache.Name]).Size

				-- Get CURRENT brainrot's bounding box
				local currentBBox = ServerUtility.GetExactBoundingBox(Models[getRot.Name]).Size

				-- Distance from the FRONT brainrot's position
				local sizeAdjustment = (frontBBox.Z * frontScale / 2) + (currentBBox.Z * scale / 2) + OffsetPerBrainrot

				-- Start from the FRONT brainrot's Target position, adjust Y for current brainrot's offset
				local frontY = frontCache.Target.Y
				local currentY = (self.Folder.Path[getRot.Path].CFrame * CFrame.new(0, positionOffset, 0)).Y

				TargetCFrame = frontCache.Target * CFrame.new(0, currentY - frontY, sizeAdjustment)
			else
				-- First brainrot uses the base position with Y offset
				TargetCFrame = self.Folder.Path[getRot.Path].CFrame * CFrame.new(0, positionOffset, 0)
			end

			getRot.Target = TargetCFrame

			local function onMove(newPos)
				getRot.Position = newPos
			end
			local function onReach(finalPos)
				self:ReachedDesk(rotID, finalPos)
			end
			getRot.Mover:MoveTo(TargetCFrame, onMove, onReach)
			SpawnRemote:FireAllClients("MoveBrainrot", {
				["ID"] = rotID;
				["Target"] = TargetCFrame;
				["Plot"] = self.PlotNumber;
			})
		end
	end)

	-- cleanup + FX
	OrderRemote:FireAllClients("Cleanup", {
		["ID"] = BrainrotID;
		["Plot"] = self.PlotNumber;
	})

	if self.CurrentOrder[self.Active[BrainrotID].Path] ~= nil then self.CurrentOrder[self.Active[BrainrotID].Path] = nil end
	self.Active[BrainrotID] = nil
	self.Objects["Customer" .. BrainrotID] = nil
end

--[[
	DELEGATION: RestockPlayerStore
	
	This function delegates to GlobalStore.RestockPlayerStore to handle
	personal restock purchases (developer products).
	
	@param plr: Player - The player requesting the restock
	@param storeType: string - "Seed" or "Gear" store type
	@return boolean - Success status
]]
function plot.RestockPlayerStore(plr, storeType)
	return GlobalStore.RestockPlayerStore(plr, storeType)
end
