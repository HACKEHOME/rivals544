--[[
    RIVALS - owl build v3
    black theme, grouped sections, silent aim, wall pierce, panic switch
--]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")

local LP = Players.LocalPlayer
if not LP then return end

local ENV = (getgenv and getgenv()) or _G
if type(ENV.__rivalsOwl) == "table" and type(ENV.__rivalsOwl.destroy) == "function" then
    pcall(ENV.__rivalsOwl.destroy)
end

local CONFIG_DIR  = "rivals_owl"
local CONFIG_FILE = CONFIG_DIR .. "/config.json"

local DRAW_SUPPORTED = (type(Drawing) == "table" or type(Drawing) == "userdata")
local FILE_SUPPORTED = type(writefile) == "function"
    and type(readfile) == "function"
    and type(isfile) == "function"
local HOOK_SUPPORTED = type(hookmetamethod) == "function"

local Connections = {}
local function track(conn)
    table.insert(Connections, conn)
    return conn
end

-- ============================================================
-- config
-- ============================================================

local Cfg = {
    menuKey = Enum.KeyCode.RightShift,
    uiScale = 1,
    esp = {
        enabled     = true,
        box         = true,
        name        = true,
        distance    = true,
        tracer      = false,
        chams       = false,
        teamCheck   = true,
        maxDist     = 500,
        color       = { 235, 240, 245 },
    },
    health = {
        enabled     = true,
        bar         = true,
        numbers     = true,
        barWidth    = 3,
        lowHp       = false,
        lowHpValue  = 35,
        gradient    = true,
    },
    aim = {
        enabled     = true,
        toggle      = false,
        -- keyboard bind (KeyCode)
        key         = Enum.KeyCode.E,
        -- mouse bind — nil means no mouse button bound
        -- valid values: "MouseButton1" | "MouseButton2" | "MouseButton3"
        mouseBtn    = nil,
        smooth      = 0.85,  -- higher = snappier lock (was 0.45)
        fov         = 140,
        prediction  = 0.18,  -- bumped for fast-moving Rivals characters
        -- OFF by default: wall check blocks aim in matches (lots of geometry)
        -- turn ON only if you want strict LOS checking
        wallCheck   = false,
        teamCheck   = true,
        aimPart     = "head",   -- "head" | "body" | "random"
    },
    hacks = {
        silent      = false,
        silentFov   = 200,
        aimHead     = true,
        wallWalk    = false,
        pierce      = false,
        noclip      = false,
        fullbright  = false,
        camFov      = 70,
    },
}

local function deepMerge(dst, src)
    if type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            deepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function loadConfig()
    if not FILE_SUPPORTED then return end
    local ok, data = pcall(function()
        if isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)
    if ok and type(data) == "table" then
        deepMerge(Cfg, data)
        if type(Cfg.menuKey) == "string" then
            Cfg.menuKey = Enum.KeyCode[Cfg.menuKey] or Enum.KeyCode.RightShift
        end
        if type(Cfg.aim.key) == "string" then
            Cfg.aim.key = Enum.KeyCode[Cfg.aim.key] or Enum.KeyCode.E
        end
        -- mouseBtn is stored as a string ("MouseButton2") or nil
        if type(Cfg.aim.mouseBtn) ~= "string" then
            Cfg.aim.mouseBtn = nil
        end
    end
end

local function saveConfig()
    if not FILE_SUPPORTED then return false end
    local ok = pcall(function()
        if makefolder and type(isfolder) == "function" and not isfolder(CONFIG_DIR) then
            makefolder(CONFIG_DIR)
        end
        local out = {
            menuKey = Cfg.menuKey.Name,
            uiScale = Cfg.uiScale,
            esp = Cfg.esp,
            health = Cfg.health,
            aim = {
                enabled     = Cfg.aim.enabled,
                toggle      = Cfg.aim.toggle,
                key         = Cfg.aim.key.Name,
                mouseBtn    = Cfg.aim.mouseBtn,
                smooth      = Cfg.aim.smooth,
                fov         = Cfg.aim.fov,
                prediction  = Cfg.aim.prediction,
                wallCheck   = Cfg.aim.wallCheck,
                teamCheck   = Cfg.aim.teamCheck,
                aimPart     = Cfg.aim.aimPart,
            },
            hacks = Cfg.hacks,
        }
        writefile(CONFIG_FILE, HttpService:JSONEncode(out))
    end)
    return ok
end

loadConfig()

local BoxColor = Color3.fromRGB(
    Cfg.esp.color[1] or 235,
    Cfg.esp.color[2] or 240,
    Cfg.esp.color[3] or 245
)

-- ============================================================
-- theme: pure black
-- ============================================================

local Theme = {
    bg        = Color3.fromRGB(0, 0, 0),
    panel     = Color3.fromRGB(8, 8, 8),
    panelAlt  = Color3.fromRGB(16, 16, 16),
    rowHover  = Color3.fromRGB(26, 26, 26),
    line      = Color3.fromRGB(34, 34, 34),
    text      = Color3.fromRGB(242, 242, 242),
    dim       = Color3.fromRGB(122, 122, 122),
    accent    = Color3.fromRGB(110, 231, 183),
    accent2   = Color3.fromRGB(220, 255, 240),
    track     = Color3.fromRGB(38, 38, 38),
    danger    = Color3.fromRGB(248, 113, 113),
}

local FONT      = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local FONT_MONO = Enum.Font.Code

-- ============================================================
-- primitives
-- ============================================================

local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function corner(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = inst
    return c
end

local function stroke(inst, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.line
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

local function tw(inst, props, time, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(
        time or 0.18,
        style or Enum.EasingStyle.Quint,
        dir or Enum.EasingDirection.Out
    ), props)
    t:Play()
    return t
end

local function gradient(inst, from, to, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, from),
        ColorSequenceKeypoint.new(1, to),
    })
    g.Rotation = rotation or 0
    g.Parent = inst
    return g
end

local function guiParent()
    local ok, res = pcall(function()
        if gethui then return gethui() end
        return game:GetService("CoreGui")
    end)
    if ok and res then return res end
    return LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui")
end

-- ============================================================
-- window shell
-- ============================================================

local ROOT = new("ScreenGui", {
    Name = "RivalsOwl",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
}, guiParent())

local Holder = new("Frame", {
    Name = "Holder",
    Size = UDim2.fromOffset(560, 430),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
}, ROOT)

local Main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Theme.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 1,
}, Holder)
corner(Main, 10)
stroke(Main, Theme.line, 1, 0)

local uiScale = new("UIScale", { Scale = 0.001 }, Holder)

local TitleBar = new("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Main)
corner(TitleBar, 10)

local TitleFill = new("Frame", {
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 1, -18),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
    ZIndex = 2,
}, TitleBar)

local AccentLine = new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 0, 46),
    BackgroundColor3 = Theme.accent,
    BorderSizePixel = 0,
    ZIndex = 4,
}, Main)
gradient(AccentLine, Theme.accent, Theme.accent2, 0)

local Dot = new("Frame", {
    Size = UDim2.fromOffset(7, 7),
    Position = UDim2.fromOffset(16, 19),
    BackgroundColor3 = Theme.accent,
    BorderSizePixel = 0,
    ZIndex = 3,
}, TitleBar)
corner(Dot, 99)

TweenService:Create(
    Dot,
    TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { BackgroundTransparency = 0.7 }
):Play()

