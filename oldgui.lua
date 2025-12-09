-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PathfindingService = game:GetService("PathfindingService")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function getGreen()
    local success, result = pcall(function()
        local main = PlayerGui:FindFirstChild("Main")
        if not main then return nil end
        local catchingBar = main:FindFirstChild("CatchingBar")
        if not catchingBar then return nil end
        local frame = catchingBar:FindFirstChild("Frame")
        if not frame then return nil end
        local bar = frame:FindFirstChild("Bar")
        if not bar then return nil end
        local catch = bar:FindFirstChild("Catch")
        if not catch then return nil end
        return catch:FindFirstChild("Green")
    end)
    return success and result or nil
end

-- Highlight tracking
local playerModelHighlight = nil
local currentTargetHighlight = nil
local currentTargetParticles = nil
local originalColors = {} -- Store original GUI colors

-- Function to create highlight with priority
local function createHighlight(model, color, transparency)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = color
    highlight.FillTransparency = transparency
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.5
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop  -- Always visible
    highlight.Parent = model
    return highlight
end

-- Highlight maintenance connection
local highlightMaintenanceConnection = nil

local function startHighlightMaintenance()
    if highlightMaintenanceConnection then
        highlightMaintenanceConnection:Disconnect()
    end
    
    highlightMaintenanceConnection = RunService.Heartbeat:Connect(function()
        if not autoFarmEnabled then
            if highlightMaintenanceConnection then
                highlightMaintenanceConnection:Disconnect()
                highlightMaintenanceConnection = nil
            end
            return
        end
        
        -- Maintain current target highlight
        if currentTargetMob and currentTargetMob.Parent then
            -- Check if highlight still exists
            local existingHighlight = currentTargetMob:FindFirstChildOfClass("Highlight")
            
            if not existingHighlight or existingHighlight ~= currentTargetHighlight then
                -- Highlight was removed or replaced, recreate it
                if currentTargetHighlight then
                    pcall(function() currentTargetHighlight:Destroy() end)
                end
                currentTargetHighlight = createHighlight(currentTargetMob, Color3.fromRGB(80, 160, 255), 0.4)
            else
                -- Ensure our highlight properties are maintained
                currentTargetHighlight.FillColor = Color3.fromRGB(80, 160, 255)
                currentTargetHighlight.FillTransparency = 0.4
                currentTargetHighlight.OutlineColor = Color3.fromRGB(80, 160, 255)
                currentTargetHighlight.OutlineTransparency = 0.5
                currentTargetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            end
        end
        
        -- Maintain player model highlight
        if playerModelHighlight and playerModelHighlight.Parent then
            playerModelHighlight.FillColor = Color3.fromRGB(80, 160, 255)
            playerModelHighlight.FillTransparency = 0.6
            playerModelHighlight.OutlineColor = Color3.fromRGB(80, 160, 255)
            playerModelHighlight.OutlineTransparency = 0.5
            playerModelHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
    end)
end

local function stopHighlightMaintenance()
    if highlightMaintenanceConnection then
        highlightMaintenanceConnection:Disconnect()
        highlightMaintenanceConnection = nil
    end
end

-- Function to create particle effect
local function createParticleEffect(part)
    local attachment = Instance.new("Attachment")
    attachment.Parent = part
    
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Color = ColorSequence.new(Color3.fromRGB(80, 160, 255))
    particles.Size = NumberSequence.new(0.5, 1)
    particles.Transparency = NumberSequence.new(0.5, 1)
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Rate = 20
    particles.Speed = NumberRange.new(2, 4)
    particles.SpreadAngle = Vector2.new(360, 360)
    particles.Parent = attachment
    
    return attachment
end

-- Function to change GUI colors to blue
local function setGUIBlueMode(enabled)
    if enabled then
        -- Store originals and change to blue
        originalColors.instructionBg = instructionLabel.BackgroundColor3
        originalColors.instructionText = instructionLabel.TextColor3
        originalColors.waitingBg = waitingLabel.BackgroundColor3
        originalColors.flyingBg = flyingToLabel.BackgroundColor3
        originalColors.healthBg = healthDisplayLabel.BackgroundColor3
        
        instructionLabel.BackgroundColor3 = Color3.fromRGB(40, 80, 140)
        instructionLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
        waitingLabel.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
        flyingToLabel.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
        healthDisplayLabel.BackgroundColor3 = Color3.fromRGB(70, 110, 170)
    else
        -- Restore originals
        if originalColors.instructionBg then
            instructionLabel.BackgroundColor3 = originalColors.instructionBg
            instructionLabel.TextColor3 = originalColors.instructionText
            waitingLabel.BackgroundColor3 = originalColors.waitingBg
            flyingToLabel.BackgroundColor3 = originalColors.flyingBg
            healthDisplayLabel.BackgroundColor3 = originalColors.healthBg
        end
    end
end

-- Function to cleanup highlights and particles
local function cleanupVisuals()
    if targetParticles then
        pcall(function() targetParticles:Destroy() end)
        targetParticles = nil
    end
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AbyssGui"
screenGui.Parent = CoreGui
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true

-- Main Window - Make it taller for mobile
local mainWindow = Instance.new("Frame")
mainWindow.Name = "MainWindow"
mainWindow.Size = isMobile and UDim2.new(0.87, 0, 0.87, 0) or UDim2.new(0, 950, 0, 600)
mainWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
mainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
mainWindow.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
mainWindow.BorderSizePixel = 0
mainWindow.Active = true
mainWindow.Parent = screenGui
mainWindow.Visible = true

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainWindow

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(40, 45, 50)
mainStroke.Thickness = 2
mainStroke.Parent = mainWindow

-- Make draggable
local dragging = false
local dragInput, mousePos, framePos
local dragHandle = nil  -- Will be set later

local function setupDragging()
    if not dragHandle then return end
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = mainWindow.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            mainWindow.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

mainWindow.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - mousePos
        mainWindow.Position = UDim2.new(
            framePos.X.Scale, 
            framePos.X.Offset + delta.X, 
            framePos.Y.Scale, 
            framePos.Y.Offset + delta.Y
        )
    end
end)

-- Top Bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, isMobile and 60 or 50)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
topBar.BorderSizePixel = 0
topBar.Parent = mainWindow

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 8)
topBarCorner.Parent = topBar

local topBarFix = Instance.new("Frame")
topBarFix.Size = UDim2.new(1, 0, 0, 8)
topBarFix.Position = UDim2.new(0, 0, 1, -8)
topBarFix.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
topBarFix.BorderSizePixel = 0
topBarFix.Parent = topBar

-- Logo Icon (Big for both PC and Mobile, replaces title)
local logoIcon = Instance.new("ImageLabel")
logoIcon.Size = isMobile and UDim2.new(0, 160, 0, 104) or UDim2.new(0, 180, 0, 104)
logoIcon.Position = UDim2.new(0, 0, 0, -24)
logoIcon.AnchorPoint = Vector2.new(0, 0)
logoIcon.BackgroundTransparency = 1
logoIcon.Image = "rbxassetid://86073140109169"
logoIcon.ImageColor3 = Color3.fromRGB(80, 160, 255)
logoIcon.ScaleType = Enum.ScaleType.Fit
logoIcon.Parent = topBar

-- Search Box (NO CLEAR BUTTON, NO ICON)
local searchBox = Instance.new("TextBox")
searchBox.Size = isMobile and UDim2.new(0.3, 0, 0, 32) or UDim2.new(0, 400, 0, 32)
searchBox.Position = isMobile and UDim2.new(0.4, 0, 0.5, -16) or UDim2.new(0, 250, 0.5, -16)
searchBox.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
searchBox.BorderSizePixel = 0
searchBox.PlaceholderText = "Search"
searchBox.PlaceholderColor3 = Color3.fromRGB(100, 110, 120)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(200, 210, 220)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = isMobile and 12 or 14
searchBox.TextXAlignment = Enum.TextXAlignment.Center
searchBox.ClearTextOnFocus = false
searchBox.Parent = topBar

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 6)
searchCorner.Parent = searchBox

-- Minimize Button
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, isMobile and 36 or 32, 0, isMobile and 36 or 32)
-- CHANGED: Position on left for mobile, right for PC
minimizeButton.Position = UDim2.new(1, isMobile and -90 or -80, 0.5, isMobile and -18 or -16)
minimizeButton.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "−"
minimizeButton.TextColor3 = Color3.fromRGB(150, 160, 170)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = isMobile and 22 or 20
minimizeButton.Parent = topBar

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 6)
minimizeCorner.Parent = minimizeButton

minimizeButton.MouseButton1Click:Connect(function()
    mainWindow.Visible = false
end)

local function stopAutoClick()
    if clickConnection then
        clickConnection:Disconnect()
        clickConnection = nil
    end
end

local function freezePlayerAboveMob(mobRoot)
    -- validate
    if positionConnection then
        positionConnection:Disconnect()
        positionConnection = nil
    end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    
    if not hrp or not humanoid or not mobRoot then 
        print("freezePlayerAboveMob: Missing requirements")
        return 
    end
    
    if not mobRoot.Parent then
        print("freezePlayerAboveMob: mobRoot has no parent")
        return
    end
    
    -- cleanup previous
    cleanupFreeze(hrp)
    
    -- setup: disable auto rotation and platform stand
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    
    -- INSTANT TELEPORT to position ABOVE mob (sleeping on back, looking down at mob)
    local mobPosition = mobRoot.Position
    local fixedY = mobPosition.Y + 20  -- 20 studs above
    local targetPos = Vector3.new(mobPosition.X, fixedY, mobPosition.Z)
    
    -- Look at mob from above, then lay on back
    local lookAt = CFrame.lookAt(targetPos, mobPosition)
    local layBack = CFrame.Angles(math.rad(180), 0, 0)
    local yaw180 = CFrame.Angles(0, math.rad(180), 0)
    local initialCFrame = lookAt * layBack * yaw180
    
    -- INSTANT POSITION - teleport immediately
    hrp.CFrame = initialCFrame
    hrp.Velocity = Vector3.zero
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    -- create an Attachment on HRP (Attachment0)
    local hrpAttachment = Instance.new("Attachment")
    hrpAttachment.Name = ATTACH_NAME
    hrpAttachment.Parent = hrp
    hrpAttachment.Position = Vector3.new(0,0,0)
    hrpAttachment.CFrame = CFrame.new()
    
    -- create a NEW target anchored invisible part to host Attachment1
    local targetPart = Instance.new("Part")
    targetPart.Name = TARGET_PART_NAME
    targetPart.Anchored = true
    targetPart.Size = Vector3.new(0.2,0.2,0.2)
    targetPart.Transparency = 1
    targetPart.CanCollide = false
    targetPart.CanTouch = false
    targetPart.CFrame = initialCFrame
    targetPart.Parent = workspace
    
    local targetAttachment = Instance.new("Attachment")
    targetAttachment.Parent = targetPart
    
    -- container for aligns
    local alignContainer = Instance.new("Folder")
    alignContainer.Name = ALIGN_NAME
    alignContainer.Parent = hrp
    
    -- AlignPosition
    local alignPos = Instance.new("AlignPosition")
    alignPos.Name = "AlignPosition"
    alignPos.Attachment0 = hrpAttachment
    alignPos.Attachment1 = targetAttachment
    alignPos.ApplyAtCenterOfMass = true
    alignPos.MaxForce = MAX_FORCE
    alignPos.Responsiveness = 500
    alignPos.RigidityEnabled = true
    alignPos.Parent = alignContainer
    
    -- AlignOrientation
    local alignOri = Instance.new("AlignOrientation")
    alignOri.Name = "AlignOrientation"
    alignOri.Attachment0 = hrpAttachment
    alignOri.Attachment1 = targetAttachment
    alignOri.MaxTorque = MAX_TORQUE
    alignOri.Responsiveness = 500
    alignOri.PrimaryAxisOnly = false
    alignOri.RigidityEnabled = true
    alignOri.Parent = alignContainer
    
    -- helper to compute "sleeping" CFrame ABOVE the mob:
    local function computeTargetCFrame(mobPosition)
        local fixedY = mobPosition.Y + 20  -- 20 studs above
        local targetPos = Vector3.new(mobPosition.X, fixedY, mobPosition.Z)
        local lookAt = CFrame.lookAt(targetPos, mobPosition)
        local layBack = CFrame.Angles(math.rad(180), 0, 0)
        local yaw180 = CFrame.Angles(0, math.rad(180), 0)
        return lookAt * layBack * yaw180
    end
    
    -- initial move
    do
        local initialCFrame = computeTargetCFrame(mobRoot.Position)
        targetPart.CFrame = initialCFrame
    end
    
    -- Heartbeat: update targetPart smoothly
    positionConnection = RunService.Heartbeat:Connect(function(dt)
        -- Check if mob still exists and autofarm is active
        if not autoFarmEnabled or not mobRoot or not mobRoot.Parent or isAvoiding or not hrp or not hrp.Parent or not targetPart or not targetPart.Parent then
            if positionConnection then
                positionConnection:Disconnect()
                positionConnection = nil
            end
            if humanoid then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true
            end
            cleanupFreeze(hrp)
            return
        end
        
        -- Verify mobRoot still has valid position
        local success, mobPosition = pcall(function()
            return mobRoot.Position
        end)
        
        if not success then
            print("mobRoot position error, cleaning up")
            if positionConnection then
                positionConnection:Disconnect()
                positionConnection = nil
            end
            cleanupFreeze(hrp)
            return
        end
        
        -- compute desired CFrame for the target (above mob, facing it, laid on back)
        local desired = computeTargetCFrame(mobPosition)
        
        -- smooth the targetPart movement using Lerp
        local alpha = math.clamp(LERP_SPEED * dt, 0, 1)
        targetPart.CFrame = targetPart.CFrame:Lerp(desired, alpha)
        
        -- STRONG zeroing of velocities
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.RotVelocity = Vector3.new(0, 0, 0)
        hrp.Anchored = false
    end)
end

local function cleanupFreeze(hrp)
    -- ALWAYS cleanup workspace target part first - check multiple times
    pcall(function()
        for i = 1, 10 do  -- Increased from 5 to 10
            local ap = workspace:FindFirstChild("___FreezeTargetPart")
            if ap then 
                pcall(function() 
                    ap.Parent = nil
                    ap:Destroy() 
                end)
                task.wait(0.02)
            else
                break  -- Exit early if not found
            end
        end
    end)
    
    if not hrp then return end
    
    -- Remove attachments and aligns from hrp
    pcall(function()
        local att = hrp:FindFirstChild("___FreezeAttach")
        if att then 
            att.Parent = nil
            att:Destroy() 
        end
        
        local alignParent = hrp:FindFirstChild("___FreezeAlign")
        if alignParent then
            for _, v in pairs(alignParent:GetChildren()) do
                v.Parent = nil
                v:Destroy()
            end
            alignParent.Parent = nil
            alignParent:Destroy()
        end
    end)
    
    -- Reset velocities
    pcall(function()
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.RotVelocity = Vector3.new(0, 0, 0)
        hrp.Anchored = false
    end)
end

local function unfreezePlayer()
    if positionConnection then
        positionConnection:Disconnect()
        positionConnection = nil
    end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")
    
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
    end
    
    cleanupFreeze(hrp)
end

local function disableNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        
        -- Re-enable collisions
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        
        -- Reset humanoid states
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
        end
        
        -- Reset velocities
        if hrp then
            hrp.Anchored = false
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end
    end
end

-- Function to check if near lava
local function isNearLava(position, radius)
    local success, result = pcall(function()
        local lavaFolder = Workspace:FindFirstChild("Assets")
        if lavaFolder then
            local caveArea = lavaFolder:FindFirstChild("Cave Area [2]")
            if caveArea then
                local lava = caveArea:FindFirstChild("Lava")
                if lava then
                    for _, part in pairs(lava:GetDescendants()) do
                        if part:IsA("BasePart") then
                            local distance = (position - part.Position).Magnitude
                            if distance <= radius then
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end)
    return success and result or false
end

-- Close Button
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, isMobile and 36 or 32, 0, isMobile and 36 or 32)
closeButton.Position    = UDim2.new(1, isMobile and -40 or -40, 0.5, isMobile and -18 or -16)
closeButton.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
closeButton.BorderSizePixel = 0
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(150, 160, 170)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = isMobile and 24 or 22
closeButton.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

-- Mobile-compatible reset function (USING GAME'S RESET REMOTEFUNCTION)
local function resetCharacterMobile()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        
        if hrp then
            -- Create safety platform
            local platformPart = Instance.new("Part")
            platformPart.Name = "___SafetyPlatform"
            platformPart.Size = Vector3.new(10, 1, 10)
            platformPart.Position = hrp.Position - Vector3.new(0, 5, 0)
            platformPart.Anchored = true
            platformPart.CanCollide = true
            platformPart.Material = Enum.Material.SmoothPlastic
            platformPart.BrickColor = BrickColor.new("Bright blue")
            platformPart.Transparency = 0.3
            platformPart.Parent = workspace
            
            -- Unfreeze player
            hrp.Anchored = false
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            
            if humanoid then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true
            end
            
            -- Enable collisions
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function() 
                        part.CanCollide = true
                        part.Anchored = false
                    end)
                end
            end
            
            task.wait(0.2)
            
            -- Use the game's reset RemoteFunction
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local success, result = pcall(function()
                local resetRF = ReplicatedStorage.Shared.Packages.Knit.Services.CharacterService.RF.Reset
                return resetRF:InvokeServer({})
            end)
            
            if success then
                print("Reset succeeded!", result)
            else
                warn("Reset failed:", result)
            end
            
            -- Wait 6 seconds then remove platform
            task.wait(6)
            if platformPart and platformPart.Parent then
                platformPart:Destroy()
            end
        end
    end)
end

local function closeGUI(resetCharacter)
    pcall(function()
        autoFarmEnabled = false
        if currentTween then 
            pcall(function() currentTween:Cancel() end) 
            currentTween = nil 
        end
        if stopAutoClick then pcall(stopAutoClick) end
        if unfreezePlayer then pcall(unfreezePlayer) end
        if disableNoclip then pcall(disableNoclip) end
        isAvoiding = false
        currentTargetMob = nil
        performanceModeEnabled = false
        
        if playerWarningLabel then pcall(function() playerWarningLabel.Visible = false end) end
        if waitingLabel then pcall(function() waitingLabel.Visible = false end) end
        if flyingToLabel then pcall(function() flyingToLabel.Visible = false end) end
        if healthDisplayLabel then pcall(function() healthDisplayLabel.Visible = false end) end
        
        if deathConnection then
            pcall(function() deathConnection:Disconnect() end)
            deathConnection = nil
        end

        if hrp then
            pcall(function()
                hrp.Anchored = false
                hrp.Velocity = Vector3.zero
            end)
        end

        if humanoid then
            pcall(function()
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true
            end)
        end

        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CanCollide = true
                end)
            end
        end

        if performanceModeEnabled then
            pcall(function()
                local Lighting = game:GetService("Lighting")
                Lighting.GlobalShadows = true
                Lighting.Brightness = 2
                for _, effect in ipairs(Lighting:GetChildren()) do
                    if effect:IsA("PostEffect") then effect.Enabled = true end
                end
                settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            end)
        end
    end)
    
    pcall(function()
        if screenGui then screenGui:Destroy() end
    end)
