--// ZerkaSense 2.0
--// WindUI-based build
--// Tabs: Main / Visuals / Settings / Config
--// StarterPlayer > StarterPlayerScripts > LocalScript
--// All visuals are local-only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--====================================================
-- WINDUI
--====================================================

local function loadWindUI()
	local studioOk, studioLibrary = pcall(function()
		if RunService:IsStudio() then
			return require(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Init"))
		end
	end)

	if studioOk and studioLibrary then
		return studioLibrary
	end

	local webOk, webLibrary = pcall(function()
		return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
	end)

	if webOk and webLibrary then
		return webLibrary
	end

	error("[ZerkaSense] WindUI was not found. Place WindUI in ReplicatedStorage > WindUI > Init.")
end

local WindUI = loadWindUI()

--====================================================
-- HELPERS
--====================================================

local Window
local IsApplyingState = false

local applyState
local applyWorldChanger
local restoreWorld
local restorePersona
local setBhopEnabled
local setZetLockEnabled
local clearZetLockTarget
local updateAllESP
local clearAllESP
local updateMenuEffects
local updateTargetHubStyle

local function safeCall(object, methodName, ...)
	if not object then
		return false, nil
	end

	local method = object[methodName]

	if type(method) ~= "function" then
		return false, nil
	end

	local args = { ... }

	return pcall(function()
		return method(object, table.unpack(args))
	end)
end

local function notify(title, content, icon, duration)
	local ok = pcall(function()
		WindUI:Notify({
			Title = title,
			Content = content,
			Icon = icon or "info",
			Duration = duration or 3,
		})
	end)

	if not ok then
		warn("[ZerkaSense] " .. tostring(title) .. ": " .. tostring(content))
	end
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end

	return copy
end

local function trim(text)
	text = tostring(text or "")
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")
	return text
end

local function clampNumber(value, minValue, maxValue, fallback)
	if type(value) ~= "number" then
		return fallback
	end

	return math.clamp(value, minValue, maxValue)
end

local function toNumber(value, fallback)
	local number = tonumber(value)

	if number == nil then
		return fallback
	end

	return number
end

local function sanitizeName(name, fallback, maxLength)
	name = trim(name)
	name = name:gsub("[^%w%s%-%_%.]", "")

	if name == "" then
		name = fallback or "Default"
	end

	maxLength = maxLength or 28

	if #name > maxLength then
		name = name:sub(1, maxLength)
	end

	return name
end

local function copyToClipboard(text)
	if type(setclipboard) == "function" then
		local ok = pcall(function()
			setclipboard(text)
		end)

		return ok
	end

	return false
end

local function urlEncode(text)
	local ok, result = pcall(function()
		return HttpService:UrlEncode(text)
	end)

	if ok and result then
		return result
	end

	return text
end

local function urlDecode(text)
	text = tostring(text or "")
	text = text:gsub("+", " ")
	text = text:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)

	return text
end

local function countKeys(tbl)
	local count = 0

	if type(tbl) ~= "table" then
		return 0
	end

	for _ in pairs(tbl) do
		count += 1
	end

	return count
end

local function safeGetProperty(instance, property)
	local ok, value = pcall(function()
		return instance[property]
	end)

	if ok then
		return true, value
	end

	return false, nil
end

local function hexToColor3(hex)
	hex = tostring(hex or "#FFFFFF"):gsub("#", "")

	if #hex ~= 6 then
		return Color3.fromRGB(255, 255, 255)
	end

	local r = tonumber(hex:sub(1, 2), 16) or 255
	local g = tonumber(hex:sub(3, 4), 16) or 255
	local b = tonumber(hex:sub(5, 6), 16) or 255

	return Color3.fromRGB(r, g, b)
end

local function isHexColor(value)
	return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

local function lerpNumber(a, b, alpha)
	return a + (b - a) * alpha
end

local function lerpColor(a, b, alpha)
	return Color3.new(
		lerpNumber(a.R, b.R, alpha),
		lerpNumber(a.G, b.G, alpha),
		lerpNumber(a.B, b.B, alpha)
	)
end

local function getCamera()
	return Workspace.CurrentCamera
end

local function getCharacter(plr)
	return plr and plr.Character
end

local function getHumanoid(plr)
	local character = getCharacter(plr)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(plr)
	local character = getCharacter(plr)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHead(plr)
	local character = getCharacter(plr)
	return character and character:FindFirstChild("Head")
end

local function isAlive(plr)
	local humanoid = getHumanoid(plr)
	return humanoid and humanoid.Health > 0
end

local function isTeammate(target)
	return player.Team ~= nil and target.Team ~= nil and player.Team == target.Team
end

local function isInList(value, list)
	for _, item in ipairs(list) do
		if value == item then
			return true
		end
	end

	return false
end

--====================================================
-- USER STATUS
--====================================================

local DEVELOPER_USERNAMES = {
	["zerkacorp"] = true,
	["zerka_corp"] = true,
	["zerka-corp"] = true,
	["zetkacorp"] = true,
	["zetka_corp"] = true,
	["zetka-corp"] = true,
}

local DEVELOPER_USER_IDS = {
	-- [123456789] = true,
}

local STATUS_STYLE = {
	Base = {
		Color = Color3.fromRGB(145, 150, 165),
		Desc = "Standard ZerkaSense access.",
	},
	Developer = {
		Color = Color3.fromRGB(255, 40, 90),
		Desc = "ZerkaSense developer access.",
	},
}

local function normalizeUsername(username)
	username = tostring(username or ""):lower()
	username = username:gsub("%s+", "")
	return username
end

local function getPlayerStatus(plr)
	if DEVELOPER_USER_IDS[plr.UserId] then
		return "Developer"
	end

	local username = normalizeUsername(plr.Name)
	local compactUsername = username:gsub("[^%w]", "")

	if DEVELOPER_USERNAMES[username] or DEVELOPER_USERNAMES[compactUsername] then
		return "Developer"
	end

	if compactUsername:find("zerka", 1, true) and compactUsername:find("corp", 1, true) then
		return "Developer"
	end

	if compactUsername:find("zetka", 1, true) and compactUsername:find("corp", 1, true) then
		return "Developer"
	end

	return "Base"
end

local PlayerStatus = getPlayerStatus(player)
local PlayerStatusStyle = STATUS_STYLE[PlayerStatus] or STATUS_STYLE.Base

local avatarImage = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=420&h=420"

pcall(function()
	local image = Players:GetUserThumbnailAsync(
		player.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size420x420
	)

	if image then
		avatarImage = image
	end
end)

--====================================================
-- STATE
--====================================================

local DEFAULT_STATE = {
	Theme = "Dark",
	Transparency = 0.12,
	UIScale = 0.65,

	MenuBlur = true,
	MenuSnow = true,
	MenuAccentA = "#FF214F",
	MenuAccentB = "#8A2BFF",
	MenuAccentC = "#00D2FF",

	TargetHubScale = 1,
	TargetHubTransparency = 0.08,
	TargetHubAccentA = "#FF214F",
	TargetHubAccentB = "#8A2BFF",
	TargetHubAccentC = "#00D2FF",

	BhopEnabled = false,
	BhopMaxSpeed = 105,
	BhopStartSpeed = 24,
	BhopMoveAccel = 115,
	BhopCameraTurnAccel = 135,
	BhopAirControl = 0.55,
	BhopGroundBoost = 16,
	BhopSpeedGrowth = 78,
	BhopAntiVelocityBrake = true,
	BhopBrakeStrength = 0.72,
	BhopBrakeTime = 0.22,
	BhopAutoStrafe = true,
	BhopAutoStrafeStrength = 0.85,

	ZetLockEnabled = false,
	ZetLockPart = "Body",
	ZetLockMode = "Pro",
	ZetLockFOV = 160,
	ZetLockShowFOV = true,
	ZetLockFOVColor = "#FF214F",
	ZetLockPredict = true,
	ZetLockPredictAmount = 0.12,
	ZetLockWallCheck = true,
	ZetLockTeamCheck = false,
	ZetLockPriority = true,
	ZetLockResolutionMode = true,
	ZetLockNoises = false,
	ZetLockNoiseStrength = 0.08,
	ZetLockNoiseSpeed = 8,

	ESPEnabled = false,
	ESPWallCheck = false,
	ESPTeamCheck = false,
	ESPMaxDistance = 2500,

	ESPHitbox = true,
	ESPFill = false,
	ESPDamageTick = true,
	ESPDamageFlashTime = 0.85,
	ESPLookDirection = true,
	ESPName = true,
	ESPHealthNumbers = true,
	ESPHealthBar = true,

	ESPBoxColor = "#FFFFFF",
	ESPFillColor = "#FF214F",
	ESPDamageColor = "#FF214F",
	ESPLookColor = "#00D2FF",
	ESPNameColor = "#FFFFFF",
	ESPHealthColor = "#4DFF8F",
	ESPTeamColor = "#00D2FF",

	ESPLineThickness = 0.035,
	ESPFillTransparency = 0.88,
	ESPBoxTransparency = 0,
	ESPLookLength = 4.4,
	ESPLookThickness = 0.095,

	FOVChangerEnabled = false,
	CameraFOV = 80,

	BetterSmoothEnabled = false,
	BetterSmoothPreset = "Soft",
	NaturalBlur = true,
	NaturalBlurStrength = 10,
	NaturalBlurDecay = 14,

	PersonaGlow = false,
	PersonaGlowColor = "#FF214F",
	PersonaGlowFillTransparency = 0.55,
	PersonaMaterialEnabled = false,
	PersonaMaterial = "Neon",
	PersonaBodyColor = "#FF214F",
	PersonaToolColor = "#00D2FF",

	WorldChangerEnabled = false,
	WorldSkyMode = "Default",
	WorldSkyboxId = "",
	WorldTime = "Day",
	WorldAmbient = "#7A7A8A",
	WorldOutdoorAmbient = "#A0A0B8",
	WorldLightColor = "#FFFFFF",
	WorldFogEnabled = false,
	WorldFogColor = "#B8C8FF",
	WorldFogStart = 40,
	WorldFogEnd = 600,
	WorldTintEnabled = false,
	WorldTintColor = "#FFFFFF",
	WorldTintSaturation = 0,
	WorldTintContrast = 0,
	WorldParticles = false,
	WorldParticlesColorA = "#FF214F",
	WorldParticlesColorB = "#00D2FF",
	WorldWeather = "Off",
}

local State = deepCopy(DEFAULT_STATE)
local Controls = {}

local ZETLOCK_PART_OPTIONS = { "Body", "Head" }
local ZETLOCK_MODE_OPTIONS = { "Smooth", "Pro", "Rage" }
local SMOOTH_PRESETS = { "Soft", "Cinematic", "Ultra" }
local MATERIAL_OPTIONS = { "Neon", "ForceField", "Glass", "SmoothPlastic" }
local WORLD_SKY_OPTIONS = { "Default", "No Sky", "Custom" }
local WORLD_TIME_OPTIONS = { "Day", "Night" }
local WORLD_WEATHER_OPTIONS = { "Off", "Rain", "Snow" }

--====================================================
-- THEME LIST
--====================================================

local function getThemes()
	local themes = {}

	local ok, result = pcall(function()
		return WindUI:GetThemes()
	end)

	if ok and type(result) == "table" then
		for themeName in pairs(result) do
			table.insert(themes, themeName)
		end
	end

	if #themes == 0 then
		themes = {
			"Dark",
			"Violet",
			"Indigo",
			"Sky",
			"Rose",
			"Plant",
			"Amber",
			"Light",
		}
	end

	table.sort(themes)

	return themes
end

local ThemeOptions = getThemes()

local function themeExists(themeName)
	for _, theme in ipairs(ThemeOptions) do
		if theme == themeName then
			return true
		end
	end

	return false
end

--====================================================
-- VALIDATION
--====================================================

local function validateState(raw)
	local clean = deepCopy(DEFAULT_STATE)

	if type(raw) ~= "table" then
		return clean
	end

	if type(raw.Theme) == "string" and themeExists(raw.Theme) then
		clean.Theme = raw.Theme
	end

	if type(raw.ZetLockPart) == "string" and isInList(raw.ZetLockPart, ZETLOCK_PART_OPTIONS) then
		clean.ZetLockPart = raw.ZetLockPart
	end

	if type(raw.ZetLockMode) == "string" and isInList(raw.ZetLockMode, ZETLOCK_MODE_OPTIONS) then
		clean.ZetLockMode = raw.ZetLockMode
	end

	if type(raw.BetterSmoothPreset) == "string" and isInList(raw.BetterSmoothPreset, SMOOTH_PRESETS) then
		clean.BetterSmoothPreset = raw.BetterSmoothPreset
	end

	if type(raw.PersonaMaterial) == "string" and isInList(raw.PersonaMaterial, MATERIAL_OPTIONS) then
		clean.PersonaMaterial = raw.PersonaMaterial
	end

	if type(raw.WorldSkyMode) == "string" and isInList(raw.WorldSkyMode, WORLD_SKY_OPTIONS) then
		clean.WorldSkyMode = raw.WorldSkyMode
	end

	if type(raw.WorldTime) == "string" and isInList(raw.WorldTime, WORLD_TIME_OPTIONS) then
		clean.WorldTime = raw.WorldTime
	end

	if type(raw.WorldWeather) == "string" and isInList(raw.WorldWeather, WORLD_WEATHER_OPTIONS) then
		clean.WorldWeather = raw.WorldWeather
	end

	if type(raw.WorldSkyboxId) == "string" then
		clean.WorldSkyboxId = raw.WorldSkyboxId:gsub("[^%d]", "")
	end

	local boolKeys = {
		"MenuBlur",
		"MenuSnow",

		"BhopEnabled",
		"BhopAntiVelocityBrake",
		"BhopAutoStrafe",

		"ZetLockEnabled",
		"ZetLockShowFOV",
		"ZetLockPredict",
		"ZetLockWallCheck",
		"ZetLockTeamCheck",
		"ZetLockPriority",
		"ZetLockResolutionMode",
		"ZetLockNoises",

		"ESPEnabled",
		"ESPWallCheck",
		"ESPTeamCheck",
		"ESPHitbox",
		"ESPFill",
		"ESPDamageTick",
		"ESPLookDirection",
		"ESPName",
		"ESPHealthNumbers",
		"ESPHealthBar",

		"FOVChangerEnabled",

		"BetterSmoothEnabled",
		"NaturalBlur",

		"PersonaGlow",
		"PersonaMaterialEnabled",

		"WorldChangerEnabled",
		"WorldFogEnabled",
		"WorldTintEnabled",
		"WorldParticles",
	}

	for _, key in ipairs(boolKeys) do
		if type(raw[key]) == "boolean" then
			clean[key] = raw[key]
		end
	end

	local numberKeys = {
		Transparency = { 0, 0.75 },
		UIScale = { 0.50, 1.25 },

		TargetHubScale = { 0.70, 1.50 },
		TargetHubTransparency = { 0, 0.75 },

		BhopMaxSpeed = { 40, 180 },
		BhopStartSpeed = { 16, 80 },
		BhopMoveAccel = { 20, 260 },
		BhopCameraTurnAccel = { 20, 280 },
		BhopAirControl = { 0.1, 1.2 },
		BhopGroundBoost = { 0, 45 },
		BhopSpeedGrowth = { 10, 180 },
		BhopBrakeStrength = { 0.05, 0.95 },
		BhopBrakeTime = { 0.05, 0.8 },
		BhopAutoStrafeStrength = { 0, 2 },

		ZetLockFOV = { 30, 600 },
		ZetLockPredictAmount = { 0, 0.6 },
		ZetLockNoiseStrength = { 0, 0.6 },
		ZetLockNoiseSpeed = { 1, 30 },

		ESPMaxDistance = { 100, 5000 },
		ESPDamageFlashTime = { 0.1, 3 },
		ESPLineThickness = { 0.005, 0.20 },
		ESPFillTransparency = { 0, 1 },
		ESPBoxTransparency = { 0, 1 },
		ESPLookLength = { 0.5, 10 },
		ESPLookThickness = { 0.01, 0.35 },

		CameraFOV = { 60, 120 },

		NaturalBlurStrength = { 0, 30 },
		NaturalBlurDecay = { 4, 30 },

		PersonaGlowFillTransparency = { 0, 1 },

		WorldFogStart = { 0, 1000 },
		WorldFogEnd = { 20, 5000 },
		WorldTintSaturation = { -1, 1 },
		WorldTintContrast = { -1, 1 },
	}

	for key, range in pairs(numberKeys) do
		clean[key] = clampNumber(raw[key], range[1], range[2], clean[key])
	end

	local colorKeys = {
		"MenuAccentA",
		"MenuAccentB",
		"MenuAccentC",

		"TargetHubAccentA",
		"TargetHubAccentB",
		"TargetHubAccentC",

		"ZetLockFOVColor",

		"ESPBoxColor",
		"ESPFillColor",
		"ESPDamageColor",
		"ESPLookColor",
		"ESPNameColor",
		"ESPHealthColor",
		"ESPTeamColor",

		"PersonaGlowColor",
		"PersonaBodyColor",
		"PersonaToolColor",

		"WorldAmbient",
		"WorldOutdoorAmbient",
		"WorldLightColor",
		"WorldFogColor",
		"WorldTintColor",
		"WorldParticlesColorA",
		"WorldParticlesColorB",
	}

	for _, key in ipairs(colorKeys) do
		if isHexColor(raw[key]) then
			clean[key] = raw[key]
		end
	end

	return clean
