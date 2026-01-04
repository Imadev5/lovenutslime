local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Load Library
local library = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local window = library:CreateWindow({
    Title = "5M Hub",
    SubTitle = "Futbol",
    TabWidth = 140,
    Size = UDim2.fromOffset(700, 400),
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local Config = {
    reachOn = false,
    reachDist = 10,
    shieldBallOn = false,
    ballMagnetOn = false,
    autoGoalOn = false,
    targetNet = "Away",
    shotPower = 100,
    walkspeed = 16,
    speedBoostOn = false,
    speedMultiplier = 0.5,
    staminaOn = false,
}

local cachedBalls = {}
local lastUpdate = 0
local brokenBalls = {} -- List of balls we have already broken

-- // OPTIMIZATION & FINDER // --

local function updateBalls()
    if tick() - lastUpdate < 1 then return end
    lastUpdate = tick()
    cachedBalls = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Part") and (v.Name == "TP" or v:FindFirstChild("network") or brokenBalls[v]) then
            table.insert(cachedBalls, v)
        end
    end
end

local function getClosestBall()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    updateBalls()
    
    local closest, minDist = nil, math.huge
    for _, ball in ipairs(cachedBalls) do
        if ball and ball.Parent then
            local dist = (ball.Position - root.Position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = ball
            end
        end
    end
    return closest
end

-- // PHYSICS HELPERS // --

local function getGroundPosition(rootPos)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, cachedBalls}
    params.FilterType = Enum.RaycastFilterType.Exclude
    -- Shoot ray down to find floor
    local result = Workspace:Raycast(rootPos, Vector3.new(0, -10, 0), params)
    
    if result then
        return result.Position + Vector3.new(0, 0.85, 0) -- Perfect floor height
    else
        return rootPos - Vector3.new(0, 2.5, 0) -- Air fallback
    end
end

local function findNet(name)
    local pitch = Workspace:FindFirstChild("pitch")
    local nets = pitch and pitch:FindFirstChild("nets")
    local folder = nets and nets:FindFirstChild(name)
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if m:FindFirstChild("Net") then return m.Net end
        end
    end
    return nil
end

-- // MAIN LOOPS // --

-- 1. Shield Ball (NETWORK BREAK METHOD)
RunService.Stepped:Connect(function()
    if not Config.shieldBallOn then return end
    
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local ball = getClosestBall()
    
    -- Activation distance
    if ball and (ball.Position - root.Position).Magnitude < 25 then
        
        -- A. BREAK THE NETWORK (The logic you asked for)
        local network = ball:FindFirstChild("network")
        if network then
            -- 1. Force Ownership NOW
            if setsimulationradius then setsimulationradius(math.huge, math.huge) end
            pcall(function() network:SetNetworkOwner(LocalPlayer) end)
            
            -- 2. DELETE IT (This prevents others from stealing it back)
            -- We destroy the object that handles ball logic on our client
            network:Destroy()
            brokenBalls[ball] = true -- Remember this ball is ours now
        end

        -- B. FORCE PHYSICS (God Mode Dribble)
        -- Calculate position in front of player
        local frontPos = root.CFrame.Position + (root.CFrame.LookVector * 2.5)
        local groundPos = getGroundPosition(frontPos) -- Use Raycast to prevent under-map
        
        -- Lock Ball
        ball.CanCollide = false
        ball.CFrame = CFrame.new(groundPos, groundPos + root.CFrame.LookVector)
        ball.AssemblyLinearVelocity = root.AssemblyLinearVelocity
        ball.AssemblyAngularVelocity = Vector3.zero
    end
end)

-- 2. Reach
RunService.Heartbeat:Connect(function()
    if not Config.reachOn then return end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    -- Only reach if we aren't shielding (Shielding already owns the ball)
    if Config.shieldBallOn then return end

    local ball = getClosestBall()
    if ball and (ball.Position - root.Position).Magnitude < Config.reachDist then
        if firetouchinterest then
            for _, v in ipairs(LocalPlayer.Character:GetChildren()) do
                if v:IsA("BasePart") then
                    firetouchinterest(ball, v, 0)
                    firetouchinterest(ball, v, 1)
                end
            end
        end
    end
end)

-- 3. Magnet
RunService.Heartbeat:Connect(function()
    if not Config.ballMagnetOn then return end
    if Config.shieldBallOn then return end -- Don't fight with Shield

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local ball = getClosestBall()
    
    if root and ball and (ball.Position - root.Position).Magnitude < 25 then
        if setsimulationradius then setsimulationradius(math.huge) end
        local network = ball:FindFirstChild("network")
        if network then pcall(function() network:SetNetworkOwner(LocalPlayer) end) end
        
        ball.CFrame = root.CFrame * CFrame.new(0, -2, -2)
        ball.AssemblyLinearVelocity = Vector3.zero
    end
end)

-- 4. Auto Goal
UserInputService.InputEnded:Connect(function(input, gp)
    if gp or not Config.autoGoalOn then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool and tool.Name:lower():find("kick") then
            local ball = getClosestBall()
            local net = findNet(Config.targetNet)
            if ball and net then
                local dist = (ball.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if dist < 20 then
                    -- If network is broken, we still own physics, so we can just shoot
                    local dir = (net.Position - ball.Position).Unit
                    ball.AssemblyLinearVelocity = dir * Config.shotPower + Vector3.new(0, Config.shotPower/6, 0)
                end
            end
        end
    end
end)

-- 5. Misc (Speed/Stamina)
RunService.Heartbeat:Connect(function()
    if Config.staminaOn then
        pcall(function() LocalPlayer.PlayerScripts.controllers.movementController.stamina.Value = 100 end)
    end
    if Config.speedBoostOn then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            char:TranslateBy(hum.MoveDirection * Config.speedMultiplier)
        end
    end
end)

-- // UI SETUP // --

local tabs = {
    main = window:AddTab({ Title = "Main", Icon = "home" }),
    game = window:AddTab({ Title = "Game", Icon = "gamepad-2" }),
    misc = window:AddTab({ Title = "Misc", Icon = "settings" }),
}

tabs.game:AddToggle("shield", {Title = "Shield Ball (Network Break)", Description = "Deletes network logic so others can't steal.", Default = false, Callback = function(v) Config.shieldBallOn = v end})
tabs.game:AddToggle("reach", {Title = "Reach", Default = false, Callback = function(v) Config.reachOn = v end})
tabs.game:AddSlider("reachDist", {Title = "Reach Radius", Default = 10, Min = 1, Max = 50, Callback = function(v) Config.reachDist = v end})
tabs.game:AddToggle("mag", {Title = "Magnet", Default = false, Callback = function(v) Config.ballMagnetOn = v end})

tabs.game:AddToggle("goal", {Title = "Auto Goal (Click)", Default = false, Callback = function(v) Config.autoGoalOn = v end})
tabs.game:AddDropdown("net", {Title = "Goal Target", Values = {"Home","Away"}, Default = "Away", Callback = function(v) Config.targetNet = v end})
tabs.game:AddSlider("power", {Title = "Power", Default = 100, Min = 50, Max = 300, Callback = function(v) Config.shotPower = v end})

tabs.misc:AddToggle("stamina", {Title = "Inf Stamina", Default = false, Callback = function(v) Config.staminaOn = v end})
tabs.misc:AddToggle("speed", {Title = "Speed Boost", Default = false, Callback = function(v) Config.speedBoostOn = v end})
tabs.misc:AddSlider("boost", {Title = "Boost Power", Default = 5, Min = 1, Max = 10, Callback = function(v) Config.speedMultiplier = v/10 end})
tabs.misc:AddSlider("walk", {Title = "WalkSpeed", Default = 16, Min = 16, Max = 150, Callback = function(v)
    Config.walkspeed = v
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = v
    end
end})

LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    c:WaitForChild("Humanoid").WalkSpeed = Config.walkspeed
end)

library:SelectTab(1)
library:Notify({Title = "Network Break Loaded", Content = "Shield Ball now destroys network logic!", Duration = 5})
