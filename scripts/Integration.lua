--[[
    /////////////////////////////////////////////////////////////////////////
    //                                                                     //
    //      HAIRKEY CLIENT - TITAN EDITION (v3.0)                          //
    //      "The Ultimate Gateway for Professional Scripts"                //
    //                                                                     //
    //      [FEATURES]                                                     //
    //      > Encrypted Local Storage (XOR)                                //
    //      > Boot Sequence Animation                                      //
    //      > Floating Toggle Widget                                       //
    //      > Server Latency Check                                         //
    //      > Particle Neural Network Background                           //
    //      > Full Sound FX System                                         //
    //                                                                     //
    //      [AUTHOR] HairKey System Dev Team                               //
    //                                                                     //
    /////////////////////////////////////////////////////////////////////////
]]
--[[
    [HOW TO USE]
    local KeySystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/HairBaconGamming/KeySystem/refs/heads/main/scripts/Integration.lua"))()
    
    KeySystem.init({
        ApplicationName = "HUB NAME",
        OnKeyCorrect = function()
            loadstring(...)()
        end
    })
]]

local HairKey = {}
HairKey.__index = HairKey

-- ==============================================================================
-- [1] SERVICES & VARIABLES
-- ==============================================================================
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Configuration
local CFG = {
    Domain = "https://hairkey.onrender.com",
    AppName = "TITAN HUB",
    FileName = "HairKey_Titan_Auth.bin",
    Theme = {
        Main = Color3.fromRGB(0, 0, 0),
        Panel = Color3.fromRGB(12, 12, 15),
        Accent = Color3.fromRGB(0, 255, 128), -- Neon Green
        Accent2 = Color3.fromRGB(0, 150, 255), -- Neon Blue
        Error = Color3.fromRGB(255, 40, 40),
        Text = Color3.fromRGB(240, 240, 240),
        TextDim = Color3.fromRGB(150, 150, 150)
    },
    Sounds = {
        Hover = 4590662766,
        Click = 4590657391,
        Success = 5153734232,
        Error = 4590608263,
        Boot = 6276409843
    }
}

-- ==============================================================================
-- [2] SECURITY & NETWORKING UTILS
-- ==============================================================================

local Crypt = {}

-- Simple XOR Encryption for Local File
function Crypt.XOR(data, key)
    local output = {}
    for i = 1, #data do
        local b = string.byte(data, i)
        local k = string.byte(key, (i - 1) % #key + 1)
        table.insert(output, string.char(bit32.bxor(b, k)))
    end
    return table.concat(output)
end

function Crypt.Save(keyData)
    if not writefile then return end
    local json = HttpService:JSONEncode(keyData)
    local encrypted = Crypt.XOR(json, "HAIRKEY_TITAN_SECRET_KEY_999") -- XOR Key
    writefile(CFG.FileName, encrypted)
end

function Crypt.Load()
    if not isfile or not isfile(CFG.FileName) then return nil end
    local encrypted = readfile(CFG.FileName)
    local decrypted = Crypt.XOR(encrypted, "HAIRKEY_TITAN_SECRET_KEY_999")
    local success, data = pcall(function() return HttpService:JSONDecode(decrypted) end)
    if success then return data else return nil end
end

local Network = {}

function Network.Request(url, method, body)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not requestFunc then
        return {Body = nil, StatusCode = 0}
    end

    local success, result = pcall(function()
        return requestFunc({
            Url = url,
            Method = method or "GET",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "HairKey-Client/3.0"
            },
            Body = body and HttpService:JSONEncode(body) or nil
        })
    end)

    if success then return result else return {Body = nil, StatusCode = 0} end
end

-- ==============================================================================
-- [3] UI LIBRARY (VISUAL ENGINE)
-- ==============================================================================

local UI = {}
UI.Screen = nil
UI.MainFrame = nil
UI.ParticleContainer = nil
UI.Connections = {}

function UI:PlaySound(id)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id
    s.Volume = 0.5
    s.Parent = workspace
    s.PlayOnRemove = true
    s:Destroy()
end