end

local function setControlValue(key, value)
	local control = Controls[key]

	if not control then
		return
	end

	safeCall(control, "Set", value)
	safeCall(control, "Select", value)
end

--====================================================
-- MENU EFFECTS OVERLAY
--====================================================

local EffectsGui = Instance.new("ScreenGui")
EffectsGui.Name = "ZerkaSenseMenuEffects"
EffectsGui.ResetOnSpawn = false
EffectsGui.IgnoreGuiInset = true
EffectsGui.DisplayOrder = 99997
EffectsGui.Parent = playerGui

local SnowLayer = Instance.new("Frame")
SnowLayer.Name = "SnowLayer"
SnowLayer.Size = UDim2.fromScale(1, 1)
SnowLayer.BackgroundTransparency = 1
SnowLayer.Visible = true
SnowLayer.Parent = EffectsGui

local MenuBlur = Lighting:FindFirstChild("ZerkaSense_MenuBlur")

if not MenuBlur then
	MenuBlur = Instance.new("BlurEffect")
	MenuBlur.Name = "ZerkaSense_MenuBlur"
	MenuBlur.Size = 0
	MenuBlur.Enabled = true
	MenuBlur.Parent = Lighting
end

local NaturalBlurEffect = Lighting:FindFirstChild("ZerkaSense_NaturalBlur")

if not NaturalBlurEffect then
	NaturalBlurEffect = Instance.new("BlurEffect")
	NaturalBlurEffect.Name = "ZerkaSense_NaturalBlur"
	NaturalBlurEffect.Size = 0
	NaturalBlurEffect.Enabled = true
	NaturalBlurEffect.Parent = Lighting
end

local Snowflakes = {}

for i = 1, 85 do
	local flake = Instance.new("TextLabel")
	flake.Name = "Snow"
	flake.Size = UDim2.fromOffset(math.random(3, 8), math.random(3, 8))
	flake.Position = UDim2.fromScale(math.random(), math.random())
	flake.BackgroundTransparency = 1
	flake.Text = math.random(1, 4) == 1 and "✦" or "•"
	flake.TextColor3 = Color3.fromRGB(255, 255, 255)
	flake.TextTransparency = math.random(15, 55) / 100
	flake.TextSize = math.random(9, 18)
	flake.Font = Enum.Font.GothamBold
	flake.Visible = true
	flake.Parent = SnowLayer

	table.insert(Snowflakes, {
		Object = flake,
		X = math.random(),
		Y = math.random(),
		Speed = math.random(18, 70) / 10000,
		Drift = math.random(-25, 25) / 10000,
	})
end

local MenuEffectsActive = true

updateMenuEffects = function()
	SnowLayer.Visible = MenuEffectsActive and State.MenuSnow

	local targetBlur = MenuEffectsActive and State.MenuBlur and 18 or 0

	TweenService:Create(
		MenuBlur,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = targetBlur }
	):Play()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.RightShift then
		MenuEffectsActive = not MenuEffectsActive
		updateMenuEffects()
	end
end)

RunService.RenderStepped:Connect(function()
	if not SnowLayer.Visible then
		return
	end

	for _, flake in ipairs(Snowflakes) do
		flake.Y += flake.Speed
		flake.X += flake.Drift

		if flake.Y > 1.05 then
			flake.Y = -0.05
			flake.X = math.random()
		end

		if flake.X < -0.05 then
			flake.X = 1.05
		elseif flake.X > 1.05 then
			flake.X = -0.05
		end

		flake.Object.Position = UDim2.fromScale(flake.X, flake.Y)
	end
end)

--====================================================
-- ANIMATED GRADIENTS
--====================================================

local AnimatedGradients = {}

local function rageGradient()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, hexToColor3(State.MenuAccentA)),
		ColorSequenceKeypoint.new(0.32, hexToColor3(State.MenuAccentB)),
		ColorSequenceKeypoint.new(0.66, hexToColor3(State.MenuAccentC)),
		ColorSequenceKeypoint.new(1.00, hexToColor3(State.MenuAccentA)),
	})
end

local function targetGradient()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, hexToColor3(State.TargetHubAccentA)),
		ColorSequenceKeypoint.new(0.45, hexToColor3(State.TargetHubAccentB)),
		ColorSequenceKeypoint.new(0.78, hexToColor3(State.TargetHubAccentC)),
		ColorSequenceKeypoint.new(1.00, hexToColor3(State.TargetHubAccentA)),
	})
end

local function registerGradient(gradient, mode, speed, wave)
	if not gradient then
		return
	end

	table.insert(AnimatedGradients, {
		Gradient = gradient,
		Mode = mode or "menu",
		Speed = speed or 35,
		Wave = wave or 0.18,
	})
end

local function refreshGradients()
	for _, entry in ipairs(AnimatedGradients) do
		local gradient = entry.Gradient

		if gradient and gradient.Parent then
			if entry.Mode == "target" then
				gradient.Color = targetGradient()
			else
				gradient.Color = rageGradient()
			end
		end
	end
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()

	for i = #AnimatedGradients, 1, -1 do
		local entry = AnimatedGradients[i]
		local gradient = entry and entry.Gradient

		if not gradient or not gradient.Parent then
			table.remove(AnimatedGradients, i)
		else
			gradient.Rotation = (t * entry.Speed) % 360
			gradient.Offset = Vector2.new(math.sin(t * 1.2) * entry.Wave, 0)
		end
	end
end)

--====================================================
-- MOBILE BHOP
--====================================================

local BHOP_ACTION_NAME = "ZerkaSenseMobileBhop"
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local BHOP_BASE_WALK_SPEED = 16
local BHOP_JUMP_COOLDOWN = 0.055
local BHOP_GROUND_FRICTION = 0.90
local BHOP_SPEED_DECAY = 12
local BHOP_MIN_CAMERA_DELTA = 0.0025
local BHOP_MAX_CAMERA_DELTA = 0.075
local BHOP_CAMERA_DELTA_MULTIPLIER = 95
local BHOP_SHIFTLOCK_CAMERA_OFFSET = Vector3.new(1.45, 0.25, 0)

local bhopCharacter
local bhopHumanoid
local bhopRootPart

local bhopJumpHeld = false
local bhopShiftLockActive = false
local bhopLastJumpTime = 0
local bhopCurrentSpeedLimit = DEFAULT_STATE.BhopStartSpeed
local bhopLastCameraYaw = 0
local bhopBrakeUntil = 0

local bhopOldAutoRotate = nil
local bhopOldCameraOffset = nil

local function bhopGetYawFromCamera()
	local camera = getCamera()

	if not camera then
		return 0
	end

	local look = camera.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function bhopGetFlatCameraLook()
	local camera = getCamera()

	if not camera then
		return Vector3.zero
	end

	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)

	if flat.Magnitude <= 0 then
		return Vector3.zero
	end

	return flat.Unit
end

local function bhopGetFlatCameraRight()
	local camera = getCamera()

	if not camera then
		return Vector3.zero
	end

	local right = camera.CFrame.RightVector
	local flat = Vector3.new(right.X, 0, right.Z)

	if flat.Magnitude <= 0 then
		return Vector3.zero
	end

	return flat.Unit
end

local function bhopGetHorizontalVelocity()
	if not bhopRootPart then
		return Vector3.zero
	end

	local velocity = bhopRootPart.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z)
end

local function bhopSetHorizontalVelocity(horizontalVelocity)
	if not bhopRootPart then
		return
	end

	local current = bhopRootPart.AssemblyLinearVelocity

	bhopRootPart.AssemblyLinearVelocity = Vector3.new(
		horizontalVelocity.X,
		current.Y,
		horizontalVelocity.Z
	)
end

local function bhopLimitVelocity(velocity, maxSpeed)
	local speed = velocity.Magnitude

	if speed > maxSpeed then
		return velocity.Unit * maxSpeed
	end

	return velocity
end

local function bhopIsGrounded()
	if not bhopHumanoid then
		return false
	end

	return bhopHumanoid.FloorMaterial ~= Enum.Material.Air
end

local function bhopGetWishDirection()
	if not bhopHumanoid then
		return Vector3.zero
	end

	local direction = bhopHumanoid.MoveDirection
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)

	if flatDirection.Magnitude > 0.05 then
		return flatDirection.Unit
	end

	if bhopJumpHeld then
		return bhopGetFlatCameraLook()
	end

	return Vector3.zero
end

local function bhopEnableShiftLock()
	if bhopShiftLockActive then
		return
	end

	bhopShiftLockActive = true

	if bhopHumanoid then
		bhopOldAutoRotate = bhopHumanoid.AutoRotate
		bhopOldCameraOffset = bhopHumanoid.CameraOffset

		bhopHumanoid.AutoRotate = false
		bhopHumanoid.CameraOffset = BHOP_SHIFTLOCK_CAMERA_OFFSET
	end
end

local function bhopDisableShiftLock()
	if not bhopShiftLockActive then
		return
	end

	bhopShiftLockActive = false

	if bhopHumanoid then
		if bhopOldAutoRotate ~= nil then
			bhopHumanoid.AutoRotate = bhopOldAutoRotate
		else
			bhopHumanoid.AutoRotate = true
		end

		if bhopOldCameraOffset then
			bhopHumanoid.CameraOffset = bhopOldCameraOffset
		else
			bhopHumanoid.CameraOffset = Vector3.zero
		end
	end
end

local function bhopUpdateShiftLockRotation()
	if not bhopShiftLockActive then
		return
	end

	if not bhopRootPart then
		return
	end

	local lookDirection = bhopGetFlatCameraLook()

	if lookDirection.Magnitude <= 0 then
		return
	end

	local position = bhopRootPart.Position
	bhopRootPart.CFrame = CFrame.lookAt(position, position + lookDirection)
end

local function bhopApplyGroundBoost()
	local wishDirection = bhopGetWishDirection()

	if wishDirection.Magnitude <= 0 then
		return
	end

	local horizontalVelocity = bhopGetHorizontalVelocity()
	local boostedVelocity = horizontalVelocity + wishDirection * State.BhopGroundBoost

	boostedVelocity = bhopLimitVelocity(boostedVelocity, State.BhopMaxSpeed)
	bhopSetHorizontalVelocity(boostedVelocity)
end

local function bhopForceJump()
	if not bhopHumanoid then
		return
	end

	if os.clock() - bhopLastJumpTime < BHOP_JUMP_COOLDOWN then
		return
	end

	bhopLastJumpTime = os.clock()

	if bhopIsGrounded() then
		bhopApplyGroundBoost()
	end

	bhopHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function bhopStartBrake()
	if State.BhopAntiVelocityBrake then
		bhopBrakeUntil = os.clock() + State.BhopBrakeTime
	end
end

local function bhopHandleAction(_, inputState)
	if not State.BhopEnabled then
		bhopJumpHeld = false
		bhopDisableShiftLock()
		return Enum.ContextActionResult.Sink
	end

	if inputState == Enum.UserInputState.Begin then
		bhopJumpHeld = true
		bhopBrakeUntil = 0
		bhopEnableShiftLock()
		bhopForceJump()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		bhopJumpHeld = false
		bhopDisableShiftLock()
		bhopStartBrake()
	end

	return Enum.ContextActionResult.Sink
end

local function bhopStyleButton()
	if not IS_MOBILE then
		return
	end

	task.defer(function()
		local button = ContextActionService:GetButton(BHOP_ACTION_NAME)

		if not button then
			return
		end

		button.Size = UDim2.new(0, 74, 0, 74)
		button.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
		button.BackgroundTransparency = 0.04
		button.ImageTransparency = 0.22
		button.AutoButtonColor = true

		if not button:FindFirstChild("ZerkaBhopCorner") then
			local corner = Instance.new("UICorner")
			corner.Name = "ZerkaBhopCorner"
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = button
		end

		if not button:FindFirstChild("ZerkaBhopStroke") then
			local stroke = Instance.new("UIStroke")
			stroke.Name = "ZerkaBhopStroke"
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Transparency = 0.45
			stroke.Thickness = 1.6
			stroke.Parent = button
		end

		local label = button:FindFirstChildWhichIsA("TextLabel")

		if label then
			label.Text = "BHOP"
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextSize = 14
			label.Font = Enum.Font.GothamBold
		end
	end)
end

local function bhopBindButton()
	ContextActionService:UnbindAction(BHOP_ACTION_NAME)

	if not IS_MOBILE then
		return
	end

	ContextActionService:BindAction(
		BHOP_ACTION_NAME,
		bhopHandleAction,
		true,
		Enum.KeyCode.Space
	)

	ContextActionService:SetTitle(BHOP_ACTION_NAME, "BHOP")
	ContextActionService:SetPosition(BHOP_ACTION_NAME, UDim2.new(1, -92, 1, -170))
	bhopStyleButton()
end

local function bhopUnbindButton()
	bhopJumpHeld = false
	bhopDisableShiftLock()
	bhopStartBrake()
	ContextActionService:UnbindAction(BHOP_ACTION_NAME)
end

setBhopEnabled = function(enabled, silent)
	State.BhopEnabled = enabled == true

	if State.BhopEnabled then
		if not IS_MOBILE then
			if not silent then
				notify("BHOP", "Mobile-only BHOP. Use phone controls.", "smartphone", 3)
			end

			State.BhopEnabled = false
			return
		end

		bhopBindButton()

		if not silent then
			notify("BHOP", "Mobile BHOP enabled.", "rabbit", 3)
		end
	else
		bhopUnbindButton()
		bhopCurrentSpeedLimit = State.BhopStartSpeed

		if not silent then
			notify("BHOP", "Mobile BHOP disabled.", "x", 2)
		end
	end
end

local function bhopSetupCharacter(newCharacter)
	bhopCharacter = newCharacter
	bhopHumanoid = bhopCharacter:WaitForChild("Humanoid")
	bhopRootPart = bhopCharacter:WaitForChild("HumanoidRootPart")

	bhopHumanoid.WalkSpeed = BHOP_BASE_WALK_SPEED
	bhopHumanoid.AutoJumpEnabled = false

	bhopCurrentSpeedLimit = State.BhopStartSpeed
	bhopLastCameraYaw = bhopGetYawFromCamera()

	bhopDisableShiftLock()
end

if player.Character then
	bhopSetupCharacter(player.Character)
end

player.CharacterAdded:Connect(bhopSetupCharacter)

