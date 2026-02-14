print('ran')
local CustomPromptModule = {}

local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')

local MarketplaceService = game:GetService("MarketplaceService")

local UIRemote = game.ReplicatedStorage.Remotes.UI

local PromptModule = require(script.Parent.Parent.UI.HUD["Prompt [Client]"])

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui

CustomPromptModule.Cache = {}

-- Track last input type
local LastInputType = "Keyboard" -- Default to keyboard

-- Update input type based on last input
local function UpdateInputType(inputType)
	if inputType == Enum.UserInputType.Touch then
		LastInputType = "Touch"
	elseif inputType == Enum.UserInputType.Gamepad1 or inputType == Enum.UserInputType.Gamepad2 or 
		inputType == Enum.UserInputType.Gamepad3 or inputType == Enum.UserInputType.Gamepad4 then
		LastInputType = "Gamepad"
	elseif inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.MouseButton1 or
		inputType == Enum.UserInputType.MouseButton2 or inputType == Enum.UserInputType.MouseButton3 then
		LastInputType = "Keyboard"
	end
end

-- Listen for input changes
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	UpdateInputType(input.UserInputType)
end)

-- Also check on window focus in case gamepad was plugged in
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	UpdateInputType(input.UserInputType)
end)

local function GetInputPrompt()
	if LastInputType == "Touch" then
		return "TAP"
	elseif LastInputType == "Gamepad" then
		return "Y" -- or ButtonY icon
	else
		return "E"
	end
end

CustomPromptModule.Functions = {
	['GiveItem'] = function(Prompt)
		local ItemName = Prompt.Parent.Name;
	end,

	['GiveObjective'] = function(Prompt)

	end,

	['Dialogue'] = function(Prompt)
		local DialogueController = require(script.Parent:WaitForChild('DialogueController'))

		DialogueController:Dialogue({
			['Index'] = 1;
			['NPC'] = Prompt:GetAttribute('DialogueTarget');
			['Prompt'] = Prompt;
		})
	end,

	['OpenFrame'] = function(Prompt)
		local FrameName = Prompt:GetAttribute("Frame")
		local MainUI = PlayerGui.MainUI[FrameName]
		
		local HUD = require(script.Parent.Parent.UI.HUD)
		HUD.OpenFrame(MainUI, true)
	end,
	
	['PurchaseProduct'] = function(Prompt)
		MarketplaceService:PromptProductPurchase(Player, Prompt:GetAttribute("ProductID"), nil)
	end,
	
	['GiftBrainrot'] = function(Prompt)
		local ID = Prompt:GetAttribute("PromptData")
		-- create a UI prompt --
		
		local text = "Are you sure you would like to gift your "..Prompt:GetAttribute("BrainrotName").." to "..Prompt.Parent.Parent.Name.."?"
		
		local data = {
			["BrainrotID"] = ID;
			["PlayerToSend"] = Prompt.Parent.Parent.Name;
		}
		local HUD = require(script.Parent.Parent.UI.HUD)
		PromptModule.CreatePrompt(text, "GiftPrompt", data, HUD.OpenFrame, HUD.CloseFrame)
	end,
}

CustomPromptModule.OnActivate = function(Prompt)

end

CustomPromptModule.OnHold = function(Prompt)

end