function UI:Tween(obj, info, props)
    local t = TweenService:Create(obj, TweenInfo.new(info, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

function UI:Create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        -- Handle children special case
        if k == "Children" then
            for _, child in pairs(v) do child.Parent = inst end
        else
            inst[k] = v
        end
    end
    return inst
end

function UI:Ripple(btn)
    task.spawn(function()
        local mouse = LocalPlayer:GetMouse()
        local ripple = UI:Create("Frame", {
            Parent = btn, BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.8,
            BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, mouse.X - btn.AbsolutePosition.X, 0, mouse.Y - btn.AbsolutePosition.Y),
            Size = UDim2.new(0,0,0,0), ZIndex = 10
        })
        UI:Create("UICorner", {Parent = ripple, CornerRadius = UDim.new(1,0)})
        
        local t = UI:Tween(ripple, 0.5, {Size = UDim2.new(0, 300, 0, 300), BackgroundTransparency = 1})
        t.Completed:Wait()
        ripple:Destroy()
    end)
end

function UI:Draggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging and dragInput then
            local delta = dragInput.Position - dragStart
            UI:Tween(frame, 0.1, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)})
        end
    end)
end

function UI:ParticleFX(parent)
    local container = UI:Create("Frame", {Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0), ZIndex = 1})
    UI.ParticleContainer = container
    
    task.spawn(function()
        while container.Parent do
            if math.random() > 0.7 then
                local size = math.random(2, 4)
                local p = UI:Create("Frame", {
                    Parent = container, BackgroundColor3 = CFG.Theme.Accent, BackgroundTransparency = 0.6,
                    Size = UDim2.new(0, size, 0, size), Position = UDim2.new(math.random(), 0, 1, 0),
                    BorderSizePixel = 0, ZIndex = 1
                })
                local duration = math.random(20, 50) / 10
                UI:Tween(p, duration, {Position = UDim2.new(math.random(), 0, 0, 0), BackgroundTransparency = 1})
                task.delay(duration, function() p:Destroy() end)
            end
            task.wait(0.1)
        end
    end)
end

