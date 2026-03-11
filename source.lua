--[[
esp-lib.lua
A library for creating esp visuals in roblox using drawing.
Provides functions to add boxes, health bars, names and distances to instances.
Written by tul (@.lutyeh).
Enhanced version with gradient healthbar and health text display.
]]--

-- // table
local esplib = getgenv().esplib
if not esplib then
    esplib = {}
    getgenv().esplib = esplib
end

-- Set defaults only if not already set
esplib.box = esplib.box or {
    enabled = true,
    type = "normal", -- normal, corner
    padding = 1.15,
    fill = Color3.new(1,1,1),
    outline = Color3.new(0,0,0),
}

esplib.healthbar = esplib.healthbar or {
    enabled = true,
    fill = Color3.new(0,1,0),
    outline = Color3.new(0,0,0),
    gradient = true, -- gradient from red to green
    low_color = Color3.new(1,0,0), -- red at low health
    high_color = Color3.new(0,1,0), -- green at high health
    width = 3, -- width of healthbar
    offset = 5, -- distance from box
}

esplib.name = esplib.name or {
    enabled = true,
    fill = Color3.new(1,1,1),
    size = 13,
    show_health = false, -- show health next to name
}

esplib.distance = esplib.distance or {
    enabled = true,
    fill = Color3.new(1,1,1),
    size = 13,
}

esplib.tracer = esplib.tracer or {
    enabled = true,
    fill = Color3.new(1,1,1),
    outline = Color3.new(0,0,0),
    from = "mouse", -- mouse, head, top, bottom, center
}

esplib.chams = esplib.chams or {
    enabled = false,
    fill_color = Color3.new(1, 0, 0),
    fill_transparency = 0.5,
    outline_color = Color3.new(1, 1, 1),
    outline_transparency = 0,
}

esplib.team_check = esplib.team_check or {
    enabled = false,
    enemy_color = Color3.new(1, 0, 0), -- red for enemies
    team_color = Color3.new(0, 1, 0), -- green for teammates
}

esplib.fade = esplib.fade or {
    enabled = false,
    max_distance = 500, -- start fading after this distance
    min_transparency = 0.3, -- minimum transparency at max distance
}

esplib.skeleton = esplib.skeleton or {
    enabled = false,
    color = Color3.new(1, 1, 1),
    thickness = 1,
}

local espinstances = {}
local espfunctions = {}

-- // services
local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera

