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
    //      HAIRKEY CLIENT - TITAN PRO MAX ULTRA (v5.1)                                              //
    //      "Matrix Protocol Edition"                                                                //
    //                                                                                               //
    //      [CHANGELOG v5.1]                                                                         //
    //      + FIXED: Connection Failed (0) - Added detailed error logging                            //
    //      + STYLE: Matrix Hacking Theme (Green/Black)                                              //
    //      + VFX: Particles changed to Random Code Characters (0, 1, X, Z)                          //
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
    Version = "5.1.0-MATRIX",
    FileName = "HairKey_Auth_V5.bin",
    EncryptionKey = "TITAN_ULTRA_SECRET_KEY_2026",

    -- [Visuals - HACKER MODE]
    Theme = {
        Background = Color3.fromRGB(0, 5, 0),       -- Matrix Black
        Panel = Color3.fromRGB(5, 15, 5),           -- Dark Terminal Green
        PanelBorder = Color3.fromRGB(0, 50, 0),
        
        Primary = Color3.fromRGB(0, 255, 70),       -- Terminal Green
        Secondary = Color3.fromRGB(150, 255, 150),  -- Pale Green
        
        Text = Color3.fromRGB(200, 255, 200),       -- Light Green Text
        TextDim = Color3.fromRGB(50, 100, 50),      -- Dim Green
        
        Success = Color3.fromRGB(0, 255, 0),        -- Pure Green
        Error = Color3.fromRGB(255, 50, 50),        -- Error Red
        Warning = Color3.fromRGB(255, 200, 0)       -- Warning Yellow
    },
    
    -- [Assets]
    Assets = {
        Font = Enum.Font.Code,          -- Hacking Font
        HeaderFont = Enum.Font.Code,    -- Hacking Font
        CodeFont = Enum.Font.Code,
        GridTexture = "rbxassetid://37243876",
        NoiseTexture = "rbxassetid://16440628399",
        Icons = {
            Key = "rbxassetid://877797859",
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
    local color = "@@GREEN@@" -- Hacker style log
    
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
-- [5] UTILITIES: NETWORK (DEBUGGED)
-- ==================================================================================================
local Network = {}

function Network.Request(url, method, body)
    -- Auto-detect request function
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    
    if not requestFunc then
        warn("[HAIRKEY] CRITICAL: No HTTP Request function found! Your executor might not support this.")
        return {Body = nil, StatusCode = 0}
    end

    local attempts = 0
    local response
    local success
    local errMessage

    repeat
        attempts = attempts + 1
        success, response = pcall(function()
            return requestFunc({
                Url = url,
                Method = method or "GET",
                Headers = {
                    ["Content-Type"] = "application/json"
                    -- User-Agent removed to prevent "Header User-Agent is not allowed" error
                },
                Body = body and HttpService:JSONEncode(body) or nil
            })
        end)
        
        if not success then
            errMessage = response -- pcall returns error message in 2nd arg if failed
            warn("[HAIRKEY] Request Failed (Attempt "..attempts.."): " .. tostring(errMessage))
            task.wait(0.5)
        end
    until (success and response) or attempts >= CFG.MaxRetries

    if not success then
        warn("[HAIRKEY] Final Error: " .. tostring(errMessage))
        return {Body = nil, StatusCode = 0, StatusMessage = tostring(errMessage)} 
    end

    return response
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

-- [MATRIX CHARACTERS ENGINE]
function VFX.SpawnParticles(parent, count)
    local container = Instance.new("Frame")
    container.Name = "FX_Matrix"
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 1, 0)
    container.ZIndex = 1
    container.Parent = parent

    if VFX.Connections[parent] then VFX.Connections[parent]:Disconnect() end

    local particles = {}
    local chars = {"0", "1", "X", "Z", "Ø", "§", "∆", "¥"}
    
    for i = 1, count do
        local p = Instance.new("TextLabel")
        p.BackgroundTransparency = 1
        p.TextColor3 = CFG.Theme.Primary
        p.TextSize = math.random(10, 18)
        p.Font = Enum.Font.Code
        p.Text = chars[math.random(1, #chars)]
        p.Size = UDim2.new(0, 20, 0, 20)
        p.Position = UDim2.new(math.random(), 0, math.random(), 0)
        p.TextTransparency = math.random(0.3, 0.8)
        p.Parent = container
        
        table.insert(particles, {
            Obj = p,
            Speed = math.random(2, 8), -- Falling speed
            ChangeRate = math.random(5, 20)
        })
    end
    
    local tickCount = 0
    VFX.Connections[parent] = RunService.RenderStepped:Connect(function(dt)
        tickCount = tickCount + 1
        for _, p in ipairs(particles) do
            local pos = p.Obj.Position
            local newY = pos.Y.Scale + (p.Speed * 0.05 * dt) -- Fall down
            
            if newY > 1 then 
                newY = -0.1 
                p.Obj.Position = UDim2.new(math.random(), 0, newY, 0)
            else
                p.Obj.Position = UDim2.new(pos.X.Scale, 0, newY, 0)
            end
            
            -- Random character change glitch effect
            if tickCount % p.ChangeRate == 0 then
                p.Obj.Text = chars[math.random(1, #chars)]
            end
        end
    end)
end

-- [CRT OVERLAY]
function VFX.ApplyCRT(parent)
    local scanline = Instance.new("ImageLabel")
    scanline.Name = "FX_CRT"
    scanline.BackgroundTransparency = 1
    scanline.Size = UDim2.new(1, 0, 1, 0)
    scanline.Image = CFG.Assets.GridTexture    -- Scanlines
    scanline.ImageTransparency = 0.92
    scanline.ImageColor3 = Color3.fromRGB(0, 255, 0) -- Green tint
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

-- [[ NOTIFICATION SYSTEM ]]
function UI.Notify(msg, type)
    task.spawn(function()
        if not UI.Screen then return end
        
        -- Color Logic
        local accentColor = CFG.Theme.Primary
        if type == "ERR" then accentColor = CFG.Theme.Error 
        elseif type == "SUCCESS" then accentColor = CFG.Theme.Success end
        
        -- Main Container
        local container = UI.Create("Frame", {
            Name = "Notification",
            Parent = UI.Screen,
            BackgroundColor3 = Color3.fromRGB(0, 10, 0), -- Black Green
            Size = UDim2.new(0, 320, 0, 60),
            Position = UDim2.new(1, 20, 0.85, 0),
            BorderSizePixel = 0,
            ZIndex = 200
        })
        
        -- Styling
        UI.Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 4)})
        UI.Create("UIStroke", {Parent = container, Color = accentColor, Thickness = 1})
        
        -- Glitch Bar
        UI.Create("Frame", {
            Parent = container, BackgroundColor3 = accentColor,
            Size = UDim2.new(0, 6, 1, 0), Position = UDim2.new(0, 0, 0, 0),
            BorderSizePixel = 0, ZIndex = 201
        })
        
        -- Title
        UI.Create("TextLabel", {
            Parent = container, BackgroundTransparency = 1,
            Size = UDim2.new(1, -50, 0, 20), Position = UDim2.new(0, 15, 0, 5),
            Text = (type == "ERR" and "SYSTEM_FAILURE") or (type == "SUCCESS" and "SYSTEM_SUCCESS") or "SYSTEM_MSG",
            TextColor3 = accentColor, Font = Enum.Font.Code, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 202
        })
        
        -- Message
        UI.Create("TextLabel", {
            Parent = container, BackgroundTransparency = 1,
            Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 15, 0, 22),
            Text = msg, TextColor3 = Color3.fromRGB(220, 255, 220),
            Font = Enum.Font.Code, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 202
        })
        
        -- Progress Bar
        local progress = UI.Create("Frame", {
            Parent = container, BackgroundColor3 = accentColor, BorderSizePixel = 0,
            Size = UDim2.new(1, -6, 0, 2), Position = UDim2.new(0, 6, 1, -2),
            BackgroundTransparency = 0.2, ZIndex = 202
        })

        VFX.PlaySound(type == "ERR" and "Error" or "Success")
        
        -- Animation
        VFX.Tween(container, 0.4, {Position = UDim2.new(1, -340, 0.85, 0)})
        VFX.Tween(progress, 4, {Size = UDim2.new(0, 0, 0, 2)})
        task.wait(4)
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
        TextColor3 = CFG.Theme.Primary, Font = CFG.Assets.CodeFont, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = ""
    })
    
    local lines = {
        "ROOT@TITAN:~# init protocol v"..CFG.Version,
        "ROOT@TITAN:~# load_modules --all",
        "[ OK ] Memory Allocation",
        "[ OK ] NetSockets Initialized",
        "ROOT@TITAN:~# ping " .. CFG.Domain,
        "Reply from server: bytes=32 time=24ms TTL=54",
        "[ OK ] Connection Secure",
        "ROOT@TITAN:~# launch_gui"
    }
    
    VFX.PlaySound("Boot")
    
    for _, l in ipairs(lines) do
        term.Text = term.Text .. l .. "\n"
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
        Size = UDim2.new(0, 500, 0, 300),
        Position = UDim2.new(0.5, -250, 0.5, -150),
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Visible = false
    })
    
    -- Matrix Border
    local Stroke = UI.Create("UIStroke", {Parent = MainFrame, Thickness = 2, Color = CFG.Theme.Primary, Transparency = 0})
    
    -- Background Particles (Matrix Rain)
    VFX.SpawnParticles(MainFrame, 40)
    VFX.ApplyCRT(MainFrame)

    -- 2. HEADER
    local TopBar = UI.Create("Frame", {Parent = MainFrame, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,40), ZIndex = 10})
    UI.MakeDraggable(MainFrame, TopBar)
    
    UI.Create("TextLabel", {
        Parent = TopBar,
        Text = "> " .. CFG.AppName .. "_AUTH",
        Font = CFG.Assets.CodeFont, TextSize = 18,
        TextColor3 = CFG.Theme.Primary, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 15, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1
    })
    
    local CloseBtn = UI.Create("TextButton", {
        Parent = TopBar, Text = "[X]", Font = CFG.Assets.CodeFont, TextSize = 18,
        TextColor3 = CFG.Theme.Error, BackgroundTransparency = 1,
        Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -40, 0, 0)
    })
    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        UI.Notify("Minimized to background process.", "WARN")
    end)

    -- 3. CONTENT AREA
    local Content = UI.Create("Frame", {Parent = MainFrame, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -60), Position = UDim2.new(0, 20, 0, 50), ZIndex = 10})
    
    -- Key Input
    local InputFrame = UI.Create("Frame", {
        Parent = Content, BackgroundColor3 = CFG.Theme.Panel, Size = UDim2.new(1, 0, 0, 45), Position = UDim2.new(0,0,0.1,0)
    })
    local InputStroke = UI.Create("UIStroke", {Parent = InputFrame, Color = CFG.Theme.PanelBorder, Thickness = 1})
    
    local InputBox = UI.Create("TextBox", {
        Parent = InputFrame, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        Text = "", PlaceholderText = "INPUT_ACCESS_KEY...", TextColor3 = CFG.Theme.Primary, PlaceholderColor3 = CFG.Theme.TextDim,
        Font = CFG.Assets.CodeFont, TextSize = 14, ClearTextOnFocus = false
    })
    
    InputBox.Focused:Connect(function() VFX.Tween(InputStroke, 0.3, {Color = CFG.Theme.Primary}) end)
    InputBox.FocusLost:Connect(function() VFX.Tween(InputStroke, 0.3, {Color = CFG.Theme.PanelBorder}) end)

    -- Button Creator
    local function CreateMatrixBtn(text, pos, color, callback)
        local btn = UI.Create("TextButton", {
            Parent = Content, BackgroundColor3 = color, BackgroundTransparency = 0.8,
            Size = UDim2.new(0.48, 0, 0, 40), Position = pos, Text = "", AutoButtonColor = false
        })
        UI.Create("UIStroke", {Parent = btn, Color = color, Thickness = 1})
        
        UI.Create("TextLabel", {
            Parent = btn, BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
            Text = text, Font = CFG.Assets.CodeFont, TextSize = 14, TextColor3 = color
        })
        
        btn.MouseEnter:Connect(function() 
            VFX.Tween(btn, 0.2, {BackgroundTransparency = 0.5}) 
        end)
        btn.MouseLeave:Connect(function() 
            VFX.Tween(btn, 0.2, {BackgroundTransparency = 0.8}) 
        end)
        btn.MouseButton1Click:Connect(function()
            VFX.PlaySound("Click")
            callback()
        end)
        
        return btn
    end
    
    -- Action Logic
    local function GetKey()
        UI.Notify("INITIALIZING HANDSHAKE...", "WARN")
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local res = Network.Request(CFG.Domain .. "/api/handshake", "POST", {hwid = hwid})
        
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.success then
                setclipboard(data.url)
                UI.Notify("LINK COPIED TO CLIPBOARD", "SUCCESS")
            else
                UI.Notify("SERVER ERR: " .. (data.error or "Unknown"), "ERR")
            end
        else
            -- Detailed Error for User
            UI.Notify("CONN FAIL ("..res.StatusCode..")", "ERR")
            print("[HAIRKEY DEBUG] Error Body:", res.Body)
        end
    end
    
    local function Verify()
        local key = InputBox.Text
        if key:gsub(" ", "") == "" then UI.Notify("KEY_EMPTY", "ERR") return end
        
        UI.Notify("VERIFYING TOKEN...", "WARN")
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local res = Network.Request(CFG.Domain .. "/api/check-key?hwid="..hwid.."&key="..key, "GET")
        
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.valid then
                UI.Notify("ACCESS GRANTED", "SUCCESS")
                Crypt.Save({key = key})
                VFX.Tween(MainFrame, 0.5, {Size = UDim2.new(0, 500, 0, 0), Position = UDim2.new(0.5, -250, 0.5, 0)})
                task.wait(0.5)
                MainFrame.Visible = false
                OnKeyCorrect()
            else
                UI.Notify("ACCESS DENIED: INVALID KEY", "ERR")
            end
        else
            UI.Notify("SERVER TIMEOUT", "ERR")
        end
    end
    
    local BtnGet = CreateMatrixBtn("[ GET KEY ]", UDim2.new(0,0,0.6,0), CFG.Theme.Secondary, GetKey)
    local BtnVer = CreateMatrixBtn("[ LOGIN ]", UDim2.new(0.52,0,0.6,0), CFG.Theme.Primary, Verify)

    -- 4. FOOTER STATUS
    local Status = UI.Create("TextLabel", {
        Parent = MainFrame, BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 1, -25),
        Text = "STATUS: AWAITING_INPUT | SECURE_CONN: TRUE", Font = CFG.Assets.CodeFont, TextSize = 10,
        TextColor3 = CFG.Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left
    })
    
    -- 5. FLOATING WIDGET
    local Widget = UI.Create("ImageButton", {
        Parent = UI.Screen, BackgroundColor3 = CFG.Theme.Panel,
        Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 20, 0.5, -20),
        Image = CFG.Assets.Icons.Key, ImageColor3 = CFG.Theme.Primary,
        BorderSizePixel = 0
    })
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
                UI.Notify("AUTO_LOGIN: SUCCESS", "SUCCESS")
                OnKeyCorrect()
                return
            end
        end
    end
    
    MainFrame.Visible = true
    UI.RunBoot(MainFrame, function() end)
end

return HairKey