new("TextLabel", {
    Size = UDim2.fromOffset(120, 46),
    Position = UDim2.fromOffset(30, 0),
    BackgroundTransparency = 1,
    Font = FONT_BOLD,
    Text = "RIVALS",
    TextColor3 = Theme.text,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, TitleBar)

new("TextLabel", {
    Size = UDim2.fromOffset(120, 46),
    Position = UDim2.fromOffset(34, 0),
    BackgroundTransparency = 1,
    Font = FONT,
    Text = "owl v3",
    TextColor3 = Theme.dim,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, TitleBar)

local KeyHint = new("TextLabel", {
    Size = UDim2.fromOffset(100, 46),
    Position = UDim2.new(1, -196, 0, 0),
    BackgroundTransparency = 1,
    Font = FONT_MONO,
    Text = "[" .. Cfg.menuKey.Name .. "]",
    TextColor3 = Theme.dim,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 3,
}, TitleBar)

local OffBtn = new("TextButton", {
    Size = UDim2.fromOffset(44, 24),
    Position = UDim2.new(1, -84, 0, 11),
    BackgroundColor3 = Theme.panelAlt,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = FONT_BOLD,
    Text = "OFF",
    TextColor3 = Theme.dim,
    TextSize = 10,
    ZIndex = 5,
}, TitleBar)
corner(OffBtn, 6)
stroke(OffBtn, Theme.line, 1, 0.2)

local CloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -34, 0, 11),
    BackgroundColor3 = Theme.panelAlt,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = FONT_BOLD,
    Text = "x",
    TextColor3 = Theme.dim,
    TextSize = 14,
    ZIndex = 5,
}, TitleBar)
corner(CloseBtn, 6)

local Sidebar = new("ScrollingFrame", {
    Name = "Sidebar",
    Size = UDim2.new(0, 132, 1, -62),
    Position = UDim2.fromOffset(10, 52),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
    ZIndex = 2,
    ClipsDescendants = true,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Theme.line,
    ScrollBarImageTransparency = 0.3,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, Main)
corner(Sidebar, 8)
stroke(Sidebar, Theme.line, 1, 0.35)

local NAV_TOP    = 6
local NAV_ROW_H  = 32
local NAV_GAP    = 4
local NAV_STEP   = NAV_ROW_H + NAV_GAP

local function navY(order)
    return NAV_TOP + (order - 1) * NAV_STEP
end

local Content = new("Frame", {
    Name = "Content",
    Size = UDim2.new(1, -156, 1, -62),
    Position = UDim2.fromOffset(148, 52),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Main)
corner(Content, 8)
stroke(Content, Theme.line, 1, 0.35)

new("Frame", {
    Size = UDim2.new(1, -20, 0, 1),
    Position = UDim2.new(0, 10, 1, -22),
    BackgroundColor3 = Theme.line,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 3,
}, Main)

new("TextLabel", {
    Size = UDim2.new(0, 220, 0, 14),
    Position = UDim2.new(0, 12, 1, -19),
    BackgroundTransparency = 1,
    Font = FONT_MONO,
    Text = "esp / aimbot / health / wall shoot / misc / settings",
    TextColor3 = Theme.dim,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTransparency = 0.4,
    ZIndex = 3,
}, Main)

-- ============================================================
-- tab controller
-- ============================================================

local Pages = {}
local TabButtons = {}
local TabOrder = {}
local ActiveTabName = nil
local Pill = nil

local function selectTab(name)
    if not Pages[name] then return end
    ActiveTabName = name

    for n, page in pairs(Pages) do
        if n ~= name then
            page.Visible = false
        end
    end

    for n, btn in pairs(TabButtons) do
        local lbl = btn:FindFirstChildOfClass("TextLabel")
        if n == name then
            tw(btn, { BackgroundColor3 = Theme.panelAlt }, 0.18)
            if lbl then tw(lbl, { TextColor3 = Theme.accent }, 0.18) end
        else
            tw(btn, { BackgroundColor3 = Theme.panel }, 0.18)
            if lbl then tw(lbl, { TextColor3 = Theme.dim }, 0.18) end
        end
    end

    local page = Pages[name]
    page.Visible = true
    page.Position = UDim2.fromOffset(6, 16)
    tw(page, { Position = UDim2.fromOffset(6, 8) }, 0.2)

    if Pill then
        local btn = TabButtons[name]
        if btn then
            tw(Pill, {
                Position = UDim2.new(0, 1, 0, navY(btn.LayoutOrder) + 9),
            }, 0.2)
        end
    end
end

local function makeTab(name, order)
    local page = new("ScrollingFrame", {
        Name = name,
        Size = UDim2.new(1, -12, 1, -12),
        Position = UDim2.fromOffset(6, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.line,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        ZIndex = 3,
    }, Content)

    local layout = new("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    new("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 12),
    }, page)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 30)
    end)

    local btn = new("TextButton", {
        Size = UDim2.new(1, -12, 0, NAV_ROW_H),
        Position = UDim2.new(0, 6, 0, navY(order)),
        BackgroundColor3 = Theme.panel,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Active = true,
        Text = "",
        LayoutOrder = order,
        ZIndex = 3,
    }, Sidebar)
    corner(btn, 7)

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Active = false,
        Font = FONT,
        Text = name,
        TextColor3 = Theme.dim,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, btn)

    btn.MouseEnter:Connect(function()
        if ActiveTabName == name then return end
        tw(btn, { BackgroundColor3 = Theme.rowHover }, 0.14)
        tw(lbl, { TextColor3 = Theme.text }, 0.14)
    end)

    btn.MouseLeave:Connect(function()
        if ActiveTabName == name then return end
        tw(btn, { BackgroundColor3 = Theme.panel }, 0.16)
        tw(lbl, { TextColor3 = Theme.dim }, 0.16)
    end)

    btn.MouseButton1Click:Connect(function()
        selectTab(name)
    end)

    Pages[name] = page
    TabButtons[name] = btn
    table.insert(TabOrder, name)
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, navY(order) + NAV_ROW_H + 8)
    return page
end

Pill = new("Frame", {
    Size = UDim2.new(0, 3, 0, 14),
    Position = UDim2.fromOffset(1, 15),
    BackgroundColor3 = Theme.accent,
    BorderSizePixel = 0,
    ZIndex = 5,
}, Sidebar)
corner(Pill, 2)
gradient(Pill, Theme.accent, Theme.accent2, 90)

-- ============================================================
-- controls
-- ============================================================

local function rowBase(parent, height)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Theme.bg,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, parent)
    corner(row, 6)
    return row
end

local function bindHover(row, hit)
    hit.MouseEnter:Connect(function()
        tw(row, { BackgroundColor3 = Theme.rowHover }, 0.14)
    end)
    hit.MouseLeave:Connect(function()
        tw(row, { BackgroundColor3 = Theme.bg }, 0.16)
    end)
end

local function label(parent, text, widthOffset)
    return new("TextLabel", {
        Size = UDim2.new(1, widthOffset or -80, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Active = false,
        Font = FONT,
        Text = text,
        TextColor3 = Theme.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, parent)
end

local function sectionHeader(parent, text)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, parent)

    new("TextLabel", {
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Active = false,
        Font = FONT_BOLD,
        Text = string.upper(text),
        TextColor3 = Theme.dim,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, row)

    return row
end

local function toggle(parent, name, state, changed)
    local row = rowBase(parent, 34)
    label(row, name)

    local trackFrame = new("Frame", {
        Size = UDim2.fromOffset(40, 20),
        Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = state and Theme.accent or Theme.track,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, row)
    corner(trackFrame, 10)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = state and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(245, 248, 252),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, trackFrame)
    corner(knob, 8)

    local value = state

    local function render(anim)
        if anim then
            tw(trackFrame, { BackgroundColor3 = value and Theme.accent or Theme.track }, 0.18)
            tw(knob, {
                Position = value and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
            }, 0.2, Enum.EasingStyle.Back)
        else
            trackFrame.BackgroundColor3 = value and Theme.accent or Theme.track
            knob.Position = value and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
        end
    end

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 6,
    }, row)
    bindHover(row, hit)

    hit.MouseButton1Click:Connect(function()
        value = not value
        render(true)
        changed(value)
    end)

    return {
        set = function(v)
            value = v
            render(true)
        end,
        get = function() return value end,
    }