RunService.RenderStepped:Connect(function(deltaTime)
	if not IS_MOBILE then
		return
	end

	if not bhopCharacter or not bhopHumanoid or not bhopRootPart then
		return
	end

	if bhopHumanoid.Health <= 0 then
		return
	end

	if not State.BhopEnabled then
		if State.BhopAntiVelocityBrake and os.clock() < bhopBrakeUntil then
			local horizontalVelocity = bhopGetHorizontalVelocity()

			if horizontalVelocity.Magnitude > BHOP_BASE_WALK_SPEED then
				local alpha = math.clamp(State.BhopBrakeStrength * deltaTime * 22, 0, 1)
				local target = horizontalVelocity.Unit * BHOP_BASE_WALK_SPEED
				bhopSetHorizontalVelocity(horizontalVelocity:Lerp(target, alpha))
			end
		end

		return
	end

	bhopUpdateShiftLockRotation()

	local grounded = bhopIsGrounded()
	local horizontalVelocity = bhopGetHorizontalVelocity()
	local horizontalSpeed = horizontalVelocity.Magnitude

	local currentYaw = bhopGetYawFromCamera()
	local cameraDelta = currentYaw - bhopLastCameraYaw

	if cameraDelta > math.pi then
		cameraDelta -= math.pi * 2
	elseif cameraDelta < -math.pi then
		cameraDelta += math.pi * 2
	end

	bhopLastCameraYaw = currentYaw

	if grounded then
		if horizontalSpeed > bhopCurrentSpeedLimit then
			bhopCurrentSpeedLimit = math.min(horizontalSpeed, State.BhopMaxSpeed)
		else
			bhopCurrentSpeedLimit = math.max(State.BhopStartSpeed, bhopCurrentSpeedLimit - BHOP_SPEED_DECAY * deltaTime)
		end

		if bhopJumpHeld then
			bhopForceJump()
		else
			if horizontalSpeed > BHOP_BASE_WALK_SPEED then
				bhopSetHorizontalVelocity(horizontalVelocity * BHOP_GROUND_FRICTION)
			end
		end

		return
	end

	if bhopJumpHeld then
		bhopCurrentSpeedLimit = math.min(
			bhopCurrentSpeedLimit + State.BhopSpeedGrowth * deltaTime,
			State.BhopMaxSpeed
		)
	else
		bhopCurrentSpeedLimit = math.max(
			bhopCurrentSpeedLimit - BHOP_SPEED_DECAY * deltaTime,
			State.BhopStartSpeed
		)
	end

	local wishDirection = bhopGetWishDirection()

	if wishDirection.Magnitude > 0 then
		local acceleratedVelocity = horizontalVelocity + wishDirection * State.BhopMoveAccel * deltaTime
		acceleratedVelocity = bhopLimitVelocity(acceleratedVelocity, bhopCurrentSpeedLimit)

		local targetVelocity = wishDirection * math.max(acceleratedVelocity.Magnitude, State.BhopStartSpeed)
		local airAlpha = math.clamp(State.BhopAirControl * deltaTime * 8, 0, 1)

		local blendedVelocity = acceleratedVelocity:Lerp(targetVelocity, airAlpha)
		blendedVelocity = bhopLimitVelocity(blendedVelocity, bhopCurrentSpeedLimit)

		bhopSetHorizontalVelocity(blendedVelocity)
	end

	if bhopJumpHeld and math.abs(cameraDelta) > BHOP_MIN_CAMERA_DELTA then
		local cameraRight = bhopGetFlatCameraRight()

		if cameraRight.Magnitude > 0 then
			local clampedDelta = math.clamp(cameraDelta, -BHOP_MAX_CAMERA_DELTA, BHOP_MAX_CAMERA_DELTA)
			local turnPower = math.clamp(math.abs(clampedDelta) * BHOP_CAMERA_DELTA_MULTIPLIER, 0, 1)

			local directionSign = clampedDelta > 0 and 1 or -1
			local cameraBoost = cameraRight * directionSign * State.BhopCameraTurnAccel * turnPower * deltaTime

			local boostedVelocity = bhopGetHorizontalVelocity() + cameraBoost
			boostedVelocity = bhopLimitVelocity(boostedVelocity, bhopCurrentSpeedLimit)

			bhopSetHorizontalVelocity(boostedVelocity)
		end
	end

	if State.BhopAutoStrafe and bhopJumpHeld then
		local right = bhopGetFlatCameraRight()

		if right.Magnitude > 0 then
			local sign = math.sin(os.clock() * 9) >= 0 and 1 or -1
			local strafeVelocity = bhopGetHorizontalVelocity() + right * sign * State.BhopAutoStrafeStrength * State.BhopCameraTurnAccel * 0.22 * deltaTime
			strafeVelocity = bhopLimitVelocity(strafeVelocity, bhopCurrentSpeedLimit)
			bhopSetHorizontalVelocity(strafeVelocity)
		end
	end
end)

--====================================================
-- ZETLOCK UI + ENGINE
--====================================================

local ZetLockGui = Instance.new("ScreenGui")
ZetLockGui.Name = "ZerkaSenseZetLock"
ZetLockGui.ResetOnSpawn = false
ZetLockGui.IgnoreGuiInset = true
ZetLockGui.DisplayOrder = 99999
ZetLockGui.Parent = playerGui

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "FOVCircle"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Position = UDim2.fromScale(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Visible = false
FOVCircle.Parent = ZetLockGui

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVCircle

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Thickness = 1.8
FOVStroke.Transparency = 0.05
FOVStroke.Color = hexToColor3(State.ZetLockFOVColor)
FOVStroke.Parent = FOVCircle

local TargetHud = Instance.new("Frame")
TargetHud.Name = "TargetHud"
TargetHud.AnchorPoint = Vector2.new(0.5, 1)
TargetHud.Position = UDim2.new(0.5, 0, 1, -34)
TargetHud.Size = UDim2.fromOffset(330, 82)
TargetHud.BackgroundColor3 = Color3.fromRGB(10, 11, 16)
TargetHud.BackgroundTransparency = State.TargetHubTransparency
TargetHud.Visible = false
TargetHud.Parent = ZetLockGui

local TargetHudScale = Instance.new("UIScale")
TargetHudScale.Scale = State.TargetHubScale
TargetHudScale.Parent = TargetHud

local TargetHudCorner = Instance.new("UICorner")
TargetHudCorner.CornerRadius = UDim.new(0, 14)
TargetHudCorner.Parent = TargetHud

local TargetHudStroke = Instance.new("UIStroke")
TargetHudStroke.Thickness = 1.8
TargetHudStroke.Color = Color3.fromRGB(255, 255, 255)
TargetHudStroke.Transparency = 0.10
TargetHudStroke.Parent = TargetHud

local TargetHudStrokeGradient = Instance.new("UIGradient")
TargetHudStrokeGradient.Color = targetGradient()
TargetHudStrokeGradient.Parent = TargetHudStroke
registerGradient(TargetHudStrokeGradient, "target", 42, 0.18)

local TargetHudTop = Instance.new("Frame")
TargetHudTop.Name = "TopGlow"
TargetHudTop.Size = UDim2.new(1, 0, 0, 6)
TargetHudTop.BorderSizePixel = 0
TargetHudTop.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TargetHudTop.Parent = TargetHud

local TargetHudTopCorner = Instance.new("UICorner")
TargetHudTopCorner.CornerRadius = UDim.new(0, 14)
TargetHudTopCorner.Parent = TargetHudTop

local TargetHudTopGradient = Instance.new("UIGradient")
TargetHudTopGradient.Color = targetGradient()
TargetHudTopGradient.Parent = TargetHudTop
registerGradient(TargetHudTopGradient, "target", 55, 0.20)

local TargetAvatar = Instance.new("ImageLabel")
TargetAvatar.Name = "Avatar"
TargetAvatar.Position = UDim2.new(0, 12, 0, 15)
TargetAvatar.Size = UDim2.fromOffset(52, 52)
TargetAvatar.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
TargetAvatar.BorderSizePixel = 0
TargetAvatar.Image = ""
TargetAvatar.Parent = TargetHud

local TargetAvatarCorner = Instance.new("UICorner")
TargetAvatarCorner.CornerRadius = UDim.new(0, 12)
TargetAvatarCorner.Parent = TargetAvatar

local TargetName = Instance.new("TextLabel")
TargetName.Name = "Name"
TargetName.BackgroundTransparency = 1
TargetName.Position = UDim2.new(0, 76, 0, 13)
TargetName.Size = UDim2.new(1, -88, 0, 22)
TargetName.Text = "NO TARGET"
TargetName.TextXAlignment = Enum.TextXAlignment.Left
TargetName.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetName.TextStrokeTransparency = 0.2
TargetName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
TargetName.Font = Enum.Font.GothamBlack
TargetName.TextSize = 16
TargetName.Parent = TargetHud

local TargetNameGradient = Instance.new("UIGradient")
TargetNameGradient.Color = targetGradient()
TargetNameGradient.Parent = TargetName
registerGradient(TargetNameGradient, "target", 48, 0.18)

local TargetInfo = Instance.new("TextLabel")
TargetInfo.Name = "Info"
TargetInfo.BackgroundTransparency = 1
TargetInfo.Position = UDim2.new(0, 76, 0, 34)
TargetInfo.Size = UDim2.new(1, -88, 0, 17)
TargetInfo.Text = "ID: -"
TargetInfo.Font = Enum.Font.GothamSemibold
TargetInfo.TextSize = 12
TargetInfo.TextXAlignment = Enum.TextXAlignment.Left
TargetInfo.TextColor3 = Color3.fromRGB(210, 220, 255)
TargetInfo.TextStrokeTransparency = 0.35
TargetInfo.Parent = TargetHud

local TargetHpBack = Instance.new("Frame")
TargetHpBack.Name = "HPBack"
TargetHpBack.Position = UDim2.new(0, 76, 0, 56)
TargetHpBack.Size = UDim2.new(1, -88, 0, 10)
TargetHpBack.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TargetHpBack.BorderSizePixel = 0
TargetHpBack.Parent = TargetHud

local TargetHpBackCorner = Instance.new("UICorner")
TargetHpBackCorner.CornerRadius = UDim.new(1, 0)
TargetHpBackCorner.Parent = TargetHpBack

local TargetHpFill = Instance.new("Frame")
TargetHpFill.Name = "HPFill"
TargetHpFill.Size = UDim2.new(1, 0, 1, 0)
TargetHpFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TargetHpFill.BorderSizePixel = 0
TargetHpFill.Parent = TargetHpBack

local TargetHpFillCorner = Instance.new("UICorner")
TargetHpFillCorner.CornerRadius = UDim.new(1, 0)
TargetHpFillCorner.Parent = TargetHpFill

local TargetHpGradient = Instance.new("UIGradient")
TargetHpGradient.Color = targetGradient()
TargetHpGradient.Parent = TargetHpFill
registerGradient(TargetHpGradient, "target", 50, 0.18)

local ZetLockCurrentTarget = nil
local ZetLockHighlight = nil
local ZetLockLastAvatarTarget = nil

updateTargetHubStyle = function()
	TargetHudScale.Scale = State.TargetHubScale
	TargetHud.BackgroundTransparency = State.TargetHubTransparency
	TargetHudStrokeGradient.Color = targetGradient()
	TargetHudTopGradient.Color = targetGradient()
	TargetNameGradient.Color = targetGradient()
	TargetHpGradient.Color = targetGradient()
end

local function getZetLockModeSpeed()
	if State.ZetLockMode == "Smooth" then
		return 7
	end

	if State.ZetLockMode == "Rage" then
		return 60
	end

	return 18
end

local function getZetLockFOVRadius()
	local camera = getCamera()

	if not camera then
		return State.ZetLockFOV
	end

	if State.ZetLockResolutionMode then
		local viewport = camera.ViewportSize
		local scale = math.clamp(math.min(viewport.X, viewport.Y) / 720, 0.65, 2.4)
		return State.ZetLockFOV * scale
	end

	return State.ZetLockFOV
end

local function getZetLockTargetPart(targetPlayer)
	local character = targetPlayer.Character

	if not character then
		return nil
	end

	if State.ZetLockPart == "Head" then
		return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	end

	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("Head")
end

local function isValidZetLockTarget(targetPlayer)
	if not targetPlayer or not targetPlayer.Parent then
		return false
	end

	if targetPlayer == player then
		return false
	end

	local character = targetPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local targetPart = getZetLockTargetPart(targetPlayer)

	if not character or not humanoid or not targetPart then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	if State.ZetLockTeamCheck and isTeammate(targetPlayer) then
		return false
	end

	return true
end

local function isZetLockTargetVisible(targetPlayer, targetPart)
	if not State.ZetLockWallCheck then
		return true
	end

	local camera = getCamera()

	if not camera or not targetPart then
		return false
	end

	local origin = camera.CFrame.Position
	local direction = targetPart.Position - origin

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, params)

	if not result then
		return true
	end

	local character = targetPlayer.Character
	return character and result.Instance and result.Instance:IsDescendantOf(character)
end

local function getScreenDistanceFromCenter(worldPosition)
	local camera = getCamera()

	if not camera then
		return math.huge, false
	end

	local viewport = camera.ViewportSize
	local screenPoint, onScreen = camera:WorldToViewportPoint(worldPosition)

	if not onScreen then
		return math.huge, false
	end

	local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
	local point = Vector2.new(screenPoint.X, screenPoint.Y)

	return (point - center).Magnitude, true
end

local function findBestZetLockTarget()
	local radius = getZetLockFOVRadius()
	local bestTarget = nil
	local bestScore = math.huge

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if isValidZetLockTarget(targetPlayer) then
			local targetPart = getZetLockTargetPart(targetPlayer)

			if targetPart and isZetLockTargetVisible(targetPlayer, targetPart) then
				local distance, onScreen = getScreenDistanceFromCenter(targetPart.Position)

				if onScreen and distance <= radius and distance < bestScore then
					bestScore = distance
					bestTarget = targetPlayer
				end
			end
		end
	end

	return bestTarget
end

local function clearZetLockHighlight()
	if ZetLockHighlight then
		pcall(function()
			ZetLockHighlight:Destroy()
		end)

		ZetLockHighlight = nil
	end
end

local function applyZetLockHighlight(targetPlayer)
	local character = targetPlayer and targetPlayer.Character

	if not character then
		clearZetLockHighlight()
		return
	end

	if ZetLockHighlight and ZetLockHighlight.Adornee == character then
		return
	end

	clearZetLockHighlight()

	ZetLockHighlight = Instance.new("Highlight")
	ZetLockHighlight.Name = "ZerkaSense_ZetLockGlow"
	ZetLockHighlight.Adornee = character
	ZetLockHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	ZetLockHighlight.FillColor = Color3.fromRGB(255, 40, 40)
	ZetLockHighlight.OutlineColor = Color3.fromRGB(255, 0, 0)
	ZetLockHighlight.FillTransparency = 0.78
	ZetLockHighlight.OutlineTransparency = 0
	ZetLockHighlight.Parent = character
end

local function updateZetLockFOV()
	local radius = getZetLockFOVRadius()

	FOVCircle.Size = UDim2.fromOffset(radius * 2, radius * 2)
	FOVCircle.Position = UDim2.fromScale(0.5, 0.5)
	FOVCircle.Visible = State.ZetLockEnabled and State.ZetLockShowFOV
	FOVStroke.Color = hexToColor3(State.ZetLockFOVColor)
end

local function updateZetLockHud(targetPlayer)
	if not State.ZetLockEnabled or not targetPlayer or not isValidZetLockTarget(targetPlayer) then
		TargetHud.Visible = false
		ZetLockLastAvatarTarget = nil
		return
	end

	local humanoid = getHumanoid(targetPlayer)

	if not humanoid then
		TargetHud.Visible = false
		return
	end

	TargetHud.Visible = true
	TargetName.Text = targetPlayer.Name
	TargetInfo.Text = "ID: " .. tostring(targetPlayer.UserId) .. "  •  HP: " .. tostring(math.floor(humanoid.Health + 0.5))

	local hpPercent = 0

	if humanoid.MaxHealth > 0 then
		hpPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	end

	TargetHpFill.Size = UDim2.new(hpPercent, 0, 1, 0)

	if ZetLockLastAvatarTarget ~= targetPlayer then
		ZetLockLastAvatarTarget = targetPlayer

		TargetAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. targetPlayer.UserId .. "&w=150&h=150"

		pcall(function()
			local img = Players:GetUserThumbnailAsync(
				targetPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)

			if img and ZetLockLastAvatarTarget == targetPlayer then
				TargetAvatar.Image = img
			end
		end)
	end
end

clearZetLockTarget = function()
	ZetLockCurrentTarget = nil
	clearZetLockHighlight()
	updateZetLockHud(nil)
end

