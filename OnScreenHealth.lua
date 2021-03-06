--[[------------------------------------------------------------
	OnScreenHealth
	Simple text displays of player and target health and power.
	by Phanx <addons@phanx.net>
	http://www.wowinterface.com/downloads/info7470-OnScreenHealth.html
	Copyright � 2007�2008 Alyssa Kinley, a.k.a. Phanx
	See README for license terms and additional information.
	Credits: Alumno, Blink, damjau, rdji
--------------------------------------------------------------]]
local _, OnScreenHealth = ...
OnScreenHealth = LibStub and LibStub("AceAddon-3.0"):NewAddon(OnScreenHealth, "OnScreenHealth", "AceEvent-3.0", "AceConsole-3.0")

--[[------------------------------------------------------------
	Locals
------------------------------------------------------------]]--
local select = select
local type = type
local tonumber = tonumber
local unpack = unpack
local string_find = string.find
local string_format = string.format
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_sub = string.sub

local GameTooltip_UnitColor = GameTooltip_UnitColor
local GetComboPoints = GetComboPoints
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsConnected = UnitIsConnected
local UnitIsGhost = UnitIsGhost
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitName = UnitName
local UnitPowerType = UnitPowerType

local OnScreenHealth = OnScreenHealth
local VERSION = GetAddOnMetadata("OnScreenHealth", "Version"); if VERSION:find("%a") then VERSION = "1.0-dev" end
local db, isPetClass, isComboClass, currentToT
local frame, font, color, text, cur, maxi, perc, kind, _
local tmp1, tmp2, tmp3, tmp4, tmp5, tmp6

local classColors = {}
for class, color in pairs(RAID_CLASS_COLORS) do
	classColors[class] = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

local ICON_LIST = {
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:",
    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:",
}

local SharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)

--[[-------------------------------------------------------------
	Debugging
-------------------------------------------------------------]]--
local debugShow = false
local debugLevel = 2

local Debug = function(lvl, msg)
	if not lvl then lvl = 0 end
	--if debugShow and debugLvl >= lvl then
	--DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7f(DEBUG) OnScreenHealth: ["..date("%H:%M:%S").."."..string_format("%3d", (GetTime() % 1) * 1000).."]|r "..msg)
	if debugShow and msg and debugLevel >= lvl then
		OnScreenHealth:Print("|cff7fff7f OnScreenHealth: "..msg)
	end
end
OnScreenHealth.Debug = Debug

--[[------------------------------------------------------------
	Localization
------------------------------------------------------------]]--
local L

if ONSCREENHEALTH_LOCALS then
	L = setmetatable(ONSCREENHEALTH_LOCALS, { __index = function(self, key) Debug(1, "Missing translation for \""..key.."\".") rawset(self, key, key) return key end })
	ONSCREENHEALTH_LOCALS = nil
else
	L = setmetatable({}, { __index = function(self, key) rawset(self, key, key) return key end })
end
OnScreenHealth.L = L

--[[------------------------------------------------------------
	Utilities
------------------------------------------------------------]]--
local function RGBPercToHex(r, g, b)
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format("%02x%02x%02x", r*255, g*255, b*255)
end

function OnScreenHealth:Short(num)
	if not num then return end
	Debug(3, "Shortening"..num)

	if type(num) == "number" then
		if num >= 10000000 then
			return string_format("%.1fm", num / 1000000)
		elseif num >= 1000000 then
			return string_format("%.2fm", num / 1000000)
		elseif num >= 100000 then
			return string_format("%.0fk", num / 1000)
		elseif num >= 10000 then
			return string_format("%.1fk", num / 1000)
		end
	end
	return num
end

function OnScreenHealth:GetUnitColor(unit)
	if not unit then return end

	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		return db.colorAbsent
	else
		tmp1 = UnitIsPlayer(unit) and classColors[select(2, UnitClass(unit))] or nil
		if tmp1 then
			return tmp1
		else
			tmp1, tmp2, tmp3 = GameTooltip_UnitColor(unit)
			return string.format("%02x%02x%02x", tmp1 * 255, tmp2 * 255, tmp3 * 255)
		end
	end
end

function OnScreenHealth:GetHealthColor(perc, unit)
	if not perc then return end
	Debug(3, "Getting health color")

	if db.colorHealthMode == "CLASS" then
		return self:GetUnitColor(unit)
	elseif db.colorHealthMode == "GRADIENT" then
		if perc <= 0.5 then
			perc = perc * 2
			tmp1, tmp2, tmp3 = unpack(db.colorHealthMin)
			tmp4, tmp5, tmp6 = unpack(db.colorHealthMid)
		else
			perc = perc * 2 - 1
			tmp1, tmp2, tmp3 = unpack(db.colorHealthMid)
			tmp4, tmp5, tmp6 = unpack(db.colorHealthMax)
		end
		return string.format("%02x%02x%02x", (tmp1 + (tmp4 - tmp1) * perc) * 255, (tmp2 + (tmp5 - tmp2) * perc) * 255, (tmp3 + (tmp6 - tmp3) * perc) * 255)
	else
		if perc < 0.33 then
			tmp1, tmp2, tmp3 = unpack(db.colorHealthMin)
		elseif perc < 0.67 then
			tmp1, tmp2, tmp3 = unpack(db.colorHealthMid)
		else
			tmp1, tmp2, tmp3 = unpack(db.colorHealthMax)
		end
		return string.format("%02x%02x%02x", tmp1 * 255, tmp2 * 255, tmp3 * 255)
	end
