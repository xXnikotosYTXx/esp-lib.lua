--[[
entity-esp-lib.lua
Универсальная библиотека ESP для объектов, NPC и лута в Roblox.
Основана на esp-lib.lua, оптимизирована под non-player сущности.
]]--

local entityesp = getgenv().entityesp
if not entityesp then
    entityesp = {}
    getgenv().entityesp = entityesp
end

-- Дефолтная структура конфигурации (для заполнения отсутствующих полей)
local defaults = {
    box = {
        enabled = true,
        type = "normal", -- normal, corner
        padding = 1.15,
        fill = Color3.new(1,1,1),
        outline = Color3.new(0,0,0),
    },
    healthbar = {
        enabled = true, -- будет работать, если у NPC есть Humanoid
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
        from = "bottom", -- mouse, head, top, bottom, center
    },
    fade = {
        enabled = false,
        max_distance = 500,
        min_transparency = 0.3,
        hover_enabled = true,
        hover_radius = 200,
        hover_transparency = 1.0,
        animation_speed = 0.25,
    },
    visibility = {
        enabled = false,
        visible_color = Color3.new(0, 1, 0),
        hidden_color = Color3.new(1, 0, 0),
    },
    glow = {
        enabled = false,
        intensity = 0.4,
        size = 1.5,
        color = Color3.new(0, 0.8, 1),
        max_distance = 150,
    },
    animations = {
        enabled = true,
        speed = 0.2,
        health_smooth = true,
        fade_in = true,
        rainbow = false,
        rainbow_speed = 0.05,
        pulse = false,
        pulse_speed = 0.1,
    },
}

-- Безопасное заполнение структуры без перезаписи уже настроенных параметров
for category, settings in pairs(defaults) do
    if not entityesp[category] then
        entityesp[category] = settings
    else
        for setting, value in pairs(settings) do
            if entityesp[category][setting] == nil then
                entityesp[category][setting] = value
            end
        end
    end
end

local espinstances = {}
local espfunctions = {}
local hover_targets = {}
local animation_data = {}
local health_animations = {}
local glow_animations = {}
local rainbow_time = 0
local pulse_time = 0

local run_service = game:GetService("RunService")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera

-- // helper functions
local function is_visible(instance)
    if not entityesp.visibility.enabled then return true end
    
    local target_part = instance:IsA("Model") and (instance:FindFirstChild("PrimaryPart") or instance:FindFirstChild("Head") or instance:FindFirstChildWhichIsA("BasePart")) or instance
    if not target_part or not target_part:IsA("BasePart") then return true end
    
    local ray = workspace:Raycast(camera.CFrame.Position, (target_part.Position - camera.CFrame.Position).Unit * 1000)
    if ray then
        return ray.Instance:IsDescendantOf(instance)
    end
    return true
end

local function get_esp_color(instance, custom_color)
    if entityesp.visibility.enabled then
        return is_visible(instance) and entityesp.visibility.visible_color or entityesp.visibility.hidden_color
    end
    return custom_color or Color3.new(1, 1, 1)
end

local function calculate_fade_transparency(distance, instance, name_pos)
    local base_transparency = 1
    
    if entityesp.fade.enabled and distance > entityesp.fade.max_distance then
        local fade_factor = math.clamp((distance - entityesp.fade.max_distance) / entityesp.fade.max_distance, 0, 1)
        base_transparency = math.max(entityesp.fade.min_transparency, 1 - fade_factor)
    end
    
    if entityesp.fade.hover_enabled and name_pos then
        local mouse_pos = user_input_service:GetMouseLocation()
        local distance_to_mouse = (Vector2.new(mouse_pos.X, mouse_pos.Y) - name_pos).Magnitude
        
        if not hover_targets[instance] then
            hover_targets[instance] = { current_transparency = base_transparency, target_transparency = base_transparency }
        end
        
        hover_targets[instance].target_transparency = distance_to_mouse <= entityesp.fade.hover_radius and 1.0 or base_transparency
        
        local current = hover_targets[instance].current_transparency
        local target = hover_targets[instance].target_transparency
        hover_targets[instance].current_transparency = current + (target - current) * entityesp.fade.animation_speed
        
        return distance_to_mouse <= entityesp.fade.hover_radius and 1.0 or hover_targets[instance].current_transparency
    end
    
    return base_transparency