end

closeButton.MouseButton1Click:Connect(function()
    -- Create confirmation popup
    local confirmPopup = Instance.new("Frame")
    confirmPopup.Size = UDim2.new(0, isMobile and 300 or 350, 0, isMobile and 180 or 160)
    confirmPopup.Position = UDim2.new(0.5, 0, 0.5, 0)
    confirmPopup.AnchorPoint = Vector2.new(0.5, 0.5)
    confirmPopup.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
    confirmPopup.BorderSizePixel = 0
    confirmPopup.ZIndex = 2000
    confirmPopup.Parent = screenGui
    
    local popupCorner = Instance.new("UICorner")
    popupCorner.CornerRadius = UDim.new(0, 8)
    popupCorner.Parent = confirmPopup
    
    local popupStroke = Instance.new("UIStroke")
    popupStroke.Color = Color3.fromRGB(80, 160, 255)
    popupStroke.Thickness = 2
    popupStroke.Parent = confirmPopup
    
    -- ADDED: X Close Button for popup
    local popupCloseButton = Instance.new("TextButton")
    popupCloseButton.Size = UDim2.new(0, 30, 0, 30)
    popupCloseButton.Position = UDim2.new(1, -35, 0, 5)
    popupCloseButton.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
    popupCloseButton.BorderSizePixel = 0
    popupCloseButton.Text = "×"
    popupCloseButton.TextColor3 = Color3.fromRGB(200, 210, 220)
    popupCloseButton.Font = Enum.Font.GothamBold
    popupCloseButton.TextSize = 20
    popupCloseButton.ZIndex = 2001
    popupCloseButton.Parent = confirmPopup
    
    local popupCloseCorner = Instance.new("UICorner")
    popupCloseCorner.CornerRadius = UDim.new(0, 6)
    popupCloseCorner.Parent = popupCloseButton
    
    popupCloseButton.MouseButton1Click:Connect(function()
        confirmPopup:Destroy()
    end)
    
    local popupTitle = Instance.new("TextLabel")
    popupTitle.Size = UDim2.new(1, -20, 0, 30)
    popupTitle.Position = UDim2.new(0, 10, 0, 10)
    popupTitle.BackgroundTransparency = 1
    popupTitle.Text = "Reset Character?"
    popupTitle.TextColor3 = Color3.fromRGB(200, 210, 220)
    popupTitle.Font = Enum.Font.GothamBold
    popupTitle.TextSize = isMobile and 16 or 18
    popupTitle.ZIndex = 2001
    popupTitle.Parent = confirmPopup
    
    local popupDesc = Instance.new("TextLabel")
    popupDesc.Size = UDim2.new(1, -20, 0, 50)
    popupDesc.Position = UDim2.new(0, 10, 0, 50)
    popupDesc.BackgroundTransparency = 1
    popupDesc.Text = "Do you want to reset your character before closing?"
    popupDesc.TextColor3 = Color3.fromRGB(150, 160, 170)
    popupDesc.Font = Enum.Font.Gotham
    popupDesc.TextSize = isMobile and 13 or 14
    popupDesc.TextWrapped = true
    popupDesc.ZIndex = 2001
    popupDesc.Parent = confirmPopup
    
    -- Yes Button
    local yesButton = Instance.new("TextButton")
    yesButton.Size = UDim2.new(0, isMobile and 130 or 150, 0, isMobile and 40 or 36)
    yesButton.Position = UDim2.new(0.5, isMobile and -135 or -155, 1, isMobile and -50 or -46)
    yesButton.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
    yesButton.BorderSizePixel = 0
    yesButton.Text = "Yes"
    yesButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    yesButton.Font = Enum.Font.GothamBold
    yesButton.TextSize = isMobile and 14 or 15
    yesButton.ZIndex = 2001
    yesButton.Parent = confirmPopup
    
    local yesCorner = Instance.new("UICorner")
    yesCorner.CornerRadius = UDim.new(0, 6)
    yesCorner.Parent = yesButton
    
    yesButton.MouseButton1Click:Connect(function()
        confirmPopup:Destroy()  -- Destroy popup first
        
        -- Cleanup first
        autoFarmEnabled = false
        
        -- Reset FOV
        local camera = workspace.CurrentCamera
        if camera then
            camera.FieldOfView = 70
        end
        
        -- ADDED: Remove all highlights
        if playerModelHighlight then
            pcall(function() playerModelHighlight:Destroy() end)
            playerModelHighlight = nil
        end
        if currentTargetHighlight then
            pcall(function() currentTargetHighlight:Destroy() end)
            currentTargetHighlight = nil
        end
        if currentTargetParticles then
            pcall(function() currentTargetParticles:Destroy() end)
            currentTargetParticles = nil
        end
        
        if currentTween then pcall(function() currentTween:Cancel() end) currentTween = nil end
        if stopAutoClick then pcall(stopAutoClick) end
        if unfreezePlayer then pcall(unfreezePlayer) end
        if disableNoclip then pcall(disableNoclip) end
        if stopHighlightMaintenance then pcall(stopHighlightMaintenance) end
        
        isAvoiding = false
        currentTargetMob = nil
        performanceModeEnabled = false
        
        if playerWarningLabel then pcall(function() playerWarningLabel.Visible = false end) end
        if waitingLabel then pcall(function() waitingLabel.Visible = false end) end
        if flyingToLabel then pcall(function() flyingToLabel.Visible = false end) end
        if healthDisplayLabel then pcall(function() healthDisplayLabel.Visible = false end) end
        if deathConnection then pcall(function() deathConnection:Disconnect() end) deathConnection = nil end
        
        -- Reset character (mobile compatible)
        resetCharacterMobile()
        
        -- Destroy GUI after reset starts
        task.wait(0.5)
        pcall(function()
            if screenGui then screenGui:Destroy() end
        end)
    end)
    
    -- No Button
    local noButton = Instance.new("TextButton")
    noButton.Size = UDim2.new(0, isMobile and 130 or 150, 0, isMobile and 40 or 36)
    noButton.Position = UDim2.new(0.5, 5, 1, isMobile and -50 or -46)
    noButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    noButton.BorderSizePixel = 0
    noButton.Text = "No"
    noButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    noButton.Font = Enum.Font.GothamBold
    noButton.TextSize = isMobile and 14 or 15
    noButton.ZIndex = 2001
    noButton.Parent = confirmPopup
    
    local noCorner = Instance.new("UICorner")
    noCorner.CornerRadius = UDim.new(0, 6)
    noCorner.Parent = noButton
    
    noButton.MouseButton1Click:Connect(function()
        confirmPopup:Destroy()  -- Destroy popup first
        
        -- Cleanup without reset
        autoFarmEnabled = false
        
        -- Reset FOV
        local camera = workspace.CurrentCamera
        if camera then
            camera.FieldOfView = 70
        end
        
        -- ADDED: Remove all highlights
        if playerModelHighlight then
            pcall(function() playerModelHighlight:Destroy() end)
            playerModelHighlight = nil
        end
        if currentTargetHighlight then
            pcall(function() currentTargetHighlight:Destroy() end)
            currentTargetHighlight = nil
        end
        if currentTargetParticles then
            pcall(function() currentTargetParticles:Destroy() end)
            currentTargetParticles = nil
        end
        
        if currentTween then pcall(function() currentTween:Cancel() end) currentTween = nil end
        if stopAutoClick then pcall(stopAutoClick) end
        if unfreezePlayer then pcall(unfreezePlayer) end
        if disableNoclip then pcall(disableNoclip) end
        if stopHighlightMaintenance then pcall(stopHighlightMaintenance) end
        
        pcall(function()
            if screenGui then screenGui:Destroy() end
        end)
    end)
end)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = isMobile and UDim2.new(0, 60, 1, -110) or UDim2.new(0, 200, 1, -100)
sidebar.Position = isMobile and UDim2.new(0, 0, 0, 60) or UDim2.new(0, 0, 0, 50)
sidebar.BackgroundColor3 = Color3.fromRGB(18, 22, 27)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainWindow

-- Content Area (Single Panel - Full Width)
local contentPanel = Instance.new("Frame")
contentPanel.Name = "ContentPanel"
contentPanel.Size = isMobile and UDim2.new(1, -60, 1, -110) or UDim2.new(1, -200, 1, -100)
contentPanel.Position = isMobile and UDim2.new(0, 60, 0, 60) or UDim2.new(0, 200, 0, 50)
contentPanel.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
contentPanel.BorderSizePixel = 0
contentPanel.Parent = mainWindow

-- Bottom Bar
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(1, 0, 0, isMobile and 50 or 50)
bottomBar.Position = UDim2.new(0, 0, 1, isMobile and -50 or -50)
bottomBar.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
bottomBar.BorderSizePixel = 0
bottomBar.Parent = mainWindow

local bottomBarCorner = Instance.new("UICorner")
bottomBarCorner.CornerRadius = UDim.new(0, 8)
bottomBarCorner.Parent = bottomBar

local bottomBarFix = Instance.new("Frame")
bottomBarFix.Size = UDim2.new(1, 0, 0, 8)
bottomBarFix.Position = UDim2.new(0, 0, 0, 0)
bottomBarFix.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
bottomBarFix.BorderSizePixel = 0
bottomBarFix.Parent = bottomBar

-- Bottom Bar Text
local bottomText = Instance.new("TextLabel")
bottomText.Size = UDim2.new(1, -20, 1, 0)
bottomText.Position = UDim2.new(0, 10, 0, 0)
bottomText.BackgroundTransparency = 1
bottomText.Text = "The Forge | https://discord.com/invite/xXethhWsze"
bottomText.TextColor3 = Color3.fromRGB(120, 130, 140)
bottomText.Font = Enum.Font.Gotham
bottomText.TextSize = isMobile and 12 or 13
bottomText.TextXAlignment = Enum.TextXAlignment.Center
bottomText.Parent = bottomBar

-- Drag Handle Icon (Bottom Right Corner)
local dragHandleContainer = Instance.new("Frame")
dragHandleContainer.Size = UDim2.new(0, isMobile and 50 or 45, 0, isMobile and 50 or 45)
dragHandleContainer.Position = UDim2.new(1, isMobile and -55 or -50, 0.5, isMobile and -25 or -22.5)
dragHandleContainer.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
dragHandleContainer.BackgroundTransparency = 1
dragHandleContainer.BorderSizePixel = 0
dragHandleContainer.Active = true
dragHandleContainer.Parent = bottomBar

local dragHandleCorner = Instance.new("UICorner")
dragHandleCorner.CornerRadius = UDim.new(0, 6)
dragHandleCorner.Parent = dragHandleContainer

local dragHandleStroke = Instance.new("UIStroke")
dragHandleStroke.Color = Color3.fromRGB(80, 160, 255)
dragHandleStroke.Thickness = 0
dragHandleStroke.Parent = dragHandleContainer

local dragHandleIcon = Instance.new("ImageLabel")
dragHandleIcon.Size = UDim2.new(0.7, 0, 0.7, 0)
dragHandleIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
dragHandleIcon.AnchorPoint = Vector2.new(0.5, 0.5)
dragHandleIcon.BackgroundTransparency = 1
dragHandleIcon.Image = "rbxassetid://105035535804966"  -- Same as logo
dragHandleIcon.ImageColor3 = Color3.fromRGB(161, 198, 255)
dragHandleIcon.ScaleType = Enum.ScaleType.Fit
dragHandleIcon.Parent = dragHandleContainer

-- Hover effect
dragHandleContainer.MouseEnter:Connect(function()
    dragHandleStroke.Thickness = 0
    dragHandleIcon.ImageColor3 = Color3.fromRGB(41, 85, 153)
end)

dragHandleContainer.MouseLeave:Connect(function()
    dragHandleStroke.Thickness = 0
    dragHandleIcon.ImageColor3 = Color3.fromRGB(161, 198, 255)
end)

-- Set drag handle and setup dragging
dragHandle = dragHandleContainer
setupDragging()

-- Current tab tracking
local currentTab = "Main"
local tabButtons = {}

-- Pages
local mainPage = Instance.new("ScrollingFrame")
mainPage.Size = UDim2.new(1, -10, 1, -10)
mainPage.Position = UDim2.new(0, 5, 0, 5)
mainPage.BackgroundTransparency = 1
mainPage.BorderSizePixel = 0
mainPage.ScrollBarThickness = isMobile and 6 or 4
mainPage.ScrollBarImageColor3 = Color3.fromRGB(80, 160, 255)
mainPage.CanvasSize = UDim2.new(0, 0, 0, 300)
mainPage.Parent = contentPanel

local miscPage = Instance.new("ScrollingFrame")
miscPage.Size = mainPage.Size
miscPage.Position = mainPage.Position
miscPage.BackgroundTransparency = 1
miscPage.BorderSizePixel = 0
miscPage.ScrollBarThickness = isMobile and 6 or 4
miscPage.ScrollBarImageColor3 = Color3.fromRGB(80, 160, 255)
miscPage.CanvasSize = UDim2.new(0, 0, 0, isMobile and 600 or 500)
miscPage.Visible = false
miscPage.Parent = contentPanel

local settingsPage = Instance.new("ScrollingFrame")
settingsPage.Size = mainPage.Size
settingsPage.Position = mainPage.Position
settingsPage.BackgroundTransparency = 1
settingsPage.BorderSizePixel = 0
settingsPage.ScrollBarThickness = isMobile and 6 or 4
settingsPage.ScrollBarImageColor3 = Color3.fromRGB(80, 160, 255)
settingsPage.CanvasSize = UDim2.new(0, 0, 0, 400)
settingsPage.Visible = false
settingsPage.Parent = contentPanel

local function showTab(name)
    currentTab = name
    mainPage.Visible = (name == "Main")
    miscPage.Visible = (name == "Misc")
    settingsPage.Visible = (name == "Settings")
end

-- Search functionality
local searchableItems = {
    {text = "Auto Farm", tab = "Main"},
    {text = "Ore Farm", tab = "Main"},
    {text = "Mob Farm", tab = "Main"},
    {text = "Performance Mode", tab = "Misc"},
    {text = "Auto Sell", tab = "Misc"},
    {text = "Discord", tab = "Settings"},
    {text = "Keybind", tab = "Settings"},
}

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local searchText = searchBox.Text:lower()
    if searchText == "" then return end
    
    for _, item in ipairs(searchableItems) do
        if item.text:lower():find(searchText) then
            showTab(item.tab)
            break
        end
    end
end)

-- Tab Button Creator
local function createTabButton(text, tabName, icon, yPos)
    local button = Instance.new("TextButton")
    button.Size = isMobile and UDim2.new(1, -6, 0, 45) or UDim2.new(1, -20, 0, 40)
    button.Position = isMobile and UDim2.new(0, 3, 0, yPos) or UDim2.new(0, 10, 0, yPos)
    button.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = sidebar
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button
    
    local iconLabel = Instance.new("ImageLabel")
    iconLabel.Size = isMobile and UDim2.new(0, 22, 0, 22) or UDim2.new(0, 20, 0, 20)
    iconLabel.Position = isMobile and UDim2.new(0.5, -11, 0, 5) or UDim2.new(0, 15, 0.5, -10)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Image = icon
    iconLabel.ImageColor3 = Color3.fromRGB(100, 140, 180)
    iconLabel.Parent = button
    
    local label = Instance.new("TextLabel")
    label.Size = isMobile and UDim2.new(1, 0, 0, 14) or UDim2.new(1, -50, 1, 0)
    label.Position = isMobile and UDim2.new(0, 0, 1, -16) or UDim2.new(0, 45, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(150, 160, 170)
    label.Font = Enum.Font.Gotham
    label.TextSize = isMobile and 8 or 14
    label.TextXAlignment = isMobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
    label.Parent = button
    
    button.MouseEnter:Connect(function()
        if currentTab ~= tabName then
            button.BackgroundTransparency = 0
            button.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if currentTab ~= tabName then
            button.BackgroundTransparency = 1
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        showTab(tabName)
        for _, btn in pairs(tabButtons) do
            btn.BackgroundTransparency = 1
        end
        button.BackgroundTransparency = 0
        button.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
    end)
    
    table.insert(tabButtons, button)
    return button
end

-- Create Tab Buttons (Only 3 tabs now)
createTabButton("Main", "Main", "rbxassetid://130853444838386", 3)
createTabButton("Misc", "Misc", "rbxassetid://85409095031269", isMobile and 48 or 60)
createTabButton("Settings", "Settings", "rbxassetid://139296610261738", isMobile and 93 or 110)

-- Set initial tab
tabButtons[1].BackgroundTransparency = 0
tabButtons[1].BackgroundColor3 = Color3.fromRGB(40, 60, 90)

-- Toggle Creator
local function createToggle(parent, text, yPos, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, isMobile and 40 or 35)
    container.Position = UDim2.new(0, 10, 0, yPos)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(180, 190, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = isMobile and 12 or 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = container
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, isMobile and 50 or 45, 0, isMobile and 26 or 22)
    toggleButton.Position = UDim2.new(1, isMobile and -50 or -45, 0.5, isMobile and -13 or -11)
    toggleButton.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = ""
    toggleButton.Parent = container
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleButton
    
    local toggleThumb = Instance.new("Frame")
    toggleThumb.Size = UDim2.new(0, isMobile and 20 or 18, 0, isMobile and 20 or 18)
    toggleThumb.Position = UDim2.new(0, 3, 0.5, isMobile and -10 or -9)
    toggleThumb.BackgroundColor3 = Color3.fromRGB(200, 210, 220)
    toggleThumb.BorderSizePixel = 0
    toggleThumb.Parent = toggleButton
    
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(1, 0)
    thumbCorner.Parent = toggleThumb
    
    local toggled = false
    toggleButton.MouseButton1Click:Connect(function()
        toggled = not toggled
        if toggled then
            TweenService:Create(toggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 160, 255)}):Play()
            TweenService:Create(toggleThumb, TweenInfo.new(0.2), {Position = UDim2.new(1, isMobile and -23 or -21, 0.5, isMobile and -10 or -9)}):Play()
        else
            TweenService:Create(toggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 45, 50)}):Play()
            TweenService:Create(toggleThumb, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.5, isMobile and -10 or -9)}):Play()
        end
        if callback then callback(toggled) end
    end)
    
    return container, function() return toggled end
