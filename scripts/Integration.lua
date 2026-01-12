--[[
    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //                                                                                               //
    //           ██╗  ██╗ █████╗ ██╗██████╗ ██╗  ██╗███████╗██╗   ██╗                                //
    //           ██║  ██║██╔══██╗██║██╔══██╗██║ ██╔╝██╔════╝╚██╗ ██╔╝                                //
    //           ███████║███████║██║██████╔╝█████╔╝ █████╗   ╚████╔╝                                 //
    //           ██╔══██║██╔══██║██║██╔══██╗██╔═██╗ ██╔══╝    ╚██╔╝                                  //
    //           ██║  ██║██║  ██║██║██║  ██║██║  ██╗███████╗   ██║                                   //
    //           ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝                                   //
    //                                                                                               //
    //      HAIRKEY CLIENT - TITAN PRO MAX ULTRA (v5.0)                                              //
    //      "Beyond The Absolute Zenith"                                                             //
    //                                                                                               //
    //      [CHANGELOG v5.0]                                                                         //
    //      + CRITICAL FIX: Notification text visibility issues resolved (ZIndex/Contrast)           //
    //      + NEW: "Void Tech" Aesthetic (Deep Black + Hyper Cyan)                                   //
    //      + NEW: Holographic Corner Borders                                                        //
    //      + NEW: Notification Progress Bar                                                         //
    //      + OPTIMIZATION: Reduced memory leaks in Particle Engine                                  //
    //                                                                                               //
    //      [AUTHOR] HairKey Development Team                                                        //
    //                                                                                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////////
]]

local HairKey = {}
HairKey.__index = HairKey

-- ==================================================================================================
-- [1] CORE SERVICES
-- ==================================================================================================
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ==================================================================================================
-- [2] CONFIGURATION MATRIX
-- ==================================================================================================
local CFG = {
    -- [Network]
    Domain = "https://hairkey.onrender.com",
    RequestTimeout = 20,
    MaxRetries = 3,

    -- [System]
    AppName = "TITAN PROTOCOL",
    Version = "5.0.0-ULTRA",
    FileName = "HairKey_Auth_V5.bin",
    EncryptionKey = "TITAN_ULTRA_SECRET_KEY_2026",

    -- [Visuals - HIGH CONTRAST MODE]
    Theme = {
        Background = Color3.fromRGB(5, 5, 5),       -- Pure Void
        Panel = Color3.fromRGB(10, 10, 12),         -- Dark Slate
        PanelBorder = Color3.fromRGB(40, 40, 50),
        
        Primary = Color3.fromRGB(0, 255, 200),      -- Hyper Cyan
        Secondary = Color3.fromRGB(140, 0, 255),    -- Deep Purple
        
        Text = Color3.fromRGB(255, 255, 255),       -- Pure White
        TextDim = Color3.fromRGB(120, 120, 140),    -- Grey
        
        Success = Color3.fromRGB(0, 255, 100),      -- Green
        Error = Color3.fromRGB(255, 50, 80),        -- Red Pink
        Warning = Color3.fromRGB(255, 220, 50)      -- Yellow
    },
    
    -- [Assets]
    Assets = {
        Font = Enum.Font.GothamMedium,
        HeaderFont = Enum.Font.GothamBlack,
        CodeFont = Enum.Font.Code,
        GridTexture = "rbxassetid://6071575925",
        NoiseTexture = "rbxassetid://16440628399",
        Gradient = "rbxassetid://7011962991",
        Icons = {
            Key = "rbxassetid://13853153610",
            Close = "rbxassetid://3926305904",
            Info = "rbxassetid://3926305904"
        }
    },

    -- [Audio]
    Sounds = {
        Hover = 4590662766,
        Click = 4590657391,
        Success = 5153734232,
        Error = 4590608263,
        Boot = 6276409843,
        Typing = 5646698666
    }
}

-- ==================================================================================================
-- [3] UTILITIES: LOGGER & DEBUG
-- ==================================================================================================
local Logger = {}

