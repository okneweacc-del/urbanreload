local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = {
    Aim = {
        Enabled = false,
        FOV = 150,
        Smoothness = 0.35,
        MaxDistance = 600,
        VisibleOnly = true,
        HeadOnly = true,
        Prediction = 0.0,
    },
    ESP = {
        Enabled = false,
        Box = true,
        Name = true,
        Health = true,
        Distance = true,
        Tracer = false,
        Skeleton = false,
        HeadDot = true,
        TeamCheck = false,
        MaxDistance = 1000,
        Color = Color3.fromRGB(0, 200, 255),
        EnemyColor = Color3.fromRGB(255, 60, 60),
    },
    AntiCheat = {
        Enabled = true,
        MaxSpeed = 100,
        MaxTeleportDistance = 50,
        CheckInterval = 0.25,
    },
    Bypass = {
        Enabled = true,
        SpoofWalkSpeed = true,
        SpoofJumpPower = true,
        SpoofGravity = true,
        AntiKick = true,
        AntiFling = true,
        AntiVoid = true,
        HideFromServer = true,
    },
    UI = {
        AccentColor = Color3.fromRGB(0, 170, 255),
        BgColor = Color3.fromRGB(20, 20, 30),
        TextColor = Color3.fromRGB(240, 240, 240),
        Font = Enum.Font.GothamBold,
        Visible = true,
    }
}

local Connections = {}
local function addConn(conn) table.insert(Connections, conn) return conn end

local Bypass = {}
Bypass.OriginalSpeed = nil
Bypass.OriginalJump = nil
Bypass.SpoofedSpeed = 16
Bypass.OriginalGravity = nil
Bypass.InternalChange = false

local function hasExecutor()
    return type(getgenv) == "table"
end

function Bypass:SpoofWalkSpeed(enable, value)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if enable then
        self.OriginalSpeed = hum.WalkSpeed
        self.SpoofedSpeed = value or hum.WalkSpeed
        hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Bypass.OriginalSpeed and not Bypass.InternalChange then
                Bypass.InternalChange = true
                hum.WalkSpeed = Bypass.SpoofedSpeed
                Bypass.InternalChange = false
            end
        end)
        hum.WalkSpeed = self.SpoofedSpeed
    else
        if self.OriginalSpeed then hum.WalkSpeed = self.OriginalSpeed end
    end
end

function Bypass:SpoofJumpPower(enable, value)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if enable then
        self.OriginalJump = hum.UseJumpPower and hum.JumpPower or hum.JumpHeight
        if hum.UseJumpPower then hum.JumpPower = value or hum.JumpPower
        else hum.JumpHeight = value or hum.JumpHeight end
    else
        if self.OriginalJump then
            if hum.UseJumpPower then hum.JumpPower = self.OriginalJump
            else hum.JumpHeight = self.OriginalJump end
        end
    end
end

function Bypass:SpoofGravity(enable)
    if enable then
        self.OriginalGravity = Workspace.Gravity
        Workspace.Gravity = 196.2
    else
        if self.OriginalGravity then Workspace.Gravity = self.OriginalGravity end
    end
end

local function antiKick()
    if not hasExecutor() then return end
    if type(hookfunction) ~= "function" then return end
    pcall(function()
        hookfunction(LocalPlayer.Kick, function() return end)
    end)
end

local function antiFling()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part:GetPropertyChangedSignal("RotVelocity"):Connect(function()
                if part.RotVelocity.Magnitude > 1000 then
                    part.RotVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end)
            part:GetPropertyChangedSignal("Velocity"):Connect(function()
                if part.Velocity.Magnitude > 1000 then
                    part.Velocity = Vector3.zero
                    part.AssemblyLinearVelocity = Vector3.zero
                end
            end)
        end
    end
end

local function antiVoid()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if hrp.Position.Y < -50 then
        local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
        if spawn then
            hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
        end
    end
end

function Bypass:Init()
    if self.InitDone then return end
    self.InitDone = true
    if Config.Bypass.SpoofWalkSpeed then self:SpoofWalkSpeed(true, 100) end
    if Config.Bypass.SpoofJumpPower then self:SpoofJumpPower(true, 100) end
    if Config.Bypass.SpoofGravity then self:SpoofGravity(true) end
    if Config.Bypass.AntiKick then antiKick() end
    if Config.Bypass.AntiFling then
        addConn(LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            antiFling()
        end))
        antiFling()
    end
    if Config.Bypass.AntiVoid then
        addConn(RunService.Heartbeat:Connect(antiVoid))
    end
    if Config.Bypass.HideFromServer and hasExecutor() and type(sethiddenproperty) == "function" then
        pcall(function()
            local char = LocalPlayer.Character
            if char then sethiddenproperty(char, "Archivable", false) end
        end)
    end