end

local function slider(parent, name, min, max, value, decimals, changed)
    local row = rowBase(parent, 46)

    new("TextLabel", {
        Size = UDim2.new(1, -100, 0, 20),
        Position = UDim2.fromOffset(12, 5),
        BackgroundTransparency = 1,
        Active = false,
        Font = FONT,
        Text = name,
        TextColor3 = Theme.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, row)

    local fmt = "%." .. tostring(decimals) .. "f"

    local valueLabel = new("TextLabel", {
        Size = UDim2.fromOffset(84, 20),
        Position = UDim2.new(1, -96, 0, 5),
        BackgroundTransparency = 1,
        Active = false,
        Font = FONT_MONO,
        Text = string.format(fmt, value),
        TextColor3 = Theme.accent,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4,
    }, row)

    local bar = new("Frame", {
        Size = UDim2.new(1, -24, 0, 4),
        Position = UDim2.fromOffset(12, 30),
        BackgroundColor3 = Theme.track,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, row)
    corner(bar, 2)

    local frac = (value - min) / (max - min)

    local fill = new("Frame", {
        Size = UDim2.new(frac, 0, 1, 0),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, bar)
    corner(fill, 2)
    gradient(fill, Theme.accent, Theme.accent2, 0)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(10, 10),
        Position = UDim2.new(frac, -5, 0.5, -5),
        BackgroundColor3 = Color3.fromRGB(240, 244, 250),
        BorderSizePixel = 0,
        ZIndex = 6,
    }, bar)
    corner(knob, 99)

    local dragging = false

    local function set(v)
        v = math.clamp(v, min, max)
        if decimals == 0 then v = math.floor(v + 0.5) end
        local f = (v - min) / (max - min)
        fill.Size = UDim2.new(f, 0, 1, 0)
        knob.Position = UDim2.new(f, -5, 0.5, -5)
        valueLabel.Text = string.format(fmt, v)
        changed(v)
    end

    local function fromInput(input)
        local rel = (input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
        set(min + (max - min) * math.clamp(rel, 0, 1))
    end

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 7,
    }, row)
    bindHover(row, hit)

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            tw(knob, { Size = UDim2.fromOffset(13, 13) }, 0.12)
            fromInput(input)
        end
    end)

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            fromInput(input)
        end
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            tw(knob, { Size = UDim2.fromOffset(10, 10) }, 0.15)
        end
    end))

    return {
        set = function(v)
            local f = (v - min) / (max - min)
            fill.Size = UDim2.new(f, 0, 1, 0)
            knob.Position = UDim2.new(f, -5, 0.5, -5)
            valueLabel.Text = string.format(fmt, v)
        end,
    }
end

-- Friendly display names for mouse buttons shown on the bind button
local MOUSE_BTN_NAMES = {
    [Enum.UserInputType.MouseButton1] = "MB1",
    [Enum.UserInputType.MouseButton2] = "MB2",
    [Enum.UserInputType.MouseButton3] = "MB3",
}
-- Mouse buttons the keybind widget will accept (not MB1 — that's used to click the button itself)
local BINDABLE_MOUSE = {
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3,
}

-- keybind: a single row that captures keyboard keys OR mouse buttons.
-- changed(keyCode, mouseBtn) — one of them will be non-nil, the other nil.
local function keybind(parent, name, key, changed)
    local row = rowBase(parent, 34)

    new("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Active = false,
        Font = FONT,
        Text = name,
        TextColor3 = Theme.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, row)

    -- show current binding
    local function displayText()
        if Cfg.aim.mouseBtn then
            local uit = Enum.UserInputType[Cfg.aim.mouseBtn]
            return MOUSE_BTN_NAMES[uit] or Cfg.aim.mouseBtn
        end
        return key.Name
    end

    local btn = new("TextButton", {
        Size = UDim2.fromOffset(88, 22),
        Position = UDim2.new(1, -100, 0.5, -11),
        BackgroundColor3 = Theme.track,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = FONT_MONO,
        Text = displayText(),
        TextColor3 = Theme.accent,
        TextSize = 12,
        ZIndex = 5,
    }, row)
    corner(btn, 5)

    local listening = false

    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        btn.Text = "press key / MB2…"
        tw(btn, { TextColor3 = Theme.dim }, 0.12)
    end)

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if not listening then return end

        local utype = input.UserInputType

        -- keyboard key
        if utype == Enum.UserInputType.Keyboard then
            listening = false
            local k = input.KeyCode
            if k == Enum.KeyCode.Escape then
                -- escape = cancel, restore display
                btn.Text = displayText()
                tw(btn, { TextColor3 = Theme.accent }, 0.12)
                return
            end
            Cfg.aim.mouseBtn = nil   -- clear any mouse bind
            btn.Text = k.Name
            tw(btn, { TextColor3 = Theme.accent }, 0.12)
            changed(k, nil)
            return
        end

        -- mouse buttons (skip MB1 — that's how you click the bind button)
        for _, mb in ipairs(BINDABLE_MOUSE) do
            if utype == mb then
                listening = false
                local mbName = Cfg.aim.mouseBtn  -- will be set by changed()
                local displayName = MOUSE_BTN_NAMES[utype] or tostring(utype)
                btn.Text = displayName
                tw(btn, { TextColor3 = Theme.accent }, 0.12)
                changed(nil, utype)
                return
            end
        end
    end))

    return {
        set = function(k, mb)
            if mb then
                btn.Text = MOUSE_BTN_NAMES[mb] or tostring(mb)
            else
                btn.Text = k and k.Name or "?"
            end
        end,
    }
end

local function button(parent, name, color, clicked)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = color or Theme.panelAlt,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = FONT,
        Text = name,
        TextColor3 = Theme.text,
        TextSize = 13,
        ZIndex = 4,
    }, parent)
    corner(btn, 6)

    local base = color or Theme.panelAlt

    btn.MouseEnter:Connect(function() tw(btn, { BackgroundColor3 = Theme.rowHover }, 0.14) end)
    btn.MouseLeave:Connect(function() tw(btn, { BackgroundColor3 = base }, 0.16) end)

    local bs = new("UIScale", { Scale = 1 }, btn)
    btn.MouseButton1Down:Connect(function() tw(bs, { Scale = 0.975 }, 0.08) end)
    btn.MouseButton1Up:Connect(function() tw(bs, { Scale = 1 }, 0.14) end)
    btn.MouseLeave:Connect(function() tw(bs, { Scale = 1 }, 0.14) end)

    btn.MouseButton1Click:Connect(clicked)
    return btn
end

