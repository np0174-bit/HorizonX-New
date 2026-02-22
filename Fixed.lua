--[[
    HorizonX Basketball v2.4
    Delta Android - OrionLib UI
]]

-- =====================
-- SERVICES
-- =====================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM               = game:GetService("VirtualInputManager")

-- =====================
-- CORE
-- =====================
local player = Players.LocalPlayer

local function getChar() return player.Character end
local function getHrp()  local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()  local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end

-- =====================
-- ORIONLIB LOAD (lightweight, works on Delta Android)
-- =====================
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()

-- =====================
-- GAME DETECTION
-- =====================
local isPark = false
pcall(function()
    local g = workspace:FindFirstChild("Game")
    isPark = g and g:FindFirstChild("Courts") ~= nil
end)

-- =====================
-- REMOTE / GUI REFS
-- =====================
local shootingElement = nil
local Shoot = nil

local function loadRefs()
    pcall(function()
        local vGui = player.PlayerGui:FindFirstChild("Visual")
        if vGui then
            shootingElement = vGui:FindFirstChild("Shooting")
        end
    end)
    pcall(function()
        Shoot = ReplicatedStorage.Packages.Knit.Services.ControlService.RE.Shoot
    end)
end

task.delay(3, loadRefs)

-- =====================
-- STATE
-- =====================
local State = {
    autoShoot      = false,
    autoGuard      = false,
    rebound        = false,
    follow         = false,
    magnet         = false,
    stealReach     = false,
    speedBoost     = false,
    jumpBoost      = false,
    postAimbot     = false,
    postHoldActive = false,
    espPlayers     = false,
    espBall        = false,
    noClip         = false,
    antiAFK        = false,
}

local Settings = {
    shootPower      = 0.80,
    guardDistance   = 10,
    predictionTime  = 0.3,
    offsetDistance  = 3,
    followOffset    = -10,
    magnetDistance  = 30,
    stealMultiplier = 1.5,
    walkSpeed       = 30,
    jumpPower       = 50,
    postDistance    = 10,
    espFillTrans    = 0.5,
}

-- =====================
-- CONNECTION POOL
-- =====================
local Connections = {}
local function addConn(key, conn)
    if Connections[key] then
        pcall(function() Connections[key]:Disconnect() end)
    end
    Connections[key] = conn
end
local function removeConn(key)
    if Connections[key] then
        pcall(function() Connections[key]:Disconnect() end)
        Connections[key] = nil
    end
end

local OriginalSizes = {}

-- =====================
-- HELPERS
-- =====================
local function getPlayerFromModel(model)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character == model then return plr end
    end
    return nil
end

local function isEnemy(model)
    local other = getPlayerFromModel(model)
    if not other or other == player then return false end
    if not player.Team or not other.Team then return other ~= player end
    return player.Team ~= other.Team
end

local function findBallCarrier()
    local myHrp = getHrp()
    if not myHrp then return nil, nil end

    if isPark then
        local best, bestDist = nil, math.huge
        for _, model in ipairs(workspace:GetChildren()) do
            if model:IsA("Model") and model ~= getChar() and model:FindFirstChild("HumanoidRootPart") then
                local tool = model:FindFirstChild("Basketball")
                if tool and tool:IsA("Tool") then
                    local d = (model.HumanoidRootPart.Position - myHrp.Position).Magnitude
                    if d < bestDist then bestDist = d; best = model end
                end
            end
        end
        return best, best and best.HumanoidRootPart
    end

    local looseBall = workspace:FindFirstChild("Basketball")
    if looseBall and looseBall:IsA("BasePart") then
        local best, bestDist = nil, math.huge
        for _, model in ipairs(workspace:GetChildren()) do
            if model:IsA("Model") and model ~= getChar() and model:FindFirstChild("HumanoidRootPart") and isEnemy(model) then
                local d = (looseBall.Position - model.HumanoidRootPart.Position).Magnitude
                if d < bestDist and d < 15 then bestDist = d; best = model end
            end
        end
        if best then return best, best.HumanoidRootPart end
    end

    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model ~= getChar() and model:FindFirstChild("HumanoidRootPart") and isEnemy(model) then
            local ball = model:FindFirstChild("Basketball")
            if ball and ball:IsA("Tool") then return model, model.HumanoidRootPart end
        end
    end
    return nil, nil
end

local function playerHasBall()
    local c = getChar()
    if not c then return false end
    local t = c:FindFirstChild("Basketball")
    return t and t:IsA("Tool")
end