end

function Bypass:Toggle(enable)
    Config.Bypass.Enabled = enable
    if enable then
        self:Init()
    else
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if self.OriginalSpeed and hum then hum.WalkSpeed = self.OriginalSpeed end
        if self.OriginalJump and hum then
            if hum.UseJumpPower then hum.JumpPower = self.OriginalJump
            else hum.JumpHeight = self.OriginalJump end
        end
        if self.OriginalGravity then Workspace.Gravity = self.OriginalGravity end
    end
end

local Aimbot = {}
Aimbot.IsActive = false
Aimbot.CurrentTarget = nil

local function getAlivePlayers()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(list, plr)
            end
        end
    end
    return list
end

local function isTeam(plr)
    if not Config.ESP.TeamCheck then return false end
    return plr.Team == LocalPlayer.Team
end

local function worldToScreen(pos)
    local sp, onScreen = Camera:WorldToViewportPoint(pos)
    if not onScreen then return nil end
    return Vector2.new(sp.X, sp.Y)
end

local function isVisible(targetPart)
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local dir = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    local hit = result.Instance
    return hit == targetPart or hit:IsDescendantOf(targetPart.Parent)
end

function Aimbot:FindBestTarget()
    local best, bestDist = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(getAlivePlayers()) do
        if not isTeam(plr) then
            local char = plr.Character
            local part = Config.Aim.HeadOnly and char:FindFirstChild("Head")
                or (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            if part then
                local dist = (part.Position - Camera.CFrame.Position).Magnitude
                if dist <= Config.Aim.MaxDistance then
                    local sp = worldToScreen(part.Position)
                    if sp and (sp - center).Magnitude <= Config.Aim.FOV then
                        local visible = (not Config.Aim.VisibleOnly) or isVisible(part)
                        if visible and dist < bestDist then
                            best = { Player = plr, Part = part }
                            bestDist = dist
                        end
                    end
                end
            end
        end
    end
    return best
end

function Aimbot:Update()
    if not Config.Aim.Enabled or not self.IsActive then
        self.CurrentTarget = nil
        return
    end
    local target = self:FindBestTarget()
    if not target then
        self.CurrentTarget = nil
        return
    end
    self.CurrentTarget = target
    local targetPos = target.Part.Position
    if Config.Aim.Prediction > 0 then
        targetPos = targetPos + target.Part.AssemblyLinearVelocity * Config.Aim.Prediction
    end
    local currentCF = Camera.CFrame
    local desiredCF = CFrame.new(currentCF.Position, targetPos)
    local alpha = 1 - math.clamp(Config.Aim.Smoothness, 0.01, 0.99)
    Camera.CFrame = currentCF:Lerp(desiredCF, alpha)
end

addConn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aimbot.IsActive = true
    end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aimbot.IsActive = false
        Aimbot.CurrentTarget = nil
    end
end))

addConn(RunService.RenderStepped:Connect(function()
    Aimbot:Update()
end))

local ESP = {}
ESP.Objects = {}
ESP.SkeletonBones = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local function createDrawing(class, props)
    local ok, obj = pcall(function() return Drawing.new(class) end)
    if not ok then return nil end
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

local function newESP(plr)
    local obj = {
        Box = createDrawing("Square", { Thickness = 1, Color = Config.ESP.Color, Filled = false }),
        Name = createDrawing("Text", { Size = 14, Center = true, Outline = true, Color = Config.ESP.Color, Font = 2 }),
        HealthBar = createDrawing("Square", { Thickness = 1, Filled = true, Color = Color3.fromRGB(0, 255, 0) }),
        HealthBg = createDrawing("Square", { Thickness = 1, Filled = true, Color = Color3.fromRGB(40, 40, 40) }),
        Distance = createDrawing("Text", { Size = 12, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255), Font = 2 }),
        Tracer = createDrawing("Line", { Thickness = 1, Color = Config.ESP.Color }),
        HeadDot = createDrawing("Circle", { Thickness = 1, Filled = true, Color = Config.ESP.Color, Radius = 4 }),
        Skeleton = {}
    }
    for i = 1, #ESP.SkeletonBones do
        obj.Skeleton[i] = createDrawing("Line", { Thickness = 1, Color = Config.ESP.Color })
    end
    ESP.Objects[plr] = obj
    return obj