-- radioGroup: horizontal pill-style 3-way selector
-- options = { {id="head", label="Head"}, ... }
-- default  = one of the ids
-- changed(id) fires on click
local function radioGroup(parent, name, options, default, changed)
    local row = rowBase(parent, 58)

    new("TextLabel", {
        Size  = UDim2.new(1, -10, 0, 20),
        Position = UDim2.fromOffset(12, 5),
        BackgroundTransparency = 1,
        Active = false,
        Font  = FONT,
        Text  = name,
        TextColor3 = Theme.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    }, row)

    local container = new("Frame", {
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.new(0, 12, 0, 28),
        BackgroundColor3 = Theme.track,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, row)
    corner(container, 6)
    stroke(container, Theme.line, 1, 0.3)

    local selected = default
    local entries  = {}
    local n        = #options

    for i, opt in ipairs(options) do
        local xScale = (i - 1) / n
        local wScale = 1 / n

        local pill = new("Frame", {
            Size = UDim2.new(wScale, -2, 1, -2),
            Position = UDim2.new(xScale, 1, 0, 1),
            BackgroundColor3 = opt.id == default and Theme.accent or Color3.fromRGB(0,0,0),
            BackgroundTransparency = opt.id == default and 0 or 1,
            BorderSizePixel = 0,
            ZIndex = 5,
        }, container)
        corner(pill, 5)

        local lbl = new("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Active = false,
            Font  = FONT_BOLD,
            Text  = opt.label,
            TextColor3 = opt.id == default and Theme.bg or Theme.dim,
            TextSize   = 11,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 6,
        }, pill)

        local hit = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 7,
        }, pill)

        entries[i] = { id = opt.id, pill = pill, lbl = lbl }

        hit.MouseButton1Click:Connect(function()
            selected = opt.id
            for _, e in ipairs(entries) do
                local active = e.id == selected
                tw(e.pill, {
                    BackgroundColor3 = active and Theme.accent or Color3.fromRGB(0,0,0),
                    BackgroundTransparency = active and 0 or 1,
                }, 0.16)
                tw(e.lbl, { TextColor3 = active and Theme.bg or Theme.dim }, 0.16)
            end
            changed(opt.id)
        end)
    end

    return {
        set = function(id)
            selected = id
            for _, e in ipairs(entries) do
                local active = e.id == selected
                e.pill.BackgroundColor3 = active and Theme.accent or Color3.fromRGB(0,0,0)
                e.pill.BackgroundTransparency = active and 0 or 1
                e.lbl.TextColor3 = active and Theme.bg or Theme.dim
            end
        end,
        get = function() return selected end,
    }
end

-- ============================================================
-- notifications
-- ============================================================

local function notify(text)
    local box = new("Frame", {
        Size = UDim2.new(1, -28, 0, 30),
        Position = UDim2.new(0, 14, 1, 14),
        BackgroundColor3 = Color3.fromRGB(14, 14, 14),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 20,
    }, Main)
    corner(box, 7)
    stroke(box, Theme.line, 1, 0.2)

    local strip = new("Frame", {
        Size = UDim2.new(0, 3, 0, 16),
        Position = UDim2.new(0, 8, 0.5, -8),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        ZIndex = 21,
    }, box)
    corner(strip, 2)

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.fromOffset(18, 0),
        BackgroundTransparency = 1,
        Active = false,
        Font = FONT,
        Text = text,
        TextColor3 = Theme.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 21,
    }, box)

    tw(box, { Position = UDim2.new(0, 14, 1, -46), BackgroundTransparency = 0.04 }, 0.24)
    tw(lbl, { TextTransparency = 0 }, 0.24)

    task.delay(2.2, function()
        tw(box, { Position = UDim2.new(0, 14, 1, 14), BackgroundTransparency = 1 }, 0.2)
        tw(lbl, { TextTransparency = 1 }, 0.2)
        task.delay(0.3, function()
            pcall(function() box:Destroy() end)
        end)
    end)
end

-- ============================================================
-- pages
-- ============================================================

local ConfigTab  = makeTab("Config", 1)
local EspTab     = makeTab("ESP", 2)
local AimTab     = makeTab("Aimbot", 3)
local HealthTab  = makeTab("Health", 4)
local WallTab    = makeTab("Wall Shoot", 5)
local MiscTab    = makeTab("Misc", 6)
local SettingsTab = makeTab("Settings", 7)

-- CONFIG ----------------------------------------------------

sectionHeader(ConfigTab, "persistence")
button(ConfigTab, "Save config", Theme.panelAlt, function()
    notify(saveConfig() and "config saved" or "no filesystem access")
end)
button(ConfigTab, "Reload config", Theme.panelAlt, function()
    loadConfig()
    BoxColor = Color3.fromRGB(Cfg.esp.color[1], Cfg.esp.color[2], Cfg.esp.color[3])
    notify("config reloaded")
end)
button(ConfigTab, "Reset to defaults", Theme.panelAlt, function()
    Cfg.esp.enabled     = true
    Cfg.esp.box         = true
    Cfg.esp.name        = true
    Cfg.esp.distance    = true
    Cfg.esp.tracer      = false
    Cfg.esp.chams       = false
    Cfg.esp.teamCheck   = true
    Cfg.esp.maxDist     = 500
    Cfg.health.enabled  = true
    Cfg.health.bar      = true
    Cfg.health.numbers  = true
    Cfg.aim.smooth      = 0.85
    Cfg.aim.fov         = 140
    Cfg.aim.wallCheck   = false
    Cfg.aim.prediction  = 0.18
    Cfg.aim.mouseBtn    = nil
    Cfg.hacks.silent    = false
    Cfg.hacks.wallWalk  = false
    Cfg.hacks.pierce    = false
    Cfg.hacks.noclip    = false
    Cfg.hacks.aimHead   = true
    Cfg.aim.aimPart     = "head"
    restoreCollide()
    pcall(function() applyPierce(false) end)
    applyFullbright(false)
    notify("defaults restored")
end)

sectionHeader(ConfigTab, "session")
button(ConfigTab, "Disable everything", Theme.panelAlt, function()
    panic()
end)
button(ConfigTab, "Unload script", Theme.panelAlt, function()
    destroy()
end)

-- ESP -------------------------------------------------------

sectionHeader(EspTab, "players")
toggle(EspTab, "ESP enabled", Cfg.esp.enabled, function(v) Cfg.esp.enabled = v end)
toggle(EspTab, "Box", Cfg.esp.box, function(v) Cfg.esp.box = v end)
toggle(EspTab, "Name", Cfg.esp.name, function(v) Cfg.esp.name = v end)
toggle(EspTab, "Distance", Cfg.esp.distance, function(v) Cfg.esp.distance = v end)
toggle(EspTab, "Tracer", Cfg.esp.tracer, function(v) Cfg.esp.tracer = v end)
toggle(EspTab, "Chams (highlight)", Cfg.esp.chams, function(v) Cfg.esp.chams = v end)

sectionHeader(EspTab, "filters")
toggle(EspTab, "Team check", Cfg.esp.teamCheck, function(v) Cfg.esp.teamCheck = v end)
slider(EspTab, "Max distance", 50, 1500, Cfg.esp.maxDist, 0, function(v) Cfg.esp.maxDist = v end)

-- AIM -------------------------------------------------------

sectionHeader(AimTab, "aimbot")
toggle(AimTab, "Aimbot enabled", Cfg.aim.enabled, function(v) Cfg.aim.enabled = v end)
toggle(AimTab, "Toggle mode", Cfg.aim.toggle, function(v) Cfg.aim.toggle = v end)
keybind(AimTab, "Aim key  (key or MB2/MB3)", Cfg.aim.key, function(k, mb)
    if mb then
        -- mouse button bound — store string name, clear keyboard key
        Cfg.aim.mouseBtn = tostring(mb):match("%.([%w]+)$") or tostring(mb)
    else
        -- keyboard key bound — clear mouse button
        Cfg.aim.key      = k
        Cfg.aim.mouseBtn = nil
    end
end)

sectionHeader(AimTab, "behaviour")
slider(AimTab, "Smoothing", 0.05, 1, Cfg.aim.smooth, 2, function(v) Cfg.aim.smooth = v end)
slider(AimTab, "FOV radius", 20, 500, Cfg.aim.fov, 0, function(v) Cfg.aim.fov = v end)
slider(AimTab, "Prediction", 0, 0.4, Cfg.aim.prediction, 3, function(v) Cfg.aim.prediction = v end)

