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
        Enabled = true,
        FOV = 200,
        Smoothness = 0.01,
        MaxDistance = 5000,
        VisibleOnly = false,
        HeadOnly = true,
        Prediction = 0.15,
        HardLock = true,
        SwitchOnTurn = true,
        TurnThreshold = 250,
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
        AntiKick = true,
        AntiFling = true,
        AntiVoid = true,
        HideFromServer = true,
    },
    UI = {
        AccentColor = Color3.fromRGB(0, 150, 255),
        BgColor = Color3.fromRGB(15, 15, 20),
        TextColor = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
    }
}

local Connections = {}
local function addConn(conn) table.insert(Connections, conn) return conn end

local Bypass = {}

local function hasExecutor() return type(getgenv) == "table" end

local function antiKick()
    if not hasExecutor() then return end
    if type(hookfunction) ~= "function" then return end
    pcall(function() hookfunction(LocalPlayer.Kick, function() return end) end)
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
        if spawn then hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0) end
    end
end

function Bypass:Init()
    if self.InitDone then return end
    self.InitDone = true
    if Config.Bypass.AntiKick then antiKick() end
    if Config.Bypass.AntiFling then
        addConn(LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5) antiFling() end))
        antiFling()
    end
    if Config.Bypass.AntiVoid then addConn(RunService.Heartbeat:Connect(antiVoid)) end
    if Config.Bypass.HideFromServer and hasExecutor() and type(sethiddenproperty) == "function" then
        pcall(function()
            local char = LocalPlayer.Character
            if char then sethiddenproperty(char, "Archivable", false) end
        end)
    end
end

function Bypass:Toggle(enable)
    Config.Bypass.Enabled = enable
    if enable then self:Init() end
end

local Aimbot = {}
Aimbot.IsActive = false
Aimbot.CurrentTarget = nil
Aimbot.LockedTarget = nil
Aimbot.LastCameraDir = nil
Aimbot.SuppressedUntil = 0

local function getAlivePlayers()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then table.insert(list, plr) end
        end
    end
    return list
end

local function isTeam(plr)
    if not Config.ESP.TeamCheck then return false end
    return plr.Team == LocalPlayer.Team
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

local function getTargetPart(plr)
    local char = plr.Character
    if not char then return nil end
    if Config.Aim.HeadOnly then return char:FindFirstChild("Head") end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function isValidTarget(plr)
    if not plr or plr == LocalPlayer then return false end
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if isTeam(plr) then return false end
    local part = getTargetPart(plr)
    if not part then return false end
    local dist = (part.Position - Camera.CFrame.Position).Magnitude
    if dist > Config.Aim.MaxDistance then return false end
    if Config.Aim.VisibleOnly and not isVisible(part) then return false end
    return true
end

local function getAngleTo(part)
    local cameraPos = Camera.CFrame.Position
    local look = Camera.CFrame.LookVector
    local toTarget = (part.Position - cameraPos).Unit
    local dot = math.clamp(look:Dot(toTarget), -1, 1)
    return math.deg(math.acos(dot))
end

function Aimbot:FindBestTarget(excludePlr)
    local best, bestScore = nil, math.huge
    for _, plr in ipairs(getAlivePlayers()) do
        if plr ~= excludePlr and isValidTarget(plr) then
            local part = getTargetPart(plr)
            if part then
                local angle = getAngleTo(part)
                if angle <= Config.Aim.FOV then
                    local dist = (part.Position - Camera.CFrame.Position).Magnitude
                    local score = angle + dist * 0.001
                    if score < bestScore then
                        best = { Player = plr, Part = part }
                        bestScore = score
                    end
                end
            end
        end
    end
    return best
end

function Aimbot:CheckCameraTurn()
    if not Config.Aim.SwitchOnTurn or not self.LockedTarget then return end
    local now = tick()
    if now < self.SuppressedUntil then return end

    local currentDir = Camera.CFrame.LookVector
    if self.LastCameraDir then
        local delta = (currentDir - self.LastCameraDir).Magnitude
        if delta * 1000 > Config.Aim.TurnThreshold then
            local oldTarget = self.LockedTarget
            self.LockedTarget = nil
            self.CurrentTarget = nil
            self.SuppressedUntil = now + 0.15
            task.spawn(function()
                task.wait(0.05)
                local newTarget = self:FindBestTarget(oldTarget.Player)
                if newTarget and isValidTarget(newTarget.Player) then
                    self.LockedTarget = newTarget
                    self.CurrentTarget = newTarget
                end
            end)
        end
    end
    self.LastCameraDir = currentDir