end

local function hideESP(obj)
    if not obj then return end
    for k, v in pairs(obj) do
        if type(v) == "table" then
            for _, line in ipairs(v) do
                if line then line.Visible = false end
            end
        elseif v and v.Remove then
            v.Visible = false
        end
    end
end

local function removeESP(plr)
    local obj = ESP.Objects[plr]
    if not obj then return end
    for k, v in pairs(obj) do
        if type(v) == "table" then
            for _, line in ipairs(v) do
                if line then line:Remove() end
            end
        elseif v and v.Remove then
            v:Remove()
        end
    end
    ESP.Objects[plr] = nil
end

local function updateESP(plr)
    local obj = ESP.Objects[plr]
    if not obj then return end
    if not Config.ESP.Enabled or not plr.Character then
        hideESP(obj)
        return
    end
    local char = plr.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then
        hideESP(obj)
        return
    end
    local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
    if dist > Config.ESP.MaxDistance then
        hideESP(obj)
        return
    end
    local color = Config.ESP.Color
    if Config.ESP.TeamCheck and not isTeam(plr) then color = Config.ESP.EnemyColor end
    local hrpScreen = worldToScreen(hrp.Position)

    if Config.ESP.Box and hrpScreen then
        local top = worldToScreen(hrp.Position + Vector3.new(0, 3, 0))
        local bottom = worldToScreen(hrp.Position - Vector3.new(0, 3, 0))
        if top and bottom then
            local h = math.abs(bottom.Y - top.Y)
            local w = h * 0.55
            obj.Box.Visible = true
            obj.Box.Color = color
            obj.Box.Size = Vector2.new(w, h)
            obj.Box.Position = Vector2.new(top.X - w / 2, top.Y)
        else
            obj.Box.Visible = false
        end
    else
        obj.Box.Visible = false
    end

    if Config.ESP.Name and hrpScreen then
        obj.Name.Visible = true
        obj.Name.Text = plr.Name
        obj.Name.Position = worldToScreen(hrp.Position + Vector3.new(0, 3.6, 0)) or Vector2.new(-100, -100)
        obj.Name.Color = color
    else
        obj.Name.Visible = false
    end

    if Config.ESP.Distance and hrpScreen then
        obj.Distance.Visible = true
        obj.Distance.Text = math.floor(dist) .. "m"
        obj.Distance.Position = worldToScreen(hrp.Position - Vector3.new(0, 3.4, 0)) or Vector2.new(-100, -100)
    else
        obj.Distance.Visible = false
    end

    if Config.ESP.Health and hrpScreen then
        local h = hum.Health / hum.MaxHealth
        local top = worldToScreen(hrp.Position + Vector3.new(0, 3, 0))
        local bottom = worldToScreen(hrp.Position - Vector3.new(0, 3, 0))
        if top and bottom then
            local barH = math.abs(bottom.Y - top.Y)
            local barX = top.X - 40
            obj.HealthBg.Visible = true
            obj.HealthBg.Size = Vector2.new(3, barH)
            obj.HealthBg.Position = Vector2.new(barX, top.Y)
            obj.HealthBar.Visible = true
            obj.HealthBar.Size = Vector2.new(3, barH * h)
            obj.HealthBar.Position = Vector2.new(barX, top.Y + barH * (1 - h))
            obj.HealthBar.Color = Color3.fromRGB(
                math.floor(255 * (1 - h)),
                math.floor(255 * h), 0
            )
        else
            obj.HealthBar.Visible = false
            obj.HealthBg.Visible = false
        end
    else
        obj.HealthBar.Visible = false
        obj.HealthBg.Visible = false
    end

    if Config.ESP.Tracer and hrpScreen then
        obj.Tracer.Visible = true
        obj.Tracer.Color = color
        obj.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        obj.Tracer.To = hrpScreen
    else
        obj.Tracer.Visible = false
    end

    if Config.ESP.HeadDot then
        local head = char:FindFirstChild("Head")
        if head then
            local sp = worldToScreen(head.Position)
            if sp then
                obj.HeadDot.Visible = true
                obj.HeadDot.Color = color
                obj.HeadDot.Position = sp
            else
                obj.HeadDot.Visible = false
            end
        else
            obj.HeadDot.Visible = false
        end
    else
        obj.HeadDot.Visible = false
    end

    if Config.ESP.Skeleton then
        for i, bone in ipairs(ESP.SkeletonBones) do
            local p1 = char:FindFirstChild(bone[1])
            local p2 = char:FindFirstChild(bone[2])
            local line = obj.Skeleton[i]
            if p1 and p2 and line then
                local s1 = worldToScreen(p1.Position)
                local s2 = worldToScreen(p2.Position)
                if s1 and s2 then
                    line.Visible = true
                    line.Color = color
                    line.From = s1
                    line.To = s2
                else
                    line.Visible = false
                end
            elseif line then
                line.Visible = false
            end
        end
    else
        for _, line in ipairs(obj.Skeleton) do
            if line then line.Visible = false end
        end
    end