end

function OnScreenHealth:GetHealthAlpha(perc)
	if not perc then return end
	Debug(3, "Getting health alpha")

	if perc < 0.25 then
		return 1
	else
		return 1.25 - perc
	end
end

function OnScreenHealth:GetFormattedText(text, cur, maxi, withPossibleDeficit)
	if not withPossibleDeficit then withPossibleDeficit = false end
	if not text and cur and maxi then return end
	Debug(3, "Getting formatted text")

	text = string_gsub(text, "$c:s", self:Short(cur))
	text = string_gsub(text, "$c", cur)

	text = string_gsub(text, "$m:s", self:Short(maxi))
	text = string_gsub(text, "$m", maxi)

	text = string_gsub(text, "-$d:s", function() if (maxi-cur) > 0 and withPossibleDeficit then return ("|cffff0000-"..self:Short(maxi - cur)).."|r" end return "" end)

	text = string_gsub(text, "$d:s", self:Short(maxi - cur))
	
	text = string_gsub(text, "-$d", function() if (maxi-cur) > 0 and withPossibleDeficit then return ("|cffff0000-"..self:Short(maxi - cur)).."|r" end return "" end)
	
	text = string_gsub(text, "$d", maxi - cur)

	text = string_gsub(text, "$p", string_format("%.0f", cur / maxi * 100))

	return text
end

--[[------------------------------------------------------------
	Generic updaters
------------------------------------------------------------]]--
function OnScreenHealth:UpdateHealth(unit, unit1)
	unit = unit1 or unit
	Debug(2, "Updating health for "..unit)
	if unit ~= "player" and unit ~= "target" and unit ~= "pet" then return end
	Debug(2, "Updating health for "..unit)

	font2 = false
	if unit == "player" then
		frame, font = OSH_PlayerFrame, OSH_PlayerHealth
	elseif unit == "target" then
		frame, font, font2 = OSH_TargetFrame, OSH_TargetHealth, OSH_TargetPercent
	elseif unit == "pet" then
		frame, font = OSH_PetFrame, OSH_PetHealth
	end
	
	if not frame or not frame:IsShown() then return end
	
	-- ps patch... don't know what for. comment.
	if unit=="player" and font ~= OSH_PlayerHealth then
		return
	end
	if unit=="pet" and font ~= OSH_PetHealth then
		return
	end

	if UnitIsDeadOrGhost(unit) then
		if font2 then
			font2:SetText("")
		end
		if UnitIsGhost(unit) then
			font:SetText("|cff"..db.colorAbsent..L["Ghost"].."|r")
			return
		else
			font:SetText("|cff"..db.colorAbsent..L["Dead"].."|r")
			return
		end
	elseif not UnitIsConnected(unit) then
		font:SetText("|cff"..db.colorAbsent..L["Offline"].."|r")
		if font2 then
			font2:SetText("")
		end
		return
	end

	local cur, maxi = UnitHealth(unit), UnitHealthMax(unit)
	local perc = cur / maxi

	font:SetText("|cff"..self:GetHealthColor(perc, unit)..self:GetFormattedText((unit == "player" and db.textFormatHealthPlayer) or db.textFormatHealthMonster, cur, maxi,true).."|r")
	
	-- ps patch for percentage
	if font2 then
		font2:SetText("|cff"..self:GetHealthColor(perc)..("%.1f%%"):format(perc * 100).."|r")
	end

	if db.alphaMode == "HEALTH" then
		frame:SetAlpha(self:GetHealthAlpha(perc))
	end
	
	self:CheckVisibility(unit)
end

local powerEnumFromEnergizeStringLookup =
{
	MANA = Enum.PowerType.Mana,
	RAGE = Enum.PowerType.Rage,
	FOCUS = Enum.PowerType.Focus,
	ENERGY = Enum.PowerType.Energy,
	COMBO_POINTS = Enum.PowerType.ComboPoints,
	RUNES = Enum.PowerType.Runes,
	RUNIC_POWER = Enum.PowerType.RunicPower,
	SOUL_SHARDS = Enum.PowerType.SoulShards,
	LUNAR_POWER = Enum.PowerType.LunarPower,
	HOLY_POWER = Enum.PowerType.HolyPower,
	ALTERNATE = Enum.PowerType.Alternate,
	MAELSTROM = Enum.PowerType.Maelstrom,
	CHI = Enum.PowerType.Chi,
	ARCANE_CHARGES = Enum.PowerType.ArcaneCharges,
	FURY = Enum.PowerType.Fury,
	PAIN = Enum.PowerType.Pain,
	INSANITY = Enum.PowerType.Insanity,
}

function OnScreenHealth:GetPowerEnumFromEnergizeString(power)
	return powerEnumFromEnergizeStringLookup[power] or Enum.PowerType.NumPowerTypes;
end

