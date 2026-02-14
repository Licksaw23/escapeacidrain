--[[
    MISSION 7 - FIX 5: Mutation Apply Model Validation
    File: Shared/Modules/Libraries/MutationsData/init.luau
    
    BUG: applyParticle silently fails if model has no Handle/RootPart
    FIX: Add proper validation and warnings
--]]

local mUtil = require(script.MutationUtil)

local function applyParticle(model, particle)
    -- NEW: Validate model exists
    if not model or typeof(model) ~= "Instance" then
        warn("[applyParticle] Invalid model:", model)
        return false
    end
    
    if not model:IsDescendantOf(game) then
        warn("[applyParticle] Model not in game hierarchy:", model:GetFullName())
        return false
    end

    if model:IsA("Tool") then
        model.PrimaryPart = model:FindFirstChild("Handle")
    end

    if not model.PrimaryPart then
        if model:FindFirstChild("RootPart") then
            model.PrimaryPart = model.RootPart
        else
            -- NEW: Try to find any BasePart to use as primary
            local firstPart = model:FindFirstChildWhichIsA("BasePart")
            if firstPart then
                warn("[applyParticle] Model has no Handle/RootPart, using:", firstPart.Name)
                model.PrimaryPart = firstPart
            else
                warn("[applyParticle] Model has no valid parts for mutation VFX:", model:GetFullName())
                return false
            end
        end
    end
    
    -- NEW: Validate particle exists
    local particleTemplate = script.MutationVFX:FindFirstChild(particle)
    if not particleTemplate then
        warn("[applyParticle] Particle template not found:", particle)
        return false
    end

    local burningPart = particleTemplate:Clone()
    burningPart.Anchored = false
    burningPart.CanCollide = false
    burningPart.Massless = true
    burningPart.Name = "MUTATIONVFX"

    local boundingTable = mUtil.GetExactBoundingBox(model)
    if not boundingTable then
        warn("[applyParticle] Failed to get bounding box for:", model:GetFullName())
        burningPart:Destroy()
        return false
    end
    
    local bboxSize = boundingTable.Size
    local pos = boundingTable.Position

    burningPart.Size = bboxSize / 1.5
    local root = model.PrimaryPart
    local look = root.CFrame.LookVector
    local yaw = math.atan2(-look.X, -look.Z)

    burningPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
    burningPart.Parent = model

    local weld = Instance.new("Motor6D") 
    weld.Part0 = burningPart 
    weld.Part1 = root 
    weld.C0 = burningPart.CFrame:ToObjectSpace(root.CFrame)
    weld.Parent = burningPart 
    
    mUtil.ResizeAllParticles(burningPart, bboxSize.Y / 10.8963)
    
    return true  -- NEW: Return success status
end

-- ============================================================================
-- NEW: Mutation Validation Helper
-- ============================================================================

local function ValidateMutation(mutationName)
    if type(mutationName) ~= "string" then
        warn("[ValidateMutation] Mutation name must be string, got:", type(mutationName))
        return false
    end
    
    local mutationData = {
        ["Normal"] = true,
        ["Gold"] = true,
        ["Petrified"] = true,
        ["Emerald"] = true,
        ["Diamond"] = true,
        ["Rainbow"] = true,
        ["Wet"] = true,
        ["Sandy"] = true,
        ["Zombified"] = true,
        ["Haunted"] = true,
        ["Burning"] = true,
        ["Chilled"] = true,
        ["Shocked"] = true,
        ["Corrupted"] = true,
    }
    
    if not mutationData[mutationName] then
        warn("[ValidateMutation] Unknown mutation:", mutationName)
        return false
    end
    
    return true
end

-- ============================================================================
-- UPDATED: Safe Apply Function for All Mutations
-- ============================================================================

