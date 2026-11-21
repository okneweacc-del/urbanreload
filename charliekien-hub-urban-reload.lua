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
        FOV = 150,
        Smoothness = 0.15, -- 0.1 là cứng, 1.0 là mượt
        MaxDistance = 5000,
        VisibleOnly = false,
        HeadOnly = true,
        TeamCheck = false,
        HardLock = true,
    },
    ESP = {
        Enabled = false,
        Box = true,
        Name = true,
        Health = true,
        Distance = true,
        Skeleton = false,
        MaxDistance = 1000,
        Color = Color3.fromRGB(0, 200, 255),
        EnemyColor = Color3.fromRGB(255, 60, 60),
    },
    Bypass = {
        Enabled = true,
        AntiKick = true,
        AntiFling = true,
        AntiVoid = true,
    }
}

local function addConn(conn) return conn end

local Aimbot = {}
Aimbot.IsActive = false
Aimbot.Target = nil

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
    if not Config.Aim.TeamCheck then return false end
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
    return result.Instance == targetPart or result.Instance:IsDescendantOf(targetPart.Parent)
end

local function getTargetPart(plr)
    local char = plr.Character
    if not char then return nil end
    if Config.Aim.HeadOnly then return char:FindFirstChild("Head") end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getClosestTarget()
    local best, bestDist = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(getAlivePlayers()) do
        if not isTeam(plr) then
            local part = getTargetPart(plr)
            if part then
                local dist = (part.Position - Camera.CFrame.Position).Magnitude
                if dist <= Config.Aim.MaxDistance then
                    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen or Config.Aim.VisibleOnly == false then
                        local screenPos = Vector2.new(sp.X, sp.Y)
                        if (screenPos - center).Magnitude <= Config.Aim.FOV then
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
    end
    return best
end

-- FIX AIM LÕI: Dùng MouseMove nếu có, không thì dùng Camera CFrame
local function aimAt(targetPos)
    local currentCF = Camera.CFrame
    local desiredCF = CFrame.new(currentCF.Position, targetPos)
    
    if Config.Aim.HardLock then
        Camera.CFrame = desiredCF
    else
        Camera.CFrame = currentCF:Lerp(desiredCF, 1 - Config.Aim.Smoothness)
    end
end

addConn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aimbot.IsActive = true
        Aimbot.Target = nil
    end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aimbot.IsActive = false
        Aimbot.Target = nil
    end
end))

addConn(RunService.RenderStepped:Connect(function()
    if not Config.Aim.Enabled or not Aimbot.IsActive then return end
    
    if not Aimbot.Target or not Aimbot.Target.Part or not Aimbot.Target.Part.Parent then
        Aimbot.Target = getClosestTarget()
    else
        -- Cập nhật vị trí mới của mục tiêu (nếu nó di chuyển)
        local part = getTargetPart(Aimbot.Target.Player)
        if part then
            Aimbot.Target.Part = part
        else
            Aimbot.Target = getClosestTarget()
        end
    end
    
    if Aimbot.Target and Aimbot.Target.Part then
        aimAt(Aimbot.Target.Part.Position)
    end
end))

local ESP = {}
ESP.Objects = {}
ESP.Bones = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}
}

local function draw(class, props)
    local ok, obj = pcall(function() return Drawing.new(class) end)
    if not ok then return nil end
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

local function addESP(plr)
    local obj = {
        Box = draw("Square", {Thickness = 1, Filled = false}),
        Name = draw("Text", {Size = 14, Center = true, Outline = true, Font = 2}),
        Dist = draw("Text", {Size = 12, Center = true, Outline = true, Font = 2}),
        Health = draw("Square", {Thickness = 1, Filled = true}),
        HealthBg = draw("Square", {Thickness = 1, Filled = true, Color = Color3.new(0.2,0.2,0.2)}),
        Skeleton = {}
    }
    for i = 1, #ESP.Bones do obj.Skeleton[i] = draw("Line", {Thickness = 1}) end
    ESP.Objects[plr] = obj
end

local function removeESP(plr)
    local obj = ESP.Objects[plr]
    if not obj then return end
    for _, v in pairs(obj) do
        if type(v) == "table" then for _, line in ipairs(v) do if line then line:Remove() end end
        elseif v and v.Remove then v:Remove() end
    end
    ESP.Objects[plr] = nil
end