setZetLockEnabled = function(enabled, silent)
	State.ZetLockEnabled = enabled == true

	if not State.ZetLockEnabled then
		clearZetLockTarget()
		FOVCircle.Visible = false

		if not silent then
			notify("ZetLock", "Disabled.", "x", 2)
		end

		return
	end

	if not silent then
		notify("ZetLock", "Enabled.", "crosshair", 3)
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	updateZetLockFOV()

	if not State.ZetLockEnabled then
		return
	end

	local camera = getCamera()

	if not camera then
		return
	end

	local target = ZetLockCurrentTarget

	if State.ZetLockPriority and target and isValidZetLockTarget(target) then
		local part = getZetLockTargetPart(target)

		if not part or not isZetLockTargetVisible(target, part) then
			target = nil
		else
			local distance, onScreen = getScreenDistanceFromCenter(part.Position)

			if not onScreen or distance > getZetLockFOVRadius() * 1.25 then
				target = nil
			end
		end
	else
		target = nil
	end

	if not target then
		target = findBestZetLockTarget()
	end

	ZetLockCurrentTarget = target

	if not target then
		clearZetLockHighlight()
		updateZetLockHud(nil)
		return
	end

	local targetPart = getZetLockTargetPart(target)

	if not targetPart then
		clearZetLockTarget()
		return
	end

	applyZetLockHighlight(target)
	updateZetLockHud(target)

	local aimPosition = targetPart.Position

	if State.ZetLockPredict and targetPart:IsA("BasePart") then
		aimPosition = aimPosition + targetPart.AssemblyLinearVelocity * State.ZetLockPredictAmount
	end

	local origin = camera.CFrame.Position
	local targetCFrame = CFrame.lookAt(origin, aimPosition)

	if State.ZetLockNoises then
		local t = os.clock() * State.ZetLockNoiseSpeed
		local strength = State.ZetLockNoiseStrength * 0.01
		local noiseX = math.sin(t * 1.31) * strength
		local noiseY = math.cos(t * 0.97) * strength
		targetCFrame = targetCFrame * CFrame.Angles(noiseY, noiseX, 0)
	end

	local speed = getZetLockModeSpeed()
	local alpha = 1 - math.exp(-speed * deltaTime)

	if State.ZetLockMode == "Rage" then
		alpha = math.clamp(alpha * 1.35, 0, 1)
	elseif State.ZetLockMode == "Smooth" then
		alpha = math.clamp(alpha * 0.75, 0, 1)
	end

	camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
end)

--====================================================
-- ESP ENGINE
--====================================================

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ZerkaSenseESP"
ESPFolder.Parent = Workspace

local ESPObjects = {}

local ESP_EDGE_CONNECTIONS = {
	{ 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 },
	{ 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 },
	{ 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local function isVisibleFromCamera(targetCharacter, targetPart)
	if not State.ESPWallCheck then
		return true
	end

	local camera = getCamera()

	if not camera or not targetPart then
		return false
	end

	local origin = camera.CFrame.Position
	local direction = targetPart.Position - origin

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, params)

	if not result then
		return true
	end

	return result.Instance and result.Instance:IsDescendantOf(targetCharacter)
end

local function cleanupESP(targetPlayer)
	local obj = ESPObjects[targetPlayer]

	if not obj then
		return
	end

	if obj.HealthConnection then
		pcall(function()
			obj.HealthConnection:Disconnect()
		end)
	end

	if obj.Root then
		pcall(function()
			obj.Root:Destroy()
		end)
	end

	if obj.TopBillboard then
		pcall(function()
			obj.TopBillboard:Destroy()
		end)
	end

	if obj.BottomBillboard then
		pcall(function()
			obj.BottomBillboard:Destroy()
		end)
	end

	ESPObjects[targetPlayer] = nil
end

local function createESPBeam(rootPart, a0, a1, name)
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.Width0 = State.ESPLineThickness
	beam.Width1 = State.ESPLineThickness
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Enabled = true
	beam.Color = ColorSequence.new(hexToColor3(State.ESPBoxColor))
	beam.Transparency = NumberSequence.new(State.ESPBoxTransparency)
	beam.Parent = rootPart
	return beam
end

local function createESPBillboardTop()
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZerkaNameESP"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.new(0, 180, 0, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.1, 0)
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextColor3 = hexToColor3(State.ESPNameColor)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = gui

	return gui
end

local function createESPBillboardBottom()
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZerkaHealthESP"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.new(0, 160, 0, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, -3.15, 0)
	gui.Parent = playerGui

	local hpNumber = Instance.new("TextLabel")
	hpNumber.Name = "HPNumber"
	hpNumber.Position = UDim2.fromOffset(0, 0)
	hpNumber.Size = UDim2.new(1, 0, 0, 18)
	hpNumber.BackgroundTransparency = 1
	hpNumber.Text = ""
	hpNumber.TextColor3 = hexToColor3(State.ESPHealthColor)
	hpNumber.TextStrokeTransparency = 0
	hpNumber.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hpNumber.Font = Enum.Font.GothamBold
	hpNumber.TextSize = 13
	hpNumber.TextXAlignment = Enum.TextXAlignment.Center
	hpNumber.Parent = gui

	local hpBack = Instance.new("Frame")
	hpBack.Name = "HPBack"
	hpBack.Position = UDim2.new(0.5, 0, 0, 22)
	hpBack.AnchorPoint = Vector2.new(0.5, 0)
	hpBack.Size = UDim2.new(0, 120, 0, 8)
	hpBack.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	hpBack.BorderSizePixel = 0
	hpBack.Parent = gui

	local hpBackCorner = Instance.new("UICorner")
	hpBackCorner.CornerRadius = UDim.new(1, 0)
	hpBackCorner.Parent = hpBack

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = hexToColor3(State.ESPHealthColor)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBack

	local hpFillCorner = Instance.new("UICorner")
	hpFillCorner.CornerRadius = UDim.new(1, 0)
	hpFillCorner.Parent = hpFill

	return gui
end

local function createESPObject(targetPlayer)
	local obj = {}

	obj.Root = Instance.new("Part")
	obj.Root.Name = "ZerkaESPBoxRoot"
	obj.Root.Anchored = true
	obj.Root.CanCollide = false
	obj.Root.CanTouch = false
	obj.Root.CanQuery = false
	obj.Root.Transparency = 1
	obj.Root.Size = Vector3.new(2, 5, 2)
	obj.Root.Parent = ESPFolder

	obj.Corners = {}
	obj.Edges = {}

	for i = 1, 8 do
		local attachment = Instance.new("Attachment")
		attachment.Name = "Corner" .. tostring(i)
		attachment.Parent = obj.Root
		obj.Corners[i] = attachment
	end

	for i, pair in ipairs(ESP_EDGE_CONNECTIONS) do
		obj.Edges[i] = createESPBeam(obj.Root, obj.Corners[pair[1]], obj.Corners[pair[2]], "Edge" .. tostring(i))
	end

	obj.Fill = Instance.new("BoxHandleAdornment")
	obj.Fill.Name = "Fill"
	obj.Fill.Adornee = obj.Root
	obj.Fill.AlwaysOnTop = true
	obj.Fill.ZIndex = 9
	obj.Fill.Size = obj.Root.Size
	obj.Fill.Color3 = hexToColor3(State.ESPFillColor)
	obj.Fill.Transparency = State.ESPFillTransparency
	obj.Fill.Visible = false
	obj.Fill.Parent = obj.Root

	obj.DamageFill = Instance.new("BoxHandleAdornment")
	obj.DamageFill.Name = "DamageTick"
	obj.DamageFill.Adornee = obj.Root
	obj.DamageFill.AlwaysOnTop = true
	obj.DamageFill.ZIndex = 11
	obj.DamageFill.Size = obj.Root.Size
	obj.DamageFill.Color3 = hexToColor3(State.ESPDamageColor)
	obj.DamageFill.Transparency = 1
	obj.DamageFill.Visible = true
	obj.DamageFill.Parent = obj.Root

	obj.LookStart = Instance.new("Attachment")
	obj.LookStart.Name = "LookStart"
	obj.LookStart.Parent = obj.Root

	obj.LookEnd = Instance.new("Attachment")
	obj.LookEnd.Name = "LookEnd"
	obj.LookEnd.Parent = obj.Root

	obj.LookGlow = Instance.new("Beam")
	obj.LookGlow.Name = "LookGlow"
	obj.LookGlow.Attachment0 = obj.LookStart
	obj.LookGlow.Attachment1 = obj.LookEnd
	obj.LookGlow.FaceCamera = true
	obj.LookGlow.Width0 = State.ESPLookThickness * 2.7
	obj.LookGlow.Width1 = State.ESPLookThickness * 2.7
	obj.LookGlow.LightEmission = 1
	obj.LookGlow.LightInfluence = 0
	obj.LookGlow.Enabled = true
	obj.LookGlow.Color = ColorSequence.new(hexToColor3(State.ESPLookColor))
	obj.LookGlow.Transparency = NumberSequence.new(0.55)
	obj.LookGlow.Parent = obj.Root

	obj.LookCore = Instance.new("Beam")
	obj.LookCore.Name = "LookCore"
	obj.LookCore.Attachment0 = obj.LookStart
	obj.LookCore.Attachment1 = obj.LookEnd
	obj.LookCore.FaceCamera = true
	obj.LookCore.Width0 = State.ESPLookThickness
	obj.LookCore.Width1 = State.ESPLookThickness
	obj.LookCore.LightEmission = 1
	obj.LookCore.LightInfluence = 0
	obj.LookCore.Enabled = true
	obj.LookCore.Color = ColorSequence.new(hexToColor3(State.ESPLookColor))
	obj.LookCore.Transparency = NumberSequence.new(0)
	obj.LookCore.Parent = obj.Root

	obj.TopBillboard = createESPBillboardTop()
	obj.BottomBillboard = createESPBillboardBottom()

	obj.LastHealth = 0
	obj.DamageUntil = 0

	ESPObjects[targetPlayer] = obj
	return obj
end

local function ensureESPObject(targetPlayer)
	return ESPObjects[targetPlayer] or createESPObject(targetPlayer)
end

local function setESPCorners(obj, size)
	local x = size.X / 2
	local y = size.Y / 2
	local z = size.Z / 2

	local positions = {
		Vector3.new(-x, -y, -z),
		Vector3.new(x, -y, -z),
		Vector3.new(-x, -y, z),
		Vector3.new(x, -y, z),

		Vector3.new(-x, y, -z),
		Vector3.new(x, y, -z),
		Vector3.new(-x, y, z),
		Vector3.new(x, y, z),
	}

	for i, pos in ipairs(positions) do
		obj.Corners[i].Position = pos
	end
end

local function hideESP(targetPlayer)
	local obj = ESPObjects[targetPlayer]

	if not obj then
		return
	end

	for _, beam in ipairs(obj.Edges) do
		beam.Enabled = false
	end

	obj.Fill.Visible = false
	obj.DamageFill.Transparency = 1
	obj.LookGlow.Enabled = false
	obj.LookCore.Enabled = false
	obj.TopBillboard.Enabled = false
	obj.BottomBillboard.Enabled = false
end

local function bindESPHealth(obj, targetPlayer, humanoid)
	if obj.Humanoid == humanoid then
		return
	end

	if obj.HealthConnection then
		pcall(function()
			obj.HealthConnection:Disconnect()
		end)
	end

	obj.Humanoid = humanoid
	obj.LastHealth = humanoid.Health
	obj.DamageUntil = 0

	obj.HealthConnection = humanoid.HealthChanged:Connect(function(newHealth)
		if State.ESPDamageTick and newHealth < obj.LastHealth then
			obj.DamageUntil = os.clock() + State.ESPDamageFlashTime
		end

		obj.LastHealth = newHealth
	end)
end

local function getESPBox(character, root)
	local bboxCFrame, bboxSize = character:GetBoundingBox()

	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)

	if flatLook.Magnitude < 0.01 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end

	return CFrame.lookAt(bboxCFrame.Position, bboxCFrame.Position + flatLook), bboxSize + Vector3.new(0.08, 0.08, 0.08)
end

local function updateESP(targetPlayer)
	if not State.ESPEnabled then
		hideESP(targetPlayer)
		return
	end

	if targetPlayer == player then
		return
	end

	if State.ESPTeamCheck and isTeammate(targetPlayer) then
		hideESP(targetPlayer)
		return
	end

	if not isAlive(targetPlayer) then
		hideESP(targetPlayer)
		return
	end

	local character = targetPlayer.Character
	local humanoid = getHumanoid(targetPlayer)
	local root = getRoot(targetPlayer)
	local head = getHead(targetPlayer)
	local myRoot = getRoot(player)

	if not character or not humanoid or not root then
		hideESP(targetPlayer)
		return
	end

	if myRoot and (root.Position - myRoot.Position).Magnitude > State.ESPMaxDistance then
		hideESP(targetPlayer)
		return
	end

	if not isVisibleFromCamera(character, root) then
		hideESP(targetPlayer)
		return
	end

	local obj = ensureESPObject(targetPlayer)
	bindESPHealth(obj, targetPlayer, humanoid)

	local boxCFrame, boxSize = getESPBox(character, root)

	obj.Root.CFrame = boxCFrame
	obj.Root.Size = boxSize

	setESPCorners(obj, boxSize)

	local baseColor = isTeammate(targetPlayer) and hexToColor3(State.ESPTeamColor) or hexToColor3(State.ESPBoxColor)
	local damageActive = obj.DamageUntil and os.clock() < obj.DamageUntil
	local boxColor = damageActive and hexToColor3(State.ESPDamageColor) or baseColor

	for _, beam in ipairs(obj.Edges) do
		beam.Enabled = State.ESPHitbox
		beam.Width0 = State.ESPLineThickness
		beam.Width1 = State.ESPLineThickness
		beam.Color = ColorSequence.new(boxColor)
		beam.Transparency = NumberSequence.new(State.ESPBoxTransparency)
	end

	obj.Fill.Adornee = obj.Root
	obj.Fill.Size = boxSize
	obj.Fill.Visible = State.ESPFill
	obj.Fill.Color3 = damageActive and hexToColor3(State.ESPDamageColor) or hexToColor3(State.ESPFillColor)
	obj.Fill.Transparency = State.ESPFillTransparency

	if damageActive then
		local remain = math.clamp((obj.DamageUntil - os.clock()) / State.ESPDamageFlashTime, 0, 1)
		obj.DamageFill.Adornee = obj.Root
		obj.DamageFill.Size = boxSize + Vector3.new(0.25, 0.25, 0.25)
		obj.DamageFill.Color3 = hexToColor3(State.ESPDamageColor)
		obj.DamageFill.Transparency = 0.18 + (1 - remain) * 0.64
	else
		obj.DamageFill.Transparency = 1
	end

	local eye = head and (head.Position + Vector3.new(0, 0.15, 0)) or (root.Position + Vector3.new(0, 1.5, 0))
	local lookEnd = eye + root.CFrame.LookVector * State.ESPLookLength

	obj.LookStart.Position = obj.Root.CFrame:PointToObjectSpace(eye)
	obj.LookEnd.Position = obj.Root.CFrame:PointToObjectSpace(lookEnd)

	obj.LookGlow.Enabled = State.ESPLookDirection
	obj.LookCore.Enabled = State.ESPLookDirection

	obj.LookGlow.Width0 = State.ESPLookThickness * 2.7
	obj.LookGlow.Width1 = State.ESPLookThickness * 2.7
	obj.LookCore.Width0 = State.ESPLookThickness
	obj.LookCore.Width1 = State.ESPLookThickness

	obj.LookGlow.Color = ColorSequence.new(hexToColor3(State.ESPLookColor))
	obj.LookCore.Color = ColorSequence.new(hexToColor3(State.ESPLookColor))

	obj.TopBillboard.Enabled = State.ESPName
	obj.TopBillboard.Adornee = root
	obj.TopBillboard.StudsOffsetWorldSpace = Vector3.new(0, boxSize.Y / 2 + 0.8, 0)

	local nameLabel = obj.TopBillboard:FindFirstChild("Name")

	if nameLabel then
		nameLabel.Text = targetPlayer.Name
		nameLabel.TextColor3 = hexToColor3(State.ESPNameColor)
	end

	obj.BottomBillboard.Enabled = State.ESPHealthNumbers or State.ESPHealthBar
	obj.BottomBillboard.Adornee = root
	obj.BottomBillboard.StudsOffsetWorldSpace = Vector3.new(0, -boxSize.Y / 2 - 0.7, 0)

	local hpNumber = obj.BottomBillboard:FindFirstChild("HPNumber")
	local hpBack = obj.BottomBillboard:FindFirstChild("HPBack")
	local hpFill = hpBack and hpBack:FindFirstChild("HPFill")

	local hp = math.floor(humanoid.Health + 0.5)
	local maxHp = math.max(1, humanoid.MaxHealth)
	local hpPercent = math.clamp(humanoid.Health / maxHp, 0, 1)

	if hpNumber then
		hpNumber.Visible = State.ESPHealthNumbers
		hpNumber.Text = tostring(hp) .. " HP"
		hpNumber.TextColor3 = hexToColor3(State.ESPHealthColor)
	end

	if hpBack then
		hpBack.Visible = State.ESPHealthBar
	end

	if hpFill then
		hpFill.Size = UDim2.new(hpPercent, 0, 1, 0)
		hpFill.BackgroundColor3 = hexToColor3(State.ESPHealthColor)
	end
