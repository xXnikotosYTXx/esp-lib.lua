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
            intensity = 0.4, -- glow intensity (0-1) - немного меньше для лучшего вида
            size = 1.5, -- glow size in pixels - меньше для более реалистичного эффекта
            color = Color3.new(0, 0.8, 1), -- cyan glow color - немного темнее
            max_distance = 150, -- glow only up to 150 studs - меньше дистанция для лучшей производительности
        },
        animations = {
            enabled = true, -- smooth animations
            speed = 0.2, -- animation speed
            health_smooth = true, -- smooth health bar changes
            fade_in = true, -- fade in when ESP appears
            rainbow = false, -- rainbow color animation
            rainbow_speed = 0.05, -- rainbow animation speed
            pulse = false, -- pulsing transparency effect
            pulse_speed = 0.1, -- pulse speed
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
esplib.glow = esplib.glow or {enabled = false, intensity = 0.4, size = 1.5, color = Color3.new(0, 0.8, 1), max_distance = 150}
esplib.animations = esplib.animations or {enabled = true, speed = 0.2, health_smooth = true, fade_in = true, rainbow = false, rainbow_speed = 0.05, pulse = false, pulse_speed = 0.1}

local espinstances = {}
local espfunctions = {}
local hover_targets = {} -- store hover animation data
local animation_data = {} -- store animation states
local health_animations = {} -- store health animation data
local glow_animations = {} -- store glow fade animation data
local rainbow_time = 0 -- for rainbow animation
local pulse_time = 0 -- for pulse animation

-- Cleanup function to reset ESP when leaving game
local function cleanup_esp()
    for instance, data in pairs(espinstances) do
        if data.box then
            if data.box.outline then pcall(function() data.box.outline:Remove() end) end
            if data.box.fill then pcall(function() data.box.fill:Remove() end) end
            if data.box.glow_layers then
                for _, glow in ipairs(data.box.glow_layers) do
                    pcall(function() glow:Remove() end)
                end
            end
            for _, line in ipairs(data.box.corner_fill or {}) do
                pcall(function() line:Remove() end)
            end
            for _, line in ipairs(data.box.corner_outline or {}) do
                pcall(function() line:Remove() end)
            end
            for _, corner_glow_layers in ipairs(data.box.corner_glow or {}) do
                for _, glow in ipairs(corner_glow_layers or {}) do
                    pcall(function() glow:Remove() end)
                end
            end
        end
        if data.healthbar then
            if data.healthbar.outline then pcall(function() data.healthbar.outline:Remove() end) end
            if data.healthbar.fill then pcall(function() data.healthbar.fill:Remove() end) end
        end
        if data.name then
            if data.name.text then pcall(function() data.name.text:Remove() end) end
            if data.name.tag_bracket_left then pcall(function() data.name.tag_bracket_left:Remove() end) end
            if data.name.tag_letter then pcall(function() data.name.tag_letter:Remove() end) end
            if data.name.tag_bracket_right then pcall(function() data.name.tag_bracket_right:Remove() end) end
        end
        if data.distance then
            pcall(function() data.distance:Remove() end)
        end
        if data.tracer then
            if data.tracer.outline then pcall(function() data.tracer.outline:Remove() end) end
            if data.tracer.fill then pcall(function() data.tracer.fill:Remove() end) end
        end
    end
    
    -- Clear all tables
    espinstances = {}
    hover_targets = {}
    animation_data = {}
    health_animations = {}
    glow_animations = {}
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
        
        -- Пересчитываем min/max с новыми размерами и центрированием (с math.floor для фикса дрожания и отслоений)
        min = Vector2.new(math.floor(center_x - width/2), math.floor(center_y - height/2))
        max = Vector2.new(math.floor(center_x + width/2), math.floor(center_y + height/2))
    end
    
    return min, max, onscreen
end

function espfunctions.add_box(instance)
    if not instance or espinstances[instance] and espinstances[instance].box then return end
    
    local box = {}
    
    local outline = Drawing.new("Square")
    outline.Filled = false
    outline.Thickness = 3
    outline.Transparency = 1
    outline.Visible = false
    pcall(function() outline.ZIndex = 1 end) -- Фикс Z-Fighting (черный бокс поверх белого)
    
    local fill = Drawing.new("Square")
    fill.Filled = false
    fill.Thickness = 1
    fill.Transparency = 1
    fill.Visible = false
    pcall(function() fill.ZIndex = 2 end)
    
    -- Multiple glow layers for REAL glow effect - IMPROVED
    local glow_layers = {}
    for i = 1, 6 do -- больше слоев для более реалистичного свечения
        local glow = Drawing.new("Square")
        glow.Filled = false
        glow.Transparency = 1
        glow.Visible = false
        glow.Thickness = math.ceil(i * 1.5) -- более плавное увеличение толщины
        pcall(function() glow.ZIndex = 0 end)
        table.insert(glow_layers, glow)
    end
    
    box.outline = outline
    box.fill = fill
    box.glow_layers = glow_layers
    box.corner_fill = {}
    box.corner_outline = {}
    box.corner_glow = {}
    
    for i = 1, 8 do
        local outline = Drawing.new("Line")
        outline.Thickness = 3 -- ИСПРАВЛЕНИЕ: для корнеров рамка тоже 3
        outline.Transparency = 1
        outline.Visible = false
        pcall(function() outline.ZIndex = 1 end)
        
        local fill = Drawing.new("Line")
        fill.Thickness = 1
        fill.Transparency = 1
        fill.Visible = false
        pcall(function() fill.ZIndex = 2 end)
        
        -- Corner glow layers - IMPROVED
        local corner_glow_layers = {}
        for j = 1, 4 do -- больше слоев для углов
            local glow = Drawing.new("Line")
            glow.Thickness = math.ceil(j * 2.5) -- более плавное увеличение толщины
            glow.Transparency = 1
            glow.Visible = false
            pcall(function() glow.ZIndex = 0 end)
            table.insert(corner_glow_layers, glow)
        end
        
        table.insert(box.corner_fill, fill)
        table.insert(box.corner_outline, outline)
        table.insert(box.corner_glow, corner_glow_layers)
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
    for _, glow in ipairs(box.glow_layers) do
        glow.Visible = false
    end
    for _, line in ipairs(box.corner_fill) do
        line.Visible = false
    end
    for _, line in ipairs(box.corner_outline) do
        line.Visible = false
    end
    for _, corner_glow_layers in ipairs(box.corner_glow) do
        for _, glow in ipairs(corner_glow_layers) do
            glow.Visible = false
        end
    end
end

function espfunctions.add_healthbar(instance)
    if not instance or espinstances[instance] and espinstances[instance].healthbar then return end
    
    local outline = Drawing.new("Square")
    outline.Thickness = 1
    outline.Filled = true
    outline.Transparency = 1
    pcall(function() outline.ZIndex = 1 end)
    
    local fill = Drawing.new("Square")
    fill.Filled = true
    fill.Transparency = 1
    pcall(function() fill.ZIndex = 2 end)
    
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
    pcall(function() text.ZIndex = 4 end)
    
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
    pcall(function() text.ZIndex = 4 end)
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].distance = text
end

