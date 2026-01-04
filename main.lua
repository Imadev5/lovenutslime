local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local library = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local options = library.Options

local window = library:CreateWindow({
    Title = "5M Hub",
    SubTitle = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
    TabWidth = 140,
    Size = UDim2.fromOffset(700, 400),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.RightControl,
})

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
    predictionOn = false,
    predictionColor = Color3.fromRGB(100, 180, 255),
}

local Connections = {}

pcall(function()
    for _, v in ipairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "overlapCheck") and rawget(v, "gkCheck") then
            hookfunction(v.overlapCheck, function() return true end)
            hookfunction(v.gkCheck, function() return true end)
        end
    end
end)


local function findBalls()
    local balls = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Part") and obj:FindFirstChild("network") then
            table.insert(balls, obj)
        end
    end
    return balls
end

local function getClosestBall()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local closest, minDist = nil, math.huge
    for _, ball in ipairs(findBalls()) do
        local dist = (ball.Position - root.Position).Magnitude
        if dist < minDist then minDist = dist closest = ball end
    end
    return closest
end

local function forceNetworkOwnership(ball)
    local network = ball:FindFirstChild("network")
    if network then
        pcall(function() network:SetNetworkOwner(LocalPlayer) end)
    end
end

local function findNetPart(netType)
    local pitch = workspace:FindFirstChild("pitch")
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

local function isKickToolEquipped()
    local char = LocalPlayer.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    return tool and tool.Name:lower():find("kick")
end

local function checkrig()
    local char = LocalPlayer.Character
    if not char then return "R15" end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return "R15" end
    return hum.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"
end

local function customclipboard(text)
    local clipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
    if clipboard then clipboard(tostring(text)) end
end

-- Reach (optimized - every heartbeat, cached limbs, closest ball only)
local function fireTouch(ball, limb)
    if not firetouchinterest then return end
    firetouchinterest(ball, limb, 0)
    firetouchinterest(ball, limb, 1)
end

local cachedLimbs = {}
local lastLimbCache = 0

Connections.reach = RunService.Heartbeat:Connect(function()
    if not Config.reachOn then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local ball = getClosestBall()
    if not ball then return end
    if (ball.Position - root.Position).Magnitude > Config.reachDist then return end
    
    -- cache limbs every 1 sec
    local now = tick()
    if now - lastLimbCache > 1 then
        cachedLimbs = {}
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") then
                cachedLimbs[#cachedLimbs + 1] = p
            end
        end
        lastLimbCache = now
    end
    
    for i = 1, #cachedLimbs do
        fireTouch(ball, cachedLimbs[i])
    end
end)

-- Shield Ball (breaks network for other players)
Connections.shieldBall = RunService.Heartbeat:Connect(function()
    if not Config.shieldBallOn then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, ball in ipairs(findBalls()) do
        local network = ball:FindFirstChild("network")
        if network then
            pcall(function()
                network:SetNetworkOwner(LocalPlayer)
            end)
            -- constantly claim ownership so others cant touch
            ball.AssemblyLinearVelocity = ball.AssemblyLinearVelocity
        end
    end
end)


-- All connections from mobile
local kickToolEquipped = false
local lastGoalShot = {}

Connections.toolMonitor = RunService.Heartbeat:Connect(function()
    kickToolEquipped = isKickToolEquipped()
end)

-- Auto Goal (from mobile - event-based, not loop)
Connections.autoGoal = UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not Config.autoGoalOn then return end
    if not kickToolEquipped then return end
    local validInputs = {
        [Enum.UserInputType.MouseButton1] = true,
        [Enum.UserInputType.Touch] = true,
    }
    if not validInputs[input.UserInputType] then return end
    task.wait(0.3)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local netPart = findNetPart(Config.targetNet)
    if not netPart then return end
    for _, ball in ipairs(findBalls()) do
        local dist = (ball.Position - root.Position).Magnitude
        if dist <= Config.reachDist then
            local currentTime = tick()
            if not lastGoalShot[ball] or (currentTime - lastGoalShot[ball]) > 0.5 then
                forceNetworkOwnership(ball)
                local toNet = (netPart.Position - ball.Position)
                local horizontalDist = Vector3.new(toNet.X, 0, toNet.Z).Magnitude
                local direction = toNet.Unit
                local velocity = direction * Config.shotPower
                local arc = math.min(horizontalDist * 0.2 + (Config.shotPower * 0.05), 30)
                velocity = velocity + Vector3.new(0, arc, 0)
                ball.AssemblyLinearVelocity = velocity
                ball.AssemblyAngularVelocity = Vector3.zero
                lastGoalShot[ball] = currentTime
            end
        end
    end
end)

