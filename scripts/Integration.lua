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
    //      HAIRKEY CLIENT - TITAN PRO MAX EDITION (v4.0)                                            //
    //      "The Absolute Zenith of Roblox Authentication Systems"                                   //
    //                                                                                               //
    //      [SYSTEM ARCHITECTURE]                                                                    //
    //      > MODULE: Core Services & Network Interface                                              //
    //      > MODULE: Cryptography (XOR + Base64 Layering)                                           //
    //      > MODULE: VisualFX Engine (Particles, Tweening, Shaders)                                 //
    //      > MODULE: User Interface (Glassmorphism, Parallax, CRT)                                  //
    //      > MODULE: Audio Engineering (Spatial UI Sounds)                                          //
    //                                                                                               //
    //      [CHANGELOG v4.0]                                                                         //
    //      + Added "Quantum" Particle Engine (2D Physics)                                           //
    //      + Implemented Mouse Parallax Background                                                  //
    //      + Added Text Decryption/Scramble Effect                                                  //
    //      + Enhanced CRT Scanline Overlay                                                          //
    //      + Optimized Network Retries                                                              //
    //                                                                                               //
    //      [AUTHOR] HairKey Development Team                                                        //
    //      [LICENSE] Proprietary - Do Not Distribute                                                //
    //                                                                                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////////
]]

local HairKey = {}
HairKey.__index = HairKey

-- ==================================================================================================
-- [1] CORE SERVICES
-- ==================================================================================================
-- Standard Roblox services used throughout the script.
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ==================================================================================================
-- [2] CONFIGURATION MATRIX
-- ==================================================================================================
-- Central configuration for the entire system.
local CFG = {
    -- [Network]
    Domain = "https://hairkey.onrender.com",
    RequestTimeout = 15,
    MaxRetries = 3,

    -- [System]
    AppName = "TITAN PROTOCOL",
    Version = "4.0.2-Build",
    FileName = "HairKey_Auth_V4.bin",
    EncryptionKey = "TITAN_PRO_MAX_SECRET_KEY_2025",

    -- [Visuals]
    Theme = {
        Background = Color3.fromRGB(5, 5, 8),
        Panel = Color3.fromRGB(12, 12, 16),
        PanelBorder = Color3.fromRGB(30, 30, 40),
        
        Primary = Color3.fromRGB(0, 255, 230),   -- Cyan Neon
        Secondary = Color3.fromRGB(130, 0, 255), -- Purple Neon
        Tertiary = Color3.fromRGB(255, 0, 110),  -- Pink Neon
        
        Text = Color3.fromRGB(240, 240, 255),
        TextDim = Color3.fromRGB(140, 140, 160),
        
        Success = Color3.fromRGB(50, 255, 100),
        Error = Color3.fromRGB(255, 50, 50),
        Warning = Color3.fromRGB(255, 200, 50)
    },
    
    -- [Assets]
    Assets = {
        Font = Enum.Font.Code,
        HeaderFont = Enum.Font.GothamBlack,
        GridTexture = "rbxassetid://6071575925",
        NoiseTexture = "rbxassetid://16440628399", -- Scanline/Noise
        Icons = {
            Key = "rbxassetid://13853153610",
            Close = "rbxassetid://3926305904",
            Lock = "rbxassetid://3926307971",
            Check = "rbxassetid://3926305904"
        }
    },

    -- [Audio]
    Sounds = {
        Hover = 4590662766,
        Click = 4590657391,
        Success = 5153734232,
        Error = 4590608263,
        Boot = 6276409843,
        Typing = 5646698666,
        Ambient = 1843343384
    }
}

-- ==================================================================================================
-- [3] UTILITIES: LOGGER
-- ==================================================================================================
-- Advanced logging system for debugging and console aesthetics.
local Logger = {}

