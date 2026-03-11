--[[
esp-lib.lua
A library for creating esp visuals in roblox using drawing.
Provides functions to add boxes, health bars, names and distances to instances.
Written by tul (@.lutyeh).
]]--

-- // table
local esplib = getgenv().esplib
if not esplib then
    esplib = {
        box = {
            enabled = true,
            type = "normal", -- normal, corner
            padding = 1.15,
            fill = Color3.new(1,1,1),
            outline = Color3.new(0,0,0),
        },
        healthbar = {
            enabled = true,
            fill = Color3.new(0,1,0),
            outline = Color3.new(0,0,0),
            gradient = true,
            low_color = Color3.new(1,0,0),
            high_color = Color3.new(0,1,0),
        },
        name = {
            enabled = true,
            fill = Color3.new(1,1,1),
            size = 13,
            show_health = false,
        },
        distance = {
            enabled = true,
            fill = Color3.new(1,1,1),
            size = 13,
        },
        tracer = {
            enabled = true,
            fill = Color3.new(1,1,1),
            outline = Color3.new(0,0,0),
            from = "mouse", -- mouse, head, top, bottom, center
        },
        fade = {
            enabled = false,
            max_distance = 500,
            min_transparency = 0.3,
        },
        visibility = {
            enabled = false,
            visible_color = Color3.new(0, 1, 0), -- green when visible
            hidden_color = Color3.new(1, 0, 0), -- red when behind wall
        },
        whitelist = {
            enabled = false,
            players = {}, -- {"PlayerName1", "PlayerName2"}
        },
        friends = {
            enabled = false,
            friend_color = Color3.new(0, 1, 0), -- green for friends
            enemy_color = Color3.new(1, 0, 0), -- red for enemies
            show_tags = false, -- show [F]/[E] tags
            friends_list = {}, -- {"FriendName1", "FriendName2"}
        },
    }
    getgenv().esplib = esplib
end

-- Add new fields if they don't exist
esplib.healthbar.gradient = esplib.healthbar.gradient == nil and true or esplib.healthbar.gradient
esplib.healthbar.low_color = esplib.healthbar.low_color or Color3.new(1,0,0)
esplib.healthbar.high_color = esplib.healthbar.high_color or Color3.new(0,1,0)
esplib.name.show_health = esplib.name.show_health == nil and false or esplib.name.show_health
esplib.fade = esplib.fade or {enabled = false, max_distance = 500, min_transparency = 0.3}
esplib.visibility = esplib.visibility or {enabled = false, visible_color = Color3.new(0, 1, 0), hidden_color = Color3.new(1, 0, 0)}
esplib.whitelist = esplib.whitelist or {enabled = false, players = {}}
esplib.friends = esplib.friends or {enabled = false, friend_color = Color3.new(0, 1, 0), enemy_color = Color3.new(1, 0, 0), show_tags = false, friends_list = {}}

local espinstances = {}
local espfunctions = {}

-- // services
local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera

-- // helper functions
local function is_whitelisted(instance)
    if not esplib.whitelist.enabled then return false end
    
    local player = players:GetPlayerFromCharacter(instance)
    if player then
        for _, name in ipairs(esplib.whitelist.players) do
            if player.Name == name then
                return true
            end
        end
    end
    return false
end

local function is_friend(instance)
    if not esplib.friends.enabled then return false end
    
    local player = players:GetPlayerFromCharacter(instance)
    if player then
        for _, name in ipairs(esplib.friends.friends_list) do
            if player.Name == name then
                return true
            end
        end
    end
    return false
end

local function is_visible(instance)
    if not esplib.visibility.enabled then return true end
    
    local target_part = nil
    if instance:IsA("Model") then
        target_part = instance:FindFirstChild("Head") or instance:FindFirstChild("HumanoidRootPart")
    else
        target_part = instance
    end
    
    if not target_part then return true end
    
    local ray = workspace:Raycast(camera.CFrame.Position, (target_part.Position - camera.CFrame.Position).Unit * 1000)
    if ray then
        return ray.Instance:IsDescendantOf(instance)
    end
    return true
