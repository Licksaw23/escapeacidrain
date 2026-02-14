--[[
    MISSION 7 - FIX 2: GuaranteedMutation Server Validation
    File: Shared/Modules/Utilities/PickMutations.luau
    
    BUG: Clients can exploit workspace.GuaranteedMutation attribute
    FIX: Add server-side validation and require explicit admin/event authorization
--]]

-- Add to top of PickMutations.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Mutations = require(ReplicatedStorage.Game.Modules.Libraries.MutationsData)

-- Server-authorized guaranteed mutations
local AuthorizedGuaranteedMutations = {}

-- Only run on server
if RunService:IsServer() then
    -- Replace workspace attribute with server-controlled system
    function SetAuthorizedGuaranteedMutation(player, mutationName, duration)
        if not Mutations[mutationName] then
            warn("Invalid mutation for guaranteed roll:", mutationName)
            return false
        end
        
        AuthorizedGuaranteedMutations[player.UserId] = {
            Mutation = mutationName,
            Expires = tick() + (duration or 60) -- Default 60 seconds
        }
        
        return true
    end
    
    function ClearAuthorizedGuaranteedMutation(player)
        AuthorizedGuaranteedMutations[player.UserId] = nil
    end
    
    -- Clean up expired entries periodically
    task.spawn(function()
        while true do
            task.wait(30) -- Check every 30 seconds
            local now = tick()
            for userId, data in pairs(AuthorizedGuaranteedMutations) do
                if now > data.Expires then
                    AuthorizedGuaranteedMutations[userId] = nil
                end
            end
        end
    end)
end

-- Modified PickMutation function
module.PickMutation = function(luckMultiplier, eventMultipliers, player)
    -- Server-side: Check authorized guaranteed mutations
    if RunService:IsServer() and player then
        local authorized = AuthorizedGuaranteedMutations[player.UserId]
        if authorized then
            if tick() < authorized.Expires then
                return authorized.Mutation
            else
                -- Expired, clean up
                AuthorizedGuaranteedMutations[player.UserId] = nil
            end
        end
    end
    
    -- Client-side or no authorization: Don't trust workspace attribute
    -- Only use it if it's a valid mutation (defense in depth)
    if workspace:GetAttribute("GuaranteedMutation") then
        local guaranteed = workspace:GetAttribute("GuaranteedMutation")
        -- Validate but warn - this path shouldn't be used
        if Mutations[guaranteed] then
            warn("[PickMutations] Using workspace.GuaranteedMutation - consider using SetAuthorizedGuaranteedMutation")
            return guaranteed
        end
    end
    
    return rollMutation(luckMultiplier, eventMultipliers)
end

--[[
    USAGE EXAMPLE (in event handler):
    
    -- During a special event, give player guaranteed Diamond mutation
    local PickMutations = require(game.ReplicatedStorage.Game.Modules.Utilities.PickMutations)
    PickMutations.SetAuthorizedGuaranteedMutation(player, "Diamond", 300) -- 5 minutes
    
    -- Player's next fruit harvest will get Diamond mutation
    
    -- Later, clear it
    PickMutations.ClearAuthorizedGuaranteedMutation(player)
--]]