function espfunctions.cleanup()
    cleanup_esp()
    print("🧹 ESP cleaned up - ready for re-injection")
end

function espfunctions.force_cleanup()
    -- Enhanced cleanup with pcall protection
    pcall(function()
        for instance, data in pairs(espinstances) do
            if data.box then
                if data.box.outline then pcall(function() data.box.outline:Remove() end) end
                if data.box.fill then pcall(function() data.box.fill:Remove() end) end
                if data.box.glow_layers then
                    for _, glow in ipairs(data.box.glow_layers) do
                        pcall(function() glow:Remove() end)
                    end
                end
                for _, line in ipairs(data.box.corner_fill or {}) do
                    pcall(function() line:Remove() end)
                end
                for _, line in ipairs(data.box.corner_outline or {}) do
                    pcall(function() line:Remove() end)
                end
                for _, corner_glow_layers in ipairs(data.box.corner_glow or {}) do
                    for _, glow in ipairs(corner_glow_layers or {}) do
                        pcall(function() glow:Remove() end)
                    end
                end
            end
            if data.healthbar then
                if data.healthbar.outline then pcall(function() data.healthbar.outline:Remove() end) end
                if data.healthbar.fill then pcall(function() data.healthbar.fill:Remove() end) end
            end
            if data.name then
                if data.name.text then pcall(function() data.name.text:Remove() end) end
                if data.name.tag_bracket_left then pcall(function() data.name.tag_bracket_left:Remove() end) end
                if data.name.tag_letter then pcall(function() data.name.tag_letter:Remove() end) end
                if data.name.tag_bracket_right then pcall(function() data.name.tag_bracket_right:Remove() end) end
            end
            if data.distance then
                pcall(function() data.distance:Remove() end)
            end
            if data.tracer then
                if data.tracer.outline then pcall(function() data.tracer.outline:Remove() end) end
                if data.tracer.fill then pcall(function() data.tracer.fill:Remove() end) end
            end
        end
    end)
    
    -- Clear all tables
    espinstances = {}
    hover_targets = {}
    animation_data = {}
    health_animations = {}
    glow_animations = {}
    
    -- Clear global reference
    if getgenv().esplib then
        getgenv().esplib = nil
    end
    
    print("🔄 ESP force cleaned - completely reset for re-injection")
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
    pcall(function() outline.ZIndex = 1 end)
    
    local fill = Drawing.new("Line")
    fill.Thickness = 1
    fill.Transparency = 1
    pcall(function() fill.ZIndex = 2 end)
    
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
    
    local final_transparency = base_transparency * anim.alpha
    
    -- Pulse effect
    if esplib.animations.pulse then
        pulse_time = pulse_time + esplib.animations.pulse_speed
        local pulse_factor = (math.sin(pulse_time) + 1) / 2 -- 0 to 1
        final_transparency = final_transparency * (0.5 + pulse_factor * 0.5) -- pulse between 50% and 100%
    end
    
    return final_transparency
