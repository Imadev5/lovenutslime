local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- Load Fluent Library
local library = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local options = library.Options

local window = library:CreateWindow({
    Title = "5M Hub | Optimized",
    SubTitle = "Futbol",
    TabWidth = 140,
    Size = UDim2.fromOffset(700, 400),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.RightControl,
})

-- Configuration
local Config = {
    reachOn = false,
    reachDist = 10,
    staminaOn = false,
    noclipOn = false,
    ballMagnetOn = false,
    bringBallOn = false,
    telekinesisOn = false,
    autoGoalOn = false,
    autoScoreOn = false,
    targetNet = "Away",
    shotPower = 100,
    walkspeed = 16,
    spinspeed = 20,
    fullbrightOn = false,
    infJumpOn = false,
    flyOn = false,
    spinOn = false,
    speedBoostOn = false,
    speedMultiplier = 0.5,
    antiOutOn = false,
    antiOutStored = {},
    shieldBallOn = false,
    freekickOn = false,
    penaltyOn = false,
}

local Connections = {}
local cachedBalls = {} -- Stores balls so we don't search workspace constantly
local lastBallUpdate = 0

-- // OPTIMIZATION FUNCTIONS // --

-- Updates the list of balls every 1 second (Prevents Lag)
local function updateBallCache()
    if tick() - lastBallUpdate < 1 then return end
    lastBallUpdate = tick()
    
    cachedBalls = {}
    -- Optimization: Most games put balls in Workspace or specific folders. 
    -- Searching GetDescendants is slow, but we limit how often we do it.
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Part") and obj.Name == "TP" or obj:FindFirstChild("network") then
            table.insert(cachedBalls, obj)
        end
    end
end

local function getClosestBall()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    updateBallCache() -- Refresh list if needed
    
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

-- Force Ownership (The Fix for Shield Ball)
local function claimBall(ball)
    if not ball then return end
    
    -- 1. Exploit Magic: Expand simulation radius to dominate physics
    if setsimulationradius then 
        setsimulationradius(math.huge, math.huge) 
    end
    
    -- 2. Network Ownership
    local network = ball:FindFirstChild("network")
    if network then
        pcall(function()
            network:SetNetworkOwner(LocalPlayer)
        end)
    end
    
    -- 3. Prevent others from interacting (Client Side Prediction)
    ball.AssemblyLinearVelocity = LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity
end

local function findNetPart(netType)
    local pitch = Workspace:FindFirstChild("pitch")
    if not pitch then return nil end
    local nets = pitch:FindFirstChild("nets")
    if not nets then return nil end
    local folder = nets:FindFirstChild(netType)
    if not folder then return nil end
    
    for _, netModel in ipairs(folder:GetChildren()) do
        if netModel:IsA("Model") then
            local netPart = netModel:FindFirstChild("Net")
            if netPart then return netPart end
        end
    end
    return nil
end

-- // MAIN FEATURES // --

-- Reach (Optimized)
Connections.reach = RunService.Heartbeat:Connect(function()
    if not Config.reachOn then return end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not root then return end
    
    local ball = getClosestBall()
    if not ball then return end
    
    if (ball.Position - root.Position).Magnitude <= Config.reachDist then
        if firetouchinterest then
            for _, limb in ipairs(char:GetChildren()) do
                if limb:IsA("BasePart") then
                    firetouchinterest(ball, limb, 0)
                    firetouchinterest(ball, limb, 1)
                end
            end
        end
    end
end)

-- Shield Ball (Fixed: Exclusive Control)
Connections.shieldBall = RunService.Heartbeat:Connect(function()
    if not Config.shieldBallOn then return end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local ball = getClosestBall()
    if ball and (ball.Position - root.Position).Magnitude < 20 then
        -- Force ownership massively
        claimBall(ball)
        
        -- Lock position to player (Others cannot touch what moves instantly with you)
        ball.CanCollide = false
        -- Position slightly in front of feet
        local dribblePos = root.CFrame * CFrame.new(0, -1.5, -1.5) 
        
        ball.AssemblyLinearVelocity = root.AssemblyLinearVelocity
        ball.AssemblyAngularVelocity = Vector3.new(0,0,0)
        ball.CFrame = dribblePos
    end
end)

