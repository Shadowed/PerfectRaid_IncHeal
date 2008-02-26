local Heal = PerfectRaid:NewModule("PerfectRaid-Heal")
local L = PRIncHealLocals

local HealComm
local playerName
local ourHeals = {}

function Heal:Initialize()
	PerfectRaid.defaults.profile.HealEnabled = true
	PerfectRaid.defaults.profile.HealSelf = true
	PerfectRaid.defaults.profile.HealWithin = 60

	playerName = UnitName("player")
	
	self:RegisterMessage("DONGLE_PROFILE_CHANGED")
	HealComm = LibStub:GetLibrary("LibHealComm-3.0")
end

function Heal:Enable()
	if( not PerfectRaid.db.profile.HealEnabled ) then
		return

	end
	

	self:RegisterEvent("UNIT_HEALTH")
	self:RegisterEvent("UNIT_HEALTH_MAX", "UNIT_HEALTH")

	HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "DirectHealStart")
	HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "DirectHealStop")
	HealComm.RegisterCallback(self, "HealComm_DirectHealDelayed", "DirectHealDelayed")
	HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
end

function Heal:Disable()
	self:UnregisterAllEvents()
	HealComm:UnregisterAllCallbacks(self)
end

function Heal:ConfigureButton(button)
	local font = button.raise:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.heal = font
	button.heal:SetTextColor(0, 1, 0)
end

function Heal:UNIT_HEALTH(event, unit)
	local name, server = UnitName(unit)
	if( server and server ~= "" ) then
		name = name .. "-" .. server
	end
	
	-- Makes sure we only update people who are in our raid, party, or it's us

	if( UnitExists(name) ) then
		self:UpdateHealing(name)
	end
end

function Heal:UpdateIncomming(healer, amount, ...)
	for i=1, select("#", ...) do
		local target = select(i, ...)
		if( healer == playerName ) then
			ourHeals[target] = amount
		end
		
		self:UpdateHealing(target)
	end
end

function Heal:UpdateHealing(target)
	local amount = HealComm:UnitIncomingHealGet(target, GetTime() + PerfectRaid.db.profile.HealWithin) or 0
	if( ourHeals[target] and PerfectRaid.db.profile.HealSelf ) then
		amount = amount + ourHeals[target]
	end
	
	-- Reduce/increase the healing done if they have a debuff or buff that changes it!
	amount = amount * HealComm:UnitHealModifierGet(target)
	amount = math.floor(amount + 0.5)
	
	if( amount > 999 ) then 
		amount = "+" .. string.format("%.1fk", amount / 1000)
	elseif( amount == 0 ) then
		amount = ""
	end
	
	-- Hack to make positioning work better
	local health = UnitHealth(target)
	local max = UnitHealthMax(target)
	if( max < health ) then max = health end

	local deficit = max - health
	
	for unit, list in pairs(PerfectRaid.frames) do
		local name, server = UnitName(unit)
		if( server and server ~= "" ) then
			name = name .. "-" .. server
		end
		
		if( name == target ) then
			local hasAggro = (PerfectRaid.aggro[unit] and PerfectRaid.aggro[unit] >= 15)
			
			for frame in pairs(list) do
				if( deficit == 0 and not hasAggro ) then
					frame.heal:ClearAllPoints()
					frame.heal:SetPoint("RIGHT", -2, 0)
					frame.heal:SetText(amount)
				else
					frame.heal:ClearAllPoints()
					frame.heal:SetPoint("TOPRIGHT", frame.status, "TOPLEFT", -2, 0)
					frame.heal:SetText(amount)
				end
			end
		end
	end
end

-- Handle callbacks from HealComm
function Heal:DirectHealStart(event, healerName, amount, endTime, ...)
	self:UpdateIncomming(healerName, amount, ...)
end

function Heal:DirectHealStop(event, healerName, amount, succeeded, ...)
	self:UpdateIncomming(healerName, 0, ...)
end

function Heal:DirectHealDelayed(event, healerName, amount, endTime, ...)
	self:UpdateIncomming(healerName, amount, ...)
end

function Heal:HealModifierUpdate(event, unit, targetName, healMod)
	self:UpdateHealing(targetName)
end

-- Config
function Heal:DONGLE_PROFILE_CHANGED(event, addon, svname)
	if( svname == "PerfectRaidDB" ) then
		if( PerfectRaid.db.profile.HealEnabled ) then
			self:Enable()
		else
			self:Disable()
		end
	end
end

local options
function Heal:CreateOptions(opt)
	options = CreateFrame("Frame", "PROptions_IncHeal", PROptions)
	options:SetScript("OnShow", function() self:OnShow() end)

	opt:AddOptionsTab("Heal", options)

	options.widgets = {}

	local check = CreateFrame("CheckButton", "PRIncHeal_Enabled", options, "PRCheckTemplate")
	check.Label:SetText(L["Enable heals incomming on raid frames"])
	table.insert(options.widgets, check)

	local check = CreateFrame("CheckButton", "PRIncHeal_Self", options, "PRCheckTemplate")
	check.Label:SetText(L["Show your own heals as incomming"])
	table.insert(options.widgets, check)

	local slider = CreateFrame("Slider", "PRIncHeal_Within", options, "PRSliderTemplate")
	slider.Text:SetText(L["Show heals incomming within"])
	slider.High:SetText("60")
	slider.Low:SetText("0")
	slider:SetMinMaxValues(0, 60)
	slider:SetValueStep(0.5)
	table.insert(options.widgets, slider)

	local cancel = CreateFrame("Button", "PRIncHeal_Cancel", options, "PRButtonTemplate")
	cancel:SetText(L["Cancel"])
	cancel:SetPoint("BOTTOMRIGHT", 0, 5)
	cancel:SetScript("OnClick", function() self:OnShow() end)
	cancel:Show()
	
	local save = CreateFrame("Button", "PRIncHeal_Save", options, "PRButtonTemplate")
	save:SetText(L["Save"])
	save:SetPoint("BOTTOMRIGHT", cancel, "BOTTOMLEFT", -10, 0)
	save:SetScript("OnClick", function() self:SaveOptions() end)
	save:Show()

	for idx,widget in ipairs(options.widgets) do
		widget:Show()
		if idx == 1 then
			widget:SetPoint("TOPLEFT", 0, 0)
		else
			widget:SetPoint("TOPLEFT", options.widgets[idx - 1], "BOTTOMLEFT", 0, -15)
		end
	end
end

function Heal:OnShow()
	local profile = PerfectRaid.db.profile

	PRIncHeal_Enabled:SetChecked(profile.HealEnabled)
	PRIncHeal_Self:SetChecked(profile.HealSelf)
	PRIncHeal_Within:SetValue(profile.HealWithin)
end

function Heal:SaveOptions()
	local profile = PerfectRaid.db.profile
	
	profile.HealEnabled = PRIncHeal_Enabled:GetChecked() or false
	profile.HealSelf = PRIncHeal_Self:GetChecked() or false
	profile.HealWithin = PRIncHeal_Within:GetValue()

	if( not profile.HealEnabled ) then
		self:Disable()
	else
		self:Enable()
	end
end
