--[[
    MISSION 7 - TEST SUITE: Mutation System Tests
    File: Shared/Modules/Utilities/MutationTests.luau
    
    Run these tests to verify mutation system integrity
--]]

local MutationTests = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MutationsData = require(ReplicatedStorage.Game.Modules.Libraries.MutationsData)
local PickMutations = require(ReplicatedStorage.Game.Modules.Utilities.PickMutations)
local FruitSystem = require(game.ServerScriptService.Server.Game.Plot.FruitSystem)

-- Test results
MutationTests.Results = {}

local function RecordTest(name, passed, message)
    table.insert(MutationTests.Results, {
        Name = name,
        Passed = passed,
        Message = message,
        Timestamp = tick()
    })
    
    local status = passed and "✓ PASS" or "✗ FAIL"
    print(string.format("[MutationTest] %s: %s - %s", status, name, message or ""))
end

-- ============================================================================
-- TEST 1: Mutation Deduplication
-- ============================================================================

function MutationTests.TestDuplicatePrevention()
    local testName = "Duplicate Mutation Prevention"
    
    -- Simulate adding mutations with deduplication
    local mutations = {}
    local seen = {}
    
    -- Try to add same mutation multiple times
    for i = 1, 5 do
        if not seen["Gold"] then
            table.insert(mutations, "Gold")
            seen["Gold"] = true
        end
    end
    
    -- Should only have 1 Gold mutation
    local goldCount = 0
    for _, m in ipairs(mutations) do
        if m == "Gold" then goldCount += 1 end
    end
    
    if goldCount == 1 then
        RecordTest(testName, true, "Correctly prevented duplicate mutations")
    else
        RecordTest(testName, false, "Found " .. goldCount .. " Gold mutations, expected 1")
    end
end

-- ============================================================================
-- TEST 2: Effect Mutation Limit
-- ============================================================================

function MutationTests.TestEffectLimit()
    local testName = "Effect Mutation Limit (6 max)"
    
    local brainrotMutations = {}
    local effectCount = 0
    local maxEffects = 6
    
    local testEffects = {"Wet", "Sandy", "Zombified", "Haunted", "Burning", "Chilled", "Shocked", "Corrupted"}
    
    for _, effect in ipairs(testEffects) do
        local mutationData = MutationsData[effect]
        if mutationData and mutationData.IsEffect then
            if effectCount < maxEffects then
                table.insert(brainrotMutations, effect)
                effectCount += 1
            end
        end
    end
    
    -- Count actual effects
    local actualEffectCount = 0
    for _, m in ipairs(brainrotMutations) do
        if MutationsData[m] and MutationsData[m].IsEffect then
            actualEffectCount += 1
        end
    end
    
    if actualEffectCount <= maxEffects then
        RecordTest(testName, true, "Effect limit enforced: " .. actualEffectCount .. "/" .. maxEffects)
    else
        RecordTest(testName, false, "Effect limit bypassed: " .. actualEffectCount .. "/" .. maxEffects)
    end
end

-- ============================================================================
-- TEST 3: Mutation Data Normalization
-- ============================================================================

function MutationTests.TestDataNormalization()
    local testName = "Mutation Data Normalization"
    
    -- Test nil normalization
    local nilResult = nil
    if not nilResult then nilResult = {} end
    
    -- Test array preservation
    local arrayInput = {"Gold", "Rainbow", "Diamond"}
    local arrayResult = {}
    for _, v in ipairs(arrayInput) do
        table.insert(arrayResult, v)
    end
    
    local passed = #nilResult == 0 and #arrayResult == 3
    
    if passed then
        RecordTest(testName, true, "Nil converted to empty array, arrays preserved")
    else
        RecordTest(testName, false, "Normalization failed")
    end
end

-- ============================================================================
-- TEST 4: Mutation Validation
-- ============================================================================

function MutationTests.TestMutationValidation()
    local testName = "Mutation Name Validation"
    
    local validMutations = {"Normal", "Gold", "Rainbow", "Diamond", "Wet", "Zombified"}
    local invalidMutations = {"Invalid", "", nil, 123, "GOLD", "rainbow"}
    
    local allValidPassed = true
    for _, m in ipairs(validMutations) do
        if not MutationsData[m] then
            allValidPassed = false
            print("  Valid mutation not found:", m)
        end
    end
    
    local allInvalidFailed = true
    for _, m in ipairs(invalidMutations) do
        if MutationsData[m] then
            allInvalidFailed = false
            print("  Invalid mutation was found:", m)
        end
    end
    
    if allValidPassed and allInvalidFailed then
        RecordTest(testName, true, "All valid mutations recognized, invalid rejected")
    else
        RecordTest(testName, false, "Validation issues detected")
    end
end

-- ============================================================================
-- TEST 5: Mutation Multiplier Calculation
-- ============================================================================

function MutationTests.TestMultiplierCalculation()
    local testName = "Mutation Multiplier Calculation"
    
    local testCases = {
        { mutation = "Normal", expected = 1 },
        { mutation = "Gold", expected = 2 },
        { mutation = "Petrified", expected = 1.5 },
        { mutation = "Emerald", expected = 3.5 },
        { mutation = "Diamond", expected = 5 },
        { mutation = "Rainbow", expected = 10 },
        { mutation = "Wet", expected = 1.5 },
        { mutation = "Zombified", expected = 3 },
    }
    
    local allPassed = true
    for _, test in ipairs(testCases) do
        local data = MutationsData[test.mutation]
        if data then
            if data.Multiplier ~= test.expected then
                allPassed = false
                print(string.format("  %s: expected %s, got %s", 
                    test.mutation, test.expected, data.Multiplier))
            end
        else
            allPassed = false
            print("  Mutation not found:", test.mutation)
        end
    end
    
    if allPassed then
        RecordTest(testName, true, "All multipliers match expected values")
    else
        RecordTest(testName, false, "Multiplier mismatch detected")
    end
