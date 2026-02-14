-- Services --

local TweenService = game:GetService('TweenService')
local ReplicatedService = game:GetService('ReplicatedStorage')

-- Objects --

local Player = game.Players.LocalPlayer
local PlayerUI = Player:WaitForChild('PlayerGui')

-- Modules --

local Dialogues = require(ReplicatedService.Game.Modules.Libraries.Dialogue)
-- Code --

local DialogueModule = {}

DialogueModule.Connections = {}
DialogueModule.DialogueActive = false
DialogueModule.DialogueCache = {
	['SelfDialogue'] = nil;
	['NPCDialogue'] = nil;
}

-- Local Functions --

local function Disconnect()
	for _, Connection in pairs(DialogueModule.Connections) do
		Connection:Disconnect()
	end
end

-- Modular Functions --
ReplicatedService.Remotes.SendDialogue.OnClientEvent:Connect(function(info) -- bandaid since this is setup kinda poorly, lets us send dialogue so we can do our checks serverside for favoriting etc.
	
	local NPC = info.NPC
	local Sentence = info.Sentence
	local Duration = info.Duration or 3
	
	DialogueModule:Talk({
		["NPC"] = NPC;
		["Text"] = Sentence;
		["Duration"] = 3;
	})
	
end)


function DialogueModule.CreateFrames(Information)
	-- basic loading code. --
	local NPCModel = workspace.Plots[Player:GetAttribute("Plot")].NPC[Information.NPC]
	local LocalModel = Player.Character

	local NewSelfDialogue = script.SelfDialogue:Clone()
	local NewNPCDialogue = script.NPCDialogue:Clone()

	NewSelfDialogue.Parent = Player.PlayerGui
	NewNPCDialogue.Parent = Player.PlayerGui

	NewSelfDialogue.Adornee = LocalModel.HumanoidRootPart
	NewNPCDialogue.Adornee = NPCModel.Head

	DialogueModule.DialogueCache.SelfDialogue = NewSelfDialogue
	DialogueModule.DialogueCache.NPCDialogue = NewNPCDialogue
end

