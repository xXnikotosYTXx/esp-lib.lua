--[[
	Universal Aimbot & Silent Aim Module (Premium UI & Hooks)
	- FIXED: ZERO LAG Silent Aim (Cached Positions, no math in hooks)
	- FIXED: Cloneref Reference Bypasses (LocalPlayer Target Bug Fix)
]]
local cloneref = cloneref or function(obj) return obj end
local game = cloneref(game)
local workspace = cloneref(workspace)
local Vector2 = Vector2
local Vector3 = Vector3
local CFrame = CFrame
local Color3 = Color3
local Drawing = Drawing
local TweenInfo = TweenInfo
local Enum = Enum
local unpack = unpack or table.unpack
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = cloneref(Players.LocalPlayer)
local Camera = cloneref(workspace.CurrentCamera)
if getgenv().ExunysDeveloperAimbot then
	pcall(function()
		getgenv().ExunysDeveloperAimbot:Exit()
	end)
end
getgenv().ExunysDeveloperAimbot = {
	Settings = {
		Enabled = true,
		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,
		SilentAim = false, 
		CameraAim = true, 
		Prediction = true, 
		PredictionAmount = 0.165,
		Sensitivity = 0,
		Sensitivity2 = 3.5, 
		LockMode = 1, 
		LockPart = "Head",
		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false
	},
	FOVSettings = {
		Enabled = true,
		Visible = true,
		Dynamic = true,
		BaseRadius = 120,
		RunRadius = 160, 
		JumpRadius = 200, 
		NumSides = 100, 
		Thickness = 1,  
		Transparency = 0.8,
		Filled = false,
		RainbowColor = false,
		Color = Color3.fromRGB(240, 240, 240),
		LockedColor = Color3.fromRGB(255, 80, 80)
	},
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1
	},
	Blacklisted = {},
	FOVCircle = Drawing.new("Circle"),
    
    -- НОВЫЕ ПЕРЕМЕННЫЕ (Для обхода лагов и интеграции меню)
    TriggerActive = false,
    TargetPosition = nil,
    Locked = nil
}
local Environment = getgenv().ExunysDeveloperAimbot
local CurrentDynamicFOV = Environment.FOVSettings.BaseRadius
local ServiceConnections = {}
local RequiredDistance = 2000
local Typing = false
local Animation = nil
local OriginalSensitivity = UserInputService.MouseDeltaSensitivity
Environment.FOVCircle.Visible = false
local function CancelLock()
	Environment.Locked = nil
    Environment.TargetPosition = nil
	Environment.FOVCircle.Color = Environment.FOVSettings.Color
	UserInputService.MouseDeltaSensitivity = OriginalSensitivity
	if Animation then Animation:Cancel() end
end
local function GetRainbowColor()
	local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed
	return Color3.fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
end
local function FixUsername(String)
	local Result
	for _, Player in ipairs(Players:GetPlayers()) do
		local Name = Player.Name
		if string.sub(string.lower(Name), 1, #String) == string.lower(String) then
			Result = Name
		end
	end
	return Result
end
local function GetClosestPlayer()
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart
	if not Environment.Locked then
		RequiredDistance = Environment.FOVSettings.Enabled and CurrentDynamicFOV or 2000
		for _, Player in ipairs(Players:GetPlayers()) do
            -- ИСПРАВЛЕНИЕ ЗДЕСЬ: Проверка по .Name обходит сбои ссылок от cloneref
			if Player.Name == LocalPlayer.Name or table.find(Environment.Blacklisted, Player.Name) then continue end
			
            local Character = Player.Character
			if not Character then continue end
			
            local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			local TargetPart = Character:FindFirstChild(LockPart)
			if Humanoid and TargetPart then
				local TeamCheckOption = Environment.DeveloperSettings.TeamCheckOption
				if Settings.TeamCheck and Player[TeamCheckOption] == LocalPlayer[TeamCheckOption] then continue end
				if Settings.AliveCheck and Humanoid.Health <= 0 then continue end
				if Settings.WallCheck then
					local RaycastParams = RaycastParams.new()
					RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
					RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character, Character}
					local RayDirection = TargetPart.Position - Camera.CFrame.Position
					local Result = workspace:Raycast(Camera.CFrame.Position, RayDirection, RaycastParams)
					if Result then continue end
				end
				local Vector, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
				local Distance = (UserInputService:GetMouseLocation() - Vector2.new(Vector.X, Vector.Y)).Magnitude
				if Distance < RequiredDistance and OnScreen then
					RequiredDistance = Distance
					Environment.Locked = Player
				end
			end
		end
	else
		local TargetCharacter = Environment.Locked.Character
		if not TargetCharacter then CancelLock() return end
		local TargetPart = TargetCharacter:FindFirstChild(Settings.LockPart)
		if not TargetPart then CancelLock() return end
		local Vector, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
		local Distance = (UserInputService:GetMouseLocation() - Vector2.new(Vector.X, Vector.Y)).Magnitude
		if Distance > RequiredDistance or not OnScreen then
			CancelLock()
		end
	end
