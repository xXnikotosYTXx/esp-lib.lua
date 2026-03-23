--[[
	Universal Aimbot & Silent Aim Module (Premium UI & Hooks)
	- Added Universal Silent Aim (Raycast / Mouse.Hit Hooks)
	- Fixed 'Ugly FOV' - removed jagged outlines, set to perfect 100-side smooth polygon
	- Added passive target locking
]]
local game = game
local workspace = workspace
local Vector2 = Vector2
local Vector3 = Vector3
local CFrame = CFrame
local Color3 = Color3
local Drawing = Drawing
local TweenInfo = TweenInfo
local Enum = Enum
local unpack = unpack or table.unpack
--// Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
--// Cleanup previous instance safely
if getgenv().ExunysDeveloperAimbot then
	pcall(function()
		getgenv().ExunysDeveloperAimbot:Exit()
	end)
end
--// Environment Setup
getgenv().ExunysDeveloperAimbot = {
	Settings = {
		Enabled = true,
		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,
		
		-- Новые настройки Aim
		SilentAim = true, -- Беспалевный изгиб пуль (Raycast / Mouse)
		CameraAim = true, -- Классическая доводка камеры (Mouse / CFrame)
		
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
		
		NumSides = 100, -- Исходно 60, теперь 100: идеальный, сглаженный круг
		Thickness = 1,  -- Отрисовка без лесенок
		Transparency = 0.8,
		Filled = false,
		RainbowColor = false,
		Color = Color3.fromRGB(240, 240, 240),
		LockedColor = Color3.fromRGB(255, 80, 80) -- Приятный красный
	},
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1
	},
	Blacklisted = {},
	FOVCircle = Drawing.new("Circle")
}
local Environment = getgenv().ExunysDeveloperAimbot
local CurrentDynamicFOV = Environment.FOVSettings.BaseRadius
local ServiceConnections = {}
local RequiredDistance = 2000
local Typing, Running = false, false
local Animation = nil
local OriginalSensitivity = UserInputService.MouseDeltaSensitivity
-- Убрал Outline. В Roblox Drawing API две линии создают адские артефакты пикселей.
Environment.FOVCircle.Visible = false
--// Core Functions
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
local function GetRainbowColor()
	local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed
	return Color3.fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
end
local function CancelLock()
	Environment.Locked = nil
	Environment.FOVCircle.Color = Environment.FOVSettings.Color
	UserInputService.MouseDeltaSensitivity = OriginalSensitivity
	if Animation then
		Animation:Cancel()
	end
end
local function GetClosestPlayer()
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart
	if not Environment.Locked then
		RequiredDistance = Environment.FOVSettings.Enabled and CurrentDynamicFOV or 2000
		for _, Player in ipairs(Players:GetPlayers()) do
			if Player == LocalPlayer or table.find(Environment.Blacklisted, Player.Name) then continue end
			
			local Character = Player.Character
			if not Character then continue end
			
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			local TargetPart = Character:FindFirstChild(LockPart)
			
			if Humanoid and TargetPart then
				local TeamCheckOption = Environment.DeveloperSettings.TeamCheckOption
				if Settings.TeamCheck and Player[TeamCheckOption] == LocalPlayer[TeamCheckOption] then
					continue
				end
				if Settings.AliveCheck and Humanoid.Health <= 0 then
					continue
				end
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
		-- Трекинг смещения (осталась ли цель в радиусе)
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
--// Hooks (Universal Silent Aim)
if not getgenv().ExunysHooksLoaded and hookmetamethod then
	getgenv().ExunysHooksLoaded = true
	local OldNamecall
	OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		local Method = getnamecallmethod()
		local Args = {...}
		local Env = getgenv().ExunysDeveloperAimbot
		if Env and Env.Settings.Enabled and Env.Settings.SilentAim and Env.Locked then
			local LockPart = Env.Locked.Character and Env.Locked.Character:FindFirstChild(Env.Settings.LockPart)
			if LockPart then
				local TargetPos = LockPart.Position
				
				if Env.Settings.Prediction and Env.Locked.Character:FindFirstChild("HumanoidRootPart") then
					TargetPos = TargetPos + (Env.Locked.Character.HumanoidRootPart.Velocity * Env.Settings.PredictionAmount)
				end
				-- Подменяем любые лучи стрельбы в мире:
				if Method == "Raycast" and self == workspace then
					local Origin = Args[1]
					Args[2] = (TargetPos - Origin).Unit * (Args[2] and Args[2].Magnitude or 5000)
					return OldNamecall(self, unpack(Args))
				elseif (Method == "FindPartOnRayWithIgnoreList" or Method == "FindPartOnRayWithWhitelist" or Method == "FindPartOnRay") and self == workspace then
					local Origin = Args[1].Origin
					local Direction = (TargetPos - Origin).Unit * Args[1].Direction.Magnitude
					Args[1] = Ray.new(Origin, Direction)
					return OldNamecall(self, unpack(Args))
				end
			end
		end
		return OldNamecall(self, ...)
	end))
	local OldIndex
	OldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
		local Env = getgenv().ExunysDeveloperAimbot
		if Env and Env.Settings.Enabled and Env.Settings.SilentAim and Env.Locked then
			-- Подменяем мышь игрока для стрельбы:
			if self == LocalPlayer:GetMouse() then
				local LockPart = Env.Locked.Character and Env.Locked.Character:FindFirstChild(Env.Settings.LockPart)
				if LockPart then
					local TargetPos = LockPart.Position
					
					if Env.Settings.Prediction and Env.Locked.Character:FindFirstChild("HumanoidRootPart") then
						TargetPos = TargetPos + (Env.Locked.Character.HumanoidRootPart.Velocity * Env.Settings.PredictionAmount)
					end
					if Index == "Hit" or Index == "hit" then
						return CFrame.new(TargetPos)
					elseif Index == "Target" or Index == "target" then
						return LockPart
					end
				end
			end
		end
		return OldIndex(self, Index)
	end))