end

-- Rainbow color animation
local function get_rainbow_color()
    if not esplib.animations.rainbow then
        return nil
    end
    
    rainbow_time = rainbow_time + esplib.animations.rainbow_speed
    
    local r = (math.sin(rainbow_time) + 1) / 2
    local g = (math.sin(rainbow_time + 2.094) + 1) / 2 -- 120 degrees offset
    local b = (math.sin(rainbow_time + 4.188) + 1) / 2 -- 240 degrees offset
    
    return Color3.new(r, g, b)
end

-- Glow fade animation helper - SMOOTH FADE IN/OUT
local function update_glow_fade(instance, distance)
    if not esplib.glow.enabled then
        return 0 -- no glow
    end
    
    if not glow_animations[instance] then
        glow_animations[instance] = {
            current_alpha = 0,
            target_alpha = 0,
        }
    end
    
    local glow_anim = glow_animations[instance]
    
    -- IMPROVED: Smoother distance-based fade calculation
    if distance <= esplib.glow.max_distance then
        -- Longer fade zone for smoother transition: 0.6 * max_distance to max_distance
        local fade_start = esplib.glow.max_distance * 0.6 -- начинаем затухание раньше
        if distance <= fade_start then
            glow_anim.target_alpha = 1.0 -- full glow
        else
            -- Smooth exponential fade for more natural look
            local fade_factor = (distance - fade_start) / (esplib.glow.max_distance - fade_start)
            -- Exponential fade instead of linear for smoother effect
            glow_anim.target_alpha = math.pow(1.0 - fade_factor, 2) -- квадратичное затухание
        end
    else
        glow_anim.target_alpha = 0 -- no glow
    end
    
    -- MUCH SMOOTHER animation with slower speed for glow
    if glow_anim.current_alpha ~= glow_anim.target_alpha then
        local diff = glow_anim.target_alpha - glow_anim.current_alpha
        -- Slower animation speed for smoother glow transitions
        glow_anim.current_alpha = glow_anim.current_alpha + (diff * esplib.animations.speed * 0.8) -- медленнее для плавности
        
        -- Smaller snap threshold for smoother transitions
        if math.abs(diff) < 0.005 then -- меньший порог для более плавного перехода
            glow_anim.current_alpha = glow_anim.target_alpha
        end
    end
    
    return math.max(glow_anim.current_alpha, 0)