end
--// ZERO-LAG HOOKS (Идеальный Silent Aim, без расчетов внутри хука)
if not getgenv().ExunysHooksLoaded and hookmetamethod then
	getgenv().ExunysHooksLoaded = true
	local OldNamecall
	OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		local Env = getgenv().ExunysDeveloperAimbot
		-- Моментальная быстрая проверка
		if Env and Env.Settings.Enabled and Env.Settings.SilentAim and Env.TargetPosition and Env.TriggerActive and not checkcaller() then
            -- Используем закешированную позицию (0 лагов!)
            local TargetPos = Env.TargetPosition
			local Method = getnamecallmethod()
            local Args = {...}
            
            -- ИСПРАВЛЕНИЕ: Безопасная проверка на Workspace (обход cloneref)
			if Method == "Raycast" and typeof(self) == "Instance" and self.ClassName == "Workspace" then
				local Origin = Args[1]
				local OriginalDirection = Args[2]
				if typeof(Origin) == "Vector3" and typeof(OriginalDirection) == "Vector3" then
					local DesiredDirection = (TargetPos - Origin).Unit
					if OriginalDirection.Unit:Dot(DesiredDirection) > 0.1 then
						Args[2] = DesiredDirection * OriginalDirection.Magnitude
						return OldNamecall(self, unpack(Args))
					end
				end
			elseif (Method == "FindPartOnRayWithIgnoreList" or Method == "FindPartOnRayWithWhitelist" or Method == "FindPartOnRay") and typeof(self) == "Instance" and self.ClassName == "Workspace" then
				local RayArg = Args[1]
				if typeof(RayArg) == "Ray" then
					local Origin = RayArg.Origin
					local OriginalDirection = RayArg.Direction
					local DesiredDirection = (TargetPos - Origin).Unit
					if OriginalDirection.Unit:Dot(DesiredDirection) > 0.1 then
						Args[1] = Ray.new(Origin, DesiredDirection * OriginalDirection.Magnitude)
						return OldNamecall(self, unpack(Args))
					end
				end
			end
		end
		return OldNamecall(self, ...)
	end))
	
    local OldIndex
	OldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
		local Env = getgenv().ExunysDeveloperAimbot
		if Env and Env.Settings.Enabled and Env.Settings.SilentAim and Env.TargetPosition and Env.TriggerActive and not checkcaller() then
            -- ИСПРАВЛЕНИЕ: Безопасная проверка на Мышку (обход cloneref)
			if typeof(self) == "Instance" and self:IsA("PlayerMouse") then
				if Index == "Hit" or Index == "hit" then
					return CFrame.new(Env.TargetPosition)
				elseif Index == "Target" or Index == "target" then
					local p = Env.Locked and Env.Locked.Character and Env.Locked.Character:FindFirstChild(Env.Settings.LockPart)
					return p or OldIndex(self, Index)
				end
			end
		end
		return OldIndex(self, Index)
	end))