sectionHeader(AimTab, "targeting")
toggle(AimTab, "Wall check", Cfg.aim.wallCheck, function(v) Cfg.aim.wallCheck = v end)
toggle(AimTab, "Team check (skip teammates)", Cfg.aim.teamCheck, function(v)
    Cfg.aim.teamCheck = v
    notify(v and "team check on — enemies only" or "team check off — all players")
end)

sectionHeader(AimTab, "aim bone")
radioGroup(AimTab, "Target bone", {
    { id = "head",   label = "Head"   },
    { id = "body",   label = "Body"   },
    { id = "random", label = "Random" },
}, Cfg.aim.aimPart, function(v)
    Cfg.aim.aimPart = v
    local hint = v == "head" and "head shots only"
        or v == "body" and "body shots only"
        or "random — 60% head / 40% body"
    notify("aim bone: " .. hint)
end)

-- HEALTH ----------------------------------------------------

sectionHeader(HealthTab, "health bars")
toggle(HealthTab, "Health enabled", Cfg.health.enabled, function(v) Cfg.health.enabled = v end)
toggle(HealthTab, "Bar", Cfg.health.bar, function(v) Cfg.health.bar = v end)
toggle(HealthTab, "Numbers", Cfg.health.numbers, function(v) Cfg.health.numbers = v end)
toggle(HealthTab, "Green to red gradient", Cfg.health.gradient, function(v) Cfg.health.gradient = v end)
slider(HealthTab, "Bar width", 2, 10, Cfg.health.barWidth, 0, function(v) Cfg.health.barWidth = v end)

sectionHeader(HealthTab, "low health")
toggle(HealthTab, "Low HP highlight", Cfg.health.lowHp, function(v) Cfg.health.lowHp = v end)
slider(HealthTab, "Threshold %", 5, 100, Cfg.health.lowHpValue, 0, function(v) Cfg.health.lowHpValue = v end)

-- WALL SHOOT ------------------------------------------------

sectionHeader(WallTab, "wall shooting")
toggle(WallTab, "Silent aim (wall shoot)", Cfg.hacks.silent, function(v)
    Cfg.hacks.silent = v
    notify(v and "wall shoot on" or "wall shoot off")
end)
slider(WallTab, "Silent FOV", 40, 600, Cfg.hacks.silentFov, 0, function(v) Cfg.hacks.silentFov = v end)
toggle(WallTab, "Aim head", Cfg.hacks.aimHead, function(v) Cfg.hacks.aimHead = v end)
toggle(WallTab, "Aimbot ignores walls", not Cfg.aim.wallCheck, function(v)
    Cfg.aim.wallCheck = not v
end)

sectionHeader(WallTab, "wall pierce")
toggle(WallTab, "Pierce walls (aimbot + silent)", Cfg.hacks.pierce, function(v)
    Cfg.hacks.pierce = v
    -- applyPierce defined in the noclip section below the UI build;
    -- wrap in pcall because UI builds before that section at parse time,
    -- but at runtime the function is already in scope.
    pcall(function() applyPierce(v) end)
    notify(v and "pierce on" or "pierce off")
end)

sectionHeader(WallTab, "movement")
toggle(WallTab, "Wall walk", Cfg.hacks.wallWalk, function(v)
    Cfg.hacks.wallWalk = v
    if v then
        Cfg.hacks.noclip = false
        -- restore saved collisions so stickFloor baseline is clean
        restoreCollide()
    end
    notify(v and "wall walk on" or "wall walk off")
end)
toggle(WallTab, "Noclip (free fall)", Cfg.hacks.noclip, function(v)
    Cfg.hacks.noclip = v
    if v then
        Cfg.hacks.wallWalk = false
        restoreCollide()
    end
    notify(v and "noclip on" or "noclip off")
end)

-- MISC ------------------------------------------------------

sectionHeader(MiscTab, "world")
toggle(MiscTab, "Fullbright", Cfg.hacks.fullbright, function(v)
    Cfg.hacks.fullbright = v
    applyFullbright(v)
end)
slider(MiscTab, "Camera FOV", 40, 120, Cfg.hacks.camFov, 0, function(v)
    Cfg.hacks.camFov = v
    local cam = Workspace.CurrentCamera
    if cam then cam.FieldOfView = v end
end)

sectionHeader(MiscTab, "interface")
button(MiscTab, "Disable everything", Theme.panelAlt, function()
    panic()
end)

-- SETTINGS --------------------------------------------------

sectionHeader(SettingsTab, "interface")
keybind(SettingsTab, "Menu key", Cfg.menuKey, function(k)
    Cfg.menuKey = k
    KeyHint.Text = "[" .. k.Name .. "]"
end)
slider(SettingsTab, "UI scale", 70, 130, math.floor(Cfg.uiScale * 100), 0, function(v)
    Cfg.uiScale = v / 100
    uiScale.Scale = Cfg.uiScale
end)

sectionHeader(SettingsTab, "session")
button(SettingsTab, "Disable everything", Theme.panelAlt, function()
    panic()
end)
button(SettingsTab, "Unload script", Theme.panelAlt, function()
    destroy()
end)

-- ============================================================
-- world hacks
-- ============================================================

local original = {
    Brightness     = Lighting.Brightness,
    Ambient        = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd         = Lighting.FogEnd,
    ClockTime      = Lighting.ClockTime,
}

function applyFullbright(state)
    if state then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.FogEnd = 100000
        Lighting.ClockTime = 14
    else
        Lighting.Brightness = original.Brightness
        Lighting.Ambient = original.Ambient
        Lighting.OutdoorAmbient = original.OutdoorAmbient
        Lighting.FogEnd = original.FogEnd
        Lighting.ClockTime = original.ClockTime
    end
end

local savedCollide = {}
local savedForChar  = nil

local moveParams = RaycastParams.new()
do
    local ok = pcall(function() moveParams.FilterType = Enum.RaycastFilterType.Exclude end)
    if not ok then
        pcall(function() moveParams.FilterType = Enum.RaycastFilterType.Blacklist end)
    end
    moveParams.IgnoreWater = true
end

local function restoreCollide()
    for part, value in pairs(savedCollide) do
        if part and part.Parent then
            pcall(function() part.CanCollide = value end)
        end
    end
    savedCollide = {}
    savedForChar = nil
end

local function stripCollide(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if savedCollide[part] == nil then
                savedCollide[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end
end

-- Keeps the character grounded while collisions are stripped.
-- Casts further down (20 studs) to handle slopes and uneven terrain
-- without snapping the player upward on flat ground (delta guard).
local function stickFloor(char, hrp)
    moveParams.FilterDescendantsInstances = { char }
    local origin = hrp.Position + Vector3.new(0, 4, 0)
    local result = Workspace:Raycast(origin, Vector3.new(0, -20, 0), moveParams)
    if not result then return end

    local targetY = result.Position.Y + 2.8
    local delta = hrp.Position.Y - targetY

    -- only correct if we're close to the floor; don't snap during jumps
    -- or when walking up a wall-like incline far from the ground
    if delta > 8 or delta < -0.4 then return end

    local spin = hrp.CFrame - hrp.CFrame.Position
    pcall(function()
        hrp.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z) * spin
        local vel = hrp.AssemblyLinearVelocity
        hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.min(vel.Y, 0), vel.Z)
    end)
end

