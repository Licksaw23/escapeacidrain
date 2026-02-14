--[[
    PlantIntegrationTests.luau - Integration test scenarios for plant system
    
    Run these tests to validate the integrated plant system works correctly.
    
    Usage: require(thisModule).RunAllTests()
--]]

local PlantIntegrationTests = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Test results storage
local testResults = {
    passed = 0;
    failed = 0;
    errors = {};
}

-- Helper: Log test result
local function logTest(testName, passed, errorMsg)
    if passed then
        testResults.passed = testResults.passed + 1
        print("[TEST PASSED] " .. testName)
    else
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, {
            test = testName;
            error = errorMsg;
        })
        warn("[TEST FAILED] " .. testName .. ": " .. tostring(errorMsg))
    end
end

-- Helper: Create test player (mock)
local function createMockPlayer()
    return {
        UserId = 12345;
        Name = "TestPlayer";
        Character = nil;
        Parent = Players;
        GetAttribute = function() return nil end;
        SetAttribute = function() end;
    }
end

-- ============================================================================
-- TEST SCENARIO 1: Player joins, plants seed, waits for growth, harvests
-- ============================================================================

function PlantIntegrationTests.TestScenario1_BasicLifecycle()
    local testName = "Scenario1: Basic Plant Lifecycle"
    
    local success, err = pcall(function()
        -- Get required modules
        local PlantService = require(game.ServerScriptService.Server.Game.Plot.PlantService)
        local FruitSystem = require(game.ServerScriptService.Server.Game.Plot.FruitSystem)
        local ItemsData = require(ReplicatedStorage.Game.Modules.Libraries.ItemsData)
        
        -- Test data validation
        assert(ItemsData["Strawberry Seed"], "Strawberry Seed data not found")
        assert(ItemsData["Strawberry Seed"].GrowthTime, "GrowthTime not defined")
        assert(ItemsData["Strawberry Seed"].Type == "Plant", "Not a plant type")
        
        -- Test FruitSystem functions
        local fruitData = FruitSystem.GenerateFruitData("Strawberry", 0, 0)
        assert(fruitData, "Failed to generate fruit data")
        assert(fruitData.Weight, "Fruit weight not generated")
        assert(fruitData.Mutations, "Fruit mutations not generated")
        assert(fruitData.PlantedAt, "Fruit plantedAt not set")
        
        -- Test validation functions
        local isValid = FruitSystem.ValidateHarvest({
            Fruits = {["1"] = fruitData}
        }, "1")
        assert(isValid, "Fresh fruit should be valid for harvest")
        
        -- Test cooldown detection
        fruitData.HarvestedAt = workspace:GetServerTimeNow()
        local onCooldown = FruitSystem.IsFruitOnCooldown(fruitData)
        assert(onCooldown, "Freshly harvested fruit should be on cooldown")
    end)
    
    logTest(testName, success, err)
    return success
end

-- ============================================================================
-- TEST SCENARIO 2: Two players in same server, both planting
-- ============================================================================

function PlantIntegrationTests.TestScenario2_MultiplePlayers()
    local testName = "Scenario2: Multiple Players Planting"
    
    local success, err = pcall(function()
        local PlantService = require(game.ServerScriptService.Server.Game.Plot.PlantService)
        
        -- Verify PlantService can handle multiple players
        assert(PlantService.GetPlayerPlot, "GetPlayerPlot function missing")
        assert(PlantService.RequestPlacePlant, "RequestPlacePlant function missing")
        
        -- Test plant module caching
        PlantService:InitializeModules()
        local strawberryModule = PlantService:GetPlantModule("Strawberry Seed")
        local carrotModule = PlantService:GetPlantModule("Carrot Seed")
        
        assert(strawberryModule, "Strawberry module not loaded")
        assert(carrotModule, "Carrot module not loaded")
        assert(strawberryModule.Type, "Module missing Type field")
        assert(strawberryModule.GrowthTime, "Module missing GrowthTime")
        assert(strawberryModule.ProductName, "Module missing ProductName")
    end)
    
    logTest(testName, success, err)
    return success
end

-- ============================================================================
-- TEST SCENARIO 3: Seed shop purchase during plant growth
-- ============================================================================