end

updateAllESP = function()
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player then
			updateESP(targetPlayer)
		end
	end

	for targetPlayer in pairs(ESPObjects) do
		if not targetPlayer or not targetPlayer.Parent then
			cleanupESP(targetPlayer)
		end
	end
end

clearAllESP = function()
	for targetPlayer in pairs(ESPObjects) do
		cleanupESP(targetPlayer)
	end
end

Players.PlayerRemoving:Connect(function(targetPlayer)
	cleanupESP(targetPlayer)
end)

RunService.RenderStepped:Connect(function()
	updateAllESP()
end)

--====================================================
-- BETTER SMOOTH
--====================================================

local lastCameraYaw = 0
local smoothBlurValue = 0

local function getCameraYaw()
	local camera = getCamera()

	if not camera then
		return 0
	end

	local look = camera.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function applySmoothPreset(name)
	if name == "Soft" then
		State.NaturalBlurStrength = 7
		State.NaturalBlurDecay = 16
	elseif name == "Cinematic" then
		State.NaturalBlurStrength = 12
		State.NaturalBlurDecay = 12
	elseif name == "Ultra" then
		State.NaturalBlurStrength = 18
		State.NaturalBlurDecay = 9
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	local yaw = getCameraYaw()
	local delta = yaw - lastCameraYaw

	if delta > math.pi then
		delta -= math.pi * 2
	elseif delta < -math.pi then
		delta += math.pi * 2
	end

	lastCameraYaw = yaw

	if State.BetterSmoothEnabled and State.NaturalBlur then
		local target = math.clamp(math.abs(delta) * State.NaturalBlurStrength * 90, 0, State.NaturalBlurStrength)
		smoothBlurValue = smoothBlurValue + (target - smoothBlurValue) * math.clamp(deltaTime * State.NaturalBlurDecay, 0, 1)
	else
		smoothBlurValue = smoothBlurValue + (0 - smoothBlurValue) * math.clamp(deltaTime * 18, 0, 1)
	end

	NaturalBlurEffect.Size = smoothBlurValue
end)

--====================================================
-- PERSONA VISUALS
--====================================================

local PersonaHighlight = nil
local PersonaOriginals = {}

local function storePersonaOriginal(part)
	if PersonaOriginals[part] then
		return
	end

	PersonaOriginals[part] = {
		Color = part.Color,
		Material = part.Material,
		Transparency = part.Transparency,
	}
end

restorePersona = function()
	for part, original in pairs(PersonaOriginals) do
		if part and part.Parent then
			pcall(function()
				part.Color = original.Color
				part.Material = original.Material
				part.Transparency = original.Transparency
			end)
		end
	end

	PersonaOriginals = {}

	if PersonaHighlight then
		pcall(function()
			PersonaHighlight:Destroy()
		end)

		PersonaHighlight = nil
	end
end

local function getMaterialFromName(name)
	if name == "Neon" then
		return Enum.Material.Neon
	end

	if name == "ForceField" then
		return Enum.Material.ForceField
	end

	if name == "Glass" then
		return Enum.Material.Glass
	end

	if name == "SmoothPlastic" then
		return Enum.Material.SmoothPlastic
	end

	return Enum.Material.Neon
end

local function applyPersonaVisuals()
	local character = player.Character

	if not character then
		return
	end

	if not State.PersonaGlow and not State.PersonaMaterialEnabled then
		restorePersona()
		return
	end

	if State.PersonaGlow then
		if not PersonaHighlight or not PersonaHighlight.Parent then
			PersonaHighlight = Instance.new("Highlight")
			PersonaHighlight.Name = "ZerkaPersonaGlow"
			PersonaHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			PersonaHighlight.Adornee = character
			PersonaHighlight.Parent = character
		end

		PersonaHighlight.FillColor = hexToColor3(State.PersonaGlowColor)
		PersonaHighlight.OutlineColor = hexToColor3(State.PersonaGlowColor)
		PersonaHighlight.FillTransparency = State.PersonaGlowFillTransparency
		PersonaHighlight.OutlineTransparency = 0
		PersonaHighlight.Enabled = true
	elseif PersonaHighlight then
		PersonaHighlight.Enabled = false
	end

	if State.PersonaMaterialEnabled then
		for _, item in ipairs(character:GetDescendants()) do
			if item:IsA("BasePart") then
				storePersonaOriginal(item)
				item.Material = getMaterialFromName(State.PersonaMaterial)
				item.Color = hexToColor3(State.PersonaBodyColor)
			end
		end

		local tool = character:FindFirstChildOfClass("Tool")

		if tool then
			for _, item in ipairs(tool:GetDescendants()) do
				if item:IsA("BasePart") then
					storePersonaOriginal(item)
					item.Material = getMaterialFromName(State.PersonaMaterial)
					item.Color = hexToColor3(State.PersonaToolColor)
				end
			end
		end
	end
end

RunService.RenderStepped:Connect(function()
	applyPersonaVisuals()
end)

--====================================================
-- WORLD CHANGER
--====================================================

local WorldOriginals = nil
local WorldCreated = {}
local WeatherPart = nil
local WeatherEmitter = nil
local ParticlesPart = nil
local ParticlesEmitter = nil

local function captureWorldOriginals()
	if WorldOriginals then
		return
	end

	WorldOriginals = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		ExposureCompensation = Lighting.ExposureCompensation,
		ColorShift_Top = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom,
		SkyObjects = {},
	}

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			table.insert(WorldOriginals.SkyObjects, child:Clone())
		end
	end
end

local function clearWorldCreated()
	for _, item in ipairs(WorldCreated) do
		if item and item.Parent then
			pcall(function()
				item:Destroy()
			end)
		end
	end

	WorldCreated = {}

	if WeatherPart then
		WeatherPart:Destroy()
		WeatherPart = nil
		WeatherEmitter = nil
	end

	if ParticlesPart then
		ParticlesPart:Destroy()
		ParticlesPart = nil
		ParticlesEmitter = nil
	end
end

restoreWorld = function()
	if not WorldOriginals then
		return
	end

	Lighting.Ambient = WorldOriginals.Ambient
	Lighting.OutdoorAmbient = WorldOriginals.OutdoorAmbient
	Lighting.Brightness = WorldOriginals.Brightness
	Lighting.ClockTime = WorldOriginals.ClockTime
	Lighting.FogColor = WorldOriginals.FogColor
	Lighting.FogStart = WorldOriginals.FogStart
	Lighting.FogEnd = WorldOriginals.FogEnd
	Lighting.ExposureCompensation = WorldOriginals.ExposureCompensation
	Lighting.ColorShift_Top = WorldOriginals.ColorShift_Top
	Lighting.ColorShift_Bottom = WorldOriginals.ColorShift_Bottom

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") and child.Name == "ZerkaCustomSky" then
			child:Destroy()
		end
	end

	clearWorldCreated()
	WorldOriginals = nil
end

local function getWorldTint()
	local existing = Lighting:FindFirstChild("ZerkaWorldTint")

	if existing and existing:IsA("ColorCorrectionEffect") then
		return existing
	end

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZerkaWorldTint"
	cc.Enabled = true
	cc.Parent = Lighting

	table.insert(WorldCreated, cc)
	return cc
end

local function createSkyFromId(id)
	if id == "" then
		return
	end

	local sky = Instance.new("Sky")
	sky.Name = "ZerkaCustomSky"

	local url = "rbxassetid://" .. id

	sky.SkyboxBk = url
	sky.SkyboxDn = url
	sky.SkyboxFt = url
	sky.SkyboxLf = url
	sky.SkyboxRt = url
	sky.SkyboxUp = url

	sky.Parent = Lighting
	table.insert(WorldCreated, sky)
end

applyWorldChanger = function()
	if not State.WorldChangerEnabled then
		restoreWorld()
		return
	end

	captureWorldOriginals()

	Lighting.Ambient = hexToColor3(State.WorldAmbient)
	Lighting.OutdoorAmbient = hexToColor3(State.WorldOutdoorAmbient)
	Lighting.ColorShift_Top = hexToColor3(State.WorldLightColor)
	Lighting.ClockTime = State.WorldTime == "Night" and 0 or 14
	Lighting.Brightness = State.WorldTime == "Night" and 1.35 or 2.25

	if State.WorldFogEnabled then
		Lighting.FogColor = hexToColor3(State.WorldFogColor)
		Lighting.FogStart = State.WorldFogStart
		Lighting.FogEnd = State.WorldFogEnd
	else
		Lighting.FogEnd = 100000
	end

	if State.WorldSkyMode == "No Sky" then
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA("Sky") then
				child:Destroy()
			end
		end
	elseif State.WorldSkyMode == "Custom" then
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA("Sky") then
				child:Destroy()
			end
		end

		createSkyFromId(State.WorldSkyboxId)
	end

	local tint = getWorldTint()
	tint.Enabled = State.WorldTintEnabled
	tint.TintColor = hexToColor3(State.WorldTintColor)
	tint.Saturation = State.WorldTintSaturation
	tint.Contrast = State.WorldTintContrast
end

local function setupWeatherEmitter()
	if not WeatherPart then
		WeatherPart = Instance.new("Part")
		WeatherPart.Name = "ZerkaWeatherPart"
		WeatherPart.Anchored = true
		WeatherPart.CanCollide = false
		WeatherPart.CanTouch = false
		WeatherPart.CanQuery = false
		WeatherPart.Transparency = 1
		WeatherPart.Size = Vector3.new(180, 1, 180)
		WeatherPart.Parent = Workspace

		WeatherEmitter = Instance.new("ParticleEmitter")
		WeatherEmitter.Name = "Weather"
		WeatherEmitter.Rate = 0
		WeatherEmitter.Lifetime = NumberRange.new(1.4, 2.4)
		WeatherEmitter.Speed = NumberRange.new(28, 42)
		WeatherEmitter.SpreadAngle = Vector2.new(10, 10)
		WeatherEmitter.EmissionDirection = Enum.NormalId.Bottom
		WeatherEmitter.LightInfluence = 0
		WeatherEmitter.Parent = WeatherPart
	end
end

local function setupParticlesEmitter()
	if not ParticlesPart then
		ParticlesPart = Instance.new("Part")
		ParticlesPart.Name = "ZerkaWorldParticlesPart"
		ParticlesPart.Anchored = true
		ParticlesPart.CanCollide = false
		ParticlesPart.CanTouch = false
		ParticlesPart.CanQuery = false
		ParticlesPart.Transparency = 1
		ParticlesPart.Size = Vector3.new(220, 120, 220)
		ParticlesPart.Parent = Workspace

		ParticlesEmitter = Instance.new("ParticleEmitter")
		ParticlesEmitter.Name = "WorldParticles"
		ParticlesEmitter.Rate = 0
		ParticlesEmitter.Lifetime = NumberRange.new(3, 6)
		ParticlesEmitter.Speed = NumberRange.new(1, 5)
		ParticlesEmitter.SpreadAngle = Vector2.new(180, 180)
		ParticlesEmitter.LightEmission = 0.8
		ParticlesEmitter.LightInfluence = 0
		ParticlesEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(1, 0),
		})
		ParticlesEmitter.Parent = ParticlesPart
	end
end

RunService.RenderStepped:Connect(function()
	local camera = getCamera()

	if not camera then
		return
	end

	if State.WorldChangerEnabled and State.WorldWeather ~= "Off" then
		setupWeatherEmitter()
		WeatherPart.CFrame = camera.CFrame * CFrame.new(0, 55, -35)

		if State.WorldWeather == "Snow" then
			WeatherEmitter.Rate = 260
			WeatherEmitter.Speed = NumberRange.new(8, 16)
			WeatherEmitter.Size = NumberSequence.new(0.16)
			WeatherEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
			WeatherEmitter.Acceleration = Vector3.new(0, -8, 0)
		elseif State.WorldWeather == "Rain" then
			WeatherEmitter.Rate = 420
			WeatherEmitter.Speed = NumberRange.new(55, 75)
			WeatherEmitter.Size = NumberSequence.new(0.08)
			WeatherEmitter.Color = ColorSequence.new(Color3.fromRGB(150, 190, 255))
			WeatherEmitter.Acceleration = Vector3.new(0, -120, 0)
		end
	elseif WeatherEmitter then
		WeatherEmitter.Rate = 0
	end

	if State.WorldChangerEnabled and State.WorldParticles then
		setupParticlesEmitter()
		ParticlesPart.CFrame = camera.CFrame * CFrame.new(0, 0, -40)
		ParticlesEmitter.Rate = 55
		ParticlesEmitter.Color = ColorSequence.new(hexToColor3(State.WorldParticlesColorA), hexToColor3(State.WorldParticlesColorB))
	elseif ParticlesEmitter then
		ParticlesEmitter.Rate = 0
	end
end)

--====================================================
-- APPLY STATE
--====================================================

local function applyThemeSideEffects()
	pcall(function()
		if themeExists(State.Theme) then
			WindUI:SetTheme(State.Theme)
		end
	end)

	pcall(function()
		WindUI.TransparencyValue = State.Transparency
	end)

	safeCall(Window, "SetUIScale", State.UIScale)
	safeCall(Window, "ToggleTransparency", State.Transparency > 0)

	if State.FOVChangerEnabled and getCamera() then
		getCamera().FieldOfView = State.CameraFOV
	end

	refreshGradients()
	updateMenuEffects()
	updateTargetHubStyle()
	applyWorldChanger()
end

applyState = function(newState, silent)
	IsApplyingState = true

	State = validateState(newState)

	for key, value in pairs(State) do
		setControlValue(key, value)
	end

	applyThemeSideEffects()

	IsApplyingState = false

	setBhopEnabled(State.BhopEnabled, true)
	setZetLockEnabled(State.ZetLockEnabled, true)
	updateAllESP()

	if not silent then
		notify("Settings Applied", "ZerkaSense state updated.", "check", 3)
	end
end

--====================================================
-- CONFIG SYSTEM
--====================================================

local SavedConfigs = {
	Default = deepCopy(DEFAULT_STATE),
}

local SelectedConfigName = "Default"
local ConfigCodeText = ""
local ConfigNameInput
local ConfigCodeInput
local ConfigDropdown

local function getConfigNames()
	local names = {}

	for name in pairs(SavedConfigs) do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

local function refreshConfigDropdown()
	if ConfigDropdown then
		local names = getConfigNames()
		safeCall(ConfigDropdown, "Refresh", names)
		safeCall(ConfigDropdown, "SetValues", names)
		safeCall(ConfigDropdown, "Select", SelectedConfigName)
		safeCall(ConfigDropdown, "Set", SelectedConfigName)
	end

	if ConfigNameInput then
		safeCall(ConfigNameInput, "Set", SelectedConfigName)
	end
end

local function saveConfig(name)
	name = sanitizeName(name, "Default", 28)
	SavedConfigs[name] = validateState(State)
	SelectedConfigName = name
	refreshConfigDropdown()
	notify("Config Saved", name, "save", 3)
end