end
local function Load()
	OriginalSensitivity = UserInputService.MouseDeltaSensitivity
	local Settings = Environment.Settings
	local FOVSettings = Environment.FOVSettings
	local FOVCircle = Environment.FOVCircle
    
	ServiceConnections.RenderSteppedConnection = RunService[Environment.DeveloperSettings.UpdateMode]:Connect(function()
		-- 1. Динамический FOV
		if FOVSettings.Dynamic and LocalPlayer.Character then
			local LocalHumanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			local LocalRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local TargetRadius = FOVSettings.BaseRadius
			if LocalHumanoid and LocalRoot then
				local State = LocalHumanoid:GetState()
				local HorizontalSpeed = Vector3.new(LocalRoot.Velocity.X, 0, LocalRoot.Velocity.Z).Magnitude
				if State == Enum.HumanoidStateType.Freefall or State == Enum.HumanoidStateType.Jumping then
					TargetRadius = FOVSettings.JumpRadius
				elseif HorizontalSpeed > 5 then
					TargetRadius = FOVSettings.RunRadius
				else
					TargetRadius = FOVSettings.BaseRadius
				end
			end
			CurrentDynamicFOV = CurrentDynamicFOV + (TargetRadius - CurrentDynamicFOV) * 0.1
		else
			CurrentDynamicFOV = FOVSettings.BaseRadius
		end
        
		-- 2. FOV Кружок
		if FOVSettings.Enabled and Settings.Enabled then
			FOVCircle.Radius = CurrentDynamicFOV
			FOVCircle.Visible = FOVSettings.Visible
			FOVCircle.NumSides = FOVSettings.NumSides
			FOVCircle.Thickness = FOVSettings.Thickness
			FOVCircle.Filled = FOVSettings.Filled
			FOVCircle.Transparency = FOVSettings.Transparency
			FOVCircle.Color = Environment.Locked and FOVSettings.LockedColor or (FOVSettings.RainbowColor and GetRainbowColor() or FOVSettings.Color)
			FOVCircle.Position = UserInputService:GetMouseLocation()
		else
			FOVCircle.Visible = false
		end
        
		-- 3. Aimbot Logic: Всегда отслеживаем цели
		if Settings.Enabled then
			GetClosestPlayer()
			if Environment.Locked then
				local TargetRoot = Environment.Locked.Character:FindFirstChild("HumanoidRootPart")
				local TargetPart = Environment.Locked.Character:FindFirstChild(Settings.LockPart)
				
				if TargetPart then
					local TargetPosition = TargetPart.Position
					
					-- Предикшн вычисляется ТУТ, один раз для всего!
					if Settings.Prediction and TargetRoot then
						TargetPosition = TargetPosition + (TargetRoot.Velocity * Settings.PredictionAmount)
					end
                    
                    -- КЭШИРУЕМ ДЛЯ СВЕРХБЫСТРОГО SILENT AIM
                    Environment.TargetPosition = TargetPosition
                    
					-- Выполнение CameraAim 
					if Environment.TriggerActive and Settings.CameraAim then
						local LockedViewportPos = Camera:WorldToViewportPoint(TargetPosition)
						if Settings.LockMode == 2 then
							local MousePos = UserInputService:GetMouseLocation()
							if mousemoverel then
								mousemoverel((LockedViewportPos.X - MousePos.X) / Settings.Sensitivity2, (LockedViewportPos.Y - MousePos.Y) / Settings.Sensitivity2)
							end
						else
							if Settings.Sensitivity > 0 then
								Animation = TweenService:Create(Camera, TweenInfo.new(Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)})
								Animation:Play()
							else
								Camera.CFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
							end
							UserInputService.MouseDeltaSensitivity = 0
						end
					else
                        UserInputService.MouseDeltaSensitivity = OriginalSensitivity
						if Animation then Animation:Cancel() end
                    end
				else
                    Environment.TargetPosition = nil
                end
			else
                Environment.TargetPosition = nil
            end
        else
            Environment.TargetPosition = nil
		end
	end)
    
    -- Резерв для Input'ов (если меню не работает или юзер не использует GUI)
	ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed or Typing then return end
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
        if TriggerKey then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
                if Toggle then
                    Environment.TriggerActive = not Environment.TriggerActive
                    if not Environment.TriggerActive then CancelLock() end
                else
                    Environment.TriggerActive = true
                end
            end
        end
	end)
	ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input, GameProcessed)
		if Typing then return end
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
		if TriggerKey and not Toggle and (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey) then
			Environment.TriggerActive = false
			CancelLock()
		end
	end)
end
ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function() Typing = true end)
ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)
function Environment:Exit()
	for _, Connection in pairs(ServiceConnections) do
		if Connection and Connection.Disconnect then Connection:Disconnect() end
	end
	table.clear(ServiceConnections)
	UserInputService.MouseDeltaSensitivity = OriginalSensitivity
	if Animation then Animation:Cancel() end
	if self.FOVCircle then self.FOVCircle:Remove() end
	getgenv().ExunysDeveloperAimbot = nil
end
function Environment:Restart()
	self:Exit()
	Load()
end
Environment.Load = Load
setmetatable(Environment, {__call = Load})
return Environment