local function updateMovement()
    local char = LP.Character
    if not char then
        if savedForChar then restoreCollide() end
        return
    end

    local walk = Cfg.hacks.wallWalk
    local free = Cfg.hacks.noclip

    -- if both are off, restore saved collision state and bail
    if not (walk or free) then
        if savedForChar then restoreCollide() end
        return
    end

    -- respawn detection: restore old char collisions before switching
    if savedForChar and savedForChar ~= char then restoreCollide() end
    savedForChar = char

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    -- strip every frame — Roblox re-enables CanCollide on some parts
    -- (ragdoll recovery, spawn, seat exit) so we re-strip every tick
    stripCollide(char)

    -- wall walk: stick to floor so player doesn't fall through
    -- noclip: no floor stick — player drifts freely
    if walk and not free then
        stickFloor(char, hrp)
    end

    -- make sure the humanoid doesn't fight us by sitting the physics state
    if free then
        pcall(function()
            if hum.PlatformStand == false then
                hum.PlatformStand = false -- intentional no-op ping to keep state fresh
            end
        end)
    end
end

-- ============================================================
-- panic
-- ============================================================

function panic()
    Cfg.esp.enabled     = false
    Cfg.health.enabled  = false
    Cfg.aim.enabled     = false
    Cfg.hacks.silent    = false
    Cfg.hacks.wallWalk  = false
    Cfg.hacks.noclip    = false
    Cfg.hacks.fullbright = false
    Cfg.hacks.pierce    = false
    aimActive           = false
    aimToggleState      = false
    currentTarget       = nil
    currentAimPart      = nil
    restoreCollide()
    applyFullbright(false)
    -- applyPierce defined later but called at runtime so safe
    pcall(function() applyPierce(false) end)
    notify("all features disabled")
end

-- ============================================================
-- esp
-- ============================================================

local espCache = {}

local function isTeammate(plr)
    local lt = LP.Team
    return lt ~= nil and plr.Team ~= nil and plr.Team == lt
end

local function newDrawing(class)
    if not DRAW_SUPPORTED then return nil end
    local ok, obj = pcall(function() return Drawing.new(class) end)
    if ok then return obj end
    return nil
end

local function createESPObjects()
    local o = {}
    o.bg     = newDrawing("Square")
    o.box    = newDrawing("Square")
    o.hpBg   = newDrawing("Square")
    o.hpFill = newDrawing("Square")
    o.name   = newDrawing("Text")
    o.hpText = newDrawing("Text")
    o.dist   = newDrawing("Text")
    o.tracer = newDrawing("Line")

    if o.bg then
        o.bg.Filled = false
        o.bg.Thickness = 1
        o.bg.Color = Color3.new(0, 0, 0)
        o.bg.Transparency = 0.4
    end
    if o.box then
        o.box.Filled = false
        o.box.Thickness = 1
        o.box.Color = BoxColor
    end
    if o.hpBg then
        o.hpBg.Filled = true
        o.hpBg.Color = Color3.fromRGB(10, 10, 10)
        o.hpBg.Transparency = 0.35
    end
    if o.hpFill then
        o.hpFill.Filled = true
        o.hpFill.Color = Color3.fromRGB(110, 231, 183)
    end
    if o.name then
        o.name.Center = true
        o.name.Outline = true
        o.name.OutlineColor = Color3.new(0, 0, 0)
        o.name.Size = 13
        o.name.Font = (Drawing and Drawing.Fonts and Drawing.Fonts.Plex) or 2
        o.name.Color = Color3.fromRGB(240, 242, 246)
    end
    if o.hpText then
        o.hpText.Center = true
        o.hpText.Outline = true
        o.hpText.OutlineColor = Color3.new(0, 0, 0)
        o.hpText.Size = 11
        o.hpText.Font = (Drawing and Drawing.Fonts and Drawing.Fonts.Plex) or 2
        o.hpText.Color = Color3.fromRGB(180, 255, 220)
    end
    if o.dist then
        o.dist.Center = true
        o.dist.Outline = true
        o.dist.OutlineColor = Color3.new(0, 0, 0)
        o.dist.Size = 11
        o.dist.Font = (Drawing and Drawing.Fonts and Drawing.Fonts.Plex) or 2
        o.dist.Color = Color3.fromRGB(180, 188, 200)
    end
    if o.tracer then
        o.tracer.Thickness = 1
        o.tracer.Color = BoxColor
    end
    return o
end

local function hideAll(o)
    for _, d in pairs(o) do
        if d then d.Visible = false end
    end
end

local function destroyAll(o)
    for _, d in pairs(o) do
        if d then pcall(function() d:Remove() end) end
    end
end

local function getESP(plr)
    local o = espCache[plr]
    if not o then
        o = createESPObjects()
        espCache[plr] = o
    end
    return o
end

local function healthColor(frac)
    if not Cfg.health.gradient then
        return Color3.fromRGB(110, 231, 183)
    end
    return Color3.fromRGB(
        math.floor(255 * (1 - frac) + 80 * frac),
        math.floor(90 + 140 * frac),
        110
    )
end

local function updateChams(plr, char, frac)
    local hl = char:FindFirstChild("__owl_chams")
    local lowHp = Cfg.health.lowHp and frac <= (Cfg.health.lowHpValue / 100)

    if Cfg.esp.enabled and (Cfg.esp.chams or lowHp) and not isTeammate(plr) then
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "__owl_chams"
            hl.FillColor = BoxColor
            hl.FillTransparency = 0.65
            hl.OutlineColor = BoxColor
            hl.OutlineTransparency = 0.2
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
        end
        if lowHp then
            hl.FillColor = Color3.fromRGB(248, 113, 113)
            hl.OutlineColor = Color3.fromRGB(248, 113, 113)
            hl.FillTransparency = 0.55
        else
            hl.FillColor = BoxColor
            hl.OutlineColor = BoxColor
            hl.FillTransparency = 0.65
        end
        hl.Enabled = true
    elseif hl then
        hl.Enabled = false
    end
end