local function fade_out_responses()
	local SelfDialogueFrame = DialogueModule.DialogueCache.SelfDialogue.Container

	for _, ResponseFrame in pairs(SelfDialogueFrame.Responses.ResponsesList:GetChildren()) do
		if ResponseFrame:IsA('Frame') then
			TweenService:Create(ResponseFrame, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
			TweenService:Create(ResponseFrame.ResponseText, TweenInfo.new(0.1), {TextTransparency = 1}):Play()
			TweenService:Create(ResponseFrame.ResponseNumber, TweenInfo.new(0.1), {TextTransparency = 1}):Play()
		end
	end

	task.wait(0.1)

	for _, ResponseFrame in pairs(SelfDialogueFrame.Responses.ResponsesList:GetChildren()) do
		if ResponseFrame:IsA('Frame') then
			ResponseFrame:Destroy()
		end
	end
end

-- NEW: Simple talk function for NPCs to say things without full dialogue
function DialogueModule:Talk(Information)
	local NPCModel = workspace.Plots[Player:GetAttribute("Plot")].NPC:FindFirstChild(Information.NPC)
	if not NPCModel then 
		warn("NPC not found:", Information.NPC)
		return 
	end

	-- Create only NPC dialogue frame
	local NewNPCDialogue = script.NPCDialogue:Clone()
	NewNPCDialogue.Parent = Player.PlayerGui
	NewNPCDialogue.Adornee = NPCModel.Head

	local NPCDialogueFrame = NewNPCDialogue.Container

	-- Type out the message
	local SplitMessage = string.split(Information.Text, ' ')
	if NPCDialogueFrame:FindFirstChild("Main") and NPCDialogueFrame.Main:FindFirstChild("Description") then
		NPCDialogueFrame.Main.Description.Text = ''

		task.spawn(function()
			for Index, Message in pairs(SplitMessage) do
				for _, Letter in pairs(string.split(Message, '')) do
					NPCDialogueFrame.Main.Description.Text = NPCDialogueFrame.Main.Description.Text..Letter
					task.wait(0.03)
				end
				NPCDialogueFrame.Main.Description.Text = NPCDialogueFrame.Main.Description.Text..' '
			end

			-- Wait for duration then destroy
			task.wait(Information.Duration or 3)

			TweenService:Create(NPCDialogueFrame, TweenInfo.new(0.3), {Size = UDim2.new(0, 0, NPCDialogueFrame.Size.Y.Scale, 0)}):Play()
			TweenService:Create(NPCDialogueFrame.Main.Description, TweenInfo.new(0.3), {TextTransparency = 1}):Play()

			task.wait(0.3)
			NewNPCDialogue:Destroy()
		end)
	else
		warn("NPCDialogue template missing Main.Description")
		NewNPCDialogue:Destroy()
	end
end

function DialogueModule:Dialogue(Information)
	if DialogueModule.DialogueActive == true and Information.DialogueContinuation == nil then return end

	local SearchForCache = Dialogues[Information.NPC]

	local DeleteFormerResponses = false

	Information.Prompt.Enabled = false
	DialogueModule.CurrentPrompt = Information.Prompt

	if DialogueModule.DialogueCache.SelfDialogue == nil then
		DialogueModule.CreateFrames({['NPC'] = Information.NPC})
	else
		DeleteFormerResponses = true
	end

	local SelfDialogueFrame = DialogueModule.DialogueCache.SelfDialogue.Container
	local NPCDialogueFrame = DialogueModule.DialogueCache.NPCDialogue.Container

	if SearchForCache ~= nil then
		local FindNPCModel = workspace.Plots[Player:GetAttribute("Plot")].NPC:FindFirstChild(Information.NPC)

		local FaceCache = DialogueModule.FacingCache[FindNPCModel]

		if FindNPCModel then
			local FaceCache = DialogueModule.FacingCache[FindNPCModel]

			if not FaceCache.FacingBodyLoop then
				FaceCache.FacingBodyLoop = game:GetService('RunService').Heartbeat:Connect(function()
					local Goal = CFrame.lookAt(FindNPCModel.HumanoidRootPart.Position, Vector3.new(Player.Character.HumanoidRootPart.Position.X, FindNPCModel.HumanoidRootPart.Position.Y, Player.Character.HumanoidRootPart.Position.Z))

					local tweenInfo = TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
					local Tween = TweenService:Create(FindNPCModel.HumanoidRootPart, tweenInfo, {CFrame = Goal})
					Tween:Play()
				end)

				if FaceCache.FacingHead == true then
					FaceCache.FacingHead = false
					FaceCache.FacingHeadLoop:Disconnect(); FaceCache.FacingHeadLoop = nil

					--local tweenInfo = TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
					--FaceCache.CurrentNeckTween = TweenService:Create(FaceCache.Neck, tweenInfo, {C0 = FaceCache.OriginalNeckCFrame})
					--FaceCache.CurrentNeckTween:Play()
				end
			end
		end

		DialogueModule.DialogueActive = true

		TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5), {FieldOfView = 60}):Play()

		local TargetProgress = (Information.Index or 1) -- What stage of the dialogue your on. --
		local TargetCache = SearchForCache[TargetProgress] -- Target dialogue w/index. --

		-- Delete old responses. --

		if DeleteFormerResponses == true then
			fade_out_responses()
		end

		-- Load responses. --

		local function NumberIntegerTable(TBL)
			local Result = 0

			for Index, _ in pairs(TBL) do
				if typeof(Index) == 'number' then
					Result += 1
				end
			end

			return Result
		end

		local function LoadResponses()
			-- loads responses in self frame. --
			local ResponseList = TargetCache.Responses
			local ResponseFunctions = TargetCache.ResponseFunctions

			local count = 0

			for Index, Data in pairs(ResponseList) do
				count += 1
				local NewResponseTemplate = script:WaitForChild('Response'):Clone()
				NewResponseTemplate.Parent = SelfDialogueFrame.Responses.ResponsesList
				NewResponseTemplate.ResponseText.Text = Index
				NewResponseTemplate.ResponseNumber.Text = count..'.'

				NewResponseTemplate.ResponseNumber.TextTransparency = 1
				NewResponseTemplate.ResponseText.TextTransparency = 1
				NewResponseTemplate.BackgroundTransparency = 1

				TweenService:Create(NewResponseTemplate, TweenInfo.new(0.5), {BackgroundTransparency = 0.35}):Play()
				TweenService:Create(NewResponseTemplate.ResponseText, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
				TweenService:Create(NewResponseTemplate.ResponseNumber, TweenInfo.new(0.5), {TextTransparency = 0}):Play()

				local originPos = NewResponseTemplate.ResponseText.Position

				local strokeTween
				local strokeTween2
				local strokeTween3

				DialogueModule.Connections[Index..'1'] = NewResponseTemplate.Overlay.MouseEnter:Connect(function()
					if strokeTween ~= nil then strokeTween:Cancel(); strokeTween = nil end
					if strokeTween2 ~= nil then strokeTween2:Cancel(); strokeTween2 = nil end
					if strokeTween3 ~= nil then strokeTween3:Cancel(); strokeTween3 = nil end

					strokeTween3 = TweenService:Create(NewResponseTemplate.ResponseText, TweenInfo.new(0.1), {Position = UDim2.new(originPos.X.Scale + 0.025, 0, originPos.Y.Scale, 0)})
					strokeTween = TweenService:Create(NewResponseTemplate.UIStroke, TweenInfo.new(0.1), {Transparency = 1})
					strokeTween2 = TweenService:Create(NewResponseTemplate, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(12, 12, 12)})

					strokeTween:Play(); strokeTween2:Play(); strokeTween3:Play()
				end)

				DialogueModule.Connections[Index..'2'] = NewResponseTemplate.Overlay.MouseLeave:Connect(function()
					if strokeTween ~= nil then strokeTween:Cancel(); strokeTween = nil end
					if strokeTween2 ~= nil then strokeTween2:Cancel(); strokeTween2 = nil end
					if strokeTween3 ~= nil then strokeTween3:Cancel(); strokeTween3 = nil end

					strokeTween3 = TweenService:Create(NewResponseTemplate.ResponseText, TweenInfo.new(0.1), {Position = UDim2.new(originPos.X.Scale, 0, originPos.Y.Scale, 0)})
					strokeTween2 = TweenService:Create(NewResponseTemplate, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(26, 26, 26)})
					strokeTween = TweenService:Create(NewResponseTemplate.UIStroke, TweenInfo.new(0.1), {Transparency = 1})

					strokeTween2:Play(); strokeTween:Play(); strokeTween3:Play()
				end)

				DialogueModule.Connections[NewResponseTemplate] = NewResponseTemplate.Overlay.MouseButton1Click:Connect(function()
					-- Fire with dialogue request. --
					warn('Clicked a response.')

					TweenService:Create(SelfDialogueFrame, TweenInfo.new(0.1), {Position = UDim2.new(SelfDialogueFrame.Position.X.Scale + 0.05, 0, SelfDialogueFrame.Position.Y.Scale, 0)}):Play()

					warn(Data)
					warn(Index)
					warn(ResponseFunctions)

					if ResponseFunctions[Data] ~= nil then
						warn("RUNNING")
						ResponseFunctions[Data]()
					end

					if Data == 'Decline' then
						warn('Closing.')
						DialogueModule.Close(FindNPCModel)
					else
						-- Continue dialogue if its not the last dialogue. --
						if NumberIntegerTable(SearchForCache) == TargetProgress then
							warn('Closing 2.')
							DialogueModule.Close(FindNPCModel)
						else
							warn('Running dialogue.')

							local NewInformation = Information
							NewInformation.Index = TargetProgress + 1
							NewInformation.DialogueContinuation = true

							DialogueModule:Dialogue(NewInformation)
						end
					end
				end)
			end
		end

		-- Setup UI. --

		-- load npc ui --

		local SplitMessage = string.split(TargetCache.Text, ' ')

		NPCDialogueFrame.Main.Description.Text = ''

		task.spawn(function()
			local LoadedResponses = false

			for Index, Message in pairs(SplitMessage) do
				for _, Letter in pairs(string.split(Message, '')) do
					NPCDialogueFrame.Main.Description.Text = NPCDialogueFrame.Main.Description.Text..Letter

					task.wait(0.03)
				end

				NPCDialogueFrame.Main.Description.Text = NPCDialogueFrame.Main.Description.Text..' '
			end

			LoadedResponses = true

			LoadResponses()

			while true do
				task.wait()

				if Player.Character then
					local Character = Player.Character
					if DialogueModule.DialogueActive ~= true then
						break
					end

					if (Character.PrimaryPart.Position - FindNPCModel.PrimaryPart.Position).Magnitude >= 15 then
						DialogueModule.Close(FindNPCModel)
						break
					end
				end

			end

		end)

		-- Run button functions. --
	end