function Logger.Print(msg, level)
    local prefix = "[HAIRKEY]"
    local color = Color3.fromRGB(0, 255, 230)
    local timestamp = os.date("%H:%M:%S")
    
    if level == "WARN" then
        prefix = "[WARNING]"
        color = Color3.fromRGB(255, 200, 0)
    elseif level == "ERR" then
        prefix = "[ERROR]"
        color = Color3.fromRGB(255, 50, 50)
    elseif level == "SUCCESS" then
        prefix = "[SUCCESS]"
        color = Color3.fromRGB(50, 255, 100)
    end

    -- Format for Roblox Console
    if rconsoleprint then
        rconsoleprint("@@WHITE@@")
        rconsoleprint("["..timestamp.."] ")
        if level == "ERR" then rconsoleprint("@@RED@@")
        elseif level == "WARN" then rconsoleprint("@@YELLOW@@")
        elseif level == "SUCCESS" then rconsoleprint("@@GREEN@@")
        else rconsoleprint("@@CYAN@@")
        end
        rconsoleprint(prefix .. " " .. msg .. "\n")
    else
        print(prefix, msg)
    end
end

-- ==================================================================================================
-- [4] UTILITIES: CRYPTOGRAPHY
-- ==================================================================================================
-- Security layer for local file storage.
local Crypt = {}

-- XOR Encryption Algorithm
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

-- Save Data Securely
function Crypt.Save(keyData)
    if not writefile then return end
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(keyData)
        local encrypted = Crypt.XOR(json, CFG.EncryptionKey)
        writefile(CFG.FileName, encrypted)
    end)
    if not success then Logger.Print("Failed to save local key: " .. tostring(err), "ERR") end
end

-- Load Data Securely
function Crypt.Load()
    if not isfile or not isfile(CFG.FileName) then return nil end
    local success, result = pcall(function()
        local encrypted = readfile(CFG.FileName)
        local decrypted = Crypt.XOR(encrypted, CFG.EncryptionKey)
        return HttpService:JSONDecode(decrypted)
    end)
    
    if success then return result else return nil end
end

-- ==================================================================================================
-- [5] UTILITIES: NETWORK
-- ==================================================================================================
-- Handles HTTP requests with retry logic and executor compatibility.
local Network = {}

function Network.Request(url, method, body)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    
    if not requestFunc then
        Logger.Print("Executor does not support HTTP requests!", "ERR")
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
                    ["User-Agent"] = "HairKey-Client/" .. CFG.Version
                },
                Body = body and HttpService:JSONEncode(body) or nil
            })
        end)

        if not success or not response then
            Logger.Print("Request failed (Attempt " .. attempts .. "/" .. CFG.MaxRetries .. ")", "WARN")
            task.wait(1)
        end
    until (success and response) or attempts >= CFG.MaxRetries

    if success then 
        return response 
    else 
        return {Body = nil, StatusCode = 0} 
    end
end

-- ==================================================================================================
-- [6] VISUAL FX ENGINE
-- ==================================================================================================
-- Custom visual effects system (Particles, Shaders, Sounds).
local VFX = {}
VFX.Particles = {}
VFX.Connections = {}

-- [[ SOUND MANAGER ]]
function VFX.PlaySound(name, volumePitchData)
    local id = CFG.Sounds[name]
    if not id then return end
    
    task.spawn(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://" .. id
        sound.Volume = (volumePitchData and volumePitchData.Volume) or 0.5
        sound.Pitch = (volumePitchData and volumePitchData.Pitch) or (0.9 + math.random()*0.2) -- Random pitch for variation
        sound.Parent = SoundService
        sound.PlayOnRemove = true
        sound:Destroy()
    end)
end