local function updateESP()
    if not DRAW_SUPPORTED then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize

    for _, plr in ipairs(Players:GetPlayers()) do
        local o = espCache[plr]
        local char = plr.Character
        local skip = (plr == LP) or not char or (Cfg.esp.teamCheck and isTeammate(plr))
        local hum = (not skip) and char:FindFirstChildOfClass("Humanoid")
        local hrp = (not skip) and char:FindFirstChild("HumanoidRootPart")
        local head = (not skip) and char:FindFirstChild("Head")

        local drawn = false

        if Cfg.esp.enabled and hum and hrp and head and hum.Health > 0 then
            o = getESP(plr)
            local pos = hrp.Position
            local dist = (cam.CFrame.Position - pos).Magnitude

            if dist <= Cfg.esp.maxDist then
                local top = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
                local bottom = cam:WorldToViewportPoint(pos - Vector3.new(0, 2.7, 0))

                if top.Z > 0 and bottom.Z > 0 then
                    local h = bottom.Y - top.Y
                    if h > 4 then
                        local w = h * 0.52
                        local x = top.X - w / 2
                        local y = top.Y
                        local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)

                        if o.bg then
                            o.bg.Visible = Cfg.esp.box
                            o.bg.Size = Vector2.new(w + 2, h + 2)
                            o.bg.Position = Vector2.new(x - 1, y - 1)
                        end
                        if o.box then
                            o.box.Visible = Cfg.esp.box
                            o.box.Size = Vector2.new(w, h)
                            o.box.Position = Vector2.new(x, y)
                            o.box.Color = BoxColor
                        end
                        if o.hpBg then
                            o.hpBg.Visible = Cfg.health.enabled and Cfg.health.bar
                            o.hpBg.Size = Vector2.new(Cfg.health.barWidth, h)
                            o.hpBg.Position = Vector2.new(x - 6, y)
                        end
                        if o.hpFill then
                            o.hpFill.Visible = Cfg.health.enabled and Cfg.health.bar
                            o.hpFill.Size = Vector2.new(Cfg.health.barWidth, h * frac)
                            o.hpFill.Position = Vector2.new(x - 6, y + h * (1 - frac))
                            o.hpFill.Color = healthColor(frac)
                        end
                        if o.name then
                            o.name.Visible = Cfg.esp.name
                            o.name.Position = Vector2.new(x + w / 2, y - 15)
                            o.name.Text = plr.Name
                        end
                        if o.hpText then
                            o.hpText.Visible = Cfg.health.enabled and Cfg.health.numbers
                            o.hpText.Position = Vector2.new(x + w / 2, y + h + 15)
                            o.hpText.Text = string.format("%d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))
                            o.hpText.Color = healthColor(frac)
                        end
                        if o.dist then
                            o.dist.Visible = Cfg.esp.distance
                            o.dist.Position = Vector2.new(x + w / 2, y + h + 3)
                            o.dist.Text = string.format("%d studs", math.floor(dist))
                        end
                        if o.tracer then
                            o.tracer.Visible = Cfg.esp.tracer
                            o.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                            o.tracer.To = Vector2.new(x + w / 2, y + h)
                        end

                        updateChams(plr, char, frac)
                        drawn = true
                    end
                end
            end
        end

        if not drawn then
            if o then hideAll(o) end
            if plr.Character then
                local hl = plr.Character:FindFirstChild("__owl_chams")
                if hl then hl.Enabled = false end
            end
        end
    end
end

-- ============================================================
-- aimbot
-- ============================================================

local aimActive      = false
local aimToggleState = false
local currentTarget  = nil
local currentAimPart = nil   -- resolved part name, locked per target-lock

-- Resolves which body part string to aim at based on Cfg.aim.aimPart.
-- "head"   → always "Head"
-- "body"   → always "HumanoidRootPart"
-- "random" → 60% chance "Head", 40% chance "HumanoidRootPart" per roll.
-- Called ONCE when the target changes so random doesn't flicker every frame.
local function resolveAimPartName()
    local mode = Cfg.aim.aimPart
    if mode == "head" then
        return "Head"
    elseif mode == "body" then
        return "HumanoidRootPart"
    else
        -- random: 60 / 40 split
        return math.random() < 0.6 and "Head" or "HumanoidRootPart"
    end
end

local fovCircle = newDrawing("Circle")
if fovCircle then
    fovCircle.Thickness = 1
    fovCircle.NumSides = 64
    fovCircle.Filled = false
    fovCircle.Color = BoxColor
    fovCircle.Transparency = 0.35
    fovCircle.Visible = false
end

local function raycastParams()
    local params = RaycastParams.new()
    local ok = pcall(function() params.FilterType = Enum.RaycastFilterType.Exclude end)
    if not ok then
        pcall(function() params.FilterType = Enum.RaycastFilterType.Blacklist end)
    end
    local ignore = {}
    if LP.Character then table.insert(ignore, LP.Character) end
    if Workspace.CurrentCamera then table.insert(ignore, Workspace.CurrentCamera) end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    return params
end

-- Checks if `part` has line-of-sight from the camera.
-- Returns true immediately if wallCheck is off (default for match play).
-- When wallCheck is on: casts to both the given part AND the character's
-- HumanoidRootPart — if either is clear, the player counts as visible.
-- This prevents losing lock when only the head clips behind a wall corner
-- while the body is still exposed.
local function visible(part)
    if not Cfg.aim.wallCheck then return true end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local params = raycastParams()
    local char   = part.Parent

    -- primary cast to the requested part
    local r1 = Workspace:Raycast(origin, part.Position - origin, params)
    if r1 == nil or r1.Instance:IsDescendantOf(char) then return true end

    -- secondary cast to HumanoidRootPart (body center) — catches peeking players
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp ~= part then
        local r2 = Workspace:Raycast(origin, hrp.Position - origin, params)
        if r2 == nil or r2.Instance:IsDescendantOf(char) then return true end
    end

    return false
end

-- findTarget: scans all players for the closest one inside FOV.
-- fovOverride  — cap in pixels; nil = use Cfg.aim.fov
-- ignoreWalls  — skip visibility check (used by silent aim)
-- forceHead    — force head-part for FOV anchor (used by silent aim's
--                own headOnly toggle); nil = derive from Cfg.aim.aimPart
local function findTarget(fovOverride, ignoreWalls, forceHead)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local vp     = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestDist = nil, fovOverride or Cfg.aim.fov

    -- FOV anchor: for "body" aim we still measure FOV from head because
    -- head is the stricter test — if head is in FOV, body definitely is.
    -- forceHead overrides for silent aim's own toggle.
    local anchorIsHead = (forceHead == nil) and (Cfg.aim.aimPart ~= "body") or forceHead

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local char = plr.Character
            if char then
                local hum  = char:FindFirstChildOfClass("Humanoid")
                local hrp  = char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("Head")

                -- team check: skip teammates when enabled
                local isTeam = Cfg.aim.teamCheck and isTeammate(plr)

                if hum and hrp and head and hum.Health > 0 and not isTeam then
                    local anchor = anchorIsHead and head or hrp
                    local screen, onScreen = cam:WorldToViewportPoint(anchor.Position)
                    local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude

                    if onScreen and dist < bestDist and (ignoreWalls or visible(anchor)) then
                        best, bestDist = plr, dist
                    end
                end
            end
        end
    end
    return best
end

-- targetPartOf: returns the Part instance to aim at for a given player.
-- Uses currentAimPart (resolved once per target-lock) so random doesn't
-- re-roll every frame and cause the camera to flicker between head and body.
local function targetPartOf(plr)
    local char = plr and plr.Character
    if not char then return nil end
    local name = currentAimPart or "Head"
    return char:FindFirstChild(name) or char:FindFirstChild("HumanoidRootPart")
end

local function applyAim(dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end

    if not Cfg.aim.enabled then
        currentTarget  = nil
        currentAimPart = nil
        return
    end

    local newTarget = aimActive and findTarget() or nil

    -- When the target changes (new lock or lost lock), resolve aim bone once.
    -- This is especially important for "random": the dice is rolled here, not
    -- every frame, so the camera stays committed to whichever bone was chosen.
    if newTarget ~= currentTarget then
        currentTarget  = newTarget
        currentAimPart = currentTarget and resolveAimPartName() or nil
    end

    if currentTarget then
        local part = targetPartOf(currentTarget)
        if part then
            -- Predict target position ahead by velocity * prediction window.
            -- Higher prediction compensates for fast-moving Rivals characters.
            local predicted = part.Position + (part.Velocity * Cfg.aim.prediction)
            local goal      = CFrame.lookAt(cam.CFrame.Position, predicted)

            -- Smoothing: multiplier 50 (was 22) gives full lock speed range.
            -- At smooth=0.85, dt=0.0167 (60fps): alpha ≈ 0.51 per frame — snappy.
            -- At smooth=1.00, dt=0.0167:          alpha ≈ 0.57 per frame — very locked.
            -- At smooth=0.05 (minimum):            alpha ≈ 0.04 — slow tracking only.
            local alpha = 1 - math.exp(-Cfg.aim.smooth * 50 * dt)
            cam.CFrame  = cam.CFrame:Lerp(goal, math.clamp(alpha, 0, 0.98))
            -- capped at 0.98 (not 1.0) to avoid a hard snap on the first frame
            -- that could trigger anti-cheat detection from sudden CFrame jumps
        end
    end
end

-- Returns true if `input` matches the currently configured aim bind.
-- Handles both keyboard (Cfg.aim.key) and mouse buttons (Cfg.aim.mouseBtn).
local function isAimInput(input)
    if Cfg.aim.mouseBtn then
        -- match by UserInputType string stored in config
        local expected = Enum.UserInputType[Cfg.aim.mouseBtn]
        if expected and input.UserInputType == expected then
            return true
        end
    end
    -- keyboard fallback — always checked even if mouseBtn is also set
    -- (lets both work simultaneously if somehow both end up configured)
    return input.UserInputType == Enum.UserInputType.Keyboard
        and input.KeyCode == Cfg.aim.key
end

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if isAimInput(input) then
        if Cfg.aim.toggle then
            aimToggleState = not aimToggleState
            aimActive = aimToggleState
        else
            aimActive = true
        end
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if not Cfg.aim.toggle and isAimInput(input) then
        aimActive = false
    end
end))