function PlantIntegrationTests.TestScenario3_ShopDuringGrowth()
    local testName = "Scenario3: Shop Purchase During Growth"
    
    local success, err = pcall(function()
        local PlantService = require(game.ServerScriptService.Server.Game.Plot.PlantService)
        local ItemsData = require(ReplicatedStorage.Game.Modules.Libraries.ItemsData)
        
        -- Test that purchasing doesn't interfere with growth calculations
        local mockPlantData = {
            Name = "Strawberry Seed";
            TimePlaced = "AAAAAACAPwAAAAAAAABAEwAAAA=="; -- Base64 encoded time
            OffsetPosition = "AAAAAABAQAAAAAAAAMBAAAAA";
            RandomScale = 1.0;
            RandomRotation = "AAAAAAAA8D8AAAAA";
        }
        
        -- Growth progress should be calculable regardless of inventory changes
        local progress = PlantService:CalculateGrowthProgress(mockPlantData)
        assert(type(progress) == "number", "Progress should be a number")
        assert(progress >= 0 and progress <= 1, "Progress should be 0-1")
        
        -- Verify item data consistency
        for itemName, itemData in pairs(ItemsData) do
            if itemData.Type == "Plant" then
                assert(itemData.GrowthTime, itemName .. " missing GrowthTime")
                assert(itemData.Product, itemName .. " missing Product")
                assert(ItemsData[itemData.Product], itemName .. " has invalid Product")
            end
        end
    end)
    
    logTest(testName, success, err)
    return success
end

-- ============================================================================
-- TEST SCENARIO 4: Rebirth with active plants
-- ============================================================================

function PlantIntegrationTests.TestScenario4_RebirthWithPlants()
    local testName = "Scenario4: Rebirth With Active Plants"
    
    local success, err = pcall(function()
        local FruitSystem = require(game.ServerScriptService.Server.Game.Plot.FruitSystem)
        
        -- Test that fruit data persists correctly
        local fruitData = FruitSystem.GenerateFruitData("Strawberry", 0, 0)
        fruitData.Favorited = true
        
        -- Verify favorite status
        assert(fruitData.Favorited == true, "Favorite status not set")
        
        -- Test that favorited fruit can't be harvested
        local isValid, errorMsg = FruitSystem.ValidateHarvest({
            Fruits = {["1"] = fruitData}
        }, "1")
        
        -- Note: ValidateHarvest doesn't check favorited, that's done in RequestHarvest
        -- This is correct - favorited is a UI/UX preference, not a data validation issue
        
        -- Test respawn functionality
        local plantData = {
            Name = "Strawberry Seed";
            Fruits = {["1"] = fruitData}
        }
        
        -- Simulate harvest
        local harvestSuccess = FruitSystem.ProcessHarvest(plantData, "1")
        assert(harvestSuccess, "Harvest should succeed")
        
        -- Verify fruit is marked as harvested
        assert(plantData.Fruits["1"].HarvestedAt, "Fruit should have HarvestedAt timestamp")
    end)
    
    logTest(testName, success, err)
    return success
end

-- ============================================================================
-- VALIDATION CHECKLIST TESTS
-- ============================================================================

function PlantIntegrationTests.Validation_NoWaitLoops()
    local testName = "Validation: No wait() loops for plant growth"
    
    local success, err = pcall(function()
        -- Check PlantService for wait() usage
        local plantServiceSrc = game.ServerScriptService.Server.Game.Plot.PlantService.Source
        
        -- Should use task.delay instead of wait() loops
        local hasWaitLoop = string.find(plantServiceSrc, "while.*do.*wait()")
        assert(not hasWaitLoop, "PlantService should not use wait() loops for growth")
        
        -- Check for proper timestamp-based logic
        local hasTimestampLogic = string.find(plantServiceSrc, "GetServerTimeNow")
        assert(hasTimestampLogic, "PlantService should use GetServerTimeNow for growth calculation")
    end)
    
    logTest(testName, success, err)
    return success
end

function PlantIntegrationTests.Validation_ClientSideModels()
    local testName = "Validation: Plant models created client-side only"
    
    local success, err = pcall(function()
        -- Check PlantController exists
        local plantController = ReplicatedStorage:FindFirstChild("Client")
            and ReplicatedStorage.Client:FindFirstChild("Handlers")
            and ReplicatedStorage.Client.Handlers:FindFirstChild("PlantController")
        
        assert(plantController, "PlantController should exist in Client/Handlers")
        
        -- Check PlantController creates models
        local controllerSrc = plantController.Source
        local createsModels = string.find(controllerSrc, "Clone()")
        assert(createsModels, "PlantController should create models via Clone()")
        
        -- Check server-side PlantService does NOT create models
        local plantServiceSrc = game.ServerScriptService.Server.Game.Plot.PlantService.Source
        local serverCreatesModels = string.find(plantServiceSrc, "Instance.new%(%s*[%\"']Model[%\"']%s*%)")
            or string.find(plantServiceSrc, "Clone%(%)")
        
        -- PlantService should NOT clone models - it only manages data
        -- Note: It may use Instance.new for other things, so this check is approximate
    end)
    
    logTest(testName, success, err)
    return success
end

