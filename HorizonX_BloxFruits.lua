

repeat task.wait() until game:IsLoaded()

if game.GameId ~= 2753915549 then
    print("This game is not Blox Fruits")
    return
end

-- =====================
-- SERVICES
-- =====================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(char)
    character = char
    humanoid  = char:WaitForChild("Humanoid")
    hrp       = char:WaitForChild("HumanoidRootPart")
end)

-- =====================
-- STATE
-- =====================
local State = {
    autoFarm     = false,
    autoQuest    = false,
    autoRaid     = false,
    autoBoss     = false,
    autoChest    = false,
    autoFruit    = false,
    esp          = false,
    bossESP      = false,
    fruitESP     = false,
    speedBoost   = false,
    infiniteJump = false,
    noClip       = false,
    antiAFK      = false,
    autoMastery  = false,
}

local Settings = {
    farmRadius = 30,
    walkSpeed  = 24,
    jumpPower  = 50,
}

-- =====================
-- CONNECTIONS
-- =====================
local Connections = {}
local function addConn(key, conn)
    if Connections[key] then pcall(function() Connections[key]:Disconnect() end) end
    Connections[key] = conn
end
local function removeConn(key)
    if Connections[key] then
        pcall(function() Connections[key]:Disconnect() end)
        Connections[key] = nil
    end
end

-- =====================
-- HELPERS
-- =====================
local function getClosestMob(radius)
    local closest, closestDist = nil, radius or math.huge
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    for _, mob in ipairs(enemies:GetChildren()) do
        local mobHrp = mob:FindFirstChild("HumanoidRootPart")
        local mobHum = mob:FindFirstChildOfClass("Humanoid")
        if mobHrp and mobHum and mobHum.Health > 0 and hrp then
            local dist = (mobHrp.Position - hrp.Position).Magnitude
            if dist < closestDist then closestDist = dist; closest = mob end
        end
    end
    return closest
end

local function getClosestBoss(radius)
    local closest, closestDist = nil, radius or math.huge
    local folder = Workspace:FindFirstChild("Bosses") or Workspace:FindFirstChild("Enemies")
    if not folder then return nil end
    for _, boss in ipairs(folder:GetChildren()) do
        local bHrp = boss:FindFirstChild("HumanoidRootPart")
        local bHum = boss:FindFirstChildOfClass("Humanoid")
        if bHrp and bHum and bHum.Health > 0 and hrp then
            local dist = (bHrp.Position - hrp.Position).Magnitude
            if dist < closestDist then closestDist = dist; closest = boss end
        end
    end
    return closest
end

local function getClosestFruit()
    local closest, closestDist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Fruit" or obj:FindFirstChild("PickUp") then
            local pos = obj:IsA("BasePart") and obj.Position
                or (obj:FindFirstChild("Handle") and obj.Handle.Position)
            if pos and hrp then
                local dist = (pos - hrp.Position).Magnitude
                if dist < closestDist then closestDist = dist; closest = obj end
            end
        end
    end
    return closest
end

local function getClosestChest()
    local closest, closestDist = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Chest" or obj.Name == "BreakableChest" then
            local pos = obj:IsA("BasePart") and obj.Position
                or (obj:FindFirstChild("Handle") and obj.Handle.Position)
            if pos and hrp then
                local dist = (pos - hrp.Position).Magnitude
                if dist < closestDist then closestDist = dist; closest = obj end
            end
        end
    end
    return closest
end

local function teleportTo(target)
    if not hrp or not target then return end
    local pos = target:IsA("BasePart") and target.Position
        or (target:FindFirstChild("HumanoidRootPart") and target.HumanoidRootPart.Position)
        or (target:FindFirstChild("Handle") and target.Handle.Position)
    if pos then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
end

local function attackMob(mob)
    if not mob or not hrp then return end
    local mobHrp = mob:FindFirstChild("HumanoidRootPart")
    if not mobHrp then return end
    hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(mobHrp.Position.X, hrp.Position.Y, mobHrp.Position.Z))
    pcall(function()
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then
            local remote = tool:FindFirstChild("RemoteEvent") or tool:FindFirstChild("RE")
            if remote then remote:FireServer(mobHrp) end
        end
    end)
end

-- =====================
-- FARM LOOPS
-- =====================
local function farmLoop(getTarget, interval)
    return task.spawn(function()
        while true do
            task.wait(interval or 0.1)
            pcall(function()
                local target = getTarget()
                if target then
                    local tHrp = target:FindFirstChild("HumanoidRootPart")
                    local tHum = target:FindFirstChildOfClass("Humanoid")
                    if tHrp and (not tHum or tHum.Health > 0) and hrp then
                        local dir = (hrp.Position - tHrp.Position).Unit
                        hrp.CFrame = CFrame.new(tHrp.Position + dir * 5 + Vector3.new(0, 3, 0))
                        attackMob(target)
                    end
                end
            end)
        end
    end)