-- ============================================================
-- silent aim: rewrite fire arguments to the target head
-- ============================================================

local silentTargetPos = nil

local function updateSilentTarget()
    if not Cfg.hacks.silent then
        silentTargetPos = nil
        return
    end

    -- silent aim has its own aimHead toggle that overrides the main aimPart
    -- for FOV scanning; we pass forceHead = Cfg.hacks.aimHead explicitly.
    local plr  = findTarget(Cfg.hacks.silentFov, true, Cfg.hacks.aimHead)
    local char = plr and plr.Character
    if not char then
        silentTargetPos = nil
        return
    end

    -- Part resolution: silent aim respects Cfg.hacks.aimHead first.
    -- If aimHead is off, fall through to the shared aimPart system
    -- (resolve once here — silent aim fires once per shot so no flicker risk).
    local partName
    if Cfg.hacks.aimHead then
        partName = "Head"
    else
        local mode = Cfg.aim.aimPart
        if mode == "head" then
            partName = "Head"
        elseif mode == "body" then
            partName = "HumanoidRootPart"
        else
            partName = math.random() < 0.6 and "Head" or "HumanoidRootPart"
        end
    end

    local part = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
    if part then
        silentTargetPos = part.Position + (part.Velocity * Cfg.aim.prediction)
    else
        silentTargetPos = nil
    end
end

if HOOK_SUPPORTED then
    local namecall
    local ok = pcall(function()
        namecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if Cfg.hacks.silent and silentTargetPos
                and (method == "FireServer" or method == "InvokeServer") then
                local args = table.pack(...)
                local changed = false
                for i = 1, args.n do
                    local v = args[i]
                    local ty = typeof(v)
                    if ty == "Vector3" then
                        args[i] = silentTargetPos
                        changed = true
                    elseif ty == "CFrame" then
                        args[i] = CFrame.new(silentTargetPos)
                        changed = true
                    elseif ty == "Ray" then
                        args[i] = Ray.new(v.Origin, silentTargetPos - v.Origin)
                        changed = true
                    end
                end
                if changed then
                    return namecall(self, table.unpack(args, 1, args.n))
                end
            end
            return namecall(self, ...)
        end)
    end)
    if not ok then
        HOOK_SUPPORTED = false
    end
end

-- ============================================================
-- noclip / wall walk
-- ============================================================

-- Full noclip: strip collisions every frame so the engine never
-- re-enables them, and do NOT apply floor sticking so the player
-- drifts freely in whatever direction the humanoid moves.
local function applyNoclip()
    local char = LP.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = false end)
        end
    end
end

-- Wall pierce: forces Cfg.aim.wallCheck off so aimbot and silent
-- aim both ignore walls.  applyPierce(false) restores the last
-- user-chosen wallCheck state.
local _savedWallCheck = Cfg.aim.wallCheck
function applyPierce(state)
    if state then
        _savedWallCheck = Cfg.aim.wallCheck
        Cfg.aim.wallCheck = false
    else
        Cfg.aim.wallCheck = _savedWallCheck
    end
end

-- ============================================================
-- loops
-- ============================================================

track(RunService.RenderStepped:Connect(function(dt)
    pcall(updateESP)
    pcall(applyAim, dt)
    pcall(updateSilentTarget)

    -- wall walk and noclip both route through updateMovement.
    -- noclip additionally strips collisions every frame so the
    -- engine cannot re-enable them between physics steps.
    if Cfg.hacks.wallWalk or Cfg.hacks.noclip then
        pcall(updateMovement)
        if Cfg.hacks.noclip then
            pcall(applyNoclip)
        end
    end

    if fovCircle then
        local cam = Workspace.CurrentCamera
        local showCircle = Cfg.aim.enabled and aimActive and cam ~= nil
        fovCircle.Visible = showCircle
        if showCircle then
            local vp = cam.ViewportSize
            fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
            fovCircle.Radius = Cfg.aim.fov / 2
            fovCircle.Color = BoxColor
        end
    end
end))

track(Players.PlayerRemoving:Connect(function(plr)
    local o = espCache[plr]
    if o then
        destroyAll(o)
        espCache[plr] = nil
    end
end))

-- ============================================================
-- window behaviour
-- ============================================================

do
    local dragging, dragStart, startPos = false, nil, nil

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Holder.Position
        end
    end)

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Holder.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
end

local menuOpen = true

local function setMenu(open)
    menuOpen = open
    if open then
        ROOT.Enabled = true
        tw(uiScale, { Scale = Cfg.uiScale }, 0.24, Enum.EasingStyle.Back)
    else
        local t = tw(uiScale, { Scale = 0.001 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            if not menuOpen then ROOT.Enabled = false end
        end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() setMenu(false) end)
OffBtn.MouseButton1Click:Connect(function() panic() end)

OffBtn.MouseEnter:Connect(function() tw(OffBtn, { BackgroundColor3 = Theme.rowHover }, 0.14) end)
OffBtn.MouseLeave:Connect(function() tw(OffBtn, { BackgroundColor3 = Theme.panelAlt }, 0.16) end)

CloseBtn.MouseEnter:Connect(function()
    tw(CloseBtn, { BackgroundColor3 = Color3.fromRGB(46, 20, 22) }, 0.14)
    tw(CloseBtn, { TextColor3 = Theme.danger }, 0.14)
end)
CloseBtn.MouseLeave:Connect(function()
    tw(CloseBtn, { BackgroundColor3 = Theme.panelAlt }, 0.16)
    tw(CloseBtn, { TextColor3 = Theme.dim }, 0.16)
end)

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Cfg.menuKey then
        setMenu(not menuOpen)
    end
end))

selectTab("ESP")
tw(uiScale, { Scale = Cfg.uiScale }, 0.38, Enum.EasingStyle.Back)

task.defer(function()
    if ActiveTabName then selectTab(ActiveTabName) end
end)

-- ============================================================
-- cleanup
-- ============================================================

function destroy()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    for _, o in pairs(espCache) do
        destroyAll(o)
    end
    espCache = {}

    if fovCircle then pcall(function() fovCircle:Remove() end) end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local hl = plr.Character:FindFirstChild("__owl_chams")
            if hl then pcall(function() hl:Destroy() end) end
        end
    end

    applyPierce(false)
    applyFullbright(false)
    pcall(function() ROOT:Destroy() end)
    ENV.__rivalsOwl = nil
end

ENV.__rivalsOwl = {
    destroy = destroy,
    config  = Cfg,
    panic   = panic,
}

print("[rivals-owl] v3 loaded - menu: " .. Cfg.menuKey.Name
    .. " | drawing: " .. tostring(DRAW_SUPPORTED)
    .. " | hook: " .. tostring(HOOK_SUPPORTED))