-- // helper functions
local function lerp_color(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

local function get_distance(instance)
    if instance:IsA("Model") then
        if instance.PrimaryPart then
            return (camera.CFrame.Position - instance.PrimaryPart.Position).Magnitude
        else
            local part = instance:FindFirstChildWhichIsA("BasePart")
            if part then
                return (camera.CFrame.Position - part.Position).Magnitude
            end
        end
    elseif instance:IsA("BasePart") then
        return (camera.CFrame.Position - instance.Position).Magnitude
    end
    return 999
end

local function is_teammate(instance)
    if not esplib.team_check.enabled then return false end
    
    local player = players:GetPlayerFromCharacter(instance)
    if player and players.LocalPlayer then
        return player.Team == players.LocalPlayer.Team
    end
    return false
end

local function get_team_color(instance)
    if is_teammate(instance) then
        return esplib.team_check.team_color
    else
        return esplib.team_check.enemy_color
    end
end

local function calculate_fade_transparency(distance)
    if not esplib.fade.enabled then return 1 end
    
    if distance <= esplib.fade.max_distance then
        return 1
    else
        local fade_factor = math.clamp((distance - esplib.fade.max_distance) / esplib.fade.max_distance, 0, 1)
        return 1 - (fade_factor * (1 - esplib.fade.min_transparency))
    end
end

-- // functions
local function get_bounding_box(instance)
    local min, max = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
    local onscreen = false
    
    if instance:IsA("Model") then
        for _, p in ipairs(instance:GetChildren()) do
            if p:IsA("BasePart") then
                local size = (p.Size / 2) * esplib.box.padding
                local cf = p.CFrame
                for _, offset in ipairs({
                    Vector3.new( size.X,  size.Y,  size.Z),
                    Vector3.new(-size.X,  size.Y,  size.Z),
                    Vector3.new( size.X, -size.Y,  size.Z),
                    Vector3.new(-size.X, -size.Y,  size.Z),
                    Vector3.new( size.X,  size.Y, -size.Z),
                    Vector3.new(-size.X,  size.Y, -size.Z),
                    Vector3.new( size.X, -size.Y, -size.Z),
                    Vector3.new(-size.X, -size.Y, -size.Z),
                }) do
                    local pos, visible = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
                    if visible then
                        local v2 = Vector2.new(pos.X, pos.Y)
                        min = min:Min(v2)
                        max = max:Max(v2)
                        onscreen = true
                    end
                end
            elseif p:IsA("Accessory") then
                local handle = p:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    local size = (handle.Size / 2) * esplib.box.padding
                    local cf = handle.CFrame
                    for _, offset in ipairs({
                        Vector3.new( size.X,  size.Y,  size.Z),
                        Vector3.new(-size.X,  size.Y,  size.Z),
                        Vector3.new( size.X, -size.Y,  size.Z),
                        Vector3.new(-size.X, -size.Y,  size.Z),
                        Vector3.new( size.X,  size.Y, -size.Z),
                        Vector3.new(-size.X,  size.Y, -size.Z),
                        Vector3.new( size.X, -size.Y, -size.Z),
                        Vector3.new(-size.X, -size.Y, -size.Z),
                    }) do
                        local pos, visible = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
                        if visible then
                            local v2 = Vector2.new(pos.X, pos.Y)
                            min = min:Min(v2)
                            max = max:Max(v2)
                            onscreen = true
                        end
                    end
                end
            end
        end
    elseif instance:IsA("BasePart") then
        local size = (instance.Size / 2)
        local cf = instance.CFrame
        for _, offset in ipairs({
            Vector3.new( size.X,  size.Y,  size.Z),
            Vector3.new(-size.X,  size.Y,  size.Z),
            Vector3.new( size.X, -size.Y,  size.Z),
            Vector3.new(-size.X, -size.Y,  size.Z),
            Vector3.new( size.X,  size.Y, -size.Z),
            Vector3.new(-size.X,  size.Y, -size.Z),
            Vector3.new( size.X, -size.Y, -size.Z),
            Vector3.new(-size.X, -size.Y, -size.Z),
        }) do
            local pos, visible = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
            if visible then
                local v2 = Vector2.new(pos.X, pos.Y)
                min = min:Min(v2)
                max = max:Max(v2)
                onscreen = true
            end
        end
    end
    
    return min, max, onscreen
end

function espfunctions.add_box(instance)
    if not instance or espinstances[instance] and espinstances[instance].box then return end
    
    local box = {}
    
    local outline = Drawing.new("Square")
    outline.Thickness = 3
    outline.Filled = false
    outline.Transparency = 1
    outline.Visible = false
    
    local fill = Drawing.new("Square")
    fill.Thickness = 1
    fill.Filled = false
    fill.Transparency = 1
    fill.Visible = false
    
    box.outline = outline
    box.fill = fill
    box.corner_fill = {}
    box.corner_outline = {}
    
    for i = 1, 8 do
        local outline = Drawing.new("Line")
        outline.Thickness = 3
        outline.Transparency = 1
        outline.Visible = false
        
        local fill = Drawing.new("Line")
        fill.Thickness = 1
        fill.Transparency = 1
        fill.Visible = false
        
        table.insert(box.corner_fill, fill)
        table.insert(box.corner_outline, outline)
    end
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].box = box
end

function espfunctions.add_healthbar(instance)
    if not instance or espinstances[instance] and espinstances[instance].healthbar then return end
    
    local outline = Drawing.new("Square")
    outline.Thickness = 1
    outline.Filled = true
    outline.Transparency = 1
    
    local fill = Drawing.new("Square")
    fill.Filled = true
    fill.Transparency = 1
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].healthbar = {
        outline = outline,
        fill = fill,
    }
