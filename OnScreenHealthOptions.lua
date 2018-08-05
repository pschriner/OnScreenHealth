--[[------------------------------------------------------------
	OnScreenHealth
	Simple text displays of player and target health and power.
	by Phanx <addons@phanx.net>
	http://www.wowinterface.com/downloads/info7470-OnScreenHealth.html
	Copyright © 2007–2008 Alyssa Kinley, a.k.a. Phanx
	See README for license terms and additional information.
	Credits: Alumno, Blink, damjau, rdji

	This file provides a configuration GUI. If you do not need
	a configuration GUI, you may delete this file to reduce
	OnScreenHealth's memory footprint.
--------------------------------------------------------------]]

if not OnScreenHealth then return end

local OnScreenHealth, self = OnScreenHealth, OnScreenHealth
local string_find = string.find
local string_format = string.format
local tonumber = tonumber
local type = type
local unpack = unpack

local noCombo, noPet
do
	local class = select(2, UnitClass("player"))
	noCombo = class ~= "DRUID" and class ~= "ROGUE"
	noPet = class ~= "HUNTER" and class ~= "WARLOCK"
end

local function getColor(k)
	local tmp = self.db.profile[k]
	if not tmp then
		return
	elseif type(tmp) == "table" then
		return unpack(tmp)
	else
		return tonumber(tmp:sub(1, 2), 16) / 255, tonumber(tmp:sub(3, 4), 16) / 255, tonumber(tmp:sub(5, 6), 16) / 255
	end
end

local function setColor(k, r, g, b)
	local tmp = self.db.profile[k]
	if not tmp then
		return
	elseif type(tmp) == "table" then
		self.db.profile[k][1] = r
		self.db.profile[k][2] = g
		self.db.profile[k][3] = b
	else
		self.db.profile[k] = string_format("%02x%02x%02x", r * 255, g * 255, b * 255)
	end
	if string_find(k, "Health") then
		self:UpdateAll("health")
	else
		-- Currently only using this for health and mana colors
		-- Will require changes if used for other color types!
		self:UpdateAll("power")
	end
end

local function getPos(k)
	return self.db.profile[k]
end

local function setPos(k, v)
	self.db.profile[k] = v
	self:ApplyPositions()
end