end

addConn(Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then newESP(plr) end
end))
addConn(Players.PlayerRemoving:Connect(function(plr) removeESP(plr) end))

addConn(RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and ESP.Objects[plr] then
            updateESP(plr)
        end
    end
end))

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then newESP(plr) end
end

local AntiCheat = {}
AntiCheat.LastPosition = nil
AntiCheat.LastCheckTime = tick()
AntiCheat.Violations = 0
AntiCheat.OnDetect = function(msg) warn("[Anti-Cheat] " .. msg) end

addConn(RunService.Heartbeat:Connect(function()
    if not Config.AntiCheat.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local now = tick()
    local dt = now - AntiCheat.LastCheckTime
    if dt < Config.AntiCheat.CheckInterval then return end
    AntiCheat.LastCheckTime = now
    if AntiCheat.LastPosition then
        local dist = (hrp.Position - AntiCheat.LastPosition).Magnitude
        local speed = dist / dt
        if speed > Config.AntiCheat.MaxSpeed then
            AntiCheat.Violations += 1
            AntiCheat.OnDetect("Speed: " .. math.floor(speed))
        end
        if dist > Config.AntiCheat.MaxTeleportDistance then
            AntiCheat.Violations += 1
            AntiCheat.OnDetect("Teleport: " .. math.floor(dist))
        end
    end
    AntiCheat.LastPosition = hrp.Position
end))