end

function DialogueModule.Close(NPC)
	if DialogueModule.DialogueActive ~= true then
		return
	end
	if DialogueModule.DialogueCache.NPCDialogue == nil then
		return
	end



	fade_out_responses()

	DialogueModule.DialogueCache.NPCDialogue:Destroy()
	DialogueModule.DialogueCache.SelfDialogue:Destroy()

	if DialogueModule.FacingCache[NPC] then
		local FaceCache = DialogueModule.FacingCache[NPC]

		if FaceCache.FacingBodyLoop then
			local tweenInfo = TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)

			-- Body. --
			FaceCache.FacingBodyLoop:Disconnect(); FaceCache.FacingBodyLoop = nil
			FaceCache.CurrentBodyTween = TweenService:Create(NPC.HumanoidRootPart, tweenInfo, {CFrame = FaceCache.OriginalRootCFrame})
			FaceCache.CurrentBodyTween:Play()

			-- Head. --
			--FaceCache.FacingHead = false
			--if FaceCache.FacingHeadLoop then FaceCache.FacingHeadLoop:Disconnect(); FaceCache.FacingHeadLoop = nil end
			--FaceCache.CurrentNeckTween = TweenService:Create(FaceCache.Neck, tweenInfo, {C0 = FaceCache.OriginalNeckCFrame})
			--FaceCache.CurrentNeckTween:Play()
		end
	end

	DialogueModule.DialogueCache.NPCDialogue = nil; DialogueModule.DialogueCache.SelfDialogue = nil

	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5), {FieldOfView = 70}):Play()
	DialogueModule.DialogueActive = nil

	DialogueModule.CurrentPrompt.Enabled = true
	DialogueModule.CurrentPrompt = nil

	Disconnect()