-- Auto Goal
Connections.autoGoal = UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not Config.autoGoalOn then return end
    
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    -- Check if clicking or tapping screen
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if tool and string.find(tool.Name:lower(), "kick") then
            local ball = getClosestBall()
            local root = char.HumanoidRootPart
            
            if ball and (ball.Position - root.Position).Magnitude <= Config.reachDist then
                local net = findNetPart(Config.targetNet)
                if net then
                    claimBall(ball)
                    local dir = (net.Position - ball.Position).Unit
                    
                    -- Physics calculation for perfect curve
                    local velocity = dir * Config.shotPower
                    velocity = velocity + Vector3.new(0, Config.shotPower * 0.15, 0) -- Add arc
                    
                    ball.AssemblyLinearVelocity = velocity
                end
            end
        end
    end
end)

-- Stamina
Connections.stamina = RunService.Heartbeat:Connect(function()
    if not Config.staminaOn then return end
    pcall(function()
        local ps = LocalPlayer.PlayerScripts
        if ps.controllers.movementController.stamina then
            ps.controllers.movementController.stamina.Value = 100
        end
    end)
end)

-- Magnet
Connections.ballMagnet = RunService.Heartbeat:Connect(function()
    if not Config.ballMagnetOn then return end
    
    local ball = getClosestBall()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if ball and root and (ball.Position - root.Position).Magnitude < 30 then
        claimBall(ball)
        ball.CFrame = root.CFrame * CFrame.new(0, -1.5, -2)
        ball.AssemblyLinearVelocity = Vector3.zero
    end
end)

-- Speed Boost
Connections.speedBoost = RunService.Heartbeat:Connect(function()
    if not Config.speedBoostOn then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0 then
        char:TranslateBy(hum.MoveDirection * Config.speedMultiplier)
    end
end)

-- // UI SETUP // --

local tabs = {
    main = window:AddTab({ Title = "Main", Icon = "home" }),
    game = window:AddTab({ Title = "Game Mechanics", Icon = "gamepad-2" }),
    misc = window:AddTab({ Title = "Misc", Icon = "settings" }),
}

-- Game Tab
tabs.game:AddToggle("reach_t", {Title = "Ball Reach", Default = false, Callback = function(v) Config.reachOn = v end})
tabs.game:AddSlider("reach_s", {Title = "Reach Distance", Default = 10, Min = 1, Max = 50, Rounding = 0, Callback = function(v) Config.reachDist = v end})
tabs.game:AddToggle("shield_t", {Title = "Shield Ball (God Mode)", Description = "Nobody else can touch the ball.", Default = false, Callback = function(v) Config.shieldBallOn = v end})
tabs.game:AddToggle("mag_t", {Title = "Ball Magnet", Default = false, Callback = function(v) Config.ballMagnetOn = v end})
tabs.game:AddToggle("autogoal_t", {Title = "Auto Goal (On Click)", Default = false, Callback = function(v) Config.autoGoalOn = v end})
tabs.game:AddDropdown("net_d", {Title = "Target Net", Values = {"Home", "Away"}, Default = "Away", Callback = function(v) Config.targetNet = v end})
tabs.game:AddSlider("pow_s", {Title = "Shot Power", Default = 100, Min = 50, Max = 300, Rounding = 0, Callback = function(v) Config.shotPower = v end})

-- Misc Tab
tabs.misc:AddToggle("stamina_t", {Title = "Infinite Stamina", Default = false, Callback = function(v) Config.staminaOn = v end})
tabs.misc:AddToggle("speed_t", {Title = "Speed Boost", Default = false, Callback = function(v) Config.speedBoostOn = v end})
tabs.misc:AddSlider("speed_m", {Title = "Boost Amount", Default = 5, Min = 1, Max = 10, Callback = function(v) Config.speedMultiplier = v/10 end})
tabs.misc:AddSlider("walk_s", {Title = "WalkSpeed", Default = 16, Min = 16, Max = 200, Callback = function(v) 
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = v
    end
    Config.walkspeed = v 
end})

-- Initialize
library:SelectTab(1)
library:Notify({ Title = "5M Hub", Content = "Optimized & Shield Fixed!", Duration = 5 })

-- Ensure walkspeed persists on respawn
LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    local h = c:WaitForChild("Humanoid")
    h.WalkSpeed = Config.walkspeed
end)