local function SafeApply(mutationName, model, requiredParent)
    if not ValidateMutation(mutationName) then
        return false
    end
    
    local mutationData = {
        ["Normal"] = { Multiplier = 1 },
        ["Gold"] = { 
            Multiplier = 2,
            Apply = function(m) mUtil.Tint(m, Color3.fromRGB(255, 221, 26)) end
        },
        ["Petrified"] = {
            Multiplier = 1.5,
            Apply = function(m) 
                mUtil.Tint(m, Color3.fromRGB(138, 138, 138))
                mUtil.Material(m, Enum.Material.Concrete)
            end
        },
        ["Emerald"] = {
            Multiplier = 3.5,
            Apply = function(m)
                mUtil.Tint(m, Color3.fromRGB(61, 252, 58))
                mUtil.Material(m, Enum.Material.Foil)
            end
        },
        ["Diamond"] = {
            Multiplier = 5,
            Apply = function(m) mUtil.Tint(m, Color3.fromRGB(29, 214, 255)) end
        },
        ["Rainbow"] = {
            Multiplier = 10,
            Apply = function(m, parent)
                -- Rainbow gradient implementation
                local Gradient3 = {
                    Color3.fromRGB(255, 0, 0),
                    Color3.fromRGB(255, 127, 0),
                    Color3.fromRGB(255, 255, 0),
                    Color3.fromRGB(0, 255, 0),
                    Color3.fromRGB(0, 127, 255),
                    Color3.fromRGB(75, 0, 130),
                    Color3.fromRGB(148, 0, 211)
                }

                task.spawn(function()
                    local index = 1
                    local progress = 0
                    local neededParent = parent or workspace

                    while m:IsDescendantOf(neededParent) do
                        local currentColor = Gradient3[index]
                        local nextIndex = index % #Gradient3 + 1
                        local nextColor = Gradient3[nextIndex]
                        local blendedColor = currentColor:Lerp(nextColor, progress)
                        mUtil.Tint(m, blendedColor)

                        progress = progress + 0.02
                        if progress >= 1 then
                            progress = 0
                            index = nextIndex
                        end
                        task.wait()
                    end
                end)
            end
        },
        -- Event effects
        ["Wet"] = { Multiplier = 1.5, IsEffect = true, Apply = function(m) applyParticle(m, "wet") end },
        ["Sandy"] = { Multiplier = 2, IsEffect = true, Apply = function(m) applyParticle(m, "sand") end },
        ["Zombified"] = { Multiplier = 3, IsEffect = true, Apply = function(m) applyParticle(m, "zombfied") end },
        ["Haunted"] = { Multiplier = 2.5, IsEffect = true, Apply = function(m) applyParticle(m, "haunted") end },
        ["Burning"] = { Multiplier = 1.5, IsEffect = true, Apply = function(m) applyParticle(m, "burning") end },
        ["Chilled"] = { Multiplier = 1.5, IsEffect = true, Apply = function(m) applyParticle(m, "chilled") end },
        ["Shocked"] = { Multiplier = 1.5, IsEffect = true, Apply = function(m) applyParticle(m, "shock") end },
        ["Corrupted"] = { Multiplier = 1.5, IsEffect = true, Apply = function(m) applyParticle(m, "corrupted") end },
    }
    
    local data = mutationData[mutationName]
    if not data then
        return false
    end
    
    -- Apply visual effects if Apply function exists
    if data.Apply then
        local success, err = pcall(function()
            data.Apply(model, requiredParent)
        end)
        
        if not success then
            warn("[SafeApply] Error applying mutation", mutationName, ":", err)
            return false
        end
    end
    
    return true
end

-- Export the safe apply function
return {
    -- Mutations data
    ["Normal"] = { Multiplier = 1; Gradient = script.Normal; Chance = 100; };
    ["Gold"] = { Multiplier = 2; Gradient = script.Gold; Chance = 25; Apply = function(m) mUtil.Tint(m,Color3.fromRGB(255, 221, 26)) end };
    ["Petrified"] = { Multiplier = 1.5; Gradient = script.Petrified; Chance = 30; Apply = function(m) mUtil.Tint(m,Color3.fromRGB(138, 138, 138)); mUtil.Material(m, Enum.Material.Concrete) end };
    ["Emerald"] = { Multiplier = 3.5; Gradient = script.Emerald; Chance = 8; Apply = function(m) mUtil.Tint(m,Color3.fromRGB(61, 252, 58)); mUtil.Material(m, Enum.Material.Foil) end };
    ["Diamond"] = { Multiplier = 5; Gradient = script.Diamond; Chance = 5; Apply = function(m) mUtil.Tint(m,Color3.fromRGB(29, 214, 255)) end };
    ["Rainbow"] = { Multiplier = 10; Gradient = script.Rainbow; Chance = 1.4; Apply = function(m, p) SafeApply("Rainbow", m, p) end };
    
    -- Effects
    ["Wet"] = { Multiplier = 1.5; Chance = 0; IsEffect = true; Gradient = script.Wet; Icon = "rbxassetid://89301420054411"; Apply = function(m) applyParticle(m, "wet") end };
    ["Sandy"] = { Multiplier = 2; Chance = 0; IsEffect = true; Gradient = script.Sandy; Icon = "rbxassetid://119181217383917"; Apply = function(m) applyParticle(m, "sand") end };
    ["Zombified"] = { Multiplier = 3; Chance = 0; IsEffect = true; Gradient = script.Zombified; Icon = "rbxassetid://89301420054411"; Apply = function(m) applyParticle(m, "zombfied") end };
    ["Haunted"] = { Multiplier = 2.5; Chance = 0; IsEffect = true; Gradient = script.Haunted; Icon = "rbxassetid://89301420054411"; Apply = function(m) applyParticle(m, "haunted") end };
    ["Burning"] = { Multiplier = 1.5; Chance = 0; IsEffect = true; Gradient = script.Burning; Icon = "rbxassetid://89301420054411"; Apply = function(m) applyParticle(m, "burning") end };
    ["Chilled"] = { Multiplier = 1.5; Chance = 0; IsEffect = true; Gradient = script.Chilled; Icon = "rbxassetid://15740392348"; Apply = function(m) applyParticle(m,"chilled") end };
    ["Shocked"] = { Multiplier = 1.5; Chance = 0; IsEffect = true; Gradient = script.Shocked; Icon = "rbxassetid://135340638057434"; Apply = function(m) applyParticle(m,"shock") end };
    ["Corrupted"] = { Multiplier = 1.5; Chance = 0; IsEffect = true; Gradient = script.Corrupted; Icon = "rbxassetid://120769463257698"; Apply = function(m) applyParticle(m,"corrupted") end };
    
    -- Export validation functions
    ValidateMutation = ValidateMutation;
    SafeApply = SafeApply;
    applyParticle = applyParticle;
}