end

local function get_bounding_box(instance)
    local min, max = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
    local onscreen = false
    
    local parts = {}
    if instance:IsA("Model") then
        for _, p in ipairs(instance:GetDescendants()) do
            if p:IsA("BasePart") then table.insert(parts, p) end
        end
    elseif instance:IsA("BasePart") then
        table.insert(parts, instance)
    end
    
    for _, p in ipairs(parts) do
        local size = (p.Size / 2) * entityesp.box.padding
        local cf = p.CFrame
        local corners = {
            Vector3.new( size.X,  size.Y,  size.Z), Vector3.new(-size.X,  size.Y,  size.Z),
            Vector3.new( size.X, -size.Y,  size.Z), Vector3.new(-size.X, -size.Y,  size.Z),
            Vector3.new( size.X,  size.Y, -size.Z), Vector3.new(-size.X,  size.Y, -size.Z),
            Vector3.new( size.X, -size.Y, -size.Z), Vector3.new(-size.X, -size.Y, -size.Z)
        }
        for _, offset in ipairs(corners) do
            local pos, visible = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
            if visible then
                local v2 = Vector2.new(pos.X, pos.Y)
                min = min:Min(v2)
                max = max:Max(v2)
                onscreen = true
            end
        end
    end
    
    if onscreen then
        local width, height = math.max(max.X - min.X, 18), math.max(max.Y - min.Y, 28)
        local center_x, center_y = (min.X + max.X) / 2, (min.Y + max.Y) / 2
        min = Vector2.new(center_x - width/2, center_y - height/2)
        max = Vector2.new(center_x + width/2, center_y + height/2)
    end
    
    return min, max, onscreen
end

-- // Add functions for objects/entities
function espfunctions.add_box(instance)
    if not instance or (espinstances[instance] and espinstances[instance].box) then return end
    
    local box = {
        outline = Drawing.new("Square"), fill = Drawing.new("Square"),
        glow_layers = {}, corner_fill = {}, corner_outline = {}, corner_glow = {}
    }
    
    box.outline.Filled = false; box.outline.Thickness = 3; box.outline.Transparency = 1; box.outline.Visible = false
    box.fill.Filled = false; box.fill.Thickness = 1; box.fill.Transparency = 1; box.fill.Visible = false
    
    for i = 1, 6 do
        local glow = Drawing.new("Square")
        glow.Filled = false; glow.Transparency = 1; glow.Visible = false; glow.Thickness = math.ceil(i * 1.5)
        table.insert(box.glow_layers, glow)
    end
    
    for i = 1, 8 do
        local outline = Drawing.new("Line")
        outline.Thickness = 2; outline.Transparency = 1; outline.Visible = false
        
        local fill = Drawing.new("Line")
        fill.Thickness = 1; fill.Transparency = 1; fill.Visible = false
        
        local corner_glow_layers = {}
        for j = 1, 4 do
            local glow = Drawing.new("Line")
            glow.Thickness = math.ceil(j * 2.5); glow.Transparency = 1; glow.Visible = false
            table.insert(corner_glow_layers, glow)
        end
        
        table.insert(box.corner_fill, fill)
        table.insert(box.corner_outline, outline)
        table.insert(box.corner_glow, corner_glow_layers)
    end
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].box = box
    if entityesp.animations.enabled then
        animation_data[instance] = { alpha = entityesp.animations.fade_in and 0 or 1, target_alpha = 1 }
    end
end