end

function espfunctions.add_name(instance)
    if not instance or espinstances[instance] and espinstances[instance].name then return end
    
    local text = Drawing.new("Text")
    text.Center = true
    text.Outline = true
    text.Font = 1
    text.Transparency = 1
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].name = text
end

function espfunctions.add_distance(instance)
    if not instance or espinstances[instance] and espinstances[instance].distance then return end
    
    local text = Drawing.new("Text")
    text.Center = true
    text.Outline = true
    text.Font = 1
    text.Transparency = 1
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].distance = text
end

function espfunctions.add_tracer(instance)
    if not instance or espinstances[instance] and espinstances[instance].tracer then return end
    
    local outline = Drawing.new("Line")
    outline.Thickness = 3
    outline.Transparency = 1
    
    local fill = Drawing.new("Line")
    fill.Thickness = 1
    fill.Transparency = 1
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].tracer = {
        outline = outline,
        fill = fill,
    }
end

function espfunctions.add_skeleton(instance)
    if not instance or espinstances[instance] and espinstances[instance].skeleton then return end
    
    local skeleton = {}
    local limb_connections = {
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},
    }
    
    for i = 1, #limb_connections do
        local line = Drawing.new("Line")
        line.Thickness = esplib.skeleton.thickness
        line.Transparency = 1
        line.Visible = false
        table.insert(skeleton, line)
    end
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].skeleton = {
        lines = skeleton,
        connections = limb_connections,
    }
end

function espfunctions.add_chams(instance)
    if not instance or espinstances[instance] and espinstances[instance].chams then return end
    
    local chams = {}
    
    if instance:IsA("Model") then
        for _, part in ipairs(instance:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("MeshPart") then
                local highlight = Instance.new("Highlight")
                highlight.Adornee = part
                highlight.FillColor = esplib.chams.fill_color
                highlight.FillTransparency = esplib.chams.fill_transparency
                highlight.OutlineColor = esplib.chams.outline_color
                highlight.OutlineTransparency = esplib.chams.outline_transparency
                highlight.Parent = part
                table.insert(chams, highlight)
            end
        end
    end
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].chams = chams
end