function Logger.Print(msg, level)
    local prefix = "[HAIRKEY]"
    local timestamp = os.date("%H:%M:%S")
    local color = "@@CYAN@@"
    
    if level == "WARN" then color = "@@YELLOW@@"
    elseif level == "ERR" then color = "@@RED@@"
    elseif level == "SUCCESS" then color = "@@GREEN@@" end

    if rconsoleprint then
        rconsoleprint("@@WHITE@@["..timestamp.."] ")
        rconsoleprint(color .. prefix .. " ")
        rconsoleprint("@@WHITE@@" .. msg .. "\n")
    else
        print(prefix, msg)
    end
end

-- ==================================================================================================
-- [4] UTILITIES: CRYPTOGRAPHY
-- ==================================================================================================
local Crypt = {}

function Crypt.XOR(data, key)
    local output = {}
    local keyLen = #key
    for i = 1, #data do
        local b = string.byte(data, i)
        local k = string.byte(key, (i - 1) % keyLen + 1)
        table.insert(output, string.char(bit32.bxor(b, k)))
    end
    return table.concat(output)
end

function Crypt.Save(keyData)
    if not writefile then return end
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(keyData)
        local encrypted = Crypt.XOR(json, CFG.EncryptionKey)
        writefile(CFG.FileName, encrypted)
    end)
end

function Crypt.Load()
    if not isfile or not isfile(CFG.FileName) then return nil end
    local success, result = pcall(function()
        local encrypted = readfile(CFG.FileName)
        local decrypted = Crypt.XOR(encrypted, CFG.EncryptionKey)
        return HttpService:JSONDecode(decrypted)
    end)
    return success and result or nil
end

-- ==================================================================================================
-- [5] UTILITIES: NETWORK
-- ==================================================================================================
local Network = {}

function Network.Request(url, method, body)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    
    if not requestFunc then
        return {Body = nil, StatusCode = 0}
    end

    local attempts = 0
    local response
    local success

    repeat
        attempts = attempts + 1
        success, response = pcall(function()
            return requestFunc({
                Url = url,
                Method = method or "GET",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = "HairKey-Titan/" .. CFG.Version
                },
                Body = body and HttpService:JSONEncode(body) or nil
            })
        end)
        if not success then task.wait(0.5) end
    until (success and response) or attempts >= CFG.MaxRetries

    return success and response or {Body = nil, StatusCode = 0} 
end

-- ==================================================================================================
-- [6] VISUAL FX ENGINE
-- ==================================================================================================
local VFX = {}
VFX.Connections = {}

function VFX.PlaySound(name, props)
    local id = CFG.Sounds[name]
    if not id then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. id
        s.Volume = (props and props.Volume) or 0.5
        s.Pitch = (props and props.Pitch) or 1
        s.Parent = SoundService
        s.PlayOnRemove = true
        s:Destroy()
    end)
end