end
--// Update Loop
local function Load()
	OriginalSensitivity = UserInputService.MouseDeltaSensitivity
	
	local Settings = Environment.Settings
	local FOVSettings = Environment.FOVSettings
	local FOVCircle = Environment.FOVCircle
	ServiceConnections.RenderSteppedConnection = RunService[Environment.DeveloperSettings.UpdateMode]:Connect(function()
		
		-- 1. Считаем Динамический FOV
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
		-- 2. Гладкий премиум рендер FOV
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
		-- 3. Aimbot Logic: Всегда отслеживаем цели, чтобы Silent Aim работал без нажатий (пассивно)
		if Settings.Enabled then
			GetClosestPlayer()
			-- Доводка камеры/мыши (CameraAim) срабатывает только если мы жмем нужную клавишу (Running = true)
			if Environment.Locked and Running and Settings.CameraAim then
				local TargetRoot = Environment.Locked.Character:FindFirstChild("HumanoidRootPart")
				local TargetPart = Environment.Locked.Character:FindFirstChild(Settings.LockPart)
				
				if TargetPart then
					local TargetPosition = TargetPart.Position
					
					if Settings.Prediction and TargetRoot then
						local TargetVelocity = TargetRoot.Velocity
						TargetPosition = TargetPosition + (TargetVelocity * Settings.PredictionAmount)
					end
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
				end
			end
		end
	end)
	ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed or Typing then return end
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
		
		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			if Toggle then
				Running = not Running
				if not Running then CancelLock() end
			else
				Running = true
			end
		end
	end)
	ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input, GameProcessed)
		if Typing then return end
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
		
		if not Toggle and (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey) then
			Running = false
			CancelLock()
		end
	end)
end
ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function() Typing = true end)
ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)
--// Exported Functions / Module API
function Environment:Exit()
	for _, Connection in pairs(ServiceConnections) do
		if Connection and Connection.Disconnect then
			Connection:Disconnect()
		end
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
function Environment:Blacklist(Username)
	assert(Username, "Aimbot Module: Missing parameter 'Username'.")
	Username = FixUsername(Username)
	assert(Username, "Aimbot Module: User couldn't be found.")
	table.insert(self.Blacklisted, Username)
end
function Environment:Whitelist(Username)
	assert(Username, "Aimbot Module: Missing parameter 'Username'.")
	Username = FixUsername(Username)
	assert(Username, "Aimbot Module: User couldn't be found.")
	local Index = table.find(self.Blacklisted, Username)
	assert(Index, "Aimbot Module: User " .. Username .. " is not blacklisted.")
	table.remove(self.Blacklisted, Index)
end
function Environment.GetClosestPlayer()
	GetClosestPlayer()
	local Value = Environment.Locked
	CancelLock()
	return Value
end
Environment.Load = Load
setmetatable(Environment, {__call = Load})
return Environment