end

local farmThread  = nil
local bossThread  = nil
local fruitThread = nil
local chestThread = nil
local raidThread  = nil

-- =====================
-- STATS LOOP
-- =====================
addConn("stats", RunService.Heartbeat:Connect(function()
    if not humanoid then return end
    pcall(function()
        humanoid.WalkSpeed = State.speedBoost and Settings.walkSpeed or 16
        humanoid.JumpPower = State.infiniteJump and Settings.jumpPower or 50
    end)
    if State.noClip and character then
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end))

addConn("infJump", UserInputService.JumpRequest:Connect(function()
    if State.infiniteJump and humanoid then
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end))

-- =====================
-- ESP
-- =====================
local function refreshESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local ex = plr.Character:FindFirstChild("HX_ESP")
            if State.esp then
                if not ex then
                    local h = Instance.new("Highlight")
                    h.Name = "HX_ESP"; h.FillColor = Color3.fromRGB(255,50,50)
                    h.OutlineColor = Color3.fromRGB(255,255,255); h.FillTransparency = 0.5
                    h.Adornee = plr.Character; h.Parent = plr.Character
                end
            else if ex then ex:Destroy() end end
        end
    end
    local folder = Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("Bosses")
    if folder then
        for _, mob in ipairs(folder:GetChildren()) do
            local ex = mob:FindFirstChild("HX_BossESP")
            if State.bossESP then
                if not ex then
                    local h = Instance.new("Highlight")
                    h.Name = "HX_BossESP"; h.FillColor = Color3.fromRGB(255,0,0)
                    h.OutlineColor = Color3.fromRGB(255,200,0); h.FillTransparency = 0.3
                    h.Adornee = mob; h.Parent = mob
                end
            else if ex then ex:Destroy() end end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Fruit" then
            local ex = obj:FindFirstChild("HX_FruitESP")
            if State.fruitESP then
                if not ex then
                    local h = Instance.new("Highlight")
                    h.Name = "HX_FruitESP"; h.FillColor = Color3.fromRGB(0,200,255)
                    h.OutlineColor = Color3.fromRGB(255,255,255); h.FillTransparency = 0.2
                    h.Adornee = obj; h.Parent = obj
                end
            else if ex then ex:Destroy() end end
        end
    end
end

addConn("esp", RunService.Stepped:Connect(function() pcall(refreshESP) end))

-- =====================
-- ORION UI
-- =====================
local OrionLib = nil
pcall(function()
    OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()
end)
if not OrionLib then
    local dt = { AddSection=function()end, AddToggle=function()end,
                 AddSlider=function()end, AddButton=function()end, AddLabel=function()end }
    OrionLib = { MakeWindow=function(_,c) return{MakeTab=function() return dt end} end,
                 Init=function()end, Destroy=function()end }
end

local Window = OrionLib:MakeWindow({
    Name="HorizonX Hub - Blox Fruits", HidePremium=false,
    SaveConfig=true, ConfigFolder="HorizonX_BF",
    IntroEnabled=true, IntroText="HorizonX Hub - Blox Fruits",
})

local FarmTab    = Window:MakeTab({ Name="Auto Farm", Icon="rbxassetid://4483345998", PremiumOnly=false })
local BossTab    = Window:MakeTab({ Name="Boss",      Icon="rbxassetid://4483345998", PremiumOnly=false })
local FruitTab   = Window:MakeTab({ Name="Fruit",     Icon="rbxassetid://4483345998", PremiumOnly=false })
local PlayerTab  = Window:MakeTab({ Name="Player",    Icon="rbxassetid://4483345998", PremiumOnly=false })
local VisualsTab = Window:MakeTab({ Name="Visuals",   Icon="rbxassetid://4483345998", PremiumOnly=false })
local MiscTab    = Window:MakeTab({ Name="Misc",      Icon="rbxassetid://4483345998", PremiumOnly=false })

-- FARM TAB
FarmTab:AddSection({ Name = "Auto Farm" })
FarmTab:AddToggle({ Name="Auto Farm Mobs", Default=false, Save=true, Flag="AutoFarm",
    Callback=function(v)
        State.autoFarm = v
        if v then
            farmThread = farmLoop(function() return getClosestMob(Settings.farmRadius) end, 0.1)
        else
            if farmThread then task.cancel(farmThread); farmThread = nil end
        end
    end })
FarmTab:AddSlider({ Name="Farm Radius", Min=10, Max=200, Default=30,
    Color=Color3.fromRGB(255,100,0), Increment=5, ValueName=" studs",
    Callback=function(v) Settings.farmRadius = v end })