Connections.stamina = RunService.Heartbeat:Connect(function()
    if not Config.staminaOn then return end
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local c = ps and ps:FindFirstChild("controllers")
        local m = c and c:FindFirstChild("movementController")
        local s = m and m:FindFirstChild("stamina")
        if s then s.Value = 100 end
    end)
end)

Connections.noclip = RunService.Stepped:Connect(function()
    if not Config.noclipOn then return end
    local char = LocalPlayer.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

Connections.ballMagnet = RunService.Heartbeat:Connect(function()
    if not Config.ballMagnetOn then return end
    local ball = getClosestBall()
    if not ball then return end
    local char = LocalPlayer.Character
    local boot = char and (char:FindFirstChild("RightBoot") or char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg"))
    if not boot then return end
    forceNetworkOwnership(ball)
    ball.CFrame = CFrame.new(boot.Position + Vector3.new(0, 0.5, 0))
    ball.AssemblyLinearVelocity = Vector3.zero
end)

Connections.bringBall = RunService.Heartbeat:Connect(function()
    if not Config.bringBallOn then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local ball = getClosestBall()
    if ball then
        forceNetworkOwnership(ball)
        ball.CFrame = root.CFrame * CFrame.new(0, 0, -3)
        ball.AssemblyLinearVelocity = Vector3.zero
        ball.AssemblyAngularVelocity = Vector3.zero
    end
end)

Connections.telekinesis = RunService.Heartbeat:Connect(function()
    if not Config.telekinesisOn then return end
    local ball = getClosestBall()
    if not ball then return end
    local mouse = LocalPlayer:GetMouse()
    local target = mouse.Hit.Position
    local dir = (target - ball.Position)
    forceNetworkOwnership(ball)
    ball.AssemblyLinearVelocity = dir.Unit * math.clamp(dir.Magnitude * 2, 0, 150)
end)

Connections.autoScore = RunService.Heartbeat:Connect(function()
    if not Config.autoScoreOn then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local netPart = findNetPart(Config.targetNet)
    if not netPart then return end
    for _, ball in ipairs(findBalls()) do
        if (ball.Position - root.Position).Magnitude <= 50 then
            forceNetworkOwnership(ball)
            local toNet = (netPart.Position - ball.Position)
            ball.AssemblyLinearVelocity = toNet.Unit * Config.shotPower + Vector3.new(0, 15, 0)
            ball.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

Connections.freekick = RunService.RenderStepped:Connect(function()
    if not Config.freekickOn then return end
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, gui in pairs(pg:GetDescendants()) do
            if gui.Name == "Composure" and gui:IsA("Frame") then
                gui.Size = UDim2.new(gui.Size.X.Scale, gui.Size.X.Offset, 0.1, gui.Size.Y.Offset)
            end
        end
    end)
end)

Connections.penalty = RunService.RenderStepped:Connect(function()
    if not Config.penaltyOn then return end
    pcall(function()
        local g = workspace:FindFirstChild("game")
        local d = g and g:FindFirstChild("debug")
        local pm = d and d:FindFirstChild(LocalPlayer.Name)
        if pm then
            for _, child in pairs(pm:GetDescendants()) do
                if child.Name == "Composure" and child:IsA("Part") then
                    child.Size = Vector3.new(3, 5, 3)
                end
            end
        end
    end)
end)

Connections.speedBoost = RunService.Heartbeat:Connect(function()
    if not Config.speedBoostOn then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0 then
        char:TranslateBy(hum.MoveDirection * Config.speedMultiplier)
    end
end)

Connections.infJump = UserInputService.JumpRequest:Connect(function()
    if not Config.infJumpOn then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)


-- UI Tabs
local tabs = {
    main = window:AddTab({ Title = "Main", Icon = "layout-dashboard" }),
    game = window:AddTab({ Title = "Real Futbol", Icon = "gamepad-2" }),
    misc = window:AddTab({ Title = "Miscellaneous", Icon = "puzzle" }),
    scripts = window:AddTab({ Title = "Scripts", Icon = "scroll" }),
    settings = window:AddTab({ Title = "Settings", Icon = "settings-2" }),
}

-- MAIN TAB
tabs.main:AddParagraph({ Title = "Player", Content = "" })

tabs.main:AddInput("teleport_input", {
    Title = "Teleport to Player",
    Default = "",
    Placeholder = "Username",
    Finished = true,
    Callback = function(value)
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        value = string.lower(value)
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= LocalPlayer and (string.find(other.Name:lower(), value) or string.find(other.DisplayName:lower(), value)) then
                local otherroot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
                if otherroot then root.CFrame = otherroot.CFrame end
                return
            end
        end
    end,
})

tabs.main:AddSlider("walkspeed_slider", {
    Title = "Walk Speed",
    Default = 16,
    Min = 0,
    Max = 1000,
    Rounding = 0,
    Callback = function(value)
        Config.walkspeed = value
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = value end
    end
})

-- GAME TAB
tabs.game:AddParagraph({ Title = "Reach", Content = "" })

tabs.game:AddToggle("reach_toggle", {
    Title = "Ball Reach",
    Default = false,
    Callback = function(value) Config.reachOn = value end
})

tabs.game:AddSlider("reach_slider", {
    Title = "Reach Distance",
    Default = 10,
    Min = 1,
    Max = 40,
    Rounding = 0,
    Callback = function(value) Config.reachDist = value end
})

tabs.game:AddParagraph({ Title = "Player", Content = "" })

tabs.game:AddToggle("stamina_toggle", {
    Title = "Infinite Stamina",
    Default = false,
    Callback = function(value) Config.staminaOn = value end
})

tabs.game:AddToggle("speedboost_toggle", {
    Title = "Speed Boost",
    Default = false,
    Callback = function(value) Config.speedBoostOn = value end
})

tabs.game:AddSlider("speedboost_slider", {
    Title = "Speed Multiplier",
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(value) Config.speedMultiplier = value / 10 end
})

tabs.game:AddToggle("antiout_toggle", {
    Title = "Anti-Out",
    Default = false,
    Callback = function(value)
        Config.antiOutOn = value
        local g = workspace:FindFirstChild("game")
        local s = g and g:FindFirstChild("system")
        local o = s and s:FindFirstChild("out")
        if not o then return end
        if value then
            for _, p in ipairs(o:GetChildren()) do
                if table.find({"AwayLeft","AwayRight","HomeLeft","HomeRight","ThrowInFarSide","ThrowInTunnelSide"}, p.Name) then
                    Config.antiOutStored[p.Name] = p.Parent
                    p.Parent = nil
                end
            end
        else
            for n, par in pairs(Config.antiOutStored) do
                local p = o:FindFirstChild(n)
                if p then p.Parent = par end
            end
            Config.antiOutStored = {}
        end
    end
})

tabs.game:AddButton({
    Title = "Pitch Teleport",
    Callback = function()
        local net = ReplicatedStorage:FindFirstChild("network")
        local sh = net and net:FindFirstChild("Shared")
        if sh then
            for _, r in pairs(sh:GetChildren()) do
                if r:IsA("RemoteEvent") then r:FireServer(1000, "pitchTeleporter") end
            end
        end
    end
})


tabs.game:AddParagraph({ Title = "Auto Goal (Kick Tool)", Content = "" })

tabs.game:AddToggle("autogoal_toggle", {
    Title = "Auto Goal",
    Default = false,
    Callback = function(value) Config.autoGoalOn = value end
})

tabs.game:AddToggle("autoscore_toggle", {
    Title = "Auto Score",
    Default = false,
    Callback = function(value) Config.autoScoreOn = value end
})

tabs.game:AddDropdown("targetnet_dropdown", {
    Title = "Target Net",
    Values = {"Home", "Away"},
    Default = "Away",
    Callback = function(value) Config.targetNet = value end
})

tabs.game:AddSlider("shotpower_slider", {
    Title = "Shot Power",
    Default = 100,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(value) Config.shotPower = value end
})

tabs.game:AddParagraph({ Title = "Auto", Content = "" })

tabs.game:AddToggle("freekick_toggle", {
    Title = "Auto Freekick",
    Default = false,
    Callback = function(value) Config.freekickOn = value end
})

tabs.game:AddToggle("penalty_toggle", {
    Title = "Auto Penalty",
    Default = false,
    Callback = function(value) Config.penaltyOn = value end
})

tabs.game:AddParagraph({ Title = "Ball Features", Content = "" })

tabs.game:AddToggle("bringball_toggle", {
    Title = "Bring Ball",
    Default = false,
    Callback = function(value) Config.bringBallOn = value end
})

tabs.game:AddToggle("ballmag_toggle", {
    Title = "Ball Magnet",
    Default = false,
    Callback = function(value) Config.ballMagnetOn = value end
})

tabs.game:AddToggle("shieldball_toggle", {
    Title = "Shield Ball",
    Default = false,
    Callback = function(value) Config.shieldBallOn = value end
})

tabs.game:AddToggle("telekinesis_toggle", {
    Title = "Ball Telekinesis",
    Default = false,
    Callback = function(value) Config.telekinesisOn = value end
})

tabs.game:AddButton({
    Title = "Shoot to Goal",
    Callback = function()
        local ball = getClosestBall()
        if not ball then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local homeNet = findNetPart("Home")
        local awayNet = findNetPart("Away")
        local target = nil
        if homeNet and awayNet then
            local dh = (homeNet.Position - root.Position).Magnitude
            local da = (awayNet.Position - root.Position).Magnitude
            target = dh > da and homeNet or awayNet
        elseif homeNet then target = homeNet
        elseif awayNet then target = awayNet end
        if not target then return end
        forceNetworkOwnership(ball)
        local dir = (target.Position - ball.Position)
        ball.AssemblyLinearVelocity = dir.Unit * Config.shotPower + Vector3.new(0, 15, 0)
    end
})

tabs.game:AddButton({
    Title = "Match Settings",
    Callback = function()
        pcall(function()
            local ms = LocalPlayer.PlayerScripts.visuals.matchSettings
            ms:SetAttribute("toggle", true)
        end)
    end
})


-- MISC TAB
tabs.misc:AddParagraph({ Title = "Lighting", Content = "" })

local originalLighting = nil
tabs.misc:AddToggle("fullbright_toggle", {
    Title = "Fullbright",
    Default = false,
    Callback = function(value)
        Config.fullbrightOn = value
        local lighting = game:GetService("Lighting")
        if value then
            originalLighting = { Ambient = lighting.Ambient, OutdoorAmbient = lighting.OutdoorAmbient, Brightness = lighting.Brightness }
            lighting.Ambient = Color3.new(1,1,1)
            lighting.OutdoorAmbient = Color3.new(1,1,1)
            lighting.Brightness = 1.5
        elseif originalLighting then
            lighting.Ambient = originalLighting.Ambient
            lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
            lighting.Brightness = originalLighting.Brightness
        end
    end
})

tabs.misc:AddParagraph({ Title = "Movement", Content = "" })

tabs.misc:AddToggle("infjump_toggle", {
    Title = "Infinite Jump",
    Default = false,
    Callback = function(value) Config.infJumpOn = value end
})

tabs.misc:AddToggle("noclip_toggle", {
    Title = "Noclip",
    Default = false,
    Callback = function(value) Config.noclipOn = value end
})

tabs.misc:AddToggle("fly_toggle", {
    Title = "Fly",
    Default = false,
    Callback = function(value)
        Config.flyOn = value
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if value then
            local bg = Instance.new("BodyGyro", root)
            bg.Name = "FlyGyro"
            bg.MaxTorque = Vector3.new(1e9,1e9,1e9)
            bg.P = 9e4
            local bv = Instance.new("BodyVelocity", root)
            bv.Name = "FlyVel"
            bv.MaxForce = Vector3.new(1e9,1e9,1e9)
            Connections.fly = RunService.Heartbeat:Connect(function()
                if not Config.flyOn then return end
                local cam = workspace.CurrentCamera
                bg.CFrame = cam.CFrame
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
                bv.Velocity = dir.Magnitude > 0 and dir.Unit * 50 or Vector3.zero
            end)
        else
            if Connections.fly then Connections.fly:Disconnect() end
            local bg = root:FindFirstChild("FlyGyro")
            local bv = root:FindFirstChild("FlyVel")
            if bg then bg:Destroy() end
            if bv then bv:Destroy() end
        end
    end
})

tabs.misc:AddToggle("spin_toggle", {
    Title = "Spin",
    Default = false,
    Callback = function(value)
        Config.spinOn = value
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if value then
            local bav = Instance.new("BodyAngularVelocity", root)
            bav.Name = "Spin"
            bav.MaxTorque = Vector3.new(0,1e9,0)
            bav.AngularVelocity = Vector3.new(0, Config.spinspeed, 0)
        else
            local s = root:FindFirstChild("Spin")
            if s then s:Destroy() end
        end
    end
})

tabs.misc:AddSlider("spin_slider", {
    Title = "Spin Speed",
    Default = 20,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(value)
        Config.spinspeed = value
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local s = root and root:FindFirstChild("Spin")
        if s then s.AngularVelocity = Vector3.new(0, value, 0) end
    end
})

tabs.misc:AddParagraph({ Title = "Animations", Content = "" })

tabs.misc:AddInput("bang_input", {
    Title = "Bang Player",
    Default = "",
    Finished = true,
    Placeholder = "username or stop",
    Callback = function(value)
        value = string.lower(value)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if value == "" or value == "stop" then
            if hum then for _, t in ipairs(hum:GetPlayingAnimationTracks()) do if t.Name == "bang" then t:Stop() end end end
            if Connections.bang then Connections.bang:Disconnect() end
            return
        end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and (string.find(p.Name:lower(), value) or string.find(p.DisplayName:lower(), value)) then
                local char = LocalPlayer.Character
                if not char or not hum then return end
                local anim = Instance.new("Animation")
                anim.AnimationId = checkrig() == "R6" and "rbxassetid://148840371" or "rbxassetid://5918726674"
                anim.Name = "bang"
                local track = hum:LoadAnimation(anim)
                track:Play()
                track:AdjustSpeed(3)
                Connections.bang = RunService.Stepped:Connect(function()
                    local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    local mr = char:FindFirstChild("HumanoidRootPart")
                    if pr and mr then mr.CFrame = pr.CFrame * CFrame.new(0,0,1.1) end
                end)
                return
            end
        end
        library:Notify({ Title = "Error", Content = "Player not found", Duration = 2 })
    end
})


-- SCRIPTS TAB
tabs.scripts:AddButton({ Title = "Infinite Yield", Callback = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end })
tabs.scripts:AddButton({ Title = "Dex Explorer", Callback = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))() end })
tabs.scripts:AddButton({ Title = "Remote Spy", Callback = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/SimpleSpyV3/main.lua"))() end })

-- SETTINGS TAB
tabs.settings:AddParagraph({ Title = "Keybinds", Content = "" })

tabs.settings:AddKeybind("toggle_keybind", {
    Title = "UI Toggle Key",
    Mode = "Toggle",
    Default = Enum.KeyCode.RightControl,
    ChangedCallback = function(key)
        window.MinimizeKey = key
        library:Notify({ Title = "Keybind", Content = "Set to " .. tostring(key), Duration = 2 })
    end
})

tabs.settings:AddParagraph({ Title = "Server", Content = "" })

tabs.settings:AddButton({ Title = "PlaceId: " .. game.PlaceId, Callback = function() customclipboard(game.PlaceId) end })
tabs.settings:AddButton({ Title = "GameId: " .. game.GameId, Callback = function() customclipboard(game.GameId) end })
tabs.settings:AddButton({ Title = "Rejoin", Callback = function()
    if #Players:GetPlayers() <= 1 then LocalPlayer:Kick("Rejoining") TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
end })
tabs.settings:AddButton({ Title = "Server Hop", Callback = function()
    if not httprequest then library:Notify({ Title = "Error", Content = "Not supported", Duration = 2 }) return end
    local req = httprequest({ Url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true" })
    local data = HttpService:JSONDecode(req.Body)
    local servers = {}
    if data and data.data then
        for _, s in pairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s.id) end
        end
    end
    if #servers > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(#servers)], LocalPlayer)
    else library:Notify({ Title = "Error", Content = "No servers", Duration = 2 }) end
end })

tabs.settings:AddParagraph({ Title = "Theme", Content = "" })

tabs.settings:AddDropdown("theme", { Title = "Theme", Values = {"Dark","Darker","Light","Aqua","Amethyst","Rose"}, Default = "Darker", Callback = function(v) library:SetTheme(v) end })
tabs.settings:AddToggle("transparency", { Title = "Transparency", Default = false, Callback = function(v) library:ToggleTransparency(v) end })
tabs.settings:AddToggle("acrylic", { Title = "Acrylic", Default = false, Callback = function(v) library:ToggleAcrylic(v) if v then options.transparency:SetValue(true) end end })

-- Character respawn handler
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = Config.walkspeed end
end)

-- Initialize
window:SelectTab(1)
library:ToggleTransparency(false)

library:Notify({ Title = "5M Hub", Content = "Loaded! Press RightControl to toggle", Duration = 5 })
print("[5M Hub] Loaded")
