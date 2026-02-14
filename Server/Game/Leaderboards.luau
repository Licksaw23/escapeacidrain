-- Server Script for Leaderboard System
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local UpdateLeaderboardRemote = game.ReplicatedStorage.Remotes.UpdateLeaderboard
local LeaderboardStore = DataStoreService:GetOrderedDataStore("PlayerLeaderboards")

local LeaderboardModule = {}

-- Configuration
LeaderboardModule.LEADERBOARD_CATEGORIES = {
	"Playtime",      -- Category 1
	"Orders",        -- Category 2
	"Cash",          -- Category 3
}

local LEADERBOARD_SIZE = 10 -- Top 10 players
local UPDATE_INTERVAL = 90 -- Update every 90 seconds

-- Cache for leaderboard data
local leaderboardCache = {}

-- Initialize cache for each category
for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
	leaderboardCache[category] = {}
end

-- Function to get leaderboard data for a category
function LeaderboardModule.GetLeaderboardData(category)
	local leaderboardData = {}
	local success, errorMsg = pcall(function()
		-- Get sorted data with min/max values for this specific category
		local pages = LeaderboardStore:GetSortedAsync(false, LEADERBOARD_SIZE)
		local data = pages:GetCurrentPage()

		local place = 1  -- Track place within this category
		for _, entry in ipairs(data) do
			-- Parse the key (format: "CategoryName_UserID")
			local parts = string.split(entry.key, "_")
			if parts[1] == category then
				local userId = tonumber(parts[2])
				if userId then
					local success2, username = pcall(function()
						return Players:GetNameFromUserIdAsync(userId)
					end)

					if success2 then
						table.insert(leaderboardData, {
							Place = place,  -- Use category-specific place
							ID = userId,
							Name = username,
							Amount = entry.value
						})
						place = place + 1

						-- Stop once we have enough entries for this category
						if place > LEADERBOARD_SIZE then
							break
						end
					end
				end
			end
		end
	end)

	if not success then
		warn("Error fetching leaderboard data for " .. category .. ": " .. errorMsg)
	end

	return leaderboardData
end

-- Function to update a player's leaderboard stat
function LeaderboardModule.UpdatePlayerStat(userId, category, amount)
	local key = category .. "_" .. tostring(userId)

	local success, errorMsg = pcall(function()
		LeaderboardStore:SetAsync(key, amount)
	end)

	if not success then
		warn("Error updating leaderboard stat for user " .. userId .. ": " .. errorMsg)
	end

	return success
end

-- Function to check if player is in leaderboard
function LeaderboardModule.IsPlayerInLeaderboard(userId, category)
	local key = category .. "_" .. tostring(userId)

	local success, currentValue = pcall(function()
		return LeaderboardStore:GetAsync(key)
	end)

	if success and currentValue ~= nil then
		return true, currentValue  -- They exist, return their current value
	else
		return false, nil  -- They don't exist or error occurred
	end
end

-- Function to refresh all leaderboards
function LeaderboardModule.RefreshAllLeaderboards()
	for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
		local data = LeaderboardModule.GetLeaderboardData(category)
		leaderboardCache[category] = data
	end

	-- Send updated data to all clients
	for _, player in ipairs(Players:GetPlayers()) do
		for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
			UpdateLeaderboardRemote:FireClient(
				player, 
				category, 
				leaderboardCache[category]
			)
		end
	end
end

-- Function to update player stat (call this from your normal data system)
function LeaderboardModule.UpdateLeaderboardStat(player, category, newAmount)
	if table.find(LeaderboardModule.LEADERBOARD_CATEGORIES, category) then
		LeaderboardModule.UpdatePlayerStat(player.UserId, category, newAmount)
	end
end

-- Handle client requests for leaderboard data
UpdateLeaderboardRemote.OnServerEvent:Connect(function(player, category)
	if table.find(LeaderboardModule.LEADERBOARD_CATEGORIES, category) then
		UpdateLeaderboardRemote:FireClient(player, category, leaderboardCache[category])
	end
end)

-- Initial leaderboard load
LeaderboardModule.RefreshAllLeaderboards()

task.spawn(function()
	-- Periodic updates
	while true do
		task.wait(UPDATE_INTERVAL)
		LeaderboardModule.RefreshAllLeaderboards()
	end
end)

-- When player joins, send them current leaderboard data
Players.PlayerAdded:Connect(function(player)
	task.wait(1) -- Small delay to ensure client is ready
	for _, category in ipairs(LeaderboardModule.LEADERBOARD_CATEGORIES) do
		UpdateLeaderboardRemote:FireClient(player, category, leaderboardCache[category])
	end
end)

return LeaderboardModule