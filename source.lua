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
            type = "normal",
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
            position = "left",
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
            from = "mouse",
        },
        fade = {
            enabled = false,
            max_distance = 500,
            min_transparency = 0.3,
            hover_enabled = true,
            hover_radius = 200,
            hover_transparency = 1.0,
            hover_boost = 2.0,
            animation_speed = 0.25,
        },
        visibility = {
            enabled = false,
            visible_color = Color3.new(0, 1, 0),
            hidden_color = Color3.new(1, 0, 0),
        },
        whitelist = {
            enabled = false,
            players = {},
        },
        friends = {
            enabled = false,
            friend_color = Color3.new(0, 1, 0),
            enemy_color = Color3.new(1, 0, 0),
            show_tags = false,
            friends_list = {},
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
    getgenv().esplib = esplib
end

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
local hover_targets = {}
local animation_data = {}
local health_animations = {}
local glow_animations = {}
local rainbow_time = 0
local pulse_time = 0

-- // services
local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local tween_service = game:GetService("TweenService")

-- ============================================================
-- CLEANUP
-- ============================================================
local function remove_instance_esp(instance)
    local data = espinstances[instance]
    if not data then return end

    if data.box then
        pcall(function() data.box.outline:Remove() end)
        pcall(function() data.box.fill:Remove() end)
        if data.box.glow_layers then
            for _, g in ipairs(data.box.glow_layers) do pcall(function() g:Remove() end) end
        end
        for _, l in ipairs(data.box.corner_fill or {}) do pcall(function() l:Remove() end) end
        for _, l in ipairs(data.box.corner_outline or {}) do pcall(function() l:Remove() end) end
        for _, cg in ipairs(data.box.corner_glow or {}) do
            for _, g in ipairs(cg or {}) do pcall(function() g:Remove() end) end
        end
    end
    if data.healthbar then
        pcall(function() data.healthbar.outline:Remove() end)
        pcall(function() data.healthbar.fill:Remove() end)
    end
    if data.name then
        pcall(function() data.name.text:Remove() end)
        pcall(function() data.name.tag_bracket_left:Remove() end)
        pcall(function() data.name.tag_letter:Remove() end)
        pcall(function() data.name.tag_bracket_right:Remove() end)
    end
    if data.distance then pcall(function() data.distance:Remove() end) end
    if data.tracer then
        pcall(function() data.tracer.outline:Remove() end)
        pcall(function() data.tracer.fill:Remove() end)
    end

    espinstances[instance] = nil
    hover_targets[instance] = nil
    animation_data[instance] = nil
    -- ✅ ИСПРАВЛЕНИЕ: сбрасываем health animation при удалении
    health_animations[instance] = nil
    glow_animations[instance] = nil
end

local function cleanup_esp()
    for instance in pairs(espinstances) do
        remove_instance_esp(instance)
    end
end

game.Players.PlayerRemoving:Connect(function(player)
    if player == game.Players.LocalPlayer then
        cleanup_esp()
    end
end)

workspace.ChildRemoved:Connect(function(child)
    if child.Name == "Live" or child.Name == "Players" then
        cleanup_esp()
    end
end)

-- ============================================================
-- AUTO ESP — новые игроки и respawn
-- ============================================================
local function setup_character(character)
    if not character then return end

    -- ✅ ИСПРАВЛЕНИЕ: сбрасываем health animation при respawn
    health_animations[character] = nil
    animation_data[character] = nil
    hover_targets[character] = nil
    glow_animations[character] = nil

    -- ждём пока персонаж полностью загрузится
    task.wait(0.5)

    if not character.Parent then return end

    espfunctions.add_box(character)
    espfunctions.add_healthbar(character)
    espfunctions.add_name(character)
    espfunctions.add_distance(character)
    espfunctions.add_tracer(character)
end

local function setup_player(player)
    if player == players.LocalPlayer then return end

    -- Подключаем к CharacterAdded для respawn
    player.CharacterAdded:Connect(function(character)
        -- ✅ ИСПРАВЛЕНИЕ: удаляем старый ESP перед созданием нового
        if espinstances[character] then
            remove_instance_esp(character)
        end
        setup_character(character)
    end)

    -- ✅ ИСПРАВЛЕНИЕ: удаляем ESP когда персонаж уходит
    player.CharacterRemoving:Connect(function(character)
        remove_instance_esp(character)
    end)

    -- Если персонаж уже есть — добавляем сразу
    if player.Character then
        setup_character(player.Character)
    end
end

-- Подключаем к существующим игрокам
for _, player in ipairs(players:GetPlayers()) do
    setup_player(player)
end

-- ✅ ИСПРАВЛЕНИЕ: подключаем к новым игрокам
players.PlayerAdded:Connect(function(player)
    setup_player(player)
end)

-- ✅ ИСПРАВЛЕНИЕ: убираем ESP когда игрок уходит
players.PlayerRemoving:Connect(function(player)
    if player.Character then
        remove_instance_esp(player.Character)
    end
end)

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
local function is_whitelisted(instance)
    if not esplib.whitelist.enabled then return false end
    local player = players:GetPlayerFromCharacter(instance)
    if player then
        for _, name in ipairs(esplib.whitelist.players) do
            if player.Name == name then return true end
        end
    end
    return false
end

local function is_friend(instance)
    if not esplib.friends.enabled then return false end
    local player = players:GetPlayerFromCharacter(instance)
    if player then
        for _, name in ipairs(esplib.friends.friends_list) do
            if player.Name == name then return true end
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
    if ray then return ray.Instance:IsDescendantOf(instance) end
    return true
end

local function get_esp_color(instance)
    local base_color = Color3.new(1, 1, 1)
    if esplib.visibility.enabled then
        base_color = is_visible(instance) and esplib.visibility.visible_color or esplib.visibility.hidden_color
    end
    return base_color
end

local function calculate_fade_transparency(distance, instance, name_pos)
    local base_transparency = 1
    if esplib.fade.enabled then
        if distance > esplib.fade.max_distance then
            local fade_factor = math.clamp((distance - esplib.fade.max_distance) / esplib.fade.max_distance, 0, 1)
            base_transparency = math.max(esplib.fade.min_transparency, 1 - fade_factor)
        end
    end
    if esplib.fade.hover_enabled and name_pos then
        local mouse_pos = user_input_service:GetMouseLocation()
        local distance_to_mouse = (Vector2.new(mouse_pos.X, mouse_pos.Y) - name_pos).Magnitude
        if not hover_targets[instance] then
            hover_targets[instance] = { current_transparency = base_transparency, target_transparency = 1.0 }
        end
        if distance_to_mouse <= esplib.fade.hover_radius then
            hover_targets[instance].target_transparency = 1.0
        else
            hover_targets[instance].target_transparency = base_transparency
        end
        local current = hover_targets[instance].current_transparency
        local target = hover_targets[instance].target_transparency
        hover_targets[instance].current_transparency = current + (target - current) * esplib.fade.animation_speed
        if distance_to_mouse <= esplib.fade.hover_radius then return 1.0 end
        return hover_targets[instance].current_transparency
    end
    return base_transparency
end

local function get_bounding_box(instance)
    local min, max = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
    local onscreen = false

    local function process_part(p)
        local size = (p.Size / 2) * esplib.box.padding
        local cf = p.CFrame
        for _, offset in ipairs({
            Vector3.new( size.X,  size.Y,  size.Z), Vector3.new(-size.X,  size.Y,  size.Z),
            Vector3.new( size.X, -size.Y,  size.Z), Vector3.new(-size.X, -size.Y,  size.Z),
            Vector3.new( size.X,  size.Y, -size.Z), Vector3.new(-size.X,  size.Y, -size.Z),
            Vector3.new( size.X, -size.Y, -size.Z), Vector3.new(-size.X, -size.Y, -size.Z),
        }) do
            local pos, visible = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
            if visible then
                local v2 = Vector2.new(pos.X, pos.Y)
                min = min:Min(v2); max = max:Max(v2); onscreen = true
            end
        end
    end

    if instance:IsA("Model") then
        for _, p in ipairs(instance:GetChildren()) do
            if p:IsA("BasePart") then process_part(p)
            elseif p:IsA("Accessory") then
                local handle = p:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then process_part(handle) end
            end
        end
    elseif instance:IsA("BasePart") then
        process_part(instance)
    end

    if onscreen then
        local width = max.X - min.X
        local height = max.Y - min.Y
        local cx = (min.X + max.X) / 2
        local cy = (min.Y + max.Y) / 2
        width = math.max(width, 18)
        height = math.max(height, 28)
        min = Vector2.new(cx - width/2, cy - height/2)
        max = Vector2.new(cx + width/2, cy + height/2)
    end

    return min, max, onscreen
end

local function update_animations(instance, base_transparency)
    if not esplib.animations.enabled then return base_transparency end
    if not animation_data[instance] then
        animation_data[instance] = {
            alpha = esplib.animations.fade_in and 0 or 1,
            target_alpha = 1,
        }
    end
    local anim = animation_data[instance]
    if anim.alpha ~= anim.target_alpha then
        local diff = anim.target_alpha - anim.alpha
        anim.alpha = anim.alpha + (diff * esplib.animations.speed)
        if math.abs(diff) < 0.01 then anim.alpha = anim.target_alpha end
    end
    local final_transparency = base_transparency * anim.alpha
    if esplib.animations.pulse then
        pulse_time = pulse_time + esplib.animations.pulse_speed
        local pulse_factor = (math.sin(pulse_time) + 1) / 2
        final_transparency = final_transparency * (0.5 + pulse_factor * 0.5)
    end
    return final_transparency
end

local function get_rainbow_color()
    if not esplib.animations.rainbow then return nil end
    rainbow_time = rainbow_time + esplib.animations.rainbow_speed
    return Color3.new(
        (math.sin(rainbow_time) + 1) / 2,
        (math.sin(rainbow_time + 2.094) + 1) / 2,
        (math.sin(rainbow_time + 4.188) + 1) / 2
    )
end

local function update_glow_fade(instance, distance)
    if not esplib.glow.enabled then return 0 end
    if not glow_animations[instance] then
        glow_animations[instance] = { current_alpha = 0, target_alpha = 0 }
    end
    local ga = glow_animations[instance]
    if distance <= esplib.glow.max_distance then
        local fade_start = esplib.glow.max_distance * 0.6
        if distance <= fade_start then
            ga.target_alpha = 1.0
        else
            local f = (distance - fade_start) / (esplib.glow.max_distance - fade_start)
            ga.target_alpha = math.pow(1.0 - f, 2)
        end
    else
        ga.target_alpha = 0
    end
    local diff = ga.target_alpha - ga.current_alpha
    ga.current_alpha = ga.current_alpha + (diff * esplib.animations.speed * 0.8)
    if math.abs(diff) < 0.005 then ga.current_alpha = ga.target_alpha end
    return math.max(ga.current_alpha, 0)
end

local function update_health_animation(instance, current_health, max_health)
    if not esplib.animations.health_smooth then
        return current_health / max_health
    end

    -- ✅ ИСПРАВЛЕНИЕ: если записи нет или max_health изменился (respawn) — сбрасываем на текущее
    if not health_animations[instance] then
        health_animations[instance] = {
            displayed_health = current_health,
            target_health = current_health,
            last_max_health = max_health,
        }
    end

    local ha = health_animations[instance]

    -- ✅ ИСПРАВЛЕНИЕ: respawn detection — max_health изменился или displayed_health сильно отличается
    if ha.last_max_health ~= max_health then
        ha.displayed_health = current_health
        ha.target_health = current_health
        ha.last_max_health = max_health
        return math.clamp(current_health / max_health, 0, 1)
    end

    -- ✅ ИСПРАВЛЕНИЕ: если текущий HP намного больше displayed (respawn с 0) — снэп сразу
    if current_health > ha.displayed_health + max_health * 0.3 then
        ha.displayed_health = current_health
        ha.target_health = current_health
        return math.clamp(current_health / max_health, 0, 1)
    end

    ha.target_health = current_health
    if ha.displayed_health ~= ha.target_health then
        local diff = ha.target_health - ha.displayed_health
        ha.displayed_health = ha.displayed_health + (diff * esplib.animations.speed * 2)
        if math.abs(diff) < 0.5 then ha.displayed_health = ha.target_health end
    end

    return math.clamp(ha.displayed_health / max_health, 0, 1)
end

-- ============================================================
-- ADD FUNCTIONS
-- ============================================================
function espfunctions.add_box(instance)
    if not instance or (espinstances[instance] and espinstances[instance].box) then return end

    local box = {}

    local outline = Drawing.new("Square")
    outline.Filled = false; outline.Transparency = 1; outline.Visible = false

    local fill = Drawing.new("Square")
    fill.Filled = false; fill.Transparency = 1; fill.Visible = false

    local glow_layers = {}
    for i = 1, 6 do
        local g = Drawing.new("Square")
        g.Filled = false; g.Transparency = 1; g.Visible = false
        g.Thickness = math.ceil(i * 1.5)
        table.insert(glow_layers, g)
    end

    box.outline = outline; box.fill = fill; box.glow_layers = glow_layers
    box.corner_fill = {}; box.corner_outline = {}; box.corner_glow = {}

    for i = 1, 8 do
        local ol = Drawing.new("Line"); ol.Thickness = 2; ol.Transparency = 1; ol.Visible = false
        local fl = Drawing.new("Line"); fl.Thickness = 1; fl.Transparency = 1; fl.Visible = false
        local cg = {}
        for j = 1, 4 do
            local g = Drawing.new("Line"); g.Thickness = math.ceil(j * 2.5); g.Transparency = 1; g.Visible = false
            table.insert(cg, g)
        end
        table.insert(box.corner_fill, fl)
        table.insert(box.corner_outline, ol)
        table.insert(box.corner_glow, cg)
    end

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].box = box

    if esplib.animations.enabled then
        animation_data[instance] = {
            alpha = esplib.animations.fade_in and 0 or 1,
            target_alpha = 1,
        }
    end