local function detectBallHand()
    local c = getChar()
    if not c then return "right" end
    local tool = c:FindFirstChild("Basketball")
    if tool then
        local handle = tool:FindFirstChild("Handle")
        local hrp = getHrp()
        if handle and hrp then
            return hrp.CFrame:ToObjectSpace(handle.CFrame).X > 0 and "right" or "left"
        end
    end
    return "right"
end

local function getClosestEnemy(maxDist)
    local hrp = getHrp()
    if not hrp then return nil end
    local best, bestDist = nil, maxDist or math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and isEnemy(plr.Character) then
            local eHrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if eHrp then
                local d = (eHrp.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = eHrp end
            end
        end
    end
    return best
end

-- =====================
-- FEATURES
-- =====================

local function startAutoShoot()
    if not shootingElement then loadRefs() end
    if not shootingElement then return end
    if Connections.autoShoot then return end
    addConn("autoShoot", shootingElement:GetPropertyChangedSignal("Visible"):Connect(function()
        if State.autoShoot and shootingElement.Visible then
            task.wait(0.25)
            if Shoot then pcall(function() Shoot:FireServer(Settings.shootPower) end) end
        end
    end))
end

local function stopAutoShoot() removeConn("autoShoot") end

local lastPositions = {}
local function autoGuardTick()
    if not State.autoGuard or playerHasBall() then return end
    local hrp = getHrp()
    local hum = getHum()
    if not hrp or not hum then return end
    local carrier, carrierRoot = findBallCarrier()
    if not carrier or not carrierRoot then
        pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game) end)
        return
    end
    local dist = (hrp.Position - carrierRoot.Position).Magnitude
    local curPos = carrierRoot.Position
    local vel = Vector3.zero
    if lastPositions[carrier] then
        vel = (curPos - lastPositions[carrier]) / 0.033
    end
    lastPositions[carrier] = curPos
    local predicted = curPos + vel * Settings.predictionTime
    local dir = (predicted - hrp.Position).Unit
    local defPos = Vector3.new(
        (predicted - dir * 5).X,
        hrp.Position.Y,
        (predicted - dir * 5).Z
    )
    if dist <= Settings.guardDistance then
        hum:MoveTo(defPos)
        pcall(function() VIM:SendKeyEvent(dist <= 10, Enum.KeyCode.F, false, game) end)
    else
        pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game) end)
    end
end

local lastPostUpdate = 0
local function postAimbotTick()
    if not State.postHoldActive then return end
    local now = tick()
    if now - lastPostUpdate < 0.033 then return end
    lastPostUpdate = now
    local hrp = getHrp()
    if not hrp then return end
    local target = getClosestEnemy(Settings.postDistance)
    if not target then return end
    local dir = (target.Position - hrp.Position).Unit
    local face = CFrame.new(hrp.Position, hrp.Position + dir)
    if playerHasBall() then
        local hand = detectBallHand()
        hrp.CFrame = face * CFrame.Angles(0, math.rad(hand == "left" and 90 or -90), 0)
    else
        hrp.CFrame = face
    end
end

