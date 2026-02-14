-- PlayerDataSystem.lua
-- Handles player data persistence using DataStore

local PlayerDataSystem = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- DataStore
local playerDataStore = DataStoreService:GetDataStore("EscapeAcidRainData_v1")

-- Cache
local playerData = {} -- [userId] = data
local dataLoaded = {} -- [userId] = boolean

-- Default data template
local DEFAULT_DATA = {
    money = 0,
    speedLevel = 0,
    capacityLevel = 0,
    baseLevel = 1,
    brainrots = {}, -- Stored brainrots
    stats = {
        brainrotsCollected = 0,
        timePlayed = 0,
        wavesSurvived = 0
    },
    lastLogin = 0
}

-- Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataLoadedEvent = Instance.new("RemoteEvent")
DataLoadedEvent.Name = "DataLoadedEvent"
DataLoadedEvent.Parent = Remotes

function PlayerDataSystem.Init()
    Players.PlayerAdded:Connect(PlayerDataSystem.PlayerAdded)
    Players.PlayerRemoving:Connect(PlayerDataSystem.PlayerRemoving)
    
    -- Auto-save every 60 seconds
    spawn(PlayerDataSystem.AutoSaveLoop)
    
    print("💾 Player Data System initialized")
end

function PlayerDataSystem.PlayerAdded(player)
    local success, data = pcall(function()
        return playerDataStore:GetAsync("Player_" .. player.UserId)
    end)
    
    if success and data then
        -- Merge with defaults (for new fields)
        playerData[player.UserId] = PlayerDataSystem.MergeDefaults(data, DEFAULT_DATA)
        print("✅ Loaded data for", player.Name)
    else
        -- New player
        playerData[player.UserId] = table.clone(DEFAULT_DATA)
        print("🆕 New player:", player.Name)
    end
    
    dataLoaded[player.UserId] = true
    playerData[player.UserId].lastLogin = os.time()
    
    -- Tell client data is ready
    DataLoadedEvent:FireClient(player, playerData[player.UserId])
end

function PlayerDataSystem.PlayerRemoving(player)
    PlayerDataSystem.SavePlayerData(player)
    playerData[player.UserId] = nil
    dataLoaded[player.UserId] = nil
end

function PlayerDataSystem.SavePlayerData(player)
    if not dataLoaded[player.UserId] then return end
    
    local data = playerData[player.UserId]
    if not data then return end
    
    local success, err = pcall(function()
        playerDataStore:SetAsync("Player_" .. player.UserId, data)
    end)
    
    if success then
        print("💾 Saved data for", player.Name)
    else
        warn("❌ Failed to save data for", player.Name, err)
    end
end

function PlayerDataSystem.AutoSaveLoop()
    while true do
        wait(60)
        for _, player in ipairs(Players:GetPlayers()) do
            PlayerDataSystem.SavePlayerData(player)
        end
    end
end

function PlayerDataSystem.GetPlayerData(player)
    return playerData[player.UserId]
end

function PlayerDataSystem.SetPlayerData(player, key, value)
    if playerData[player.UserId] then
        playerData[player.UserId][key] = value
    end
end

function PlayerDataSystem.AddMoney(player, amount)
    if playerData[player.UserId] then
        playerData[player.UserId].money = playerData[player.UserId].money + amount
        
        -- Update other systems
        local UpgradeSystem = require(game.ServerStorage.Systems.UpgradeSystem)
        UpgradeSystem.AddMoney(player, amount)
    end
end

function PlayerDataSystem.GetMoney(player)
    if playerData[player.UserId] then
        return playerData[player.UserId].money
    end
    return 0
end

function PlayerDataSystem.MergeDefaults(savedData, defaults)
    local merged = table.clone(defaults)
    
    for key, value in pairs(savedData) do
        if typeof(value) == "table" and typeof(merged[key]) == "table" then
            merged[key] = PlayerDataSystem.MergeDefaults(value, merged[key])
        else
            merged[key] = value
        end
    end
    
    return merged
end

return PlayerDataSystem
