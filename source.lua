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
            position = "left", -- left, right, bottom
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
            hover_enabled = true, -- hover fade effect
            hover_radius = 200, -- bigger radius around cursor
            hover_transparency = 1.0, -- full brightness on hover
            hover_boost = 2.0, -- extra brightness multiplier (removed, using 1.0 directly)
            animation_speed = 0.25, -- faster animation
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
        glow = {
            enabled = false, -- glow effect
            intensity = 0.3, -- glow intensity (0-1)
            size = 2, -- glow size in pixels
        },
        animations = {
            enabled = true, -- smooth animations
            speed = 0.15, -- animation speed
            health_smooth = true, -- smooth health bar changes
            fade_in = true, -- fade in when ESP appears
        },
    }
    getgenv().esplib = esplib
end

-- Add new fields if they don't exist
esplib.healthbar.gradient = esplib.healthbar.gradient == nil and true or esplib.healthbar.gradient
esplib.healthbar.low_color = esplib.healthbar.low_color or Color3.new(1,0,0)
esplib.healthbar.high_color = esplib.healthbar.high_color or Color3.new(0,1,0)
esplib.healthbar.position = esplib.healthbar.position or "left"
esplib.name.show_health = esplib.name.show_health == nil and false or esplib.name.show_health
esplib.fade = esplib.fade or {enabled = false, max_distance = 500, min_transparency = 0.3, hover_enabled = true, hover_radius = 200, hover_transparency = 1.0, hover_boost = 2.0, animation_speed = 0.25}
esplib.visibility = esplib.visibility or {enabled = false, visible_color = Color3.new(0, 1, 0), hidden_color = Color3.new(1, 0, 0)}
esplib.whitelist = esplib.whitelist or {enabled = false, players = {}}
esplib.friends = esplib.friends or {enabled = false, friend_color = Color3.new(0, 1, 0), enemy_color = Color3.new(1, 0, 0), show_tags = false, friends_list = {}}
esplib.glow = esplib.glow or {enabled = false, intensity = 0.3, size = 2}
esplib.animations = esplib.animations or {enabled = true, speed = 0.15, health_smooth = true, fade_in = true}

local espinstances = {}
local espfunctions = {}
local hover_targets = {} -- store hover animation data
local animation_data = {} -- store animation states
local health_animations = {} -- store health animation data

-- Cleanup function to reset ESP when leaving game
local function cleanup_esp()
    for instance, data in pairs(espinstances) do
        if data.box then
            if data.box.outline then data.box.outline:Remove() end
            if data.box.fill then data.box.fill:Remove() end
            for _, line in ipairs(data.box.corner_fill or {}) do
                if line then line:Remove() end
            end
            for _, line in ipairs(data.box.corner_outline or {}) do
                if line then line:Remove() end
            end
        end
        if data.healthbar then
            if data.healthbar.outline then data.healthbar.outline:Remove() end
            if data.healthbar.fill then data.healthbar.fill:Remove() end
        end
        if data.name then
            if data.name.text then data.name.text:Remove() end
            if data.name.tag_bracket_left then data.name.tag_bracket_left:Remove() end
            if data.name.tag_letter then data.name.tag_letter:Remove() end
            if data.name.tag_bracket_right then data.name.tag_bracket_right:Remove() end
        end
        if data.distance then
            data.distance:Remove()
        end
        if data.tracer then
            if data.tracer.outline then data.tracer.outline:Remove() end
            if data.tracer.fill then data.tracer.fill:Remove() end
        end
    end
    
    -- Clear all tables
    espinstances = {}
    hover_targets = {}
end

-- Connect cleanup to game leaving
game.Players.PlayerRemoving:Connect(function(player)
    if player == game.Players.LocalPlayer then
        cleanup_esp()
    end
end)

-- Also cleanup when workspace changes (teleporting between places)
workspace.ChildRemoved:Connect(function(child)
    if child.Name == "Live" or child.Name == "Players" then
        cleanup_esp()
    end
end)

-- // services
local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local tween_service = game:GetService("TweenService")

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