function OnScreenHealth:UNIT_PET(unit)
	self:UpdatePet()
end

function OnScreenHealth:PLAYER_CONTROL_GAINED()
	self:UpdateAll()
end

function OnScreenHealth:PLAYER_CONTROL_LOST()
	self:UpdateAll()
end

function OnScreenHealth:PET_BAR_UPDATE()
	self:UpdatePet()
end

function OnScreenHealth:PET_UI_UPDATE()
	self:UpdatePet()
end

function OnScreenHealth:UPDATE_VEHICLE_ACTIONBAR()
	self:UpdatePet()
end

function OnScreenHealth:PLAYER_FARSIGHT_FOCUS_CHANGED()
	self:UpdatePet()
end

function OnScreenHealth:PET_BAR_UPDATE_USABLE()
	self:UpdatePet()
end

function OnScreenHealth:PLAYER_MOUNT_DISPLAY_CHANGED()
	self:UpdatePet()
end





function OnScreenHealth:UpdatePower(unit, unit1, powertype)
	if powertype ~= nil then
		Debug(2, "Updating powertype "..powertype)
		if powertype == "COMBO_POINTS" and db.targetShowCP then
		 	self:UpdateCP()
		end
	end
	unit = unit1 or unit
	if unit ~= "player" and unit ~= "target" and unit ~= "pet" then return end
	Debug(2, "Updating power for "..unit)

	if unit == "player" then
		frame, font, fontSecondaryPower = OSH_PlayerFrame, OSH_PlayerPower, OSH_PlayerSecondaryPower
	elseif unit == "target" then
		frame, font = OSH_TargetFrame, OSH_TargetPower
	elseif unit == "pet" then
		frame, font = OSH_PetFrame, OSH_PetPower
	end
	
	if not frame or not frame:IsShown() then return end

	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) or UnitPowerMax(unit) == 0 then
		font:SetText(" ")
		return
	end
	
	-- Secondary power
	local secondaryPowers = {
		"RUNES",
		"SOUL_SHARDS",
		"LUNAR_POWER",
		"HOLY_POWER",
		"MAELSTROM_POWER",
		"CHI",
		"ARCANE_CHARGES"
	}
	if unit == "player" and powertype ~= nil and tContains(secondaryPowers, powertype) then
		secondaryPower = UnitPower(unit, self:GetPowerEnumFromEnergizeString(powertype)) or 0
		color = PowerBarColor[powertype] or db.colorDefault
		if type(color) == "table" then
			color = RGBPercToHex(color.r, color.g, color.b)
		end
		Debug(3, "Secondary power: "..secondaryPower)
		if secondaryPower ~= 0 then
			fontSecondaryPower:SetText("|cff"..color..secondaryPower.."|r")
		else
			fontSecondaryPower:SetText(" ")
		end
	end

	local withPossibleDeficit = false
	local _, powertype = UnitPowerType(unit)
	if powertype == "MANA" then
		color = db.colorMana
		withPossibleDeficit = true
	elseif powertype == "ENERGY" then
		color = db.colorEnergy
	elseif powertype == "RAGE" then
		color = db.colorRage
	elseif powertype == "RUNIC_POWER" then
		color = db.colorRunicPower
	elseif powertype == "FOCUS" then
		color = db.colorFocus
	else
		color = db.colorDefault
	end	

	font:SetText("|cff"..color..self:GetFormattedText(UnitIsPlayer(unit) and db.textFormatPowerPlayer or db.textFormatPowerMonster, UnitPower(unit), UnitPowerMax(unit) , withPossibleDeficit).."|r")
	
	self:CheckVisibility(unit)
end

--[[------------------------------------------------------------
	We like to hide Pets and Players that are at max and not in combat.
------------------------------------------------------------]]--
function OnScreenHealth:CheckVisibility(unit)
	if (unit == "pet") and ((not UnitExists("pet")) or (not UnitIsConnected("pet"))) and (not UnitInVehicle("player")) then
		OSH_PetFrame:Hide()
		return false
	end
	if unit == "pet" and  UnitInVehicle("player") then
		unit = "vehicle"
	end
	if (unit ~= "player" and unit ~= "pet" and unit ~= "vehicle") or UnitAffectingCombat(unit) or db.playerShowOOC then
		return true
	end
	
	cur, maxi = UnitHealth(unit), UnitHealthMax(unit)
	curM, maxM = UnitPower(unit), UnitPowerMax(unit)
	
	Debug(1, "CheckVisibility for "..unit.."("..cur.."|"..maxi..")("..curM.."|"..maxM..")")
	if unit == "player" then
		if cur == maxi then
			kind = UnitPowerType("player")
			if (curM == maxM or (curM == 0 and kind == 1)) then
				OSH_PlayerFrame:Hide()
				return false
			end
		end
	elseif unit == "pet" then
		if (cur == maxi) or (not UnitExists("pet")) or (not UnitIsConnected("pet")) then
			OSH_PetFrame:Hide()
			return false
		end
	elseif unit == "vehicle" then
		if (cur == maxi) then
			OSH_PetFrame:Hide()
			return false
		end
	end
	return true
end

