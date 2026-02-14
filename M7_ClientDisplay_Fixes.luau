-- M7_ClientDisplay_Fixes.luau
-- FIXED client-side leaderboard display code
-- Addresses: BUG #8, display formatting issues

-- Place this file in Client/UI/HUD/ and require it from Leaderboards [Client].luau
-- Or replace the contents of Leaderboards [Client].luau with this code

local ViewportModelCFrame = CFrame.new(0, -4, -9) * CFrame.Angles(math.rad(8), math.rad(-13), math.rad(0))
local ViewportPlantCFrame = CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(90), math.rad(20), math.rad(20))

-- player --
local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local CurrentCamera = workspace.CurrentCamera

-- services --
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")

-- folders --
local GameFolder = RS.Game
local Sounds = GameFolder.Sounds
local Modules = GameFolder.Modules
local UI = GameFolder.UI

-- modules --
local NewTS = require(Modules.Utilities.Tweener)
local NumberShortener = require(Modules.Utilities.NumberShortener)

-- data --
local PlayerReplica = require(RS:WaitForChild("PlayerData")):GetData()

-- remotes --
local UpdateLeaderboardRemote = RS.Remotes.UpdateLeaderboard

-- // Code \\ --

local module = {}

-- Load leaderboard UI.
repeat task.wait() until Player:GetAttribute("Plot")
local plotFolder = workspace.Plots:WaitForChild(Player:GetAttribute("Plot"))

local newLeaderboardUI = PlayerGui:WaitForChild("LeaderboardUI")
newLeaderboardUI.Adornee = plotFolder:WaitForChild("Leaderboard")

local leaderboardList = newLeaderboardUI.Frame.ScrollingFrame
local currentCategory = "Playtime" -- default category

-- Sound utility
local flowUtil = require(Modules.Utilities.flowUtil)
local function playSound(Name)
    local SoundPath = Sounds.GameSounds[Name]
    if SoundPath then
        flowUtil:PlaySound(SoundPath, workspace)
    end
end

-- Button hover effects
local function surfaceHover(button)
    if button:GetAttribute("HoverParent") then
        if not button.Parent:FindFirstChild("UIScale") then
            local newScale = Instance.new("UIScale", button.Parent)
            newScale.Scale = 1
        end

        button.MouseEnter:Connect(function()
            NewTS:TweenBounce(button.Parent.UIScale, {Scale = 0.95})
            playSound("hover2")
        end)

        button.MouseLeave:Connect(function()
            NewTS:TweenBounce(button.Parent.UIScale, {Scale = 1})
            playSound("hover2")
        end)

        button.MouseButton1Down:Connect(function()
            NewTS:TweenBounce(button.Parent.UIScale, {Scale = 0.8})
        end)

        button.MouseButton1Up:Connect(function()
            NewTS:TweenBounce(button.Parent.UIScale, {Scale = 1})
            playSound("hover1")
        end)
    end
end

surfaceHover(newLeaderboardUI.Frame.Buttons.Cash.Button)
surfaceHover(newLeaderboardUI.Frame.Buttons.Playtime.Button)
surfaceHover(newLeaderboardUI.Frame.Buttons.Orders.Button)

-- NEW: Format time in human-readable format
local function formatTime(seconds)
    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m"
    elseif seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return hours .. "h " .. mins .. "m"
    else
        local days = math.floor(seconds / 86400)
        local hours = math.floor((seconds % 86400) / 3600)
        return days .. "d " .. hours .. "h"
    end
end

-- Refresh all the leaderboards when server sends data
module.RefreshLeaderboards = function(category, data)
    -- BUG #8 FIX: Validate data before processing
    if not data or type(data) ~= "table" then
        warn("[Leaderboard] Invalid data received for category: " .. tostring(category))
        return
    end
    
    if category == currentCategory then
        -- Clear existing frames
        for _, child in ipairs(leaderboardList:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "LeaderboardTemplate" then
                child:Destroy()
            end
        end

        -- Create new frames for each player
        for _, playerData in ipairs(data) do
            if type(playerData) == "table" then
                module.CreatePlayerFrame(playerData, currentCategory)
            end
        end
    end
end

local prefix = {
    Cash = "$",
    Orders = "",
    Playtime = ""  -- Will use formatTime instead
}

module.CreatePlayerFrame = function(data, cat)
    -- Validate required fields
    if not data or not data.ID or not data.Name then
        warn("[Leaderboard] Invalid player data")
        return
    end
    
    local newTemplate = script:FindFirstChild("LeaderboardTemplate"):Clone()
    newTemplate.Parent = leaderboardList
    newTemplate.Name = "Entry_" .. tostring(data.ID)
    newTemplate.PlayerName.Text = data.Name
    
    -- Set player icon with fallback
    local iconUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. data.ID .. "&width=420&height=420&format=png"
    newTemplate.PlayerIcon.ImageLabel.Image = iconUrl
    
    -- Format amount based on category
    local amountText = ""
    if cat == "Playtime" then
        -- NEW: Human-readable time format
        amountText = formatTime(tonumber(data.Amount) or 0)
    else
        amountText = NumberShortener.roundNumber(data.Amount or 0)
        if prefix[cat] then
            amountText = prefix[cat] .. amountText
        end
    end
    
    newTemplate.Amount.Text = amountText
    newTemplate.PlayerIcon.PlayerName.Text = "#" .. (data.Place or "?")

    -- Set place badge if available
    local placeNum = tonumber(data.Place)
    if placeNum and newTemplate.PlayerIcon.PlayerName:FindFirstChild(tostring(placeNum)) then
        newTemplate.PlayerIcon.PlayerName:FindFirstChild(tostring(placeNum)).Enabled = true
    end

    -- NEW: Add gradient based on category
    local newGradient = newLeaderboardUI.Frame.Title:FindFirstChild(cat)
    if newGradient then
        newGradient = newGradient:Clone()
        newGradient.Enabled = true
        newGradient.Parent = newTemplate.Amount
    end
end

-- Function to switch between leaderboard categories
module.SwitchCategory = function(category)
    currentCategory = category
    newLeaderboardUI.Frame.Title.Text = "Most " .. category
    
    -- Update gradient
    for _, grad in ipairs(newLeaderboardUI.Frame.Title:GetChildren()) do
        if grad:IsA("UIGradient") then
            grad.Enabled = false
        end
    end
    
    local categoryGradient = newLeaderboardUI.Frame.Title:FindFirstChild(category)
    if categoryGradient then
        categoryGradient.Enabled = true
    end
    
    -- Request updated data
    UpdateLeaderboardRemote:FireServer(category)
end

-- Function to get current category
module.GetCurrentCategory = function()
    return currentCategory
end

-- Listen for leaderboard updates from server
UpdateLeaderboardRemote.OnClientEvent:Connect(function(category, data)
    -- BUG #8 FIX: Add timestamp validation if server sends it
    module.RefreshLeaderboards(category, data)
end)

-- Initial request with retry
task.delay(0.5, function()
    UpdateLeaderboardRemote:FireServer(currentCategory)
end)

-- Retry after delay if no data received
task.delay(5, function()
    if #leaderboardList:GetChildren() <= 1 then  -- Only template exists
        UpdateLeaderboardRemote:FireServer(currentCategory)
    end
end)

-- Category button handlers
for _, button in ipairs(newLeaderboardUI.Frame.Buttons:GetChildren()) do
    if button:IsA("Frame") and button:FindFirstChild("Button") then
        button.Button.MouseButton1Click:Connect(function()
            module.SwitchCategory(button.Name)
        end)
    end
end

-- Start with Playtime
module.SwitchCategory("Playtime")

return module