end

function espfunctions.add_healthbar(instance)
    if not instance or (espinstances[instance] and espinstances[instance].healthbar) then return end

    local outline = Drawing.new("Square"); outline.Thickness = 1; outline.Filled = true; outline.Transparency = 1
    local fill = Drawing.new("Square"); fill.Filled = true; fill.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].healthbar = { outline = outline, fill = fill }

    -- ✅ ИСПРАВЛЕНИЕ: сбрасываем health animation при добавлении healthbar
    health_animations[instance] = nil
end

function espfunctions.add_name(instance)
    if not instance or (espinstances[instance] and espinstances[instance].name) then return end

    local text = Drawing.new("Text"); text.Center = true; text.Outline = true; text.Font = 1; text.Transparency = 1
    local tbl = Drawing.new("Text"); tbl.Center = false; tbl.Outline = true; tbl.Font = 1; tbl.Transparency = 1; tbl.Visible = false
    local tlt = Drawing.new("Text"); tlt.Center = false; tlt.Outline = true; tlt.Font = 1; tlt.Transparency = 1; tlt.Visible = false
    local tbr = Drawing.new("Text"); tbr.Center = false; tbr.Outline = true; tbr.Font = 1; tbr.Transparency = 1; tbr.Visible = false

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].name = { text = text, tag_bracket_left = tbl, tag_letter = tlt, tag_bracket_right = tbr }
end

