-- // Full ESP Example with all features
getgenv().esplib = {
    box = {
        enabled = true,
        type = "corner", -- normal, corner
        padding = 1.15,
        fill = Color3.new(1, 1, 1),
        outline = Color3.new(0, 0, 0),
    },
    healthbar = {
        enabled = true,
        fill = Color3.new(0, 1, 0),
        outline = Color3.new(0, 0, 0),
        gradient = true, -- gradient from red to green
        low_color = Color3.new(1, 0, 0), -- red at low health
        high_color = Color3.new(0, 1, 0), -- green at high health
        width = 3, -- width of healthbar
        offset = 5, -- distance from box
    },
    name = {
        enabled = true,
        fill = Color3.new(1, 1, 1),
        size = 13,
        show_health = true, -- show health next to name like "Player [100:100]"
    },
    distance = {
        enabled = true,
        fill = Color3.new(1, 1, 1),
        size = 13,
    },
    tracer = {
        enabled = true,
        fill = Color3.new(1, 1, 1),
        outline = Color3.new(0, 0, 0),
        from = "bottom", -- mouse, head, top, bottom, center
    },
    chams = {
        enabled = false, -- highlight through walls
        fill_color = Color3.new(1, 0, 0),
        fill_transparency = 0.5,
        outline_color = Color3.new(1, 1, 1),
        outline_transparency = 0,
    },
    team_check = {
        enabled = true, -- auto color enemies/teammates
        enemy_color = Color3.new(1, 0, 0), -- red for enemies
        team_color = Color3.new(0, 1, 0), -- green for teammates
    },
    fade = {
        enabled = true, -- fade ESP at distance
        max_distance = 500, -- start fading after this distance
        min_transparency = 0.3, -- minimum transparency at max distance
    },
    skeleton = {
        enabled = true, -- show player skeleton
        color = Color3.new(1, 1, 1),
        thickness = 1,
    },
}

local esplib = loadstring(game:HttpGet('https://raw.githubusercontent.com/tulontop/esp-lib.lua/refs/heads/main/source.lua'))()

-- Function to add full ESP to a character
local function add_full_esp(character)
    esplib.add_box(character)
    esplib.add_healthbar(character)
    esplib.add_name(character)
    esplib.add_distance(character)
    esplib.add_tracer(character)
    esplib.add_skeleton(character)
    esplib.add_chams(character)
end

-- Add ESP to existing players
for _, plr in ipairs(game.Players:GetPlayers()) do
    if plr ~= game.Players.LocalPlayer then
        if plr.Character then
            add_full_esp(plr.Character)
        end
        
        plr.CharacterAdded:Connect(function(character)
            add_full_esp(character)
        end)
    end
end

-- Add ESP to new players
game.Players.PlayerAdded:Connect(function(plr)
    if plr ~= game.Players.LocalPlayer then
        plr.CharacterAdded:Connect(function(character)
            add_full_esp(character)
        end)
    end
end)

-- Optional: Toggle ESP with keybinds
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Toggle box type (normal/corner) with B key
    if input.KeyCode == Enum.KeyCode.B then
        if esplib.box.type == "normal" then
            esplib.box.type = "corner"
            print("Box type: corner")
        else
            esplib.box.type = "normal"
            print("Box type: normal")
        end
    end
    
    -- Toggle health text with H key
    if input.KeyCode == Enum.KeyCode.H then
        esplib.name.show_health = not esplib.name.show_health
        print("Show health:", esplib.name.show_health)
    end
    
    -- Toggle skeleton with K key
    if input.KeyCode == Enum.KeyCode.K then
        esplib.skeleton.enabled = not esplib.skeleton.enabled
        print("Skeleton:", esplib.skeleton.enabled)
    end
    
    -- Toggle chams with C key
    if input.KeyCode == Enum.KeyCode.C then
        esplib.chams.enabled = not esplib.chams.enabled
        print("Chams:", esplib.chams.enabled)
    end
    
    -- Toggle team check with T key
    if input.KeyCode == Enum.KeyCode.T then
        esplib.team_check.enabled = not esplib.team_check.enabled
        print("Team check:", esplib.team_check.enabled)
    end
    
    -- Toggle fade with F key
    if input.KeyCode == Enum.KeyCode.F then
        esplib.fade.enabled = not esplib.fade.enabled
        print("Fade:", esplib.fade.enabled)
    end
end)

print("ESP Loaded!")
print("Keybinds:")
print("B - Toggle box type (normal/corner)")
print("H - Toggle health text")
print("K - Toggle skeleton")
print("C - Toggle chams")
print("T - Toggle team check")
print("F - Toggle fade")