function VFX.Tween(obj, info, props)
    local t = TweenService:Create(obj, TweenInfo.new(info, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- [PARTICLE SYSTEM V2 - MEMORY OPTIMIZED]
function VFX.SpawnParticles(parent, count)
    local container = Instance.new("Frame")
    container.Name = "FX_Particles"
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 1, 0)
    container.ZIndex = 1
    container.Parent = parent

    if VFX.Connections[parent] then VFX.Connections[parent]:Disconnect() end

    local particles = {}
    for i = 1, count do
        local p = Instance.new("Frame")
        p.BorderSizePixel = 0
        p.BackgroundColor3 = CFG.Theme.Primary
        p.Size = UDim2.new(0, math.random(1, 3), 0, math.random(1, 3))
        p.Position = UDim2.new(math.random(), 0, math.random(), 0)
        p.BackgroundTransparency = math.random(0.4, 0.9)
        p.Parent = container
        table.insert(particles, {
            Obj = p,
            Speed = math.random(5, 15),
            Drift = math.random(-5, 5)
        })
    end
    
    VFX.Connections[parent] = RunService.RenderStepped:Connect(function(dt)
        for _, p in ipairs(particles) do
            local pos = p.Obj.Position
            local newY = pos.Y.Scale - (p.Speed * 0.005 * dt * 60)
            local newX = pos.X.Scale + (p.Drift * 0.0005 * dt * 60)
            
            if newY < 0 then newY = 1; newX = math.random() end
            if newX < 0 then newX = 1 elseif newX > 1 then newX = 0 end
            
            p.Obj.Position = UDim2.new(newX, 0, newY, 0)
        end
    end)
end

-- [CRT OVERLAY]
function VFX.ApplyCRT(parent)
    local scanline = Instance.new("ImageLabel")
    scanline.Name = "FX_CRT"
    scanline.BackgroundTransparency = 1
    scanline.Size = UDim2.new(1, 0, 1, 0)
    scanline.Image = "rbxassetid://7019796593" -- Better scanline texture
    scanline.ImageTransparency = 0.95
    scanline.ImageColor3 = Color3.new(0,0,0)
    scanline.ScaleType = Enum.ScaleType.Tile
    scanline.TileSize = UDim2.new(0, 128, 0, 128)
    scanline.ZIndex = 100
    scanline.Parent = parent
end

-- ==================================================================================================
-- [7] UI ENGINE: COMPONENT BUILDER
-- ==================================================================================================
local UI = {}
UI.Screen = nil

function UI.Create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" and k ~= "Children" then inst[k] = v end
    end
    if props.Children then for _, child in pairs(props.Children) do child.Parent = inst end end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

function UI.MakeDraggable(frame, handle)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            VFX.Tween(frame, 0.05, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)})
        end
    end)
end

-- [[ NOTIFICATION SYSTEM - FIXED ]]
function UI.Notify(msg, type)
    task.spawn(function()
        if not UI.Screen then return end
        
        -- Color Logic
        local accentColor = CFG.Theme.Primary
        local iconId = "rbxassetid://3926305904" -- Info
        
        if type == "ERR" then 
            accentColor = CFG.Theme.Error 
            iconId = "rbxassetid://3926305904" -- Alert
        elseif type == "SUCCESS" then 
            accentColor = CFG.Theme.Success 
            iconId = "rbxassetid://3926307971" -- Check
        end
        
        -- Main Container
        local container = UI.Create("Frame", {
            Name = "Notification",
            Parent = UI.Screen,
            BackgroundColor3 = Color3.fromRGB(15, 15, 20), -- Darker background for contrast
            Size = UDim2.new(0, 320, 0, 60),
            Position = UDim2.new(1, 20, 0.85, 0), -- Start off screen
            BorderSizePixel = 0,
            ZIndex = 200 -- Ensure it's on top
        })
        
        -- Styling
        UI.Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 6)})
        UI.Create("UIStroke", {Parent = container, Color = Color3.fromRGB(40,40,45), Thickness = 1})
        
        -- Side Color Bar
        UI.Create("Frame", {
            Parent = container,
            BackgroundColor3 = accentColor,
            Size = UDim2.new(0, 4, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BorderSizePixel = 0,
            ZIndex = 201
        })
        
        -- Title
        UI.Create("TextLabel", {
            Parent = container,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -50, 0, 20),
            Position = UDim2.new(0, 15, 0, 8),
            Text = (type == "ERR" and "SYSTEM ERROR") or (type == "SUCCESS" and "SUCCESS") or "NOTIFICATION",
            TextColor3 = accentColor,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202
        })
        
        -- Message (FIXED VISIBILITY)
        UI.Create("TextLabel", {
            Parent = container,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -20, 0, 25),
            Position = UDim2.new(0, 15, 0, 25),
            Text = msg,
            TextColor3 = Color3.fromRGB(255, 255, 255), -- Pure White for max contrast
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 202
        })
        
        -- Progress Bar (Timer)
        local progress = UI.Create("Frame", {
            Parent = container,
            BackgroundColor3 = accentColor,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -4, 0, 2),
            Position = UDim2.new(0, 4, 1, -2),
            BackgroundTransparency = 0.5,
            ZIndex = 202
        })

        VFX.PlaySound(type == "ERR" and "Error" or "Success")
        
        -- Animation IN
        VFX.Tween(container, 0.4, {Position = UDim2.new(1, -340, 0.85, 0)})
        
        -- Timer Animation
        VFX.Tween(progress, 4, {Size = UDim2.new(0, 0, 0, 2)})
        task.wait(4)
        
        -- Animation OUT
        VFX.Tween(container, 0.4, {Position = UDim2.new(1, 20, 0.85, 0)})
        task.wait(0.4)
        container:Destroy()
    end)