local function loadConfig(name)
	name = sanitizeName(name, "Default", 28)

	if not SavedConfigs[name] then
		notify("Config Not Found", name, "x", 3)
		return
	end

	SelectedConfigName = name
	applyState(SavedConfigs[name], true)
	refreshConfigDropdown()
	notify("Config Loaded", name, "folder-open", 3)
end

local function deleteConfig(name)
	name = sanitizeName(name, "Default", 28)

	if name == "Default" then
		notify("Protected Config", "Default cannot be deleted.", "shield", 3)
		return
	end

	SavedConfigs[name] = nil
	SelectedConfigName = "Default"
	refreshConfigDropdown()
	notify("Config Deleted", name, "trash", 3)
end

local function exportConfig()
	local payload = {
		version = "ZerkaSense2.0",
		name = SelectedConfigName,
		state = validateState(State),
	}

	local ok, json = pcall(function()
		return HttpService:JSONEncode(payload)
	end)

	if not ok or not json then
		notify("Export Failed", "Could not encode config.", "x", 3)
		return
	end

	ConfigCodeText = "ZERKASENSE2:" .. urlEncode(json)

	if ConfigCodeInput then
		safeCall(ConfigCodeInput, "Set", ConfigCodeText)
	end

	local copied = copyToClipboard(ConfigCodeText)

	if copied then
		notify("Config Exported", "Copied to clipboard.", "copy", 3)
	else
		print("[ZerkaSense Config]")
		print(ConfigCodeText)
		notify("Config Exported", "Printed to Output.", "copy", 3)
	end
end

local function importConfig(code, applyNow)
	code = trim(code)

	if code == "" then
		notify("Import Empty", "Paste config code first.", "alert-triangle", 3)
		return
	end

	if code:sub(1, 12) ~= "ZERKASENSE2:" then
		notify("Import Failed", "Invalid config prefix.", "x", 3)
		return
	end

	local decodedText = urlDecode(code:sub(13))

	local ok, payload = pcall(function()
		return HttpService:JSONDecode(decodedText)
	end)

	if not ok or type(payload) ~= "table" or type(payload.state) ~= "table" then
		notify("Import Failed", "Invalid config data.", "x", 3)
		return
	end

	local name = sanitizeName(payload.name or "Imported", "Imported", 28)
	SavedConfigs[name] = validateState(payload.state)
	SelectedConfigName = name
	refreshConfigDropdown()

	if applyNow then
		applyState(SavedConfigs[name], true)
	end

	notify("Config Imported", name, "download", 3)
end

--====================================================
-- WINDUI WINDOW
--====================================================

Window = WindUI:CreateWindow({
	Title = "ZerkaSense",
	Author = "Release 2.0",
	Folder = "ZerkaSense",
	Icon = "crosshair",
	Theme = State.Theme,
	NewElements = true,
	HideSearchBar = true,

	Size = UDim2.fromOffset(790, 540),
	MinSize = Vector2.new(580, 380),
	ToggleKey = Enum.KeyCode.RightShift,

	OpenButton = {
		Title = "Zerka",
		Enabled = true,
		Draggable = false,
		OnlyMobile = false,
		Scale = 0.52,
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 1.5,
		Color = ColorSequence.new(
			hexToColor3(State.MenuAccentA),
			hexToColor3(State.MenuAccentB)
		),
	},

	Topbar = {
		Height = 44,
		ButtonsType = "Default",
	},

	User = {
		Enabled = false,
	},
})

local MainTab = Window:Tab({
	Title = "Main",
	Icon = "layout-dashboard",
	Desc = "BHOP and ZetLock",
})

local VisualsTab = Window:Tab({
	Title = "Visuals",
	Icon = "eye",
	Desc = "ESP, FOV, Smooth, Persona, World",
})

local SettingsTab = Window:Tab({
	Title = "Settings",
	Icon = "settings",
	Desc = "Menu and Target Hub",
})

local ConfigTab = Window:Tab({
	Title = "Config",
	Icon = "save",
	Desc = "Config system",
})

--====================================================
-- MAIN TAB
--====================================================

MainTab:Paragraph({
	Title = "ZerkaSense 2.0",
	Desc = "WindUI-based build.\nMain contains BHOP and ZetLock.\nVisuals are local-only.",
	Image = avatarImage,
	ImageSize = 54,
	Color = PlayerStatusStyle.Color,
})

MainTab:Space()

MainTab:Paragraph({
	Title = "Mobile BHOP",
	Desc = "Phone-only BHOP with configurable speed, auto-strafe and anti-velocity brake.",
	Image = "move",
	ImageSize = 24,
	Color = Color3.fromRGB(0, 210, 255),
})

Controls.BhopEnabled = MainTab:Toggle({
	Title = "Mobile BHOP",
	Desc = "Shows BHOP hold button on mobile.",
	Type = "Checkbox",
	Value = State.BhopEnabled,
	Flag = "ZS_BhopEnabled",
	Callback = function(value)
		State.BhopEnabled = value
		setBhopEnabled(value, false)
	end,
})

Controls.BhopMaxSpeed = MainTab:Slider({
	Title = "BHOP Max Speed",
	Desc = "Maximum horizontal speed.",
	Step = 1,
	Value = { Min = 40, Max = 180, Default = State.BhopMaxSpeed },
	Flag = "ZS_BhopMaxSpeed",
	Callback = function(value) State.BhopMaxSpeed = value end,
})

Controls.BhopStartSpeed = MainTab:Slider({
	Title = "BHOP Start Speed",
	Desc = "Starting speed after jump.",
	Step = 1,
	Value = { Min = 16, Max = 80, Default = State.BhopStartSpeed },
	Flag = "ZS_BhopStartSpeed",
	Callback = function(value) State.BhopStartSpeed = value end,
})

Controls.BhopMoveAccel = MainTab:Slider({
	Title = "Move Acceleration",
	Desc = "Air move acceleration.",
	Step = 1,
	Value = { Min = 20, Max = 260, Default = State.BhopMoveAccel },
	Flag = "ZS_BhopMoveAccel",
	Callback = function(value) State.BhopMoveAccel = value end,
})

Controls.BhopCameraTurnAccel = MainTab:Slider({
	Title = "Camera Turn Accel",
	Desc = "Acceleration from camera turning.",
	Step = 1,
	Value = { Min = 20, Max = 280, Default = State.BhopCameraTurnAccel },
	Flag = "ZS_BhopCameraTurnAccel",
	Callback = function(value) State.BhopCameraTurnAccel = value end,
})

Controls.BhopAirControl = MainTab:Slider({
	Title = "Air Control",
	Desc = "Air direction blending.",
	Step = 0.01,
	Value = { Min = 0.1, Max = 1.2, Default = State.BhopAirControl },
	Flag = "ZS_BhopAirControl",
	Callback = function(value) State.BhopAirControl = value end,
})

Controls.BhopGroundBoost = MainTab:Slider({
	Title = "Ground Boost",
	Desc = "Boost before jumping from ground.",
	Step = 1,
	Value = { Min = 0, Max = 45, Default = State.BhopGroundBoost },
	Flag = "ZS_BhopGroundBoost",
	Callback = function(value) State.BhopGroundBoost = value end,
})

Controls.BhopSpeedGrowth = MainTab:Slider({
	Title = "Speed Growth",
	Desc = "How quickly speed cap grows while holding BHOP.",
	Step = 1,
	Value = { Min = 10, Max = 180, Default = State.BhopSpeedGrowth },
	Flag = "ZS_BhopSpeedGrowth",
	Callback = function(value) State.BhopSpeedGrowth = value end,
})

Controls.BhopAntiVelocityBrake = MainTab:Toggle({
	Title = "Anti-Velocity Brake",
	Desc = "Guides velocity down after BHOP release.",
	Type = "Checkbox",
	Value = State.BhopAntiVelocityBrake,
	Flag = "ZS_BhopAntiVelocityBrake",
	Callback = function(value) State.BhopAntiVelocityBrake = value end,
})

Controls.BhopBrakeStrength = MainTab:Slider({
	Title = "Brake Strength",
	Desc = "Anti-velocity braking strength.",
	Step = 0.01,
	Value = { Min = 0.05, Max = 0.95, Default = State.BhopBrakeStrength },
	Flag = "ZS_BhopBrakeStrength",
	Callback = function(value) State.BhopBrakeStrength = value end,
})

Controls.BhopBrakeTime = MainTab:Slider({
	Title = "Brake Time",
	Desc = "Brake duration after release.",
	Step = 0.01,
	Value = { Min = 0.05, Max = 0.8, Default = State.BhopBrakeTime },
	Flag = "ZS_BhopBrakeTime",
	Callback = function(value) State.BhopBrakeTime = value end,
})

Controls.BhopAutoStrafe = MainTab:Toggle({
	Title = "Auto-Strafe",
	Desc = "Adds automatic side-strafe while BHOP is held.",
	Type = "Checkbox",
	Value = State.BhopAutoStrafe,
	Flag = "ZS_BhopAutoStrafe",
	Callback = function(value) State.BhopAutoStrafe = value end,
})

Controls.BhopAutoStrafeStrength = MainTab:Slider({
	Title = "Auto-Strafe Strength",
	Desc = "Side strafe strength.",
	Step = 0.01,
	Value = { Min = 0, Max = 2, Default = State.BhopAutoStrafeStrength },
	Flag = "ZS_BhopAutoStrafeStrength",
	Callback = function(value) State.BhopAutoStrafeStrength = value end,
})

MainTab:Space()

MainTab:Paragraph({
	Title = "ZetLock",
	Desc = "Admin/dev camera lock. Tracks target inside FOV and shows compact Target HUD.",
	Image = "crosshair",
	ImageSize = 24,
	Color = Color3.fromRGB(255, 40, 90),
})

Controls.ZetLockEnabled = MainTab:Toggle({
	Title = "ZetLock Enabled",
	Desc = "Main ZetLock switch.",
	Type = "Checkbox",
	Value = State.ZetLockEnabled,
	Flag = "ZS_ZetLockEnabled",
	Callback = function(value)
		setZetLockEnabled(value, false)
	end,
})

Controls.ZetLockPart = MainTab:Dropdown({
	Title = "Target Part",
	Desc = "Body or Head.",
	Values = ZETLOCK_PART_OPTIONS,
	Value = State.ZetLockPart,
	AllowNone = false,
	Flag = "ZS_ZetLockPart",
	Callback = function(value)
		if isInList(value, ZETLOCK_PART_OPTIONS) then
			State.ZetLockPart = value
		end
	end,
})

Controls.ZetLockMode = MainTab:Dropdown({
	Title = "Smooth Mode",
	Desc = "Smooth / Pro / Rage.",
	Values = ZETLOCK_MODE_OPTIONS,
	Value = State.ZetLockMode,
	AllowNone = false,
	Flag = "ZS_ZetLockMode",
	Callback = function(value)
		if isInList(value, ZETLOCK_MODE_OPTIONS) then
			State.ZetLockMode = value
		end
	end,
})

Controls.ZetLockFOV = MainTab:Slider({
	Title = "FOV Radius",
	Desc = "Target search radius around screen center.",
	Step = 1,
	Value = { Min = 30, Max = 600, Default = State.ZetLockFOV },
	Flag = "ZS_ZetLockFOV",
	Callback = function(value) State.ZetLockFOV = value end,
})

Controls.ZetLockShowFOV = MainTab:Toggle({
	Title = "Show FOV",
	Desc = "Displays FOV circle.",
	Type = "Checkbox",
	Value = State.ZetLockShowFOV,
	Flag = "ZS_ZetLockShowFOV",
	Callback = function(value) State.ZetLockShowFOV = value end,
})

Controls.ZetLockFOVColor = MainTab:Input({
	Title = "FOV Color HEX",
	Desc = "Default: #FF214F",
	Value = State.ZetLockFOVColor,
	Flag = "ZS_ZetLockFOVColor",
	Callback = function(value)
		if isHexColor(value) then
			State.ZetLockFOVColor = value
		end
	end,
})

Controls.ZetLockPredict = MainTab:Toggle({
	Title = "Predict",
	Desc = "Predicts target movement using velocity.",
	Type = "Checkbox",
	Value = State.ZetLockPredict,
	Flag = "ZS_ZetLockPredict",
	Callback = function(value) State.ZetLockPredict = value end,
})

Controls.ZetLockPredictAmount = MainTab:Slider({
	Title = "Predict Amount",
	Desc = "Prediction multiplier.",
	Step = 0.01,
	Value = { Min = 0, Max = 0.6, Default = State.ZetLockPredictAmount },
	Flag = "ZS_ZetLockPredictAmount",
	Callback = function(value) State.ZetLockPredictAmount = value end,
})

Controls.ZetLockWallCheck = MainTab:Toggle({
	Title = "Wall Check",
	Desc = "Keeps target only if visible from camera.",
	Type = "Checkbox",
	Value = State.ZetLockWallCheck,
	Flag = "ZS_ZetLockWallCheck",
	Callback = function(value) State.ZetLockWallCheck = value end,
})

Controls.ZetLockTeamCheck = MainTab:Toggle({
	Title = "Team Check",
	Desc = "Ignores teammates.",
	Type = "Checkbox",
	Value = State.ZetLockTeamCheck,
	Flag = "ZS_ZetLockTeamCheck",
	Callback = function(value) State.ZetLockTeamCheck = value end,
})

Controls.ZetLockPriority = MainTab:Toggle({
	Title = "Priority Target",
	Desc = "Keeps current target even if another one enters FOV.",
	Type = "Checkbox",
	Value = State.ZetLockPriority,
	Flag = "ZS_ZetLockPriority",
	Callback = function(value) State.ZetLockPriority = value end,
})

Controls.ZetLockResolutionMode = MainTab:Toggle({
	Title = "Resolution Mode",
	Desc = "Scales FOV by screen resolution.",
	Type = "Checkbox",
	Value = State.ZetLockResolutionMode,
	Flag = "ZS_ZetLockResolutionMode",
	Callback = function(value) State.ZetLockResolutionMode = value end,
})

Controls.ZetLockNoises = MainTab:Toggle({
	Title = "Noises",
	Desc = "Tiny camera hand-noise.",
	Type = "Checkbox",
	Value = State.ZetLockNoises,
	Flag = "ZS_ZetLockNoises",
	Callback = function(value) State.ZetLockNoises = value end,
})

Controls.ZetLockNoiseStrength = MainTab:Slider({
	Title = "Noise Strength",
	Desc = "Tiny camera shake strength.",
	Step = 0.01,
	Value = { Min = 0, Max = 0.6, Default = State.ZetLockNoiseStrength },
	Flag = "ZS_ZetLockNoiseStrength",
	Callback = function(value) State.ZetLockNoiseStrength = value end,
})

Controls.ZetLockNoiseSpeed = MainTab:Slider({
	Title = "Noise Speed",
	Desc = "Tiny camera shake speed.",
	Step = 1,
	Value = { Min = 1, Max = 30, Default = State.ZetLockNoiseSpeed },
	Flag = "ZS_ZetLockNoiseSpeed",
	Callback = function(value) State.ZetLockNoiseSpeed = value end,
})

MainTab:Button({
	Title = "Apply Pro ZetLock",
	Desc = "Recommended balanced settings.",
	Icon = "crosshair",
	Color = Color3.fromRGB(255, 40, 90),
	Callback = function()
		State.ZetLockEnabled = true
		State.ZetLockPart = "Body"
		State.ZetLockMode = "Pro"
		State.ZetLockFOV = 160
		State.ZetLockShowFOV = true
		State.ZetLockPredict = true
		State.ZetLockPredictAmount = 0.12
		State.ZetLockWallCheck = true
		State.ZetLockTeamCheck = false
		State.ZetLockPriority = true
		State.ZetLockResolutionMode = true
		State.ZetLockNoises = false
		applyState(State, true)
		notify("ZetLock", "Pro preset applied.", "crosshair", 3)
	end,
})

MainTab:Button({
	Title = "Clear ZetLock Target",
	Desc = "Drops current priority target.",
	Icon = "x",
	Color = Color3.fromRGB(255, 90, 90),
	Callback = function()
		clearZetLockTarget()
		notify("ZetLock", "Target cleared.", "x", 2)
	end,
})