end

function Aimbot:Update()
    if not Config.Aim.Enabled or not self.IsActive then
        self.CurrentTarget = nil
        self.LockedTarget = nil
        self.LastCameraDir = nil
        return
    end

    self:CheckCameraTurn()

    if self.LockedTarget and not isValidTarget(self.LockedTarget.Player) then
        self.LockedTarget = nil
        self.CurrentTarget = nil
    end

    if not self.LockedTarget then
        local newTarget = self:FindBestTarget()
        if newTarget then
            self.LockedTarget = newTarget
        else
            self.CurrentTarget = nil
            return
        end
    end

    local target = self.LockedTarget
    self.CurrentTarget = target
    local targetPart = getTargetPart(target.Player)
    if not targetPart then
        self.LockedTarget = nil
        self.CurrentTarget = nil
        return
    end
    target.Part = targetPart

    local targetPos = targetPart.Position
    if Config.Aim.Prediction > 0 then
        targetPos = targetPos + targetPart.AssemblyLinearVelocity * Config.Aim.Prediction
    end

    local currentCF = Camera.CFrame
    local desiredCF = CFrame.new(currentCF.Position, targetPos)
    if Config.Aim.HardLock then
        Camera.CFrame = desiredCF
    else
        local alpha = 1 - math.clamp(Config.Aim.Smoothness, 0.01, 0.99)
        Camera.CFrame = currentCF:Lerp(desiredCF, alpha)
    end

    self.LastCameraDir = Camera.CFrame.LookVector
end

addConn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aimbot.IsActive = true
        Aimbot.LockedTarget = nil
        Aimbot.SuppressedUntil = 0
    end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aimbot.IsActive = false
        Aimbot.CurrentTarget = nil
        Aimbot.LockedTarget = nil
        Aimbot.LastCameraDir = nil
    end
end))

addConn(RunService.RenderStepped:Connect(function() Aimbot:Update() end))

local ESP = {}
ESP.Objects = {}
ESP.SkeletonBones = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
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
            for _, line in ipairs(v) do if line then line.Visible = false end end
        elseif v and v.Remove then v.Visible = false end
    end
end

local function removeESP(plr)
    local obj = ESP.Objects[plr]
    if not obj then return end
    for k, v in pairs(obj) do
        if type(v) == "table" then
            for _, line in ipairs(v) do if line then line:Remove() end end
        elseif v and v.Remove then v:Remove() end
    end
    ESP.Objects[plr] = nil
end