-- Notification System
function UI:Notify(msg, type)
    task.spawn(function()
        local color = type == "err" and CFG.Theme.Error or CFG.Theme.Accent
        
        local notif = UI:Create("Frame", {
            Parent = UI.Screen, BackgroundColor3 = CFG.Theme.Panel,
            Size = UDim2.new(0, 280, 0, 50), Position = UDim2.new(1, 20, 0.85, #UI.Screen:GetChildren() * -60),
            BorderSizePixel = 0
        })
        UI:Create("UICorner", {Parent = notif, CornerRadius = UDim.new(0, 6)})
        UI:Create("UIStroke", {Parent = notif, Color = color, Thickness = 1.5})
        
        local bar = UI:Create("Frame", {
            Parent = notif, BackgroundColor3 = color, Size = UDim2.new(0, 4, 1, -10),
            Position = UDim2.new(0, 5, 0, 5)
        })
        UI:Create("UICorner", {Parent = bar, CornerRadius = UDim.new(0, 4)})

        UI:Create("TextLabel", {
            Parent = notif, BackgroundTransparency = 1, Size = UDim2.new(1, -25, 1, 0),
            Position = UDim2.new(0, 20, 0, 0), Text = msg, TextColor3 = CFG.Theme.Text,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true
        })

        UI:PlaySound(type == "err" and CFG.Sounds.Error or CFG.Sounds.Success)
        UI:Tween(notif, 0.5, {Position = UDim2.new(1, -300, 0.85, #UI.Screen:GetChildren() * -60)})
        
        task.wait(4)
        UI:Tween(notif, 0.5, {Position = UDim2.new(1, 20, 0.85, 0)})
        task.wait(0.5)
        notif:Destroy()
    end)
end

-- Floating Widget (Toggle Button)
function UI:CreateWidget(callback)
    local widget = UI:Create("ImageButton", {
        Name = "HairKeyWidget", Parent = UI.Screen,
        BackgroundColor3 = CFG.Theme.Panel, Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(0, 20, 0.5, 0), BorderSizePixel = 0,
        Image = "rbxassetid://13853153610", -- Key Icon
        ImageColor3 = CFG.Theme.Accent
    })
    UI:Create("UICorner", {Parent = widget, CornerRadius = UDim.new(0, 8)})
    UI:Create("UIStroke", {Parent = widget, Color = CFG.Theme.Accent, Thickness = 2})
    
    -- Draggable Widget
    UI:Draggable(widget, widget)
    
    widget.MouseButton1Click:Connect(function()
        UI:PlaySound(CFG.Sounds.Click)
        callback()
    end)
    
    -- Pulse Effect
    task.spawn(function()
        while widget.Parent do
            UI:Tween(widget, 1, {ImageColor3 = CFG.Theme.Accent2})
            task.wait(1)
            UI:Tween(widget, 1, {ImageColor3 = CFG.Theme.Accent})
            task.wait(1)
        end
    end)
    
    return widget
end

-- Boot Sequence Animation
function UI:BootSequence(frame, onComplete)
    frame.Visible = true
    local console = UI:Create("Frame", {
        Parent = frame, BackgroundColor3 = Color3.fromRGB(0,0,0), Size = UDim2.new(1,0,1,0), ZIndex = 100
    })
    local txt = UI:Create("TextLabel", {
        Parent = console, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -40),
        Position = UDim2.new(0, 20, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Font = Enum.Font.Code, TextSize = 14, TextColor3 = CFG.Theme.Accent, Text = ""
    })
    
    UI:PlaySound(CFG.Sounds.Boot)
    
    local lines = {
        "> INITIALIZING TITAN KERNEL...",
        "> LOADING MEMORY MODULES... [OK]",
        "> CONNECTING TO SECURE GATEWAY... [OK]",
        "> CHECKING HWID INTEGRITY...",
        "> STATUS: CONNECTED",
        "> LAUNCHING INTERFACE..."
    }
    
    for _, line in ipairs(lines) do
        txt.Text = txt.Text .. line .. "\n"
        task.wait(math.random(1, 4)/10)
    end
    
    task.wait(0.5)
    UI:Tween(console, 0.5, {BackgroundTransparency = 1})
    UI:Tween(txt, 0.5, {TextTransparency = 1})
    task.wait(0.5)
    console:Destroy()
    onComplete()
end


-- Main UI Builder
function UI:Init(config, logic)
    -- Cleanup
    for _, v in pairs(CoreGui:GetChildren()) do if v.Name == "HairKey_Titan" then v:Destroy() end end
    
    UI.Screen = UI:Create("ScreenGui", {Name = "HairKey_Titan", Parent = CoreGui})
    
    -- *** MAIN FRAME ***
    local Main = UI:Create("Frame", {
        Name = "MainFrame", Parent = UI.Screen,
        BackgroundColor3 = CFG.Theme.Main, Size = UDim2.new(0, 500, 0, 320),
        Position = UDim2.new(0.5, -250, 0.5, -160), BorderSizePixel = 0,
        ClipsDescendants = true, Visible = false -- Hidden for Boot
    })
    UI.MainFrame = Main
    UI:Create("UICorner", {Parent = Main, CornerRadius = UDim.new(0, 10)})
    
    -- Gradient Stroke
    local Stroke = UI:Create("UIStroke", {Parent = Main, Thickness = 2, Transparency = 0})
    local Gradient = UI:Create("UIGradient", {Parent = Stroke, Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, CFG.Theme.Accent),
        ColorSequenceKeypoint.new(1, CFG.Theme.Accent2)
    }, Rotation = 45})
    
    task.spawn(function()
        while Main.Parent do
            Gradient.Rotation = Gradient.Rotation + 1
            task.wait(0.05)
        end
    end)
    
    UI:ParticleFX(Main) -- Background particles
    
    -- *** HEADER ***
    local TopBar = UI:Create("Frame", {
        Parent = Main, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), ZIndex = 2
    })
    UI:Draggable(Main, TopBar)
    
    UI:Create("TextLabel", {
        Parent = TopBar, Text = CFG.AppName, Font = Enum.Font.GothamBold, TextSize = 18,
        TextColor3 = CFG.Theme.Text, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 15, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1
    })
    
    -- Close Button
    local CloseBtn = UI:Create("TextButton", {
        Parent = TopBar, Text = "X", TextColor3 = CFG.Theme.Error, BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 18, Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -40, 0, 0)
    })
    CloseBtn.MouseButton1Click:Connect(function()
        Main.Visible = false
        UI:Notify("Interface Hidden. Click widget to restore.", "norm")
    end)
    
    -- *** CONTENT ***
    local Container = UI:Create("Frame", {
        Parent = Main, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -60),
        Position = UDim2.new(0, 20, 0, 50), ZIndex = 2
    })
    
    -- Input Box
    local InputBoxBg = UI:Create("Frame", {
        Parent = Container, BackgroundColor3 = CFG.Theme.Panel, Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.new(0, 0, 0.2, 0)
    })
    UI:Create("UICorner", {Parent = InputBoxBg, CornerRadius = UDim.new(0, 8)})
    UI:Create("UIStroke", {Parent = InputBoxBg, Color = Color3.fromRGB(40,40,40), Thickness = 1})
    
    local KeyInput = UI:Create("TextBox", {
        Parent = InputBoxBg, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0), Text = "", PlaceholderText = "Enter Access Key...",
        TextColor3 = CFG.Theme.Accent, PlaceholderColor3 = CFG.Theme.TextDim,
        Font = Enum.Font.Code, TextSize = 16, ClearTextOnFocus = false
    })
    
    -- *** BUTTONS ***
    local function AddButton(text, pos, color, func)
        local btn = UI:Create("TextButton", {
            Parent = Container, BackgroundColor3 = color, Size = UDim2.new(0.48, 0, 0, 45),
            Position = pos, Text = "", AutoButtonColor = false
        })
        UI:Create("UICorner", {Parent = btn, CornerRadius = UDim.new(0, 8)})
        
        -- Glow Shadow
        local glow = UI:Create("ImageLabel", {
            Parent = btn, BackgroundTransparency = 1, Image = "rbxassetid://5028857472",
            ImageColor3 = color, Size = UDim2.new(1, 40, 1, 40), Position = UDim2.new(0, -20, 0, -20),
            ImageTransparency = 0.5, ZIndex = 0
        })
        
        UI:Create("TextLabel", {
            Parent = btn, BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
            Text = text, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(0,0,0), TextSize = 14
        })
        
        btn.MouseEnter:Connect(function() UI:Tween(glow, 0.2, {ImageTransparency = 0.2}) end)
        btn.MouseLeave:Connect(function() UI:Tween(glow, 0.2, {ImageTransparency = 0.5}) end)
        btn.MouseButton1Click:Connect(function() UI:Ripple(btn); UI:PlaySound(CFG.Sounds.Click); func() end)
    end
    
    AddButton("GET KEY", UDim2.new(0, 0, 0.5, 0), CFG.Theme.Accent2, logic.GetKey)
    AddButton("VERIFY KEY", UDim2.new(0.52, 0, 0.5, 0), CFG.Theme.Accent, function() logic.Verify(KeyInput.Text) end)
    
    -- *** FOOTER STATUS ***
    local StatusText = UI:Create("TextLabel", {
        Parent = Container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0.85, 0), Text = "STATUS: WAITING FOR USER",
        Font = Enum.Font.Code, TextSize = 12, TextColor3 = CFG.Theme.TextDim
    })
    
    -- *** SERVER PING & HWID ***
    local Info = UI:Create("TextLabel", {
        Parent = Main, BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 15),
        Position = UDim2.new(0, 5, 1, -20), TextXAlignment = Enum.TextXAlignment.Right,
        Font = Enum.Font.Code, TextSize = 10, TextColor3 = Color3.fromRGB(80,80,80),
        Text = "SERVER LATENCY: ... | HWID: ..."
    })
    
    -- Widget Logic
    local Widget = UI:CreateWidget(function()
        Main.Visible = not Main.Visible
    end)
    
    -- Live Update Stats
    task.spawn(function()
        while Main.Parent do
            -- Fake Ping Logic (Or Real if you send request)
            local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
            local hwid = string.sub(game:GetService("RbxAnalyticsService"):GetClientId(), 1, 15) .. "..."
            Info.Text = "PING: " .. ping .. "ms | HWID: " .. hwid
            task.wait(1)
        end
    end)
    
    return {
        SetStatus = function(txt, col) 
            StatusText.Text = "> " .. txt
            StatusText.TextColor3 = col or CFG.Theme.TextDim
        end,
        Show = function() Main.Visible = true end,
        Hide = function() Main.Visible = false end,
        Boot = function(cb) UI:BootSequence(Main, cb) end
    }