local function createUI()
    local old = CoreGui:FindFirstChild("CharlieKienMenu")
    if old then old:Destroy() end

    local function tw(obj, time, props, style, dir)
        local ti = TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
        local t = TweenService:Create(obj, ti, props)
        t:Play()
        return t
    end

    local function corner(parent, radius)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius or 8)
        c.Parent = parent
        return c
    end

    local function stroke(parent, color, thickness, transparency)
        local s = Instance.new("UIStroke")
        s.Color = color or Config.UI.AccentColor
        s.Thickness = thickness or 1
        s.Transparency = transparency or 0.5
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end

    local function gradient(parent, c1, c2, rotation)
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(c1, c2)
        g.Rotation = rotation or 90
        g.Parent = parent
        return g
    end

    local Accent = Config.UI.AccentColor
    local AccentDark = Color3.fromRGB(0, 120, 200)
    local AccentLight = Color3.fromRGB(80, 200, 255)
    local BgPanel = Color3.fromRGB(22, 22, 32)
    local BgRow = Color3.fromRGB(32, 32, 46)
    local BgRowHover = Color3.fromRGB(42, 42, 60)
    local TextC = Config.UI.TextColor
    local TextDim = Color3.fromRGB(150, 150, 170)
    local Green = Color3.fromRGB(60, 220, 120)
    local Red = Color3.fromRGB(240, 80, 80)

    local gui = Instance.new("ScreenGui")
    gui.Name = "CharlieKienMenu"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = CoreGui

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(0, 44, 0, 44)
    toggleBtn.Position = UDim2.new(0, 24, 0.5, -22)
    toggleBtn.BackgroundColor3 = BgPanel
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.Visible = false
    toggleBtn.Parent = gui
    corner(toggleBtn, 22)
    stroke(toggleBtn, Accent, 1.5, 0.2)

    local toggleGlow = Instance.new("Frame")
    toggleGlow.Size = UDim2.new(1, 4, 1, 4)
    toggleGlow.Position = UDim2.new(0, -2, 0, -2)
    toggleGlow.BackgroundColor3 = Accent
    toggleGlow.BackgroundTransparency = 0.7
    toggleGlow.ZIndex = -1
    toggleGlow.Parent = toggleBtn
    corner(toggleGlow, 24)

    local toggleIcon = Instance.new("TextLabel")
    toggleIcon.Size = UDim2.new(1, 0, 1, 0)
    toggleIcon.BackgroundTransparency = 1
    toggleIcon.Text = "C"
    toggleIcon.TextColor3 = Accent
    toggleIcon.Font = Enum.Font.GothamBold
    toggleIcon.TextSize = 20
    toggleIcon.Parent = toggleBtn

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 500, 0, 620)
    panel.Position = UDim2.new(0.5, -250, 0.5, -310)
    panel.BackgroundColor3 = BgPanel
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = gui
    panel.Visible = true
    corner(panel, 16)
    stroke(panel, Accent, 1.5, 0.4)
    gradient(panel, Color3.fromRGB(28, 28, 40), Color3.fromRGB(18, 18, 26), 90)

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 0.85
    shadow.ZIndex = -1
    shadow.Parent = panel
    corner(shadow, 20)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = Color3.new(1, 1, 1)
    header.BackgroundTransparency = 1
    header.BorderSizePixel = 0
    header.Parent = panel

    local headerGrad = Instance.new("Frame")
    headerGrad.Size = UDim2.new(1, 0, 1, 0)
    headerGrad.BackgroundColor3 = Accent
    headerGrad.BackgroundTransparency = 0.85
    headerGrad.BorderSizePixel = 0
    headerGrad.Parent = header
    corner(headerGrad, 16)
    gradient(headerGrad, Accent, AccentDark, 0)

    local logoCircle = Instance.new("Frame")
    logoCircle.Size = UDim2.new(0, 36, 0, 36)
    logoCircle.Position = UDim2.new(0, 16, 0.5, -18)
    logoCircle.BackgroundColor3 = Accent
    logoCircle.Parent = header
    corner(logoCircle, 10)
    gradient(logoCircle, AccentLight, Accent, 45)

    local logoIcon = Instance.new("TextLabel")
    logoIcon.Size = UDim2.new(1, 0, 1, 0)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Text = "⚡"
    logoIcon.TextColor3 = Color3.new(1, 1, 1)
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.TextSize = 20
    logoIcon.Parent = logoCircle

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 240, 0, 20)
    title.Position = UDim2.new(0, 62, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "CharlieKien Hub"
    title.TextColor3 = TextC
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0, 240, 0, 16)
    subtitle.Position = UDim2.new(0, 62, 0, 30)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Premium Build v2.0"
    subtitle.TextColor3 = TextDim
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextSize = 11
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -42, 0.5, -15)
    closeBtn.BackgroundColor3 = Red
    closeBtn.BackgroundTransparency = 0.75
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header
    corner(closeBtn, 8)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -78, 0.5, -15)
    minBtn.BackgroundColor3 = Accent
    minBtn.BackgroundTransparency = 0.75
    minBtn.Text = "−"
    minBtn.TextColor3 = Color3.new(1, 1, 1)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 16
    minBtn.AutoButtonColor = false
    minBtn.Parent = header
    corner(minBtn, 8)

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 44)
    tabBar.Position = UDim2.new(0, 10, 0, 68)
    tabBar.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    tabBar.BackgroundTransparency = 0.2
    tabBar.BorderSizePixel = 0
    tabBar.Parent = panel
    corner(tabBar, 10)

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.Parent = tabBar

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -128)
    contentFrame.Position = UDim2.new(0, 10, 0, 118)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.Parent = panel

    local tabs = {}
    local activeTab = nil

    local function createScroll(parent)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.ScrollBarImageTransparency = 0.3
        scroll.Parent = parent
        local l = Instance.new("UIListLayout")
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Padding = UDim.new(0, 8)
        l.Parent = scroll
        local p = Instance.new("UIPadding")
        p.PaddingRight = UDim.new(0, 8)
        p.Parent = scroll
        return scroll
    end

    local function createTab(name, icon)
        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(0, 108, 0, 32)
        tabBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
        tabBtn.Text = ""
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = tabBar
        corner(tabBtn, 8)

        local tabIcon = Instance.new("TextLabel")
        tabIcon.Size = UDim2.new(0, 24, 1, 0)
        tabIcon.Position = UDim2.new(0, 8, 0, 0)
        tabIcon.BackgroundTransparency = 1
        tabIcon.Text = icon or "●"
        tabIcon.TextColor3 = TextDim
        tabIcon.Font = Enum.Font.GothamBold
        tabIcon.TextSize = 14
        tabIcon.Parent = tabBtn

        local tabLabel = Instance.new("TextLabel")
        tabLabel.Size = UDim2.new(1, -34, 1, 0)
        tabLabel.Position = UDim2.new(0, 32, 0, 0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.Text = name
        tabLabel.TextColor3 = TextDim
        tabLabel.Font = Enum.Font.GothamBold
        tabLabel.TextSize = 12
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.Parent = tabBtn

        local scroll = createScroll(contentFrame)
        scroll.Visible = false

        local tab = {
            Button = tabBtn,
            Scroll = scroll,
            Icon = tabIcon,
            Label = tabLabel,
            Active = false,
        }
        tabs[name] = tab
        return tab
    end

    local function activateTab(name)
        for tName, tab in pairs(tabs) do
            local isActive = tName == name
            tab.Active = isActive
            tab.Scroll.Visible = isActive
            tw(tab.Button, 0.2, { BackgroundColor3 = isActive and Accent or Color3.fromRGB(28, 28, 40) })
            tw(tab.Icon, 0.2, { TextColor3 = isActive and Color3.new(1, 1, 1) or TextDim })
            tw(tab.Label, 0.2, { TextColor3 = isActive and Color3.new(1, 1, 1) or TextDim })
        end
        activeTab = name
    end

    local function createSection(scroll, text)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 24)
        lbl.BackgroundTransparency = 1
        lbl.Text = "▸ " .. text
        lbl.TextColor3 = Accent
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = scroll
        return lbl
    end

    local function createToggle(scroll, text, initial, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 40)
        row.BackgroundColor3 = BgRow
        row.BorderSizePixel = 0
        row.Parent = scroll
        corner(row, 8)

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 3, 0, 16)
        indicator.Position = UDim2.new(0, 0, 0.5, -8)
        indicator.BackgroundColor3 = initial and Accent or Color3.fromRGB(60, 60, 70)
        indicator.BorderSizePixel = 0
        indicator.Parent = row
        corner(indicator, 2)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -80, 1, 0)
        lbl.Position = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = TextC
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local toggle = Instance.new("Frame")
        toggle.Size = UDim2.new(0, 42, 0, 22)
        toggle.Position = UDim2.new(1, -52, 0.5, -11)
        toggle.BackgroundColor3 = initial and Accent or Color3.fromRGB(55, 55, 70)
        toggle.Parent = row
        corner(toggle, 11)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = initial and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.Parent = toggle
        corner(knob, 8)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = row

        local state = initial
        btn.MouseEnter:Connect(function()
            tw(row, 0.15, { BackgroundColor3 = BgRowHover })
        end)
        btn.MouseLeave:Connect(function()
            tw(row, 0.15, { BackgroundColor3 = BgRow })
        end)
        btn.MouseButton1Click:Connect(function()
            state = not state
            local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            local targetColor = state and Accent or Color3.fromRGB(55, 55, 70)
            tw(knob, 0.15, { Position = targetPos })
            tw(toggle, 0.15, { BackgroundColor3 = targetColor })
            tw(indicator, 0.15, { BackgroundColor3 = state and Accent or Color3.fromRGB(60, 60, 70) })
            if callback then callback(state) end
        end)
    end

    local function createSlider(scroll, text, min, max, default, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 64)
        row.BackgroundColor3 = BgRow
        row.BorderSizePixel = 0
        row.Parent = scroll
        corner(row, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -90, 0, 24)
        lbl.Position = UDim2.new(0, 12, 0, 6)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = TextC
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local valueBox = Instance.new("TextBox")
        valueBox.Size = UDim2.new(0, 64, 0, 22)
        valueBox.Position = UDim2.new(1, -76, 0, 7)
        valueBox.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
        valueBox.Text = string.format("%.2f", default)
        valueBox.TextColor3 = Accent
        valueBox.Font = Enum.Font.GothamBold
        valueBox.TextSize = 12
        valueBox.Parent = row
        corner(valueBox, 6)
        stroke(valueBox, Accent, 1, 0.6)

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, -24, 0, 10)
        barBg.Position = UDim2.new(0, 12, 0, 40)
        barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        barBg.BorderSizePixel = 0
        barBg.Parent = row
        corner(barBg, 5)

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        barFill.BackgroundColor3 = Accent
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg
        corner(barFill, 5)
        gradient(barFill, AccentLight, Accent, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.ZIndex = 2
        knob.Parent = barBg
        corner(knob, 7)
        stroke(knob, Accent, 2, 0)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = barBg

        local dragging = false
        local function setValue(value)
            value = math.clamp(value, min, max)
            local rel = (value - min) / (max - min)
            barFill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, -7, 0.5, -7)
            valueBox.Text = string.format("%.2f", value)
            if callback then callback(value) end
            return value
        end

        local function updateFromInput(input)
            local relX = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
            setValue(min + relX * (max - min))
        end

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                updateFromInput(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromInput(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)

        valueBox.FocusLost:Connect(function()
            local num = tonumber(valueBox.Text)
            if num then setValue(num)
            else valueBox.Text = string.format("%.2f", min + ((barFill.Size.X.Scale) * (max - min))) end
        end)

        row.MouseEnter:Connect(function()
            tw(row, 0.15, { BackgroundColor3 = BgRowHover })
        end)
        row.MouseLeave:Connect(function()
            tw(row, 0.15, { BackgroundColor3 = BgRow })
        end)
    end

    local aimTab = createTab("AIM", "◎")
    createSection(aimTab.Scroll, "TARGETING")
    createToggle(aimTab.Scroll, "Enable Aimbot", Config.Aim.Enabled, function(v) Config.Aim.Enabled = v end)
    createToggle(aimTab.Scroll, "Head Only", Config.Aim.HeadOnly, function(v) Config.Aim.HeadOnly = v end)
    createToggle(aimTab.Scroll, "Visible Only", Config.Aim.VisibleOnly, function(v) Config.Aim.VisibleOnly = v end)
    createSection(aimTab.Scroll, "TUNING")
    createSlider(aimTab.Scroll, "FOV", 20, 500, Config.Aim.FOV, function(v) Config.Aim.FOV = v end)
    createSlider(aimTab.Scroll, "Smoothness", 0.01, 0.99, Config.Aim.Smoothness, function(v) Config.Aim.Smoothness = v end)
    createSlider(aimTab.Scroll, "Prediction", 0.0, 0.3, Config.Aim.Prediction, function(v) Config.Aim.Prediction = v end)

    local espTab = createTab("ESP", "◈")
    createSection(espTab.Scroll, "GENERAL")
    createToggle(espTab.Scroll, "Enable ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
    createToggle(espTab.Scroll, "Team Check", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)
    createSection(espTab.Scroll, "ELEMENTS")
    createToggle(espTab.Scroll, "Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
    createToggle(espTab.Scroll, "Name", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    createToggle(espTab.Scroll, "Health Bar", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    createToggle(espTab.Scroll, "Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
    createToggle(espTab.Scroll, "Tracer", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)
    createToggle(espTab.Scroll, "Skeleton", Config.ESP.Skeleton, function(v) Config.ESP.Skeleton = v end)
    createToggle(espTab.Scroll, "Head Dot", Config.ESP.HeadDot, function(v) Config.ESP.HeadDot = v end)
    createSection(espTab.Scroll, "RANGE")
    createSlider(espTab.Scroll, "Max Distance", 100, 3000, Config.ESP.MaxDistance, function(v) Config.ESP.MaxDistance = v end)

    local bypassTab = createTab("BYPASS", "⚙")
    createSection(bypassTab.Scroll, "MASTER")
    createToggle(bypassTab.Scroll, "Enable Bypass", Config.Bypass.Enabled, function(v) Bypass:Toggle(v) end)
    createSection(bypassTab.Scroll, "SPOOFING")
    createToggle(bypassTab.Scroll, "Spoof WalkSpeed", Config.Bypass.SpoofWalkSpeed, function(v)
        Config.Bypass.SpoofWalkSpeed = v
        Bypass:SpoofWalkSpeed(v, 100)
    end)
    createToggle(bypassTab.Scroll, "Spoof JumpPower", Config.Bypass.SpoofJumpPower, function(v)
        Config.Bypass.SpoofJumpPower = v
        Bypass:SpoofJumpPower(v, 100)
    end)
    createToggle(bypassTab.Scroll, "Spoof Gravity", Config.Bypass.SpoofGravity, function(v)
        Config.Bypass.SpoofGravity = v
        Bypass:SpoofGravity(v)
    end)
    createSection(bypassTab.Scroll, "PROTECTION")
    createToggle(bypassTab.Scroll, "Anti Kick", Config.Bypass.AntiKick, function(v) Config.Bypass.AntiKick = v end)
    createToggle(bypassTab.Scroll, "Anti Fling", Config.Bypass.AntiFling, function(v) Config.Bypass.AntiFling = v end)
    createToggle(bypassTab.Scroll, "Anti Void", Config.Bypass.AntiVoid, function(v) Config.Bypass.AntiVoid = v end)
    createToggle(bypassTab.Scroll, "Hide From Server", Config.Bypass.HideFromServer, function(v) Config.Bypass.HideFromServer = v end)

    local miscTab = createTab("MISC", "✦")
    createSection(miscTab.Scroll, "SECURITY")
    createToggle(miscTab.Scroll, "Enable Anti-Cheat", Config.AntiCheat.Enabled, function(v) Config.AntiCheat.Enabled = v end)

    local infoRow = Instance.new("Frame")
    infoRow.Size = UDim2.new(1, 0, 0, 50)
    infoRow.BackgroundColor3 = BgRow
    infoRow.BorderSizePixel = 0
    infoRow.Parent = miscTab.Scroll
    corner(infoRow, 8)

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, -24, 0, 20)
    infoLbl.Position = UDim2.new(0, 12, 0, 6)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = "👤 " .. LocalPlayer.Name
    infoLbl.TextColor3 = Accent
    infoLbl.Font = Enum.Font.GothamBold
    infoLbl.TextSize = 13
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.Parent = infoRow

    local infoSub = Instance.new("TextLabel")
    infoSub.Size = UDim2.new(1, -24, 0, 18)
    infoSub.Position = UDim2.new(0, 12, 0, 26)
    infoSub.BackgroundTransparency = 1
    infoSub.Text = "RMB = Aim | RightShift = Toggle"
    infoSub.TextColor3 = TextDim
    infoSub.Font = Enum.Font.GothamMedium
    infoSub.TextSize = 11
    infoSub.TextXAlignment = Enum.TextXAlignment.Left
    infoSub.Parent = infoRow

    activateTab("AIM")

    local isOpen = true
    local function openPanel()
        isOpen = true
        panel.Visible = true
        toggleBtn.Visible = false
        panel.Size = UDim2.new(0, 500, 0, 0)
        panel.BackgroundTransparency = 1
        tw(panel, 0.3, {
            Size = UDim2.new(0, 500, 0, 620),
            BackgroundTransparency = 0.05
        }, Enum.EasingStyle.Back)
    end

    local function minimizePanel()
        isOpen = false
        local t = tw(panel, 0.2, {
            Size = UDim2.new(0, 500, 0, 0),
            BackgroundTransparency = 1
        }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            panel.Visible = false
            toggleBtn.Visible = true
            toggleBtn.Size = UDim2.new(0, 0, 0, 0)
            toggleBtn.Position = UDim2.new(0, 24, 0.5, -22)
            tw(toggleBtn, 0.25, {
                Size = UDim2.new(0, 44, 0, 44)
            }, Enum.EasingStyle.Back)
        end)
    end

    local function togglePanel()
        if isOpen then minimizePanel() else openPanel() end
    end

    toggleBtn.MouseButton1Click:Connect(openPanel)
    closeBtn.MouseButton1Click:Connect(minimizePanel)
    minBtn.MouseButton1Click:Connect(minimizePanel)

    toggleBtn.MouseEnter:Connect(function()
        tw(toggleBtn, 0.15, { Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 21, 0.5, -25) })
        tw(toggleGlow, 0.15, { BackgroundTransparency = 0.5 })
    end)
    toggleBtn.MouseLeave:Connect(function()
        tw(toggleBtn, 0.15, { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 24, 0.5, -22) })
        tw(toggleGlow, 0.15, { BackgroundTransparency = 0.7 })
    end)

    closeBtn.MouseEnter:Connect(function() tw(closeBtn, 0.15, { BackgroundTransparency = 0.4 }) end)
    closeBtn.MouseLeave:Connect(function() tw(closeBtn, 0.15, { BackgroundTransparency = 0.75 }) end)
    minBtn.MouseEnter:Connect(function() tw(minBtn, 0.15, { BackgroundTransparency = 0.4 }) end)
    minBtn.MouseLeave:Connect(function() tw(minBtn, 0.15, { BackgroundTransparency = 0.75 }) end)

    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local tabOrder = {"AIM", "ESP", "BYPASS", "MISC"}
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            togglePanel()
        end
        local num = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
        if num >= 1 and num <= #tabOrder and panel.Visible then
            activateTab(tabOrder[num])
        end
    end)

    for name, tab in pairs(tabs) do
        tab.Button.MouseButton1Click:Connect(function()
            activateTab(name)
        end)
    end

    return gui
end

local ui = createUI()

if Config.Bypass.Enabled then
    Bypass:Init()
end

print("[CharlieKien] Loaded. RMB = Aim | RightShift = Menu | 1-4 = Tabs")