local function updateESP(plr)
    local obj = ESP.Objects[plr]
    if not obj then return end
    if not Config.ESP.Enabled or not plr.Character then hideESP(obj) return end
    local char = plr.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then hideESP(obj) return end
    local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
    if dist > Config.ESP.MaxDistance then hideESP(obj) return end
    local color = Config.ESP.Color
    if Config.ESP.TeamCheck and not isTeam(plr) then color = Config.ESP.EnemyColor end
    
    local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    local hrpScreen = Vector2.new(sp.X, sp.Y)

    if Config.ESP.Box and onScreen then
        local topV, _ = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
        local bottomV, _ = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
        local top = Vector2.new(topV.X, topV.Y)
        local bottom = Vector2.new(bottomV.X, bottomV.Y)
        local h = math.abs(bottom.Y - top.Y)
        local w = h * 0.55
        obj.Box.Visible = true
        obj.Box.Color = color
        obj.Box.Size = Vector2.new(w, h)
        obj.Box.Position = Vector2.new(top.X - w / 2, top.Y)
    else
        obj.Box.Visible = false
    end

    if Config.ESP.Name and onScreen then
        obj.Name.Visible = true
        obj.Name.Text = plr.Name
        obj.Name.Position = Vector2.new(hrpScreen.X, hrpScreen.Y - 25)
        obj.Name.Color = color
    else
        obj.Name.Visible = false
    end

    if Config.ESP.Distance and onScreen then
        obj.Distance.Visible = true
        obj.Distance.Text = math.floor(dist) .. "m"
        obj.Distance.Position = Vector2.new(hrpScreen.X, hrpScreen.Y + 20)
    else
        obj.Distance.Visible = false
    end

    if Config.ESP.Health and onScreen then
        local h = hum.Health / hum.MaxHealth
        local topV, _ = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
        local bottomV, _ = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
        local top = Vector2.new(topV.X, topV.Y)
        local bottom = Vector2.new(bottomV.X, bottomV.Y)
        local barH = math.abs(bottom.Y - top.Y)
        local barX = top.X - 40
        obj.HealthBg.Visible = true
        obj.HealthBg.Size = Vector2.new(3, barH)
        obj.HealthBg.Position = Vector2.new(barX, top.Y)
        obj.HealthBar.Visible = true
        obj.HealthBar.Size = Vector2.new(3, barH * h)
        obj.HealthBar.Position = Vector2.new(barX, top.Y + barH * (1 - h))
        obj.HealthBar.Color = Color3.fromRGB(math.floor(255 * (1 - h)), math.floor(255 * h), 0)
    else
        obj.HealthBar.Visible = false
        obj.HealthBg.Visible = false
    end

    if Config.ESP.Tracer and onScreen then
        obj.Tracer.Visible = true
        obj.Tracer.Color = color
        obj.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        obj.Tracer.To = hrpScreen
    else
        obj.Tracer.Visible = false
    end

    if Config.ESP.HeadDot and onScreen then
        local head = char:FindFirstChild("Head")
        if head then
            local hs, hOnScreen = Camera:WorldToViewportPoint(head.Position)
            if hOnScreen then
                obj.HeadDot.Visible = true
                obj.HeadDot.Color = color
                obj.HeadDot.Position = Vector2.new(hs.X, hs.Y)
            else
                obj.HeadDot.Visible = false
            end
        else
            obj.HeadDot.Visible = false
        end
    else
        obj.HeadDot.Visible = false
    end

    if Config.ESP.Skeleton and onScreen then
        for i, bone in ipairs(ESP.SkeletonBones) do
            local p1 = char:FindFirstChild(bone[1])
            local p2 = char:FindFirstChild(bone[2])
            local line = obj.Skeleton[i]
            if p1 and p2 and line then
                local s1, on1 = Camera:WorldToViewportPoint(p1.Position)
                local s2, on2 = Camera:WorldToViewportPoint(p2.Position)
                if on1 and on2 then
                    line.Visible = true
                    line.Color = color
                    line.From = Vector2.new(s1.X, s1.Y)
                    line.To = Vector2.new(s2.X, s2.Y)
                else
                    line.Visible = false
                end
            elseif line then
                line.Visible = false
            end
        end
    else
        for _, line in ipairs(obj.Skeleton) do if line then line.Visible = false end end
    end
end

addConn(Players.PlayerAdded:Connect(function(plr) if plr ~= LocalPlayer then newESP(plr) end end))
addConn(Players.PlayerRemoving:Connect(function(plr) removeESP(plr) end))
addConn(RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and ESP.Objects[plr] then updateESP(plr) end
    end
end))
for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then newESP(plr) end end