local function calculate_fade_transparency(distance, instance, name_pos)
    local base_transparency = 1
    
    -- Distance fade
    if esplib.fade.enabled then
        if distance > esplib.fade.max_distance then
            local fade_factor = math.clamp((distance - esplib.fade.max_distance) / esplib.fade.max_distance, 0, 1)
            base_transparency = math.max(esplib.fade.min_transparency, 1 - fade_factor)
        end
    end
    
    -- Hover fade effect - SUPER DRAMATIC LIGHT UP
    if esplib.fade.hover_enabled and name_pos then
        local mouse_pos = user_input_service:GetMouseLocation()
        local distance_to_mouse = (Vector2.new(mouse_pos.X, mouse_pos.Y) - name_pos).Magnitude
        
        if distance_to_mouse <= esplib.fade.hover_radius then
            -- Initialize hover data if not exists
            if not hover_targets[instance] then
                hover_targets[instance] = {
                    current_transparency = base_transparency,
                    target_transparency = 1.0, -- full brightness
                }
            end
            -- MAXIMUM brightness for super bright effect - OVERRIDE base transparency
            hover_targets[instance].target_transparency = 1.0
        else
            if hover_targets[instance] then
                hover_targets[instance].target_transparency = base_transparency
            end
        end
        
        -- Animate transparency with faster speed
        if hover_targets[instance] then
            local current = hover_targets[instance].current_transparency
            local target = hover_targets[instance].target_transparency
            local new_transparency = current + (target - current) * esplib.fade.animation_speed
            hover_targets[instance].current_transparency = new_transparency
            
            -- FORCE full brightness when hovering - no matter what base transparency is
            if distance_to_mouse <= esplib.fade.hover_radius then
                return 1.0 -- ALWAYS full brightness when hovering
            else
                return new_transparency
            end
        end
    end
    
    return base_transparency
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
    
    -- ИСПРАВЛЕНИЕ: Минимальный размер бокса и правильные пропорции
    if onscreen then
        local width = max.X - min.X
        local height = max.Y - min.Y
        local center_x = (min.X + max.X) / 2
        local center_y = (min.Y + max.Y) / 2
        
        -- Минимальные размеры для дальних дистанций
        local min_width = 18  -- уменьшил на 2 пикселя
        local min_height = 28 -- уменьшил на 2 пикселя
        
        -- Применяем минимальные размеры
        width = math.max(width, min_width)
        height = math.max(height, min_height)
        
        -- Пересчитываем min/max с новыми размерами и центрированием
        min = Vector2.new(center_x - width/2, center_y - height/2)
        max = Vector2.new(center_x + width/2, center_y + height/2)
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
    
    -- Glow objects
    local glow_outline = Drawing.new("Square")
    glow_outline.Filled = false
    glow_outline.Transparency = 1
    glow_outline.Visible = false
    glow_outline.Thickness = 3
    
    box.outline = outline
    box.fill = fill
    box.glow_outline = glow_outline
    box.corner_fill = {}
    box.corner_outline = {}
    box.corner_glow = {}
    
    for i = 1, 8 do
        local outline = Drawing.new("Line")
        outline.Thickness = 2
        outline.Transparency = 1
        outline.Visible = false
        
        local fill = Drawing.new("Line")
        fill.Thickness = 1
        fill.Transparency = 1
        fill.Visible = false
        
        local glow = Drawing.new("Line")
        glow.Thickness = 4
        glow.Transparency = 1
        glow.Visible = false
        
        table.insert(box.corner_fill, fill)
        table.insert(box.corner_outline, outline)
        table.insert(box.corner_glow, glow)
    end
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].box = box
    
    -- Initialize animation data
    if esplib.animations.enabled then
        animation_data[instance] = {
            alpha = esplib.animations.fade_in and 0 or 1,
            target_alpha = 1,
        }
    end
    
    -- Force hide everything initially
    box.outline.Visible = false
    box.fill.Visible = false
    box.glow_outline.Visible = false
    for _, line in ipairs(box.corner_fill) do
        line.Visible = false
    end
    for _, line in ipairs(box.corner_outline) do
        line.Visible = false
    end
    for _, line in ipairs(box.corner_glow) do
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

function espfunctions.cleanup()
    cleanup_esp()
    print("🧹 ESP cleaned up - ready for re-injection")
end

function espfunctions.reset()
    cleanup_esp()
    -- Reset hover targets
    hover_targets = {}
    print("🔄 ESP completely reset")
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

-- Animation helper function
local function update_animations(instance, base_transparency)
    if not esplib.animations.enabled then
        return base_transparency
    end
    
    if not animation_data[instance] then
        animation_data[instance] = {
            alpha = esplib.animations.fade_in and 0 or 1,
            target_alpha = 1,
        }
    end
    
    local anim = animation_data[instance]
    
    -- Smooth fade in/out
    if anim.alpha ~= anim.target_alpha then
        local diff = anim.target_alpha - anim.alpha
        anim.alpha = anim.alpha + (diff * esplib.animations.speed)
        
        -- Snap to target if close enough
        if math.abs(diff) < 0.01 then
            anim.alpha = anim.target_alpha
        end
    end
    
    return base_transparency * anim.alpha
end

-- Health animation helper
local function update_health_animation(instance, current_health, max_health)
    if not esplib.animations.health_smooth then
        return current_health / max_health
    end
    
    if not health_animations[instance] then
        health_animations[instance] = {
            displayed_health = current_health,
            target_health = current_health,
        }
    end
    
    local health_anim = health_animations[instance]
    health_anim.target_health = current_health
    
    -- Smooth health changes
    if health_anim.displayed_health ~= health_anim.target_health then
        local diff = health_anim.target_health - health_anim.displayed_health
        health_anim.displayed_health = health_anim.displayed_health + (diff * esplib.animations.speed * 2) -- faster for health
        
        -- Snap if close
        if math.abs(diff) < 0.5 then
            health_anim.displayed_health = health_anim.target_health
        end
    end
    
    return math.clamp(health_anim.displayed_health / max_health, 0, 1)
