--[[
    RIVALS - owl build v12
    black theme, grouped sections, silent aim, wall walk, panic switch
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

-- declared early so panic() and every loop share one binding
local aimActive = false
local aimToggleState = false

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
        key         = Enum.KeyCode.E,
        smooth      = 0.45,
        fov         = 140,
        prediction  = 0.12,
        wallCheck   = true,
        teamCheck   = true,
        headOnly    = true,
        pingPredict = false,
        ignoreForcefield = true,
        sticky      = true,
        method      = "camera",
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
        debugRemotes = false,
        godmode     = false,
        noHitbox    = false,
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

local function deepCopy(t)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            out[k] = deepCopy(v)
        else
            out[k] = v
        end
    end
    return out
end

local DEFAULTS = deepCopy(Cfg)

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
        -- a hand-edited or version-skewed config must not reach Color3.fromRGB
        if type(Cfg.esp.color) ~= "table"
            or type(Cfg.esp.color[1]) ~= "number"
            or type(Cfg.esp.color[2]) ~= "number"
            or type(Cfg.esp.color[3]) ~= "number" then
            Cfg.esp.color = { 235, 240, 245 }
        end
        if type(Cfg.uiScale) ~= "number" then Cfg.uiScale = 1 end
        if type(Cfg.aim.method) ~= "string" then Cfg.aim.method = "camera" end
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
                smooth      = Cfg.aim.smooth,
                fov         = Cfg.aim.fov,
                prediction  = Cfg.aim.prediction,
                wallCheck   = Cfg.aim.wallCheck,
                teamCheck   = Cfg.aim.teamCheck,
                headOnly    = Cfg.aim.headOnly,
                pingPredict = Cfg.aim.pingPredict,
                ignoreForcefield = Cfg.aim.ignoreForcefield,
                sticky      = Cfg.aim.sticky,
                method      = Cfg.aim.method,
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
    Size = UDim2.fromOffset(64, 46),
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
    Position = UDim2.fromOffset(92, 0),
    BackgroundTransparency = 1,
    Font = FONT,
    Text = "owl v12",
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
    Text = "esp / aimbot / health / wall shoot / misc / settings",    TextColor3 = Theme.dim,
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

-- every input registers here so config reload / reset can re-sync visuals
local Controls = {}

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

    local api = {
        set = function(v)
            value = v and true or false
            render(true)
        end,
        get = function() return value end,
    }
    table.insert(Controls, { page = parent.Name, label = name, set = api.set })
    return api
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

    local api = {
        set = function(v)
            v = math.clamp(v or min, min, max)
            if decimals == 0 then v = math.floor(v + 0.5) end
            local f = (v - min) / (max - min)
            fill.Size = UDim2.new(f, 0, 1, 0)
            knob.Position = UDim2.new(f, -5, 0.5, -5)
            valueLabel.Text = string.format(fmt, v)
        end,
    }
    table.insert(Controls, { page = parent.Name, label = name, set = api.set })
    return api
end

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

    local btn = new("TextButton", {
        Size = UDim2.fromOffset(88, 22),
        Position = UDim2.new(1, -100, 0.5, -11),
        BackgroundColor3 = Theme.track,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = FONT_MONO,
        Text = key.Name,
        TextColor3 = Theme.accent,
        TextSize = 12,
        ZIndex = 5,
    }, row)
    corner(btn, 5)

    local listening = false

    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
        tw(btn, { TextColor3 = Theme.dim }, 0.12)
    end)

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if not listening or processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            local k = input.KeyCode
            btn.Text = k.Name
            tw(btn, { TextColor3 = Theme.accent }, 0.12)
            changed(k)
        end
    end))

    local api = { set = function(k) if k and k.Name then btn.Text = k.Name end end }
    table.insert(Controls, { page = parent.Name, label = name, set = api.set })
    return api
end