--[[------------------------------------------------------------
	Unit-specific updaters
------------------------------------------------------------]]--
function OnScreenHealth:UpdateAll(type)
	if type and type == "health" then
		self:UpdateHealth("player")
		self:UpdateHealth("target")
		if UnitExists("pet") then
			self:UpdateHealth("pet")
		end
	elseif type and type == "power" and db.showPower then
		self:UpdatePower("player")
		self:UpdatePower("target")
		if UnitExists("pet") then
			self:UpdatePower("pet")
		end
	else
		self:UpdatePlayer()
		self:UpdateTarget()
		if UnitExists("pet") then
			self:UpdatePet("player")
		end
	end
end

function OnScreenHealth:UpdatePlayer()
	if not db.playerEnable or not (db.playerShowOOC or UnitAffectingCombat("player")) or not (db.playerShowDead or not UnitIsDeadOrGhost("player")) then
		self:CheckVisibility("player")
		return
	end
	
	Debug(1, "Updating player")

	OSH_PlayerFrame:Show()
	self:UpdateHealth("player")
	if db.showPower then
		self:UpdatePower("player")
	end
	if db.playerShowCombatStatus then
		self:UpdateCombatStatus("player")
	end
end

function OnScreenHealth:UpdateCombatStatus(unit)
	if not unit then unit = "player" end
	Debug(1, "Updating "..unit.." status")

	if db[unit.."ShowCombatStatus"] and UnitAffectingCombat(unit) then
		OSH_PlayerStatus:SetText("|cff"..db.colorCombatStatus.."+|r")
	else
		OSH_PlayerStatus:SetText()
	end
end

function OnScreenHealth:UpdatePet(owner)
	if owner and owner ~= "player" or db.disablePet then return end
	-- ps patch
	--if not db.petEnable or (not db.playerShowOOC and not UnitAffectingCombat("player") and not UnitAffectingCombat("pet")) or (not db.petShowDead and UnitIsDeadOrGhost("pet")) or not UnitExists("pet") then
	if not db.petEnable or (not UnitAffectingCombat("player") and not UnitAffectingCombat("pet")) or (not db.petShowDead and UnitIsDeadOrGhost("pet")) or not UnitExists("pet") then
		Debug(1, "Check Pet visibility")
		show = self:CheckVisibility("pet")
		if not show then
			 return -- pet frame was hidden
		end
	end
	Debug(1, "Updating pet")

	OSH_PetFrame:Show()
	if db.alphaMode == "COMBAT" then
		if UnitAffectingCombat("pet") or UnitAffectingCombat("player") then
			OSH_TargetFrame:SetAlpha(db.alphaCombat)
		else
			OSH_TargetFrame:SetAlpha(db.alphaOOC)
		end
	end
	self:UpdateHealth("pet")
	if db.showPower then
		self:UpdatePower("pet")
	end
end

function OnScreenHealth:UpdateTarget()
	if not UnitExists("target") or not db.targetEnable or not (db.targetShowOOC or UnitAffectingCombat("player")) or not (db.targetShowDead or (not UnitIsDeadOrGhost("target") and UnitIsConnected("target"))) then
		OSH_TargetFrame:SetAlpha(db.alphaOOC)
		OSH_TargetFrame:Hide()
		currentToT = nil
		return
	end
	Debug(1, "Updating target")

	OSH_TargetFrame:Show()
	
	if UnitIsEnemy("player","target") or UnitAffectingCombat("player") then
		OSH_TargetFrame:SetAlpha(db.alphaCombat)
	elseif not UnitAffectingCombat("player") then
		OSH_TargetFrame:SetAlpha(db.alphaOOC)
	end
	
	self:UpdateHealth("target")
	if db.showPower then
		self:UpdatePower("target")
	end
	if db.targetShowCP then
		self:UpdateCP()
	end
	
	self:UpdateTargetIcon()
end

function OnScreenHealth:CheckToT()
	tmp1 = UnitExists("targettarget") and UnitName("targettarget") or "NONE"
	if currentToT ~= tmp1 then
		currentToT = tmp1
		OnScreenHealth:UpdateToT()
	end
end

function OnScreenHealth:UpdateToT()
	if UnitExists("target") and UnitExists("targettarget") then
		if UnitIsUnit("player", "targettarget") then
			OSH_TargetTarget:SetText("|cff"..db.colorTargetSelf..L["<<YOU>>"].."|r")
			return
		else
			OSH_TargetTarget:SetText("|cff"..self:GetUnitColor("targettarget")..UnitName("targettarget").."|r")
			return
		end
	else
		OSH_TargetTarget:SetText(nil)
	end
end

function OnScreenHealth:UpdateCP()
	local isInVehicle = UnitHasVehicleUI("player")
	local tmp1 = GetComboPoints("player", "target")
	local tmp2 = 0		
	if isInVehicle then
		tmp2 = UnitPower("vehicle", 4)
	end	
	if tmp1 == 0 and tmp2 == 0 then -- no combo points
		OSH_TargetCombo:SetText()
	else
		if tmp1 ~= 0 and tmp2 ~= 0 then -- player and vehicle points ~= 0
			OSH_TargetCombo:SetText("|cff"..db.colorCombo..tmp1.." | "..tmp2.."|r")
		else
			if tmp2 == 0 then -- player points only
				OSH_TargetCombo:SetText("|cff"..db.colorCombo..tmp1.."|r")
			else -- vehicle points only
				OSH_TargetCombo:SetText("|cff"..db.colorCombo..tmp2.."|r")
			end
		end		
	end