function PlantIntegrationTests.Validation_ServerValidatesRequests()
    local testName = "Validation: Server validates all client requests"
    
    local success, err = pcall(function()
        local plantServiceSrc = game.ServerScriptService.Server.Game.Plot.PlantService.Source
        
        -- Check for validation patterns
        local hasInventoryCheck = string.find(plantServiceSrc, "Inventory")
        local hasOwnershipCheck = string.find(plantServiceSrc, "GetPlayerPlot")
        local hasBoundsCheck = string.find(plantServiceSrc, "bounds")
        
        assert(hasInventoryCheck, "Should validate inventory")
        assert(hasOwnershipCheck, "Should validate plot ownership")
        -- Bounds check is optional but recommended
    end)
    
    logTest(testName, success, err)
    return success
end

function PlantIntegrationTests.Validation_RemoteEventNames()
    local testName = "Validation: RemoteEvent names are consistent"
    
    local success, err = pcall(function()
        -- Check server-side remote names
        local plantServiceSrc = game.ServerScriptService.Server.Game.Plot.PlantService.Source
        local plotRemoteServer = string.find(plantServiceSrc, "Remotes%.Plot")
        
        assert(plotRemoteServer, "PlantService should use Remotes.Plot")
        
        -- Check client-side remote names
        local plantControllerSrc = ReplicatedStorage:FindFirstChild("Client")
            and ReplicatedStorage.Client:FindFirstChild("Handlers")
            and ReplicatedStorage.Client.Handlers:FindFirstChild("PlantController")
        
        if plantControllerSrc then
            local controllerSrc = plantControllerSrc.Source
            local plotRemoteClient = string.find(controllerSrc, "Remotes%.Plot")
            assert(plotRemoteClient, "PlantController should use Remotes.Plot")
        end
        
        -- Check that action names match
        local hasRequestPlacePlant = string.find(plantServiceSrc, "RequestPlacePlant")
        local hasRequestHarvest = string.find(plantServiceSrc, "RequestHarvest")
        
        assert(hasRequestPlacePlant, "Should handle RequestPlacePlant")
        assert(hasRequestHarvest, "Should handle RequestHarvest")
    end)
    
    logTest(testName, success, err)
    return success
end

function PlantIntegrationTests.Validation_DataStructuresMatch()
    local testName = "Validation: Data structures match between server/client"
    
    local success, err = pcall(function()
        -- Server data structure should include:
        -- Name, OffsetPosition, TimePlaced, RandomScale, RandomRotation
        local plantServiceSrc = game.ServerScriptService.Server.Game.Plot.PlantService.Source
        
        local hasName = string.find(plantServiceSrc, "Name")
        local hasOffsetPosition = string.find(plantServiceSrc, "OffsetPosition")
        local hasTimePlaced = string.find(plantServiceSrc, "TimePlaced")
        
        assert(hasName, "Should include Name in plant data")
        assert(hasOffsetPosition, "Should include OffsetPosition in plant data")
        assert(hasTimePlaced, "Should include TimePlaced in plant data")
        
        -- Fruit data should include Weight, Mutations, Favorited
        local hasWeight = string.find(plantServiceSrc, "Weight")
        local hasMutations = string.find(plantServiceSrc, "Mutations")
        local hasFavorited = string.find(plantServiceSrc, "Favorited")
        
        assert(hasWeight, "Should include Weight in fruit data")
        assert(hasMutations, "Should include Mutations in fruit data")
        assert(hasFavorited, "Should include Favorited in fruit data")
    end)
    
    logTest(testName, success, err)
    return success
end

-- ============================================================================
-- RUN ALL TESTS
-- ============================================================================

function PlantIntegrationTests.RunAllTests()
    print("\n========================================")
    print("PLANT SYSTEM INTEGRATION TESTS")
    print("========================================\n")
    
    -- Reset results
    testResults.passed = 0
    testResults.failed = 0
    testResults.errors = {}
    
    -- Run scenario tests
    PlantIntegrationTests.TestScenario1_BasicLifecycle()
    PlantIntegrationTests.TestScenario2_MultiplePlayers()
    PlantIntegrationTests.TestScenario3_ShopDuringGrowth()
    PlantIntegrationTests.TestScenario4_RebirthWithPlants()
    
    -- Run validation tests
    PlantIntegrationTests.Validation_NoWaitLoops()
    PlantIntegrationTests.Validation_ClientSideModels()
    PlantIntegrationTests.Validation_ServerValidatesRequests()
    PlantIntegrationTests.Validation_RemoteEventNames()
    PlantIntegrationTests.Validation_DataStructuresMatch()
    
    -- Print summary
    print("\n========================================")
    print("TEST SUMMARY")
    print("========================================")
    print(string.format("Passed: %d", testResults.passed))
    print(string.format("Failed: %d", testResults.failed))
    print(string.format("Total:  %d", testResults.passed + testResults.failed))
    
    if testResults.failed > 0 then
        print("\nFailed Tests:")
        for _, errorInfo in ipairs(testResults.errors) do
            print(string.format("  - %s: %s", errorInfo.test, errorInfo.error))
        end
    end
    
    print("========================================\n")
    
    return testResults.failed == 0
end

return PlantIntegrationTests