-- label -> current config value, consumed by syncControls()
local ValueMap = {
    ["ESP|ESP enabled"]          = function() return Cfg.esp.enabled end,
    ["ESP|Box"]                  = function() return Cfg.esp.box end,
    ["ESP|Name"]                 = function() return Cfg.esp.name end,
    ["ESP|Distance"]             = function() return Cfg.esp.distance end,
    ["ESP|Tracer"]               = function() return Cfg.esp.tracer end,
    ["ESP|Chams (highlight)"]    = function() return Cfg.esp.chams end,
    ["ESP|Team check"]           = function() return Cfg.esp.teamCheck end,
    ["ESP|Max distance"]         = function() return Cfg.esp.maxDist end,

    ["Aimbot|Aimbot enabled"]    = function() return Cfg.aim.enabled end,
    ["Aimbot|Toggle mode"]       = function() return Cfg.aim.toggle end,
    ["Aimbot|Aim key"]           = function() return Cfg.aim.key end,
    ["Aimbot|Smoothing"]         = function() return Cfg.aim.smooth end,
    ["Aimbot|FOV radius"]        = function() return Cfg.aim.fov end,
    ["Aimbot|Prediction"]        = function() return Cfg.aim.prediction end,
    ["Aimbot|Wall check"]        = function() return Cfg.aim.wallCheck end,
    ["Aimbot|Team check"]        = function() return Cfg.aim.teamCheck end,
    ["Aimbot|Head only"]         = function() return Cfg.aim.headOnly end,
    ["Aimbot|Ignore forcefield"] = function() return Cfg.aim.ignoreForcefield end,
    ["Aimbot|Sticky target"]     = function() return Cfg.aim.sticky end,
    ["Aimbot|Ping prediction"]   = function() return Cfg.aim.pingPredict end,
    ["Aimbot|Mouse method"]      = function() return Cfg.aim.method == "mouse" end,

    ["Health|Health enabled"]    = function() return Cfg.health.enabled end,
    ["Health|Bar"]               = function() return Cfg.health.bar end,
    ["Health|Numbers"]           = function() return Cfg.health.numbers end,
    ["Health|Green to red gradient"] = function() return Cfg.health.gradient end,
    ["Health|Bar width"]         = function() return Cfg.health.barWidth end,
    ["Health|Low HP highlight"]  = function() return Cfg.health.lowHp end,
    ["Health|Threshold %"]       = function() return Cfg.health.lowHpValue end,
    ["Health|God mode (no damage)"] = function() return Cfg.hacks.godmode end,
    ["Health|No hitbox (untouchable)"] = function() return Cfg.hacks.noHitbox end,

    ["Wall Shoot|Silent aim (wall shoot)"] = function() return Cfg.hacks.silent end,
    ["Wall Shoot|Silent FOV"]    = function() return Cfg.hacks.silentFov end,
    ["Wall Shoot|Aim head"]      = function() return Cfg.hacks.aimHead end,
    ["Wall Shoot|Debug remote names"] = function() return Cfg.hacks.debugRemotes end,
    ["Wall Shoot|Aimbot ignores walls"] = function() return not Cfg.aim.wallCheck end,
    ["Wall Shoot|Wall walk"]     = function() return Cfg.hacks.wallWalk end,
    ["Wall Shoot|Noclip (free fall)"] = function() return Cfg.hacks.noclip end,

    ["Misc|Fullbright"]          = function() return Cfg.hacks.fullbright end,
    ["Misc|Camera FOV"]          = function() return Cfg.hacks.camFov end,

    ["Settings|Menu key"]        = function() return Cfg.menuKey end,
    ["Settings|UI scale"]        = function() return math.floor(Cfg.uiScale * 100) end,
}

local function syncControls()
    for _, c in ipairs(Controls) do
        local get = ValueMap[c.page .. "|" .. c.label]
        if get then
            pcall(c.set, get())
        end
    end
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

-- forward declarations: UI callbacks below run long after these locals exist
local restoreCollide, applyFullbright, panic, destroy

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
    uiScale.Scale = Cfg.uiScale
    syncControls()
    KeyHint.Text = "[" .. Cfg.menuKey.Name .. "]"
    notify("config reloaded")