end

-- // main thread
run_service.RenderStepped:Connect(function()
    -- Safety check - if we're not in a valid game state, cleanup and return
    if not game.Players.LocalPlayer or not workspace.CurrentCamera then
        cleanup_esp()
        return
    end
    
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
        local name_pos = nil
        
        -- Calculate name position for hover detection
        if onscreen then
            local center_x = (min.X + max.X) / 2
            local y = min.Y - 15
            name_pos = Vector2.new(center_x, y)
        end
        
        -- Use hover fade function for better transparency calculation
        transparency = calculate_fade_transparency(dist, instance, name_pos)
        
        local esp_color = get_esp_color(instance)
        
        -- Optimization: hide boxes/healthbars/tracers beyond 1000 studs, keep names/tags/distance visible
        local show_boxes = dist <= 1000 -- boxes and healthbars only up to 1000 studs
        local show_distant_elements = dist <= 2000 -- names, tags, distance up to 2000 studs
        
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
                if humanoid and humanoid.MaxHealth > 0 then
                    -- Используем ИСПРАВЛЕННЫЕ размеры бокса (min/max уже содержат минимальные размеры)
                    local height = max.Y - min.Y
                    local width = max.X - min.X
                    local padding = 1
                    local current_health = math.max(humanoid.Health, 0) -- защита от отрицательных значений
                    local health = math.clamp(current_health / humanoid.MaxHealth, 0, 1)
                    
                    local x, y, bar_width, bar_height, fillheight, fillwidth
                    
                    if esplib.healthbar.position == "right" then
                        -- Right side healthbar - привязан к исправленному боксу
                        x = max.X + 2 + padding -- ближе к боксу
                        y = min.Y - padding
                        bar_width = 1 + 2 * padding
                        bar_height = height + 2 * padding
                        fillheight = math.max(height * health, 1)
                        fillwidth = 1
                        
                        outline.Position = Vector2.new(x, y)
                        outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + (height + padding) - fillheight)
                        fill.Size = Vector2.new(fillwidth, fillheight)
                        
                    elseif esplib.healthbar.position == "bottom" then
                        -- Bottom healthbar - привязан к исправленному боксу
                        x = min.X - padding
                        y = max.Y + 2 + padding -- ближе к боксу
                        bar_width = width + 2 * padding
                        bar_height = 1 + 2 * padding
                        fillwidth = math.max(width * health, 1)
                        fillheight = 1
                        
                        outline.Position = Vector2.new(x, y)
                        outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + padding)
                        fill.Size = Vector2.new(fillwidth, fillheight)
                        
                    else
                        -- Left side healthbar - привязан к исправленному боксу
                        x = min.X - 2 - 1 - padding -- ближе к боксу
                        y = min.Y - padding
                        bar_width = 1 + 2 * padding
                        bar_height = height + 2 * padding
                        fillheight = math.max(height * health, 1)
                        fillwidth = 1
                        
                        outline.Position = Vector2.new(x, y)
                        outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + (height + padding) - fillheight)
                        fill.Size = Vector2.new(fillwidth, fillheight)
                    end
                    
                    outline.Color = esplib.healthbar.outline
                    outline.Transparency = 1
                    outline.Visible = true
                    
                    if esplib.healthbar.gradient and health >= 0 then -- показывать даже при 0 HP
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
                local tag_str = ""
                local health_str = ""
                
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local player = players:GetPlayerFromCharacter(instance)
                    if player then
                        name_str = player.Name
                        
                        -- Check for friend/enemy tags
                        if esplib.friends.enabled and esplib.friends.show_tags then
                            if is_friend(instance) then
                                tag_str = " [F]" -- friend tag
                            else
                                tag_str = " [E]" -- enemy tag
                            end
                        end
                    end
                    
                    if esplib.name.show_health and humanoid.MaxHealth > 0 then
                        local current_health = math.floor(humanoid.Health)
                        local max_health = math.floor(humanoid.MaxHealth)
                        health_str = " [" .. current_health .. ":" .. max_health .. "]"
                    end
                end
                
                -- Combine: "PlayerName [100:100] [E]" - тег ПОСЛЕ хила
                local full_text = name_str .. health_str .. tag_str
                
                -- Hide all separate tag objects
                name_obj.tag_bracket_left.Visible = false
                name_obj.tag_letter.Visible = false
                name_obj.tag_bracket_right.Visible = false
                
                -- Show combined text (all white)
                name_obj.text.Text = full_text
                name_obj.text.Size = esplib.name.size
                name_obj.text.Color = esplib.name.fill
                name_obj.text.Transparency = transparency
                name_obj.text.Visible = true
                
                -- Name stays centered
                name_obj.text.Position = Vector2.new(center_x, y)
                
                -- Show name (always white) - текст уже установлен выше
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
            if esplib.tracer.enabled and onscreen and show_distant_elements then
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