local function reboundTick()
    if not State.rebound then return end
    local hrp = getHrp()
    if not hrp then return end
    local best, bestDist = nil, isPark and 100 or math.huge
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Basketball" then
            local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (part.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = part end
            end
        end
    end
    if best then
        hrp.CFrame = CFrame.new(best.Position + best.CFrame.LookVector * Settings.offsetDistance)
    end
end

local function followTick()
    if not State.follow then return end
    local hrp = getHrp()
    if not hrp then return end
    local _, carrierRoot = findBallCarrier()
    if not carrierRoot then return end
    local maxD = isPark and 100 or math.huge
    if (hrp.Position - carrierRoot.Position).Magnitude <= maxD then
        hrp.CFrame = carrierRoot.CFrame * CFrame.new(0, 0, Settings.followOffset)
    end
end

local function magnetTick()
    if not State.magnet then return end
    local hrp = getHrp()
    if not hrp then return end
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Basketball" then
            local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
            if part and (part.Position - hrp.Position).Magnitude <= Settings.magnetDistance then
                part.CFrame = CFrame.new(hrp.Position + hrp.CFrame.LookVector * 2 + Vector3.new(0, 1, 0))
            end
        end
    end
end

local REACH_LIMBS = {
    "Right Arm", "RightHand", "RightLowerArm",
    "Left Arm", "LeftHand", "LeftLowerArm",
}
local function applyReach()
    local c = getChar()
    if not c then return end
    for _, name in ipairs(REACH_LIMBS) do
        local part = c:FindFirstChild(name)
        if part then
            if State.stealReach then
                if not OriginalSizes[name] then OriginalSizes[name] = part.Size end
                part.Size = OriginalSizes[name] * Settings.stealMultiplier
                part.Transparency = 1
                part.CanCollide = false
                part.Massless = true
            else
                if OriginalSizes[name] then
                    part.Size = OriginalSizes[name]
                    part.Transparency = 0
                    part.CanCollide = true
                    part.Massless = false
                end
            end
        end
    end
end

local function applyStats()
    local hum = getHum()
    if not hum then return end
    hum.WalkSpeed = State.speedBoost and Settings.walkSpeed or 16
    hum.JumpPower = State.jumpBoost and Settings.jumpPower or 50
end

local function refreshESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local existing = plr.Character:FindFirstChild("HX_ESP")
            if State.espPlayers then
                if not existing then
                    local h = Instance.new("Highlight")
                    h.Name = "HX_ESP"
                    h.FillColor = isEnemy(plr.Character) and Color3.fromRGB(220, 50, 50) or Color3.fromRGB(50, 200, 100)
                    h.OutlineColor = Color3.fromRGB(255, 255, 255)
                    h.FillTransparency = Settings.espFillTrans
                    h.Adornee = plr.Character
                    h.Parent = plr.Character
                end
            else
                if existing then existing:Destroy() end
            end
        end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Basketball" then
            local existing = child:FindFirstChild("HX_BallESP")
            if State.espBall then
                if not existing then
                    local h = Instance.new("Highlight")
                    h.Name = "HX_BallESP"
                    h.FillColor = Color3.fromRGB(255, 165, 0)
                    h.OutlineColor = Color3.fromRGB(255, 220, 0)
                    h.FillTransparency = 0.2
                    h.Adornee = child
                    h.Parent = child
                end
            else
                if existing then existing:Destroy() end
            end
        end
    end
end

local function noClipTick()
    if not State.noClip then return end
    local c = getChar()
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

local function startAntiAFK()
    addConn("antiAFK", RunService.Heartbeat:Connect(function()
        if not State.antiAFK then return end
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        end)
    end))
end

-- =====================
-- MASTER HEARTBEAT
-- =====================
addConn("master", RunService.Heartbeat:Connect(function()
    pcall(autoGuardTick)
    pcall(postAimbotTick)
    pcall(reboundTick)
    pcall(followTick)
    pcall(magnetTick)
    pcall(noClipTick)
    pcall(applyStats)
end))

addConn("espRefresh", RunService.Stepped:Connect(function()
    pcall(refreshESP)
end))

player.CharacterAdded:Connect(function(c)
    OriginalSizes = {}
    lastPositions = {}
    c:WaitForChild("HumanoidRootPart")
    c:WaitForChild("Humanoid")
    task.wait(1)
    pcall(loadRefs)
    pcall(applyReach)
    pcall(applyStats)
end)

local function unloadAll()
    for k, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
        Connections[k] = nil
    end
    State.stealReach = false; pcall(applyReach)
    State.speedBoost = false
    State.jumpBoost = false
    pcall(applyStats)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local e = plr.Character:FindFirstChild("HX_ESP")
            if e then e:Destroy() end
        end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        local e = child:FindFirstChild("HX_BallESP")
        if e then e:Destroy() end
    end
    pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game) end)
end

-- =====================
-- ORION WINDOW
-- =====================
local Window = OrionLib:MakeWindow({
    Name            = "HorizonX Basketball",
    HidePremium     = false,
    SaveConfig      = true,
    ConfigFolder    = "HorizonX",
    IntroEnabled    = true,
    IntroText       = "HorizonX Basketball",
})

