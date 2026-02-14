--[[
    BUG FIX 1: Order Persistence
    File: Server/Game/Plot/init.luau
    Issue: Orders are lost on server shutdown/player leave
    
    This fix adds order persistence to player data.
--]]

-- STEP 1: Update StarterData.luau to include ActiveOrders
--[[ Add to Server/Data/StarterData.luau:
    ActiveOrders = {}; -- Persist active orders
--]]

-- STEP 2: Add order persistence functions to Plot module
-- Insert these functions into the plot table in Plot/init.luau

--[[
    Saves all active orders to player data for persistence
    Call this in plot:Terminate() and before rebirth
--]]
function plot:SaveOrdersToData()
    local ordersToSave = {}
    
    for orderID, orderData in pairs(self.Orders) do
        -- Only save if brainrot still exists
        if self.Active[orderID] then
            ordersToSave[orderID] = {
                Requirements = orderData.Requirements,
                Currents = orderData.Currents,
                Mutations = orderData.Mutations,
                Weight = orderData.Weight,
                TimeRemaining = orderData.TimeRemaining,
                MaxTime = orderData.MaxTime,
                BrainrotName = self.Active[orderID].Name,
                Path = self.Active[orderID].Path,
                Index = self.Active[orderID].Index
            }
        end
    end
    
    self.OwnerReplica:SetValue({"ActiveOrders"}, ordersToSave)
end

--[[
    Restores orders from player data on plot initialization
    Call this after plot setup in plot.new()
--]]
function plot:RestoreOrdersFromData()
    local savedOrders = self.OwnerData.ActiveOrders
    if not savedOrders or next(savedOrders) == nil then
        return
    end
    
    for orderID, orderData in pairs(savedOrders) do
        -- Only restore if we can find the brainrot
        if self.Active[orderID] then
            -- Restore order data
            self.Orders[orderID] = {
                Requirements = orderData.Requirements,
                Currents = orderData.Currents or {},
                Mutations = orderData.Mutations or {},
                Weight = orderData.Weight or 1,
                TimeRemaining = orderData.TimeRemaining or 30,
                MaxTime = orderData.MaxTime or 30,
                Delay = nil -- Will be recreated
            }
            
            -- Restore current order reference
            if orderData.Path then
                self.CurrentOrder[orderData.Path] = {
                    Brainrot = orderData.BrainrotName,
                    BrainrotID = orderID,
                    Cache = self.Orders[orderID],
                    Index = orderData.Index,
                    Weight = orderData.Weight,
                    Mutations = orderData.Mutations
                }
            end
            
            -- Restart the timer
            self:StartOrderTimer(orderID, orderData.Path)
        end
    end
    
    -- Clear saved orders after restoration
    self.OwnerReplica:SetValue({"ActiveOrders"}, {})
end

--[[
    Starts a timer for an active order
--]]
function plot:StartOrderTimer(brainrotID, path)
    local orderCache = self.Orders[brainrotID]
    if not orderCache then return end
    
    local function IsOrderComplete(cache)
        for fruitName, requiredAmount in pairs(cache.Requirements) do
            local currentAmount = cache.Currents[fruitName] and #cache.Currents[fruitName] or 0
            if currentAmount < requiredAmount then
                return false
            end
        end
        return true
    end
    
    -- Heartbeat timer system
    local timerConnection
    timerConnection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
        if not self.Active[brainrotID] or not self.Orders[brainrotID] then
            if timerConnection then
                timerConnection:Disconnect()
            end
            return
        end
        
        orderCache.TimeRemaining -= deltaTime
        
        if orderCache.TimeRemaining <= 0 then
            timerConnection:Disconnect()
            
            if IsOrderComplete(orderCache) then
                self.Functions["CompleteOrder"](path, true)
            else
                self:DestroyBrainrot(brainrotID, path, orderCache.Index, nil, true)
            end
        end
    end)
    
    self.Connections[brainrotID.."Timer"] = timerConnection
end

-- STEP 3: Modify plot:Terminate() to save orders
--[[ In plot:Terminate(), add at the beginning:
    self:SaveOrdersToData()
--]]

-- STEP 4: Call RestoreOrdersFromData after plot initialization
--[[ In plot.new(), after setting up desks, add:
    task.delay(2, function()
        newPlot:RestoreOrdersFromData()
    end)
--]]

return {}