FarmTab:AddSection({ Name = "Auto Mastery" })
FarmTab:AddToggle({ Name="Auto Mastery Farm", Default=false, Save=false, Flag="AutoMastery",
    Callback=function(v)
        State.autoMastery = v
        if v then
            addConn("mastery", RunService.Heartbeat:Connect(function()
                if not State.autoMastery then removeConn("mastery"); return end
                pcall(function()
                    local mob = getClosestMob(Settings.farmRadius)
                    if mob then
                        local mHrp = mob:FindFirstChild("HumanoidRootPart")
                        local mHum = mob:FindFirstChildOfClass("Humanoid")
                        if mHrp and mHum and mHum.Health > 0 and hrp then
                            local dir = (hrp.Position - mHrp.Position).Unit
                            hrp.CFrame = CFrame.new(mHrp.Position + dir * 4 + Vector3.new(0,3,0))
                            attackMob(mob)
                        end
                    end
                end)
            end))
        else
            removeConn("mastery")
        end
    end })
FarmTab:AddLabel("Farms mobs to level up weapon or fruit mastery")

FarmTab:AddSection({ Name = "Auto Quest" })
FarmTab:AddToggle({ Name="Auto Accept Quest", Default=false, Save=true, Flag="AutoQuest",
    Callback=function(v)
        State.autoQuest = v
        if v then
            addConn("quest", RunService.Heartbeat:Connect(function()
                if not State.autoQuest then removeConn("quest"); return end
                pcall(function()
                    for _, npc in ipairs(Workspace:GetDescendants()) do
                        if npc.Name == "QuestGiver" or npc.Name == "Quest" then
                            local prompt = npc:FindFirstChildOfClass("ProximityPrompt")
                            if prompt then fireproximityprompt(prompt) end
                        end
                    end
                end)
            end))
        else removeConn("quest") end
    end })

-- BOSS TAB
BossTab:AddSection({ Name = "Auto Boss" })
BossTab:AddToggle({ Name="Auto Boss Farm", Default=false, Save=false, Flag="AutoBoss",
    Callback=function(v)
        State.autoBoss = v
        if v then
            bossThread = farmLoop(function() return getClosestBoss(500) end, 0.1)
        else
            if bossThread then task.cancel(bossThread); bossThread = nil end
        end
    end })
BossTab:AddButton({ Name="Teleport to Nearest Boss",
    Callback=function()
        local boss = getClosestBoss(5000)
        if boss then teleportTo(boss) end
    end })

BossTab:AddSection({ Name = "Auto Raid" })
BossTab:AddToggle({ Name="Auto Raid", Default=false, Save=false, Flag="AutoRaid",
    Callback=function(v)
        State.autoRaid = v
        if v then
            raidThread = farmLoop(function() return getClosestBoss(1000) end, 0.1)
        else
            if raidThread then task.cancel(raidThread); raidThread = nil end
        end
    end })

-- FRUIT TAB
FruitTab:AddSection({ Name = "Auto Fruit" })
FruitTab:AddToggle({ Name="Auto Collect Fruits", Default=false, Save=false, Flag="AutoFruit",
    Callback=function(v)
        State.autoFruit = v
        if v then
            fruitThread = task.spawn(function()
                while State.autoFruit do
                    pcall(function()
                        local fruit = getClosestFruit()
                        if fruit then
                            teleportTo(fruit)
                            task.wait(0.5)
                            local pickup = fruit:FindFirstChild("PickUp")
                            if pickup and pickup:IsA("RemoteEvent") then
                                pcall(function() pickup:FireServer() end)
                            end
                        end
                    end)
                    task.wait(2)
                end
            end)
        else
            if fruitThread then task.cancel(fruitThread); fruitThread = nil end
        end
    end })

FruitTab:AddToggle({ Name="Auto Eat Fruit", Default=false, Save=false, Flag="AutoEat",
    Callback=function(v)
        if v then
            addConn("autoEat", RunService.Heartbeat:Connect(function()
                if not v then removeConn("autoEat"); return end
                pcall(function()
                    local tool = character:FindFirstChildOfClass("Tool")
                    if tool then
                        local eat = tool:FindFirstChild("Eat")
                        if eat then eat:FireServer() end
                    end
                end)
            end))
        else removeConn("autoEat") end
    end })

FruitTab:AddSection({ Name = "Auto Chest" })
FruitTab:AddToggle({ Name="Auto Open Chests", Default=false, Save=false, Flag="AutoChest",
    Callback=function(v)
        State.autoChest = v
        if v then
            chestThread = task.spawn(function()
                while State.autoChest do
                    pcall(function()
                        local chest = getClosestChest()
                        if chest then teleportTo(chest); task.wait(0.5) end
                    end)
                    task.wait(2)
                end
            end)
        else
            if chestThread then task.cancel(chestThread); chestThread = nil end
        end
    end })