end

local function get_esp_color(instance)
    local base_color = Color3.new(1, 1, 1) -- default white
    
    -- Only visibility check changes ESP color
    if esplib.visibility.enabled then
        if is_visible(instance) then
            base_color = esplib.visibility.visible_color
        else
            base_color = esplib.visibility.hidden_color
        end
    end
    
    return base_color
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
    outline.Filled = false
    outline.Transparency = 1
    outline.Visible = false
    
    local fill = Drawing.new("Square")
    fill.Filled = false
    fill.Transparency = 1
    fill.Visible = false
    
    box.outline = outline
    box.fill = fill
    box.corner_fill = {}
    box.corner_outline = {}
    
    for i = 1, 8 do
        local outline = Drawing.new("Line")
        outline.Thickness = 2
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
    
    -- Force hide everything initially
    box.outline.Visible = false
    box.fill.Visible = false
    for _, line in ipairs(box.corner_fill) do
        line.Visible = false
    end
    for _, line in ipairs(box.corner_outline) do
        line.Visible = false
    end
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
    
    local tag_bracket_left = Drawing.new("Text")
    tag_bracket_left.Center = false
    tag_bracket_left.Outline = true
    tag_bracket_left.Font = 1
    tag_bracket_left.Transparency = 1
    tag_bracket_left.Visible = false
    
    local tag_letter = Drawing.new("Text")
    tag_letter.Center = false
    tag_letter.Outline = true
    tag_letter.Font = 1
    tag_letter.Transparency = 1
    tag_letter.Visible = false
    
    local tag_bracket_right = Drawing.new("Text")
    tag_bracket_right.Center = false
    tag_bracket_right.Outline = true
    tag_bracket_right.Font = 1
    tag_bracket_right.Transparency = 1
    tag_bracket_right.Visible = false
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].name = {
        text = text,
        tag_bracket_left = tag_bracket_left,
        tag_letter = tag_letter,
        tag_bracket_right = tag_bracket_right,
    }
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
    outline.Thickness = 2
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
                if data.name.text then
                    data.name.text:Remove()
                end
                if data.name.tag_bracket_left then
                    data.name.tag_bracket_left:Remove()
                end
                if data.name.tag_letter then
                    data.name.tag_letter:Remove()
                end
                if data.name.tag_bracket_right then
                    data.name.tag_bracket_right:Remove()
                end
            end
            if data.distance then
                data.distance:Remove()
            end
            if data.tracer then
                data.tracer.outline:Remove()
                data.tracer.fill:Remove()
            end
            espinstances[instance] = nil
            continue
        end
        
        -- Skip whitelisted players
        if is_whitelisted(instance) then
            if data.box then
                data.box.outline.Visible = false
                data.box.fill.Visible = false
                for _, line in ipairs(data.box.corner_fill) do
                    line.Visible = false
                end
                for _, line in ipairs(data.box.corner_outline) do
                    line.Visible = false
                end
            end
            if data.healthbar then
                data.healthbar.outline.Visible = false
                data.healthbar.fill.Visible = false
            end
            if data.name then
                if data.name.text then
                    data.name.text.Visible = false
                end
                if data.name.tag_bracket_left then
                    data.name.tag_bracket_left.Visible = false
                end
                if data.name.tag_letter then
                    data.name.tag_letter.Visible = false
                end
                if data.name.tag_bracket_right then
                    data.name.tag_bracket_right.Visible = false
                end
            end
            if data.distance then
                data.distance.Visible = false
            end
            if data.tracer then
                data.tracer.outline.Visible = false
                data.tracer.fill.Visible = false
            end
            continue
        end
        
        if instance:IsA("Model") and not instance.PrimaryPart then
            continue
        end
        
        local min, max, onscreen = get_bounding_box(instance)
        
        local dist
        if instance:IsA("Model") then
            if instance.PrimaryPart then
                dist = (camera.CFrame.Position - instance.PrimaryPart.Position).Magnitude
            else
                local part = instance:FindFirstChildWhichIsA("BasePart")
                if part then
                    dist = (camera.CFrame.Position - part.Position).Magnitude
                else
                    dist = 999
                end
            end
        else
            dist = (camera.CFrame.Position - instance.Position).Magnitude
        end
        
        local transparency = 1
        if esplib.fade.enabled then
            if dist > esplib.fade.max_distance then
                local fade_factor = math.clamp((dist - esplib.fade.max_distance) / esplib.fade.max_distance, 0, 1)
                transparency = math.max(esplib.fade.min_transparency, 1 - fade_factor)
            end
        end
        
        local esp_color = get_esp_color(instance)
        
        -- Optimization: hide boxes at very long distances
        local show_boxes = dist <= 1000 -- hide boxes beyond 1000 studs
        
        if data.box then
            local box = data.box
            if esplib.box.enabled and onscreen and show_boxes then
                local x, y = min.X, min.Y
                local w, h = (max - min).X, (max - min).Y
                local len = math.min(w, h) * 0.25
                
                if esplib.box.type == "normal" then
                    -- Hide ALL corner lines first
                    for _, line in ipairs(box.corner_fill) do
                        line.Visible = false
                    end
                    for _, line in ipairs(box.corner_outline) do
                        line.Visible = false
                    end
                    
                    -- Show normal box
                    box.outline.Position = min
                    box.outline.Size = max - min
                    box.outline.Color = esplib.box.outline
                    box.outline.Transparency = transparency
                    box.outline.Visible = true
                    
                    box.fill.Position = min
                    box.fill.Size = max - min
                    box.fill.Color = esp_color
                    box.fill.Transparency = transparency
                    box.fill.Visible = true
                    
                elseif esplib.box.type == "corner" then
                    -- Hide normal box first
                    box.outline.Visible = false
                    box.fill.Visible = false
                    
                    local fill_lines = box.corner_fill
                    local outline_lines = box.corner_outline
                    local fill_color = esp_color
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
                -- Hide EVERYTHING when box is disabled
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
            if not esplib.healthbar.enabled or not onscreen or not show_boxes then
                outline.Visible = false
                fill.Visible = false
            else
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 and humanoid.MaxHealth > 0 then
                    local height = max.Y - min.Y
                    local padding = 1
                    local x = min.X - 3 - 1 - padding
                    local y = min.Y - padding
                    local health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    local fillheight = math.max(height * health, 1) -- minimum 1 pixel height
                    
                    outline.Color = esplib.healthbar.outline
                    outline.Position = Vector2.new(x, y)
                    outline.Size = Vector2.new(1 + 2 * padding, height + 2 * padding)
                    outline.Transparency = 1
                    outline.Visible = true
                    
                    if esplib.healthbar.gradient and health > 0 then
                        local low = esplib.healthbar.low_color
                        local high = esplib.healthbar.high_color
                        fill.Color = Color3.new(
                            low.R + (high.R - low.R) * health,
                            low.G + (high.G - low.G) * health,
                            low.B + (high.B - low.B) * health
                        )
                    else
                        fill.Color = esplib.healthbar.fill
                    end
                    
                    fill.Position = Vector2.new(x + padding, y + (height + padding) - fillheight)
                    fill.Size = Vector2.new(1, fillheight)
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
                local name_obj = data.name
                local center_x = (min.X + max.X) / 2
                local y = min.Y - 15
                
                local name_str = instance.Name
                local show_tag = false
                local tag_color = Color3.new(1, 1, 1)
                local tag_letter = ""
                
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local player = players:GetPlayerFromCharacter(instance)
                    if player then
                        name_str = player.Name
                        
                        -- Check for friend/enemy tags
                        if esplib.friends.enabled and esplib.friends.show_tags then
                            if is_friend(instance) then
                                show_tag = true
                                tag_letter = "F"
                                tag_color = esplib.friends.friend_color -- green F
                            else
                                show_tag = true
                                tag_letter = "E"
                                tag_color = esplib.friends.enemy_color -- red E
                            end
                        end
                    end
                    
                    if esplib.name.show_health and humanoid.MaxHealth > 0 then
                        local current_health = math.floor(humanoid.Health)
                        local max_health = math.floor(humanoid.MaxHealth)
                        name_str = name_str .. " [" .. current_health .. ":" .. max_health .. "]"
                    end
                end
                
                -- Show tag parts if needed
                if show_tag then
                    -- Calculate name width to position tag relative to name
                    local name_width = #name_str * 7 -- approximate character width
                    local tag_x = center_x - (name_width / 2) - 35 -- position tag to the left of name start
                    
                    -- White left bracket [
                    name_obj.tag_bracket_left.Text = "["
                    name_obj.tag_bracket_left.Size = esplib.name.size
                    name_obj.tag_bracket_left.Color = Color3.new(1, 1, 1) -- white
                    name_obj.tag_bracket_left.Transparency = transparency
                    name_obj.tag_bracket_left.Position = Vector2.new(tag_x, y)
                    name_obj.tag_bracket_left.Visible = true
                    
                    -- Colored letter E/F
                    name_obj.tag_letter.Text = tag_letter
                    name_obj.tag_letter.Size = esplib.name.size
                    name_obj.tag_letter.Color = tag_color -- red E or green F
                    name_obj.tag_letter.Transparency = transparency
                    name_obj.tag_letter.Position = Vector2.new(tag_x + 8, y)
                    name_obj.tag_letter.Visible = true
                    
                    -- White right bracket ]
                    name_obj.tag_bracket_right.Text = "]"
                    name_obj.tag_bracket_right.Size = esplib.name.size
                    name_obj.tag_bracket_right.Color = Color3.new(1, 1, 1) -- white
                    name_obj.tag_bracket_right.Transparency = transparency
                    name_obj.tag_bracket_right.Position = Vector2.new(tag_x + 16, y)
                    name_obj.tag_bracket_right.Visible = true
                else
                    name_obj.tag_bracket_left.Visible = false
                    name_obj.tag_letter.Visible = false
                    name_obj.tag_bracket_right.Visible = false
                end
                
                -- Name stays centered
                name_obj.text.Position = Vector2.new(center_x, y)
                
                -- Show name (always white)
                name_obj.text.Text = name_str
                name_obj.text.Size = esplib.name.size
                name_obj.text.Color = esplib.name.fill
                name_obj.text.Transparency = transparency
                name_obj.text.Visible = true
            else
                if data.name.text then
                    data.name.text.Visible = false
                end
                if data.name.tag_bracket_left then
                    data.name.tag_bracket_left.Visible = false
                end
                if data.name.tag_letter then
                    data.name.tag_letter.Visible = false
                end
                if data.name.tag_bracket_right then
                    data.name.tag_bracket_right.Visible = false
                end
            end
        end
        
        if data.distance then
            if esplib.distance.enabled and onscreen then
                local text = data.distance
                local center_x = (min.X + max.X) / 2
                local y = max.Y + 5
                
                text.Text = tostring(math.floor(dist)) .. "m"
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
            if esplib.tracer.enabled and onscreen and show_boxes then
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
                
                -- If box is enabled, attach tracer to bottom center of box
                if esplib.box.enabled then
                    to_pos = Vector2.new((min.X + max.X) / 2, max.Y)
                end
                
                outline.From = from_pos
                outline.To = to_pos
                outline.Color = esplib.tracer.outline
                outline.Transparency = 0 -- hide outline completely
                outline.Visible = false
                
                fill.From = from_pos
                fill.To = to_pos
                fill.Color = esp_color
                fill.Transparency = transparency
                fill.Visible = true
            else
                data.tracer.outline.Visible = false
                data.tracer.fill.Visible = false
            end
        end
    end
end)

-- // return
for k, v in pairs(espfunctions) do
    esplib[k] = v
end

return esplib