function espfunctions.add_healthbar(instance)
    if not instance or (espinstances[instance] and espinstances[instance].healthbar) then return end
    
    local outline = Drawing.new("Square")
    outline.Thickness = 1; outline.Filled = true; outline.Transparency = 1
    
    local fill = Drawing.new("Square")
    fill.Filled = true; fill.Transparency = 1
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].healthbar = { outline = outline, fill = fill }
end

function espfunctions.add_name(instance, custom_name)
    if not instance or (espinstances[instance] and espinstances[instance].name) then return end
    
    local text = Drawing.new("Text")
    text.Center = true; text.Outline = true; text.Font = 1; text.Transparency = 1
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].name = { text = text, custom_name = custom_name }
end

function espfunctions.add_distance(instance)
    if not instance or (espinstances[instance] and espinstances[instance].distance) then return end
    
    local text = Drawing.new("Text")
    text.Center = true; text.Outline = true; text.Font = 1; text.Transparency = 1
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].distance = text
end

function espfunctions.add_tracer(instance)
    if not instance or (espinstances[instance] and espinstances[instance].tracer) then return end
    
    local outline = Drawing.new("Line")
    outline.Thickness = 2; outline.Transparency = 1
    
    local fill = Drawing.new("Line")
    fill.Thickness = 1; fill.Transparency = 1
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].tracer = { outline = outline, fill = fill }
end

-- Главная функция для быстрого добавления любого предмета/NPC
function espfunctions.add_entity(instance, options)
    if not instance then return end
    options = options or {}
    
    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].custom_color = options.color
    
    if entityesp.box.enabled then espfunctions.add_box(instance) end
    if entityesp.healthbar.enabled and instance:FindFirstChildOfClass("Humanoid") then espfunctions.add_healthbar(instance) end
    if entityesp.name.enabled then espfunctions.add_name(instance, options.name) end
    if entityesp.distance.enabled then espfunctions.add_distance(instance) end
    if entityesp.tracer.enabled then espfunctions.add_tracer(instance) end
end

function espfunctions.remove_entity(instance)
    if not instance or not espinstances[instance] then return end
    local data = espinstances[instance]
    
    pcall(function()
        if data.box then
            data.box.outline:Remove(); data.box.fill:Remove()
            for _, g in ipairs(data.box.glow_layers) do g:Remove() end
            for _, l in ipairs(data.box.corner_fill) do l:Remove() end
            for _, l in ipairs(data.box.corner_outline) do l:Remove() end
            for _, cg in ipairs(data.box.corner_glow) do for _, g in ipairs(cg) do g:Remove() end end
        end
        if data.healthbar then data.healthbar.outline:Remove(); data.healthbar.fill:Remove() end
        if data.name and data.name.text then data.name.text:Remove() end
        if data.distance then data.distance:Remove() end
        if data.tracer then data.tracer.outline:Remove(); data.tracer.fill:Remove() end
    end)
    
    espinstances[instance] = nil
    hover_targets[instance] = nil
    animation_data[instance] = nil
    health_animations[instance] = nil
    glow_animations[instance] = nil
end

function espfunctions.cleanup()
    for instance, _ in pairs(espinstances) do espfunctions.remove_entity(instance) end
end

-- // Animation helpers
local function update_animations(instance, base_transparency)
    if not entityesp.animations.enabled then return base_transparency end
    local anim = animation_data[instance] or { alpha = entityesp.animations.fade_in and 0 or 1, target_alpha = 1 }
    animation_data[instance] = anim
    
    if anim.alpha ~= anim.target_alpha then
        local diff = anim.target_alpha - anim.alpha
        anim.alpha = anim.alpha + (diff * entityesp.animations.speed)
        if math.abs(diff) < 0.01 then anim.alpha = anim.target_alpha end
    end
    
    local final_transparency = base_transparency * anim.alpha
    if entityesp.animations.pulse then
        pulse_time = pulse_time + entityesp.animations.pulse_speed
        final_transparency = final_transparency * (0.5 + ((math.sin(pulse_time) + 1) / 2) * 0.5)
    end
    return final_transparency
