--[[
    BUG FIX 7.2: Receipt Deduplication
    File: Server/Game/Purchases.luau
    Issue: Roblox can send same receipt multiple times, causing double grants
    
    This fix adds receipt tracking to prevent duplicate processing.
--]]

-- STEP 1: Add receipt tracking table at the top of PurchaseHandler
--[[ Add after: local registeredProducts = {} --]]

local processedReceipts = {} -- Cache of processed receipt IDs
local RECEIPT_CACHE_SIZE = 1000 -- Maximum receipts to track
local RECEIPT_CACHE_TIME = 600 -- Keep receipts for 10 minutes

-- STEP 2: Add receipt tracking functions
--[[ Add before: local function processReceipt(receipt) --]]

-- Check if receipt was already processed
local function isReceiptProcessed(purchaseId)
    local receiptData = processedReceipts[purchaseId]
    if not receiptData then
        return false
    end
    
    -- Check if cache entry expired
    if tick() - receiptData.time > RECEIPT_CACHE_TIME then
        processedReceipts[purchaseId] = nil
        return false
    end
    
    return true
end

-- Mark receipt as processed
local function markReceiptProcessed(purchaseId, playerId, productId)
    -- Clean old entries if cache is full
    local count = 0
    for _ in pairs(processedReceipts) do
        count += 1
    end
    
    if count >= RECEIPT_CACHE_SIZE then
        -- Remove oldest 20% of entries
        local currentTime = tick()
        local sorted = {}
        for id, data in pairs(processedReceipts) do
            table.insert(sorted, {id = id, time = data.time})
        end
        table.sort(sorted, function(a, b) return a.time < b.time end)
        
        local toRemove = math.floor(RECEIPT_CACHE_SIZE * 0.2)
        for i = 1, toRemove do
            processedReceipts[sorted[i].id] = nil
        end
    end
    
    processedReceipts[purchaseId] = {
        time = tick(),
        playerId = playerId,
        productId = productId
    }
end

-- STEP 3: Modify processReceipt function
--[[ In processReceipt(receipt), add after validation --]]

local function processReceipt(receipt)
    -- Validate receipt structure
    local isValid, validationError = validateReceipt(receipt)
    if not isValid then
        logError("Receipt Validation", validationError, receipt)
        return PurchaseResult.NotProcessedYet
    end
    
    -- NEW: Check for duplicate receipt
    if isReceiptProcessed(receipt.PurchaseId) then
        warn(string.format(
            "[PurchaseHandler] Duplicate receipt detected | Player: %s | Product: %d | PurchaseId: %s",
            receipt.PlayerId,
            receipt.ProductId,
            receipt.PurchaseId
        ))
        return PurchaseResult.PurchaseGranted -- Already processed successfully
    end
    
    -- ... rest of existing processReceipt code ...
    
    -- Check if handler successfully granted the purchase
    if handlerResult == true then
        -- NEW: Mark receipt as processed BEFORE returning
        markReceiptProcessed(receipt.PurchaseId, receipt.PlayerId, receipt.ProductId)
        logSuccess(receipt)
        return PurchaseResult.PurchaseGranted
    else
        logError("Handler Result", "Handler returned false (purchase not granted)", receipt)
        return PurchaseResult.NotProcessedYet
    end
end

-- STEP 4: Add persistent receipt storage (optional but recommended)
--[[ For maximum safety, also store in DataStore --]]

local DataStoreService = game:GetService("DataStoreService")
local ReceiptStore = DataStoreService:GetDataStore("ProcessedReceipts")

local function persistReceipt(purchaseId, playerId, productId)
    task.spawn(function()
        local success, err = pcall(function()
            ReceiptStore:SetAsync(purchaseId, {
                playerId = playerId,
                productId = productId,
                timestamp = os.time()
            })
        end)
        if not success then
            warn("[PurchaseHandler] Failed to persist receipt:", err)
        end
    end)
end

local function isReceiptPersisted(purchaseId)
    local success, data = pcall(function()
        return ReceiptStore:GetAsync(purchaseId)
    end)
    return success and data ~= nil
end

return {}