-- // main thread
run_service.RenderStepped:Connect(function()
    for instance, data in pairs(espinstances) do
        if not instance or not instance.Parent then
            if data.box then
                data.box.outline:Remove()
                data.box.fill:Remove()
                for _, line in ipairs(data.box.corner_fill) do
                    line:Remove()
                end
                for _, line in ipairs(data.box.corner_outline) do
                    line:Remove()
                end
            end
            if data.healthbar then
                data.healthbar.outline:Remove()
                data.healthbar.fill:Remove()
            end
            if data.name then
                data.name:Remove()
            end
            if data.distance then
                data.distance:Remove()
            end
            if data.tracer then
                data.tracer.outline:Remove()
                data.tracer.fill:Remove()
            end
            if data.skeleton then
                for _, line in ipairs(data.skeleton.lines) do
                    line:Remove()
                end
            end
            if data.chams then
                for _, highlight in ipairs(data.chams) do
                    highlight:Destroy()
                end
            end
            espinstances[instance] = nil
            continue
        end
        
        if instance:IsA("Model") and not instance.PrimaryPart then
            continue
        end
        
        local min, max, onscreen = get_bounding_box(instance)
        local distance = get_distance(instance)
        local transparency = calculate_fade_transparency(distance)
        local color = esplib.team_check.enabled and get_team_color(instance) or nil
        
        if data.box then
            local box = data.box
            if esplib.box.enabled and onscreen then
                local x, y = min.X, min.Y
                local w, h = (max - min).X, (max - min).Y
                local len = math.min(w, h) * 0.25
                
                if esplib.box.type == "normal" then
                    box.outline.Position = min
                    box.outline.Size = max - min
                    box.outline.Color = esplib.box.outline
                    box.outline.Transparency = transparency
                    box.outline.Visible = true
                    
                    box.fill.Position = min
                    box.fill.Size = max - min
                    box.fill.Color = color or esplib.box.fill
                    box.fill.Transparency = transparency
                    box.fill.Visible = true
                    
                    -- Hide corner lines when using normal box
                    for _, line in ipairs(box.corner_fill) do
                        line.Visible = false
                    end
                    for _, line in ipairs(box.corner_outline) do
                        line.Visible = false
                    end
                elseif esplib.box.type == "corner" then
                    -- Hide normal box when using corner
                    box.outline.Visible = false
                    box.fill.Visible = false
                    
                    local fill_lines = box.corner_fill
                    local outline_lines = box.corner_outline
                    local fill_color = color or esplib.box.fill
                    local outline_color = esplib.box.outline
                    
                    local corners = {
                        { Vector2.new(x, y), Vector2.new(x + len, y) },
                        { Vector2.new(x, y), Vector2.new(x, y + len) },
                        { Vector2.new(x + w - len, y), Vector2.new(x + w, y) },
                        { Vector2.new(x + w, y), Vector2.new(x + w, y + len) },
                        { Vector2.new(x, y + h), Vector2.new(x + len, y + h) },
                        { Vector2.new(x, y + h - len), Vector2.new(x, y + h) },
                        { Vector2.new(x + w - len, y + h), Vector2.new(x + w, y + h) },
                        { Vector2.new(x + w, y + h - len), Vector2.new(x + w, y + h) },
                    }
                    
                    for i = 1, 8 do
                        local from, to = corners[i][1], corners[i][2]
                        local dir = (to - from).Unit
                        local oFrom = from - dir
                        local oTo = to + dir
                        
                        local o = outline_lines[i]
                        o.From = oFrom
                        o.To = oTo
                        o.Color = outline_color
                        o.Transparency = transparency
                        o.Visible = true
                        
                        local f = fill_lines[i]
                        f.From = from
                        f.To = to
                        f.Color = fill_color
                        f.Transparency = transparency
                        f.Visible = true
                    end
                end
            else
                box.outline.Visible = false
                box.fill.Visible = false
                for _, line in ipairs(box.corner_fill) do
                    line.Visible = false
                end
                for _, line in ipairs(box.corner_outline) do
                    line.Visible = false
                end
            end
        end
        
        if data.healthbar then
            local outline, fill = data.healthbar.outline, data.healthbar.fill
            if not esplib.healthbar.enabled or not onscreen then
                outline.Visible = false
                fill.Visible = false
            else
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local height = max.Y - min.Y
                    local padding = 1
                    local bar_width = esplib.healthbar.width
                    local bar_offset = esplib.healthbar.offset
                    local x = min.X - bar_width - bar_offset
                    local y = min.Y - padding
                    local health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    local fillheight = height * health
                    
                    outline.Color = esplib.healthbar.outline
                    outline.Position = Vector2.new(x, y)
                    outline.Size = Vector2.new(bar_width + 2 * padding, height + 2 * padding)
                    outline.Transparency = transparency
                    outline.Visible = true
                    
                    -- Gradient color based on health
                    if esplib.healthbar.gradient then
                        fill.Color = lerp_color(esplib.healthbar.low_color, esplib.healthbar.high_color, health)
                    else
                        fill.Color = esplib.healthbar.fill
                    end
                    
                    fill.Position = Vector2.new(x + padding, y + (height + padding) - fillheight)
                    fill.Size = Vector2.new(bar_width, fillheight)
                    fill.Transparency = transparency
                    fill.Visible = true
                else
                    outline.Visible = false
                    fill.Visible = false
                end
            end
        end
        
        if data.name then
            if esplib.name.enabled and onscreen then
                local text = data.name
                local center_x = (min.X + max.X) / 2
                local y = min.Y - 15
                
                local name_str = instance.Name
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local player = players:GetPlayerFromCharacter(instance)
                    if player then
                        name_str = player.Name
                    end
                    
                    -- Add health text if enabled
                    if esplib.name.show_health then
                        local current_health = math.floor(humanoid.Health)
                        local max_health = math.floor(humanoid.MaxHealth)
                        name_str = name_str .. " [" .. current_health .. ":" .. max_health .. "]"
                    end
                end
                
                text.Text = name_str
                text.Size = esplib.name.size
                text.Color = color or esplib.name.fill
                text.Transparency = transparency
                text.Position = Vector2.new(center_x, y)
                text.Visible = true
            else
                data.name.Visible = false
            end
        end
        
        if data.distance then
            if esplib.distance.enabled and onscreen then
                local text = data.distance
                local center_x = (min.X + max.X) / 2
                local y = max.Y + 5
                
                text.Text = tostring(math.floor(distance)) .. "m"
                text.Size = esplib.distance.size
                text.Color = esplib.distance.fill
                text.Transparency = transparency
                text.Position = Vector2.new(center_x, y)
                text.Visible = true
            else
                data.distance.Visible = false
            end
        end
        
        if data.tracer then
            if esplib.tracer.enabled and onscreen then
                local outline, fill = data.tracer.outline, data.tracer.fill
                local from_pos = Vector2.new()
                local to_pos = Vector2.new()
                
                if esplib.tracer.from == "mouse" then
                    local mouse_location = user_input_service:GetMouseLocation()
                    from_pos = Vector2.new(mouse_location.X, mouse_location.Y)
                elseif esplib.tracer.from == "head" then
                    local head = instance:FindFirstChild("Head")
                    if head then
                        local pos, visible = camera:WorldToViewportPoint(head.Position)
                        if visible then
                            from_pos = Vector2.new(pos.X, pos.Y)
                        else
                            from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                        end
                    else
                        from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                    end
                elseif esplib.tracer.from == "bottom" then
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                elseif esplib.tracer.from == "center" then
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                else
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                end
                
                to_pos = (min + max) / 2
                
                outline.From = from_pos
                outline.To = to_pos
                outline.Color = esplib.tracer.outline
                outline.Transparency = transparency
                outline.Visible = true
                
                fill.From = from_pos
                fill.To = to_pos
                fill.Color = color or esplib.tracer.fill
                fill.Transparency = transparency
                fill.Visible = true
            else
                data.tracer.outline.Visible = false
                data.tracer.fill.Visible = false
            end
        end
        
        if data.skeleton then
            if esplib.skeleton.enabled and onscreen and instance:IsA("Model") then
                local skeleton = data.skeleton
                for i, connection in ipairs(skeleton.connections) do
                    local part1 = instance:FindFirstChild(connection[1])
                    local part2 = instance:FindFirstChild(connection[2])
                    
                    if part1 and part2 then
                        local pos1, vis1 = camera:WorldToViewportPoint(part1.Position)
                        local pos2, vis2 = camera:WorldToViewportPoint(part2.Position)
                        
                        if vis1 and vis2 then
                            local line = skeleton.lines[i]
                            line.From = Vector2.new(pos1.X, pos1.Y)
                            line.To = Vector2.new(pos2.X, pos2.Y)
                            line.Color = color or esplib.skeleton.color
                            line.Transparency = transparency
                            line.Visible = true
                        else
                            skeleton.lines[i].Visible = false
                        end
                    else
                        skeleton.lines[i].Visible = false
                    end
                end
            else
                if data.skeleton then
                    for _, line in ipairs(data.skeleton.lines) do
                        line.Visible = false
                    end
                end
            end
        end
        
        if data.chams then
            if esplib.chams.enabled then
                for _, highlight in ipairs(data.chams) do
                    highlight.FillColor = color or esplib.chams.fill_color
                    highlight.FillTransparency = esplib.chams.fill_transparency * (2 - transparency)
                    highlight.OutlineColor = esplib.chams.outline_color
                    highlight.OutlineTransparency = esplib.chams.outline_transparency
                    highlight.Enabled = true
                end
            else
                for _, highlight in ipairs(data.chams) do
                    highlight.Enabled = false
                end
            end
        end
    end
end)

-- // return
for k, v in pairs(espfunctions) do
    esplib[k] = v
end

return esplib