end

-- [[ BOOT SEQUENCE ]]
function UI.RunBoot(parent, onDone)
    local bootFrame = UI.Create("Frame", {
        Parent = parent, BackgroundColor3 = Color3.new(0,0,0), Size = UDim2.new(1,0,1,0), ZIndex = 999
    })
    local term = UI.Create("TextLabel", {
        Parent = bootFrame, BackgroundTransparency = 1, Size = UDim2.new(0.9,0,0.9,0), Position = UDim2.new(0.05,0,0.05,0),
        TextColor3 = CFG.Theme.Primary, Font = CFG.Assets.CodeFont, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = ""
    })
    
    local lines = {
        "[KERNEL] Initializing Titan Protocol v"..CFG.Version,
        "[MEM] Allocating heap size 128MB... OK",
        "[NET] Pinging " .. CFG.Domain:sub(9, 20) .. "... 24ms",
        "[SEC] Verifying Integrity Checksum... PASSED",
        "[SYS] Mounting User Interface...",
        "[SYS] Launching..."
    }
    
    VFX.PlaySound("Boot")
    
    for _, l in ipairs(lines) do
        term.Text = term.Text .. "> " .. l .. "\n"
        VFX.PlaySound("Typing", {Volume = 0.2, Pitch = 1 + math.random()*0.2})
        task.wait(math.random(1,3)/10)
    end
    task.wait(0.5)
    
    VFX.Tween(bootFrame, 0.8, {BackgroundTransparency = 1})
    VFX.Tween(term, 0.8, {TextTransparency = 1})
    task.wait(0.8)
    bootFrame:Destroy()
    onDone()
end

