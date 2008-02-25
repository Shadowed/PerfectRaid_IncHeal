local Heal = PerfectRaid:NewModule("PerfectRaid-Heal")
local L = PerfectRaidLocals

local HealComm
local playerName
local ourHeals = {}

function Heal:Initialize()
	playerName = UnitName("player")
	
	self:RegisterEvent("UNIT_HEALTH")
	self:RegisterEvent("UNIT_HEALTH_MAX", "UNIT_HEALTH")
	
	HealComm = LibStub:GetLibrary("LibHealComm-3.0")
	HealComm.RegisterCallback(self, "HealComm_DirectHealStart", "DirectHealStart")
	HealComm.RegisterCallback(self, "HealComm_DirectHealStop", "DirectHealStop")
	HealComm.RegisterCallback(self, "HealComm_DirectHealDelayed", "DirectHealDelayed")
	HealComm.RegisterCallback(self, "HealComm_HealModifierUpdate", "HealModifierUpdate")
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
	
	self:UpdateHealing(name)
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
	local amount = HealComm:UnitIncomingHealGet(target, GetTime() + 60) or 0
	if( ourHeals[target] ) then
		amount = amount + ourHeals[target]
	end
	
	-- Reduce/increase the healing done if they have a debuff or buff that changes it!
	amount = amount * HealComm:UnitHealModifierGet(target)
	
	if( amount > 999 ) then 
		amount = "+" .. string.format("%.1fk", amount / 1000)
	elseif( amount <= 0 ) then
		amount = ""
	end
	
	for unit, list in pairs(PerfectRaid.frames) do
		local name, server = UnitName(unit)
		if( server and server ~= "" ) then
			name = name .. "-" .. server
		end
		
		if( name == target ) then
			for frame in pairs(list) do
				local text = frame.status:GetText()
				if( not text or text == "" ) then
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