end

--[[------------------------------------------------------------
	Event handlers
------------------------------------------------------------]]--
function OnScreenHealth:EnterCombat()
	Debug(1, "Entering combat")
	self:UpdatePlayer()
	self:UpdateCP() -- added to make sure CP are cleared before Combat
	if UnitExists("pet") then
		self:UpdatePet()
	end
	self:UpdateTarget()
	if db.alphaMode == "COMBAT" then
		tmp1 = db.alphaCombat
		OSH_PlayerFrame:SetAlpha(tmp1)
		OSH_TargetFrame:SetAlpha(tmp1)
		OSH_TargetIcon:SetAlpha(tmp1)
		if UnitExists("pet") then
			OSH_PetFrame:SetAlpha(tmp1)
		end
	end
end

function OnScreenHealth:LeaveCombat()
	Debug(1, "Leaving combat")
	self:UpdatePlayer()
	self:UpdateCP() -- added to make sure CP are cleared after Combat
	if UnitExists("pet") then
		self:UpdatePet()
	end
	if not db.targetShowOOC then
		self:UpdateTarget()
	end
	if db.alphaMode == "COMBAT" then
		tmp1 = db.alphaOOC
		OSH_PlayerFrame:SetAlpha(tmp1)
		OSH_TargetFrame:SetAlpha(tmp1)
		OSH_TargetIcon:SetAlpha(tmp1)
		if UnitExists("pet") then
			OSH_PetFrame:SetAlpha(tmp1)
		end
	end
	self:CheckVisibility("player")
	self:CheckVisibility("pet")
end

function OnScreenHealth:PlayerDead()
	Debug(1, "Died")
	self:UpdateCombatStatus("player")
	OSH_PlayerFrame:Hide()
	if UnitExists("pet") then
		OSH_PetFrame:Hide()
	end
end

function OnScreenHealth:PlayerAlive()
	Debug(1, "Resurrected")
	--if not UnitIsGhost("player") and db.playerShowOOC or UnitAffectingCombat("player") then
	--	OSH_PlayerFrame:Show()
	--	self:UpdateHealth("player")
	--	if db.showPower then
	--		self:UpdatePower("player")
	--	end
	--	if UnitExists("pet") then
	--		self:UpdatePet()
	--	end
	--end
	self:UpdatePlayer()
	self:UpdatePet()
	if db.alphaMode == "COMBAT" then
		tmp1 = db.alphaOOC
		OSH_PlayerFrame:SetAlpha(tmp1)
		OSH_TargetFrame:SetAlpha(tmp1)
		if UnitExists("pet") then
			OSH_PetFrame:SetAlpha(tmp1)
		end
	end
end

function OnScreenHealth:UpdateTargetIcon()
	if not UnitExists("target") or not db.targetEnable or not (db.targetShowOOC or UnitAffectingCombat("player")) or not (db.targetShowDead or (not UnitIsDeadOrGhost("target") and UnitIsConnected("target"))) then
		OSH_TargetFrame:SetAlpha(db.alphaOOC)
		OSH_TargetIcon:SetAlpha(db.alphaOOC)
		OSH_TargetIcon:Hide()
		OSH_TargetIcon:SetText("")
		currentToT = nil
		return
	end
	Debug(1, "Updating target icon")
	
	local index = GetRaidTargetIndex("target")
	if index then
		OSH_TargetIcon:Show()
		OSH_TargetIcon:SetText(ICON_LIST[index].."0|t")
	else
		OSH_TargetIcon:Hide()
		OSH_TargetIcon:SetText("")
	end
	
	if UnitIsEnemy("player","target") or UnitAffectingCombat("player") then
		OSH_TargetIcon:SetAlpha(db.alphaCombat)
	elseif not UnitAffectingCombat("player") then
		OSH_TargetIcon:SetAlpha(db.alphaOOC)
	end
end