end)
button(ConfigTab, "Reset to defaults", Theme.panelAlt, function()
    deepMerge(Cfg, deepCopy(DEFAULTS))
    aimActive = false
    aimToggleState = false
    uiScale.Scale = Cfg.uiScale
    restoreCollide()
    applyFullbright(false)
    syncControls()
    KeyHint.Text = "[" .. Cfg.menuKey.Name .. "]"
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
keybind(AimTab, "Aim key", Cfg.aim.key, function(k) Cfg.aim.key = k end)

sectionHeader(AimTab, "behaviour")
slider(AimTab, "Smoothing", 0.05, 1, Cfg.aim.smooth, 2, function(v) Cfg.aim.smooth = v end)
slider(AimTab, "FOV radius", 20, 500, Cfg.aim.fov, 0, function(v) Cfg.aim.fov = v end)
slider(AimTab, "Prediction", 0, 0.4, Cfg.aim.prediction, 3, function(v) Cfg.aim.prediction = v end)

sectionHeader(AimTab, "targeting")
toggle(AimTab, "Wall check", Cfg.aim.wallCheck, function(v) Cfg.aim.wallCheck = v end)
toggle(AimTab, "Team check", Cfg.aim.teamCheck, function(v) Cfg.aim.teamCheck = v end)
toggle(AimTab, "Head only", Cfg.aim.headOnly, function(v) Cfg.aim.headOnly = v end)
toggle(AimTab, "Ignore forcefield", Cfg.aim.ignoreForcefield, function(v) Cfg.aim.ignoreForcefield = v end)
toggle(AimTab, "Sticky target", Cfg.aim.sticky, function(v) Cfg.aim.sticky = v end)
toggle(AimTab, "Ping prediction", Cfg.aim.pingPredict, function(v) Cfg.aim.pingPredict = v end)
toggle(AimTab, "Mouse method", Cfg.aim.method == "mouse", function(v)
    Cfg.aim.method = v and "mouse" or "camera"
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

sectionHeader(HealthTab, "protection")
toggle(HealthTab, "God mode (no damage)", Cfg.hacks.godmode, function(v)
    Cfg.hacks.godmode = v
    notify(v and "god mode on" or "god mode off")
end)
toggle(HealthTab, "No hitbox (untouchable)", Cfg.hacks.noHitbox, function(v)
    Cfg.hacks.noHitbox = v
    notify(v and "hitbox stripped" or "hitbox restored")
end)

-- WALL SHOOT ------------------------------------------------

sectionHeader(WallTab, "wall shooting")
toggle(WallTab, "Silent aim (wall shoot)", Cfg.hacks.silent, function(v)
    Cfg.hacks.silent = v
    notify(v and "wall shoot on" or "wall shoot off")
end)
slider(WallTab, "Silent FOV", 40, 600, Cfg.hacks.silentFov, 0, function(v) Cfg.hacks.silentFov = v end)
toggle(WallTab, "Aim head", Cfg.hacks.aimHead, function(v) Cfg.hacks.aimHead = v end)
toggle(WallTab, "Debug remote names", Cfg.hacks.debugRemotes, function(v) Cfg.hacks.debugRemotes = v end)
toggle(WallTab, "Aimbot ignores walls", not Cfg.aim.wallCheck, function(v)
    Cfg.aim.wallCheck = not v
    syncControls()
end)

sectionHeader(WallTab, "movement")
toggle(WallTab, "Wall walk", Cfg.hacks.wallWalk, function(v)
    Cfg.hacks.wallWalk = v
    if v then Cfg.hacks.noclip = false end
    syncControls()
    notify(v and "wall walk on" or "wall walk off")
end)
toggle(WallTab, "Noclip (free fall)", Cfg.hacks.noclip, function(v)
    Cfg.hacks.noclip = v
    if v then Cfg.hacks.wallWalk = false end
    syncControls()
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

applyFullbright = function(state)
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

-- hitbox state: CanQuery=false makes server raycasts skip your parts entirely,
-- which is the only damage path a client can actually take away from the server
local savedQuery = {}

local function restoreHitbox()
    for part, state in pairs(savedQuery) do
        if part and part.Parent then
            pcall(function()
                part.CanQuery = state.query
                part.CanTouch = state.touch
            end)
        end
    end
    savedQuery = {}
end

local moveParams = RaycastParams.new()
do
    local ok = pcall(function() moveParams.FilterType = Enum.RaycastFilterType.Exclude end)
    if not ok then
        pcall(function() moveParams.FilterType = Enum.RaycastFilterType.Blacklist end)
    end
    moveParams.IgnoreWater = true
end

restoreCollide = function()
    for part, value in pairs(savedCollide) do
        if part and part.Parent then
            pcall(function() part.CanCollide = value end)
        end
    end
    savedCollide = {}
    savedForChar = nil
end

local function stripCollide(char, hrp, hrpSolid)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if savedCollide[part] == nil then
                savedCollide[part] = part.CanCollide
            end
            if part == hrp then
                -- the root stays solid most of the time so the Humanoid keeps a
                -- floor contact - no floor means no jump, no jumppad
                part.CanCollide = hrpSolid
            else
                part.CanCollide = false
            end
        end
    end
end

-- Keeps the character on the ground with collisions off, so walls are walkable
-- without dropping through the floor.
local function stickFloor(char, hrp, hum)
    if hum then
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.FallingDown then
            return
        end
    end
    local vel = hrp.AssemblyLinearVelocity
    if vel.Y > 0.5 then return end

    local ignore = { char }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then table.insert(ignore, plr.Character) end
    end
    moveParams.FilterDescendantsInstances = ignore
    local origin = hrp.Position + Vector3.new(0, 3, 0)
    local result = Workspace:Raycast(origin, Vector3.new(0, -14, 0), moveParams)
    if not result then return end

    local targetY = result.Position.Y + 2.8
    local delta = hrp.Position.Y - targetY
    if delta > 6 or delta < -0.6 then return end

    local spin = hrp.CFrame - hrp.CFrame.Position
    pcall(function()
        hrp.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z) * spin
        hrp.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
    end)
end

local hrpGhostUntil = 0

local function updateMovement()
    local char = LP.Character
    if not char then
        if savedForChar then restoreCollide() end
        hrpGhostUntil = 0
        return
    end

    local walk = Cfg.hacks.wallWalk
    local free = Cfg.hacks.noclip

    if not (walk or free) then
        if savedForChar then restoreCollide() end
        hrpGhostUntil = 0
        return
    end

    if savedForChar and savedForChar ~= char then restoreCollide() end
    savedForChar = char

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if free then
        stripCollide(char, hrp, false)
        return
    end

    -- wall walk: ghost the root only while actually pushing into geometry, so
    -- the Humanoid keeps its floor contact (jump input and jumppads need it)
    local now = os.clock()
    if hum.MoveDirection.Magnitude > 0.1 then
        local ignore = { char }
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and plr.Character ~= char then
                table.insert(ignore, plr.Character)
            end
        end
        moveParams.FilterDescendantsInstances = ignore
        local hit = Workspace:Raycast(hrp.Position, hum.MoveDirection * 3.5, moveParams)
        if hit then hrpGhostUntil = now + 0.2 end
    end

    local ghosted = now <= hrpGhostUntil
    stripCollide(char, hrp, not ghosted)
    if ghosted then
        stickFloor(char, hrp, hum)
    end
end

-- God mode: own-server authority is a lie, so this does the three things a
-- client actually controls - refuse local TakeDamage/BreakJoints, block writes
-- that lower our own Health, and top the bar back up every frame.
local function updateGodmode()
    if not Cfg.hacks.noHitbox then
        if next(savedQuery) then restoreHitbox() end
    end
    if not Cfg.hacks.godmode then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.BreakJointsOnDeath = false
        hum.RequiresNeck = false
    end)
    if hum.MaxHealth > 0 and hum.Health < hum.MaxHealth then
        pcall(function() hum.Health = hum.MaxHealth end)
    end
end

-- Strip the hitbox on the parts the server raycasts against. CanQuery/CanTouch
-- changes replicate from the owning client, so hitscan weapons pass through.
local hitboxAt = 0
local function updateHitboxProtection()
    if not Cfg.hacks.noHitbox then
        if next(savedQuery) then restoreHitbox() end
        return
    end
    local now = os.clock()
    if now - hitboxAt < 0.1 then return end
    hitboxAt = now
    local char = LP.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if savedQuery[part] == nil then
                savedQuery[part] = { query = part.CanQuery, touch = part.CanTouch }
            end
            if part.CanQuery then part.CanQuery = false end
            if part.CanTouch then part.CanTouch = false end
        end
    end
end

-- ============================================================
-- panic
-- ============================================================

panic = function()
    Cfg.esp.enabled = false
    Cfg.health.enabled = false
    Cfg.aim.enabled = false
    Cfg.hacks.silent = false
    Cfg.hacks.wallWalk = false
    Cfg.hacks.noclip = false
    Cfg.hacks.fullbright = false
    Cfg.hacks.godmode = false
    Cfg.hacks.noHitbox = false
    aimActive = false
    aimToggleState = false
    restoreCollide()
    restoreHitbox()
    applyFullbright(false)
    syncControls()
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

    if Cfg.esp.enabled and (Cfg.esp.chams or lowHp)
        and not (Cfg.esp.teamCheck and isTeammate(plr)) then
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

aimActive = false
local currentTarget = nil

local fovCircle = newDrawing("Circle")
if fovCircle then
    fovCircle.Thickness = 1
    fovCircle.NumSides = 64
    fovCircle.Filled = false
    fovCircle.Color = BoxColor
    fovCircle.Transparency = 0.35
    fovCircle.Visible = false
end

local aimParams, aimParamsAt = nil, 0

local function raycastParams()
    -- rebuild at 4 Hz; characters come and go but a wall stays a wall
    local now = os.clock()
    if aimParams and now - aimParamsAt < 0.25 then
        return aimParams
    end
    local params = RaycastParams.new()
    local ok = pcall(function() params.FilterType = Enum.RaycastFilterType.Exclude end)
    if not ok then
        pcall(function() params.FilterType = Enum.RaycastFilterType.Blacklist end)
    end
    local ignore = {}
    if LP.Character then table.insert(ignore, LP.Character) end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then table.insert(ignore, plr.Character) end
    end
    if Workspace.CurrentCamera then table.insert(ignore, Workspace.CurrentCamera) end
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    aimParams, aimParamsAt = params, now
    return params
end

local function visible(part)
    if not Cfg.aim.wallCheck then return true end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local result = Workspace:Raycast(origin, part.Position - origin, raycastParams())
    return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

-- ============================================================
-- aim core (owl-hub target model): ping prediction, forcefield
-- skip, sticky lock, camera or mouse response
-- ============================================================

local function moveMouse(dx, dy)
    if type(mousemoverel) == "function" then
        pcall(mousemoverel, dx, dy)
        return true
    end
    local ok, m = pcall(function() return getgenv().mouse end)
    if ok and type(m) == "table" and type(m.MoveRel) == "function" then
        pcall(function() m:MoveRel(dx, dy) end)
        return true
    end
    return false
end

local function pingSeconds(plr)
    local ok, ping = pcall(function() return plr:GetNetworkPing() end)
    if ok and type(ping) == "number" and ping > 0 then
        return math.clamp(ping, 0, 0.35)
    end
    return 0
end

local function hasForcefield(char)
    return char:FindFirstChildOfClass("ForceField") ~= nil
end

local function predictPos(plr, part)
    local scale = Cfg.aim.prediction
    if Cfg.aim.pingPredict then
        scale = scale + pingSeconds(plr)
    end
    return part.Position + (part.Velocity * scale)
end

local function targetPartOf(plr)
    local char = plr and plr.Character
    if not char then return nil end
    if Cfg.aim.headOnly then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function findTarget(fovOverride, ignoreWalls, headOnly)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local limit = fovOverride or Cfg.aim.fov
    local best, bestDist = nil, limit
    local wantHead = headOnly
    if wantHead == nil then wantHead = Cfg.aim.headOnly end

    -- sticky lock: a live target keeps priority until it leaves a wider cone
    if Cfg.aim.sticky and not fovOverride and currentTarget and currentTarget ~= LP then
        local char = currentTarget.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local part = char and (wantHead and char:FindFirstChild("Head")
            or char:FindFirstChild("HumanoidRootPart"))
        if hum and hum.Health > 0 and part
            and not (Cfg.aim.teamCheck and isTeammate(currentTarget))
            and not (Cfg.aim.ignoreForcefield and hasForcefield(char))
            and (ignoreWalls or visible(part)) then
            local screen, onScreen = cam:WorldToViewportPoint(predictPos(currentTarget, part))
            local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
            if onScreen and dist < limit * 1.6 then
                return currentTarget
            end
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("Head")
                local teammate = Cfg.aim.teamCheck and isTeammate(plr)
                local shielded = Cfg.aim.ignoreForcefield and hasForcefield(char)

                if hum and hrp and head and hum.Health > 0
                    and not teammate and not shielded then
                    local part = wantHead and head or hrp
                    local aimAt = predictPos(plr, part)
                    local screen, onScreen = cam:WorldToViewportPoint(aimAt)
                    local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude

                    if onScreen and dist < bestDist and (ignoreWalls or visible(part)) then
                        best, bestDist = plr, dist
                    end
                end
            end
        end
    end
    return best
end

local function applyAim(dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end

    if not Cfg.aim.enabled then
        currentTarget = nil
        return
    end

    currentTarget = aimActive and findTarget() or nil
    if not currentTarget then return end

    local part = targetPartOf(currentTarget)
    if not part then return end

    local goalPos = predictPos(currentTarget, part)

    if Cfg.aim.method == "mouse" then
        local screen, onScreen = cam:WorldToViewportPoint(goalPos)
        if onScreen and screen.Z > 0 then
            local vp = cam.ViewportSize
            local dx = screen.X - vp.X / 2
            local dy = screen.Y - vp.Y / 2
            local step = math.clamp(Cfg.aim.smooth, 0.02, 1) * 0.34
            if moveMouse(dx * step, dy * step) then return end
            -- executor has no mouse API: fall through to camera lock
        end
    end

    local goal = CFrame.lookAt(cam.CFrame.Position, goalPos)
    local alpha = 1 - math.exp(-Cfg.aim.smooth * 22 * dt)
    cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(alpha, 0, 1))
end

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Cfg.aim.key then
        if Cfg.aim.toggle then
            aimToggleState = not aimToggleState
            aimActive = aimToggleState
        else
            aimActive = true
        end
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if not Cfg.aim.toggle and input.KeyCode == Cfg.aim.key then
        aimActive = false
    end
end))