local AntiCheat = { LastPosition = nil, LastCheckTime = tick(), Violations = 0 }
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
        s.Color = color or Color3.fromRGB(60, 60, 60)
        s.Thickness = thickness or 1
        s.Transparency = transparency or 0
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end

    local Accent = Config.UI.AccentColor
    local BgDark = Color3.fromRGB(20, 20, 20)
    local BgPanel = Color3.fromRGB(30, 30, 30)
    local BgRow = Color3.fromRGB(35, 35, 35)
    local TextC = Config.UI.TextColor
    local TextDim = Color3.fromRGB(180, 180, 180)

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
    toggleBtn.Text = "C"
    toggleBtn.TextColor3 = Accent
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 20
    toggleBtn.AutoButtonColor = false
    toggleBtn.Visible = false
    toggleBtn.Parent = gui
    corner(toggleBtn, 22)
    stroke(toggleBtn, Accent, 1.5, 0.3)

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 340, 0, 560)
    panel.Position = UDim2.new(0.5, -170, 0.5, -280)
    panel.BackgroundColor3 = BgDark
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = gui
    panel.Visible = true
    corner(panel, 16)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundTransparency = 1
    header.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "CharlieKien"
    title.TextColor3 = TextC
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -76, 0.5, -15)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "−"
    minBtn.TextColor3 = TextDim
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 20
    minBtn.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -42, 0.5, -15)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = header

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -24, 0, 40)
    tabBar.Position = UDim2.new(0, 12, 0, 60)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = panel

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Parent = tabBar

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -24, 1, -116)
    contentFrame.Position = UDim2.new(0, 12, 0, 110)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = panel

    local tabs = {}
    local activeTab = nil

    local function createScroll(parent)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 2
        scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Parent = parent
        local l = Instance.new("UIListLayout")
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Padding = UDim.new(0, 8)
        l.Parent = scroll
        local p = Instance.new("UIPadding")
        p.PaddingRight = UDim.new(0, 6)
        p.PaddingBottom = UDim.new(0, 10)
        p.Parent = scroll
        return scroll
    end

    local function createTab(name, iconStr)
        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(0, 96, 0, 36)
        tabBtn.BackgroundColor3 = BgPanel
        tabBtn.Text = ""
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = tabBar
        corner(tabBtn, 18)
        local s = stroke(tabBtn, Color3.fromRGB(60, 60, 60), 1, 0.5)

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 20, 1, 0)
        icon.Position = UDim2.new(0, 8, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Text = iconStr
        icon.TextColor3 = TextDim
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 14
        icon.Parent = tabBtn

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -30, 1, 0)
        lbl.Position = UDim2.new(0, 28, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = TextDim
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = tabBtn

        local scroll = createScroll(contentFrame)
        scroll.Visible = false

        tabs[name] = { Button = tabBtn, Scroll = scroll, Icon = icon, Label = lbl, Stroke = s }
    end

    local function activateTab(name)
        for tName, tab in pairs(tabs) do
            local isActive = tName == name
            tab.Scroll.Visible = isActive
            if isActive then
                tw(tab.Button, 0.2, { BackgroundColor3 = Color3.fromRGB(240, 240, 240) })
                tab.Stroke.Transparency = 1
                tw(tab.Icon, 0.2, { TextColor3 = Color3.fromRGB(20, 20, 20) })
                tw(tab.Label, 0.2, { TextColor3 = Color3.fromRGB(20, 20, 20) })
            else
                tw(tab.Button, 0.2, { BackgroundColor3 = BgPanel })
                tab.Stroke.Transparency = 0.5
                tw(tab.Icon, 0.2, { TextColor3 = TextDim })
                tw(tab.Label, 0.2, { TextColor3 = TextDim })
            end
        end
    end

    local function createToggle(scroll, text, initial, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 48)
        row.BackgroundColor3 = BgRow
        row.BorderSizePixel = 0
        row.Parent = scroll
        corner(row, 12)
        stroke(row, Color3.fromRGB(60, 60, 60), 1, 0.3)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -80, 1, 0)
        lbl.Position = UDim2.new(0, 16, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = TextC
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local toggle = Instance.new("Frame")
        toggle.Size = UDim2.new(0, 44, 0, 24)
        toggle.Position = UDim2.new(1, -60, 0.5, -12)
        toggle.BackgroundColor3 = initial and Accent or Color3.fromRGB(50, 50, 50)
        toggle.Parent = row
        corner(toggle, 12)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = initial and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.Parent = toggle
        corner(knob, 9)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = row

        local state = initial
        btn.MouseButton1Click:Connect(function()
            state = not state
            local targetPos = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
            local targetColor = state and Accent or Color3.fromRGB(50, 50, 50)
            tw(knob, 0.15, { Position = targetPos })
            tw(toggle, 0.15, { BackgroundColor3 = targetColor })
            if callback then callback(state) end
        end)
    end

    local function createSlider(scroll, text, min, max, default, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 54)
        row.BackgroundColor3 = BgRow
        row.BorderSizePixel = 0
        row.Parent = scroll
        corner(row, 12)
        stroke(row, Color3.fromRGB(60, 60, 60), 1, 0.3)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -100, 1, 0)
        lbl.Position = UDim2.new(0, 16, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = TextC
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(0, 140, 0, 36)
        barBg.Position = UDim2.new(1, -156, 0.5, -18)
        barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        barBg.Parent = row
        corner(barBg, 18)
        stroke(barBg, Color3.fromRGB(70, 70, 70), 1, 0.5)

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        barFill.BackgroundColor3 = Accent
        barFill.Parent = barBg
        corner(barFill, 18)

        local valueLbl = Instance.new("TextLabel")
        valueLbl.Size = UDim2.new(0, 40, 1, 0)
        valueLbl.Position = UDim2.new(0, 12, 0, 0)
        valueLbl.BackgroundTransparency = 1
        valueLbl.Text = tostring(default)
        valueLbl.TextColor3 = Color3.new(1, 1, 1)
        valueLbl.Font = Enum.Font.GothamBold
        valueLbl.TextSize = 13
        valueLbl.TextXAlignment = Enum.TextXAlignment.Left
        valueLbl.Parent = barBg

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
            valueLbl.Text = string.format("%.2f", value)
            if text:find("FPS") then valueLbl.Text = tostring(math.floor(value)) end
            if callback then callback(value) end
        end

        local function updateFromInput(input)
            local relX = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
            setValue(min + relX * (max - min))
        end

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromInput(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromInput(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    createTab("ESP", "◈")
    createTab("Aimbot", "◎")
    createTab("Misc", "⚙")

    local espScroll = tabs["ESP"].Scroll
    createToggle(espScroll, "Bật ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
    createToggle(espScroll, "Hiện Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
    createToggle(espScroll, "Hiện Tên", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    createToggle(espScroll, "Máu", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    createToggle(espScroll, "Khoảng cách", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
    createToggle(espScroll, "Team check", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)
    createSlider(espScroll, "Khoảng cách tối đa", 100, 3000, Config.ESP.MaxDistance, function(v) Config.ESP.MaxDistance = v end)

    local aimScroll = tabs["Aimbot"].Scroll
    createToggle(aimScroll, "Bật Aimbot", Config.Aim.Enabled, function(v) Config.Aim.Enabled = v end)
    createToggle(aimScroll, "Wall check", Config.Aim.VisibleOnly, function(v) Config.Aim.VisibleOnly = v end)
    createToggle(aimScroll, "Team check", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)
    createToggle(aimScroll, "Tự chuyển khi xoay", Config.Aim.SwitchOnTurn, function(v) Config.Aim.SwitchOnTurn = v end)
    createSlider(aimScroll, "Tốc độ quét mục tiêu (FPS)", 10, 120, 55, function(v) end)
    createSlider(aimScroll, "Khoảng cách tối đa (m)", 100, 10000, Config.Aim.MaxDistance, function(v) Config.Aim.MaxDistance = v end)
    createSlider(aimScroll, "Vùng FOV", 20, 800, Config.Aim.FOV, function(v) Config.Aim.FOV = v end)

    local miscScroll = tabs["Misc"].Scroll
    createToggle(miscScroll, "Chống Kick", Config.Bypass.AntiKick, function(v) Config.Bypass.AntiKick = v end)
    createToggle(miscScroll, "Chống Fling", Config.Bypass.AntiFling, function(v) Config.Bypass.AntiFling = v end)
    createToggle(miscScroll, "Chống rơi (Void)", Config.Bypass.AntiVoid, function(v) Config.Bypass.AntiVoid = v end)
    createToggle(miscScroll, "Ẩn khỏi Server", Config.Bypass.HideFromServer, function(v) Config.Bypass.HideFromServer = v end)
    createToggle(miscScroll, "Anti-Cheat Nội bộ", Config.AntiCheat.Enabled, function(v) Config.AntiCheat.Enabled = v end)

    activateTab("Aimbot")

    local isOpen = true
    local function openPanel()
        isOpen = true
        panel.Visible = true
        toggleBtn.Visible = false
        panel.Size = UDim2.new(0, 340, 0, 0)
        tw(panel, 0.3, { Size = UDim2.new(0, 340, 0, 560) }, Enum.EasingStyle.Back)
    end

    local function minimizePanel()
        isOpen = false
        local t = tw(panel, 0.2, { Size = UDim2.new(0, 340, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            panel.Visible = false
            toggleBtn.Visible = true
            toggleBtn.Size = UDim2.new(0, 0, 0, 0)
            tw(toggleBtn, 0.25, { Size = UDim2.new(0, 44, 0, 44) }, Enum.EasingStyle.Back)
        end)
    end

    toggleBtn.MouseButton1Click:Connect(openPanel)
    closeBtn.MouseButton1Click:Connect(minimizePanel)
    minBtn.MouseButton1Click:Connect(minimizePanel)

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
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    for name, tab in pairs(tabs) do
        tab.Button.MouseButton1Click:Connect(function() activateTab(name) end)
    end

    return gui
end

local ui = createUI()
if Config.Bypass.Enabled then Bypass:Init() end