end

-- ==============================================================================
-- [4] MAIN LOGIC CONTROLLER
-- ==============================================================================

function HairKey.init(config)
    -- Apply Config
    CFG.AppName = config.ApplicationName or "TITAN HUB"
    local OnSuccess = config.OnKeyCorrect or function() print("SUCCESS") end
    
    -- Define Interface Logic
    local Logic = {}
    local Interface = nil
    
    function Logic.GetKey()
        Interface.SetStatus("HANDSHAKING WITH SERVER...", CFG.Theme.Accent2)
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        
        local res = Network.Request(CFG.Domain .. "/api/handshake", "POST", {hwid = hwid})
        
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.success then
                setclipboard(data.url)
                Interface.SetStatus("LINK COPIED TO CLIPBOARD!", CFG.Theme.Accent)
                UI:Notify("Link copied! Check your browser.", "succ")
            else
                Interface.SetStatus("SERVER ERROR", CFG.Theme.Error)
                UI:Notify("Failed to generate link.", "err")
            end
        else
            Interface.SetStatus("CONNECTION FAILED ("..res.StatusCode..")", CFG.Theme.Error)
        end
    end
    
    function Logic.Verify(key)
        if key == "" then UI:Notify("Key cannot be empty!", "err") return end
        
        Interface.SetStatus("VERIFYING KEY...", CFG.Theme.Text)
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        
        local res = Network.Request(CFG.Domain .. "/api/check-key?hwid="..hwid.."&key="..key, "GET")
        
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.valid then
                Interface.SetStatus("ACCESS GRANTED", CFG.Theme.Accent)
                UI:Notify("Authentication Successful.", "succ")
                UI:PlaySound(CFG.Sounds.Success)
                
                Crypt.Save({key = key, timestamp = os.time()}) -- Secure Save
                
                task.wait(1)
                Interface.Hide()
                if UI.Screen then UI.Screen:Destroy() end
                
                OnSuccess()
            else
                Interface.SetStatus("INVALID KEY", CFG.Theme.Error)
                UI:Notify("Key is invalid or expired.", "err")
                UI:PlaySound(CFG.Sounds.Error)
            end
        else
            Interface.SetStatus("SERVER TIMEOUT", CFG.Theme.Error)
        end
    end
    
    -- Start Sequence
    -- 1. Check Saved Key
    local saved = Crypt.Load()
    if saved and saved.key then
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local res = Network.Request(CFG.Domain .. "/api/check-key?hwid="..hwid.."&key="..saved.key, "GET")
        
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.valid then
                -- Silent Login
                UI:PlaySound(CFG.Sounds.Success)
                local starter = Instance.new("ScreenGui", CoreGui)
                local notify = Instance.new("TextLabel", starter)
                notify.Size = UDim2.new(0, 300, 0, 50)
                notify.Position = UDim2.new(0.5, -150, 0, 50)
                notify.BackgroundColor3 = CFG.Theme.Accent
                notify.Text = "⚡ QUICK LOGIN SUCCESSFUL"
                notify.Font = Enum.Font.GothamBold
                task.delay(3, function() starter:Destroy() end)
                
                OnSuccess()
                return
            end
        end
    end
    
    -- 2. If no valid key, Init UI
    Interface = UI:Init(CFG, Logic)
    Interface.Boot(function()
        -- Callback after boot animation finishes
    end)
end

return HairKey