-- [[ TWEEN WRAPPER ]]
function VFX.Tween(obj, info, props)
    local t = TweenService:Create(obj, TweenInfo.new(info, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- [[ TEXT SCRAMBLER EFFECT ]]
-- Simulates a decryption effect on text labels.
function VFX.ScrambleText(label, targetText, duration)
    task.spawn(function()
        local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"
        local startTime = tick()
        local len = #targetText
        
        while tick() - startTime < duration do
            local progress = (tick() - startTime) / duration
            local revealCount = math.floor(progress * len)
            
            local scrambled = ""
            for i = 1, len do
                if i <= revealCount then
                    scrambled = scrambled .. string.sub(targetText, i, i)
                else
                    local r = math.random(1, #chars)
                    scrambled = scrambled .. string.sub(chars, r, r)
                end
            end
            label.Text = scrambled
            RunService.RenderStepped:Wait()
        end
        label.Text = targetText
    end)
end

-- [[ PARTICLE ENGINE ]]
-- A 2D particle system using GuiObjects.
function VFX.SpawnParticles(parent, count)
    local container = Instance.new("Frame")
    container.Name = "ParticleLayer"
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 1, 0)
    container.ZIndex = 0
    container.Parent = parent

    -- Cleanup old connections
    if VFX.Connections[parent] then VFX.Connections[parent]:Disconnect() end

    local particles = {}
    
    -- Initialize Particles
    for i = 1, count do
        local p = Instance.new("Frame")
        p.BorderSizePixel = 0
        p.BackgroundColor3 = CFG.Theme.Primary
        p.Size = UDim2.new(0, math.random(2, 4), 0, math.random(2, 4))
        p.Position = UDim2.new(math.random(), 0, math.random(), 0)
        p.BackgroundTransparency = math.random(0.5, 0.9)
        p.Parent = container
        
        table.insert(particles, {
            Obj = p,
            Speed = math.random(10, 30),
            Angle = math.rad(math.random(0, 360)),
            RotSpeed = math.rad(math.random(-50, 50))
        })
    end
    
    -- Physics Loop
    VFX.Connections[parent] = RunService.RenderStepped:Connect(function(dt)
        for _, p in ipairs(particles) do
            local x = p.Obj.Position.X.Scale
            local y = p.Obj.Position.Y.Scale
            
            -- Simple Movement
            x = x + (math.cos(p.Angle) * p.Speed * 0.0005)
            y = y + (math.sin(p.Angle) * p.Speed * 0.0005)
            
            -- Screen Wrapping
            if x > 1 then x = 0 elseif x < 0 then x = 1 end
            if y > 1 then y = 0 elseif y < 0 then y = 1 end
            
            p.Obj.Position = UDim2.new(x, 0, y, 0)
            p.Obj.Rotation = p.Obj.Rotation + (p.RotSpeed * dt * 10)
        end
    end)
end

-- [[ CRT SCANLINE SHADER ]]
-- Adds a retro scanline overlay effect.
function VFX.ApplyCRT(parent)
    local overlay = Instance.new("ImageLabel")
    overlay.Name = "CRT_Overlay"
    overlay.BackgroundTransparency = 1
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Image = CFG.Assets.NoiseTexture
    overlay.ImageTransparency = 0.92
    overlay.ScaleType = Enum.ScaleType.Tile
    overlay.TileSize = UDim2.new(0, 50, 0, 2) -- Thin lines
    overlay.ZIndex = 100
    overlay.Parent = parent

    -- Scroll the texture
    task.spawn(function()
        local t = 0
        while parent.Parent do
            t = t + 0.5
            overlay.TileSize = UDim2.new(0, 50, 0, 2 + math.sin(t*0.1))
            RunService.RenderStepped:Wait()
        end
    end)
end

-- ==================================================================================================
-- [7] UI ENGINE: COMPONENT BUILDER
-- ==================================================================================================
-- Builds the GUI elements with high-level functions.
local UI = {}
UI.Screen = nil

function UI.Create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" and k ~= "Children" then
            inst[k] = v
        end
    end
    
    if props.Children then
        for _, child in pairs(props.Children) do
            child.Parent = inst
        end
    end
    
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

function UI.MakeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    RunService.RenderStepped:Connect(function()
        if dragging and dragInput then
            local delta = dragInput.Position - dragStart
            local newX = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            VFX.Tween(frame, 0.05, {Position = newX})
        end
    end)
end

-- [[ NOTIFICATION COMPONENT ]]
function UI.Notify(msg, type)
    task.spawn(function()
        if not UI.Screen then return end
        
        local color = CFG.Theme.Primary
        if type == "ERR" then color = CFG.Theme.Error end
        if type == "SUCCESS" then color = CFG.Theme.Success end
        
        local container = UI.Create("Frame", {
            Parent = UI.Screen,
            BackgroundColor3 = CFG.Theme.Panel,
            Size = UDim2.new(0, 300, 0, 50),
            Position = UDim2.new(1, 20, 0.85, 0), -- Start off-screen
            BorderSizePixel = 0,
            ZIndex = 200
        })
        
        UI.Create("UICorner", {Parent = container, CornerRadius = UDim.new(0, 6)})
        UI.Create("UIStroke", {Parent = container, Color = color, Thickness = 2, Transparency = 0.5})
        
        -- Decorative Bar
        UI.Create("Frame", {
            Parent = container,
            BackgroundColor3 = color,
            Size = UDim2.new(0, 4, 1, -16),
            Position = UDim2.new(0, 8, 0, 8),
            BorderSizePixel = 0
        })
        
        local textLabel = UI.Create("TextLabel", {
            Parent = container,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -30, 1, 0),
            Position = UDim2.new(0, 20, 0, 0),
            Text = msg,
            TextColor3 = CFG.Theme.Text,
            Font = CFG.Assets.Font,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true
        })

        -- Play sound
        if type == "ERR" then VFX.PlaySound("Error") else VFX.PlaySound("Success") end
        
        -- Animation: Slide In
        VFX.Tween(container, 0.5, {Position = UDim2.new(1, -320, 0.85, 0)})
        
        task.wait(4)
        
        -- Animation: Slide Out
        VFX.Tween(container, 0.5, {Position = UDim2.new(1, 20, 0.85, 0)})
        task.wait(0.5)
        container:Destroy()
    end)
end

-- [[ BOOT ANIMATION COMPONENT ]]
function UI.RunBootSequence(parent, callback)
    local bootFrame = UI.Create("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 500
    })
    
    local console = UI.Create("TextLabel", {
        Parent = bootFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.9, 0, 0.9, 0),
        Position = UDim2.new(0.05, 0, 0.05, 0),
        Text = "",
        TextColor3 = CFG.Theme.Primary,
        Font = Enum.Font.Code,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top
    })
    
    local logs = {
        "INITIALIZING " .. CFG.AppName .. " KERNEL v" .. CFG.Version,
        "ALLOCATING MEMORY BLOCKS [0x44F - 0xFF2]...",
        "LOADING ASSETS... SUCCESS",
        "ESTABLISHING SECURE CONNECTION TO " .. string.sub(CFG.Domain, 9, 25) .. "...",
        "VERIFYING INTEGRITY...",
        "HANDSHAKE COMPLETE.",
        "LAUNCHING GUI..."
    }
    
    VFX.PlaySound("Boot")
    
    for _, line in ipairs(logs) do
        console.Text = console.Text .. "> " .. line .. "\n"
        VFX.PlaySound("Typing", {Volume = 0.2, Pitch = 1 + (math.random() * 0.2)})
        task.wait(math.random(1, 4) / 10)
    end
    
    task.wait(0.5)
    
    -- Fade out
    VFX.Tween(bootFrame, 0.8, {BackgroundTransparency = 1})
    VFX.Tween(console, 0.8, {TextTransparency = 1})
    task.wait(0.8)
    bootFrame:Destroy()
    
    if callback then callback() end