end

local function get_rainbow_color()
    if not entityesp.animations.rainbow then return nil end
    rainbow_time = rainbow_time + entityesp.animations.rainbow_speed
    return Color3.new((math.sin(rainbow_time) + 1) / 2, (math.sin(rainbow_time + 2.094) + 1) / 2, (math.sin(rainbow_time + 4.188) + 1) / 2)
end

local function update_glow_fade(instance, distance)
    if not entityesp.glow.enabled then return 0 end
    local glow_anim = glow_animations[instance] or { current_alpha = 0, target_alpha = 0 }
    glow_animations[instance] = glow_anim
    
    local fade_start = entityesp.glow.max_distance * 0.6
    glow_anim.target_alpha = distance <= fade_start and 1.0 or (distance <= entityesp.glow.max_distance and math.pow(1.0 - ((distance - fade_start) / (entityesp.glow.max_distance - fade_start)), 2) or 0)
    
    if glow_anim.current_alpha ~= glow_anim.target_alpha then
        local diff = glow_anim.target_alpha - glow_anim.current_alpha
        glow_anim.current_alpha = glow_anim.current_alpha + (diff * entityesp.animations.speed * 0.8)
        if math.abs(diff) < 0.005 then glow_anim.current_alpha = glow_anim.target_alpha end
    end
    return math.max(glow_anim.current_alpha, 0)
end

local function update_health_animation(instance, current_health, max_health)
    if not entityesp.animations.health_smooth then return current_health / max_health end
    local health_anim = health_animations[instance] or { displayed_health = current_health, target_health = current_health, last_max_health = max_health }
    health_animations[instance] = health_anim
    
    if health_anim.last_max_health ~= max_health then
        health_anim.displayed_health = current_health
        health_anim.last_max_health = max_health
    end
    health_anim.target_health = current_health
    
    if health_anim.displayed_health ~= health_anim.target_health then
        local diff = health_anim.target_health - health_anim.displayed_health
        health_anim.displayed_health = health_anim.displayed_health + (diff * entityesp.animations.speed * 2)
        if math.abs(diff) < 0.5 then health_anim.displayed_health = health_anim.target_health end
    end
    return math.clamp(health_anim.displayed_health / max_health, 0, 1)
end