-- ============================================================
-- silent aim: rewrite fire arguments to the target head
-- ============================================================

local silentTargetPos = nil
local silentTargetPart = nil
local hookRestore = nil
local restoreNamecall = nil

local function updateSilentTarget()
    if not Cfg.hacks.silent then
        silentTargetPos = nil
        silentTargetPart = nil
        return
    end
    local plr = findTarget(Cfg.hacks.silentFov, true, Cfg.hacks.aimHead)
    local char = plr and plr.Character
    local part = char and (Cfg.hacks.aimHead and char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart"))
    if part then
        silentTargetPos = predictPos(plr, part)
        silentTargetPart = part
    else
        silentTargetPos = nil
        silentTargetPart = nil
    end
end

if HOOK_SUPPORTED then
    -- origin the rewritten direction is measured from: camera when present, else head
    local function shotOrigin()
        local cam = Workspace.CurrentCamera
        if cam then return cam.CFrame.Position end
        local char = LP.Character
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
        return head and head.Position or Vector3.new(0, 0, 0)
    end

    local lastLoggedRemote = nil

    local namecall
    local ok = pcall(function()
        namecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if Cfg.hacks.godmode and (method == "TakeDamage" or method == "BreakJoints") then
                local own = false
                pcall(function()
                    own = typeof(self) == "Instance" and self.Parent == LP.Character
                end)
                if own then return end
            end
            if Cfg.hacks.silent and silentTargetPos
                and (method == "FireServer" or method == "InvokeServer") then
                local remoteName = ""
                pcall(function()
                    if typeof(self) == "Instance" then remoteName = self.Name end
                end)
                local skipRemote = remoteName:find("[Mm]ove")
                    or remoteName:find("[Ww]alk")
                    or remoteName:find("[Ii]nput")
                    or remoteName:find("[Dd]ash")
                    or remoteName:find("[Cc]hat")
                if skipRemote then
                    return namecall(self, ...)
                end

                local target = silentTargetPos
                local origin = shotOrigin()
                local args = table.pack(...)
                local changed = false
                for i = 1, args.n do
                    local v = args[i]
                    local ty = typeof(v)
                    if ty == "Vector3" then
                        -- short vectors are directions, long ones are world positions
                        if v.Magnitude <= 4 then
                            local dir = target - origin
                            if dir.Magnitude > 0.001 then
                                args[i] = dir.Unit * v.Magnitude
                            else
                                args[i] = target
                            end
                        else
                            args[i] = target
                        end
                        changed = true
                    elseif ty == "CFrame" then
                        args[i] = CFrame.lookAt(v.Position, target)
                        changed = true
                    elseif ty == "Ray" then
                        local dir = target - v.Origin
                        if dir.Magnitude > 0.001 then
                            args[i] = Ray.new(v.Origin, dir)
                            changed = true
                        end
                    elseif ty == "table" then
                        -- some games ship a hit table: {pos=, dir=, part=}
                        local touched = false
                        for k, inner in pairs(v) do
                            local it = typeof(inner)
                            if it == "Vector3" then
                                local dir = target - origin
                                v[k] = inner.Magnitude <= 4
                                    and (dir.Magnitude > 0.001 and (dir.Unit * inner.Magnitude) or target)
                                    or target
                                touched = true
                            elseif it == "CFrame" then
                                v[k] = CFrame.lookAt(inner.Position, target)
                                touched = true
                            elseif it == "Instance" and inner:IsA("BasePart") then
                                if silentTargetPart then v[k] = silentTargetPart end
                                touched = true
                            end
                        end
                        if touched then changed = true end
                    elseif ty == "Instance" and silentTargetPart and v:IsA("BasePart") then
                        -- bare part argument: only swap parts that belong to a player
                        local model = v:FindFirstAncestorOfClass("Model")
                        if model and Players:GetPlayerFromCharacter(model) then
                            args[i] = silentTargetPart
                            changed = true
                        end
                    end
                end
                if changed then
                    if Cfg.hacks.debugRemotes and remoteName ~= lastLoggedRemote then
                        lastLoggedRemote = remoteName
                        notify("wall shoot -> " .. remoteName, 2)
                    end
                    return namecall(self, table.unpack(args, 1, args.n))
                end
            end
            return namecall(self, ...)
        end)
    end)
    if not ok then
        HOOK_SUPPORTED = false
    else
        restoreNamecall = function()
            if type(namecall) == "function" then
                pcall(function() hookmetamethod(game, "__namecall", namecall) end)
            end
        end
    end

    -- mouse level: games that read mouse.Hit / mouse.UnitRay get a target-locked value
    pcall(function()
        if type(newcclosure) ~= "function" or type(setreadonly) ~= "function" then
            return
        end
        local mt = getrawmetatable(game)
        if not mt then return end
        local oldIndex = mt.__index
        local wasLocked = isreadonly(mt)
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, key)
            -- the key gate matters: testing self:IsA() here would re-enter this
            -- hook for "IsA" and blow the stack every property read
            if Cfg.hacks.silent and silentTargetPos
                and (key == "Hit" or key == "UnitRay" or key == "Target")
                and typeof(self) == "Instance" and self.ClassName == "Mouse" then
                if key == "Hit" then
                    local hit = oldIndex(self, key)
                    local dir = (hit and hit.LookVector) or Vector3.new(0, 0, -1)
                    return CFrame.lookAt(silentTargetPos, silentTargetPos + dir)
                elseif key == "UnitRay" then
                    local ray = oldIndex(self, key)
                    local dir = silentTargetPos - ray.Origin
                    if dir.Magnitude > 0.001 then
                        return Ray.new(ray.Origin, dir.Unit)
                    end
                    return ray
                elseif key == "Target" then
                    if silentTargetPart then return silentTargetPart end
                end
            end
            return oldIndex(self, key)
        end)
        setreadonly(mt, wasLocked)

        -- second metamethod: refuse Health writes that lower our own bar
        local oldNewIndex = mt.__newindex
        if type(oldNewIndex) == "function" then
            setreadonly(mt, false)
            mt.__newindex = newcclosure(function(self, key, value)
                if Cfg.hacks.godmode and key == "Health"
                    and typeof(self) == "Instance" and self.ClassName == "Humanoid" then
                    local owner = self.Parent
                    if owner == LP.Character then
                        local max = self.MaxHealth
                        if type(value) == "number" and type(max) == "number" and value < max then
                            value = max
                        end
                    end
                end
                return oldNewIndex(self, key, value)
            end)
            setreadonly(mt, wasLocked)
        end

        hookRestore = function()
            local ok = pcall(function()
                setreadonly(mt, false)
                mt.__index = oldIndex
                if type(oldNewIndex) == "function" then
                    mt.__newindex = oldNewIndex
                end
                setreadonly(mt, wasLocked)
            end)
            return ok
        end
    end)