--====================================================
-- VISUALS TAB
--====================================================

VisualsTab:Paragraph({
	Title = "ESP",
	Desc = "Advanced Hitbox ESP, damage tick, look direction, name and health display.",
	Image = "eye",
	ImageSize = 24,
	Color = Color3.fromRGB(255, 40, 90),
})

Controls.ESPEnabled = VisualsTab:Toggle({
	Title = "ESP Enabled",
	Desc = "Main ESP switch.",
	Type = "Checkbox",
	Value = State.ESPEnabled,
	Flag = "ZS_ESPEnabled",
	Callback = function(value) State.ESPEnabled = value end,
})

Controls.ESPHitbox = VisualsTab:Toggle({
	Title = "Hitbox ESP",
	Desc = "Advanced hitbox outline.",
	Type = "Checkbox",
	Value = State.ESPHitbox,
	Flag = "ZS_ESPHitbox",
	Callback = function(value) State.ESPHitbox = value end,
})

Controls.ESPFill = VisualsTab:Toggle({
	Title = "Hitbox Fill",
	Desc = "Transparent fill inside hitbox.",
	Type = "Checkbox",
	Value = State.ESPFill,
	Flag = "ZS_ESPFill",
	Callback = function(value) State.ESPFill = value end,
})

Controls.ESPDamageTick = VisualsTab:Toggle({
	Title = "Damage Tick",
	Desc = "Strong red flash when target takes damage.",
	Type = "Checkbox",
	Value = State.ESPDamageTick,
	Flag = "ZS_ESPDamageTick",
	Callback = function(value) State.ESPDamageTick = value end,
})

Controls.ESPDamageFlashTime = VisualsTab:Slider({
	Title = "Damage Flash Time",
	Desc = "How long damage tick stays visible.",
	Step = 0.05,
	Value = { Min = 0.1, Max = 3, Default = State.ESPDamageFlashTime },
	Flag = "ZS_ESPDamageFlashTime",
	Callback = function(value) State.ESPDamageFlashTime = value end,
})

Controls.ESPLookDirection = VisualsTab:Toggle({
	Title = "Look Direction",
	Desc = "Bright direction beam.",
	Type = "Checkbox",
	Value = State.ESPLookDirection,
	Flag = "ZS_ESPLookDirection",
	Callback = function(value) State.ESPLookDirection = value end,
})

Controls.ESPName = VisualsTab:Toggle({
	Title = "Name",
	Desc = "Name above player.",
	Type = "Checkbox",
	Value = State.ESPName,
	Flag = "ZS_ESPName",
	Callback = function(value) State.ESPName = value end,
})

Controls.ESPHealthNumbers = VisualsTab:Toggle({
	Title = "HP Numbers",
	Desc = "HP number below player.",
	Type = "Checkbox",
	Value = State.ESPHealthNumbers,
	Flag = "ZS_ESPHealthNumbers",
	Callback = function(value) State.ESPHealthNumbers = value end,
})

Controls.ESPHealthBar = VisualsTab:Toggle({
	Title = "HP Bar",
	Desc = "Health bar below player.",
	Type = "Checkbox",
	Value = State.ESPHealthBar,
	Flag = "ZS_ESPHealthBar",
	Callback = function(value) State.ESPHealthBar = value end,
})

Controls.ESPWallCheck = VisualsTab:Toggle({
	Title = "Wall Check",
	Desc = "If enabled, ESP hides behind walls.",
	Type = "Checkbox",
	Value = State.ESPWallCheck,
	Flag = "ZS_ESPWallCheck",
	Callback = function(value) State.ESPWallCheck = value end,
})

Controls.ESPTeamCheck = VisualsTab:Toggle({
	Title = "Team Check",
	Desc = "Ignores teammates.",
	Type = "Checkbox",
	Value = State.ESPTeamCheck,
	Flag = "ZS_ESPTeamCheck",
	Callback = function(value) State.ESPTeamCheck = value end,
})

Controls.ESPMaxDistance = VisualsTab:Slider({
	Title = "ESP Max Distance",
	Desc = "Maximum ESP render distance.",
	Step = 10,
	Value = { Min = 100, Max = 5000, Default = State.ESPMaxDistance },
	Flag = "ZS_ESPMaxDistance",
	Callback = function(value) State.ESPMaxDistance = value end,
})

VisualsTab:Space()

Controls.ESPBoxColor = VisualsTab:Input({
	Title = "Box Color",
	Desc = "HEX color.",
	Value = State.ESPBoxColor,
	Flag = "ZS_ESPBoxColor",
	Callback = function(value) if isHexColor(value) then State.ESPBoxColor = value end end,
})

Controls.ESPFillColor = VisualsTab:Input({
	Title = "Fill Color",
	Desc = "HEX color.",
	Value = State.ESPFillColor,
	Flag = "ZS_ESPFillColor",
	Callback = function(value) if isHexColor(value) then State.ESPFillColor = value end end,
})

Controls.ESPDamageColor = VisualsTab:Input({
	Title = "Damage Color",
	Desc = "HEX color.",
	Value = State.ESPDamageColor,
	Flag = "ZS_ESPDamageColor",
	Callback = function(value) if isHexColor(value) then State.ESPDamageColor = value end end,
})

Controls.ESPLookColor = VisualsTab:Input({
	Title = "Look Direction Color",
	Desc = "HEX color.",
	Value = State.ESPLookColor,
	Flag = "ZS_ESPLookColor",
	Callback = function(value) if isHexColor(value) then State.ESPLookColor = value end end,
})

Controls.ESPNameColor = VisualsTab:Input({
	Title = "Name Color",
	Desc = "HEX color.",
	Value = State.ESPNameColor,
	Flag = "ZS_ESPNameColor",
	Callback = function(value) if isHexColor(value) then State.ESPNameColor = value end end,
})

Controls.ESPHealthColor = VisualsTab:Input({
	Title = "Health Color",
	Desc = "HEX color.",
	Value = State.ESPHealthColor,
	Flag = "ZS_ESPHealthColor",
	Callback = function(value) if isHexColor(value) then State.ESPHealthColor = value end end,
})

Controls.ESPTeamColor = VisualsTab:Input({
	Title = "Team Color",
	Desc = "HEX color.",
	Value = State.ESPTeamColor,
	Flag = "ZS_ESPTeamColor",
	Callback = function(value) if isHexColor(value) then State.ESPTeamColor = value end end,
})

VisualsTab:Space()

Controls.ESPLineThickness = VisualsTab:Slider({
	Title = "ESP Line Thickness",
	Desc = "Hitbox line thickness.",
	Step = 0.005,
	Value = { Min = 0.005, Max = 0.2, Default = State.ESPLineThickness },
	Flag = "ZS_ESPLineThickness",
	Callback = function(value) State.ESPLineThickness = value end,
})

Controls.ESPFillTransparency = VisualsTab:Slider({
	Title = "Fill Transparency",
	Desc = "Hitbox fill transparency.",
	Step = 0.01,
	Value = { Min = 0, Max = 1, Default = State.ESPFillTransparency },
	Flag = "ZS_ESPFillTransparency",
	Callback = function(value) State.ESPFillTransparency = value end,
})

Controls.ESPBoxTransparency = VisualsTab:Slider({
	Title = "Box Transparency",
	Desc = "Hitbox edge transparency.",
	Step = 0.01,
	Value = { Min = 0, Max = 1, Default = State.ESPBoxTransparency },
	Flag = "ZS_ESPBoxTransparency",
	Callback = function(value) State.ESPBoxTransparency = value end,
})

Controls.ESPLookLength = VisualsTab:Slider({
	Title = "Look Direction Length",
	Desc = "Direction beam length.",
	Step = 0.1,
	Value = { Min = 0.5, Max = 10, Default = State.ESPLookLength },
	Flag = "ZS_ESPLookLength",
	Callback = function(value) State.ESPLookLength = value end,
})

Controls.ESPLookThickness = VisualsTab:Slider({
	Title = "Look Direction Thickness",
	Desc = "Direction beam thickness.",
	Step = 0.005,
	Value = { Min = 0.01, Max = 0.35, Default = State.ESPLookThickness },
	Flag = "ZS_ESPLookThickness",
	Callback = function(value) State.ESPLookThickness = value end,
})

VisualsTab:Button({
	Title = "Clear ESP Objects",
	Desc = "Rebuilds ESP visuals.",
	Icon = "refresh-cw",
	Color = Color3.fromRGB(255, 40, 90),
	Callback = function()
		clearAllESP()
		notify("ESP", "ESP objects cleared.", "refresh-cw", 2)
	end,
})

VisualsTab:Space()

VisualsTab:Paragraph({
	Title = "FOV Changer",
	Desc = "Camera FOV changer.",
	Image = "camera",
	ImageSize = 24,
	Color = Color3.fromRGB(0, 210, 255),
})

Controls.FOVChangerEnabled = VisualsTab:Toggle({
	Title = "FOV Changer Enabled",
	Desc = "Uses custom camera FOV.",
	Type = "Checkbox",
	Value = State.FOVChangerEnabled,
	Flag = "ZS_FOVChangerEnabled",
	Callback = function(value)
		State.FOVChangerEnabled = value

		if getCamera() then
			getCamera().FieldOfView = State.FOVChangerEnabled and State.CameraFOV or 70
		end
	end,
})

Controls.CameraFOV = VisualsTab:Slider({
	Title = "Camera FOV",
	Desc = "Camera field of view.",
	Step = 1,
	Value = { Min = 60, Max = 120, Default = State.CameraFOV },
	Flag = "ZS_CameraFOV",
	Callback = function(value)
		State.CameraFOV = value

		if State.FOVChangerEnabled and getCamera() then
			getCamera().FieldOfView = State.CameraFOV
		end
	end,
})

VisualsTab:Space()

VisualsTab:Paragraph({
	Title = "Better Smooth",
	Desc = "Natural blur on camera turns with clean presets.",
	Image = "sparkles",
	ImageSize = 24,
	Color = Color3.fromRGB(138, 43, 255),
})

Controls.BetterSmoothEnabled = VisualsTab:Toggle({
	Title = "Better Smooth Enabled",
	Desc = "Main Better Smooth switch.",
	Type = "Checkbox",
	Value = State.BetterSmoothEnabled,
	Flag = "ZS_BetterSmoothEnabled",
	Callback = function(value) State.BetterSmoothEnabled = value end,
})

Controls.BetterSmoothPreset = VisualsTab:Dropdown({
	Title = "Preset",
	Desc = "Soft / Cinematic / Ultra.",
	Values = SMOOTH_PRESETS,
	Value = State.BetterSmoothPreset,
	AllowNone = false,
	Flag = "ZS_BetterSmoothPreset",
	Callback = function(value)
		if isInList(value, SMOOTH_PRESETS) then
			State.BetterSmoothPreset = value
			applySmoothPreset(value)
			applyState(State, true)
		end
	end,
})

Controls.NaturalBlur = VisualsTab:Toggle({
	Title = "Natural Blur",
	Desc = "Adds blur on quick camera turns.",
	Type = "Checkbox",
	Value = State.NaturalBlur,
	Flag = "ZS_NaturalBlur",
	Callback = function(value) State.NaturalBlur = value end,
})

Controls.NaturalBlurStrength = VisualsTab:Slider({
	Title = "Blur Strength",
	Desc = "Maximum blur intensity.",
	Step = 1,
	Value = { Min = 0, Max = 30, Default = State.NaturalBlurStrength },
	Flag = "ZS_NaturalBlurStrength",
	Callback = function(value) State.NaturalBlurStrength = value end,
})

Controls.NaturalBlurDecay = VisualsTab:Slider({
	Title = "Blur Decay",
	Desc = "How quickly blur disappears.",
	Step = 1,
	Value = { Min = 4, Max = 30, Default = State.NaturalBlurDecay },
	Flag = "ZS_NaturalBlurDecay",
	Callback = function(value) State.NaturalBlurDecay = value end,
})

VisualsTab:Space()

VisualsTab:Paragraph({
	Title = "Personas Visuals",
	Desc = "Glow, material and local color changes for your character and held items.",
	Image = "user-round",
	ImageSize = 24,
	Color = Color3.fromRGB(255, 40, 90),
})

Controls.PersonaGlow = VisualsTab:Toggle({
	Title = "Persona Glow",
	Desc = "Adds local glow to your character.",
	Type = "Checkbox",
	Value = State.PersonaGlow,
	Flag = "ZS_PersonaGlow",
	Callback = function(value) State.PersonaGlow = value end,
})

Controls.PersonaGlowColor = VisualsTab:Input({
	Title = "Glow Color",
	Desc = "HEX color.",
	Value = State.PersonaGlowColor,
	Flag = "ZS_PersonaGlowColor",
	Callback = function(value) if isHexColor(value) then State.PersonaGlowColor = value end end,
})

Controls.PersonaGlowFillTransparency = VisualsTab:Slider({
	Title = "Glow Fill Transparency",
	Desc = "Lower = stronger fill.",
	Step = 0.01,
	Value = { Min = 0, Max = 1, Default = State.PersonaGlowFillTransparency },
	Flag = "ZS_PersonaGlowFillTransparency",
	Callback = function(value) State.PersonaGlowFillTransparency = value end,
})

Controls.PersonaMaterialEnabled = VisualsTab:Toggle({
	Title = "Material Override",
	Desc = "Changes your body/tool material locally.",
	Type = "Checkbox",
	Value = State.PersonaMaterialEnabled,
	Flag = "ZS_PersonaMaterialEnabled",
	Callback = function(value) State.PersonaMaterialEnabled = value end,
})

Controls.PersonaMaterial = VisualsTab:Dropdown({
	Title = "Material",
	Desc = "Neon / ForceField / Glass / SmoothPlastic.",
	Values = MATERIAL_OPTIONS,
	Value = State.PersonaMaterial,
	AllowNone = false,
	Flag = "ZS_PersonaMaterial",
	Callback = function(value)
		if isInList(value, MATERIAL_OPTIONS) then
			State.PersonaMaterial = value
		end
	end,
})

Controls.PersonaBodyColor = VisualsTab:Input({
	Title = "Body Color",
	Desc = "HEX color.",
	Value = State.PersonaBodyColor,
	Flag = "ZS_PersonaBodyColor",
	Callback = function(value) if isHexColor(value) then State.PersonaBodyColor = value end end,
})

Controls.PersonaToolColor = VisualsTab:Input({
	Title = "Tool Color",
	Desc = "HEX color.",
	Value = State.PersonaToolColor,
	Flag = "ZS_PersonaToolColor",
	Callback = function(value) if isHexColor(value) then State.PersonaToolColor = value end end,
})

VisualsTab:Button({
	Title = "Restore Persona",
	Desc = "Restores character material/colors.",
	Icon = "rotate-ccw",
	Color = Color3.fromRGB(255, 190, 80),
	Callback = function()
		State.PersonaGlow = false
		State.PersonaMaterialEnabled = false
		restorePersona()
		applyState(State, true)
	end,
})

VisualsTab:Space()

VisualsTab:Paragraph({
	Title = "World Changer",
	Desc = "Local world visuals: sky, lighting, fog, tint, particles, rain and snow.",
	Image = "cloud",
	ImageSize = 24,
	Color = Color3.fromRGB(0, 210, 255),
})

Controls.WorldChangerEnabled = VisualsTab:Toggle({
	Title = "World Changer Enabled",
	Desc = "Main world changer switch.",
	Type = "Checkbox",
	Value = State.WorldChangerEnabled,
	Flag = "ZS_WorldChangerEnabled",
	Callback = function(value)
		State.WorldChangerEnabled = value
		applyWorldChanger()
	end,
})

Controls.WorldSkyMode = VisualsTab:Dropdown({
	Title = "Sky Mode",
	Desc = "Default / No Sky / Custom.",
	Values = WORLD_SKY_OPTIONS,
	Value = State.WorldSkyMode,
	AllowNone = false,
	Flag = "ZS_WorldSkyMode",
	Callback = function(value)
		if isInList(value, WORLD_SKY_OPTIONS) then
			State.WorldSkyMode = value
			applyWorldChanger()
		end
	end,
})