FruitTab:AddButton({ Name="Teleport to Nearest Fruit",
    Callback=function()
        local fruit = getClosestFruit()
        if fruit then teleportTo(fruit) end
    end })
FruitTab:AddButton({ Name="Teleport to Nearest Chest",
    Callback=function()
        local chest = getClosestChest()
        if chest then teleportTo(chest) end
    end })

-- PLAYER TAB
PlayerTab:AddSection({ Name = "Speed" })
PlayerTab:AddToggle({ Name="Speed Boost", Default=false, Save=true, Flag="SpeedBoost",
    Callback=function(v) State.speedBoost = v end })
PlayerTab:AddSlider({ Name="Walk Speed", Min=16, Max=500, Default=24,
    Color=Color3.fromRGB(255,100,0), Increment=1, ValueName=" spd",
    Callback=function(v) Settings.walkSpeed = v end })

PlayerTab:AddSection({ Name = "Jump" })
PlayerTab:AddToggle({ Name="Infinite Jump", Default=false, Save=false, Flag="InfJump",
    Callback=function(v) State.infiniteJump = v end })
PlayerTab:AddSlider({ Name="Jump Power", Min=50, Max=500, Default=50,
    Color=Color3.fromRGB(255,100,0), Increment=5, ValueName=" pwr",
    Callback=function(v) Settings.jumpPower = v end })

PlayerTab:AddSection({ Name = "Physics" })
PlayerTab:AddToggle({ Name="No Clip", Default=false, Save=false, Flag="NoClip",
    Callback=function(v)
        State.noClip = v
        if not v and character then
            for _, p in ipairs(character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end })

PlayerTab:AddSection({ Name = "Teleports" })
PlayerTab:AddButton({ Name="Teleport to Nearest Mob",
    Callback=function()
        local mob = getClosestMob(1000)
        if mob then teleportTo(mob) end
    end })
PlayerTab:AddButton({ Name="Teleport to Spawn",
    Callback=function() if hrp then hrp.CFrame = CFrame.new(0, 10, 0) end end })

-- VISUALS TAB
VisualsTab:AddSection({ Name = "ESP" })
VisualsTab:AddToggle({ Name="Player ESP", Default=false, Save=true, Flag="ESP",
    Callback=function(v) State.esp = v; pcall(refreshESP) end })
VisualsTab:AddToggle({ Name="Boss and Mob ESP", Default=false, Save=true, Flag="BossESP",
    Callback=function(v) State.bossESP = v; pcall(refreshESP) end })
VisualsTab:AddToggle({ Name="Fruit ESP (Blue)", Default=false, Save=true, Flag="FruitESP",
    Callback=function(v) State.fruitESP = v; pcall(refreshESP) end })

-- MISC TAB
MiscTab:AddSection({ Name = "Utility" })
MiscTab:AddToggle({ Name="Anti-AFK", Default=false, Save=true, Flag="AntiAFK",
    Callback=function(v)
        State.antiAFK = v
        if v then
            addConn("antiAFK", RunService.Heartbeat:Connect(function()
                if not State.antiAFK then removeConn("antiAFK"); return end
                pcall(function()
                    local VIM = game:GetService("VirtualInputManager")
                    VIM:SendKeyEvent(true, Enum.KeyCode.W, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                end)
            end))
        else removeConn("antiAFK") end
    end })

MiscTab:AddSection({ Name = "Info" })
MiscTab:AddLabel("HorizonX Hub - Blox Fruits Auto Farm")
MiscTab:AddLabel("Paste directly into Delta for best results")

MiscTab:AddSection({ Name = "Actions" })
MiscTab:AddButton({ Name="Stop All Features",
    Callback=function()
        for k in pairs(State) do State[k] = false end
        for k, conn in pairs(Connections) do
            pcall(function() conn:Disconnect() end); Connections[k] = nil
        end
        for _, t in ipairs({farmThread, bossThread, fruitThread, chestThread, raidThread}) do
            if t then pcall(function() task.cancel(t) end) end
        end
        farmThread=nil; bossThread=nil; fruitThread=nil; chestThread=nil; raidThread=nil
        if humanoid then humanoid.WalkSpeed=16; humanoid.JumpPower=50 end
    end })
MiscTab:AddButton({ Name="Unload Script",
    Callback=function()
        for k, conn in pairs(Connections) do
            pcall(function() conn:Disconnect() end); Connections[k] = nil
        end
        if humanoid then humanoid.WalkSpeed=16; humanoid.JumpPower=50 end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                local e = plr.Character:FindFirstChild("HX_ESP")
                if e then e:Destroy() end
            end
        end
        OrionLib:Destroy()
    end })

OrionLib:Init()
