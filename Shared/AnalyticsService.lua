-- AnalyticsService.lua
-- Place this in ServerScriptService or ReplicatedStorage
-- This handles all analytics tracking for FeedTheBrainrots

local AnalyticsService = {}

-- CONFIG - UPDATE THESE VALUES
local CONFIG = {
    BASE_URL = "https://analytics.arcadias.games",  -- Your analytics server
    API_KEY = "flowandroadaregay1234567",            -- Your API key
    GAME_ID = "feedthebrainrots",                    -- Your game ID
    DEBUG = true                                      -- Set to false in production
}

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Internal state
local playerSessions = {}
local isStudio = RunService:IsStudio()

-- Debug print
local function log(...)
    if CONFIG.DEBUG then
        print("[Analytics]", ...)
    end
end

-- Send HTTP request to analytics server
local function sendRequest(endpoint, data)
    if isStudio then
        log("Studio mode - would send to", endpoint, data)
        return true
    end
    
    local success, result = pcall(function()
        local url = CONFIG.BASE_URL .. endpoint
        local payload = HttpService:JSONEncode(data)
        
        return HttpService:PostAsync(
            url,
            payload,
            Enum.HttpContentType.ApplicationJson,
            false,
            {["X-API-Key"] = CONFIG.API_KEY}
        )
    end)
    
    if success then
        log("Sent to", endpoint)
    else
        warn("[Analytics] Failed to send to", endpoint, ":", result)
    end
    
    return success
end

-- ============================================
-- PLAYER JOIN/LEAVE TRACKING
-- ============================================

-- Call this when a player joins the game
function AnalyticsService.PlayerJoined(player)
    local userId = tostring(player.UserId)
    local timestamp = os.time() * 1000
    
    playerSessions[userId] = {
        joinTime = tick(),
        joinTimestamp = timestamp
    }
    
    -- Send join event
    sendRequest("/api/player/join", {
        apiKey = CONFIG.API_KEY,
        gameId = CONFIG.GAME_ID,
        userId = userId,
        timestamp = timestamp,
        placeId = game.PlaceId,
        jobId = game.JobId
    })
    
    log("Player joined:", player.Name, "(", userId, ")")
end

-- Call this when a player leaves the game
function AnalyticsService.PlayerLeft(player)
    local userId = tostring(player.UserId)
    local session = playerSessions[userId]
    
    if session then
        local sessionDuration = tick() - session.joinTime
        local timestamp = os.time() * 1000
        
        -- Send leave event
        sendRequest("/api/player/leave", {
            apiKey = CONFIG.API_KEY,
            gameId = CONFIG.GAME_ID,
            userId = userId,
            timestamp = timestamp,
            sessionDuration = math.floor(sessionDuration)
        })
        
        playerSessions[userId] = nil
        log("Player left:", player.Name, "Duration:", sessionDuration, "seconds")
    end
end

-- ============================================
-- REVENUE/PURCHASE TRACKING - IMPORTANT!
-- ============================================

-- THIS IS WHERE YOU TRACK PURCHASES
-- Call this function whenever a player buys something!

--[[
    HOW TO USE:
    
    1. For gamepass purchases (MarketplaceService):
    
    local MarketplaceService = game:GetService("MarketplaceService")
    
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        
        -- YOUR PURCHASE LOGIC HERE
        -- Give the player the item they bought
        
        -- TRACK THE PURCHASE
        AnalyticsService.TrackPurchase(
            player,
            receiptInfo.CurrencySpent,  -- Amount in Robux
            "Gamepass Name",            -- Product name
            tostring(receiptInfo.ProductId),  -- Product ID
            "Robux"                     -- Currency type
        )
        
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    2. For developer products:
    
    Same as above - ProcessReceipt handles both gamepasses and dev products
    
    3. For custom purchases (like trading coins for items):
    
    AnalyticsService.TrackPurchase(
        player,
        100,                    -- Amount (e.g., 100 coins worth)
        "Premium Seeds Pack",   -- Product name
        "seeds_pack_001",       -- Your internal product ID
        "Coins"                 -- Your currency name
    )
--]]

function AnalyticsService.TrackPurchase(player, amount, productName, productId, currency)
    if not player or not amount then
        warn("[Analytics] TrackPurchase called with invalid parameters")
        return
    end
    
    local userId = tostring(player.UserId)
    local timestamp = os.time() * 1000
    
    -- Send purchase event to server
    sendRequest("/api/player/purchase", {
        apiKey = CONFIG.API_KEY,
        gameId = CONFIG.GAME_ID,
        userId = userId,
        timestamp = timestamp,
        amount = amount,
        productName = productName or "Unknown",
        productId = productId or "",
        currency = currency or "Robux"
    })
    
    log("Purchase tracked:", player.Name, "bought", productName, "for", amount, currency)