end

-- ============================================================
-- loops
-- ============================================================

track(RunService.RenderStepped:Connect(function(dt)
    pcall(updateESP)
    pcall(applyAim, dt)
    pcall(updateSilentTarget)
    pcall(updateMovement)
    pcall(updateGodmode)
    pcall(updateHitboxProtection)

    if fovCircle then
        local cam = Workspace.CurrentCamera
        local showCircle = Cfg.aim.enabled and aimActive and cam ~= nil
        fovCircle.Visible = showCircle
        if showCircle then
            local vp = cam.ViewportSize
            fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
            fovCircle.Radius = Cfg.aim.fov
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
    local cam = Workspace.CurrentCamera
    if cam then cam.FieldOfView = Cfg.hacks.camFov end
    if Cfg.hacks.fullbright then applyFullbright(true) end
end)

-- ============================================================
-- cleanup
-- ============================================================

destroy = function()
    Cfg.aim.enabled = false
    Cfg.hacks.silent = false
    Cfg.hacks.wallWalk = false
    Cfg.hacks.noclip = false
    Cfg.hacks.godmode = false
    Cfg.hacks.noHitbox = false
    aimActive = false
    aimToggleState = false
    silentTargetPos = nil
    silentTargetPart = nil

    if hookRestore then
        pcall(hookRestore)
        hookRestore = nil
    end
    if restoreNamecall then
        pcall(restoreNamecall)
        restoreNamecall = nil
    end

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

    restoreCollide()
    restoreHitbox()
    applyFullbright(false)
    pcall(function() ROOT:Destroy() end)
    ENV.__rivalsOwl = nil
end

ENV.__rivalsOwl = {
    destroy = destroy,
    config  = Cfg,
    panic   = panic,
}

print("[rivals-owl] v12 loaded - menu: " .. Cfg.menuKey.Name
    .. " | tabs: " .. tostring(#TabOrder)
    .. " | drawing: " .. tostring(DRAW_SUPPORTED)
    .. " | hook: " .. tostring(HOOK_SUPPORTED))