-- // Main render loop
run_service.RenderStepped:Connect(function()
    if not workspace.CurrentCamera then return end
    
    for instance, data in pairs(espinstances) do
        -- Авто-очистка удаленных объектов
        if not instance or not instance.Parent then
            espfunctions.remove_entity(instance)
            continue
        end
        
        local min, max, onscreen = get_bounding_box(instance)
        local target_part = instance:IsA("Model") and (instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")) or instance
        local dist = target_part and (camera.CFrame.Position - target_part.Position).Magnitude or 999
        
        local name_pos = onscreen and Vector2.new((min.X + max.X) / 2, min.Y - 15) or nil
        local transparency = update_animations(instance, calculate_fade_transparency(dist, instance, name_pos))
        local esp_color = get_esp_color(instance, data.custom_color)
        
        local show_boxes = dist <= 1000
        local show_distant_elements = dist <= 2000
        
        -- BOX
        if data.box then
            local box = data.box
            if entityesp.box.enabled and onscreen and show_boxes then
                local x, y, w, h = min.X, min.Y, (max - min).X, (max - min).Y
                local len = math.min(w, h) * 0.25
                local box_color = get_rainbow_color() or esp_color
                local glow_alpha = update_glow_fade(instance, dist)
                
                if entityesp.box.type == "normal" then
                    for _, l in ipairs(box.corner_fill) do l.Visible = false end
                    for _, l in ipairs(box.corner_outline) do l.Visible = false end
                    for _, cg in ipairs(box.corner_glow) do for _, g in ipairs(cg) do g.Visible = false end end
                    
                    for i, glow in ipairs(box.glow_layers) do
                        local layer_size = i * entityesp.glow.size * 1.5
                        glow.Position = Vector2.new(x - layer_size, y - layer_size)
                        glow.Size = Vector2.new(w + layer_size * 2, h + layer_size * 2)
                        glow.Color = entityesp.glow.color
                        glow.Transparency = math.max(transparency * entityesp.glow.intensity * glow_alpha * math.pow(0.6, i - 1), 0.02)
                        glow.Visible = glow_alpha > 0
                    end
                    
                    box.outline.Position, box.outline.Size = min, max - min
                    box.outline.Color, box.outline.Transparency, box.outline.Visible = entityesp.box.outline, transparency, true
                    box.fill.Position, box.fill.Size = min, max - min
                    box.fill.Color, box.fill.Transparency, box.fill.Visible = box_color, transparency, true
                else
                    box.outline.Visible, box.fill.Visible = false, false
                    for _, g in ipairs(box.glow_layers) do g.Visible = false end
                    
                    local corners = {
                        {Vector2.new(x, y), Vector2.new(x + len, y)}, {Vector2.new(x, y), Vector2.new(x, y + len)},
                        {Vector2.new(x + w - len, y), Vector2.new(x + w, y)}, {Vector2.new(x + w, y), Vector2.new(x + w, y + len)},
                        {Vector2.new(x, y + h), Vector2.new(x + len, y + h)}, {Vector2.new(x, y + h - len), Vector2.new(x, y + h)},
                        {Vector2.new(x + w - len, y + h), Vector2.new(x + w, y + h)}, {Vector2.new(x + w, y + h - len), Vector2.new(x + w, y + h)}
                    }
                    
                    for i = 1, 8 do
                        local from, to = corners[i][1], corners[i][2]
                        local dir = (to - from).Unit
                        
                        for j, glow in ipairs(box.corner_glow[i]) do
                            glow.From, glow.To = from - dir * j * 1.5, to + dir * j * 1.5
                            glow.Color, glow.Transparency = entityesp.glow.color, math.max(transparency * entityesp.glow.intensity * glow_alpha * math.pow(0.5, j - 1), 0.02)
                            glow.Visible = glow_alpha > 0
                        end
                        
                        local o, f = box.corner_outline[i], box.corner_fill[i]
                        o.From, o.To, o.Color, o.Transparency, o.Visible = from - dir, to + dir, entityesp.box.outline, transparency, true
                        f.From, f.To, f.Color, f.Transparency, f.Visible = from, to, box_color, transparency, true
                    end
                end
            else
                box.outline.Visible, box.fill.Visible = false, false
                for _, g in ipairs(box.glow_layers) do g.Visible = false end
                for _, l in ipairs(box.corner_fill) do l.Visible = false end
                for _, l in ipairs(box.corner_outline) do l.Visible = false end
                for _, cg in ipairs(box.corner_glow) do for _, g in ipairs(cg) do g.Visible = false end end
            end
        end
        
        -- HEALTHBAR
        if data.healthbar then
            local outline, fill = data.healthbar.outline, data.healthbar.fill
            local humanoid = instance:FindFirstChildOfClass("Humanoid")
            if entityesp.healthbar.enabled and onscreen and show_boxes and humanoid and humanoid.MaxHealth > 0 then
                local h, w, p = max.Y - min.Y, max.X - min.X, 1
                local health = update_health_animation(instance, math.max(humanoid.Health, 0), humanoid.MaxHealth)
                local pos_x, pos_y, bar_w, bar_h, f_w, f_h
                
                if entityesp.healthbar.position == "right" then
                    pos_x, pos_y, bar_w, bar_h, f_w, f_h = max.X + 2 + p, min.Y - p, 1 + 2*p, h + 2*p, 1, math.max(h * health, 1)
                    outline.Position, outline.Size = Vector2.new(pos_x, pos_y), Vector2.new(bar_w, bar_h)
                    fill.Position, fill.Size = Vector2.new(pos_x + p, pos_y + (h + p) - f_h), Vector2.new(f_w, f_h)
                elseif entityesp.healthbar.position == "bottom" then
                    pos_x, pos_y, bar_w, bar_h, f_w, f_h = min.X - p, max.Y + 2 + p, w + 2*p, 1 + 2*p, math.max(w * health, 1), 1
                    outline.Position, outline.Size = Vector2.new(pos_x, pos_y), Vector2.new(bar_w, bar_h)
                    fill.Position, fill.Size = Vector2.new(pos_x + p, pos_y + p), Vector2.new(f_w, f_h)
                else
                    pos_x, pos_y, bar_w, bar_h, f_w, f_h = min.X - 3 - p, min.Y - p, 1 + 2*p, h + 2*p, 1, math.max(h * health, 1)
                    outline.Position, outline.Size = Vector2.new(pos_x, pos_y), Vector2.new(bar_w, bar_h)
                    fill.Position, fill.Size = Vector2.new(pos_x + p, pos_y + (h + p) - f_h), Vector2.new(f_w, f_h)
                end
                
                outline.Color, outline.Transparency, outline.Visible = entityesp.healthbar.outline, 1, true
                fill.Color = entityesp.healthbar.gradient and Color3.new(
                    entityesp.healthbar.low_color.R + (entityesp.healthbar.high_color.R - entityesp.healthbar.low_color.R) * health,
                    entityesp.healthbar.low_color.G + (entityesp.healthbar.high_color.G - entityesp.healthbar.low_color.G) * health,
                    entityesp.healthbar.low_color.B + (entityesp.healthbar.high_color.B - entityesp.healthbar.low_color.B) * health
                ) or entityesp.healthbar.fill
                fill.Transparency, fill.Visible = transparency, true
            else
                outline.Visible, fill.Visible = false, false
            end
        end
        
        -- NAME
        if data.name then
            if entityesp.name.enabled and onscreen and show_distant_elements then
                local name_str = data.name.custom_name or instance.Name
                local health_str = ""
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                
                if humanoid and humanoid.MaxHealth > 0 and entityesp.name.show_health then
                    health_str = " [" .. math.floor(humanoid.Health) .. ":" .. math.floor(humanoid.MaxHealth) .. "]"
                end
                
                data.name.text.Text = name_str .. health_str
                data.name.text.Size, data.name.text.Color = entityesp.name.size, entityesp.name.fill
                data.name.text.Position = Vector2.new((min.X + max.X) / 2, min.Y - 15)
                data.name.text.Transparency, data.name.text.Visible = transparency, true
            else
                data.name.text.Visible = false
            end
        end
        
        -- DISTANCE
        if data.distance then
            if entityesp.distance.enabled and onscreen and show_distant_elements then
                data.distance.Text = tostring(math.floor(dist)) .. "m"
                data.distance.Size, data.distance.Color = entityesp.distance.size, entityesp.distance.fill
                data.distance.Position = Vector2.new((min.X + max.X) / 2, max.Y + 5)
                data.distance.Transparency, data.distance.Visible = transparency, true
            else
                data.distance.Visible = false
            end
        end
        
        -- TRACER
        if data.tracer then
            if entityesp.tracer.enabled and onscreen and show_distant_elements then
                local from_pos
                if entityesp.tracer.from == "mouse" then
                    local m = user_input_service:GetMouseLocation(); from_pos = Vector2.new(m.X, m.Y)
                elseif entityesp.tracer.from == "center" then
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                else
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                end
                
                data.tracer.fill.From, data.tracer.fill.To = from_pos, Vector2.new((min.X + max.X) / 2, entityesp.box.enabled and max.Y or (min.Y + max.Y) / 2)
                data.tracer.fill.Color, data.tracer.fill.Transparency, data.tracer.fill.Visible = esp_color, transparency, true
            else
                data.tracer.fill.Visible = false
            end
        end
    end
end)

for k, v in pairs(espfunctions) do entityesp[k] = v end
return entityesp