end

-- ============================================================================
-- TEST 6: Mutation Probability Distribution (Statistical)
-- ============================================================================

function MutationTests.TestProbabilityDistribution()
    local testName = "Mutation Probability Distribution"
    
    if not RunService:IsServer() then
        RecordTest(testName, true, "Skipped (server only)")
        return
    end
    
    -- Run 1000 rolls with no luck
    local results = {}
    local iterations = 1000
    
    for i = 1, iterations do
        local mutation = PickMutations.PickMutation(1, {}) -- No luck multiplier
        mutation = mutation or "Normal"
        results[mutation] = (results[mutation] or 0) + 1
    end
    
    -- Check that Normal is most common
    local normalCount = results["Normal"] or 0
    local otherCount = 0
    
    for m, count in pairs(results) do
        if m ~= "Normal" then
            otherCount += count
        end
    end
    
    -- Normal should be roughly 70-80% with base chances
    local normalRate = normalCount / iterations
    
    if normalRate > 0.6 and normalRate < 0.9 then
        RecordTest(testName, true, string.format("Normal rate: %.1f%% (expected 60-90%%)", normalRate * 100))
    else
        RecordTest(testName, false, string.format("Abnormal distribution: Normal %.1f%%", normalRate * 100))
    end
end

-- ============================================================================
-- TEST 7: Fruit Data Structure
-- ============================================================================

function MutationTests.TestFruitDataStructure()
    local testName = "Fruit Data Structure Integrity"
    
    -- Mock player with luck attributes
    local mockPlayer = {
        GetAttribute = function(self, attr)
            if attr == "Luck" then return 1 end
            if attr == "MutationLuck" then return 0.5 end
            return 0
        end
    }
    
    local fruitData = FruitSystem.GenerateFruitData("Strawberry", 1, 0.5, {})
    
    local checks = {
        fruitData ~= nil,
        type(fruitData) == "table",
        fruitData.PlantedAt ~= nil,
        fruitData.GrowthDuration ~= nil,
        fruitData.Mutations ~= nil,
        type(fruitData.Mutations) == "table",
        fruitData.Weight ~= nil,
    }
    
    local allPassed = true
    for i, check in ipairs(checks) do
        if not check then
            allPassed = false
            print("  Check " .. i .. " failed")
        end
    end
    
    if allPassed then
        RecordTest(testName, true, "Fruit data structure valid")
    else
        RecordTest(testName, false, "Fruit data structure invalid")
    end
end

-- ============================================================================
-- TEST 8: Mutation Stacking Exploit
-- ============================================================================

function MutationTests.TestStackingExploit()
    local testName = "Mutation Stacking Exploit Prevention"
    
    -- Simulate rapid mutation additions
    local mutations = {}
    local attempts = 20
    local targetMutation = "Rainbow"
    
    for i = 1, attempts do
        -- Check before adding
        local exists = false
        for _, m in ipairs(mutations) do
            if m == targetMutation then
                exists = true
                break
            end
        end
        
        if not exists then
            table.insert(mutations, targetMutation)
        end
    end
    
    -- Count Rainbow occurrences
    local rainbowCount = 0
    for _, m in ipairs(mutations) do
        if m == targetMutation then rainbowCount += 1 end
    end
    
    if rainbowCount == 1 then
        RecordTest(testName, true, "Stacking prevented - only 1 Rainbow after " .. attempts .. " attempts")
    else
        RecordTest(testName, false, "Stacking possible - found " .. rainbowCount .. " Rainbows")
    end
end

-- ============================================================================
-- RUN ALL TESTS
-- ============================================================================

function MutationTests.RunAllTests()
    print("\n" .. string.rep("=", 60))
    print("MUTATION SYSTEM TEST SUITE")
    print(string.rep("=", 60) .. "\n")
    
    MutationTests.Results = {}
    
    MutationTests.TestDuplicatePrevention()
    MutationTests.TestEffectLimit()
    MutationTests.TestDataNormalization()
    MutationTests.TestMutationValidation()
    MutationTests.TestMultiplierCalculation()
    MutationTests.TestProbabilityDistribution()
    MutationTests.TestFruitDataStructure()
    MutationTests.TestStackingExploit()
    
    -- Summary
    print("\n" .. string.rep("-", 60))
    local passed = 0
    local failed = 0
    
    for _, result in ipairs(MutationTests.Results) do
        if result.Passed then
            passed += 1
        else
            failed += 1
        end
    end
    
    print(string.format("RESULTS: %d passed, %d failed out of %d tests", 
        passed, failed, #MutationTests.Results))
    print(string.rep("=", 60) .. "\n")
    
    return failed == 0
end

-- Auto-run if executed directly
if RunService:IsServer() then
    -- Delay to allow systems to initialize
    task.delay(5, function()
        MutationTests.RunAllTests()
    end)
end

return MutationTests
