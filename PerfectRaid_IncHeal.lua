local Heal = PerfectRaid:NewModule("PerfectRaid-Heal")
local L = PRIncHealLocals

local HealComm

function Heal:Initialize()
	PerfectRaid.defaults.profile.HealEnabled = true
	PerfectRaid.defaults.profile.HealSelf = true
	PerfectRaid.defaults.profile.HealAtDeficit = true
	PerfectRaid.defaults.profile.HealWithin = 4
		
	self:RegisterMessage("DONGLE_PROFILE_CHANGED")
	HealComm = LibStub:GetLibrary("LibHealComm-4.0")
end

function Heal:Enable()
	if( not PerfectRaid.db.profile.HealEnabled ) then return end
	PerfectRaid.db.profile.HealWithin = math.max(PerfectRaid.db.profile.HealWithin, 4)

	HealComm.RegisterCallback(self, "HealComm_HealStarted", "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_HealStopped", "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_HealDelayed", "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_ModifierChanged", "HealComm_GUIDChanged")
	HealComm.RegisterCallback(self, "HealComm_GUIDDisappeared", "HealComm_GUIDChanged")
end

function Heal:Disable()
	self:UnregisterAllEvents()
	HealComm:UnregisterAllCallbacks(self)
end

function Heal:ConfigureButton(button)
	if( not button.raise ) then
		button.raise = CreateFrame("Frame", nil, button.healthbar)
		button.raise:SetAllPoints()
	end
	
	local font = button.raise:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.heal = font
	button.heal:SetTextColor(0, 1, 0)
end

function Heal:UpdateButtonLayout(button)
	if( not button.heal ) then return end
	
	if( PerfectRaid.db.profile.HealAtDeficit ) then
		button.heal:ClearAllPoints()
		button.heal:SetPoint("TOPRIGHT", button.status, "TOPLEFT", -2, -2)
		button.status:SetHeight(14)
	else
		button.heal:ClearAllPoints()
		button.heal:SetPoint("LEFT", 2, 0)
	end
end

function Heal:UpdateHealing(frame, guid)
	local amount
	if( PerfectRaid.db.profile.HealSelf ) then
		amount = HealComm:GetHealAmount(guid, HealComm.ALL_HEALS, GetTime() + PerfectRaid.db.profile.HealWithin) or 0
	else
		amount = HealComm:GetOthersHealAmount(guid, HealComm.ALL_HEALS, GetTime() + PerfectRaid.db.profile.HealWithin) or 0
	end
		
	-- Reduce/increase the healing done if they have a debuff or buff that changes it!
	amount = amount * HealComm:GetHealModifier(guid)
	
	if( amount > 999 ) then 
		frame.heal:SetFormattedText("+%.1fk", amount / 1000)
	elseif( amount > 0 ) then
		frame.heal:SetFormattedText("+%d", amount)
	else
		frame.heal:SetText("")
	end
end

local tempTableMap = {}
function Heal:UpdateIncoming(...)
	table.wipe(tempTableMap)
	for i=1, select("#", ...) do
		tempTableMap[select(i, ...)] = true
	end
	
	for unit, list in pairs(PerfectRaid.frames) do
		local guid = UnitGUID(unit)
		if( guid and tempTableMap[guid] ) then
			for frame in pairs(list) do
				self:UpdateHealing(frame, guid)
			end
		end
	end
end

function Heal:HealComm_HealUpdated(event, casterGUID, spellID, healType, endTime, ...)
	self:UpdateIncoming(...)
end

function Heal:HealComm_GUIDChanged(event, guid)
	self:UpdateIncoming(guid)
end

-- Config
function Heal:DONGLE_PROFILE_CHANGED(event, addon, svname)
	if( svname == "PerfectRaidDB" ) then
		if( PerfectRaid.db.profile.HealEnabled ) then
			self:Enable()
		else
			self:Disable()
		end
		
		for unit, list in pairs(PerfectRaid.frames) do
			for button in pairs(list) do
				self:UpdateButtonLayout(button)
			end
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

	local check = CreateFrame("CheckButton", "PRIncHeal_AtDeficit", options, "PRCheckTemplate")
	check.Label:SetText(L["Position heals incomming next to health deficit"])
	table.insert(options.widgets, check)

	local slider = CreateFrame("Slider", "PRIncHeal_Within", options, "PRSliderTemplate")
	slider.Text:SetText(L["Show heals incomming within"])
	slider.High:SetText("5")
	slider.Low:SetText("0")
	slider:SetMinMaxValues(0, 5)
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
	PRIncHeal_AtDeficit:SetChecked(profile.HealAtDeficit)
	PRIncHeal_Within:SetValue(profile.HealWithin)
end

function Heal:SaveOptions()
	local profile = PerfectRaid.db.profile
	
	profile.HealEnabled = PRIncHeal_Enabled:GetChecked() or false
	profile.HealSelf = PRIncHeal_Self:GetChecked() or false
	profile.HealAtDeficit = PRIncHeal_AtDeficit:GetChecked() or false
	profile.HealWithin = PRIncHeal_Within:GetValue()

	if( not profile.HealEnabled ) then
		self:Disable()
	else
		self:Enable()
	end

	for unit, list in pairs(PerfectRaid.frames) do
		for button in pairs(list) do
			self:UpdateButtonLayout(button)
		end
	end
end
