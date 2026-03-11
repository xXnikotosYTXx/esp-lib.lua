-- // Simple player ESP with basic settings
-- Load library first
local esplib = loadstring(game:HttpGet('https://raw.githubusercontent.com/xXnikotosYTXx/esp-lib.lua/refs/heads/main/source.lua'))()

-- Now configure it (library already has defaults)
esplib.box.enabled = true
esplib.box.type = "normal" -- or "corner"
esplib.healthbar.enabled = true
esplib.healthbar.gradient = true -- gradient from red to green
esplib.name.enabled = true
esplib.name.show_health = false -- set to true to show health like "Player [100:100]"
esplib.distance.enabled = true
esplib.tracer.enabled = true
esplib.tracer.from = "mouse" -- mouse, head, top, bottom, center

-- Optional advanced features (disabled by default)
esplib.skeleton.enabled = false
esplib.chams.enabled = false
esplib.team_check.enabled = false
esplib.fade.enabled = false

-- Function to add ESP to a character
local function add_esp(character)
    esplib.add_box(character)
    esplib.add_healthbar(character)
    esplib.add_name(character)
    esplib.add_distance(character)
    esplib.add_tracer(character)
    -- Optional: uncomment to add skeleton
    -- esplib.add_skeleton(character)
    -- esplib.add_chams(character)
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

print("ESP Loaded! Box type:", esplib.box.type)