end


-- ==================================================================================================
-- [8] MAIN LOGIC CONTROLLER
-- ==================================================================================================
-- Coordinates the logic between UI, Network, and User Input.

function HairKey.init(config)
    -- Override defaults
    if config.ApplicationName then CFG.AppName = config.ApplicationName end
    local OnKeyCorrect = config.OnKeyCorrect or function() print("Key Correct") end

    -- Cleanup old GUI
    for _, v in pairs(CoreGui:GetChildren()) do
        if v.Name == "HairKey_Titan_V4" then v:Destroy() end
    end
    
    UI.Screen = UI.Create("ScreenGui", {Name = "HairKey_Titan_V4", Parent = CoreGui})

    -- 1. BUILD MAIN WINDOW
    local MainFrame = UI.Create("Frame", {
        Name = "MainFrame",
        Parent = UI.Screen,
        BackgroundColor3 = CFG.Theme.Background,
        Size = UDim2.new(0, 520, 0, 340),
        Position = UDim2.new(0.5, -260, 0.5, -170),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false -- Hidden initially for boot
    })
    
    UI.Create("UICorner", {Parent = MainFrame, CornerRadius = UDim.new(0, 10)})
    
    -- Holographic Border
    local BorderStroke = UI.Create("UIStroke", {Parent = MainFrame, Thickness = 2, Transparency = 0})
    local BorderGradient = UI.Create("UIGradient", {
        Parent = BorderStroke,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, CFG.Theme.Primary),
            ColorSequenceKeypoint.new(0.5, CFG.Theme.Secondary),
            ColorSequenceKeypoint.new(1, CFG.Theme.Primary)
        }),
        Rotation = 45
    })
    
    -- Animate Border
    task.spawn(function()
        while MainFrame.Parent do
            BorderGradient.Rotation = BorderGradient.Rotation + 1
            task.wait(0.02)
        end
    end)
    
    -- Parallax Background
    local ParallaxBg = UI.Create("ImageLabel", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Image = CFG.Assets.GridTexture,
        ImageColor3 = CFG.Theme.Primary,
        ImageTransparency = 0.9,
        Size = UDim2.new(1.5, 0, 1.5, 0), -- Larger than frame
        Position = UDim2.new(-0.25, 0, -0.25, 0),
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.new(0, 40, 0, 40)
    })
    
    -- Parallax Logic
    RunService.RenderStepped:Connect(function()
        if not MainFrame.Visible then return end
        local mX = Mouse.X / workspace.CurrentCamera.ViewportSize.X
        local mY = Mouse.Y / workspace.CurrentCamera.ViewportSize.Y
        
        local targetX = -0.25 + (mX - 0.5) * 0.05
        local targetY = -0.25 + (mY - 0.5) * 0.05
        
        ParallaxBg.Position = ParallaxBg.Position:Lerp(UDim2.new(targetX, 0, targetY, 0), 0.1)
    end)
    
    -- Apply Effects
    VFX.SpawnParticles(MainFrame, 20)
    VFX.ApplyCRT(MainFrame)
    
    -- 2. BUILD HEADER
    local TopBar = UI.Create("Frame", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 45),
        ZIndex = 5
    })
    UI.MakeDraggable(MainFrame, TopBar)
    
    local Title = UI.Create("TextLabel", {
        Parent = TopBar,
        Text = CFG.AppName .. " <font color='#888'>// ACCESS TERMINAL</font>",
        RichText = true,
        Font = CFG.Assets.HeaderFont,
        TextSize = 18,
        TextColor3 = CFG.Theme.Text,
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 20, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1
    })
    
    local CloseBtn = UI.Create("ImageButton", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 45, 0, 45),
        Position = UDim2.new(1, -45, 0, 0),
        Image = CFG.Assets.Icons.Close,
        ImageColor3 = CFG.Theme.Error,
        ImageRectOffset = Vector2.new(284, 4),
        ImageRectSize = Vector2.new(24, 24)
    })
    
    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        UI.Notify("Minimized to Widget. Click icon to restore.", "WARN")
        VFX.PlaySound("Click")
    end)
    
    -- 3. BUILD CONTENT
    local ContentContainer = UI.Create("Frame", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 1, -60),
        Position = UDim2.new(0, 20, 0, 50),
        ZIndex = 5
    })
    
    -- Input Field
    local InputBg = UI.Create("Frame", {
        Parent = ContentContainer,
        BackgroundColor3 = CFG.Theme.Panel,
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.new(0, 0, 0.25, 0)
    })
    UI.Create("UICorner", {Parent = InputBg, CornerRadius = UDim.new(0, 8)})
    UI.Create("UIStroke", {Parent = InputBg, Color = Color3.fromRGB(50,50,60), Thickness = 1})
    
    local KeyInput = UI.Create("TextBox", {
        Parent = InputBg,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Text = "",
        PlaceholderText = "ENTER SECURITY KEY...",
        TextColor3 = CFG.Theme.Primary,
        PlaceholderColor3 = CFG.Theme.TextDim,
        Font = CFG.Assets.Font,
        TextSize = 16,
        ClearTextOnFocus = false
    })
    
    -- Focus Effect
    KeyInput.Focused:Connect(function()
        VFX.Tween(InputBg.UIStroke, 0.3, {Color = CFG.Theme.Primary})
    end)
    KeyInput.FocusLost:Connect(function()
        VFX.Tween(InputBg.UIStroke, 0.3, {Color = Color3.fromRGB(50,50,60)})
    end)
    
    -- Button Builder
    local function AddButton(text, pos, color, callback)
        local btn = UI.Create("TextButton", {
            Parent = ContentContainer,
            BackgroundColor3 = color,
            Size = UDim2.new(0.48, 0, 0, 45),
            Position = pos,
            Text = "",
            AutoButtonColor = false
        })
        UI.Create("UICorner", {Parent = btn, CornerRadius = UDim.new(0, 8)})
        
        -- Inner Text
        local label = UI.Create("TextLabel", {
            Parent = btn,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = text,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = Color3.new(0,0,0)
        })
        
        -- Glow Effect
        local glow = UI.Create("ImageLabel", {
            Parent = btn,
            BackgroundTransparency = 1,
            Image = "rbxassetid://5028857472", -- Glow texture
            ImageColor3 = color,
            Size = UDim2.new(1, 40, 1, 40),
            Position = UDim2.new(0, -20, 0, -20),
            ImageTransparency = 1,
            ZIndex = 0
        })
        
        -- Interactions
        btn.MouseEnter:Connect(function()
            VFX.PlaySound("Hover", {Volume = 0.2, Pitch = 1})
            VFX.Tween(glow, 0.2, {ImageTransparency = 0.4})
            VFX.Tween(btn, 0.1, {Size = UDim2.new(0.48, 4, 0, 49), Position = pos - UDim2.new(0, 2, 0, 2)})
        end)
        
        btn.MouseLeave:Connect(function()
            VFX.Tween(glow, 0.2, {ImageTransparency = 1})
            VFX.Tween(btn, 0.1, {Size = UDim2.new(0.48, 0, 0, 45), Position = pos})
        end)
        
        btn.MouseButton1Click:Connect(function()
            VFX.PlaySound("Click")
            
            -- Ripple Logic
            local rip = UI.Create("Frame", {
                Parent = btn, BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.6,
                Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0), AnchorPoint = Vector2.new(0.5,0.5)
            })
            UI.Create("UICorner", {Parent = rip, CornerRadius = UDim.new(1,0)})
            local t = VFX.Tween(rip, 0.4, {Size = UDim2.new(1.5,0,2.5,0), BackgroundTransparency = 1})
            t.Completed:Wait()
            rip:Destroy()
            
            callback()
        end)
    end
    
    -- 4. BUTTON LOGIC IMPLEMENTATION
    local function GetKeyAction()
        UI.Notify("Establishing Secure Handshake...", "WARN")
        
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local response = Network.Request(CFG.Domain .. "/api/handshake", "POST", {hwid = hwid})
        
        if response.StatusCode == 200 then
            local data = HttpService:JSONDecode(response.Body)
            if data.success then
                setclipboard(data.url)
                UI.Notify("Link Copied to Clipboard!", "SUCCESS")
            else
                UI.Notify("Server Error: " .. (data.error or "Unknown"), "ERR")
            end
        else
            UI.Notify("Connection Failed (" .. response.StatusCode .. ")", "ERR")
        end
    end
    
    local function VerifyAction()
        local key = KeyInput.Text
        if key == "" or key == " " then
            UI.Notify("Key field cannot be empty.", "ERR")
            return
        end
        
        UI.Notify("Verifying Access Token...", "WARN")
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local response = Network.Request(CFG.Domain .. "/api/check-key?hwid="..hwid.."&key="..key, "GET")
        
        if response.StatusCode == 200 then
            local data = HttpService:JSONDecode(response.Body)
            if data.valid then
                UI.Notify("Authentication Successful.", "SUCCESS")
                Crypt.Save({key = key, date = os.time()})
                
                -- Close Animation
                VFX.Tween(MainFrame, 0.5, {Size = UDim2.new(0, 520, 0, 0), Position = UDim2.new(0.5, -260, 0.5, 0)})
                task.wait(0.5)
                MainFrame.Visible = false
                if UI.Screen then UI.Screen:Destroy() end
                
                OnKeyCorrect()
            else
                UI.Notify("Invalid or Expired Key.", "ERR")
            end
        else
            UI.Notify("Server Timeout.", "ERR")
        end
    end
    
    -- Add Buttons
    AddButton("GET KEY LINK", UDim2.new(0, 0, 0.6, 0), CFG.Theme.Primary, GetKeyAction)
    AddButton("VERIFY ACCESS", UDim2.new(0.52, 0, 0.6, 0), CFG.Theme.Secondary, VerifyAction)
    
    -- 5. FOOTER & STATUS
    local StatusLabel = UI.Create("TextLabel", {
        Parent = ContentContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0.9, 0),
        Text = "> SYSTEM STATUS: WAITING FOR USER INPUT",
        TextColor3 = CFG.Theme.TextDim,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    -- Info Footer (Ping & HWID)
    local InfoLabel = UI.Create("TextLabel", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -10, 0, 15),
        Position = UDim2.new(0, 5, 1, -20),
        Text = "LATENCY: ... | ID: ...",
        TextColor3 = Color3.fromRGB(80, 80, 90),
        Font = Enum.Font.Code,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 6
    })
    
    -- Live Data Update
    task.spawn(function()
        while MainFrame.Parent do
            local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
            local rawHwid = game:GetService("RbxAnalyticsService"):GetClientId()
            local shortHwid = string.sub(rawHwid, 1, 12) .. "..."
            
            InfoLabel.Text = "LATENCY: " .. ping .. "ms | ID: " .. shortHwid
            task.wait(1)
        end
    end)
    
    -- 6. FLOATING WIDGET (Toggle)
    local Widget = UI.Create("ImageButton", {
        Name = "ToggleWidget",
        Parent = UI.Screen,
        BackgroundColor3 = CFG.Theme.Panel,
        Size = UDim2.new(0, 50, 0, 50),
        Position = UDim2.new(0, 20, 0.5, -25),
        Image = CFG.Assets.Icons.Key,
        ImageColor3 = CFG.Theme.Primary,
        ImageRectOffset = Vector2.new(0,0), -- Adjust if using spritesheet
        ImageRectSize = Vector2.new(0,0)    -- Adjust if using spritesheet
    })
    
    UI.Create("UICorner", {Parent = Widget, CornerRadius = UDim.new(0, 12)})
    local WidgetStroke = UI.Create("UIStroke", {Parent = Widget, Color = CFG.Theme.Primary, Thickness = 2})
    
    UI.MakeDraggable(Widget, Widget)
    
    Widget.MouseButton1Click:Connect(function()
        VFX.PlaySound("Click")
        MainFrame.Visible = not MainFrame.Visible
        if MainFrame.Visible then
            VFX.Tween(MainFrame, 0.3, {BackgroundTransparency = 0})
        end
    end)
    
    -- Pulse Widget
    task.spawn(function()
        while Widget.Parent do
            VFX.Tween(WidgetStroke, 1.5, {Color = CFG.Theme.Secondary})
            VFX.Tween(Widget, 1.5, {ImageColor3 = CFG.Theme.Secondary})
            task.wait(1.5)
            VFX.Tween(WidgetStroke, 1.5, {Color = CFG.Theme.Primary})
            VFX.Tween(Widget, 1.5, {ImageColor3 = CFG.Theme.Primary})
            task.wait(1.5)
        end
    end)
    
    -- ==============================================================================================
    -- [9] INITIALIZATION FLOW
    -- ==============================================================================================
    
    -- Step 1: Check Local Cache (Auto-Auth)
    local cachedData = Crypt.Load()
    if cachedData and cachedData.key then
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local res = Network.Request(CFG.Domain .. "/api/check-key?hwid="..hwid.."&key="..cachedData.key, "GET")
        
        if res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data.valid then
                VFX.PlaySound("Success")
                
                -- Create a temporary notification for silent login
                local silentNotif = Instance.new("ScreenGui", CoreGui)
                local frame = Instance.new("Frame", silentNotif)
                frame.Size = UDim2.new(0, 300, 0, 60)
                frame.Position = UDim2.new(0.5, -150, 0, -100)
                frame.BackgroundColor3 = CFG.Theme.Accent
                Instance.new("UICorner", frame)
                
                local lbl = Instance.new("TextLabel", frame)
                lbl.Size = UDim2.new(1,0,1,0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "⚡ QUICK LOGIN: ACCESS RESTORED"
                lbl.Font = Enum.Font.GothamBlack
                lbl.TextSize = 14
                
                VFX.Tween(frame, 0.5, {Position = UDim2.new(0.5, -150, 0, 50)})
                task.wait(3)
                VFX.Tween(frame, 0.5, {Position = UDim2.new(0.5, -150, 0, -100)})
                task.wait(0.5)
                silentNotif:Destroy()
                
                OnKeyCorrect()
                return -- Exit init, no GUI needed
            end
        end
    end
    
    -- Step 2: Boot GUI if verification failed or no key
    MainFrame.Visible = true
    UI.RunBootSequence(MainFrame, function()
        -- Callback when boot finishes
        Logger.Print("UI Initialized successfully.", "SUCCESS")
    end)
end

return HairKey