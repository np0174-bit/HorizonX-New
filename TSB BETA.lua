--[[
    HorizonX - The Strongest Battlegrounds
    Delta Android Compatible - Paste Directly
]]

local placeID = game.PlaceId
if placeID ~= 10449761463 then
    print("This game is not The Strongest Battlegrounds")
    return
end

-- =====================
-- SERVICES
-- =====================
local RunService    = game:GetService("RunService")
local Players       = game:GetService("Players")
local UserInput     = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")

-- =====================
-- PLAYER SETUP
-- =====================
local localPlayer = Players.LocalPlayer
local character   = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid    = character:WaitForChild("Humanoid")
local hrp         = character:WaitForChild("HumanoidRootPart")

localPlayer.CharacterAdded:Connect(function(char)
    character = char
    humanoid  = char:WaitForChild("Humanoid")
    hrp       = char:WaitForChild("HumanoidRootPart")
end)

-- =====================
-- EXPLOITS SETUP
-- =====================
local function setupExploits()
    pcall(function()
        if workspace:GetAttribute("VIPServer") ~= tostring(localPlayer.UserId) then
            workspace:SetAttribute("VIPServer", tostring(localPlayer.UserId))
        end
        if workspace:GetAttribute("VIPServerOwner") ~= localPlayer.Name then
            workspace:SetAttribute("VIPServerOwner", localPlayer.Name)
        end
        if localPlayer:GetAttribute("ExtraSlots") == nil then
            localPlayer:SetAttribute("ExtraSlots", false)
        end
        if localPlayer:GetAttribute("EmoteSearchBar") == nil then
            localPlayer:SetAttribute("EmoteSearchBar", false)
        end
        if workspace:GetAttribute("NoDashCooldown") == nil then
            workspace:SetAttribute("NoDashCooldown", false)
        end
        if workspace:GetAttribute("NoFatigue") == nil then
            workspace:SetAttribute("NoFatigue", false)
        end
    end)
end
setupExploits()

-- =====================
-- STATE
-- =====================
local State = {
    speedBoost    = false,
    jumpBoost     = false,
    noDashCD      = false,
    noFatigue     = false,
    extraSlots    = false,
    searchBar     = false,
    infiniteStam  = false,
    autoBlock     = false,
    killAura      = false,
    esp           = false,
    noclip        = false,
    frozenCam     = false,
}

local Settings = {
    speedMult     = 0.1,
    jumpHeight    = 7.2,
    gravity       = 192.6,
    fov           = 70,
    killAuraDist  = 10,
}

-- =====================
-- ORION UI LOAD
-- =====================
local OrionLib = nil
pcall(function()
    OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()
end)

-- Fallback dummy if load fails
if not OrionLib then
    local dummyTab = {
        AddSection = function() end,
        AddToggle  = function(_, c) end,
        AddSlider  = function(_, c) end,
        AddButton  = function(_, c) end,
        AddLabel   = function() end,
    }
    OrionLib = {
        MakeWindow = function(_, c)
            return { MakeTab = function(_, c) return dummyTab end }
        end,
        Init    = function() end,
        Destroy = function() end,
    }
    warn("[HorizonX] UI failed to load - running headless. Paste script directly into Delta for best results!")
end

-- =====================
-- WINDOW
-- =====================
local Window = OrionLib:MakeWindow({
    Name         = "HorizonX Hub TSB",
    HidePremium  = false,
    SaveConfig   = true,
    ConfigFolder = "HorizonX_TSB",
    IntroEnabled = true,
    IntroText    = "HorizonX Hub TSB",
})

