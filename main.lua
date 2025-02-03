local addon = {}
addon.name = 'ImpPvPMeter'
addon.displayName = 'Imp\'s PvP Meter'
addon.version = '0.1.0b18'

local Log = IPM_Logger('IPM_MAIN')

local DEFAULTS = {
	battlegrounds = {
		enabled = true,
		namingMode = 1,
		-- selectedCharacters = {},
	},
	duels = {
		enabled = true,
		namingMode = 1,
		-- selectedCharacters = {},
	},
	tot = {
		enabled = true,
		namingMode = 1,
		-- selectedCharacters = {},
	},
}

local CHARACTER_DEFAULTS = {
	battlegrounds = {
		-- enabled = true,
		-- namingMode = 1,
		selectedCharacters = {},
	},
	duels = {
		-- enabled = true,
		-- namingMode = 1,
		selectedCharacters = {},
	},
	tot = {
		-- enabled = true,
		-- namingMode = 1,
		selectedCharacters = {},
	},
}

function addon:OnLoad()
	Log('Loading %s v%s', self.name, self.version)

	self.sv = ZO_SavedVars:NewAccountWide(self.name .. 'SV', 1, nil, DEFAULTS)
	self.csv = ZO_SavedVars:NewCharacterIdSettings(self.name .. 'CSV', 1, nil, CHARACTER_DEFAULTS)

	IPM_MAIN_MENU:Initialize(self.sv.battlegrounds.enabled, self.sv.duels.enabled, self.sv.tot.enabled)

	if self.sv.battlegrounds.enabled then
    	IPM_InitializeMatchSaver(self.sv.battlegrounds, self.csv.battlegrounds)
		Log('[B] Initialized')
	end

	if self.sv.duels.enabled then
		IPM_InitializeDuelSaver(self.sv.duels, self.csv.duels)
		Log('[D] Initialized')
	end

	if self.sv.tot.enabled then
		IPM_InitializeTOTManager(self.sv.tot, self.csv.tot)
		Log('[T] Initialized')
	end

	IPM_InitializeSettings(addon.name .. 'Settings', addon.displayName, self.sv)

	GetControl('IPM_VersionLabel'):SetText('v.' .. addon.version)
end

local function OnAddonLoaded(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon:OnLoad()

	IPM = addon
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)