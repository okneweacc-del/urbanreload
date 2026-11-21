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

    local gui = Instance.new("ScreenGui")
    gui.Name = "CharlieKienMenu"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(0, 48, 0, 48)
    toggleBtn.Position = UDim2.new(0, 20, 0.5, -24)
    toggleBtn.BackgroundColor3 = Config.UI.AccentColor
    toggleBtn.Text = "CK"
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 20
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = gui
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 12)

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 340, 0, 560)
    panel.Position = UDim2.new(0, 20, 0.5, -280)
    panel.BackgroundColor3 = Config.UI.BgColor
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.UI.AccentColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = panel

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = Config.UI.AccentColor
    header.BackgroundTransparency = 0.15
    header.Parent = panel
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 20)
    headerFix.Position = UDim2.new(0, 0, 1, -20)
    headerFix.BackgroundColor3 = header.BackgroundColor3
    headerFix.BackgroundTransparency = header.BackgroundTransparency
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡ CharlieKien"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Config.UI.Font
    title.TextSize = 17
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -38, 0, 7)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -24, 1, -60)
    scroll.Position = UDim2.new(0, 12, 0, 52)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Config.UI.AccentColor
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = scroll

    local function section(text)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 22)
        lbl.BackgroundTransparency = 1
        lbl.Text = "─ " .. text .. " ─"
        lbl.TextColor3 = Config.UI.AccentColor
        lbl.Font = Config.UI.Font
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = scroll
    end

    local function createToggle(text, initial, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        row.BorderSizePixel = 0
        row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -70, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Config.UI.TextColor
        lbl.Font = Config.UI.Font
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local toggle = Instance.new("Frame")
        toggle.Size = UDim2.new(0, 44, 0, 22)
        toggle.Position = UDim2.new(1, -54, 0.5, -11)
        toggle.BackgroundColor3 = initial and Config.UI.AccentColor or Color3.fromRGB(60, 60, 70)
        toggle.Parent = row
        Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = initial and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.Parent = toggle
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = toggle

        local state = initial
        btn.MouseButton1Click:Connect(function()
            state = not state
            local targetPos = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
            local targetColor = state and Config.UI.AccentColor or Color3.fromRGB(60, 60, 70)
            TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
            TweenService:Create(toggle, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
            if callback then callback(state) end
        end)
    end

    local function createSlider(text, min, max, default, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 58)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        row.BorderSizePixel = 0
        row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -24, 0, 24)
        lbl.Position = UDim2.new(0, 12, 0, 6)
        lbl.BackgroundTransparency = 1
        lbl.Text = text .. ": " .. string.format("%.2f", default)
        lbl.TextColor3 = Config.UI.TextColor
        lbl.Font = Config.UI.Font
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, -24, 0, 8)
        barBg.Position = UDim2.new(0, 12, 0, 38)
        barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        barBg.Parent = row
        Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        barFill.BackgroundColor3 = Config.UI.AccentColor
        barFill.Parent = barBg
        Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = barBg

        local dragging = false
        local function update(input)
            local relX = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
            local value = min + relX * (max - min)
            barFill.Size = UDim2.new(relX, 0, 1, 0)
            lbl.Text = text .. ": " .. string.format("%.2f", value)
            if callback then callback(value) end
        end

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                update(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                update(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end

    section("AIM")
    createToggle("Enable Aimbot", Config.Aim.Enabled, function(v) Config.Aim.Enabled = v end)
    createToggle("Head Only", Config.Aim.HeadOnly, function(v) Config.Aim.HeadOnly = v end)
    createToggle("Visible Only", Config.Aim.VisibleOnly, function(v) Config.Aim.VisibleOnly = v end)
    createSlider("FOV", 20, 500, Config.Aim.FOV, function(v) Config.Aim.FOV = v end)
    createSlider("Smoothness", 0.01, 0.99, Config.Aim.Smoothness, function(v) Config.Aim.Smoothness = v end)
    createSlider("Prediction", 0.0, 0.3, Config.Aim.Prediction, function(v) Config.Aim.Prediction = v end)

    section("ESP")
    createToggle("Enable ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
    createToggle("Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
    createToggle("Name", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    createToggle("Health Bar", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    createToggle("Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
    createToggle("Tracer", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)
    createToggle("Skeleton", Config.ESP.Skeleton, function(v) Config.ESP.Skeleton = v end)
    createToggle("Head Dot", Config.ESP.HeadDot, function(v) Config.ESP.HeadDot = v end)
    createToggle("Team Check", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)
    createSlider("ESP Max Dist", 100, 3000, Config.ESP.MaxDistance, function(v) Config.ESP.MaxDistance = v end)

    section("BYPASS")
    createToggle("Enable Bypass", Config.Bypass.Enabled, function(v) Bypass:Toggle(v) end)
    createToggle("Spoof WalkSpeed", Config.Bypass.SpoofWalkSpeed, function(v)
        Config.Bypass.SpoofWalkSpeed = v
        Bypass:SpoofWalkSpeed(v, 100)
    end)
    createToggle("Spoof JumpPower", Config.Bypass.SpoofJumpPower, function(v)
        Config.Bypass.SpoofJumpPower = v
        Bypass:SpoofJumpPower(v, 100)
    end)
    createToggle("Spoof Gravity", Config.Bypass.SpoofGravity, function(v)
        Config.Bypass.SpoofGravity = v
        Bypass:SpoofGravity(v)
    end)
    createToggle("Anti Kick", Config.Bypass.AntiKick, function(v) Config.Bypass.AntiKick = v end)
    createToggle("Anti Fling", Config.Bypass.AntiFling, function(v) Config.Bypass.AntiFling = v end)
    createToggle("Anti Void", Config.Bypass.AntiVoid, function(v) Config.Bypass.AntiVoid = v end)
    createToggle("Hide From Server", Config.Bypass.HideFromServer, function(v) Config.Bypass.HideFromServer = v end)

    section("ANTI-CHEAT")
    createToggle("Enable Anti-Cheat", Config.AntiCheat.Enabled, function(v) Config.AntiCheat.Enabled = v end)

    section("UI")
    createToggle("Show Menu", Config.UI.Visible, function(v)
        Config.UI.Visible = v
        toggleBtn.Visible = v
        if not v then panel.Visible = false end
    end)

    local isOpen = false
    local function togglePanel()
        isOpen = not isOpen
        if isOpen then
            panel.Visible = true
            panel.Size = UDim2.new(0, 340, 0, 0)
            panel.BackgroundTransparency = 1
            TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 340, 0, 560),
                BackgroundTransparency = 0
            }):Play()
        else
            local tween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 340, 0, 0),
                BackgroundTransparency = 1
            })
            tween:Play()
            tween.Completed:Connect(function() panel.Visible = false end)
        end
    end

    toggleBtn.MouseButton1Click:Connect(togglePanel)
    closeBtn.MouseButton1Click:Connect(togglePanel)

    toggleBtn.MouseEnter:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.15), {Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(0, 17, 0.5, -27)}):Play()
    end)
    toggleBtn.MouseLeave:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.15), {Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(0, 20, 0.5, -24)}):Play()
    end)

    panel.Visible = false
    return gui
end

local ui = createUI()

if Config.Bypass.Enabled then
    Bypass:Init()
end

print("[CharlieKien] Loaded. RMB = Aim | Menu = CharlieKien")