-- =====================
-- TABS
-- =====================
local MainTab      = Window:MakeTab({ Name = "Main",      Icon = "rbxassetid://4483345998", PremiumOnly = false })
local CombatTab    = Window:MakeTab({ Name = "Combat",    Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TeleportTab  = Window:MakeTab({ Name = "Teleport",  Icon = "rbxassetid://4483345998", PremiumOnly = false })
local VisualsTab   = Window:MakeTab({ Name = "Visuals",   Icon = "rbxassetid://4483345998", PremiumOnly = false })
local ExploitsTab  = Window:MakeTab({ Name = "Exploits",  Icon = "rbxassetid://4483345998", PremiumOnly = false })
local MiscTab      = Window:MakeTab({ Name = "Misc",      Icon = "rbxassetid://4483345998", PremiumOnly = false })

-- =====================
-- MAIN TAB - MOVEMENT
-- =====================
MainTab:AddSection({ Name = "Movement" })

MainTab:AddToggle({
    Name    = "Speed Boost",
    Default = false,
    Save    = true,
    Flag    = "SpeedBoost",
    Callback = function(v) State.speedBoost = v end,
})

MainTab:AddSlider({
    Name      = "Speed Multiplier",
    Min       = 0.1,
    Max       = 10,
    Default   = 0.1,
    Color     = Color3.fromRGB(255, 100, 0),
    Increment = 0.1,
    ValueName = "x",
    Callback  = function(v) Settings.speedMult = v end,
})

RunService.Heartbeat:Connect(function()
    if State.speedBoost and character and humanoid then
        if humanoid.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (humanoid.MoveDirection * Settings.speedMult)
        end
    end
end)

MainTab:AddToggle({
    Name    = "Jump Boost",
    Default = false,
    Save    = true,
    Flag    = "JumpBoost",
    Callback = function(v)
        State.jumpBoost = v
        if humanoid then
            humanoid.UseJumpPower = not v
        end
    end,
})

MainTab:AddSlider({
    Name      = "Jump Height",
    Min       = 7.2,
    Max       = 500,
    Default   = 7.2,
    Color     = Color3.fromRGB(255, 100, 0),
    Increment = 0.1,
    ValueName = "%",
    Callback  = function(v)
        Settings.jumpHeight = v
        if humanoid then humanoid.JumpHeight = v end
    end,
})

MainTab:AddToggle({
    Name    = "No Clip",
    Default = false,
    Save    = false,
    Flag    = "NoClip",
    Callback = function(v) State.noclip = v end,
})

RunService.Stepped:Connect(function()
    if State.noclip and character then
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

MainTab:AddSection({ Name = "World" })

MainTab:AddSlider({
    Name      = "Gravity",
    Min       = 0,
    Max       = 196,
    Default   = 196,
    Color     = Color3.fromRGB(255, 100, 0),
    Increment = 0.1,
    ValueName = "%",
    Callback  = function(v)
        Settings.gravity = v
        workspace.Gravity = v
    end,
})

MainTab:AddSlider({
    Name      = "Field of View",
    Min       = 30,
    Max       = 120,
    Default   = 70,
    Color     = Color3.fromRGB(255, 100, 0),
    Increment = 1,
    ValueName = "",
    Callback  = function(v)
        Settings.fov = v
        workspace.CurrentCamera.FieldOfView = v
    end,
})

-- =====================
-- COMBAT TAB
-- =====================
CombatTab:AddSection({ Name = "Kill Aura" })

CombatTab:AddToggle({
    Name    = "Kill Aura",
    Default = false,
    Save    = false,
    Flag    = "KillAura",
    Callback = function(v) State.killAura = v end,
})

CombatTab:AddSlider({
    Name      = "Kill Aura Range",
    Min       = 5,
    Max       = 60,
    Default   = 10,
    Color     = Color3.fromRGB(255, 100, 0),
    Increment = 1,
    ValueName = " studs",
    Callback  = function(v) Settings.killAuraDist = v end,
})

RunService.Heartbeat:Connect(function()
    if not State.killAura then return end
    if not character or not hrp then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer and plr.Character then
            local eHrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local eHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if eHrp and eHum and eHum.Health > 0 then
                local dist = (eHrp.Position - hrp.Position).Magnitude
                if dist <= Settings.killAuraDist then
                    pcall(function()
                        eHum:TakeDamage(eHum.MaxHealth)
                    end)
                end
            end
        end
    end
end)

CombatTab:AddSection({ Name = "Auto Block" })

CombatTab:AddToggle({
    Name    = "Auto Block",
    Default = false,
    Save    = false,
    Flag    = "AutoBlock",
    Callback = function(v)
        State.autoBlock = v
        if v then
            pcall(function()
                workspace:SetAttribute("NoDashCooldown", true)
            end)
        end
    end,
})

CombatTab:AddSection({ Name = "Infinite Stamina" })

CombatTab:AddToggle({
    Name    = "Infinite Stamina",
    Default = false,
    Save    = false,
    Flag    = "InfiniteStam",
    Callback = function(v)
        State.infiniteStam = v
        workspace:SetAttribute("NoFatigue", v)
    end,
})

-- =====================
-- TELEPORT TAB
-- =====================
TeleportTab:AddSection({ Name = "Locations" })

local teleports = {
    { Name = "Middle",             Pos = CFrame.new(148, 441, 27) },
    { Name = "Atomic Room",        Pos = CFrame.new(1079, 155, 23003) },
    { Name = "Death Counter Room", Pos = CFrame.new(-92, 29, 20347) },
    { Name = "Baseplate",          Pos = CFrame.new(968, 20, 23088) },
    { Name = "Mountain 1",         Pos = CFrame.new(266, 699, 458) },
    { Name = "Mountain 2",         Pos = CFrame.new(551, 630, -265) },
    { Name = "Mountain 3",         Pos = CFrame.new(-107, 642, -328) },
    { Name = "Sky",                Pos = CFrame.new(148, 2000, 27) },
    { Name = "Underground",        Pos = CFrame.new(148, -200, 27) },
}

for _, tp in ipairs(teleports) do
    TeleportTab:AddButton({
        Name     = tp.Name,
        Callback = function()
            if hrp then hrp.CFrame = tp.Pos end
        end,
    })
end

TeleportTab:AddSection({ Name = "Teleport to Player" })

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= localPlayer then
        TeleportTab:AddButton({
            Name     = "TP to " .. plr.Name,
            Callback = function()
                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and hrp then
                    hrp.CFrame = plr.Character.HumanoidRootPart.CFrame + Vector3.new(3, 0, 0)
                end
            end,
        })
    end
end

-- =====================
-- VISUALS TAB
-- =====================
VisualsTab:AddSection({ Name = "ESP" })

local function refreshESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer and plr.Character then
            local existing = plr.Character:FindFirstChild("HX_ESP")
            if State.esp then
                if not existing then
                    local h = Instance.new("Highlight")
                    h.Name             = "HX_ESP"
                    h.FillColor        = Color3.fromRGB(255, 50, 50)
                    h.OutlineColor     = Color3.fromRGB(255, 255, 255)
                    h.FillTransparency = 0.5
                    h.Adornee          = plr.Character
                    h.Parent           = plr.Character
                end
            else
                if existing then existing:Destroy() end
            end
        end
    end
end

RunService.Stepped:Connect(function() pcall(refreshESP) end)

VisualsTab:AddToggle({
    Name    = "Player ESP",
    Default = false,
    Save    = true,
    Flag    = "ESP",
    Callback = function(v)
        State.esp = v
        pcall(refreshESP)
    end,
})

VisualsTab:AddSection({ Name = "Camera" })

VisualsTab:AddSlider({
    Name      = "FOV",
    Min       = 30,
    Max       = 120,
    Default   = 70,
    Color     = Color3.fromRGB(255, 100, 0),
    Increment = 1,
    ValueName = "",
    Callback  = function(v)
        workspace.CurrentCamera.FieldOfView = v
    end,
})

-- =====================
-- EXPLOITS TAB
-- =====================
ExploitsTab:AddSection({ Name = "Game Exploits" })

ExploitsTab:AddToggle({
    Name    = "No Dash Cooldown",
    Default = false,
    Save    = true,
    Flag    = "NoDashCD",
    Callback = function(v)
        State.noDashCD = v
        workspace:SetAttribute("NoDashCooldown", v)
    end,
})

ExploitsTab:AddToggle({
    Name    = "No Fatigue",
    Default = false,
    Save    = true,
    Flag    = "NoFatigue",
    Callback = function(v)
        State.noFatigue = v
        workspace:SetAttribute("NoFatigue", v)
    end,
})

ExploitsTab:AddSection({ Name = "Emotes" })

ExploitsTab:AddToggle({
    Name    = "Extra Emote Slots",
    Default = false,
    Save    = true,
    Flag    = "ExtraSlots",
    Callback = function(v)
        State.extraSlots = v
        localPlayer:SetAttribute("ExtraSlots", v)
    end,
})

ExploitsTab:AddToggle({
    Name    = "Emote Search Bar",
    Default = false,
    Save    = true,
    Flag    = "SearchBar",
    Callback = function(v)
        State.searchBar = v
        localPlayer:SetAttribute("EmoteSearchBar", v)
    end,
})

-- =====================
-- MISC TAB
-- =====================
MiscTab:AddSection({ Name = "Info" })
MiscTab:AddLabel("HorizonX - The Strongest Battlegrounds")
MiscTab:AddLabel("Paste directly into Delta for best results")

MiscTab:AddSection({ Name = "Actions" })

MiscTab:AddButton({
    Name     = "Reset Character",
    Callback = function()
        if humanoid then humanoid.Health = 0 end
    end,
})

MiscTab:AddButton({
    Name     = "Reset Gravity",
    Callback = function()
        workspace.Gravity = 196
    end,
})

MiscTab:AddButton({
    Name     =pm "Reset FOV",
    Callback = function()
        workspace.CurrentCamera.FieldOfView = 70
    end,
})

MiscTab:AddButton({
    Name     = "Unload Script",
    Callback = function()
        workspace.Gravity = 196
        workspace.CurrentCamera.FieldOfView = 70
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                local e = plr.Character:FindFirstChild("HX_ESP")
                if e then e:Destroy() end
            end
        end
        OrionLib:Destroy()
    end,
})

-- =====================
-- INIT
-- =====================
OrionLib:Init()