end

-- Global Initiation --

DialogueModule.FacingCache = {}
DialogueModule.CurrentPrompt = nil

for _, NPC in pairs(workspace:GetDescendants()) do
	if NPC:IsA('Model') and NPC:FindFirstChild('Dialogue') then
		local ProxPrompt = NPC:FindFirstChild('Dialogue')

		ProxPrompt.Triggered:Connect(function(User)
			if User == Player then
				ProxPrompt.Enabled = false
				DialogueModule.CurrentPrompt = ProxPrompt

				DialogueModule:Dialogue({
					['Index'] = 1;
					['NPC'] = NPC.Name;
				})
			end
		end)
	end

	if NPC:FindFirstChild('Touchable') then

		local Neck = NPC:WaitForChild("Torso"):WaitForChild("Neck")

		local NormalNeckC0 = Neck.C0

		DialogueModule.FacingCache[NPC] = {
			FacingBodyLoop = nil;
			FacingHeadLoop = nil;

			OriginalRootCFrame = NPC.HumanoidRootPart.CFrame;
			OriginalNeckCFrame = NormalNeckC0;
			['Neck'] = Neck;

			CurrentNeckTween = nil;

			FacingBody = false;
			FacingHead = false;
		}

		DialogueModule.FacingCache[NPC].CurrentNeckTween = nil

		--NPC:FindFirstChild('Touchable').Touched:Connect(function(hit)
		--	if DialogueModule.FacingCache[NPC].FacingHead == false then
		--		if hit:IsDescendantOf(Player.Character or Player.CharacterAdded:Wait()) then
		--			local Character = Player.Character

		--			if DialogueModule.FacingCache[NPC].CurrentNeckTween then DialogueModule.FacingCache[NPC].CurrentNeckTween:Cancel() end

		--			DialogueModule.FacingCache[NPC].FacingHead = true

		--			DialogueModule.FacingCache[NPC].FacingHeadLoop = game:GetService('RunService').Heartbeat:Connect(function()
		--				local CameraDirection = (CFrame.new(NPC.HumanoidRootPart.Position, Character.PrimaryPart.Position):inverse() * NPC.HumanoidRootPart.CFrame).lookVector * -1
		--				local YOffset = Neck.C0.Y

		--				local Goal = CFrame.new(0, YOffset, 0) * CFrame.Angles(0, 0, math.rad(180)) * CFrame.Angles(0, math.asin(CameraDirection.x), 0) * CFrame.Angles(math.asin(CameraDirection.y), 0, 0) * CFrame.Angles(math.rad(90), 0, 0)

		--				--local tweenInfo = TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
		--				--local Tween = TweenService:Create(Neck, tweenInfo, {C0 = Goal})
		--				--Tween:Play()
		--			end)
		--		end
		--	end
		--end)

		NPC:FindFirstChild('Touchable').StoppedTouching:Connect(function(hit)
			if DialogueModule.FacingCache[NPC].FacingHead == true then
				if hit:IsDescendantOf(Player.Character or Player.CharacterAdded:Wait()) then
					DialogueModule.FacingCache[NPC].FacingHead = false
					DialogueModule.FacingCache[NPC].FacingHeadLoop:Disconnect(); DialogueModule.FacingCache[NPC].FacingHeadLoop = nil

					--local tweenInfo = TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
					--DialogueModule.FacingCache[NPC].CurrentNeckTween = TweenService:Create(Neck, tweenInfo, {C0 = NormalNeckC0})
					--DialogueModule.FacingCache[NPC].CurrentNeckTween:Play()
				end
			end
		end)
	end
end

return DialogueModule