--[[------------------------------------------------------------
	Frame creation and manipulation
------------------------------------------------------------]]--
function OnScreenHealth:CreateFrames()
	Debug(1, "Creating frames")
	local pf, ph, pp, ps, php, mf, mh, mp, tf, th, tp, tt, tc, tp2, ti

	if db.fontShadow then
		tmp1, tmp2 = 1, -1
	else
		tmp1, tmp2 = 0, 0
	end

	pf = CreateFrame("Frame", "OSH_PlayerFrame", UIParent)
	pf:SetFrameStrata("BACKGROUND")
	pf:SetFrameLevel(0)
	pf:SetWidth(100)
	pf:SetHeight(50)

	-- health
	ph = pf:CreateFontString("OSH_PlayerHealth", "OVERLAY")
	ph:SetShadowOffset(tmp1, tmp2)

	-- power
	pp = pf:CreateFontString("OSH_PlayerPower", "OVERLAY")
	pp:SetShadowOffset(tmp1, tmp2)

	-- status
	ps = pf:CreateFontString("OSH_PlayerStatus", "OVERLAY")
	ps:SetShadowOffset(tmp1, tmp2)
	
	-- secondary power
	php = pf:CreateFontString("OSH_PlayerSecondaryPower", "OVERLAY")
	php:SetShadowOffset(tmp1, tmp2)

	mf = CreateFrame("Frame", "OSH_PetFrame", UIParent)
	mf:SetFrameStrata("BACKGROUND")
	mf:SetFrameLevel(0)
	mf:SetWidth(100)
	mf:SetHeight(50)

	mh = mf:CreateFontString("OSH_PetHealth", "OVERLAY")
	mh:SetShadowOffset(tmp1, tmp2)

	mp = mf:CreateFontString("OSH_PetPower", "OVERLAY")
	mp:SetShadowOffset(tmp1, tmp2)

	tf = CreateFrame("Frame", "OSH_TargetFrame", UIParent)
	tf:SetFrameStrata("BACKGROUND")
	tf:SetFrameLevel(0)
	tf:SetWidth(100)
	tf:SetHeight(50)

	th = tf:CreateFontString("OSH_TargetHealth", "OVERLAY")
	th:SetShadowOffset(tmp1, tmp2)

	tp = tf:CreateFontString("OSH_TargetPower", "OVERLAY")
	tp:SetShadowOffset(tmp1, tmp2)

	tt = tf:CreateFontString("OSH_TargetTarget", "OVERLAY")
	tt:SetShadowOffset(tmp1, tmp2)
	
	ti = tf:CreateFontString("OSH_TargetIcon", "OVERLAY")
	ti:SetShadowOffset(tmp1, tmp2)
	
	tp2 = tf:CreateFontString("OSH_TargetPercent", "OVERLAY")
	tp2:SetShadowOffset(tmp1, tmp2)

	--if isComboClass then
		tc = tf:CreateFontString("OSH_TargetCombo", "OVERLAY")
		tc:SetShadowOffset(tmp1, tmp2)
	--end

	if db.alphaMode == "COMBAT" then
		tmp3 = UnitAffectingCombat("player") and ( db.alphaCombat or 1) or ( db.alphaOOC or 0.5)
	else
		tmp3 = db.alphaFixed
	end
	pf:SetAlpha(tmp3)
	tf:SetAlpha(tmp3)
	mf:SetAlpha(tmp3)

	self:ApplyPositions()
	self:ApplyFonts()
	self:UpdatePlayer()
	self:UpdateTarget()
	if UnitExists("pet") then
		self:UpdatePet()
	end
end

function OnScreenHealth:ApplyPositions()
	Debug(1, "Setting frame positions")

	if db.textAlign == "CENTER" then
		tmp1, tmp2, tmp3, tmp4, tmp5, tmp6 = "TOP", "BOTTOM", "CENTER", "TOP", "BOTTOM", "CENTER"
	elseif db.textAlign == "OUTSIDE" then
		tmp1, tmp2, tmp3, tmp4, tmp5, tmp6 = "TOPLEFT", "BOTTOMLEFT", "LEFT", "TOPRIGHT", "BOTTOMRIGHT", "RIGHT"
	else
		tmp1, tmp2, tmp3, tmp4, tmp5, tmp6 = "TOPRIGHT", "BOTTOMRIGHT", "RIGHT", "TOPLEFT", "BOTTOMLEFT", "LEFT"
	end

	Debug(1, "PosX ".. db.posX)
	Debug(1, "PosY ".. db.posY)

	OSH_PlayerFrame:ClearAllPoints()
	OSH_PlayerFrame:SetPoint(tmp1, UIParent, "CENTER", -db.posX, db.posY)
	OSH_PlayerHealth:ClearAllPoints()
	OSH_PlayerHealth:SetPoint(tmp1, OSH_PlayerFrame, tmp1, 0, 0)
	OSH_PlayerHealth:SetJustifyH(tmp3)
	OSH_PlayerPower:ClearAllPoints()
	OSH_PlayerPower:SetPoint(tmp1, OSH_PlayerHealth, tmp2, 0, 0)
	OSH_PlayerPower:SetJustifyH(tmp3)
	OSH_PlayerStatus:ClearAllPoints()
	OSH_PlayerStatus:SetPoint(tmp2, OSH_PlayerHealth, tmp1, 0, 0)
	OSH_PlayerStatus:SetJustifyH(tmp3)

	OSH_PlayerSecondaryPower:ClearAllPoints()
	OSH_PlayerSecondaryPower:SetPoint(tmp2, OSH_PlayerHealth, tmp1, 0, 10)
	OSH_PlayerSecondaryPower:SetJustifyH(tmp3)

	OSH_TargetFrame:ClearAllPoints()
	OSH_TargetFrame:SetPoint(tmp4, UIParent, "CENTER", db.posX, db.posY)
	OSH_TargetHealth:ClearAllPoints()
	OSH_TargetHealth:SetPoint(tmp4, OSH_TargetFrame, tmp4, 0, 0)
	OSH_TargetHealth:SetJustifyH("CENTER")
	OSH_TargetPower:ClearAllPoints()
	OSH_TargetPower:SetPoint(tmp4, OSH_TargetHealth, tmp5, 0, 0)
	OSH_TargetPower:SetJustifyH(tmp6)
	OSH_TargetTarget:ClearAllPoints()
	OSH_TargetTarget:SetPoint(tmp4, OSH_TargetPower, tmp5, 0, 0)
	OSH_TargetTarget:SetJustifyH(tmp6)
	
	OSH_TargetPercent:ClearAllPoints()
	OSH_TargetPercent:SetPoint("LEFT", OSH_TargetHealth, "RIGHT", 10, 0)
	OSH_TargetPercent:SetJustifyH(tmp6)
	
	OSH_TargetIcon:ClearAllPoints()
	OSH_TargetIcon:SetPoint("RIGHT", OSH_TargetHealth, "LEFT", 0, 0)
	OSH_TargetIcon:SetJustifyH(tmp6)

	-- combo class
	OSH_TargetCombo:ClearAllPoints()
	OSH_TargetCombo:SetPoint(tmp5, OSH_TargetHealth, tmp4, 0, 0)
	OSH_TargetCombo:SetJustifyH(tmp6)

	-- pet frame
	OSH_PetFrame:ClearAllPoints()
	OSH_PetFrame:SetPoint(tmp2, OSH_PlayerFrame, tmp1, 0, db.posPet)
	OSH_PetHealth:ClearAllPoints()
	OSH_PetHealth:SetPoint(tmp1, OSH_PetFrame, tmp1, 0, 0)
	OSH_PetHealth:SetJustifyH(tmp3)
	OSH_PetPower:ClearAllPoints()
	OSH_PetPower:SetPoint(tmp1, OSH_PetHealth, tmp2, 0, 0)
	OSH_PetPower:SetJustifyH(tmp3)