function espfunctions.add_distance(instance)
    if not instance or (espinstances[instance] and espinstances[instance].distance) then return end

    local text = Drawing.new("Text"); text.Center = true; text.Outline = true; text.Font = 1; text.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].distance = text
end

function espfunctions.add_tracer(instance)
    if not instance or (espinstances[instance] and espinstances[instance].tracer) then return end

    local outline = Drawing.new("Line"); outline.Thickness = 2; outline.Transparency = 1
    local fill = Drawing.new("Line"); fill.Thickness = 1; fill.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].tracer = { outline = outline, fill = fill }
end

function espfunctions.cleanup()
    cleanup_esp()
end

function espfunctions.force_cleanup()
    pcall(cleanup_esp)
    espinstances = {}; hover_targets = {}; animation_data = {}
    health_animations = {}; glow_animations = {}
    if getgenv().esplib then getgenv().esplib = nil end
end

function espfunctions.reset()
    cleanup_esp()
    hover_targets = {}
end

-- ============================================================
-- MAIN RENDER LOOP
-- ============================================================
run_service.RenderStepped:Connect(function()
    if not game.Players.LocalPlayer or not workspace.CurrentCamera then
        cleanup_esp()
        return
    end

    for instance, data in pairs(espinstances) do
        if not instance or not instance.Parent then
            remove_instance_esp(instance)
            continue
        end

        if is_whitelisted(instance) then
            if data.box then data.box.outline.Visible = false; data.box.fill.Visible = false end
            if data.healthbar then data.healthbar.outline.Visible = false; data.healthbar.fill.Visible = false end
            if data.name then data.name.text.Visible = false end
            if data.distance then data.distance.Visible = false end
            if data.tracer then data.tracer.outline.Visible = false; data.tracer.fill.Visible = false end
            continue
        end

        if instance:IsA("Model") and not instance.PrimaryPart then continue end

        local min, max, onscreen = get_bounding_box(instance)

        local dist
        if instance:IsA("Model") then
            local part = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
            dist = part and (camera.CFrame.Position - part.Position).Magnitude or 999
        else
            dist = (camera.CFrame.Position - instance.Position).Magnitude
        end

        local name_pos = onscreen and Vector2.new((min.X + max.X) / 2, min.Y - 15) or nil
        local transparency = calculate_fade_transparency(dist, instance, name_pos)
        transparency = update_animations(instance, transparency)
        local esp_color = get_esp_color(instance)
        local show_boxes = dist <= 1000
        local show_distant = dist <= 2000

        -- BOX
        if data.box then
            local box = data.box
            if esplib.box.enabled and onscreen and show_boxes then
                local x, y = min.X, min.Y
                local w, h = (max - min).X, (max - min).Y
                local len = math.min(w, h) * 0.25

                if esplib.box.type == "normal" then
                    for _, l in ipairs(box.corner_fill) do l.Visible = false end
                    for _, l in ipairs(box.corner_outline) do l.Visible = false end
                    for _, cg in ipairs(box.corner_glow) do for _, g in ipairs(cg) do g.Visible = false end end

                    local glow_alpha = update_glow_fade(instance, dist)
                    if glow_alpha > 0 and box.glow_layers then
                        for i, g in ipairs(box.glow_layers) do
                            local ls = i * esplib.glow.size * 1.5
                            g.Position = Vector2.new(min.X - ls, min.Y - ls)
                            g.Size = Vector2.new(w + ls * 2, h + ls * 2)
                            g.Color = esplib.glow.color
                            g.Transparency = math.max(transparency * esplib.glow.intensity * glow_alpha * math.pow(0.6, i - 1), 0.02)
                            g.Visible = true
                        end
                    else
                        if box.glow_layers then for _, g in ipairs(box.glow_layers) do g.Visible = false end end
                    end

                    local box_color = get_rainbow_color() or esp_color
                    box.outline.Position = min; box.outline.Size = max - min
                    box.outline.Color = esplib.box.outline; box.outline.Transparency = transparency; box.outline.Visible = true
                    box.fill.Position = min; box.fill.Size = max - min
                    box.fill.Color = box_color; box.fill.Transparency = transparency; box.fill.Visible = true

                elseif esplib.box.type == "corner" then
                    box.outline.Visible = false; box.fill.Visible = false
                    if box.glow_layers then for _, g in ipairs(box.glow_layers) do g.Visible = false end end

                    local fill_color = get_rainbow_color() or esp_color
                    local corners = {
                        {Vector2.new(x,y),         Vector2.new(x+len,y)},
                        {Vector2.new(x,y),         Vector2.new(x,y+len)},
                        {Vector2.new(x+w-len,y),   Vector2.new(x+w,y)},
                        {Vector2.new(x+w,y),       Vector2.new(x+w,y+len)},
                        {Vector2.new(x,y+h),       Vector2.new(x+len,y+h)},
                        {Vector2.new(x,y+h-len),   Vector2.new(x,y+h)},
                        {Vector2.new(x+w-len,y+h), Vector2.new(x+w,y+h)},
                        {Vector2.new(x+w,y+h-len), Vector2.new(x+w,y+h)},
                    }
                    local glow_alpha = update_glow_fade(instance, dist)
                    for i = 1, 8 do
                        local from, to = corners[i][1], corners[i][2]
                        local dir = (to - from).Unit
                        if glow_alpha > 0 and box.corner_glow[i] then
                            for j, g in ipairs(box.corner_glow[i]) do
                                g.From = from - dir * j * 1.5; g.To = to + dir * j * 1.5
                                g.Color = esplib.glow.color
                                g.Transparency = math.max(transparency * esplib.glow.intensity * glow_alpha * math.pow(0.5, j-1), 0.02)
                                g.Visible = true
                            end
                        else
                            if box.corner_glow[i] then for _, g in ipairs(box.corner_glow[i]) do g.Visible = false end end
                        end
                        local o = box.corner_outline[i]
                        o.From = from - dir; o.To = to + dir
                        o.Color = esplib.box.outline; o.Transparency = transparency; o.Visible = true
                        local f = box.corner_fill[i]
                        f.From = from; f.To = to
                        f.Color = fill_color; f.Transparency = transparency; f.Visible = true
                    end
                end
            else
                box.outline.Visible = false; box.fill.Visible = false
                if box.glow_layers then for _, g in ipairs(box.glow_layers) do g.Visible = false end end
                for _, l in ipairs(box.corner_fill) do l.Visible = false end
                for _, l in ipairs(box.corner_outline) do l.Visible = false end
                for _, cg in ipairs(box.corner_glow) do for _, g in ipairs(cg) do g.Visible = false end end
            end
        end

        -- HEALTHBAR
        if data.healthbar then
            local outline, fill = data.healthbar.outline, data.healthbar.fill
            if not esplib.healthbar.enabled or not onscreen or not show_boxes then
                outline.Visible = false; fill.Visible = false
            else
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                -- ✅ ИСПРАВЛЕНИЕ: показываем healthbar даже при 0 HP, проверяем только наличие humanoid
                if humanoid and humanoid.MaxHealth > 0 then
                    local height = max.Y - min.Y
                    local width = max.X - min.X
                    local padding = 1
                    local current_health = math.max(humanoid.Health, 0)
                    local health = update_health_animation(instance, current_health, humanoid.MaxHealth)
                    local x, y = min.X, min.Y
                    local bar_width, bar_height, fillheight, fillwidth

                    if esplib.healthbar.position == "right" then
                        x = max.X + 2 + padding; y = min.Y - padding
                        bar_width = 1 + 2 * padding; bar_height = height + 2 * padding
                        fillheight = math.max(height * health, 1); fillwidth = 1
                        outline.Position = Vector2.new(x, y); outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + (height + padding) - fillheight)
                        fill.Size = Vector2.new(fillwidth, fillheight)
                    elseif esplib.healthbar.position == "bottom" then
                        x = min.X - padding; y = max.Y + 2 + padding
                        bar_width = width + 2 * padding; bar_height = 1 + 2 * padding
                        fillwidth = math.max(width * health, 1); fillheight = 1
                        outline.Position = Vector2.new(x, y); outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + padding)
                        fill.Size = Vector2.new(fillwidth, fillheight)
                    else -- left
                        x = min.X - 2 - 1 - padding; y = min.Y - padding
                        bar_width = 1 + 2 * padding; bar_height = height + 2 * padding
                        fillheight = math.max(height * health, 1); fillwidth = 1
                        outline.Position = Vector2.new(x, y); outline.Size = Vector2.new(bar_width, bar_height)
                        fill.Position = Vector2.new(x + padding, y + (height + padding) - fillheight)
                        fill.Size = Vector2.new(fillwidth, fillheight)
                    end

                    outline.Color = esplib.healthbar.outline; outline.Transparency = 1; outline.Visible = true

                    if esplib.healthbar.gradient then
                        local low = esplib.healthbar.low_color; local high = esplib.healthbar.high_color
                        fill.Color = Color3.new(
                            low.R + (high.R - low.R) * health,
                            low.G + (high.G - low.G) * health,
                            low.B + (high.B - low.B) * health
                        )
                    else
                        fill.Color = esplib.healthbar.fill
                    end
                    fill.Transparency = transparency; fill.Visible = true
                else
                    outline.Visible = false; fill.Visible = false
                end
            end
        end

        -- NAME
        if data.name then
            if esplib.name.enabled and onscreen then
                local nm = data.name
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
                        if esplib.friends.enabled and esplib.friends.show_tags then
                            tag_str = is_friend(instance) and " [F]" or " [E]"
                        end
                    end
                    if esplib.name.show_health and humanoid.MaxHealth > 0 then
                        health_str = " [" .. math.floor(humanoid.Health) .. ":" .. math.floor(humanoid.MaxHealth) .. "]"
                    end
                end
                nm.tag_bracket_left.Visible = false; nm.tag_letter.Visible = false; nm.tag_bracket_right.Visible = false
                nm.text.Text = name_str .. health_str .. tag_str
                nm.text.Size = esplib.name.size; nm.text.Color = esplib.name.fill
                nm.text.Transparency = transparency; nm.text.Position = Vector2.new(center_x, y); nm.text.Visible = true
            else
                if data.name.text then data.name.text.Visible = false end
                if data.name.tag_bracket_left then data.name.tag_bracket_left.Visible = false end
                if data.name.tag_letter then data.name.tag_letter.Visible = false end
                if data.name.tag_bracket_right then data.name.tag_bracket_right.Visible = false end
            end
        end

        -- DISTANCE
        if data.distance then
            if esplib.distance.enabled and onscreen then
                local t = data.distance
                t.Text = tostring(math.floor(dist)) .. "m"
                t.Size = esplib.distance.size; t.Color = esplib.distance.fill
                t.Transparency = transparency
                t.Position = Vector2.new((min.X + max.X) / 2, max.Y + 5)
                t.Visible = true
            else
                data.distance.Visible = false
            end
        end

        -- TRACER
        if data.tracer then
            if esplib.tracer.enabled and onscreen and show_distant then
                local outline, fill = data.tracer.outline, data.tracer.fill
                local from_pos
                if esplib.tracer.from == "mouse" then
                    local ml = user_input_service:GetMouseLocation()
                    from_pos = Vector2.new(ml.X, ml.Y)
                elseif esplib.tracer.from == "head" then
                    local head = instance:FindFirstChild("Head")
                    if head then
                        local pos, vis = camera:WorldToViewportPoint(head.Position)
                        from_pos = vis and Vector2.new(pos.X, pos.Y) or Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                    else
                        from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                    end
                elseif esplib.tracer.from == "center" then
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                else -- bottom
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                end
                local to_pos = esplib.box.enabled and Vector2.new((min.X+max.X)/2, max.Y) or (min+max)/2
                outline.From = from_pos; outline.To = to_pos; outline.Color = esplib.tracer.outline
                outline.Transparency = 0; outline.Visible = false
                fill.From = from_pos; fill.To = to_pos; fill.Color = esp_color
                fill.Transparency = transparency; fill.Visible = true
            else
                data.tracer.outline.Visible = false; data.tracer.fill.Visible = false
            end
        end
    end
end)

-- // return
for k, v in pairs(espfunctions) do
    esplib[k] = v
end

return esplib