-- =====================
-- TABS
-- =====================
local MainTab    = Window:MakeTab({ Name = "Main",    Icon = "rbxassetid://4483345998", PremiumOnly = false })
local DefenseTab = Window:MakeTab({ Name = "Defense", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local OffenseTab = Window:MakeTab({ Name = "Offense", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local PlayerTab  = Window:MakeTab({ Name = "Player",  Icon = "rbxassetid://4483345998", PremiumOnly = false })
local VisualsTab = Window:MakeTab({ Name = "Visuals", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local MiscTab    = Window:MakeTab({ Name = "Misc",    Icon = "rbxassetid://4483345998", PremiumOnly = false })

-- =====================
-- MAIN TAB
-- =====================
MainTab:AddSection({ Name = "Auto Shooting" })

MainTab:AddToggle({
    Name    = "Auto Time Shot",
    Default = false,
    Save    = true,
    Flag    = "AutoShoot",
    Callback = function(v)
        State.autoShoot = v
        if v then startAutoShoot() else stopAutoShoot() end
    end,
})

MainTab:AddSlider({
    Name    = "Shot Timing",
    Min     = 50,
    Max     = 100,
    Default = 80,
    Color   = Color3.fromRGB(255, 165, 0),
    Increment = 1,
    ValueName = "%",
    Callback = function(v) Settings.shootPower = v / 100 end,
})

MainTab:AddLabel("50-79 = Early/Late | 80 = OK | 90 = Good | 95 = Great | 100 = Perfect")

MainTab:AddSection({ Name = "Auto Rebound and Steal" })

MainTab:AddToggle({
    Name    = "Auto Rebound and Steal",
    Default = false,
    Save    = true,
    Flag    = "Rebound",
    Callback = function(v) State.rebound = v end,
})

MainTab:AddSlider({
    Name      = "Teleport Offset",
    Min       = 0,
    Max       = 6,
    Default   = 0,
    Color     = Color3.fromRGB(255, 165, 0),
    Increment = 1,
    ValueName = " studs",
    Callback  = function(v) Settings.offsetDistance = v end,
})

MainTab:AddSection({ Name = "Steal Reach" })

MainTab:AddToggle({
    Name    = "Expanded Steal Hitbox",
    Default = false,
    Save    = true,
    Flag    = "StealReach",
    Callback = function(v)
        State.stealReach = v
        pcall(applyReach)
    end,
})

MainTab:AddSlider({
    Name      = "Reach Multiplier",
    Min       = 100,
    Max       = 400,
    Default   = 150,
    Color     = Color3.fromRGB(255, 165, 0),
    Increment = 10,
    ValueName = "%",
    Callback  = function(v)
        Settings.stealMultiplier = v / 100
        if State.stealReach then pcall(applyReach) end
    end,
})

MainTab:AddSection({ Name = "Ball Magnet" })

MainTab:AddToggle({
    Name    = "Ball Magnet",
    Default = false,
    Save    = true,
    Flag    = "Magnet",
    Callback = function(v) State.magnet = v end,
})

MainTab:AddSlider({
    Name      = "Magnet Radius",
    Min       = 5,
    Max       = 150,
    Default   = 30,
    Color     = Color3.fromRGB(255, 165, 0),
    Increment = 5,
    ValueName = " studs",
    Callback  = function(v) Settings.magnetDistance = v end,
})

-- =====================
-- DEFENSE TAB
-- =====================
DefenseTab:AddSection({ Name = "Auto Guard" })

DefenseTab:AddToggle({
    Name    = "Auto Guard",
    Default = false,
    Save    = true,
    Flag    = "AutoGuard",
    Callback = function(v)
        State.autoGuard = v
        if not v then
            lastPositions = {}
            pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game) end)
        end
    end,
})

DefenseTab:AddSlider({
    Name      = "Guard Distance",
    Min       = 3,
    Max       = 40,
    Default   = 10,
    Color     = Color3.fromRGB(255, 165, 0),
    Increment = 1,
    ValueName = " studs",
    Callback  = function(v) Settings.guardDistance = v end,
})

DefenseTab:AddSlider({
    Name      = "Movement Prediction",
    Min       = 0,
    Max       = 10,
    Default   = 3,
    Color     = Color3.fromRGB(255, 165, 0),
    Increment = 1,
    ValueName = "x",
    Callback  = function(v) Settings.predictionTime = v / 10 end,
})

DefenseTab:AddSection({ Name = "Follow Ball Carrier" })

DefenseTab:AddToggle({
    Name    = "Follow Ball Carrier",
    Default = false,
    Save    = true,
    Flag    = "Follow",
    Callback = function(v) State.follow = v end,
})

DefenseTab:AddSlider({
    Name      = "Follow Offset",
    Min       = -15,
    Max       = 15,
    Default   = -10,
    Color     = Color3.fromRGB(255, 165, 0),
    Increment = 1,
    ValueName = " studs",
    Callback  = function(v) Settings.followOffset = v end,
})

-- =====================
-- OFFENSE TAB
-- =====================
OffenseTab:AddSection({ Name = "Post Aimbot" })

OffenseTab:AddToggle({
    Name    = "Post Aimbot",
    Default = false,
    Save    = true,
    Flag    = "PostAimbot",
    Callback =