end

-- Slider Creator
local function createSlider(parent, text, min, max, default, yPos, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, isMobile and 60 or 50)
    container.Position = UDim2.new(0, 10, 0, yPos)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(180, 190, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = isMobile and 12 or 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local currentValue = default
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 150, 0, 20)
    valueLabel.Position = UDim2.new(1, -150, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(currentValue) .. " / " .. tostring(max)
    valueLabel.TextColor3 = Color3.fromRGB(120, 130, 140)
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextSize = isMobile and 10 or 11
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container
    
    local sliderBar = Instance.new("TextButton")
    sliderBar.Size = UDim2.new(1, 0, 0, isMobile and 8 or 6)
    sliderBar.Position = UDim2.new(0, 0, 0, isMobile and 35 or 30)
    sliderBar.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
    sliderBar.BorderSizePixel = 0
    sliderBar.Text = ""
    sliderBar.AutoButtonColor = false
    sliderBar.Parent = container
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = sliderBar
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill
    
    local draggingSlider = false
    
    local function updateSlider(input)
        local pos = (input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X
        pos = math.clamp(pos, 0, 1)
        currentValue = math.floor(min + (max - min) * pos)
        sliderFill.Size = UDim2.new(pos, 0, 1, 0)
        valueLabel.Text = tostring(currentValue) .. " / " .. tostring(max)
        if callback then callback(currentValue) end
    end
    
    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            updateSlider(input)
        end
    end)
    
    sliderBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    
    return container, function() return currentValue end
end

-- Dropdown Creator
local function createDropdown(parent, text, options, yPos, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, isMobile and 55 or 50)
    container.Position = UDim2.new(0, 10, 0, yPos)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 15)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(180, 190, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = isMobile and 12 or 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(1, 0, 0, isMobile and 32 or 28)
    dropdown.Position = UDim2.new(0, 0, 0, isMobile and 22 or 20)
    dropdown.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
    dropdown.BorderSizePixel = 0
    dropdown.Text = "---"
    dropdown.TextColor3 = Color3.fromRGB(150, 160, 170)
    dropdown.Font = Enum.Font.Gotham
    dropdown.TextSize = isMobile and 13 or 12
    dropdown.TextXAlignment = Enum.TextXAlignment.Left
    dropdown.Parent = container

    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 4)
    dropdownCorner.Parent = dropdown

    local dropdownPadding = Instance.new("UIPadding")
    dropdownPadding.PaddingLeft = UDim.new(0, 10)
    dropdownPadding.Parent = dropdown

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -25, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "^"
    arrow.TextColor3 = Color3.fromRGB(120, 130, 140)
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = isMobile and 13 or 12
    arrow.Parent = dropdown

    return container
    end

    -- Button Creator
    local function createButton(parent, text, yPos, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -20, 0, isMobile and 36 or 32)
        button.Position = UDim2.new(0, 10, 0, yPos)
        button.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = Color3.fromRGB(180, 190, 200)
        button.Font = Enum.Font.Gotham
        button.TextSize = isMobile and 14 or 13
        button.Parent = parent
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button
        
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
        end)
        
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
        end)
        
        if callback then
            button.MouseButton1Click:Connect(callback)
        end
        
        return button
    end

    -- Track selection changes
    local lastSelectedEnemies = {}
    local lastSelectedOres = {}

    local function hasSelectionChanged()
        -- ADDED: Check if farmMode is valid
        if not farmMode then
            return false
        end
        
        if farmMode == "Mob" then
            for mobName, selected in pairs(selectedEnemies) do
                if lastSelectedEnemies[mobName] ~= selected then
                    return true
                end
            end
        else
            for oreName, selected in pairs(selectedOres) do
                if lastSelectedOres[oreName] ~= selected then
                    return true
                end
            end
        end
        return false
    end

    local function updateLastSelection()
        -- ADDED: Check if farmMode is valid
        if not farmMode then
            return
        end
        
        if farmMode == "Mob" then
            for mobName, selected in pairs(selectedEnemies) do
                lastSelectedEnemies[mobName] = selected
            end
        else
            for oreName, selected in pairs(selectedOres) do
                lastSelectedOres[oreName] = selected
            end
        end
    end

    -- MAIN TAB
    -- Instruction Label
    local instructionLabel = Instance.new("TextLabel")
    instructionLabel.Size = UDim2.new(1, -20, 0, 30)
    instructionLabel.Position = UDim2.new(0, 10, 0, 10)
    instructionLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
    instructionLabel.BorderSizePixel = 0
    instructionLabel.Text = "⚠️ Place sword in slot 1 and pickaxe in slot 2."
    instructionLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    instructionLabel.Font = Enum.Font.GothamBold
    instructionLabel.TextSize = isMobile and 12 or 13
    instructionLabel.Parent = mainPage

    local instructionCorner = Instance.new("UICorner")
    instructionCorner.CornerRadius = UDim.new(0, 6)
    instructionCorner.Parent = instructionLabel

    -- Player Detected Warning Label
    local playerWarningLabel = Instance.new("TextLabel")
    playerWarningLabel.Size = UDim2.new(0, isMobile and 200 or 250, 0, isMobile and 35 or 40)
    playerWarningLabel.Position = UDim2.new(0.5, 0, 0, isMobile and 10 or 15)
    playerWarningLabel.AnchorPoint = Vector2.new(0.5, 0)
    playerWarningLabel.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    playerWarningLabel.BorderSizePixel = 0
    playerWarningLabel.Text = "⚠️ Player Detected!"
    playerWarningLabel.TextColor3 = Color3.fromRGB(38, 38, 38)
    playerWarningLabel.Font = Enum.Font.GothamBold
    playerWarningLabel.TextSize = isMobile and 16 or 18
    playerWarningLabel.TextXAlignment = Enum.TextXAlignment.Center
    playerWarningLabel.Visible = false
    playerWarningLabel.Parent = screenGui
    playerWarningLabel.ZIndex = 10

    local warningCorner = Instance.new("UICorner")
    warningCorner.CornerRadius = UDim.new(0, 8)
    warningCorner.Parent = playerWarningLabel

    local warningStroke = Instance.new("UIStroke")
    warningStroke.Color = Color3.fromRGB(255, 50, 50)
    warningStroke.Thickness = 2
    warningStroke.Parent = playerWarningLabel

    -- Waiting Label
    local waitingLabel = Instance.new("TextLabel")
    waitingLabel.Size = UDim2.new(0, isMobile and 250 or 300, 0, isMobile and 30 or 35)
    waitingLabel.Position = UDim2.new(0.5, 0, 1, isMobile and -40 or -45)
    waitingLabel.AnchorPoint = Vector2.new(0.5, 1)
    waitingLabel.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
    waitingLabel.BorderSizePixel = 0
    waitingLabel.Text = "Waiting for target to spawn!"
    waitingLabel.TextColor3 = Color3.fromRGB(200, 210, 220)
    waitingLabel.Font = Enum.Font.GothamBold
    waitingLabel.TextSize = isMobile and 14 or 16
    waitingLabel.TextXAlignment = Enum.TextXAlignment.Center
    waitingLabel.Visible = false
    waitingLabel.Parent = screenGui
    waitingLabel.ZIndex = 10

    local waitingCorner = Instance.new("UICorner")
    waitingCorner.CornerRadius = UDim.new(0, 8)
    waitingCorner.Parent = waitingLabel

    -- Flying to Target Label
    local flyingToLabel = Instance.new("TextLabel")
    flyingToLabel.Size = UDim2.new(0, isMobile and 220 or 280, 0, isMobile and 35 or 40)
    flyingToLabel.Position = UDim2.new(0.5, 0, 0, isMobile and 55 or 65)
    flyingToLabel.AnchorPoint = Vector2.new(0.5, 0)
    flyingToLabel.BackgroundColor3 = Color3.fromRGB(40, 120, 200)
    flyingToLabel.BorderSizePixel = 0
    flyingToLabel.Text = "Flying to: Target"
    flyingToLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyingToLabel.Font = Enum.Font.GothamBold
    flyingToLabel.TextSize = isMobile and 14 or 16
    flyingToLabel.TextXAlignment = Enum.TextXAlignment.Center
    flyingToLabel.Visible = false
    flyingToLabel.Parent = screenGui
    flyingToLabel.ZIndex = 10

    local flyingCorner = Instance.new("UICorner")
    flyingCorner.CornerRadius = UDim.new(0, 8)
    flyingCorner.Parent = flyingToLabel

    local flyingStroke = Instance.new("UIStroke")
    flyingStroke.Color = Color3.fromRGB(60, 160, 255)
    flyingStroke.Thickness = 2
    flyingStroke.Parent = flyingToLabel

    -- Ore/Mob Health Display Label
    local healthDisplayLabel = Instance.new("TextLabel")
    healthDisplayLabel.Size = UDim2.new(0, isMobile and 240 or 300, 0, isMobile and 40 or 45)

    -- 0.5 = center of screen  
    -- -100 = 100px above the center  
    healthDisplayLabel.Position = UDim2.new(0.5, 0, 0.5, -100)

    healthDisplayLabel.AnchorPoint = Vector2.new(0.5, 0.5) -- center the label correctly
    healthDisplayLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthDisplayLabel.BorderSizePixel = 0
    healthDisplayLabel.Text = "Ore: Pebble | HP: 100"
    healthDisplayLabel.TextColor3 = Color3.fromRGB(38, 38, 38)
    healthDisplayLabel.Font = Enum.Font.GothamBold
    healthDisplayLabel.TextSize = isMobile and 14 or 16
    healthDisplayLabel.TextXAlignment = Enum.TextXAlignment.Center
    healthDisplayLabel.Visible = false
    healthDisplayLabel.Parent = screenGui
    healthDisplayLabel.ZIndex = 10

    local healthDisplayCorner = Instance.new("UICorner")
    healthDisplayCorner.CornerRadius = UDim.new(0, 8)
    healthDisplayCorner.Parent = healthDisplayLabel

    local healthDisplayStroke = Instance.new("UIStroke")
    healthDisplayStroke.Color = Color3.fromRGB(100, 255, 100)
    healthDisplayStroke.Thickness = 2
    healthDisplayStroke.Parent = healthDisplayLabel

    -- Health bar background
    local healthBarBg = Instance.new("Frame")
    healthBarBg.Size = UDim2.new(0.9, 0, 0, 6)
    healthBarBg.Position = UDim2.new(0.05, 0, 1, -10)
    healthBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Parent = healthDisplayLabel

    local healthBarBgCorner = Instance.new("UICorner")
    healthBarBgCorner.CornerRadius = UDim.new(1, 0)
    healthBarBgCorner.Parent = healthBarBg

    -- Health bar fill
    local healthBarFill = Instance.new("Frame")
    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
    healthBarFill.Position = UDim2.new(0, 0, 0, 0)
    healthBarFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    healthBarFill.BorderSizePixel = 0
    healthBarFill.Parent = healthBarBg

    local healthBarFillCorner = Instance.new("UICorner")
    healthBarFillCorner.CornerRadius = UDim.new(1, 0)
    healthBarFillCorner.Parent = healthBarFill

    -- Auto Sell Variables
    local autoSellEnabled = false
    local hasSoldOnce = false  -- Track if we've sold at startup
    local farmMode = nil
    local selectedSellOres = {
        Copper = false,
        Stone = false,
        ["Sand Stone"] = false,
        Iron = false,
        Cardboardite = false,
        Tin = false,
        Silver = false,
        Banananite = false,
        Gold = false,
        Mushroomite = false,
        Platinum = false,
        Aite = false,
        Poopite = false,
        Cobalt = false,
        Titanium = false,
        ["Lapis Lazuli"] = false,
        ["Volcanic Rock"] = false,
        Quartz = false,
        Amethyst = false,
        Topaz = false,
        Diamond = false,
        Sapphire = false,
        Cuprite = false,
        Obsidian = false,
        Emerald = false,
        Ruby = false,
        Rivalite = false,
        Uranium = false,
        Mythril = false,
        ["Eye Ore"] = false,
        Fireite = false,
        Magmaite = false,
        Lightite = false,
        Demonite = false,
        Darkryte = false
    }

    local selectedSellDrops = {
        ["Tiny Essence"] = false,
        ["Small Essence"] = false,
        ["Medium Essence"] = false,
        ["Large Essence"] = false,
        ["Greater Essence"] = false,
        ["Epic Essence"] = false,
        ["Superior Essence"] = false,
    }

    -- Farm Mode Selection
    local selectedEnemies = {
        Reaper = false,
        Slime = false,
        Zombie = false,
        EliteZombie = false,
        ["Delver Zombie"] = false,
        ["Brute Zombie"] = false,
        ["Skeleton Rogue"] = false,
        ["Elite Deathaxe Skeleton"] = false,
        ["Elite Rogue Skeleton"] = false,
        ["Blazing Slime"] = false,
        ["Axe Skeleton"] = false,
        ["Blight Pyromancer"] = false,
        Bomber = false
    }

    local selectedOres = {
        Pebble = false,
        Boulder = false,
        Rock = false,
        ["Basalt Core"] = false,
        ["Basalt Vein"] = false,
        ["Basalt Rock"] = false, 
        ["Volcanic Rock"] = false 
    }

    local sellerPositions = {
        Map1 = Vector3.new(-112.156, 36.901, -38.552),
        Map2 = Vector3.new(-139.706, 20.711, -24.840)  -- UPDATED
    }

    -- Container for all selection UI
    local selectionContainer = Instance.new("Frame")
    selectionContainer.Size = UDim2.new(1, -20, 0, 400)  -- CHANGED: Increased from 150 to 350
    selectionContainer.Position = UDim2.new(0, 10, 0, 50)
    selectionContainer.BackgroundTransparency = 1
    selectionContainer.ZIndex = 99000
    selectionContainer.Parent = mainPage

    local selectionLayout = Instance.new("UIListLayout")
    selectionLayout.Padding = UDim.new(0, 5)
    selectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    selectionLayout.Parent = selectionContainer

    -- Mode Selection Buttons
    local modeButtonContainer = Instance.new("Frame")
    modeButtonContainer.Size = UDim2.new(1, 0, 0, 65)
    modeButtonContainer.BackgroundTransparency = 1
    modeButtonContainer.LayoutOrder = 1
    modeButtonContainer.Parent = selectionContainer

    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(1, 0, 0, 20)
    modeLabel.Position = UDim2.new(0, 0, 0, 0)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Text = "Farm Mode:"
    modeLabel.TextColor3 = Color3.fromRGB(200, 210, 220)
    modeLabel.Font = Enum.Font.GothamBold
    modeLabel.TextSize = isMobile and 13 or 14
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.Parent = modeButtonContainer

    -- Mob Mode Button
    local mobModeButton = Instance.new("TextButton")
    mobModeButton.Size = UDim2.new(0.48, 0, 0, 36)
    mobModeButton.Position = UDim2.new(0, 0, 0, 28)
    mobModeButton.BackgroundColor3 = Color3.fromRGB(40, 45, 50)  -- CHANGED: Gray instead of blue
    mobModeButton.BorderSizePixel = 0
    mobModeButton.Text = "Mob Farm"
    mobModeButton.TextColor3 = Color3.fromRGB(150, 160, 170)  -- CHANGED: Gray text
    mobModeButton.Font = Enum.Font.Gotham  -- CHANGED: Not bold
    mobModeButton.TextSize = isMobile and 12 or 13
    mobModeButton.Parent = modeButtonContainer

    local mobModeCorner = Instance.new("UICorner")
    mobModeCorner.CornerRadius = UDim.new(0, 6)
    mobModeCorner.Parent = mobModeButton

    -- Ore Mode Button
    local oreModeButton = Instance.new("TextButton")
    oreModeButton.Size = UDim2.new(0.48, 0, 0, 36)
    oreModeButton.Position = UDim2.new(0.52, 0, 0, 28)
    oreModeButton.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
    oreModeButton.BorderSizePixel = 0
    oreModeButton.Text = "Ore Farm"
    oreModeButton.TextColor3 = Color3.fromRGB(150, 160, 170)
    oreModeButton.Font = Enum.Font.Gotham
    oreModeButton.TextSize = isMobile and 12 or 13
    oreModeButton.Parent = modeButtonContainer

    local oreModeCorner = Instance.new("UICorner")
    oreModeCorner.CornerRadius = UDim.new(0, 6)
    oreModeCorner.Parent = oreModeButton

    -- Dropdown Selection Container
    local dropdownContainer = Instance.new("Frame")
    dropdownContainer.Size = UDim2.new(1, 0, 0, 400)  -- INCREASED to accommodate taller dropdown
    dropdownContainer.BackgroundTransparency = 1
    dropdownContainer.ZIndex = 99000
    dropdownContainer.LayoutOrder = 2
    dropdownContainer.Parent = selectionContainer

    -- Create dropdown button
    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Size = UDim2.new(1, 0, 0, isMobile and 40 or 36)
    dropdownButton.Position = UDim2.new(0, 0, 0, 0)
    dropdownButton.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
    dropdownButton.BorderSizePixel = 0
    dropdownButton.Text = "Select farm mode first"
    dropdownButton.TextColor3 = Color3.fromRGB(200, 210, 220)
    dropdownButton.Font = Enum.Font.Gotham
    dropdownButton.TextSize = isMobile and 13 or 14
    dropdownButton.TextXAlignment = Enum.TextXAlignment.Left
    dropdownButton.Visible = true  -- Make sure it's visible
    dropdownButton.Parent = dropdownContainer

    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = dropdownButton

    local dropdownPadding = Instance.new("UIPadding")
    dropdownPadding.PaddingLeft = UDim.new(0, 10)
    dropdownPadding.Parent = dropdownButton

    local dropdownArrow = Instance.new("TextLabel")
    dropdownArrow.Size = UDim2.new(0, 20, 1, 0)
    dropdownArrow.Position = UDim2.new(1, -30, 0, 0)
    dropdownArrow.BackgroundTransparency = 1
    dropdownArrow.Text = "▼"
    dropdownArrow.TextColor3 = Color3.fromRGB(150, 160, 170)
    dropdownArrow.Font = Enum.Font.GothamBold
    dropdownArrow.TextSize = isMobile and 12 or 14
    dropdownArrow.Parent = dropdownButton

    -- Dropdown list frame - Parent to dropdownContainer instead of screenGui
    local dropdownList = Instance.new("ScrollingFrame")
    dropdownList.Size = UDim2.new(1, 0, 0, isMobile and 220 or 210)
    dropdownList.Position = UDim2.new(0, 0, 0.10, 2)
    dropdownList.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
    dropdownList.BorderSizePixel = 0
    dropdownList.ScrollBarThickness = isMobile and 12 or 8
    dropdownList.ScrollBarImageColor3 = Color3.fromRGB(80, 160, 255)
    dropdownList.ScrollBarImageTransparency = 0
    dropdownList.ScrollingEnabled = true
    dropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
    dropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
    dropdownList.Visible = false
    dropdownList.ZIndex = 99000
    dropdownList.Parent = dropdownContainer
    dropdownList.ClipsDescendants = true
    dropdownList.ElasticBehavior = Enum.ElasticBehavior.Never

    local dropdownListCorner = Instance.new("UICorner")
    dropdownListCorner.CornerRadius = UDim.new(0, 6)
    dropdownListCorner.Parent = dropdownList

    local dropdownListStroke = Instance.new("UIStroke")
    dropdownListStroke.Color = Color3.fromRGB(80, 160, 255)
    dropdownListStroke.Thickness = 0
    dropdownListStroke.Parent = dropdownList

    -- ONLY ONE dropdownListLayout definition
    local dropdownListLayout = Instance.new("UIListLayout")
    dropdownListLayout.Padding = UDim.new(0, 2)
    dropdownListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropdownListLayout.Parent = dropdownList

    -- Update positions when dropdown visibility changes
    dropdownButton.MouseButton1Click:Connect(function()
        if not farmMode then
            dropdownButton.Text = "⚠️ Select farm mode first!"
            task.wait(1.5)
            dropdownButton.Text = "Select farm mode first"
            return
        end
        dropdownList.Visible = not dropdownList.Visible
        dropdownArrow.Text = dropdownList.Visible and "▲" or "▼"
        
        -- Recalculate positions when dropdown opens/closes
        toggleStartY = getToggleStartY()
        
        -- Update all toggle/slider positions
        autoFarmToggle.Position = UDim2.new(0, 10, 0, toggleStartY)
        
        -- Find and update other elements by iterating through mainPage children
        for _, child in pairs(mainPage:GetChildren()) do
            if child:IsA("Frame") and child ~= selectionContainer and child ~= instructionLabel then
                local currentY = child.Position.Y.Offset
                -- Only update if it's one of our controls (below the selection container)
                if currentY > 400 then
                    -- Recalculate based on original offset from toggleStartY
                    if child.Name:find("Avoid Players") or currentY > toggleStartY then
                        -- This is a control that needs repositioning
                        -- You'll need to track original offsets or recreate them
                    end
                end
            end
        end
        
        updateCanvasSize()
    end)

    -- CREATE DROPDOWN ITEM FUNCTION
    local function createDropdownItem(name, parent)
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -10, 0, isMobile and 32 or 28)
        item.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
        item.BorderSizePixel = 0
        item.Text = ""
        item.AutoButtonColor = false
        item.ZIndex = 1001
        item.Parent = parent
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 4)
        itemCorner.Parent = item
        
        local checkbox = Instance.new("Frame")
        checkbox.Size = UDim2.new(0, isMobile and 20 or 18, 0, isMobile and 20 or 18)
        checkbox.Position = UDim2.new(0, 8, 0.5, isMobile and -10 or -9)
        checkbox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
        checkbox.BorderSizePixel = 0
        checkbox.ZIndex = 1002
        checkbox.Parent = item
        
        local checkboxCorner = Instance.new("UICorner")
        checkboxCorner.CornerRadius = UDim.new(0, 4)
        checkboxCorner.Parent = checkbox
        
        local checkmark = Instance.new("TextLabel")
        checkmark.Size = UDim2.new(1, 0, 1, 0)
        checkmark.BackgroundTransparency = 1
        checkmark.Text = ""
        checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
        checkmark.Font = Enum.Font.GothamBold
        checkmark.TextSize = isMobile and 14 or 12
        checkmark.ZIndex = 1003
        checkmark.Parent = checkbox
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -40, 1, 0)
        label.Position = UDim2.new(0, 35, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(200, 210, 220)
        label.Font = Enum.Font.Gotham
        label.TextSize = isMobile and 12 or 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 1002
        label.Parent = item
        
        return item, checkbox, checkmark
    end

    -- Function to update dropdown text
    local function updateDropdownText()
        if not farmMode then
            dropdownButton.Text = "Select farm mode first"
            return
        end
        
        local count = 0
        local items = farmMode == "Mob" and selectedEnemies or selectedOres
        for _, selected in pairs(items) do
            if selected then count = count + 1 end
        end
        
        if farmMode == "Mob" then
            dropdownButton.Text = string.format("Select Mobs (%d)", count)
        else
            dropdownButton.Text = string.format("Select Ores (%d)", count)
        end
    end

    -- Function to force target switch
    local function forceTargetSwitch()
        if not autoFarmEnabled then return end
        print("Force switching target due to selection change...")
        
        if currentTween then
            currentTween:Cancel()
            currentTween = nil
        end
        removeTweenLine()
        unfreezePlayer()
        
        currentTargetMob = nil
        healthDisplayLabel.Visible = false
        flyingToLabel.Visible = false
        waitingLabel.Visible = false
        maxHealthCache = {}
        isAvoiding = false
    end

    -- ONLY ONE populateMobDropdown function
    local function populateMobDropdown()
        for _, child in pairs(dropdownList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local mobNames = {
            "Reaper", "Slime", "Zombie", "EliteZombie", 
            "Delver Zombie", "Brute Zombie", "Skeleton Rogue", 
            "Elite Deathaxe Skeleton", "Elite Rogue Skeleton", 
            "Blazing Slime", "Axe Skeleton", "Blight Pyromancer", "Bomber"
        }
        
        for _, mobName in ipairs(mobNames) do
            local item, checkbox, checkmark = createDropdownItem(mobName, dropdownList)
            if selectedEnemies[mobName] then
                checkbox.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
                checkmark.Text = "✓"
            end
            item.MouseButton1Click:Connect(function()
                selectedEnemies[mobName] = not selectedEnemies[mobName]
                if selectedEnemies[mobName] then
                    checkbox.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
                    checkmark.Text = "✓"
                else
                    checkbox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
                    checkmark.Text = ""
                end
                updateDropdownText()
                if autoFarmEnabled then
                    forceTargetSwitch()
                end
            end)
        end
        
        dropdownList.CanvasSize = UDim2.new(0, 0, 0, dropdownListLayout.AbsoluteContentSize.Y + 5)
    end

    -- ONLY ONE populateOreDropdown function
    local function populateOreDropdown()
        for _, child in pairs(dropdownList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local oreNames = {"Pebble", "Boulder", "Rock", "Basalt Core", "Basalt Vein", "Basalt Rock", "Volcanic Rock"}
        
        for _, oreName in ipairs(oreNames) do
            local item, checkbox, checkmark = createDropdownItem(oreName, dropdownList)
            
            if selectedOres[oreName] then
                checkbox.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
                checkmark.Text = "✓"
            end
            
            item.MouseButton1Click:Connect(function()
                selectedOres[oreName] = not selectedOres[oreName]
                
                if selectedOres[oreName] then
                    checkbox.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
                    checkmark.Text = "✓"
                else
                    checkbox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
                    checkmark.Text = ""
                end
                
                updateDropdownText()
                
                if autoFarmEnabled then
                    forceTargetSwitch()
                end
            end)
        end
        
        dropdownList.CanvasSize = UDim2.new(0, 0, 0, dropdownListLayout.AbsoluteContentSize.Y + 5)
    end

    -- Mode switching logic
    local function updateModeUI()
        if farmMode == "Mob" then
            mobModeButton.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
            mobModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            mobModeButton.Font = Enum.Font.GothamBold
            oreModeButton.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
            oreModeButton.TextColor3 = Color3.fromRGB(150, 160, 170)
            oreModeButton.Font = Enum.Font.Gotham
            populateMobDropdown()
        else
            oreModeButton.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
            oreModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            oreModeButton.Font = Enum.Font.GothamBold
            mobModeButton.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
            mobModeButton.TextColor3 = Color3.fromRGB(150, 160, 170)
            mobModeButton.Font = Enum.Font.Gotham
            populateOreDropdown()
        end
        
        dropdownList.Visible = false
        dropdownArrow.Text = "▼"
        updateDropdownText()
    end

    mobModeButton.MouseButton1Click:Connect(function()
        local previousMode = farmMode
        farmMode = "Mob"
        updateModeUI()
        
        if autoFarmEnabled and previousMode ~= farmMode then
            forceTargetSwitch()
        end
    end)

    oreModeButton.MouseButton1Click:Connect(function()
        local previousMode = farmMode
        farmMode = "Ore"
        updateModeUI()
        
        if autoFarmEnabled and previousMode ~= farmMode then
            forceTargetSwitch()
        end
    end)


    dropdownButton.Text = "Select farm mode first"

    local function updateCanvasSize()
        local contentHeight = 50 + selectionContainer.AbsoluteSize.Y + 250
        mainPage.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
    end

    updateCanvasSize()

    selectionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        task.wait(0.1)
        toggleStartY = getToggleStartY()
        updateCanvasSize()
    end)

    -- Auto Farm Feature
    local autoFarmEnabled = false
    local autoFarmConnection = nil
    local noclipConnection = nil
    local positionConnection = nil
    local clickConnection = nil
    local avoidEnabled = false
    local avoidDistance = 50
    local flyHeight = 50
    local attackHeight = 5.5
    local attackDistance = 10
    local tweenSpeedFarm = 60
    local tweenSpeedInitial = 50 
    local tweenSpeedReturn = 50
    local tweenSpeedSwitch = 50
    local currentTween = nil
    local isAvoiding = false
    local currentTargetMob = nil
    local autoFarmToggleCallback = nil

    local function updateWaitingLabel()
        if farmMode == "Mob" then
            local enabledEnemies = {}
            for enemyName, enabled in pairs(selectedEnemies) do
                if enabled then
                    table.insert(enabledEnemies, enemyName)
                end
            end
            
            if #enabledEnemies == 0 then
                waitingLabel.Text = "No mobs selected!"
            elseif #enabledEnemies == 1 then
                waitingLabel.Text = "Waiting for " .. enabledEnemies[1] .. " to spawn!"
            else
                waitingLabel.Text = "Waiting for " .. table.concat(enabledEnemies, " and ") .. " to spawn!"
            end
        else
            local enabledOres = {}
            for oreName, enabled in pairs(selectedOres) do
                if enabled then
                    table.insert(enabledOres, oreName)
                end
            end
            
            if #enabledOres == 0 then
                waitingLabel.Text = "No ores selected!"
            elseif #enabledOres == 1 then
                waitingLabel.Text = "Waiting for " .. enabledOres[1] .. " to spawn!"
            else
                waitingLabel.Text = "Waiting for " .. table.concat(enabledOres, " and ") .. " to spawn!"
            end
        end
    end

    local maxHealthCache = {}

    local function updateHealthDisplay(target, targetType, currentHP)
        if not target or not currentHP then
            healthDisplayLabel.Visible = false
            return
        end
        
        -- Cache max health on first encounter
        local targetId = tostring(target)
        if not maxHealthCache[targetId] then
            maxHealthCache[targetId] = currentHP
        end
        
        local maxHP = maxHealthCache[targetId]
        if currentHP > maxHP then
            maxHP = currentHP
            maxHealthCache[targetId] = maxHP
        end
        
        -- Update text
        healthDisplayLabel.Text = targetType .. " | HP: " .. currentHP .. "/" .. maxHP
        
        -- Update health bar
        local healthPercent = math.clamp(currentHP / maxHP, 0, 1)
        healthBarFill.Size = UDim2.new(healthPercent, 0, 1, 0)
        
        -- Color based on health percentage
        if healthPercent > 0.6 then
            healthBarFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            healthDisplayStroke.Color = Color3.fromRGB(100, 255, 100)
            healthDisplayLabel.TextColor3 = Color3.fromRGB(38, 38, 38)
        elseif healthPercent > 0.3 then
            healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
            healthDisplayStroke.Color = Color3.fromRGB(255, 200, 100)
            healthDisplayLabel.TextColor3 = Color3.fromRGB(38, 38, 38)
        else
            healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
            healthDisplayStroke.Color = Color3.fromRGB(255, 100, 100)
            healthDisplayLabel.TextColor3 = Color3.fromRGB(38, 38, 38)
        end
        
        healthDisplayLabel.Visible = true
    end

    local function getRockHP(rockModel)
        local success, hp = pcall(function()
            local infoFrame = rockModel:FindFirstChild("infoFrame")
            if not infoFrame then return nil end
            
            local frame = infoFrame:FindFirstChild("Frame")
            if not frame then return nil end
            
            local rockHP = frame:FindFirstChild("rockHP")
            if not rockHP then return nil end
            
            -- Parse the HP from text (format might be "100/100" or just "100")
            local text = rockHP.Text
            if text then
                -- Try to extract current HP (first number)
                local currentHP = tonumber(text:match("^(%d+)"))
                return currentHP
            end
            
            return nil
        end)
        
        return success and hp or nil
    end

    local function findTargetMob(avoidPlayerPos)
        local livingFolder = Workspace:FindFirstChild("Living")
        if not livingFolder then return nil, nil, nil end
        
        local enabledEnemies = {}
        for enemyName, enabled in pairs(selectedEnemies) do
            if enabled then
                table.insert(enabledEnemies, enemyName)
            end
        end
        
        if #enabledEnemies == 0 then return nil, nil, nil end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil, nil, nil end
        
        local foundMobs = {}
        
        for _, mob in pairs(livingFolder:GetChildren()) do
            if mob:IsA("Model") and mob ~= currentTargetMob then
                for _, enemyName in ipairs(enabledEnemies) do
                    local mobName = mob.Name
                    local matched = false

                    -- Special handling for "Zombie" (ONLY Zombie with numbers/underscores)
                    if enemyName == "Zombie" then
                        if mobName:match("^Zombie[_%d]*$") then
                            matched = true
                        end
                    -- Skeleton Rogue
                    elseif enemyName == "Skeleton Rogue" then
                        if mobName:match("^Skeleton Rogue[_%d]*$") then
                            matched = true
                        end
                    -- Elite Deathaxe Skeleton
                    elseif enemyName == "Elite Deathaxe Skeleton" then
                        if (mobName:find("Elite") and mobName:find("Deathaxe") and mobName:find("Skeleton")) or
                        (mobName:find("Elite") and mobName:find("Skeleton") and not mobName:find("Rogue")) then
                            matched = true
                        end
                    -- Elite Rogue Skeleton
                    elseif enemyName == "Elite Rogue Skeleton" then
                        if mobName:find("Elite") and mobName:find("Rogue") and mobName:find("Skeleton") then
                            matched = true
                        end
                    -- Axe Skeleton
                    elseif enemyName == "Axe Skeleton" then
                        if mobName:find("Axe") and mobName:find("Skeleton") and not mobName:find("Elite") then
                            matched = true
                        end
                    -- Blazing Slime
                    elseif enemyName == "Blazing Slime" then
                        if mobName:find("Blazing") and mobName:find("Slime") then
                            matched = true
                        end
                    -- Slime (ONLY regular Slime, NOT Blazing)
                    elseif enemyName == "Slime" then
                        if mobName:match("^Slime[_%d]*$") and not mobName:find("Blazing") then
                            matched = true
                        end
                    -- Blight Pyromancer
                    elseif enemyName == "Blight Pyromancer" then
                        if mobName:find("Blight") and mobName:find("Pyromancer") then
                            matched = true
                        end
                    -- Bomber
                    elseif enemyName == "Bomber" then
                        if mobName:find("Bomber") then
                            matched = true
                        end
                    -- Default: exact name match
                    elseif mobName:find(enemyName) then
                        matched = true
                    end
                    
                    if matched then
                        local humanoidRootPart = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Head")
                        if humanoidRootPart then
                            local humanoid = mob:FindFirstChild("Humanoid")
                            if humanoid and humanoid.Health > 0 then
                                local distance = (hrp.Position - humanoidRootPart.Position).Magnitude
                                local playerDistance = 0
                                
                                if avoidPlayerPos then
                                    playerDistance = (avoidPlayerPos - humanoidRootPart.Position).Magnitude
                                end
                                
                                table.insert(foundMobs, {
                                    mob = mob,
                                    root = humanoidRootPart,
                                    type = enemyName,
                                    distance = distance,
                                    playerDistance = playerDistance
                                })
                            end
                        end
                        break
                    end
                end
            end
        end
        
        if #foundMobs == 0 then return nil, nil, nil end
        
        if avoidPlayerPos then
            table.sort(foundMobs, function(a, b)
                return a.playerDistance > b.playerDistance
            end)
        else
            table.sort(foundMobs, function(a, b)
                return a.distance < b.distance
            end)
        end
        
        local selected = foundMobs[1]
        return selected.mob, selected.root, selected.type
    end

    -- Update the findTargetOre function to accept player position for distance calculation
    local function findTargetOre(avoidPlayerPos)
        local rocksFolder = Workspace:FindFirstChild("Rocks")
        if not rocksFolder then return nil, nil, nil end
        
        local enabledOres = {}
        for oreName, enabled in pairs(selectedOres) do
            if enabled then
                table.insert(enabledOres, oreName)
            end
        end
        
        if #enabledOres == 0 then return nil, nil, nil end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil, nil, nil end
        
        local foundOres = {}
        
        for _, rockModel in pairs(rocksFolder:GetDescendants()) do
            if rockModel:IsA("Model") then
                for _, oreName in ipairs(enabledOres) do
                    if rockModel.Name:lower():find(oreName:lower()) then
                        local hp = getRockHP(rockModel)
                        if hp and hp > 0 then
                            local primaryPart = rockModel.PrimaryPart or rockModel:FindFirstChildWhichIsA("BasePart")
                            if primaryPart then
                                local distance = (hrp.Position - primaryPart.Position).Magnitude
                                local playerDistance = 0
                                
                                -- If avoiding player, calculate distance from player to ore
                                if avoidPlayerPos then
                                    playerDistance = (avoidPlayerPos - primaryPart.Position).Magnitude
                                end
                                
                                table.insert(foundOres, {
                                    mob = rockModel,
                                    root = primaryPart,
                                    type = oreName,
                                    distance = distance,
                                    playerDistance = playerDistance,
                                    hp = hp
                                })
                                print("Found ore:", rockModel.Name, "HP:", hp, "Distance from player:", playerDistance)
                            end
                        end
                        break
                    end
                end
            end
        end
        
        if #foundOres == 0 then 
            print("No valid ores found")
            return nil, nil, nil 
        end
        
        -- If avoiding player, sort by farthest from player, otherwise by nearest to character
        if avoidPlayerPos then
            table.sort(foundOres, function(a, b)
                return a.playerDistance > b.playerDistance  -- Farthest from player
            end)
            print("Sorting by farthest from player - Selected:", foundOres[1].mob.Name, "Distance:", foundOres[1].playerDistance)
        else
            table.sort(foundOres, function(a, b)
                return a.distance < b.distance  -- Nearest to player
            end)
            print("Sorting by nearest to character - Selected:", foundOres[1].mob.Name, "Distance:", foundOres[1].distance)
        end
        
        local selected = foundOres[1]
        return selected.mob, selected.root, selected.type
    end

    -- Update checkNearbyPlayers to return player position
    local function checkNearbyPlayers()
        if not avoidEnabled then return false, nil end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false, nil end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local otherChar = player.Character
                local otherHrp = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
                if otherHrp then
                    local distance = (hrp.Position - otherHrp.Position).Magnitude
                    if distance <= avoidDistance then
                        return true, otherHrp.Position  -- Return player position
                    end
                end
            end
        end
        
        return false, nil
    end

    local function disableLavaCollision()
        pcall(function()
            local lavaFolder = Workspace:FindFirstChild("Assets")
            if lavaFolder then
                local caveArea = lavaFolder:FindFirstChild("Cave Area [2]")
                if caveArea then
                    local lava = caveArea:FindFirstChild("Lava")
                    if lava then
                        for _, part in pairs(lava:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                                part.CanTouch = false
                            end
                        end
                    end
                end
            end
        end)
    end

    local function disableAssetsCollision()
        pcall(function()
            local assetsFolder = Workspace:FindFirstChild("Assets")
            if assetsFolder then
                for _, obj in pairs(assetsFolder:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        obj.CanCollide = false
                        obj.CanTouch = false
                        obj.CanQuery = false
                    elseif obj:IsA("Model") then
                        -- Disable collision for models too
                        pcall(function()
                            for _, part in pairs(obj:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                    part.CanTouch = false
                                    part.CanQuery = false
                                end
                            end
                        end)
                    end
                end
                print("Assets collision disabled")
            end
        end)
    end

    local function enableAssetsCollision()
        pcall(function()
            local assetsFolder = Workspace:FindFirstChild("Assets")
            if assetsFolder then
                for _, obj in pairs(assetsFolder:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        obj.CanCollide = true
                        obj.CanTouch = true
                        obj.CanQuery = true
                    elseif obj:IsA("Model") then
                        -- Re-enable collision for models
                        pcall(function()
                            for _, part in pairs(obj:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = true
                                    part.CanTouch = true
                                    part.CanQuery = true
                                end
                            end
                        end)
                    end
                end
                print("Assets collision enabled")
            end
        end)
    end

    local currentTweenLine = nil

    local function createTweenLine(startPos, endPos)
        if currentTweenLine then
            pcall(function() currentTweenLine:Destroy() end)
            currentTweenLine = nil
        end
        
        pcall(function()
            -- Create beam instead of part for better visuals
            local attachment0 = Instance.new("Attachment")
            local attachment1 = Instance.new("Attachment")
            
            local part0 = Instance.new("Part")
            part0.Name = "___TweenLineStart"
            part0.Anchored = true
            part0.CanCollide = false
            part0.CanTouch = false
            part0.Transparency = 1
            part0.Size = Vector3.new(0.1, 0.1, 0.1)
            part0.CFrame = CFrame.new(startPos)
            part0.Parent = workspace
            attachment0.Parent = part0
            
            local part1 = Instance.new("Part")
            part1.Name = "___TweenLineEnd"
            part1.Anchored = true
            part1.CanCollide = false
            part1.CanTouch = false
            part1.Transparency = 1
            part1.Size = Vector3.new(0.1, 0.1, 0.1)
            part1.CFrame = CFrame.new(endPos)
            part1.Parent = workspace
            attachment1.Parent = part1
            
            local beam = Instance.new("Beam")
            beam.Attachment0 = attachment0
            beam.Attachment1 = attachment1
            beam.Color = ColorSequence.new(Color3.fromRGB(80, 160, 255))
            beam.Transparency = NumberSequence.new(0.3)
            beam.Width0 = 0.5
            beam.Width1 = 0.5
            beam.FaceCamera = true
            beam.Parent = part0
            
            currentTweenLine = part0
            
            -- Store part1 reference for cleanup
            part0:SetAttribute("EndPart", part1:GetDebugId())
        end)
    end

    local function removeTweenLine()
        if currentTweenLine then
            pcall(function()
                local endPartId = currentTweenLine:GetAttribute("EndPart")
                if endPartId then
                    for _, obj in pairs(workspace:GetChildren()) do
                        if obj.Name == "___TweenLineEnd" and obj:GetDebugId() == endPartId then
                            obj:Destroy()
                            break
                        end
                    end
                end
                currentTweenLine:Destroy()
            end)
            currentTweenLine = nil
        end
    end

    local function createStabilityPlatform(hrp)
        -- Remove old platform if exists
        if currentStabilityPlatform then
            pcall(function() currentStabilityPlatform:Destroy() end)
            currentStabilityPlatform = nil
        end
        
        if stabilityConnection then
            stabilityConnection:Disconnect()
            stabilityConnection = nil
        end
        
        pcall(function()
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            
            -- Create invisible platform
            local platform = Instance.new("Part")
            platform.Name = "___StabilityPlatform"
            platform.Size = Vector3.new(8, 1, 8)
            platform.Position = hrp.Position - Vector3.new(0, 3.5, 0)
            platform.Anchored = true
            platform.CanCollide = true
            platform.CanTouch = false
            platform.CanQuery = false
            platform.Transparency = 1
            platform.Material = Enum.Material.SmoothPlastic
            platform.Parent = workspace
            
            currentStabilityPlatform = platform
            
            -- Disable humanoid physics
            if humanoid then
                humanoid.PlatformStand = true
                humanoid.AutoRotate = false
            end
            
            -- STRONG physics lock during tween
            stabilityConnection = RunService.Heartbeat:Connect(function()
                if not platform or not platform.Parent or not hrp or not hrp.Parent or not autoFarmEnabled then
                    if stabilityConnection then 
                        stabilityConnection:Disconnect()
                        stabilityConnection = nil
                    end
                    if platform and platform.Parent then
                        platform:Destroy()
                    end
                    currentStabilityPlatform = nil
                    return
                end
                
                -- Keep platform directly below player
                platform.Position = hrp.Position - Vector3.new(0, 3.5, 0)
                
                -- FORCE zero all velocities every frame
                hrp.Velocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
                
                -- Keep player upright and stable
                local currentPos = hrp.Position
                hrp.CFrame = CFrame.new(currentPos) * CFrame.Angles(0, hrp.CFrame.Rotation.Y, 0)
            end)
        end)
    end

    local function removeStabilityPlatform()
        if stabilityConnection then
            stabilityConnection:Disconnect()
            stabilityConnection = nil
        end
        
        if currentStabilityPlatform then
            pcall(function() currentStabilityPlatform:Destroy() end)
            currentStabilityPlatform = nil
        end
        
        -- Re-enable humanoid physics
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
        end
    end

    local currentWaitingPlatform = nil
    local waitingPlatformConnection = nil
    local frozenYPosition = nil

    local function createWaitingPlatform(hrp)
        -- Remove old platform if exists
        if currentWaitingPlatform then
            pcall(function() currentWaitingPlatform:Destroy() end)
            currentWaitingPlatform = nil
        end
        if waitingPlatformConnection then
            waitingPlatformConnection:Disconnect()
            waitingPlatformConnection = nil
        end
        
        pcall(function()
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            
            -- Store the current Y position to freeze at
            frozenYPosition = math.max(hrp.Position.Y, -30)
            
            -- Freeze player at current position
            if humanoid then
                humanoid.PlatformStand = true
                humanoid.AutoRotate = false
            end
            
            -- Create platform below player at frozen position
            local platform = Instance.new("Part")
            platform.Name = "___WaitingPlatform"
            platform.Size = Vector3.new(10, 1, 10)
            platform.Position = Vector3.new(hrp.Position.X, frozenYPosition - 3.5, hrp.Position.Z)
            platform.Anchored = true
            platform.CanCollide = true
            platform.CanTouch = false
            platform.CanQuery = false
            platform.Transparency = 0.5
            platform.Material = Enum.Material.Neon
            platform.Color = Color3.fromRGB(80, 160, 255)
            platform.Parent = workspace
            
            currentWaitingPlatform = platform
            
            -- Keep player frozen at the platform
            waitingPlatformConnection = RunService.Heartbeat:Connect(function()
                if not platform or not platform.Parent or not hrp or not hrp.Parent or not autoFarmEnabled or currentTargetMob then
                    if waitingPlatformConnection then
                        waitingPlatformConnection:Disconnect()
                        waitingPlatformConnection = nil
                    end
                    if platform and platform.Parent then
                        platform:Destroy()
                    end
                    currentWaitingPlatform = nil
                    if humanoid then
                        humanoid.PlatformStand = false
                        humanoid.AutoRotate = true
                    end
                    return
                end
                
                -- FREEZE player at the frozen Y position
                local currentPos = hrp.Position
                hrp.CFrame = CFrame.new(currentPos.X, frozenYPosition, currentPos.Z)
                
                -- Zero all velocities to prevent any movement
                hrp.Velocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
                
                -- Keep platform at frozen position
                platform.Position = Vector3.new(currentPos.X, frozenYPosition - 3.5, currentPos.Z)
            end)
        end)
    end

    local function removeWaitingPlatform()
        if waitingPlatformConnection then
            waitingPlatformConnection:Disconnect()
            waitingPlatformConnection = nil
        end
        if currentWaitingPlatform then
            pcall(function() currentWaitingPlatform:Destroy() end)
            currentWaitingPlatform = nil
        end
        
        -- Unfreeze player
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
        end
        
        frozenYPosition = nil
    end

    local function equipWeapon()
        local VirtualInputManager = game:GetService("VirtualInputManager")
        pcall(function()
            if farmMode == "Mob" then
                -- Mob farming: equip slot 2 first (sword), then slot 1
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
                task.wait(0.2)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
            else
                -- Ore farming: equip slot 1 first (pickaxe), then slot 2
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
                task.wait(0.2)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
            end
        end)
    end

    -- NEW: Function to re-equip weapon during travel
    local function equipWeaponDuringTravel()
        task.spawn(function()
            task.wait(0.5)  -- Wait half a second before equipping
            equipWeapon()
        end)
    end

    local function startAutoClick()
        if clickConnection then return end
        
        task.spawn(function()
            -- Get Knit
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local Knit = nil
            local ToolService = nil
            
            local success, err = pcall(function()
                Knit = require(ReplicatedStorage.Shared.Packages.Knit)
            end)
            
            if not success or not Knit then
                warn("Failed to load Knit:", err)
                return
            end
            
            -- Wait for Knit to start
            Knit.OnStart():andThen(function()
                local serviceSuccess, serviceErr = pcall(function()
                    ToolService = Knit.GetService("ToolService")
                end)
                
                if not serviceSuccess or not ToolService then
                    warn("Failed to get ToolService:", serviceErr)
                    return
                end
                
                print("ToolService loaded successfully!")
                
                local lastActivation = 0
                local activationCooldown = 0.1  -- 10 times per second
                
                clickConnection = RunService.Heartbeat:Connect(function()
                    if not autoFarmEnabled then
                        if clickConnection then
                            clickConnection:Disconnect()
                            clickConnection = nil
                        end
                        return
                    end
                    
                    -- Don't click if avoiding players
                    if isAvoiding then
                        return
                    end
                    
                    -- ONLY CLICK IF UNDER TARGET
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    
                    if not hrp or not currentTargetMob then
                        return
                    end
                    
                    -- Get target root
                    local mobRoot = nil
                    if farmMode == "Mob" then
                        mobRoot = currentTargetMob:FindFirstChild("HumanoidRootPart") or currentTargetMob:FindFirstChild("Head")
                    else
                        mobRoot = currentTargetMob.PrimaryPart or currentTargetMob:FindFirstChildWhichIsA("BasePart")
                    end
                    
                    if not mobRoot then
                        return
                    end
                    
                    -- Check if player is under the target (within attack range)
                    local horizontalDistance = math.sqrt(
                        (hrp.Position.X - mobRoot.Position.X)^2 + 
                        (hrp.Position.Z - mobRoot.Position.Z)^2
                    )
                    
                    local verticalDistance = mobRoot.Position.Y - hrp.Position.Y
                    
                    -- Only click if:
                    -- 1. Horizontally close to target (within attack distance)
                    -- 2. Below the target (positive vertical distance)
                    -- 3. Within reasonable vertical range (not too far below)
                    if horizontalDistance <= attackDistance and verticalDistance > 0 and verticalDistance <= (attackHeight + 10) then
                        local currentTime = tick()
                        if currentTime - lastActivation >= activationCooldown then
                            pcall(function()
                                local tool = char:FindFirstChildOfClass("Tool")
                                if tool then
                                    -- Get the tool name dynamically
                                    local toolName = tool.Name
                                    -- Use Knit's ToolService to activate the tool
                                    ToolService:ToolActivated(toolName)
                                    lastActivation = currentTime
                                end
                            end)
                        end
                    end
                end)
            end):catch(function(err)
                warn("Knit.OnStart() failed:", err)
            end)
        end)
    end

    local function enableNoclip()
        if noclipConnection then return end
        
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                
                -- Prevent falling below -30 ALWAYS (even when dead)
                if hrp and hrp.Position.Y < -30 then
                    hrp.CFrame = CFrame.new(hrp.Position.X, -29, hrp.Position.Z)
                    hrp.Velocity = Vector3.zero
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
                
                -- Only disable collisions when autofarm is active AND player is alive
                if autoFarmEnabled and humanoid and humanoid.Health > 0 then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    end

    -- Constants for freeze system
    local ATTACH_NAME = "___FreezeAttach"
    local TARGET_PART_NAME = "___FreezeTargetPart"
    local ALIGN_NAME = "___FreezeAlign"
    local LERP_SPEED = 12
    local ORIENT_RESPONSIVENESS = 300
    local POS_RESPONSIVENESS = 300
    local MAX_FORCE = 1e9
    local MAX_TORQUE = 1e9

    local function freezePlayerBelowMob(mobRoot)
        -- validate
        if positionConnection then
            positionConnection:Disconnect()
            positionConnection = nil
        end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChild("Humanoid")
        
        if not hrp or not humanoid or not mobRoot then 
            print("freezePlayerBelowMob: Missing requirements")
            return 
        end
        
        if not mobRoot.Parent then
            print("freezePlayerBelowMob: mobRoot has no parent")
            return
        end
        
        -- cleanup previous (this deletes old target part)
        cleanupFreeze(hrp)
        
        -- setup: disable auto rotation and platform stand
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        
        -- INSTANT TELEPORT to position first (no lerp delay)
        local mobPosition = mobRoot.Position
        -- FIXED: Remove the math.max clamp to allow going below -59
        local fixedY = mobPosition.Y - attackHeight  -- CHANGED: Removed math.max(..., -59)
        local targetPos = Vector3.new(mobPosition.X, fixedY, mobPosition.Z)
        local lookAt = CFrame.lookAt(targetPos, mobPosition)
        local layBack = CFrame.Angles(math.rad(180), 0, 0)
        local yaw180 = CFrame.Angles(0, math.rad(180), 0)
        local initialCFrame = lookAt * layBack * yaw180
        
        -- INSTANT POSITION - teleport immediately
        hrp.CFrame = initialCFrame
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        
        -- create an Attachment on HRP (Attachment0)
        local hrpAttachment = Instance.new("Attachment")
        hrpAttachment.Name = ATTACH_NAME
        hrpAttachment.Parent = hrp
        hrpAttachment.Position = Vector3.new(0,0,0)
        hrpAttachment.CFrame = CFrame.new()
        
        -- create a NEW target anchored invisible part to host Attachment1
        local targetPart = Instance.new("Part")
        targetPart.Name = TARGET_PART_NAME
        targetPart.Anchored = true
        targetPart.Size = Vector3.new(0.2,0.2,0.2)
        targetPart.Transparency = 1
        targetPart.CanCollide = false
        targetPart.CanTouch = false
        targetPart.CFrame = initialCFrame  -- Start at correct position
        targetPart.Parent = workspace
        
        local targetAttachment = Instance.new("Attachment")
        targetAttachment.Parent = targetPart
        
        -- container for aligns to make cleanup easy
        local alignContainer = Instance.new("Folder")
        alignContainer.Name = ALIGN_NAME
        alignContainer.Parent = hrp
        
        -- AlignPosition with HIGHER responsiveness for instant lock
        local alignPos = Instance.new("AlignPosition")
        alignPos.Name = "AlignPosition"
        alignPos.Attachment0 = hrpAttachment
        alignPos.Attachment1 = targetAttachment
        alignPos.ApplyAtCenterOfMass = true
        alignPos.MaxForce = MAX_FORCE
        alignPos.Responsiveness = 500  -- INCREASED from 300
        alignPos.RigidityEnabled = true
        alignPos.Parent = alignContainer
        
        -- AlignOrientation with HIGHER responsiveness
        local alignOri = Instance.new("AlignOrientation")
        alignOri.Name = "AlignOrientation"
        alignOri.Attachment0 = hrpAttachment
        alignOri.Attachment1 = targetAttachment
        alignOri.MaxTorque = MAX_TORQUE
        alignOri.Responsiveness = 500  -- INCREASED from 300
        alignOri.PrimaryAxisOnly = false
        alignOri.RigidityEnabled = true
        alignOri.Parent = alignContainer
        
        -- helper to compute "sleeping" CFrame under the mob:
        local function computeTargetCFrame(mobPosition)
            -- FIXED: Remove the math.max clamp here too
            local fixedY = mobPosition.Y - attackHeight  -- CHANGED: Removed math.max(..., -59)
            local targetPos = Vector3.new(mobPosition.X, fixedY, mobPosition.Z)
            local lookAt = CFrame.lookAt(targetPos, mobPosition)
            local layBack = CFrame.Angles(math.rad(180), 0, 0)
            local yaw180 = CFrame.Angles(0, math.rad(180), 0)
            return lookAt * layBack * yaw180
        end
        
        -- initial move: place the targetPart near the mob (lerp to avoid teleport)
        do
            local initialCFrame = computeTargetCFrame(mobRoot.Position)
            targetPart.CFrame = initialCFrame
        end
        
        -- Heartbeat: update targetPart smoothly, zero velocities on HRP to avoid drift
        positionConnection = RunService.Heartbeat:Connect(function(dt)
            -- Check if mob still exists and autofarm is active
            if not autoFarmEnabled or not mobRoot or not mobRoot.Parent or isAvoiding or not hrp or not hrp.Parent or not targetPart or not targetPart.Parent then
                -- cleanup - mob disappeared or avoiding
                if positionConnection then
                    positionConnection:Disconnect()
                    positionConnection = nil
                end
                if humanoid then
                    humanoid.PlatformStand = false
                    humanoid.AutoRotate = true
                end
                cleanupFreeze(hrp)
                return
            end
            
            -- Verify mobRoot still has valid position
            local success, mobPosition = pcall(function()
                return mobRoot.Position
            end)
            
            if not success then
                print("mobRoot position error, cleaning up")
                if positionConnection then
                    positionConnection:Disconnect()
                    positionConnection = nil
                end
                cleanupFreeze(hrp)
                return
            end
            
            -- compute desired CFrame for the target (under mob, facing it, laid on back)
            local desired = computeTargetCFrame(mobPosition)
            
            -- smooth the targetPart movement using Lerp (no teleport). LERP factor based on dt.
            local alpha = math.clamp(LERP_SPEED * dt, 0, 1)
            targetPart.CFrame = targetPart.CFrame:Lerp(desired, alpha)
            
            -- STRONG zeroing of velocities AND anchoring to prevent drift
            hrp.Velocity = Vector3.new(0, 0, 0)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            hrp.RotVelocity = Vector3.new(0, 0, 0)
            -- Temporarily anchor to prevent physics interference
            hrp.Anchored = false -- Keep false to let AlignPosition work
        end)
    end

    local function hideUnderground()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        unfreezePlayer()
        
        local hideY = math.max(hrp.Position.Y - 50, -59)
        local hidePos = Vector3.new(hrp.Position.X, hideY, hrp.Position.Z)
        
        -- INSTANT teleport when player detected
        hrp.CFrame = CFrame.new(hidePos)
    end

    local function freezeAtNegative30()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        unfreezePlayer()
        
        local freezePos = Vector3.new(hrp.Position.X, -30, hrp.Position.Z)
        hrp.CFrame = CFrame.new(freezePos)
        hrp.Anchored = true
        waitingLabel.Visible = true
    end

    local function unfreezeFromWaiting()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = false
        end
        waitingLabel.Visible = false
    end

    local deathConnection = nil
    local function setupDeathDetection()
        if deathConnection then
            deathConnection:Disconnect()
        end
        
        local char = LocalPlayer.Character
        if not char then return end
        
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        deathConnection = humanoid.Died:Connect(function()
            print("Player died - INSTANT cleanup...")
            
            -- STORE the autofarm state BEFORE disabling
            local wasAutoFarmEnabled = autoFarmEnabled
            
            -- INSTANT DISABLE EVERYTHING
            autoFarmEnabled = false
            
            -- Cancel all tweens
            if currentTween then
                currentTween:Cancel()
                currentTween = nil
            end
            removeTweenLine()
            
            -- Remove stability platform
            removeStabilityPlatform()
            
            -- Stop all connections
            stopAutoClick()
            
            -- Disconnect position connection immediately
            if positionConnection then
                positionConnection:Disconnect()
                positionConnection = nil
            end
            
            -- Force cleanup workspace part IMMEDIATELY
            for i = 1, 5 do
                local ap = workspace:FindFirstChild("___FreezeTargetPart")
                if ap then pcall(function() ap:Destroy() end) end
            end
            
            -- Cleanup player attachments
            pcall(function()
                local oldChar = LocalPlayer.Character
                if oldChar then
                    local hrp = oldChar:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        cleanupFreeze(hrp)
                    end
                end
            end)
            
            -- Reset all state
            isAvoiding = false
            currentTargetMob = nil
            playerWarningLabel.Visible = false
            waitingLabel.Visible = false
            flyingToLabel.Visible = false
            healthDisplayLabel.Visible = false
            
            -- ONLY re-enable if autofarm was enabled before death
            if not wasAutoFarmEnabled then
                print("Autofarm was not enabled before death, not re-enabling")
                return
            end
            
            -- Wait 5 seconds before respawn
            print("Waiting 5 seconds...")
            task.wait(5)
            
            -- Wait for new character
            print("Waiting for character respawn...")
            char = LocalPlayer.CharacterAdded:Wait()
            task.wait(1)
            
            -- Verify character is loaded
            local newHrp = char:WaitForChild("HumanoidRootPart", 10)
            if not newHrp then
                print("Failed to get HumanoidRootPart after respawn")
                return
            end
            
            local newHumanoid = char:WaitForChild("Humanoid", 10)
            if not newHumanoid then
                print("Failed to get Humanoid after respawn")
                return
            end
            
            -- Ensure player is above -30
            if newHrp.Position.Y < -30 then
                newHrp.CFrame = CFrame.new(newHrp.Position.X, -25, newHrp.Position.Z)
            end
            
            -- Final cleanup check
            cleanupFreeze(nil)
            
            -- Re-enable autofarm
            print("Re-enabling autofarm...")
            autoFarmEnabled = true
            task.wait(0.5)
            
            disableLavaCollision()
            disableAssetsCollision()
            enableNoclip()
            setupDeathDetection()
            task.spawn(autoFarmLoop)
        end)
    end

    -- Setup death detection when character loads
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1)
        if autoFarmEnabled then
            setupDeathDetection()
        end
    end)

    local lastFarmMode = nil

    -- Auto Sell Variables
    local autoSellEnabled = false
    local autoSellInterval = 300 -- 5 minutes in seconds
    local lastSellTime = 0
    local selectedSellItems = {
        Copper = false, 
        Stone = false,
        ["Sand Stone"] = false
    }

    -- Function to get inventory quantity for an item
    local function getInventoryQuantity(itemName)
        local success, quantity = pcall(function()
            local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
            if not playerGui then return 0 end
            
            local menu = playerGui:FindFirstChild("Menu")
            if not menu then return 0 end
            
            local frame = menu:FindFirstChild("Frame")
            if not frame then return 0 end
            
            local frame2 = frame:FindFirstChild("Frame")
            if not frame2 then return 0 end
            
            local menus = frame2:FindFirstChild("Menus")
            if not menus then return 0 end
            
            local stash = menus:FindFirstChild("Stash")
            if not stash then return 0 end
            
            local background = stash:FindFirstChild("Background")
            if not background then return 0 end
            
            -- First try direct folder match (for ores and regular essences)
            local itemFolder = background:FindFirstChild(itemName)
            if itemFolder then
                local main = itemFolder:FindFirstChild("Main")
                if not main then return 0 end
                
                local quantityLabel = main:FindFirstChild("Quantity")
                if not quantityLabel then
                    -- fallback: find first TextLabel inside Main
                    for _, c in ipairs(main:GetChildren()) do
                        if c:IsA("TextLabel") then
                            quantityLabel = c
                            break
                        end
                    end
                    if not quantityLabel then return 0 end
                end
                
                -- Extract numbers from text
                local text = tostring(quantityLabel.Text or "")
                local digits = text:gsub("%D", "")
                if digits == "" then return 0 end
                return tonumber(digits) or 0
            end
            
            -- If not found, search for runes/shards by ItemName TextLabel
            for _, folder in pairs(background:GetChildren()) do
                if folder:IsA("Frame") or folder:IsA("Folder") then
                    local main = folder:FindFirstChild("Main")
                    if main then
                        local itemNameLabel = main:FindFirstChild("ItemName")
                        if itemNameLabel and itemNameLabel:IsA("TextLabel") then
                            if itemNameLabel.Text == itemName then
                                -- Found matching rune/shard, get quantity
                                local quantityLabel = main:FindFirstChild("Quantity")
                                if not quantityLabel then
                                    -- fallback: find first TextLabel that's not ItemName
                                    for _, c in ipairs(main:GetChildren()) do
                                        if c:IsA("TextLabel") and c ~= itemNameLabel then
                                            quantityLabel = c
                                            break
                                        end
                                    end
                                    if not quantityLabel then return 0 end
                                end
                                
                                -- Extract numbers from text
                                local text = tostring(quantityLabel.Text or "")
                                local digits = text:gsub("%D", "")
                                if digits == "" then return 0 end
                                return tonumber(digits) or 0
                            end
                        end
                    end
                end
            end
            
            return 0
        end)
        
        return success and quantity or 0
    end

    -- Perform auto-sell (fixed)
    local function performAutoSell()
        if not autoSellEnabled then
            print("Auto-sell disabled; aborting.")
            return
        end

        print("Starting auto-sell sequence.")

        -- Step 1: Build itemsToSell table based on selected flags and GUI quantities
        local itemsToSell = {}
        local totalTypes = 0
        local totalQuantity = 0

        for itemName, selected in pairs(selectedSellOres) do
            if selected then
                local qty = getInventoryQuantity(itemName)
                if qty > 0 then
                    itemsToSell[itemName] = qty
                    totalTypes = totalTypes + 1
                    totalQuantity = totalQuantity + qty
                    print("Found " .. tostring(qty) .. "x " .. tostring(itemName) .. " in inventory")
                end
            end
        end

        for itemName, selected in pairs(selectedSellDrops) do
            if selected then
                local qty = getInventoryQuantity(itemName)
                if qty > 0 then
                    itemsToSell[itemName] = qty
                    totalTypes = totalTypes + 1
                    totalQuantity = totalQuantity + qty
                    print("Found " .. tostring(qty) .. "x " .. itemName .. " in inventory")
                end
            end
        end

        if totalTypes == 0 then
            print("No selected items with quantity found; skipping sell.")
            return
        end

        print("Preparing to sell " .. tostring(totalQuantity) .. " items across " .. tostring(totalTypes) .. " types.")

        -- Step 2: Optionally tween to seller (if you want to keep movement)
        -- If you already perform movement elsewhere (initial visit), you can skip here.

        -- Step 3: Call RunCommand safely (use WaitForChild to avoid nil)
        local success, result = pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local shared = rs:WaitForChild("Shared", 5)
            if not shared then error("ReplicatedStorage.Shared missing") end
            local packages = shared:WaitForChild("Packages", 5)
            if not packages then error("Shared.Packages missing") end
            local knit = packages:WaitForChild("Knit", 5)
            if not knit then error("Knit folder missing") end
            local services = knit:WaitForChild("Services", 5)
            if not services then error("Knit.Services missing") end
            local dialogue = services:WaitForChild("DialogueService", 5)
            if not dialogue then error("DialogueService missing") end
            local rf = dialogue:WaitForChild("RF", 5)
            if not rf then error("DialogueService.RF missing") end
            local runCommandRF = rf:WaitForChild("RunCommand", 5)
            if not runCommandRF then error("RunCommand RemoteFunction missing") end

            local arguments = {
                [1] = "SellConfirm",
                [2] = {
                    ["Basket"] = itemsToSell
                }
            }
            return runCommandRF:InvokeServer(unpack(arguments))
        end)

        if success then
            print("Sell succeeded! Result:", result)
        else
            warn("Sell failed:", result)
        end

        print("Auto-sell finished.")
    end

    local isVisitingSeller = false  -- global or upvalue

    local function performInitialSellerVisit()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        isVisitingSeller = true  -- block autofarm
        
        local isMap2 = Workspace:FindFirstChild("Proximity") and Workspace.Proximity:FindFirstChild("Gurak") ~= nil
        local sellerPos = isMap2 and Vector3.new(-139.706, 20.711, -24.840)
            or Vector3.new(-112.156, 36.901, -38.552)
        
        local moveSpeed = 45
        
        local function tweenTo(targetPos, speed)
            speed = speed or moveSpeed
            local dist = (hrp.Position - targetPos).Magnitude
            local tween = TweenService:Create(hrp,
                TweenInfo.new(dist / speed, Enum.EasingStyle.Linear),
                {CFrame = CFrame.new(targetPos)})
            tween:Play()
            tween.Completed:Wait()
        end
        
        -- Step 1: Tween fly to -30Y below seller coordinates
        local undergroundPos = Vector3.new(sellerPos.X, -30, sellerPos.Z)
        tweenTo(undergroundPos)
        
        -- Step 2: Instant TP up to seller coordinates
        hrp.CFrame = CFrame.new(sellerPos)
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        
        task.wait(0.2)
        
        -- Step 3: Click E for 0.5 seconds
        local VIM = game:GetService("VirtualInputManager")
        local clickDuration = 0.5
        local clickStart = tick()
        
        while tick() - clickStart < clickDuration do
            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            task.wait(0.05)
        end
        
        task.wait(0.3)
        
        -- Perform sell
        performAutoSell()
        
        task.wait(0.3)
        
        -- Step 4: Instant TP back down to -30Y
        hrp.CFrame = CFrame.new(undergroundPos)
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        
        task.wait(0.2)
        
        -- Step 5: Re-equip weapon
        equipWeapon()
        
        isVisitingSeller = false  -- unblock autofarm
    end

    local function autoFarmLoop()
        
        -- ADDED: Check if farm mode is selected
        if not farmMode then
            print("ERROR: No farm mode selected!")
            autoFarmEnabled = false
            -- Show warning
            local warningLabel = Instance.new("TextLabel")
            warningLabel.Size = UDim2.new(0, 300, 0, 40)
            warningLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
            warningLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            warningLabel.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            warningLabel.Text = "⚠️ Select Mob or Ore Farm Mode First!"
            warningLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            warningLabel.Font = Enum.Font.GothamBold
            warningLabel.TextSize = 14
            warningLabel.Parent = screenGui
            warningLabel.ZIndex = 2000
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = warningLabel
            task.wait(3)
            warningLabel:Destroy()
            return
        end

        -- ADDED: Check if any targets are selected
        local hasTargets = false
        if farmMode == "Mob" then
            for _, selected in pairs(selectedEnemies) do
                if selected then
                    hasTargets = true
                    break
                end
            end
        else
            for _, selected in pairs(selectedOres) do
                if selected then
                    hasTargets = true
                    break
                end
            end
        end

        if not hasTargets then
            print("ERROR: No targets selected!")
            autoFarmEnabled = false
            -- Show warning
            local warningLabel = Instance.new("TextLabel")
            warningLabel.Size = UDim2.new(0, 300, 0, 40)
            warningLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
            warningLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            warningLabel.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            warningLabel.Text = "⚠️ Select at least one " .. (farmMode == "Mob" and "Mob" or "Ore") .. "!"
            warningLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            warningLabel.Font = Enum.Font.GothamBold
            warningLabel.TextSize = 14
            warningLabel.Parent = screenGui
            warningLabel.ZIndex = 2000
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = warningLabel
            task.wait(3)
            warningLabel:Destroy()
            return
        end

        -- Cleanup any leftover parts
        cleanupFreeze(nil)
        local oldPart = workspace:FindFirstChild("___FreezeTargetPart")
        if oldPart then
            oldPart:Destroy()
        end
        task.wait(0.5)

        updateLastSelection()
        setupDeathDetection()

        -- Initialize lastFarmMode
        lastFarmMode = farmMode

        -- MODIFIED: Initial seller visit if auto-sell enabled
        if autoSellEnabled and not hasSoldOnce then
            print("First time - visiting seller...")
            performInitialSellerVisit()
            hasSoldOnce = true
            
            -- After seller visit, re-equip weapon and reset character
            print("Post-seller cleanup...")

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            if hrp then
                hrp.Anchored = false
                hrp.Velocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero

                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.PlatformStand = false
                    humanoid.AutoRotate = true
                end
            end

            task.wait(0.5)
            print("Ready to start farming!")
        end

        -- Disable Assets collision
        disableAssetsCollision()
        -- Start auto-clicking
        startAutoClick()

        -- MAIN FARM LOOP
        while autoFarmEnabled do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                local mob, mobRoot, targetType

                -- Check if farm mode changed and re-equip weapon
                if lastFarmMode ~= farmMode then
                    print("Farm mode changed from " .. tostring(lastFarmMode) .. " to " .. tostring(farmMode) .. " - re-equipping weapon")
                    
                    -- Cancel current operations
                    if currentTween then
                        currentTween:Cancel()
                        currentTween = nil
                    end
                    removeTweenLine()
                    unfreezePlayer()
                    currentTargetMob = nil
                    healthDisplayLabel.Visible = false
                    flyingToLabel.Visible = false
                    waitingLabel.Visible = false
                    isAvoiding = false
                    playerWarningLabel.Visible = false

                    -- Re-equip weapon for new mode
                    equipWeapon()
                    task.wait(0.5)
                    lastFarmMode = farmMode
                end

                -- Before creating/finding new mobs/ores
                if isVisitingSeller then
                    -- Skip this loop iteration entirely
                    task.wait(0.1)
                    continue  -- or `return`/`break` depending on loop structure
                end

                -- Choose target based on farm mode
                if farmMode == "Mob" then
                    mob, mobRoot, targetType = findTargetMob()
                elseif farmMode == "Ore" then
                    mob, mobRoot, targetType = findTargetOre()
                else
                    print("ERROR: Invalid farm mode:", farmMode)
                    break
                end

                if mob and mobRoot and mob.Parent and mobRoot.Parent then
                    equipWeapon()
                    
                    -- Found a target - HIDE waiting label immediately
                    waitingLabel.Visible = false
                    
                    -- Remove waiting platform since we have a target
                    removeWaitingPlatform()
                    
                    -- Highlight the target
                    if currentTargetHighlight then
                        pcall(function() currentTargetHighlight:Destroy() end)
                    end
                    currentTargetHighlight = createHighlight(mob, Color3.fromRGB(80, 160, 255), 0.4)
                    
                    -- Add particle effects
                    if currentTargetParticles then
                        pcall(function() currentTargetParticles:Destroy() end)
                    end
                    currentTargetParticles = createParticleEffect(mobRoot)
                    
                    -- Show flying label
                    flyingToLabel.Text = "Flying to: " .. tostring(targetType)
                    flyingToLabel.Visible = true
                    
                    if hrp.Anchored then
                        hrp.Anchored = false
                    end
                    
                    currentTargetMob = mob
                    local mobPosition = mobRoot.Position
                    
                    -- NEW MOVEMENT LOGIC: Instant TP to -20Y, then tween horizontally at -20Y, then drop below
                    local startPos = hrp.Position
                    
                    -- Step 1: INSTANT TP to -20Y at current position
                    local currentX = hrp.Position.X
                    local currentZ = hrp.Position.Z
                    hrp.CFrame = CFrame.new(currentX, -20, currentZ)
                    hrp.Velocity = Vector3.zero
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    
                    -- Step 2: Tween horizontally at -20Y to target X,Z position
                    local intermediatePos = Vector3.new(mobPosition.X, -20, mobPosition.Z)
                    local distanceToIntermediate = (hrp.Position - intermediatePos).Magnitude
                    
                    createStabilityPlatform(hrp)
                    task.wait(0.05)
                    hrp.Velocity = Vector3.zero
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.Anchored = false
                    
                    createTweenLine(hrp.Position, intermediatePos)
                    local tweenInfo = TweenInfo.new(distanceToIntermediate / tweenSpeedFarm, Enum.EasingStyle.Linear)
                    currentTween = TweenService:Create(hrp, tweenInfo, { CFrame = CFrame.new(intermediatePos) })
                    currentTween:Play()
                    currentTween.Completed:Wait()
                    currentTween = nil
                    
                    removeTweenLine()
                    removeStabilityPlatform()
                    
                    -- Step 3: Instant TP to final position below target
                    local finalY = mobPosition.Y - attackHeight
                    local finalPos = Vector3.new(mobPosition.X, finalY, mobPosition.Z)
                    
                    -- Instant teleport (NO TWEEN LINE HERE)
                    hrp.CFrame = CFrame.new(finalPos)
                    hrp.Velocity = Vector3.zero
                    
                    -- Show flying label
                    flyingToLabel.Visible = false
                    
                    -- Attack phase - Verify mob is still valid before freezing
                    if not mob or not mob.Parent or not mobRoot or not mobRoot.Parent then
                        print("Mob or mobRoot invalid before freeze, skipping")
                        currentTargetMob = nil
                        healthDisplayLabel.Visible = false
                    else
                        local freezeSuccess = pcall(function()
                            freezePlayerBelowMob(mobRoot)
                        end)
                        
                        if not freezeSuccess then
                            print("Failed to freeze player, skipping target")
                            currentTargetMob = nil
                            healthDisplayLabel.Visible = false
                            unfreezePlayer()
                        else
                            local avoidStartTime = nil
                            local lastHealthCheck = tick()
                            local healthCheckInterval = 0.05
                            local consecutiveZeroHP = 0
                            
                            while autoFarmEnabled and mob and mob.Parent do
                                -- Verify mobRoot is still valid
                                if not mobRoot or not mobRoot.Parent then
                                    print("mobRoot became invalid during attack")
                                    break
                                end
                                
                                -- Check if mode changed during attack
                                if lastFarmMode ~= farmMode then
                                    print("Mode changed during attack - breaking to re-equip")
                                    unfreezePlayer()
                                    currentTargetMob = nil
                                    healthDisplayLabel.Visible = false
                                    break
                                end
                                
                                -- Check if selection changed
                                if hasSelectionChanged() then
                                    print("Selection changed - checking if current target is still valid...")
                                    local currentTargetValid = false
                                    
                                    if farmMode == "Mob" then
                                        for enemyName, enabled in pairs(selectedEnemies) do
                                            if enabled and mob.Name:find(enemyName) then
                                                currentTargetValid = true
                                                break
                                            end
                                        end
                                    else
                                        for oreName, enabled in pairs(selectedOres) do
                                            if enabled and mob.Name:lower():find(oreName:lower()) then
                                                currentTargetValid = true
                                                break
                                            end
                                        end
                                    end
                                    
                                    if not currentTargetValid then
                                        print("Current target no longer selected, switching...")
                                        if currentTween then
                                            currentTween:Cancel()
                                            currentTween = nil
                                        end
                                        removeTweenLine()
                                        unfreezePlayer()
                                        currentTargetMob = nil
                                        healthDisplayLabel.Visible = false
                                        maxHealthCache[tostring(mob)] = nil
                                        updateLastSelection()
                                        break
                                    end
                                    
                                    updateLastSelection()
                                end
                                
                                local currentTime = tick()
                                
                                -- Health check logic
                                if currentTime - lastHealthCheck >= healthCheckInterval then
                                    lastHealthCheck = currentTime
                                    if farmMode == "Ore" then
                                        local currentHP = getRockHP(mob)
                                        if not currentHP or currentHP <= 0 then
                                            consecutiveZeroHP = consecutiveZeroHP + 1
                                            if consecutiveZeroHP >= 2 then
                                                print("Rock depleted, switching immediately...")
                                                maxHealthCache[tostring(mob)] = nil
                                                healthDisplayLabel.Visible = false
                                                unfreezePlayer()
                                                break
                                            end
                                        else
                                            consecutiveZeroHP = 0
                                            updateHealthDisplay(mob, targetType, currentHP)
                                        end
                                    elseif farmMode == "Mob" then
                                        local mobHumanoid = mob:FindFirstChild("Humanoid")
                                        if mobHumanoid then
                                            -- FIXED: Check actual health value BEFORE flooring
                                            local actualHP = mobHumanoid.Health
                                            if actualHP <= 0 then
                                                consecutiveZeroHP = consecutiveZeroHP + 1
                                                if consecutiveZeroHP >= 2 then
                                                    print("Mob defeated, switching immediately...")
                                                    maxHealthCache[tostring(mob)] = nil
                                                    healthDisplayLabel.Visible = false
                                                    unfreezePlayer()
                                                    break
                                                end
                                            else
                                                consecutiveZeroHP = 0
                                                -- Display floored value but check actual value
                                                local displayHP = math.floor(actualHP)
                                                updateHealthDisplay(mob, targetType, displayHP)
                                            end
                                        end
                                    end
                                end
                        
                                -- Player detection check
                                local playerDetected, detectedPlayerPos = checkNearbyPlayers()
                                if playerDetected then
                                    if not isAvoiding then
                                        isAvoiding = true
                                        avoidStartTime = tick()
                                        playerWarningLabel.Visible = true
                                        healthDisplayLabel.Visible = false
                                        
                                        task.spawn(function()
                                            task.wait(3)
                                            playerWarningLabel.Visible = false
                                        end)
                                        
                                        -- IMPORTANT: Unfreeze and cancel current operations
                                        if currentTween then
                                            currentTween:Cancel()
                                            currentTween = nil
                                        end
                                        removeTweenLine()
                                        unfreezePlayer()
                                        
                                        if currentTargetMob then
                                            maxHealthCache[tostring(currentTargetMob)] = nil
                                        end
                                        
                                        if detectedPlayerPos then
                                            print("Player detected - switching to farthest target")
                                            -- CLEANUP OLD HIGHLIGHTS IMMEDIATELY
                                            if currentTargetHighlight then
                                                pcall(function() currentTargetHighlight:Destroy() end)
                                                currentTargetHighlight = nil
                                            end
                                            if currentTargetParticles then
                                                pcall(function() currentTargetParticles:Destroy() end)
                                                currentTargetParticles = nil
                                            end
                                            
                                            local newMob, newMobRoot, newTargetType
                                            if farmMode == "Ore" then
                                                newMob, newMobRoot, newTargetType = findTargetOre(detectedPlayerPos)
                                            elseif farmMode == "Mob" then
                                                newMob, newMobRoot, newTargetType = findTargetMob(detectedPlayerPos)
                                            end
                                            
                                            if newMob and newMobRoot and newMob ~= mob then
                                                print("Switching to farthest:", newTargetType, "from player")
                                                -- Clear current target
                                                currentTargetMob = nil
                                                
                                                -- CREATE NEW HIGHLIGHTS IMMEDIATELY
                                                currentTargetHighlight = createHighlight(newMob, Color3.fromRGB(80, 160, 255), 0.4)
                                                currentTargetParticles = createParticleEffect(newMobRoot)
                                                
                                                -- TWEEN to the new furthest target
                                                local newMobPosition = newMobRoot.Position
                                                
                                                -- Step 1: Instant TP to -20Y at current position
                                                local currentX = hrp.Position.X
                                                local currentZ = hrp.Position.Z
                                                hrp.CFrame = CFrame.new(currentX, -20, currentZ)
                                                hrp.Velocity = Vector3.zero
                                                hrp.AssemblyLinearVelocity = Vector3.zero
                                                
                                                -- Step 2: Tween horizontally at -20Y to new target
                                                local intermediatePos = Vector3.new(newMobPosition.X, -20, newMobPosition.Z)
                                                local distanceToIntermediate = (hrp.Position - intermediatePos).Magnitude
                                                
                                                createStabilityPlatform(hrp)
                                                task.wait(0.05)
                                                hrp.Velocity = Vector3.zero
                                                hrp.AssemblyLinearVelocity = Vector3.zero
                                                hrp.Anchored = false
                                                
                                                createTweenLine(hrp.Position, intermediatePos)
                                                local tweenInfo = TweenInfo.new(distanceToIntermediate / tweenSpeedFarm, Enum.EasingStyle.Linear)
                                                currentTween = TweenService:Create(hrp, tweenInfo, { CFrame = CFrame.new(intermediatePos) })
                                                currentTween:Play()
                                                currentTween.Completed:Wait()
                                                currentTween = nil
                                                
                                                removeTweenLine()
                                                removeStabilityPlatform()
                                                
                                                -- Step 3: Instant TP to final position
                                                local finalY = newMobPosition.Y - attackHeight
                                                local finalPos = Vector3.new(newMobPosition.X, finalY, newMobPosition.Z)
                                                hrp.CFrame = CFrame.new(finalPos)
                                                hrp.Velocity = Vector3.zero
                                                
                                                -- Set new target
                                                currentTargetMob = newMob
                                                mob = newMob
                                                mobRoot = newMobRoot
                                                targetType = newTargetType
                                                isAvoiding = false
                                                flyingToLabel.Visible = false
                                                
                                                -- FREEZE PLAYER AT NEW TARGET
                                                local freezeSuccess = pcall(function()
                                                    freezePlayerBelowMob(newMobRoot)
                                                end)
                                                
                                                if not freezeSuccess then
                                                    print("Failed to freeze at new target after player detection")
                                                end
                                                
                                                -- Continue attacking new target (don't break)
                                            else
                                                print("No alternative target found - staying away")
                                                isAvoiding = false
                                                currentTargetMob = nil
                                                flyingToLabel.Visible = false
                                                unfreezePlayer()
                                                break
                                            end
                                        else
                                            isAvoiding = false
                                            currentTargetMob = nil
                                            flyingToLabel.Visible = false
                                            unfreezePlayer()
                                            break
                                        end
                                    end
                                elseif isAvoiding then
                                    isAvoiding = false
                                    if not mob or not mob.Parent then
                                        break
                                    end
                                    
                                    if farmMode == "Ore" then
                                        local currentHP = getRockHP(mob)
                                        if not currentHP or currentHP <= 0 then
                                            print("Rock depleted during avoid, switching...")
                                            unfreezePlayer()
                                            break
                                        end
                                    end
                                    
                                    -- Re-freeze at current target
                                    if farmingPosition == "Above" then
                                        freezePlayerAboveMob(mobRoot)
                                    else
                                        freezePlayerBelowMob(mobRoot)
                                    end
                                end
                                
                                task.wait(0.05)
                            end
                        end
                    end

                    -- Cleanup after target defeated
                    healthDisplayLabel.Visible = false
                    unfreezePlayer()
                    isAvoiding = false
                    playerWarningLabel.Visible = false
                    flyingToLabel.Visible = false
                    currentTargetMob = nil
                    waitingLabel.Visible = false
                    removeTweenLine()

                    -- Auto-sell after each target if enabled
                    if autoSellEnabled and hasSoldOnce then
                        print("Target finished - performing auto-sell...")
                        performAutoSell()
                    end

                else
                    currentTargetMob = nil
                    healthDisplayLabel.Visible = false
                    waitingLabel.Visible = true
                    updateWaitingLabel()
                    
                    -- Create waiting platform to prevent falling
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        createWaitingPlatform(hrp)
                    end
                    
                    task.wait(2)
                    continue
                end
            end

            task.wait(0.1)
        end

        stopAutoClick()
        playerWarningLabel.Visible = false
        flyingToLabel.Visible = false
        waitingLabel.Visible = false
        unfreezeFromWaiting()
        
    end

    -- Calculate dynamic position for toggles based on dropdown visibility
    local function getToggleStartY()
        if dropdownList.Visible then
            -- Dropdown is open - add space for it
            return 50 + selectionContainer.AbsoluteSize.Y + 20
        else
            -- Dropdown is closed - move everything up
            return 50 + 65 + 50 + 20  -- modeButtonContainer height + dropdown button height + spacing
        end
    end

    -- Wait for layout to calculate
    task.wait(0.1)
    local toggleStartY = getToggleStartY()

    local autoFarmToggle, getAutoFarmState = createToggle(mainPage, "Auto Farm", toggleStartY, function(state)
        autoFarmEnabled = state
        if state then
            -- Set FOV to 90
            local camera = workspace.CurrentCamera
            if camera then
                camera.FieldOfView = 90
            end
            
            -- Highlight player model
            local char = LocalPlayer.Character
            if char then
                local livingFolder = Workspace:FindFirstChild("Living")
                if livingFolder then
                    local playerModel = livingFolder:FindFirstChild(LocalPlayer.Name)
                    if playerModel then
                        playerModelHighlight = createHighlight(playerModel, Color3.fromRGB(80, 160, 255), 0.6)
                    end
                end
            end
            disableLavaCollision()
            enableNoclip()
            setupDeathDetection()
            startHighlightMaintenance()
            task.spawn(autoFarmLoop)
        else
            -- Reset FOV to default (70)
            local camera = workspace.CurrentCamera
            if camera then
                camera.FieldOfView = 70
            end
            
            stopHighlightMaintenance()
            
            -- ADDED: Remove all highlights
            if playerModelHighlight then
                pcall(function() playerModelHighlight:Destroy() end)
                playerModelHighlight = nil
            end
            if currentTargetHighlight then
                pcall(function() currentTargetHighlight:Destroy() end)
                currentTargetHighlight = nil
            end
            if currentTargetParticles then
                pcall(function() currentTargetParticles:Destroy() end)
                currentTargetParticles = nil
            end
            
            -- Disable blue GUI mode
            setGUIBlueMode(false)
            -- Cancel all tweens
            if currentTween then
                currentTween:Cancel()
                currentTween = nil
            end
            removeTweenLine()
            -- Stop all connections
            stopAutoClick()
            unfreezePlayer()
            disableNoclip()
            -- Remove stability platform
            removeStabilityPlatform()
            -- Remove waiting platform
            removeWaitingPlatform()
            -- Re-enable Assets collision
            enableAssetsCollision()
            -- Reset state
            isAvoiding = false
            currentTargetMob = nil
            playerWarningLabel.Visible = false
            waitingLabel.Visible = false
            flyingToLabel.Visible = false
            healthDisplayLabel.Visible = false
            -- Freeze character safely
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                if hrp then
                    hrp.Anchored = true
                    hrp.Velocity = Vector3.zero
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
                if humanoid then
                    humanoid.PlatformStand = true
                    humanoid.AutoRotate = false
                    humanoid.Sit = true
                end
                -- Ensure collisions are enabled
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
            if deathConnection then
                deathConnection:Disconnect()
                deathConnection = nil
            end
            -- Create safety platform and reset like CLOSE button
            task.spawn(function()
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local platformPart = Instance.new("Part")
                platformPart.Name = "___SafetyPlatform"
                platformPart.Size = Vector3.new(10, 1, 10)
                platformPart.Position = hrp.Position - Vector3.new(0, 5, 0)
                platformPart.Anchored = true
                platformPart.CanCollide = true
                platformPart.Material = Enum.Material.SmoothPlastic
                platformPart.BrickColor = BrickColor.new("Bright blue")
                platformPart.Transparency = 0.3
                platformPart.Parent = workspace
                task.wait(6)
                pcall(function()
                    if platformPart then
                        platformPart:Destroy()
                    end
                end)
                pcall(resetCharacterMobile)
            end)
        end
    end)

    createToggle(mainPage, "Avoid Players", toggleStartY + (isMobile and 50 or 45), function(state)
        avoidEnabled = state
    end)

    createSlider(mainPage, "Avoid Distance", 0, 100, 50, toggleStartY + (isMobile and 100 or 90), function(value)
        avoidDistance = value
    end)

    createSlider(mainPage, "Attack Height", 1, 100, 9, toggleStartY + (isMobile and 165 or 150), function(value)
        attackHeight = value
        if positionConnection and currentTargetMob then
            local mobRoot = nil
            if farmMode == "Mob" then
                mobRoot = currentTargetMob:FindFirstChild("HumanoidRootPart") or currentTargetMob:FindFirstChild("Head")
            else
                mobRoot = currentTargetMob.PrimaryPart or currentTargetMob:FindFirstChildWhichIsA("BasePart")
            end
            if mobRoot then
                unfreezePlayer()
                task.wait(0.05)
                freezePlayerBelowMob(mobRoot)
            end
        end
    end)

    createSlider(mainPage, "Tween Speed", 10, 100, 45, toggleStartY + (isMobile and 230 or 210), function(value)
        tweenSpeedFarm = value
        tweenSpeedInitial = value
        tweenSpeedReturn = value
        tweenSpeedSwitch = value
    end)

    -- Map Transparency Slider (NEW)
    local mapTransparency = 0
    local transparencyCache = {} -- Cache original transparency values

    local function applyMapTransparency(value)
        mapTransparency = value
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                -- Skip player character and GUI-related objects
                local char = LocalPlayer.Character
                if char and obj:IsA("BasePart") and obj:IsDescendantOf(char) then
                    continue
                end
                
                -- Skip Living folder (mobs/players)
                local livingFolder = Workspace:FindFirstChild("Living")
                if livingFolder and obj:IsDescendantOf(livingFolder) then
                    continue
                end
                
                -- Skip Rocks folder (ores)
                local rocksFolder = Workspace:FindFirstChild("Rocks")
                if rocksFolder and obj:IsDescendantOf(rocksFolder) then
                    continue
                end
                
                -- Skip autofarm-related parts
                if obj.Name == "___FreezeTargetPart" or obj.Name == "___SafetyPlatform" or obj.Name == "___TweenLine" or obj.Name == "___TweenLineStart" or obj.Name == "___TweenLineEnd" or obj.Name == "___StabilityPlatform" or obj.Name == "___WaitingPlatform" then
                    continue
                end
                
                -- Skip highlights and particle effects
                if obj:IsA("Highlight") or obj:IsA("ParticleEmitter") or obj:IsA("Attachment") then
                    continue
                end
                
                -- Apply transparency to parts
                if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                    -- Cache original transparency on first change
                    local objId = tostring(obj:GetDebugId())
                    if not transparencyCache[objId] then
                        transparencyCache[objId] = obj.Transparency
                    end
                    -- FIXED: Use value directly instead of adding to original
                    obj.Transparency = value
                -- Apply transparency to textures and decals
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    local objId = tostring(obj:GetDebugId())
                    if not transparencyCache[objId] then
                        transparencyCache[objId] = obj.Transparency
                    end
                    -- FIXED: Use value directly
                    obj.Transparency = value
                -- Apply transparency to surface appearances
                elseif obj:IsA("SurfaceAppearance") then
                    local objId = tostring(obj:GetDebugId())
                    if not transparencyCache[objId] then
                        transparencyCache[objId] = obj.AlphaMode
                    end
                    if value > 0.5 then
                        obj.AlphaMode = Enum.AlphaMode.Transparent
                    else
                        obj.AlphaMode = transparencyCache[objId] or Enum.AlphaMode.Overlay
                    end
                end
            end
        end)
    end

    local function resetMapTransparency()
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                local objId = tostring(obj:GetDebugId())
                
                if transparencyCache[objId] then
                    if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                        obj.Transparency = transparencyCache[objId]
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        obj.Transparency = transparencyCache[objId]
                    elseif obj:IsA("SurfaceAppearance") then
                        obj.AlphaMode = transparencyCache[objId]
                    end
                end
            end
            
            transparencyCache = {}
        end)
    end

    createSlider(mainPage, "Map Transparency", 0, 100, 0, toggleStartY + (isMobile and 295 or 270), function(value)
        local normalizedValue = value / 100 -- Convert 0-100 to 0-1
        if normalizedValue == 0 then
            resetMapTransparency()
        else
            applyMapTransparency(normalizedValue)
        end
    end)

    -- Update canvas size dynamically
    local function updateCanvasSize()
        local contentHeight = toggleStartY + (isMobile and 360 or 330)
        mainPage.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
    end

    updateCanvasSize()
    
    -- Misc Tab
    -- Auto Sell Toggle
    createToggle(miscPage, "Auto Sell", 10, function(state)
        autoSellEnabled = state
        -- FIX: If Auto-Sell is turned ON mid-autoFarm, do initial seller visit AFTER current target.
        if state == true then
            if autoFarmEnabled and not hasSoldOnce then
                task.spawn(function()
                    -- Wait until current attack finishes
                    repeat task.wait() until currentTargetMob == nil
                    print("Auto-Sell enabled mid-run → Doing first seller visit.")
                    performInitialSellerVisit()
                    hasSoldOnce = true
                end)
            end
        else
            -- Reset if user disables Auto-Sell
            hasSoldOnce = false
        end
    end)

    -- Function to create ore selection UI
    local function createOresSection()
        -- Ores Section Label
        local oresHeaderLabel = Instance.new("TextLabel")
        oresHeaderLabel.Size = UDim2.new(1, -20, 0, 30)
        oresHeaderLabel.Position = UDim2.new(0, 10, 0, 60)
        oresHeaderLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
        oresHeaderLabel.BorderSizePixel = 0
        oresHeaderLabel.Text = "ORES"
        oresHeaderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        oresHeaderLabel.Font = Enum.Font.GothamBold
        oresHeaderLabel.TextSize = isMobile and 14 or 15
        oresHeaderLabel.TextXAlignment = Enum.TextXAlignment.Center
        oresHeaderLabel.Parent = miscPage
        
        local oresHeaderCorner = Instance.new("UICorner")
        oresHeaderCorner.CornerRadius = UDim.new(0, 6)
        oresHeaderCorner.Parent = oresHeaderLabel
        
        -- Ores ScrollingFrame
        local oresScrollFrame = Instance.new("ScrollingFrame")
        oresScrollFrame.Size = UDim2.new(1, -20, 0, isMobile and 200 or 180)
        oresScrollFrame.Position = UDim2.new(0, 10, 0, 100)
        oresScrollFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
        oresScrollFrame.BorderSizePixel = 0
        oresScrollFrame.ScrollBarThickness = isMobile and 8 or 6
        oresScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 160, 255)
        oresScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        oresScrollFrame.Parent = miscPage
        
        local oresScrollCorner = Instance.new("UICorner")
        oresScrollCorner.CornerRadius = UDim.new(0, 6)
        oresScrollCorner.Parent = oresScrollFrame
        
        local oresLayout = Instance.new("UIListLayout")
        oresLayout.Padding = UDim.new(0, 5)
        oresLayout.SortOrder = Enum.SortOrder.LayoutOrder
        oresLayout.Parent = oresScrollFrame
        
        -- Create ore checkboxes
        local oreItems = {"Copper", "Stone", "Sand Stone", "Iron", "Cardboardite", "Tin", "Silver", "Banananite", "Gold", "Mushroomite", "Platinum", "Aite", "Poopite", "Cobalt", "Titanium", "Lapis Lazuli", "Volcanic Rock", "Quartz", "Amethyst", "Topaz", "Diamond", "Sapphire", "Cuprite", "Obsidian", "Emerald", "Ruby", "Rivalite", "Uranium", "Mythril", "Eye Ore", "Fireite", "Magmaite", "Lightite", "Demonite", "Darkryte"}
        
        for _, itemName in ipairs(oreItems) do
            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, -10, 0, isMobile and 32 or 28)
            container.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
            container.BorderSizePixel = 0
            container.Parent = oresScrollFrame
            
            local containerCorner = Instance.new("UICorner")
            containerCorner.CornerRadius = UDim.new(0, 4)
            containerCorner.Parent = container
            
            local checkbox = Instance.new("Frame")
            checkbox.Size = UDim2.new(0, isMobile and 20 or 18, 0, isMobile and 20 or 18)
            checkbox.Position = UDim2.new(0, 8, 0.5, isMobile and -10 or -9)
            checkbox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
            checkbox.BorderSizePixel = 0
            checkbox.Parent = container
            
            local checkboxCorner = Instance.new("UICorner")
            checkboxCorner.CornerRadius = UDim.new(0, 4)
            checkboxCorner.Parent = checkbox
            
            local checkmark = Instance.new("TextLabel")
            checkmark.Size = UDim2.new(1, 0, 1, 0)
            checkmark.BackgroundTransparency = 1
            checkmark.Text = ""
            checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
            checkmark.Font = Enum.Font.GothamBold
            checkmark.TextSize = isMobile and 14 or 12
            checkmark.Parent = checkbox
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -40, 1, 0)
            label.Position = UDim2.new(0, 35, 0, 0)
            label.BackgroundTransparency = 1
            label.Text = itemName
            label.TextColor3 = Color3.fromRGB(200, 210, 220)
            label.Font = Enum.Font.Gotham
            label.TextSize = isMobile and 11 or 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = container
            
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 1, 0)
            button.BackgroundTransparency = 1
            button.Text = ""
            button.Parent = container
            
            button.MouseButton1Click:Connect(function()
                selectedSellOres[itemName] = not selectedSellOres[itemName]
                if selectedSellOres[itemName] then
                    checkbox.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
                    checkmark.Text = "✓"
                else
                    checkbox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
                    checkmark.Text = ""
                end
            end)
        end
        
        oresLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            oresScrollFrame.CanvasSize = UDim2.new(0, 0, 0, oresLayout.AbsoluteContentSize.Y + 10)
        end)
    end

    -- Function to create drops selection UI
    local function createDropsSection()
        -- Mobs & Drops Section Label
        local dropsHeaderLabel = Instance.new("TextLabel")
        dropsHeaderLabel.Size = UDim2.new(1, -20, 0, 30)
        dropsHeaderLabel.Position = UDim2.new(0, 10, 0, 290)
        dropsHeaderLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
        dropsHeaderLabel.BorderSizePixel = 0
        dropsHeaderLabel.Text = "MOBS & DROPS"
        dropsHeaderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        dropsHeaderLabel.Font = Enum.Font.GothamBold
        dropsHeaderLabel.TextSize = isMobile and 14 or 15
        dropsHeaderLabel.TextXAlignment = Enum.TextXAlignment.Center
        dropsHeaderLabel.Parent = miscPage
        
        local dropsHeaderCorner = Instance.new("UICorner")
        dropsHeaderCorner.CornerRadius = UDim.new(0, 6)
        dropsHeaderCorner.Parent = dropsHeaderLabel
        
        -- Drops ScrollingFrame
        local dropsScrollFrame = Instance.new("ScrollingFrame")
        dropsScrollFrame.Size = UDim2.new(1, -20, 0, isMobile and 250 or 220)
        dropsScrollFrame.Position = UDim2.new(0, 10, 0, 330)
        dropsScrollFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
        dropsScrollFrame.BorderSizePixel = 0
        dropsScrollFrame.ScrollBarThickness = isMobile and 8 or 6
        dropsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 160, 255)
        dropsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        dropsScrollFrame.Parent = miscPage
        
        local dropsScrollCorner = Instance.new("UICorner")
        dropsScrollCorner.CornerRadius = UDim.new(0, 6)
        dropsScrollCorner.Parent = dropsScrollFrame
        
        local dropsLayout = Instance.new("UIListLayout")
        dropsLayout.Padding = UDim.new(0, 5)
        dropsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        dropsLayout.Parent = dropsScrollFrame
        
        -- Create drop checkboxes
        local dropItems = {
            "Tiny Essence",
            "Small Essence",
            "Medium Essence",
            "Large Essence",
            "Greater Essence",
            "Epic Essence",
            "Superior Essence",
        }
        
        for _, itemName in ipairs(dropItems) do
            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, -10, 0, isMobile and 32 or 28)
            container.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
            container.BorderSizePixel = 0
            container.Parent = dropsScrollFrame
            
            local containerCorner = Instance.new("UICorner")
            containerCorner.CornerRadius = UDim.new(0, 4)
            containerCorner.Parent = container
            
            local checkbox = Instance.new("Frame")
            checkbox.Size = UDim2.new(0, isMobile and 20 or 18, 0, isMobile and 20 or 18)
            checkbox.Position = UDim2.new(0, 8, 0.5, isMobile and -10 or -9)
            checkbox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
            checkbox.BorderSizePixel = 0
            checkbox.Parent = container
            
            local checkboxCorner = Instance.new("UICorner")
            checkboxCorner.CornerRadius = UDim.new(0, 4)
            checkboxCorner.Parent = checkbox
            
            local checkmark = Instance.new("TextLabel")
            checkmark.Size = UDim2.new(1, 0, 1, 0)
            checkmark.BackgroundTransparency = 1
            checkmark.Text = ""
            checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
            checkmark.Font = Enum.Font.GothamBold
            checkmark.TextSize = isMobile and 14 or 12
            checkmark.Parent = checkbox
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -40, 1, 0)
            label.Position = UDim2.new(0, 35, 0, 0)
            label.BackgroundTransparency = 1
            label.Text = itemName
            label.TextColor3 = Color3.fromRGB(200, 210, 220)
            label.Font = Enum.Font.Gotham
            label.TextSize = isMobile and 11 or 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = container
            
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 1, 0)
            button.BackgroundTransparency = 1
            button.Text = ""
            button.Parent = container
            
            button.MouseButton1Click:Connect(function()
                selectedSellDrops[itemName] = not selectedSellDrops[itemName]
                if selectedSellDrops[itemName] then
                    checkbox.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
                    checkmark.Text = "✓"
                else
                    checkbox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
                    checkmark.Text = ""
                end
            end)
        end
        
        dropsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            dropsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, dropsLayout.AbsoluteContentSize.Y + 10)
        end)
    end

    -- Call the functions to create the sections
    createOresSection()
    createDropsSection()

    -- Performance Mode Button
    createButton(miscPage, "Performance Mode", isMobile and 600 or 570, function()
        performanceModeEnabled = not performanceModeEnabled
        if performanceModeEnabled then
            -- Lower graphics settings
            local Lighting = game:GetService("Lighting")
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
                Lighting.Brightness = 0
                for _, effect in pairs(Lighting:GetChildren()) do
                    if effect:IsA("PostEffect") then
                        effect.Enabled = false
                    end
                end
            end)
            for _, obj in pairs(workspace:GetDescendants()) do
                pcall(function()
                    if obj:IsA("BasePart") then
                        obj.Material = Enum.Material.SmoothPlastic
                        obj.Reflectance = 0
                        obj.CastShadow = false
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        obj.Transparency = 1
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                        obj.Enabled = false
                    elseif obj:IsA("MeshPart") then
                        obj.Material = Enum.Material.SmoothPlastic
                        obj.Reflectance = 0
                        obj.TextureID = ""
                        obj.CastShadow = false
                    elseif obj:IsA("SpecialMesh") then
                        obj.TextureId = ""
                    end
                end)
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            print("Performance Mode: ENABLED")
        else
            local Lighting = game:GetService("Lighting")
            pcall(function()
                Lighting.GlobalShadows = true
                Lighting.Brightness = 2
                for _, effect in pairs(Lighting:GetChildren()) do
                    if effect:IsA("PostEffect") then
                        effect.Enabled = true
                    end
                end
            end)
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            print("Performance Mode: DISABLED")
        end
    end)

    -- Update canvas size for misc page
    miscPage.CanvasSize = UDim2.new(0, 0, 0, isMobile and 700 or 650)

    -- SETTINGS TAB
    local currentKeybind = Enum.KeyCode.RightShift

    -- Function to create settings tab content
    local function createSettingsTab()
        if not isMobile then
            local keybindLabel = Instance.new("TextLabel")
            keybindLabel.Size = UDim2.new(1, -20, 0, 20)
            keybindLabel.Position = UDim2.new(0, 10, 0, 10)
            keybindLabel.BackgroundTransparency = 1
            keybindLabel.Text = "GUI Toggle Key: Right Shift"
            keybindLabel.TextColor3 = Color3.fromRGB(180, 190, 200)
            keybindLabel.Font = Enum.Font.Gotham
            keybindLabel.TextSize = 13
            keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
            keybindLabel.Parent = settingsPage
            
            createButton(settingsPage, "Change Keybind", 40, function()
                keybindLabel.Text = "Press any key..."
                local connection
                connection = UserInputService.InputBegan:Connect(function(input, gp)
                    if gp then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        currentKeybind = input.KeyCode
                        keybindLabel.Text = "GUI Toggle Key: " .. input.KeyCode.Name
                        connection:Disconnect()
                    end
                end)
            end)
        end
        
        -- Clipboard notification label
        local clipboardNotification = Instance.new("TextLabel")
        clipboardNotification.Size = UDim2.new(1, -20, 0, 20)
        clipboardNotification.Position = UDim2.new(0, 10, 0, isMobile and 100 or 170)
        clipboardNotification.BackgroundTransparency = 1
        clipboardNotification.Text = "Discord link copied to clipboard!"
        clipboardNotification.TextColor3 = Color3.fromRGB(80, 160, 255)
        clipboardNotification.Font = Enum.Font.GothamBold
        clipboardNotification.TextSize = 13
        clipboardNotification.TextXAlignment = Enum.TextXAlignment.Left
        clipboardNotification.Visible = false
        clipboardNotification.Parent = settingsPage
        
        -- Discord button
        createButton(settingsPage, "Join Discord", isMobile and 10 or 90, function()
            if setclipboard then
                setclipboard("https://discord.com/invite/xXethhWsze")
                clipboardNotification.Visible = true
                task.spawn(function()
                    task.wait(2)
                    clipboardNotification.Visible = false
                end)
            end
        end)
        
        -- Global Execution Counter
        local GlobalExecLabel = Instance.new("TextLabel")
        GlobalExecLabel.Size = UDim2.new(1, -20, 0, 20)
        GlobalExecLabel.Position = UDim2.new(0, 10, 0, isMobile and 50 or 130)
        GlobalExecLabel.BackgroundTransparency = 1
        GlobalExecLabel.Text = "GLOBAL EXECUTIONS: Loading..."
        GlobalExecLabel.TextColor3 = Color3.fromRGB(180, 190, 200)
        GlobalExecLabel.Font = Enum.Font.Gotham
        GlobalExecLabel.TextSize = 13
        GlobalExecLabel.TextXAlignment = Enum.TextXAlignment.Left
        GlobalExecLabel.Parent = settingsPage
        
        -- API info
        local URL_UP = "https://api.counterapi.dev/v2/nflars-team-1908/executecount/up"
        local API_KEY = "ut_LeC1jUUeElfaBuhBJgfM4TUPsfuAnTEzi6L9i31L"
        
        -- Executor HTTP detection
        local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request or (fluxus and fluxus.request) or (krnl and krnl.request)
        
        if httpRequest then
            task.spawn(function()
                local success, res = pcall(function()
                    return httpRequest({
                        Url = URL_UP,
                        Method = "GET",
                        Headers = {
                            ["Content-Type"] = "application/json",
                            ["Authorization"] = "Bearer " .. API_KEY
                        }
                    })
                end)
                
                if success and res and res.Body then
                    local ok, data = pcall(function()
                        return HttpService:JSONDecode(res.Body)
                    end)
                    
                    if ok and data and data.data and data.data.up_count then
                        GlobalExecLabel.Text = "GLOBAL EXECUTIONS: " .. tostring(data.data.up_count)
                        return
                    end
                end
                
                GlobalExecLabel.Text = "GLOBAL EXECUTIONS: Error"
            end)
        else
            GlobalExecLabel.Text = "GLOBAL EXECUTIONS: (no http)"
        end
    end

    -- Call the function to create settings tab
    createSettingsTab()

    -- Keybind toggle (keep this outside the function so it works globally)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == currentKeybind then
            mainWindow.Visible = not mainWindow.Visible
        end
    end)

    -- Mobile Toggle Button
    if isMobile then
        local mobileToggle = Instance.new("ImageButton")
        mobileToggle.Size = UDim2.new(0, 60, 0, 60)
        mobileToggle.Position = UDim2.new(1, -70, 0.5, -30)
        mobileToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
        mobileToggle.BackgroundTransparency = 0.5
        mobileToggle.BorderSizePixel = 0
        mobileToggle.Image = "rbxassetid://128171660606376"  -- FIXED
        mobileToggle.ImageColor3 = Color3.fromRGB(80, 160, 255)  -- FIXED
        mobileToggle.Active = true
        mobileToggle.Draggable = true
        mobileToggle.Parent = screenGui
        
        local mobileCorner = Instance.new("UICorner")
        mobileCorner.CornerRadius = UDim.new(1, 0)
        mobileCorner.Parent = mobileToggle
        
        mobileToggle.MouseButton1Click:Connect(function()
            mainWindow.Visible = not mainWindow.Visible
        end)
    end