Controls.WorldSkyboxId = VisualsTab:Input({
	Title = "Custom Skybox ID",
	Desc = "Roblox asset id, used for all sky faces.",
	Value = State.WorldSkyboxId,
	Flag = "ZS_WorldSkyboxId",
	Callback = function(value)
		State.WorldSkyboxId = tostring(value or ""):gsub("[^%d]", "")
		applyWorldChanger()
	end,
})

Controls.WorldTime = VisualsTab:Dropdown({
	Title = "Time",
	Desc = "Day / Night.",
	Values = WORLD_TIME_OPTIONS,
	Value = State.WorldTime,
	AllowNone = false,
	Flag = "ZS_WorldTime",
	Callback = function(value)
		if isInList(value, WORLD_TIME_OPTIONS) then
			State.WorldTime = value
			applyWorldChanger()
		end
	end,
})

Controls.WorldAmbient = VisualsTab:Input({
	Title = "Ambient Color",
	Desc = "HEX color.",
	Value = State.WorldAmbient,
	Flag = "ZS_WorldAmbient",
	Callback = function(value) if isHexColor(value) then State.WorldAmbient = value applyWorldChanger() end end,
})

Controls.WorldOutdoorAmbient = VisualsTab:Input({
	Title = "Outdoor Ambient",
	Desc = "HEX color.",
	Value = State.WorldOutdoorAmbient,
	Flag = "ZS_WorldOutdoorAmbient",
	Callback = function(value) if isHexColor(value) then State.WorldOutdoorAmbient = value applyWorldChanger() end end,
})

Controls.WorldLightColor = VisualsTab:Input({
	Title = "Light Color",
	Desc = "HEX color.",
	Value = State.WorldLightColor,
	Flag = "ZS_WorldLightColor",
	Callback = function(value) if isHexColor(value) then State.WorldLightColor = value applyWorldChanger() end end,
})

Controls.WorldFogEnabled = VisualsTab:Toggle({
	Title = "Fog Enabled",
	Desc = "Local fog.",
	Type = "Checkbox",
	Value = State.WorldFogEnabled,
	Flag = "ZS_WorldFogEnabled",
	Callback = function(value) State.WorldFogEnabled = value applyWorldChanger() end,
})

Controls.WorldFogColor = VisualsTab:Input({
	Title = "Fog Color",
	Desc = "HEX color.",
	Value = State.WorldFogColor,
	Flag = "ZS_WorldFogColor",
	Callback = function(value) if isHexColor(value) then State.WorldFogColor = value applyWorldChanger() end end,
})

Controls.WorldFogStart = VisualsTab:Slider({
	Title = "Fog Start",
	Desc = "Fog start distance.",
	Step = 5,
	Value = { Min = 0, Max = 1000, Default = State.WorldFogStart },
	Flag = "ZS_WorldFogStart",
	Callback = function(value) State.WorldFogStart = value applyWorldChanger() end,
})

Controls.WorldFogEnd = VisualsTab:Slider({
	Title = "Fog End",
	Desc = "Fog end distance.",
	Step = 10,
	Value = { Min = 20, Max = 5000, Default = State.WorldFogEnd },
	Flag = "ZS_WorldFogEnd",
	Callback = function(value) State.WorldFogEnd = value applyWorldChanger() end,
})

Controls.WorldTintEnabled = VisualsTab:Toggle({
	Title = "World Tint",
	Desc = "Adds ColorCorrection tint.",
	Type = "Checkbox",
	Value = State.WorldTintEnabled,
	Flag = "ZS_WorldTintEnabled",
	Callback = function(value) State.WorldTintEnabled = value applyWorldChanger() end,
})

Controls.WorldTintColor = VisualsTab:Input({
	Title = "Tint Color",
	Desc = "HEX color.",
	Value = State.WorldTintColor,
	Flag = "ZS_WorldTintColor",
	Callback = function(value) if isHexColor(value) then State.WorldTintColor = value applyWorldChanger() end end,
})

Controls.WorldTintSaturation = VisualsTab:Slider({
	Title = "Tint Saturation",
	Desc = "World saturation.",
	Step = 0.01,
	Value = { Min = -1, Max = 1, Default = State.WorldTintSaturation },
	Flag = "ZS_WorldTintSaturation",
	Callback = function(value) State.WorldTintSaturation = value applyWorldChanger() end,
})

Controls.WorldTintContrast = VisualsTab:Slider({
	Title = "Tint Contrast",
	Desc = "World contrast.",
	Step = 0.01,
	Value = { Min = -1, Max = 1, Default = State.WorldTintContrast },
	Flag = "ZS_WorldTintContrast",
	Callback = function(value) State.WorldTintContrast = value applyWorldChanger() end,
})

Controls.WorldParticles = VisualsTab:Toggle({
	Title = "Map Particles",
	Desc = "Floating local particles around camera.",
	Type = "Checkbox",
	Value = State.WorldParticles,
	Flag = "ZS_WorldParticles",
	Callback = function(value) State.WorldParticles = value end,
})

Controls.WorldParticlesColorA = VisualsTab:Input({
	Title = "Particles Color A",
	Desc = "HEX color.",
	Value = State.WorldParticlesColorA,
	Flag = "ZS_WorldParticlesColorA",
	Callback = function(value) if isHexColor(value) then State.WorldParticlesColorA = value end end,
})

Controls.WorldParticlesColorB = VisualsTab:Input({
	Title = "Particles Color B",
	Desc = "HEX color.",
	Value = State.WorldParticlesColorB,
	Flag = "ZS_WorldParticlesColorB",
	Callback = function(value) if isHexColor(value) then State.WorldParticlesColorB = value end end,
})

Controls.WorldWeather = VisualsTab:Dropdown({
	Title = "Weather",
	Desc = "Off / Rain / Snow.",
	Values = WORLD_WEATHER_OPTIONS,
	Value = State.WorldWeather,
	AllowNone = false,
	Flag = "ZS_WorldWeather",
	Callback = function(value)
		if isInList(value, WORLD_WEATHER_OPTIONS) then
			State.WorldWeather = value
		end
	end,
})

VisualsTab:Button({
	Title = "Restore World",
	Desc = "Restores original world visuals.",
	Icon = "rotate-ccw",
	Color = Color3.fromRGB(255, 190, 80),
	Callback = function()
		State.WorldChangerEnabled = false
		restoreWorld()
		applyState(State, true)
	end,
})

--====================================================
-- SETTINGS TAB
--====================================================

SettingsTab:Paragraph({
	Title = "Menu Style",
	Desc = "WindUI stays. These settings control blur, snow, scale, transparency and ZerkaSense visual accents.",
	Image = "settings",
	ImageSize = 24,
	Color = Color3.fromRGB(255, 40, 90),
})

Controls.Theme = SettingsTab:Dropdown({
	Title = "WindUI Theme",
	Desc = "Base WindUI theme.",
	Values = ThemeOptions,
	Value = State.Theme,
	AllowNone = false,
	Flag = "ZS_Theme",
	Callback = function(value)
		if type(value) == "string" and themeExists(value) then
			State.Theme = value
			applyThemeSideEffects()
		end
	end,
})

Controls.Transparency = SettingsTab:Slider({
	Title = "WindUI Transparency",
	Desc = "WindUI liquid glass transparency.",
	Step = 0.01,
	Value = { Min = 0, Max = 0.75, Default = State.Transparency },
	Flag = "ZS_Transparency",
	Callback = function(value)
		State.Transparency = value
		applyThemeSideEffects()
	end,
})

Controls.UIScale = SettingsTab:Slider({
	Title = "UI Scale",
	Desc = "WindUI scale.",
	Step = 0.01,
	Value = { Min = 0.50, Max = 1.25, Default = State.UIScale },
	Flag = "ZS_UIScale",
	Callback = function(value)
		State.UIScale = value
		applyThemeSideEffects()
	end,
})

Controls.MenuBlur = SettingsTab:Toggle({
	Title = "Menu Blur",
	Desc = "Blur background while menu effects are active.",
	Type = "Checkbox",
	Value = State.MenuBlur,
	Flag = "ZS_MenuBlur",
	Callback = function(value)
		State.MenuBlur = value
		updateMenuEffects()
	end,
})

Controls.MenuSnow = SettingsTab:Toggle({
	Title = "Menu Snow",
	Desc = "Minimal snow overlay while menu effects are active.",
	Type = "Checkbox",
	Value = State.MenuSnow,
	Flag = "ZS_MenuSnow",
	Callback = function(value)
		State.MenuSnow = value
		updateMenuEffects()
	end,
})

Controls.MenuAccentA = SettingsTab:Input({
	Title = "Menu Rage Color A",
	Desc = "HEX color.",
	Value = State.MenuAccentA,
	Flag = "ZS_MenuAccentA",
	Callback = function(value)
		if isHexColor(value) then
			State.MenuAccentA = value
			refreshGradients()
		end
	end,
})

Controls.MenuAccentB = SettingsTab:Input({
	Title = "Menu Rage Color B",
	Desc = "HEX color.",
	Value = State.MenuAccentB,
	Flag = "ZS_MenuAccentB",
	Callback = function(value)
		if isHexColor(value) then
			State.MenuAccentB = value
			refreshGradients()
		end
	end,
})

Controls.MenuAccentC = SettingsTab:Input({
	Title = "Menu Rage Color C",
	Desc = "HEX color.",
	Value = State.MenuAccentC,
	Flag = "ZS_MenuAccentC",
	Callback = function(value)
		if isHexColor(value) then
			State.MenuAccentC = value
			refreshGradients()
		end
	end,
})

SettingsTab:Space()

SettingsTab:Paragraph({
	Title = "Target Hub",
	Desc = "ZetLock compact Target HUD style.",
	Image = "badge-info",
	ImageSize = 24,
	Color = Color3.fromRGB(0, 210, 255),
})

Controls.TargetHubScale = SettingsTab:Slider({
	Title = "Target Hub Scale",
	Desc = "Target HUD size.",
	Step = 0.01,
	Value = { Min = 0.70, Max = 1.50, Default = State.TargetHubScale },
	Flag = "ZS_TargetHubScale",
	Callback = function(value)
		State.TargetHubScale = value
		updateTargetHubStyle()
	end,
})

Controls.TargetHubTransparency = SettingsTab:Slider({
	Title = "Target Hub Transparency",
	Desc = "Target HUD background transparency.",
	Step = 0.01,
	Value = { Min = 0, Max = 0.75, Default = State.TargetHubTransparency },
	Flag = "ZS_TargetHubTransparency",
	Callback = function(value)
		State.TargetHubTransparency = value
		updateTargetHubStyle()
	end,
})

Controls.TargetHubAccentA = SettingsTab:Input({
	Title = "Target Hub Color A",
	Desc = "HEX color.",
	Value = State.TargetHubAccentA,
	Flag = "ZS_TargetHubAccentA",
	Callback = function(value)
		if isHexColor(value) then
			State.TargetHubAccentA = value
			updateTargetHubStyle()
		end
	end,
})

Controls.TargetHubAccentB = SettingsTab:Input({
	Title = "Target Hub Color B",
	Desc = "HEX color.",
	Value = State.TargetHubAccentB,
	Flag = "ZS_TargetHubAccentB",
	Callback = function(value)
		if isHexColor(value) then
			State.TargetHubAccentB = value
			updateTargetHubStyle()
		end
	end,
})

Controls.TargetHubAccentC = SettingsTab:Input({
	Title = "Target Hub Color C",
	Desc = "HEX color.",
	Value = State.TargetHubAccentC,
	Flag = "ZS_TargetHubAccentC",
	Callback = function(value)
		if isHexColor(value) then
			State.TargetHubAccentC = value
			updateTargetHubStyle()
		end
	end,
})

SettingsTab:Button({
	Title = "Reset Interface",
	Desc = "Resets only UI/menu/target hub styling.",
	Icon = "rotate-ccw",
	Color = Color3.fromRGB(255, 190, 80),
	Callback = function()
		State.Theme = DEFAULT_STATE.Theme
		State.Transparency = DEFAULT_STATE.Transparency
		State.UIScale = DEFAULT_STATE.UIScale
		State.MenuBlur = DEFAULT_STATE.MenuBlur
		State.MenuSnow = DEFAULT_STATE.MenuSnow
		State.MenuAccentA = DEFAULT_STATE.MenuAccentA
		State.MenuAccentB = DEFAULT_STATE.MenuAccentB
		State.MenuAccentC = DEFAULT_STATE.MenuAccentC
		State.TargetHubScale = DEFAULT_STATE.TargetHubScale
		State.TargetHubTransparency = DEFAULT_STATE.TargetHubTransparency
		State.TargetHubAccentA = DEFAULT_STATE.TargetHubAccentA
		State.TargetHubAccentB = DEFAULT_STATE.TargetHubAccentB
		State.TargetHubAccentC = DEFAULT_STATE.TargetHubAccentC
		applyState(State, true)
	end,
})

--====================================================
-- CONFIG TAB
--====================================================

ConfigTab:Paragraph({
	Title = "Config",
	Desc = "Old-style config system: save, load, export, import.",
	Image = "save",
	ImageSize = 24,
	Color = Color3.fromRGB(255, 40, 90),
})

ConfigNameInput = ConfigTab:Input({
	Title = "Config Name",
	Desc = "Example: Main, Rage, Smooth, Mobile.",
	Value = SelectedConfigName,
	Callback = function(value)
		SelectedConfigName = sanitizeName(value, "Default", 28)
	end,
})

ConfigDropdown = ConfigTab:Dropdown({
	Title = "Saved Configs",
	Desc = "Choose saved config.",
	Values = getConfigNames(),
	Value = SelectedConfigName,
	AllowNone = false,
	Callback = function(value)
		if type(value) == "string" then
			SelectedConfigName = sanitizeName(value, "Default", 28)

			if ConfigNameInput then
				safeCall(ConfigNameInput, "Set", SelectedConfigName)
			end
		end
	end,
})

ConfigTab:Button({
	Title = "Save Config",
	Desc = "Saves current settings into memory.",
	Icon = "save",
	Color = Color3.fromRGB(0, 210, 255),
	Callback = function()
		saveConfig(SelectedConfigName)
	end,
})

ConfigTab:Button({
	Title = "Load Config",
	Desc = "Loads selected config.",
	Icon = "folder-open",
	Color = Color3.fromRGB(138, 43, 255),
	Callback = function()
		loadConfig(SelectedConfigName)
	end,
})

ConfigTab:Button({
	Title = "Delete Config",
	Desc = "Deletes selected config. Default is protected.",
	Icon = "trash",
	Color = Color3.fromRGB(255, 40, 90),
	Callback = function()
		deleteConfig(SelectedConfigName)
	end,
})

ConfigTab:Space()

ConfigCodeInput = ConfigTab:Input({
	Title = "Config Code",
	Desc = "Export/import config share code.",
	Value = "",
	Callback = function(value)
		ConfigCodeText = tostring(value or "")
	end,
})

ConfigTab:Button({
	Title = "Export Config",
	Desc = "Exports current settings to config code.",
	Icon = "share-2",
	Color = Color3.fromRGB(0, 210, 255),
	Callback = function()
		exportConfig()
	end,
})

ConfigTab:Button({
	Title = "Import Config",
	Desc = "Imports config code without applying.",
	Icon = "download",
	Color = Color3.fromRGB(255, 190, 80),
	Callback = function()
		importConfig(ConfigCodeText, false)
	end,
})

ConfigTab:Button({
	Title = "Import And Apply",
	Desc = "Imports config code and applies it now.",
	Icon = "check",
	Color = Color3.fromRGB(70, 255, 170),
	Callback = function()
		importConfig(ConfigCodeText, true)
	end,
})

ConfigTab:Button({
	Title = "Reset To Default",
	Desc = "Resets all ZerkaSense settings.",
	Icon = "rotate-ccw",
	Color = Color3.fromRGB(255, 80, 90),
	Callback = function()
		State = deepCopy(DEFAULT_STATE)
		applyState(State, true)
		notify("Config", "Reset to default.", "rotate-ccw", 3)
	end,
})

--====================================================
-- INIT
--====================================================

refreshConfigDropdown()
applyState(State, true)
updateMenuEffects()

notify("ZerkaSense Loaded", "Release 2.0 WindUI build loaded.", "sparkles", 4)