CustomPromptModule.Init = function()
	local function runPrompt(Desc)
		if Desc:IsA('ProximityPrompt') then
			CustomPromptModule.Cache[Desc] = {
				['Connections'] = {};
				['Tweens'] = {};
				['PromptUI'] = nil;
				['Highlight'] = nil;
			}

			local Cache = CustomPromptModule.Cache[Desc]
			local Function = CustomPromptModule.Functions[Desc:GetAttribute('PromptType')]

			Desc.Style = Enum.ProximityPromptStyle.Custom
			Desc.ClickablePrompt = true
			Desc.GamepadKeyCode = Enum.KeyCode.ButtonY
			Desc.KeyboardKeyCode = Enum.KeyCode.E

			local PromptStyle = Desc:GetAttribute("PromptStyle") or "Vertical"

			-- Function to create the UI when prompt is shown
			local function CreatePromptUI()
				if Cache.PromptUI then return end -- Already created

				local PromptUI = script[PromptStyle]:Clone()
				if Desc:GetAttribute("PromptName") then
					PromptUI.Name = Desc:GetAttribute("PromptName")
				end
				PromptUI.Parent = Player.PlayerGui
				PromptUI.Adornee = Desc.Parent
				PromptUI.StudsOffset = Desc:GetAttribute("Offset") or Vector3.new(0,0,0)

				Cache.PromptUI = PromptUI

				-- Setup text content
				local Initial = Desc:GetAttribute('PromptText') or 'Do'
				local Bold = Desc:GetAttribute('BoldText')

				local function HexToRGB(hex)
					hex = hex:gsub("#", "")
					return tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16)
				end

				if Desc:GetAttribute("BoldColor") then
					local r,g,b = HexToRGB(Desc:GetAttribute("BoldColor"))
					PromptUI.Frame.Top.Info.Text = Initial..' <font color="rgb('..r..','..g..','..b..')">'..Bold..'</font>'
				elseif Bold ~= nil then
					PromptUI.Frame.Top.Info.Text = Initial..' <b>'..Bold..'</b>'
				else
					PromptUI.Frame.Top.Info.Text = Initial
				end

				return PromptUI
			end

			-- Function to create highlight on hover
			local function CreateHighlight()
				if Cache.Highlight then return end -- Already exists
				
				local newHighlight = Instance.new("Highlight", Desc.Parent.Parent)
				newHighlight.FillTransparency = 1
				newHighlight.OutlineTransparency = 1
				Cache.Highlight = newHighlight
			end
			
			-- Function to destroy highlight on unhover
			local function DestroyHighlight()
				if Cache.Highlight then
					Cache.Highlight:Destroy()
					Cache.Highlight = nil
				end
			end

			-- Function to destroy the UI when prompt is hidden
			local function DestroyPromptUI()
				if Cache.PromptUI then
					Cache.PromptUI:Destroy()
					Cache.PromptUI = nil
				end
				DestroyHighlight()
				-- Cancel any ongoing tweens
				for _, tween in pairs(Cache.Tweens) do
					tween:Cancel()
				end
				Cache.Tweens = {}
			end

			-- Function to update button prompt based on current input
			local function UpdateButtonPrompt(PromptUI)
				if PromptUI.Frame:FindFirstChild("Bottom") and PromptUI.Frame.Bottom:FindFirstChild("Press") then
					local KeyFrame = PromptUI.Frame.Bottom.Press:FindFirstChild("Key")
					if KeyFrame then
						local input = GetInputPrompt()
						if KeyFrame.Parent:FindFirstChild("ControllerKey") then
							if input == "Y" then
								KeyFrame.Visible = false
								KeyFrame.Parent.ControllerKey.Visible = true
								KeyFrame.Parent.ControllerKey.Image = script[UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonY)].Image
								KeyFrame.Parent.Box.Visible = false
							else
								KeyFrame.Visible = true
								KeyFrame.Parent.ControllerKey.Visible = false
								KeyFrame.Text = GetInputPrompt()
							end
						else
							KeyFrame.Text = GetInputPrompt()
						end
					end
				end
			end

			local AppearTween
			local DisappearTween
			local UsedTween

			if PromptStyle == "Vertical" then
				local BottomOnScreen = UDim2.new(0.5, 0, 0.25, 0)
				local TopOnScreen = UDim2.new(0.5, 0, 0.8, 0)
				local BottomOffScreen = nil
				local TopOffScreen = nil

				local function CancelTweens()
					for _, tween in pairs(Cache.Tweens) do
						tween:Cancel()
					end
					Cache.Tweens = {}
				end

				AppearTween = function()
					local PromptUI = CreatePromptUI()
					if not PromptUI then return end

					-- Create highlight when hovering (to avoid hitting highlight limit)
					if not Cache.Highlight then
						local newHighlight = Instance.new("Highlight", Desc.Parent.Parent)
						newHighlight.FillTransparency = 1
						newHighlight.OutlineTransparency = 1
						Cache.Highlight = newHighlight
					end

					-- Store the initial off-screen positions
					BottomOffScreen = PromptUI.Frame.Bottom.Press.Position
					TopOffScreen = PromptUI.Frame.Top.Info.Position

					PromptUI.Frame.TextButton.Visible = true
					CancelTweens()
					UpdateButtonPrompt(PromptUI)

					for _, label in PromptUI.Frame.Top.Extra:GetChildren() do
						if not label:IsA("TextLabel") then continue end
						TweenService:Create(label, TweenInfo.new(0.15), {TextTransparency = 0}):Play()
						TweenService:Create(label.UIStroke, TweenInfo.new(0.15), {Transparency = 0}):Play()
					end

					Cache.Tweens["InHL"] = TweenService:Create(Cache.Highlight, TweenInfo.new(0.15), {OutlineTransparency = 0}):Play()
					Cache.Tweens['InTop'] = TweenService:Create(PromptUI.Frame.Top.Info, TweenInfo.new(0.15), {Position = TopOnScreen}):Play()
					Cache.Tweens['InBlur'] = TweenService:Create(PromptUI.Frame.Blur, TweenInfo.new(0.15), {ImageTransparency = 0.32}):Play()
					Cache.Tweens['InController'] = TweenService:Create(PromptUI.Frame.Bottom.Press.ControllerKey, TweenInfo.new(0.15), {ImageTransparency = 0}):Play()
					Cache.Tweens['InBottom'] = TweenService:Create(PromptUI.Frame.Bottom.Press, TweenInfo.new(0.15), {Position = BottomOnScreen}):Play()
				end

				DisappearTween = function()
					local PromptUI = Cache.PromptUI
					if not PromptUI then return end

					CancelTweens()
					PromptUI.Frame.TextButton.Visible = false

					for _, label in PromptUI.Frame.Top.Extra:GetChildren() do
						if not label:IsA("TextLabel") then continue end
						Cache.Tweens["label"..label.Name.."Text"] = TweenService:Create(label, TweenInfo.new(0.15), {TextTransparency = 1})
						Cache.Tweens["label"..label.Name.."Text"]:Play()
						Cache.Tweens["label"..label.Name.."Stroke"] = TweenService:Create(label.UIStroke, TweenInfo.new(0.15), {Transparency = 1})
						Cache.Tweens["label"..label.Name.."Stroke"]:Play()
					end

					if Cache.Highlight then
						Cache.Tweens["OutHL"] = TweenService:Create(Cache.Highlight, TweenInfo.new(0.15), {OutlineTransparency = 1})
						Cache.Tweens["OutHL"]:Play()
					end
					Cache.Tweens['OutTop'] = TweenService:Create(PromptUI.Frame.Top.Info, TweenInfo.new(0.15), {Position = TopOffScreen})
					Cache.Tweens['OutTop']:Play()
					Cache.Tweens['OutBlur'] = TweenService:Create(PromptUI.Frame.Blur, TweenInfo.new(0.15), {ImageTransparency = 1})
					Cache.Tweens['OutBlur']:Play()
					Cache.Tweens['OutController'] = TweenService:Create(PromptUI.Frame.Bottom.Press.ControllerKey, TweenInfo.new(0.15), {ImageTransparency = 1})
					Cache.Tweens['OutController']:Play()
					Cache.Tweens['OutBottom'] = TweenService:Create(PromptUI.Frame.Bottom.Press, TweenInfo.new(0.15), {Position = BottomOffScreen})
					Cache.Tweens['OutBottom']:Play()

					-- Destroy UI after animation completes
					task.delay(0.15, function()
						DestroyPromptUI()
					end)
				end

				UsedTween = function()
					if Function then Function(Desc) end
					local PromptUI = Cache.PromptUI
					if not PromptUI then return end

					local FillClone = PromptUI.Frame.Bottom.Press.Fill:Clone()
					FillClone.Parent = PromptUI.Frame.Bottom.Press
					FillClone.Size = UDim2.new(1, 0, 1, 0)
					TweenService:Create(FillClone, TweenInfo.new(0.35), {Size = UDim2.new(1.5, 0, 1.5, 0); Position = UDim2.new(0.5, 0, 0.5, 0); ImageTransparency = 1}):Play()
					task.delay(0.35, function()
						FillClone:Destroy()
					end)
				end

			elseif PromptStyle == "Horizontal" then
				local BottomOnScreen = UDim2.new(0.1, 0, 0.25, 0)
				local TopOnScreen = UDim2.new(0.83, 0, 0.8, 0)

				local function CancelTweens()
					for _, tween in pairs(Cache.Tweens) do
						tween:Cancel()
					end
					Cache.Tweens = {}
				end

				AppearTween = function()
					local PromptUI = CreatePromptUI()
					if not PromptUI then return end

					-- Create highlight when hovering (to avoid hitting highlight limit)
					if not Cache.Highlight then
						local newHighlight = Instance.new("Highlight", Desc.Parent.Parent)
						newHighlight.FillTransparency = 1
						newHighlight.OutlineTransparency = 1
						Cache.Highlight = newHighlight
					end

					PromptUI.Frame.TextButton.Visible = true
					CancelTweens()
					UpdateButtonPrompt(PromptUI)

					PromptUI.Enabled = true
					PromptUI.Frame.Top.Info.Position = TopOnScreen
					PromptUI.Frame.Top.Info.TextTransparency = 0
					PromptUI.Frame.Top.Info.UIStroke.Transparency = 0
					PromptUI.Frame.Bottom.Press.Key.TextTransparency = 0
					PromptUI.Frame.Bottom.Press.Box.UIStroke.Transparency = 0
					PromptUI.Frame.Bottom.Press.BackgroundTransparency = 0.4
					PromptUI.Frame.Bottom.Press.ControllerKey.ImageTransparency = 0
					Cache.Tweens["inHL"] = TweenService:Create(Cache.Highlight, TweenInfo.new(0.1), {OutlineTransparency = 0}):Play()
				end

				DisappearTween = function()
					local PromptUI = Cache.PromptUI
					if not PromptUI then return end

					local TopOffScreen = PromptUI.Frame.Top.Info.Position

					PromptUI.Frame.TextButton.Visible = false
					CancelTweens()

					if Cache.Highlight then
						Cache.Tweens["outHL"] = TweenService:Create(Cache.Highlight, TweenInfo.new(0.1), {OutlineTransparency = 1}):Play()
					end
					Cache.Tweens['outpress'] = TweenService:Create(PromptUI.Frame.Bottom.Press, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
					Cache.Tweens['outpress2'] = TweenService:Create(PromptUI.Frame.Bottom.Press.Box.UIStroke, TweenInfo.new(0.15), {Transparency = 1}):Play()
					Cache.Tweens['outpress3'] = TweenService:Create(PromptUI.Frame.Bottom.Press.Key, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
					Cache.Tweens['InController'] = TweenService:Create(PromptUI.Frame.Bottom.Press.ControllerKey, TweenInfo.new(0.15), {ImageTransparency = 1}):Play()
					Cache.Tweens['InTopText'] = TweenService:Create(PromptUI.Frame.Top.Info, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
					Cache.Tweens['InTopStroke'] = TweenService:Create(PromptUI.Frame.Top.Info.UIStroke, TweenInfo.new(0.15), {Transparency = 1}):Play()
					Cache.Tweens['OutTop'] = TweenService:Create(PromptUI.Frame.Top.Info, TweenInfo.new(0.15), {Position = TopOffScreen}):Play()

					-- Destroy UI after animation completes
					task.delay(0.15, function()
						DestroyPromptUI()
					end)
				end

				UsedTween = function()
					if Function then Function(Desc) end
					local PromptUI = Cache.PromptUI
					if not PromptUI then return end

					local FillClone = PromptUI.Frame.Bottom.Press.Fill:Clone()
					FillClone.Parent = PromptUI.Frame.Bottom.Press
					FillClone.Size = UDim2.new(1, 0, 1, 0)
					FillClone.ZIndex -= 1
					TweenService:Create(FillClone, TweenInfo.new(0.35), {Size = UDim2.new(1.5, 0, 1.5, 0); Position = UDim2.new(0.5, 0, 0.5, 0); ImageTransparency = 1}):Play()
					task.delay(0.35, function()
						FillClone:Destroy()
					end)
				end
			end

			-- Connections
			Cache.Connections['Appear'] = Desc.PromptShown:Connect(function()
				AppearTween()
			end)

			Cache.Connections['Disappear'] = Desc.PromptHidden:Connect(function()
				DisappearTween()
			end)

			Cache.Connections['Activated'] = Desc.Triggered:Connect(function()
			
				UsedTween()
			end)

			-- Click activation connection - needs special handling since PromptUI might not exist yet
			local clickConnection
			Cache.Connections['ClickActivated'] = Desc.PromptShown:Connect(function()
				-- Wait a frame for UI to be created
				task.wait()
				if Cache.PromptUI and not clickConnection then
					clickConnection = Cache.PromptUI.Frame.TextButton.MouseButton1Click:Connect(function()
						UsedTween()
						UIRemote:FireServer("ActivatePrompt", Desc.Name)
					end)
				end
			end)

			-- Clean up click connection when prompt hidden
			Cache.Connections['ClickCleanup'] = Desc.PromptHidden:Connect(function()
				if clickConnection then
					clickConnection:Disconnect()
					clickConnection = nil
				end
			end)

			if Desc.HoldDuration > 0 then
				Cache.Connections['Hold'] = Desc.PromptButtonHoldBegan:Connect(function()
					if Cache.PromptUI then
						Cache.Tweens['Hold'] = TweenService:Create(Cache.PromptUI.Frame.Bottom.Press.Fill, TweenInfo.new(Desc.HoldDuration), {Size = UDim2.new(1, 0, 1, 0)}):Play()
					end
				end)

				Cache.Connections['HoldEnded'] = Desc.PromptButtonHoldEnded:Connect(function()
					if Cache.Tweens['Hold'] then
						Cache.Tweens['Hold']:Cancel()
					end
				end)
			end

			local tConn
			tConn = Desc.AncestryChanged:Connect(function()
				DestroyPromptUI()
				tConn:Disconnect()
				for _, conn in Cache.Connections do
					conn:Disconnect()
				end
				for _, obj in Cache.Tweens do
					obj:Cancel()
				end
			end)
		end
	end

	for _, Desc in pairs(workspace:GetDescendants()) do
		runPrompt(Desc)
	end

	workspace.DescendantAdded:Connect(function(desc)
		runPrompt(desc)
	end)
end

return CustomPromptModule