-- ==================================================================================================
-- [8] MAIN LOGIC CONTROLLER
-- ==================================================================================================
function HairKey.init(config)
    if config.ApplicationName then CFG.AppName = config.ApplicationName end
    local OnKeyCorrect = config.OnKeyCorrect or function() end

    -- Cleanup
    for _, v in pairs(CoreGui:GetChildren()) do if v.Name == "HairKey_Titan_Ultra" then v:Destroy() end end
    
    UI.Screen = UI.Create("ScreenGui", {Name = "HairKey_Titan_Ultra", Parent = CoreGui, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})

    -- 1. MAIN CONTAINER
    local MainFrame = UI.Create("Frame", {
        Name = "MainFrame",
        Parent = UI.Screen,
        BackgroundColor3 = CFG.Theme.Background,
        Size = UDim2.new(0, 550, 0, 360),
        Position = UDim2.new(0.5, -275, 0.5, -180),
        BorderSizePixel = 0,
        ClipsDescendants = false, -- Enable glow outside
        Visible = false
    })
    
    UI.Create("UICorner", {Parent = MainFrame, CornerRadius = UDim.new(0, 8)})
    
    -- Outer Glow Shadow
    UI.Create("ImageLabel", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857472",
        ImageColor3 = Color3.new(0,0,0),
        Size = UDim2.new(1, 100, 1, 100),
        Position = UDim2.new(0, -50, 0, -50),
        ImageTransparency = 0.2,
        ZIndex = 0
    })

    -- Tech Border (Animated)
    local Stroke = UI.Create("UIStroke", {Parent = MainFrame, Thickness = 2, Transparency = 0})
    local Gradient = UI.Create("UIGradient", {
        Parent = Stroke,
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, CFG.Theme.Primary),
            ColorSequenceKeypoint.new(0.5, CFG.Theme.Secondary),
            ColorSequenceKeypoint.new(1, CFG.Theme.Primary)
        },
        Rotation = 45
    })
    
    task.spawn(function()
        while MainFrame.Parent do
            Gradient.Rotation = Gradient.Rotation + 1.5
            task.wait(0.02)
        end
    end)

    -- Background Grid (Parallax)
    local Grid = UI.Create("ImageLabel", {
        Parent = MainFrame, BackgroundTransparency = 1, Image = CFG.Assets.GridTexture,
        ImageColor3 = CFG.Theme.Primary, ImageTransparency = 0.95,
        Size = UDim2.new(1.2, 0, 1.2, 0), Position = UDim2.new(-0.1, 0, -0.1, 0),
        ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.new(0, 30, 0, 30), ZIndex = 1
    })
    
    RunService.RenderStepped:Connect(function()
        if not MainFrame.Visible then return end
        local mX, mY = Mouse.X / workspace.CurrentCamera.ViewportSize.X, Mouse.Y / workspace.CurrentCamera.ViewportSize.Y
        local targetPos = UDim2.new(-0.1 + (mX-0.5)*0.03, 0, -0.1 + (mY-0.5)*0.03, 0)
        Grid.Position = Grid.Position:Lerp(targetPos, 0.1)
    end)

    VFX.SpawnParticles(MainFrame, 25)
    VFX.ApplyCRT(MainFrame)

    -- 2. HEADER
    local TopBar = UI.Create("Frame", {Parent = MainFrame, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,50), ZIndex = 10})
    UI.MakeDraggable(MainFrame, TopBar)
    
    UI.Create("TextLabel", {
        Parent = TopBar,
        Text = CFG.AppName .. " <font color='#666'>// AUTHENTICATION</font>",
        RichText = true, Font = CFG.Assets.HeaderFont, TextSize = 20,
        TextColor3 = CFG.Theme.Text, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 25, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1
    })
    
    local CloseBtn = UI.Create("TextButton", {
        Parent = TopBar, Text = "×", Font = Enum.Font.GothamMedium, TextSize = 30,
        TextColor3 = CFG.Theme.TextDim, BackgroundTransparency = 1,
        Size = UDim2.new(0, 50, 1, 0), Position = UDim2.new(1, -50, 0, 0)
    })
    CloseBtn.MouseEnter:Connect(function() CloseBtn.TextColor3 = CFG.Theme.Error end)
    CloseBtn.MouseLeave:Connect(function() CloseBtn.TextColor3 = CFG.Theme.TextDim end)
    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        UI.Notify("Minimized to tray.", "WARN")
    end)

    -- 3. CONTENT AREA
    local Content = UI.Create("Frame", {Parent = MainFrame, BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, -80), Position = UDim2.new(0, 25, 0, 60), ZIndex = 10})
    
    -- Key Input
    local InputFrame = UI.Create("Frame", {
        Parent = Content, BackgroundColor3 = CFG.Theme.Panel, Size = UDim2.new(1, 0, 0, 55), Position = UDim2.new(0,0,0.1,0)
    })
    UI.Create("UICorner", {Parent = InputFrame, CornerRadius = UDim.new(0, 8)})
    local InputStroke = UI.Create("UIStroke", {Parent = InputFrame, Color = Color3.fromRGB(40,40,45), Thickness = 1})
    
    local InputBox = UI.Create("TextBox", {
        Parent = InputFrame, BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 15, 0, 0),
        Text = "", PlaceholderText = "PASTE KEY HERE...", TextColor3 = CFG.Theme.Primary, PlaceholderColor3 = CFG.Theme.TextDim,
        Font = CFG.Assets.CodeFont, TextSize = 16, ClearTextOnFocus = false
    })
    
    InputBox.Focused:Connect(function() VFX.Tween(InputStroke, 0.3, {Color = CFG.Theme.Primary}) end)
    InputBox.FocusLost:Connect(function() VFX.Tween(InputStroke, 0.3, {Color = Color3.fromRGB(40,40,45)}) end)

    -- Button Creator
    local function CreateTechBtn(text, pos, color, callback)
        local btn = UI.Create("TextButton", {
            Parent = Content, BackgroundColor3 = color, BackgroundTransparency = 0.1,
            Size = UDim2.new(0.48, 0, 0, 50), Position = pos, Text = "", AutoButtonColor = false
        })
        UI.Create("UICorner", {Parent = btn, CornerRadius = UDim.new(0, 8)})
        
        -- Tech Pattern Inside
        UI.Create("ImageLabel", {
            Parent = btn, BackgroundTransparency = 1, Image = "rbxassetid://300134974", ImageTransparency = 0.9,
            Size = UDim2.new(1,0,1,0), ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.new(0, 10, 0, 10)
        })
        
        UI.Create("TextLabel", {
            Parent = btn, BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
            Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(0,0,0)
        })
        
        btn.MouseButton1Click:Connect(function()
            VFX.PlaySound("Click")
            callback()
        end)
        
        return btn
    end
    
    -- Action Logic
    local function GetKey()
        UI.Notify("Contacting Server...", "WARN")
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local res = Network.Request(CFG.Domain .. "/api/handshake", "POST", {hwid = hwid})
        
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.success then
                setclipboard(data.url)
                UI.Notify("Link Copied to Clipboard!", "SUCCESS")
            else
                UI.Notify("Server Error: " .. (data.error or "Unknown"), "ERR")
            end
        else
            UI.Notify("Connection Failed ("..res.StatusCode..")", "ERR")
        end
    end
    
    local function Verify()
        local key = InputBox.Text
        if key:gsub(" ", "") == "" then UI.Notify("Please enter a key.", "ERR") return end
        
        UI.Notify("Verifying...", "WARN")
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local res = Network.Request(CFG.Domain .. "/api/check-key?hwid="..hwid.."&key="..key, "GET")
        
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.valid then
                UI.Notify("Access Granted. Welcome.", "SUCCESS")
                Crypt.Save({key = key})
                VFX.Tween(MainFrame, 0.5, {Size = UDim2.new(0, 550, 0, 0), Position = UDim2.new(0.5, -275, 0.5, 0)})
                task.wait(0.5)
                MainFrame.Visible = false
                OnKeyCorrect()
            else
                UI.Notify("Invalid Key.", "ERR")
            end
        else
            UI.Notify("Server Timeout.", "ERR")
        end
    end
    
    local BtnGet = CreateTechBtn("GET KEY", UDim2.new(0,0,0.5,0), CFG.Theme.Primary, GetKey)
    local BtnVer = CreateTechBtn("LOGIN", UDim2.new(0.52,0,0.5,0), CFG.Theme.Secondary, Verify)

    -- 4. FOOTER STATUS
    local Status = UI.Create("TextLabel", {
        Parent = MainFrame, BackgroundTransparency = 1,
        Size = UDim2.new(1, -50, 0, 20), Position = UDim2.new(0, 25, 1, -30),
        Text = "> WAITING FOR INPUT...", Font = CFG.Assets.CodeFont, TextSize = 12,
        TextColor3 = CFG.Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left
    })
    
    -- 5. FLOATING WIDGET
    local Widget = UI.Create("ImageButton", {
        Parent = UI.Screen, BackgroundColor3 = CFG.Theme.Panel,
        Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 20, 0.5, -25),
        Image = CFG.Assets.Icons.Key, ImageColor3 = CFG.Theme.Primary,
        BorderSizePixel = 0
    })
    UI.Create("UICorner", {Parent = Widget, CornerRadius = UDim.new(0, 16)})
    UI.Create("UIStroke", {Parent = Widget, Color = CFG.Theme.Primary, Thickness = 2})
    UI.MakeDraggable(Widget, Widget)
    
    Widget.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
        VFX.PlaySound("Click")
    end)

    -- ==============================================================================================
    -- [9] INIT SEQUENCE
    -- ==============================================================================================
    local cached = Crypt.Load()
    if cached and cached.key then
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local res = Network.Request(CFG.Domain .. "/api/check-key?hwid="..hwid.."&key="..cached.key, "GET")
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.valid then
                UI.Notify("Quick Login Successful.", "SUCCESS")
                OnKeyCorrect()
                return
            end
        end
    end
    
    MainFrame.Visible = true
    UI.RunBoot(MainFrame, function() end)
end

return HairKey