end
local function update_health_animation(instance, current_health, max_health)
    if not esplib.animations.health_smooth then
        return current_health / max_health
    end
    
    if not health_animations[instance] then
        health_animations[instance] = {
            displayed_health = current_health,
            target_health = current_health,
            last_max_health = max_health,
        }
    end
    
    local health_anim = health_animations[instance]
    
    -- Reset animation if max health changed (respawn detection)
    if health_anim.last_max_health ~= max_health then
        health_anim.displayed_health = current_health
        health_anim.last_max_health = max_health
    end
    
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
        
        -- Apply smooth animations
        transparency = update_animations(instance, transparency)
        
        local esp_color = get_esp_color(instance)
        
        -- Optimization: hide boxes/healthbars/tracers beyond 1000 studs, keep names/tags/distance visible
        local show_boxes = dist <= 1000 -- boxes and healthbars only up to 1000 studs
        local show_distant_elements = dist <= 2000 -- names, tags, distance up to 2000 studs
        
        if data.box then
            local box = data.box
            if esplib.box.enabled and onscreen and show_boxes then
                local x, y = min.X, min.Y
                local w, h = (max.X - min.X), (max.Y - min.Y)
                local len = math.min(w, h) * 0.25
                
                if esplib.box.type == "normal" then
                    -- Hide ALL corner lines first
                    for _, line in ipairs(box.corner_fill) do
                        line.Visible = false
                    end
                    for _, line in ipairs(box.corner_outline) do
                        line.Visible = false
                    end
                    for _, line in ipairs(box.corner_glow or {}) do
                        line.Visible = false
                    end
                    
                    -- Real glow effect with smooth fade - IMPROVED GLOW LAYERS
                    local glow_alpha = update_glow_fade(instance, dist)
                    if glow_alpha > 0 and box.glow_layers then
                        for i, glow in ipairs(box.glow_layers) do
                            local layer_size = i * esplib.glow.size * 1.5 -- больше размер для реального свечения
                            -- IMPROVED: More realistic glow with exponential falloff
                            local layer_transparency = transparency * esplib.glow.intensity * glow_alpha * math.pow(0.6, i - 1) -- экспоненциальное затухание
                            
                            glow.Position = Vector2.new(min.X - layer_size, min.Y - layer_size)
                            glow.Size = Vector2.new((max.X - min.X) + layer_size * 2, (max.Y - min.Y) + layer_size * 2)
                            glow.Color = esplib.glow.color
                            glow.Transparency = math.max(layer_transparency, 0.02) -- минимальная прозрачность для видимости
                            glow.Visible = true
                        end
                    else
                        if box.glow_layers then
                            for _, glow in ipairs(box.glow_layers) do
                                glow.Visible = false
                            end
                        end
                    end
                    
                    -- Get animated color for box
                    local box_color = get_rainbow_color() or esp_color
                    
                    -- Show normal box
                    box.outline.Position = min
                    box.outline.Size = max - min
                    box.outline.Color = esplib.box.outline
                    box.outline.Transparency = transparency
                    box.outline.Visible = true
                    
                    box.fill.Position = min
                    box.fill.Size = max - min
                    box.fill.Color = box_color -- используем анимированный цвет
                    box.fill.Transparency = transparency
                    box.fill.Visible = true
                    
                elseif esplib.box.type == "corner" then
                    -- Hide normal box and glow first
                    box.outline.Visible = false
                    box.fill.Visible = false
                    if box.glow_layers then
                        for _, glow in ipairs(box.glow_layers) do
                            glow.Visible = false
                        end
                    end
                    
                    local fill_lines = box.corner_fill
                    local outline_lines = box.corner_outline
                    local glow_lines = box.corner_glow
                    local fill_color = get_rainbow_color() or esp_color -- анимированный цвет
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
                        
                        -- Corner glow effect with smooth fade - IMPROVED CORNER GLOW
                        local glow_alpha = update_glow_fade(instance, dist)
                        if glow_alpha > 0 and glow_lines[i] then
                            for j, glow in ipairs(glow_lines[i]) do
                                -- IMPROVED: Better corner glow with exponential falloff
                                local glow_transparency = transparency * esplib.glow.intensity * glow_alpha * math.pow(0.5, j - 1) -- экспоненциальное затухание
                                glow.From = from - dir * j * 1.5 -- больше расстояние для реального свечения
                                glow.To = to + dir * j * 1.5
                                glow.Color = esplib.glow.color
                                glow.Transparency = math.max(glow_transparency, 0.02) -- минимальная прозрачность
                                glow.Visible = true
                            end
                        else
                            if glow_lines[i] then
                                for _, glow in ipairs(glow_lines[i]) do
                                    glow.Visible = false
                                end
                            end
                        end
                        
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
                if box.glow_layers then
                    for _, glow in ipairs(box.glow_layers) do
                        glow.Visible = false
                    end
                end
                for _, line in ipairs(box.corner_fill) do
                    line.Visible = false
                end
                for _, line in ipairs(box.corner_outline) do
                    line.Visible = false
                end
                for _, corner_glow_layers in ipairs(box.corner_glow) do
                    for _, glow in ipairs(corner_glow_layers) do
                        glow.Visible = false
                    end
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
                if humanoid then
                    local raw_health = humanoid.Health
                    if type(raw_health) ~= "number" or raw_health ~= raw_health then raw_health = 0 end 
                    local raw_maxhealth = humanoid.MaxHealth
                    if type(raw_maxhealth) ~= "number" or raw_maxhealth ~= raw_maxhealth or raw_maxhealth <= 0 then raw_maxhealth = 100 end 
                    
                    local current_health = math.clamp(raw_health, 0, raw_maxhealth)
                    local anim_health = update_health_animation(instance, current_health, raw_maxhealth) 
                    if type(anim_health) ~= "number" or anim_health ~= anim_health then anim_health = 1 end
                    local health = math.clamp(anim_health, 0, 1)

                    -- Используем ИСПРАВЛЕННЫЕ размеры бокса (min/max уже содержат минимальные размеры)
                    local height = math.floor(max.Y - min.Y)
                    local width = math.floor(max.X - min.X)
                    local padding = 1
                    
                    local x, y, bar_width, bar_height, fillheight, fillwidth
                    
                    if esplib.healthbar.position == "right" then
                        -- Right side healthbar - привязан к исправленному боксу
                        bar_width = 3 -- 1 fill + 2 padding
                        x = math.floor(max.X + padding + 1)
                        y = math.floor(min.Y - padding)
                        bar_height = height + 2 * padding
                        fillheight = math.max(math.floor(height * health), 1)
                        fillwidth = 1
                        
                        outline.Position = Vector2.new(x, y)
                        outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + padding + (height - fillheight))
                        fill.Size = Vector2.new(fillwidth, fillheight)
                        
                    elseif esplib.healthbar.position == "bottom" then
                        -- Bottom healthbar - привязан к исправленному боксу
                        x = math.floor(min.X - padding)
                        y = math.floor(max.Y + padding + 1)
                        bar_width = width + 2 * padding
                        bar_height = 3
                        fillwidth = math.max(math.floor(width * health), 1)
                        fillheight = 1
                        
                        outline.Position = Vector2.new(x, y)
                        outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + padding)
                        fill.Size = Vector2.new(fillwidth, fillheight)
                        
                    else
                        -- Left side healthbar - привязан к исправленному боксу
                        bar_width = 3
                        x = math.floor(min.X - bar_width - padding) -- ближе к боксу
                        y = math.floor(min.Y - padding)
                        bar_height = height + 2 * padding
                        fillheight = math.max(math.floor(height * health), 1)
                        fillwidth = 1
                        
                        outline.Position = Vector2.new(x, y)
                        outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + padding + (height - fillheight))
                        fill.Size = Vector2.new(fillwidth, fillheight)
                    end
                    
                    outline.Color = esplib.healthbar.outline
                    outline.Transparency = 1
                    outline.Visible = true
                    
                    if esplib.healthbar.gradient and health >= 0 then -- показывать даже при 0 HP
                        local low = esplib.healthbar.low_color
                        local high = esplib.healthbar.high_color
                        fill.Color = Color3.new(
                            low.R + (high.R - low.R) * health
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
                local center_x = math.floor((min.X + max.X) / 2)
                local y = math.floor(min.Y - 15)
                
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
                local center_x = math.floor((min.X + max.X) / 2)
                local y = math.floor(max.Y + 5)
                
                if esplib.healthbar.enabled and esplib.healthbar.position == "bottom" then 
                    y = y + 4 
                end
                
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
                
                to_pos = Vector2.new(math.floor((min.X + max.X) / 2), math.floor((min.Y + max.Y) / 2))
                
                -- If box is enabled, attach tracer to bottom center of box
                if esplib.box.enabled then
                    to_pos = Vector2.new(math.floor((min.X + max.X) / 2), math.floor(max.Y))
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