local function updateESP(plr)
    local obj = ESP.Objects[plr]
    if not obj then return end
    if not Config.ESP.Enabled or not plr.Character then
        for _, v in pairs(obj) do
            if type(v) == "table" then for _, line in ipairs(v) do if line then line.Visible = false end end
            elseif v and v.Visible ~= nil then v.Visible = false end
        end
        return
    end
    local char = plr.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end
    local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
    if dist > Config.ESP.MaxDistance then
        for _, v in pairs(obj) do
            if type(v) == "table" then for _, line in ipairs(v) do if line then line.Visible = false end end
            elseif v and v.Visible ~= nil then v.Visible = false end
        end
        return
    end
    
    local color = Config.ESP.Color
    if isTeam(plr) then color = Config.ESP.EnemyColor end
    local sp, on = Camera:WorldToViewportPoint(hrp.Position)
    local spH, onH = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
    local spL, onL = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

    if Config.ESP.Box and on and onH and onL then
        local h = math.abs(spL.Y - spH.Y)
        local w = h * 0.5
        obj.Box.Visible = true
        obj.Box.Color = color
        obj.Box.Size = Vector2.new(w, h)
        obj.Box.Position = Vector2.new(spH.X - w/2, spH.Y)
    else
        obj.Box.Visible = false
    end

    if Config.ESP.Name and on then
        obj.Name.Visible = true
        obj.Name.Text = plr.Name
        obj.Name.Position = Vector2.new(sp.X, sp.Y - 30)
        obj.Name.Color = color
    else
        obj.Name.Visible = false
    end

    if Config.ESP.Distance and on then
        obj.Dist.Visible = true
        obj.Dist.Text = math.floor(dist) .. "m"
        obj.Dist.Position = Vector2.new(sp.X, sp.Y + 20)
        obj.Dist.Color = Color3.new(1,1,1)
    else
        obj.Dist.Visible = false
    end

    if Config.ESP.Health and on and onH and onL then
        local h = hum.Health / hum.MaxHealth
        local bh = math.abs(spL.Y - spH.Y)
        obj.HealthBg.Visible = true
        obj.HealthBg.Size = Vector2.new(3, bh)
        obj.HealthBg.Position = Vector2.new(spH.X - 35, spH.Y)
        obj.Health.Visible = true
        obj.Health.Size = Vector2.new(3, bh * h)
        obj.Health.Position = Vector2.new(spH.X - 35, spH.Y + bh * (1 - h))
        obj.Health.Color = Color3.fromRGB(255 * (1-h), 255 * h, 0)
    else
        obj.Health.Visible = false
        obj.HealthBg.Visible = false
    end

    if Config.ESP.Skeleton and on then
        for i, bone in ipairs(ESP.Bones) do
            local p1 = char:FindFirstChild(bone[1])
            local p2 = char:FindFirstChild(bone[2])
            local line = obj.Skeleton[i]
            if p1 and p2 and line then
                local s1, o1 = Camera:WorldToViewportPoint(p1.Position)
                local s2, o2 = Camera:WorldToViewportPoint(p2.Position)
                if o1 and o2 then
                    line.Visible = true
                    line.Color = color
                    line.From = Vector2.new(s1.X, s1.Y)
                    line.To = Vector2.new(s2.X, s2.Y)
                else
                    line.Visible = false
                end
            end
        end
    else
        for _, line in ipairs(obj.Skeleton) do line.Visible = false end
    end
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then addESP(p) end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then addESP(p) end end)
Players.PlayerRemoving:Connect(function(p) removeESP(p) end)
RunService.RenderStepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then updateESP(p) end
    end
end)