end

-- ============================================
-- CONVENIENCE METHODS FOR COMMON SCENARIOS
-- ============================================

-- Track a gamepass purchase (wraps TrackPurchase with defaults)
function AnalyticsService.TrackGamepassPurchase(player, gamepassId, gamepassName, price)
    AnalyticsService.TrackPurchase(
        player,
        price or 0,
        gamepassName or ("Gamepass #" .. gamepassId),
        tostring(gamepassId),
        "Robux"
    )
end

-- Track a developer product purchase
function AnalyticsService.TrackDevProductPurchase(player, productId, productName, price)
    AnalyticsService.TrackPurchase(
        player,
        price or 0,
        productName or ("Product #" .. productId),
        tostring(productId),
        "Robux"
    )
end

-- Track in-game currency spent (for analytics on economy health)
function AnalyticsService.TrackCurrencySpent(player, amount, itemName, currencyName)
    -- This tracks "virtual" purchases - useful for seeing what players value
    AnalyticsService.TrackPurchase(
        player,
        amount,
        itemName or "Unknown Item",
        "",
        currencyName or "Coins"
    )
end

-- ============================================
-- FUNNEL TRACKING
-- ============================================

--[[
    HOW TO USE:
    
    Track player progression through a series of steps (tutorial, onboarding, etc.)
    
    Example - Tutorial Funnel:
    
    -- Step 1: Player joins
    AnalyticsService.TrackFunnel(player, "Tutorial", "Started", 1, 5)
    
    -- Step 2: Player completes first task
    AnalyticsService.TrackFunnel(player, "Tutorial", "Planted First Seed", 2, 5)
    
    -- Step 3: Player harvests first fruit
    AnalyticsService.TrackFunnel(player, "Tutorial", "First Harvest", 3, 5)
    
    -- Step 4: Player sells first fruit
    AnalyticsService.TrackFunnel(player, "Tutorial", "First Sale", 4, 5)
    
    -- Step 5: Tutorial complete
    AnalyticsService.TrackFunnel(player, "Tutorial", "Completed", 5, 5)
    
    Parameters:
    - player: The Player object
    - funnelName: Name of the funnel (e.g., "Tutorial", "FirstPurchase", "Rebirth")
    - stepName: Name of this specific step
    - stepNumber: Current step number (1-based)
    - totalSteps: Total number of steps in the funnel
--]]

function AnalyticsService.TrackFunnel(player, funnelName, stepName, stepNumber, totalSteps)
    if not player or not funnelName or not stepName then
        warn("[Analytics] TrackFunnel called with invalid parameters")
        return
    end
    
    local userId = tostring(player.UserId)
    local timestamp = os.time() * 1000
    
    sendRequest("/api/funnel/track", {
        apiKey = CONFIG.API_KEY,
        gameId = CONFIG.GAME_ID,
        userId = userId,
        timestamp = timestamp,
        funnelName = funnelName,
        stepName = stepName,
        stepNumber = stepNumber,
        totalSteps = totalSteps
    })
    
    log("Funnel tracked:", player.Name, "-", funnelName, "Step", stepNumber .. "/" .. totalSteps, "(" .. stepName .. ")")
end

-- ============================================
-- SETUP - CONNECT EVENTS
-- ============================================

function AnalyticsService.Init()
    -- Connect player join/leave
    Players.PlayerAdded:Connect(AnalyticsService.PlayerJoined)
    Players.PlayerRemoving:Connect(AnalyticsService.PlayerLeft)
    
    -- Track existing players (for studio testing)
    for _, player in ipairs(Players:GetPlayers()) do
        AnalyticsService.PlayerJoined(player)
    end
    
    -- Periodic stats update
    spawn(function()
        while true do
            wait(60) -- Update every minute
            
            local activeUsers = #Players:GetPlayers()
            
            sendRequest("/api/stats/update", {
                apiKey = CONFIG.API_KEY,
                gameId = CONFIG.GAME_ID,
                stats = {
                    concurrentUsers = activeUsers,
                    totalVisits = 0  -- Server doesn't use this directly
                }
            })
        end
    end)
    
    log("Analytics Service initialized")
end

-- Initialize
AnalyticsService.Init()

-- Return the service for use in other scripts
return AnalyticsService