end

function OnScreenHealth:ApplyFonts()
	tmp1 = SharedMedia and SharedMedia:Fetch("font", db.fontFace) or "Fonts\\FRIZQT__.ttf"
	tmp2, tmp3, tmp4 = db.fontSizeHealth, db.fontSizePower, db.fontOutline
	OSH_PlayerHealth:SetFont(tmp1, tmp2, tmp4)
	OSH_PlayerPower:SetFont(tmp1, tmp3, tmp4)
	OSH_PlayerStatus:SetFont(tmp1, tmp3, tmp4)
	OSH_PlayerSecondaryPower:SetFont(tmp1, db.fontSizeCombo, tmp4)
	OSH_TargetHealth:SetFont(tmp1, tmp2, tmp4)
	OSH_TargetPower:SetFont(tmp1, tmp3, tmp4)
	OSH_TargetTarget:SetFont(tmp1, db.fontSizeTarget, tmp4)
	OSH_TargetPercent:SetFont(tmp1, db.fontSizeTargetPercent, tmp4)
	OSH_TargetIcon:SetFont(tmp1, db.fontSizeTargetPercent, tmp4)
		OSH_TargetCombo:SetFont(tmp1, db.fontSizeCombo, tmp4)
		OSH_PetHealth:SetFont(tmp1, tmp2 * db.fontSizePet, tmp4)
		OSH_PetPower:SetFont(tmp1, tmp3 * db.fontSizePet, tmp4)
end

--[[------------------------------------------------------------
--	Event registration
------------------------------------------------------------]]--
function OnScreenHealth:UpdatePowerEvents()
	if db.showPower then
		self:RegisterEvent("UNIT_DISPLAYPOWER", "UpdatePower")
		self:RegisterEvent("RAID_TARGET_UPDATE", "UpdateTargetIcon")
		self:RegisterEvent("UNIT_POWER_UPDATE", "UpdatePower")
		self:RegisterEvent("UNIT_MAXPOWER", "UpdatePower")
	else
		self:UnregisterEvent("UNIT_DISPLAYPOWER")
		self:UnregisterEvent("RAID_TARGET_UPDATE")
		self:UnregisterEvent("UNIT_POWER_UPDATE", "UpdatePower")
		self:UnregisterEvent("UNIT_MAXPOWER", "UpdatePower")
		end	
end

function OnScreenHealth:UpdateCombatEvents()
	if db.playerShowOOC and db.targetShowOOC and db.alphaMode ~= "COMBAT" and not db.playerShowCombatStatus then
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	else
		self:RegisterEvent("PLAYER_REGEN_DISABLED", "EnterCombat")
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "LeaveCombat")
	end
end

function OnScreenHealth:UpdateDeathEvents()
	if db.playerShowDead then
		self:UnregisterEvent("PLAYER_ALIVE")
		self:UnregisterEvent("PLAYER_DEAD")
	else
		self:RegisterEvent("PLAYER_ALIVE", "PlayerAlive")
		self:RegisterEvent("PLAYER_UNGHOST", "PlayerAlive")
		self:RegisterEvent("PLAYER_DEAD", "PlayerDead")
	end
end