-- ==========================================
-- UI MỚI: HÌNH CHỮ NHẬT BO GÓC CHUẨN MOBILE
-- ==========================================
local function createUI()
    local old = CoreGui:FindFirstChild("CharlieKienMenu")
    if old then old:Destroy() end

    local function tw(obj, t, props, style)
        local ti = TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad)
        local tween = TweenService:Create(obj, ti, props)
        tween:Play()
        return tween
    end

    local function corner(parent, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 8)
        c.Parent = parent
        return c
    end

    local function stroke(parent, color, thick, trans)
        local s = Instance.new("UIStroke")
        s.Color = color or Color3.fromRGB(60, 60, 60)
        s.Thickness = thick or 1
        s.Transparency = trans or 0.5
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end

    local Accent = Color3.fromRGB(0, 150, 255)
    local BgDark = Color3.fromRGB(25, 25, 25)
    local BgRow = Color3.fromRGB(40, 40, 40)
    local TextC = Color3.fromRGB(255, 255, 255)
    local TextDim = Color3.fromRGB(170, 170, 170)

    local gui = Instance.new("ScreenGui")
    gui.Name = "CharlieKienMenu"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = CoreGui

    -- Nút thu nhỏ (C)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 44, 0, 44)
    toggleBtn.Position = UDim2.new(0, 24, 0.5, -22)
    toggleBtn.BackgroundColor3 = BgDark
    toggleBtn.Text = "C"
    toggleBtn.TextColor3 = Accent
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 20
    toggleBtn.Visible = false
    toggleBtn.Parent = gui
    corner(toggleBtn, 22)
    stroke(toggleBtn, Accent, 1.5, 0.2)

    -- Panel chính
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 340, 0, 500) -- Nhỏ gọn như ảnh
    panel.Position = UDim2.new(0.5, -170, 0.5, -250)
    panel.BackgroundColor3 = BgDark
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = gui
    panel.Visible = true
    corner(panel, 12)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
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

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = TextC
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = header

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -75, 0.5, -15)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "−"
    minBtn.TextColor3 = TextC
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 20
    minBtn.Parent = header

    -- Thanh Tabs
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -24, 0, 40)
    tabBar.Position = UDim2.new(0, 12, 0, 50)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = panel

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Parent = tabBar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -24, 1, -106)
    content.Position = UDim2.new(0, 12, 0, 98)
    content.BackgroundTransparency = 1
    content.Parent = panel

    local tabs = {}

    local function createScroll(parent)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 2
        scroll.ScrollBarImageColor3 = Accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Parent = parent
        local l = Instance.new("UIListLayout")
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Padding = UDim.new(0, 6)
        l.Parent = scroll
        local p = Instance.new("UIPadding")
        p.PaddingRight = UDim.new(0, 4)
        p.PaddingBottom = UDim.new(0, 10)
        p.Parent = scroll
        return scroll
    end

    local function createTab(name, iconStr)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 0, 34)
        btn.BackgroundColor3 = BgRow
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = tabBar
        corner(btn, 17)
        local s = stroke(btn, Color3.fromRGB(60,60,60), 1, 0.5)

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 20, 1, 0)
        icon.Position = UDim2.new(0, 8, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Text = iconStr
        icon.TextColor3 = TextDim
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 14
        icon.Parent = btn

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -30, 1, 0)
        lbl.Position = UDim2.new(0, 28, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = TextDim
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = btn

        local scroll = createScroll(content)
        scroll.Visible = false
        tabs[name] = { Btn = btn, Scroll = scroll, Icon = icon, Lbl = lbl, Stroke = s }
    end

    local function activateTab(name)
        for tName, tab in pairs(tabs) do
            local isActive = (tName == name)
            tab.Scroll.Visible = isActive
            if isActive then
                tw(tab.Btn, 0.2, { BackgroundColor3 = Color3.fromRGB(240,240,240) })
                tab.Stroke.Transparency = 1
                tw(tab.Icon, 0.2, { TextColor3 = Color3.fromRGB(20,20,20) })
                tw(tab.Lbl, 0.2, { TextColor3 = Color3.fromRGB(20,20,20) })
            else
                tw(tab.Btn, 0.2, { BackgroundColor3 = BgRow })
                tab.Stroke.Transparency = 0.5
                tw(tab.Icon, 0.2, { TextColor3 = TextDim })
                tw(tab.Lbl, 0.2, { TextColor3 = TextDim })
            end
        end
    end

    local function addToggle(scroll, text, init, cb)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 44)
        row.BackgroundColor3 = BgRow
        row.Parent = scroll
        corner(row, 8)
        stroke(row, Color3.fromRGB(60,60,60), 1, 0.6)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -70, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = TextC
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local tgl = Instance.new("Frame")
        tgl.Size = UDim2.new(0, 40, 0, 22)
        tgl.Position = UDim2.new(1, -52, 0.5, -11)
        tgl.BackgroundColor3 = init and Accent or Color3.fromRGB(60,60,60)
        tgl.Parent = row
        corner(tgl, 11)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = init and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.new(1,1,1)
        knob.Parent = tgl
        corner(knob, 8)

        local state = init
        row.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                state = not state
                tw(knob, 0.15, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) })
                tw(tgl, 0.15, { BackgroundColor3 = state and Accent or Color3.fromRGB(60,60,60) })
                if cb then cb(state) end
            end
        end)
    end

    local function addSlider(scroll, text, minV, maxV, defV, cb)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 48)
        row.BackgroundColor3 = BgRow
        row.Parent = scroll
        corner(row, 8)
        stroke(row, Color3.fromRGB(60,60,60), 1, 0.6)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -100, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = TextC
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 130, 0, 32)
        bar.Position = UDim2.new(1, -142, 0.5, -16)
        bar.BackgroundColor3 = Color3.fromRGB(50,50,50)
        bar.Parent = row
        corner(bar, 16)
        stroke(bar, Color3.fromRGB(70,70,70), 1, 0.5)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((defV - minV)/(maxV - minV), 0, 1, 0)
        fill.BackgroundColor3 = Accent
        fill.Parent = bar
        corner(fill, 16)

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0, 50, 1, 0)
        valLbl.Position = UDim2.new(0, 10, 0, 0)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(defV)
        valLbl.TextColor3 = Color3.new(1,1,1)
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 12
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.Parent = bar

        local dragging = false
        local function setVal(v)
            v = math.clamp(v, minV, maxV)
            local pct = (v - minV)/(maxV - minV)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            valLbl.Text = string.format("%.2f", v)
            if cb then cb(v) end
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                local pct = math.clamp((input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
                setVal(minV + pct * (maxV - minV))
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local pct = math.clamp((input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
                setVal(minV + pct * (maxV - minV))
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

    -- Đổ Setting
    addToggle(tabs["ESP"].Scroll, "Bật ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
    addToggle(tabs["ESP"].Scroll, "Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
    addToggle(tabs["ESP"].Scroll, "Name", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    addToggle(tabs["ESP"].Scroll, "Health", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    addToggle(tabs["ESP"].Scroll, "Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
    addSlider(tabs["ESP"].Scroll, "Max Dist", 100, 3000, Config.ESP.MaxDistance, function(v) Config.ESP.MaxDistance = v end)

    addToggle(tabs["Aimbot"].Scroll, "Bật Aim", Config.Aim.Enabled, function(v) Config.Aim.Enabled = v end)
    addToggle(tabs["Aimbot"].Scroll, "Wall check", Config.Aim.VisibleOnly, function(v) Config.Aim.VisibleOnly = v end)
    addToggle(tabs["Aimbot"].Scroll, "Team check", Config.Aim.TeamCheck, function(v) Config.Aim.TeamCheck = v end)
    addSlider(tabs["Aimbot"].Scroll, "Max Dist", 100, 5000, Config.Aim.MaxDistance, function(v) Config.Aim.MaxDistance = v end)
    addSlider(tabs["Aimbot"].Scroll, "FOV", 20, 800, Config.Aim.FOV, function(v) Config.Aim.FOV = v end)
    addSlider(tabs["Aimbot"].Scroll, "Smooth", 0.01, 0.99, Config.Aim.Smoothness, function(v) Config.Aim.Smoothness = v end)

    addToggle(tabs["Misc"].Scroll, "Anti Kick", Config.Bypass.AntiKick, function(v) Config.Bypass.AntiKick = v end)
    addToggle(tabs["Misc"].Scroll, "Anti Fling", Config.Bypass.AntiFling, function(v) Config.Bypass.AntiFling = v end)
    addToggle(tabs["Misc"].Scroll, "Anti Void", Config.Bypass.AntiVoid, function(v) Config.Bypass.AntiVoid = v end)

    activateTab("Aimbot")

    local isOpen = true
    local function open()
        isOpen = true
        panel.Visible = true
        toggleBtn.Visible = false
        panel.Size = UDim2.new(0, 340, 0, 0)
        tw(panel, 0.25, { Size = UDim2.new(0, 340, 0, 500) }, Enum.EasingStyle.Back)
    end
    local function close()
        isOpen = false
        local t = tw(panel, 0.2, { Size = UDim2.new(0, 340, 0, 0) })
        t.Completed:Connect(function()
            panel.Visible = false
            toggleBtn.Visible = true
        end)
    end

    toggleBtn.MouseButton1Click:Connect(open)
    closeBtn.MouseButton1Click:Connect(close)
    minBtn.MouseButton1Click:Connect(close)

    -- Drag
    local drag, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true; dragStart = input.Position; startPos = panel.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)

    for name, tab in pairs(tabs) do
        tab.Btn.MouseButton1Click:Connect(function() activateTab(name) end)
    end

    return gui
end

createUI()
print("[CharlieKien] UI Loaded. Fix Aimbot: Active!")
