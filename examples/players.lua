-- // Pre-configured ESP (set settings BEFORE loading library)
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
        gradient = true,
        low_color = Color3.new(1, 0, 0),
        high_color = Color3.new(0, 1, 0),
        width = 3,
        offset = 5,
    },
    name = {
        enabled = true,
        fill = Color3.new(1, 1, 1),
        size = 13,
        show_health = true, -- show "Player [100:100]"
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
        from = "bottom",
    },
    skeleton = {
        enabled = true,
        color = Color3.new(1, 1, 1),
        thickness = 1,
    },
    chams = {
        enabled = false,
        fill_color = Color3.new(1, 0, 0),
        fill_transparency = 0.5,
        outline_color = Color3.new(1, 1, 1),
        outline_transparency = 0,
    },
    team_check = {
        enabled = true,
        enemy_color = Color3.new(1, 0, 0),
        team_color = Color3.new(0, 1, 0),
    },
    fade = {
        enabled = true,
        max_distance = 500,
        min_transparency = 0.3,
    },
}

-- Load library (will use settings above)
local esplib = loadstring(game:HttpGet('https://raw.githubusercontent.com/xXnikotosYTXx/esp-lib.lua/refs/heads/main/source.lua'))()

-- Function to add full ESP
local function add_esp(character)
    esplib.add_box(character)
    esplib.add_healthbar(character)
    esplib.add_name(character)
    esplib.add_distance(character)
    esplib.add_tracer(character)
    esplib.add_skeleton(character)
    -- esplib.add_chams(character) -- uncomment if you want chams
end

-- Add ESP to existing players
for _, plr in ipairs(game.Players:GetPlayers()) do
    if plr ~= game.Players.LocalPlayer then
        if plr.Character then
            add_esp(plr.Character)
        end
        
        plr.CharacterAdded:Connect(function(character)
            add_esp(character)
        end)
    end
end

-- Add ESP to new players
game.Players.PlayerAdded:Connect(function(plr)
    if plr ~= game.Players.LocalPlayer then
        plr.CharacterAdded:Connect(function(character)
            add_esp(character)
        end)
    end
end)

-- Toggle box type with B key
game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.B then
        if esplib.box.type == "normal" then
            esplib.box.type = "corner"
        else
            esplib.box.type = "normal"
        end
        print("Box type:", esplib.box.type)
    end
end)

print("ESP Loaded!")
print("Press B to toggle box type (normal/corner)")
print("Current settings:")
print("- Box type:", esplib.box.type)
print("- Health text:", esplib.name.show_health)
print("- Skeleton:", esplib.skeleton.enabled)
print("- Team check:", esplib.team_check.enabled)
print("- Fade:", esplib.fade.enabled)