local defaults = {
	profile = {
		playerEnable = true,
		playerShowDead = false,
		playerShowOOC = true,
		playerShowCombatStatus = false,
		playerFrequentUpdates = false,
		targetEnable = true,
		targetShowDead = true,
		targetShowOOC = true,
		targetShowCP = true,
		targetShowToT = false,
		petEnable = true,
		petShowDead = false,
		alphaMode = "FIXED",
		alphaFixed = 1,
		alphaCombat = 1,
		alphaOOC = 0.5,
		colorHealthMode = "GRADIENT",
		showPower = true,
		textAlign = "INSIDE",
		textFormatHealthMonster = "$c",
		textFormatHealthPlayer = "$c",
		textFormatPowerMonster = "$c",
		textFormatPowerPlayer = "$c",
		fontFace = "Friz Quadrata TT",
		fontOutline = "OUTLINE",
		fontShadow = true,
		fontSizeHealth = 32,
		fontSizePower = 24,
		fontSizeTarget = 24,
		fontSizeTargetPercent = 16,
		fontSizeCombo = 24,
		fontSizePet = 0.8,
		colorHealthMax = { 0, 1, 0 },
		colorHealthMid = { 1, 1, 0 },
		colorHealthMin = { 1, 0, 0 },
		colorMana = "0000FF",
		colorFocus = "FF9933",
		colorRage = "FF0000",
		colorEnergy = "FFFF00",
		colorRunicPower = "00D1FF",
		colorAbsent = "999999",
		colorCombatStatus = "FFFFFF",
		colorCombo = "FF7F00",
		colorTargetSelf = "FFFFFF",
		colorDefault = "FF00FF", -- Fallback
		posX = 200,
		posY = 0,
		posPet = 20,
		version = VERSION
	}
}

--[[------------------------------------------------------------
	Initialization
------------------------------------------------------------]]--
function OnScreenHealth:OnInitialize()
	_, tmp1 = UnitClass("player")

	self.db = LibStub("AceDB-3.0"):New("OnScreenHealthDB", defaults, "Default")
	db = self.db.profile

	--
	-- upgrade from old health formats
	--
	local upgradePaths = {
		["VALUE"] = "$c",
		["VALUE-S"] = "$c:s",
		["DEF"] = "$d",
		["DEF-S"] = "$d:s",
		["PER"] = "$p%",
		["PER-N"] = "$p",
		["VALUE-DEF"] = "$c-$d",
		["VALUE-DEF-S"] = "$c:s-$d:s",
		["VALUE-PER"] = "$c ($p%)",
		["VALUE-PER-N"] = "$c ($p)",
		["VALUE-PER-M"] = "$c$n$p%",
		["VALUE-PER-N-M"] = "$c$n$p"
	}
	local upgradeKeys = {
		"textFormatHealthMonster",
		"textFormatHealthPlayer",
		"textFormatPowerMonster",
		"textFormatPowerPlayer"
	}
	local old, new
	for _, k in ipairs(upgradeKeys) do
		new = upgradePaths[db[k]]
		if new then
			db[k] = new
		end
	end
	--
	-- end upgrade
	--

	self:LoadOptions()
end

function OnScreenHealth.FrequentUpdate(frame, elapsed)
	OnScreenHealth:UpdatePower("player")
end

function OnScreenHealth:OnEnable()
	Debug(1, "Enabling")
	if not OSH_PlayerFrame then
		self:CreateFrames()
	end

	self:RegisterEvent("UNIT_HEALTH", "UpdateHealth")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateTarget")
	self:RegisterEvent("PLAYER_TALENT_UPDATE", "UpdateAll")

	self:UpdatePowerEvents()
	self:UpdateCombatEvents()
	self:UpdateDeathEvents()

	Debug(1, "Registering pet events")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PLAYER_CONTROL_GAINED")
	self:RegisterEvent("PLAYER_CONTROL_LOST")
	self:RegisterEvent("PET_BAR_UPDATE")
	self:RegisterEvent("PET_UI_UPDATE")
	self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
	self:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED")
	self:RegisterEvent("PET_BAR_UPDATE_USABLE")
	self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

	if db.playerFrequentUpdates then
		OSH_PlayerFrame:SetScript("OnUpdate", OnScreenHealth.FrequentUpdate)
	end

	if db.targetShowToT then
		OSH_TargetFrame:SetScript("OnUpdate", OnScreenHealth.CheckToT)
	end

	if db.alphaMode == "COMBAT" then
		tmp1 = db.alphaOOC
		OSH_PlayerFrame:SetAlpha(tmp1)
		OSH_PlayerFrame:Show()
		self:CheckVisibility("player")
		OSH_TargetFrame:SetAlpha(tmp1)
		OSH_TargetIcon:SetAlpha(tmp1)
		if UnitExists("pet") then
			OSH_PetFrame:SetAlpha(tmp1)
			self:CheckVisibility("pet")
		end
	end
end

function OnScreenHealth:OnDisable()
	Debug(1, "Disabling")
	OSH_PlayerFrame:Hide()
	OSH_TargetFrame:Hide()
		OSH_PetFrame:Hide()
end

function OnScreenHealth:OnProfileChanged(event, database, newProfileKey)
	Debug(1, "OnProfileChanged")
	local oldDB = db
	db = database.profile
	self:UpdateAll("health")
	self:UpdateAll("power")
end