function OnScreenHealth:LoadOptions()
	db = self.db.profile

	local L = self.L
	local Debug = self.Debug

	self.options = {
		type = "group",
		args = {
			player = {
				order = 100,
				name = L["Player"],
				desc = L["Basic options for the player display."],
				type = "group",
				args = {
					enable = {
						order = 110,
						name = L["Enable"],
						desc = L["Enable the player display."],
						type = "toggle",
						get = function() return db.playerEnable end,
						set = function(v)
							db.playerEnable = v
							self:UpdatePlayer()
							if not noPet then self:UpdatePet() end
						end
					},
					showDead = {
						order = 120,
						name = L["Show Dead"],
						desc = L["Show the player display while you are dead."],
						type = "toggle",
						get = function() return db.playerShowDead end,
						set = function(v)
							db.playerShowDead = v
							self:UpdateDeathEvents()
							self:UpdatePlayer()
							if not noPet then self:UpdatePet() end
						end
					},
					showOOC = {
						order = 130,
						name = L["Show OOC"],
						desc = L["Show the player display while you are out of combat."],
						type = "toggle",
						get = function() return db.playerShowOOC end,
						set = function(v)
							db.playerShowOOC = v
							self:UpdateCombatEvents()
							self:UpdatePlayer()
							if not noPet then self:UpdatePet() end
						end
					},
					showCombatStatus = {
						order = 140,
						name = L["Show Combat Status"],
						desc = L["Show an indicator above player health while you are in combat."],
						type = "toggle",
						get = function() return db.playerShowCombatStatus end,
						set = function(v)
							db.playerShowCombatStatus = v
							self:UpdateCombatEvents()
							self:UpdatePlayer()
						end,
					},
					frequentUpdates = {
						order = 150,
						name = L["Frequent Power Updates"],
						desc = L["Enable updating the power text more frequently than normal."],
						type = "toggle",
						get = function() return db.playerFrequentUpdates end,
						set = function(v)
							db.playerFrequentUpdates = v
							if v then
								OSH_PlayerFrame:SetScript("OnUpdate", OnScreenHealth.FrequentUpdate)
							else
								OSH_PlayerFrame:SetScript("OnUpdate", nil)
							end
						end
					}
				}
			},
			pet = {
				order = 200,
				name = L["Pet"],
				desc = L["Basic options for the pet display."],
				disabled = noPet,
				hidden = noPet,
				type = "group",
				args = {
					enable = {
						order = 210,
						name = L["Enable"],
						desc = L["Enable the pet display."],
						type = "toggle",
						get = function() return db.petEnable end,
						set = function(v)
							db.petEnable = v
							self:UpdatePet()
						end,
					},
					showDead = {
						order = 220,
						name = L["Show Dead"],
						desc = L["Show the pet display while your pet is dead."],
						type = "toggle",
						get = function() return db.petShowDead end,
						set = function(v)
							db.petShowDead = v
							self:UpdatePet()
						end
					}
				}
			},
			target = {
				order = 300,
				name = L["Target"],
				desc = L["Basic options for the target display."],
				type = "group",
				args = {
					enable = {
						order = 310,
						name = L["Enable"],
						desc = L["Enable the target display."],
						type = "toggle",
						get = function() return db.targetEnable end,
						set = function(v)
							db.targetEnable = v
							self:UpdateTarget()
						end
					},
					showDead = {
						order = 320,
						name = L["Show Dead"],
						desc = L["Show the target display while your target is dead or offline."],
						type = "toggle",
						get = function() return db.targetShowDead end,
						set = function(v)
							db.targetShowDead = v
							self:UpdateTarget()
						end
					},
					showOOC = {
						order = 330,
						name = L["Show OOC"],
						desc = L["Show the target display while you are out of combat."],
						type = "toggle",
						get = function() return db.targetShowOOC end,
						set = function(v)
							db.targetShowOOC = v
							self:UpdateCombatEvents()
							self:UpdateTarget()
						end
					},
					showCP = {
						order = 340,
						name = L["Combo Points"],
						desc = L["Show your combo points."],
						disabled = noCombo,
						hidden = noCombo,
						type = "toggle",
						get = function() return db.targetShowCP end,
						set = function(v)
							db.targetShowCP = v
							if v then
								if not self:IsEventRegistered("UNIT_COMBO_POINTS") then
									self:RegisterEvent("UNIT_COMBO_POINTS", "UpdateCP")
								end
								self:UpdateCP()
							else
								if self:EventIsRegistered("UNIT_COMBO_POINTS") then
									self:UnregisterEvent("UNIT_COMBO_POINTS")
								end
								OSH_TargetCombo:SetText()
							end
						end
					},
					showToT = {
						order = 350,
						name = L["Target of Target"],
						desc = L["Show the name of your target's target."],
						type = "toggle",
						get = function() return db.targetShowToT end,
						set = function(v)
							db.targetShowToT = v
							if v then
								OSH_TargetFrame:SetScript("OnUpdate", OnScreenHealth.CheckToT)
							else
								OSH_TargetFrame:SetScript("OnUpdate", nil)
							end
						end
					}
				}
			},
			appearance = {
				order = 600,
				name = L["Appearance"],
				desc = L["Options related to general appearance."],
				type = "group",
				args = {
					alpha = {
						name = L["Alpha"],
						desc = L["Options related to transparency."],
						type = "group",
						args = {
							mode = {
								order = 611,
								name = L["Mode"],
								desc = L["Choose how transparency should be set."],
								type = "text",
								validate = { ["FIXED"] = L["Fixed Alpha"], ["COMBAT"] = L["Combat Fade"], ["HEALTH"] = L["Health Fade"] },
								get = function() return db.alphaMode end,
								set = function(v)
									db.alphaMode = v
									self:UpdateCombatEvents()
									if v == "COMBAT" then
										tmp1 = UnitAffectingCombat("player") and db.alphaCombat or db.alphaOOC
										OSH_PlayerFrame:SetAlpha(tmp1)
										OSH_TargetFrame:SetAlpha(tmp1)
										if isPetClass then
											OSH_PetFrame:SetAlpha(tmp1)
										end
									else
										if v == "HEALTH" then
											self:UpdateHealth("player")
											self:UpdateHealth("target")
											if isPetClass then
												self:UpdateHealth("pet")
											end
										else
											tmp1 = db.alphaFixed
											OSH_PlayerFrame:SetAlpha(tmp1)
											OSH_TargetFrame:SetAlpha(tmp1)
											if isPetClass then
												OSH_PetFrame:SetAlpha(tmp1)
											end
										end
									end
								end,
							},
							fixed = {
								order = 612,
								name = L["Alpha"],
								desc = L["Set a fixed transparency for the displays."],
								hidden = function() return db.alphaMode ~= "FIXED" end,
								type = "range",
								min = 0.05,
								max = 1.00,
								step = 0.01,
								bigStep = 0.05,
								get = function() return db.alphaFixed end,
								set = function(v)
									db.alphaFixed = v
									if db.alphaMode == "FIXED" then
										OSH_PlayerFrame:SetAlpha(v)
										OSH_TargetFrame:SetAlpha(v)
										if isPetClass then
											OSH_PetFrame:SetAlpha(v)
										end
									end
								end,
							},
							combat = {
								order = 613,
								name = L["Alpha In Combat"],
								desc = L["Set the transparency level to use in combat."],
								hidden = function() return db.alphaMode ~= "COMBAT" end,
								type = "range",
								min = 0.05,
								max = 1.00,
								step = 0.01,
								bigStep = 0.05,
								get = function() return db.alphaCombat end,
								set = function(v)
									db.alphaCombat = v
									if db.alphaMode == "COMBAT" and UnitAffectingCombat("player") then
										OSH_PlayerFrame:SetAlpha(v)
										OSH_TargetFrame:SetAlpha(v)
										if isPetClass then
											OSH_PetFrame:SetAlpha(v)
										end
									end
								end,
							},
							ooc = {
								order = 614,
								name = L["Alpha Out Of Combat"],
								desc = L["Set the transparency level to use out of combat."],
								hidden = function() return db.alphaMode ~= "COMBAT" end,
								type = "range",
								min = 0.05,
								max = 1.00,
								step = 0.01,
								bigStep = 0.05,
								get = function() return db.alphaOOC end,
								set = function(v)
									db.alphaOOC = v
									if db.alphaMode == "COMBAT" and not UnitAffectingCombat("player") then
										OSH_PlayerFrame:SetAlpha(v)
										OSH_TargetFrame:SetAlpha(v)
										if isPetClass then
											OSH_PetFrame:SetAlpha(v)
										end
									end
								end,
							},
						}
					},
					colorMode = {
						name = L["Health Color Mode"],
						desc = L["Choose how to color the unit's health."],
						type = "text",
						validate = { ["FIXED"] = L["Solid Color Thresholds"], ["GRADIENT"] = L["Smooth Color Gradient"], ["CLASS"] = L["Player Class"] },
						get = function() return db.colorHealthMode end,
						set = function(v)
							db.colorHealthMode = v
							self:UpdateAll("health")
						end
					},
					showPower = {
						name = L["Show Power Text"],
						desc = L["Show text for mana, rage, energy, and focus."],
						type = "toggle",
						get = function() return db.showPower end,
						set = function(v)
							db.showPower = v
							self:UpdatePowerEvents()
							if v then
								self:UpdatePower("player")
								self:UpdatePower("target")
								if isPetClass then
									self:UpdatePower("pet")
								end
							else
								OSH_PlayerPower:SetText()
								OSH_TargetPower:SetText()
								if isPetClass then
									OSH_PetPower:SetText()
								end
							end
						end
					},
					textAlign = {
						name = L["Text Alignment"],
						desc = L["Set the text alignment."],
						type = "text",
						validate = { ["CENTER"] = L["Center"], ["INSIDE"] = L["Inside"], ["OUTSIDE"] = L["Outside"] },
						get = function() return db.textAlign end,
						set = function(v)
							db.textAlign = v
							self:ApplyPositions()
						end
					},
					textFormat = {
						name = L["Text Format"],
						desc = L["Set the format for displayed text."],
						type = "group",
						args = {
							health = {
								name = L["Health Format"],
								desc = L["Set the formats for health text."],
								type = "group",
								pass = true,
								get = function(key) return db[key] end,
								set = function(key, value)
									db[key] = value
									self:UpdateAll("health")
								end,
								args = {
									monster = {
										name = L["NPC Health"],
										desc = L["Set the format for NPCs' health text."]..L["\n$p = percent \n$c = current \n$m = maximum \n$d = missing \n$c:s = short current \n$m:s = short maximum \n$d:s = short missing"],
										type = "text",
										usage = "Enter a text format for NPC health.",
										passValue = "textFormatHealthMonster"
									},
									player = {
										name = L["Player Health"],
										desc = L["Set the format for players' health text."]..L["\n$p = percent \n$c = current \n$m = maximum \n$d = missing \n$c:s = short current \n$m:s = short maximum \n$d:s = short missing"],
										type = "text",
										usage = "Enter a text format for player health.",
										passValue = "textFormatHealthPlayer"
									}
								}
							},
							power = {
								name = L["Power Format"],
								desc = L["Set the formats for power text."],
								type = "group",
								pass = true,
								get = function(key) return db[key] end,
								set = function(key, value)
									db[key] = value
									self:UpdateAll("power")
								end,
								args = {
									monster = {
										name = L["NPC Power"],
										desc = L["Set the format for NPCs' power text."]..L["\n$p = percent \n$c = current \n$m = maximum \n$d = missing \n$c:s = short current \n$m:s = short maximum \n$d:s = short missing"],
										type = "text",
										usage = "Enter a text format for NPC power.",
										passValue = "textFormatPowerMonster"
									},
									player = {
										name = L["Player Power"],
										desc = L["Set the format for players' power text."]..L["\n$p = percent \n$c = current \n$m = maximum \n$d = missing \n$c:s = short current \n$m:s = short maximum \n$d:s = short missing"],
										type = "text",
										usage = "Enter a text format for player power.",
										passValue = "textFormatPowerPlayer"
									}
								}
							}
						}
					}
				}
			},
			font = {
				order = 700,
				name = L["Font"],
				desc = L["Options relating to the font used."],
				type = "group",
				args = {
					outline = {
						order = 720,
						name = L["Outline"],
						desc = L["Set the text outline to be used."],
						type = "text",
						validate = { ["NONE"] = L["None"], ["OUTLINE"] = L["Thin"], ["THICKOUTLINE"] = L["Thick"] },
						get = function() return db.fontOutline end,
						set = function(v)
							db.fontOutline = v
							self:ApplyFonts()
						end
					},
					shadow = {
						order = 730,
						name = L["Shadow"],
						desc = L["Enable a text shadow."],
						type = "toggle",
						get = function() return db.fontShadow end,
						set = function(v)
							db.fontShadow = v
							if v then
								tmp1, tmp2 = 2, -2
							else
								tmp1, tmp2 = 0, 0
							end
							OSH_PlayerHealth:SetShadowOffset(tmp1, tmp2)
							OSH_PlayerPower:SetShadowOffset(tmp1, tmp2)
							OSH_TargetHealth:SetShadowOffset(tmp1, tmp2)
							OSH_TargetPower:SetShadowOffset(tmp1, tmp2)
							OSH_TargetTarget:SetShadowOffset(tmp1, tmp2)
							if isComboClass then
								OSH_TargetCombo:SetShadowOffset(tmp1, tmp2)
							end
							if isPetClass then
								OSH_PetHealth:SetShadowOffset(tmp1, tmp2)
								OSH_PetPower:SetShadowOffset(tmp1, tmp2)
							end
						end
					},
					size = {
						order = 740,
						name = L["Size"],
						desc = L["Options relating to font size."],
						type = "group",
						args = {
							health = {
								order = 741,
								name = L["Health"],
								desc = L["Set the font size used for health text."],
								type = "range",
								min = 8,
								max = 32,
								step = 1,
								bigStep = 4,
								get = function() return db.fontSizeHealth end,
								set = function(v)
									db.fontSizeHealth = v
									tmp1, tmp2 = db.fontFace, db.fontOutline
									OSH_PlayerHealth:SetFont(tmp1, v, tmp2)
									OSH_TargetHealth:SetFont(tmp1, v, tmp2)
									if isPetClass then
										OSH_PetHealth:SetFont(tmp1, db.fontSizePet * v, tmp2)
									end
								end
							},
							power = {
								order = 742,
								name = L["Power"],
								desc = L["Set the font size used for power text."],
								type = "range",
								min = 8,
								max = 32,
								step = 1,
								bigStep = 4,
								get = function() return db.fontSizePower end,
								set = function(v)
									db.fontSizePower = v
									tmp1, tmp2 = db.fontFace, db.fontOutline
									OSH_PlayerPower:SetFont(tmp1, v, tmp2)
									OSH_TargetPower:SetFont(tmp1, v, tmp2)
									if isPetClass then
										OSH_PetPower:SetFont(tmp1, db.fontSizePet * v, tmp2)
									end
								end
							},
							combo = {
								order = 743,
								name = L["Combo Points"],
								desc = L["Set the font size used for combo points."],
								disabled = noCombo,
								hidden = noCombo,
								type = "range",
								min = 8,
								max = 32,
								step = 1,
								bigStep = 4,
								get = function() return db.fontSizeCombo end,
								set = function(v)
									db.fontSizeCombo = v
									OSH_TargetCombo:SetFont(db.fontFace, v, db.fontOutline)
								end
							},
							target = {
								order = 744,
								name = L["Target Name"],
								desc = L["Set the font size used for target name text."],
								type = "range",
								min = 8,
								max = 32,
								step = 1,
								bigStep = 4,
								get = function() return db.fontSizeTarget end,
								set = function(v)
									db.fontSizeTarget = v
									OSH_TargetTarget:SetFont(db.fontFace, v, db.fontOutline)
								end
							},
							pet = {
								order = 745,
								name = L["Pet Scale"],
								desc = L["Set the scale for pet health and power text compared to player text."],
								disabled = noPet,
								hidden = noPet,
								type = "range",
								min = 0.1,
								max = 1.0,
								step = 0.1,
								get = function() return db.fontSizePet end,
								set = function(v)
									db.fontSizePet = v
									local tmp1, tmp2 = db.fontFace, db.fontOutline
									OSH_PetHealth:SetFont(tmp1, db.fontSizeHealth * v, tmp2)
									OSH_PetPower:SetFont(tmp1, db.fontSizePower * v, tmp2)
								end
							}
						}
					}
				}
			},
			colors = {
				name = L["Colors"],
				desc = L["Set the colors used."],
				type = "group",
				args = {
					health = {
						name = L["Health"],
						desc = L["Set the colors used for health."],
						type = "group",
						pass = true,
						get = getColor,
						set = setColor,
						args = {
							max = {
								order = 811,
								name = L["Health Maximum"],
								desc = L["Set the color used for maximum health."],
								type = "color",
								passValue = "colorHealthMax"
							},
							mid = {
								order = 812,
								name = L["Health 50%"],
								desc = L["Set the color used for 50% health."],
								type = "color",
								passValue = "colorHealthMid"
							},
							min = {
								order = 813,
								name = L["Health Minimum"],
								desc = L["Set the color used for minimum health."],
								type = "color",
								passValue = "colorHealthMin"
							}
						}
					},
					power = {
						name = L["Power"],
						desc = L["Set the colors used for each power type."],
						type = "group",
						pass = true,
						get = getColor,
						set = setColor,
						args = {
							mana = {
								order = 821,
								name = L["Mana"],
								desc = L["Set the color used for mana."],
								type = "color",
								passValue = "colorMana"
							},
							rage = {
								order = 822,
								name = L["Rage"],
								desc = L["Set the color used for rage."],
								type = "color",
								passValue = "colorRage"
							},
							energy = {
								order = 823,
								name = L["Energy"],
								desc = L["Set the color used for energy."],
								type = "color",
								passValue = "colorEnergy"
							},
							runicpower = {
								order = 824,
								name = L["Runic Power"],
								desc = L["Set the color used for runic power."],
								type = "color",
								passValue = "colorRunicPower",
							},
							focus = {
								order = 825,
								name = L["Focus"],
								desc = L["Set the color used for focus."],
								type = "color",
								passValue = "colorFocus"
							}
						}
					},
					absent = {
						name = L["Absent"],
						desc = L["Set the color used for dead and offline units."],
						type = "color",
						get = function()
							tmp1 = db.colorAbsent
							return tonumber(tmp1:sub(1, 2), 16) / 255, tonumber(tmp1:sub(3, 4), 16) / 255, tonumber(tmp1:sub(5, 6), 16) / 255
						end,
						set = function(r, g, b)
							db.colorAbsent = string.format("%02x%02x%02x", r*255, g*255, b*255)
							self:UpdateHealth("player")
							self:UpdateHealth("target")
							if isPetClass then
								self:UpdateHealth("player")
							end
						end
					},
					combatStatus = {
						name = L["Combat Status"],
						desc = L["Set the color used for the player combat status indicator."],
						type = "color",
						get = function()
							tmp1 = db.colorCombatStatus
							return tonumber(tmp1:sub(1, 2), 16) / 255, tonumber(tmp1:sub(3, 4), 16) / 255, tonumber(tmp1:sub(5, 6), 16) / 255
						end,
						set = function(r, g, b)
							db.colorCombatStatus = string.format("%02x%02x%02x", r*255, g*255, b*255)
							self:UpdateCombatStatus("player")
						end
					},
					combo = {
						name = L["Combo Points"],
						desc = L["Set the color used for combo points."],
						disabled = noCombo,
						hidden = noCombo,
						type = "color",
						get = function()
							tmp1 = db.colorCombo
							return tonumber(tmp1:sub(1, 2), 16) / 255, tonumber(tmp1:sub(3, 4), 16) / 255, tonumber(tmp1:sub(5, 6), 16) / 255
						end,
						set = function(r, g, b)
							db.colorCombo = string.format("%02x%02x%02x", r*255, g*255, b*255)
							self:UpdateCP()
						end
					},
					targetSelf = {
						name = L["Target Self"],
						desc = L["Set the color used for yourself as your target's target."],
						type = "color",
						get = function()
							tmp1 = db.colorTargetSelf
							return tonumber(tmp1:sub(1, 2), 16) / 255, tonumber(tmp1:sub(3, 4), 16) / 255, tonumber(tmp1:sub(5, 6), 16) / 255
						end,
						set = function(r, g, b)
							db.colorTargetSelf = string.format("%02x%02x%02x", r*255, g*255, b*255)
							self:UpdateToT()
						end
					}
				}
			},
			position = {
				order = 900,
				name = L["Position"],
				desc = L["Set the position of the displays on-screen."],
				type = "group",
				pass = true,
				get = getPos,
				set = setPos,
				args = {
					x = {
						order = 910,
						name = L["Horizontal"],
						desc = L["Set the horizontal distance from the center of the screen."],
						type = "range",
						min = 0,
						max = 800,
						step = 10,
						bigStep = 50,
						passValue = "posX"
					},
					y = {
						order = 920,
						name = L["Vertical"],
						desc = L["Set the vertical distance from the center of the screen."],
						type = "range",
						min = -500,
						max = 500,
						step = 10,
						bigStep = 25,
						passValue = "posY"
					},
					petOffset = {
						order = 930,
						name = L["Pet Offset"],
						desc = L["Set the distance to position the pet frame from the player frame."],
						disabled = noPet,
						hidden = noPet,
						type = "range",
						min = -200,
						max = 200,
						step = 10,
						bigStep = 25,
						passValue = "posPet"
					}
				}
			}
		}
	}

	local SharedMedia = LibStub and ( LibStub("LibSharedMedia-3.0", true) or LibStub("LibSharedMedia-2.0", true) )
	if SharedMedia then
		Debug("SharedMedia library found; loading typeface option.")
		self.options.args.font.args.face = {
			order = 710,
			name = L["Typeface"],
			desc = L["Set the typeface to be used."],
			type = "text",
			validate = SharedMedia:List("font"),
			get = function() return db.fontFace end,
			set = function(v)
				db.fontFace =  v
				self:ApplyFonts()
			end
		}
	end

	self:RegisterChatCommand("/onscreenhealth", "/osh", self.options, "ONSCREENHEALTH")
end