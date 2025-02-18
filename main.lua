local addon = {}
addon.name = 'ImpressiveStats'
addon.displayName = '|c7c42f2Imp|ceeeeee-ressive Stats|r'
addon.version = '1.0.3'

local Log = IMP_STATS_Logger('IMP_STATS_MAIN')

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

	self.sv = ZO_SavedVars:NewAccountWide('ImpressiveStatsSV', 1, nil, DEFAULTS)
	self.csv = ZO_SavedVars:NewCharacterIdSettings('ImpressiveStatsCSV', 1, nil, CHARACTER_DEFAULTS)

	IMP_STATS_MENU:Initialize(self.sv.battlegrounds.enabled, self.sv.duels.enabled, self.sv.tot.enabled)

	if self.sv.battlegrounds.enabled then
    	IMP_STATS_InitializeMatchManager(self.sv.battlegrounds, self.csv.battlegrounds)
		Log('Matches initialized')
	end

	if self.sv.duels.enabled then
		IMP_STATS_InitializeDuelsManager(self.sv.duels, self.csv.duels)
		Log('Duels initialized')
	end

	if self.sv.tot.enabled then
		IMP_STATS_InitializeTributeManager(self.sv.tot, self.csv.tot)
		Log('Tales of tribute initialized')
	end

	IMP_STATS_InitializeSettings(addon.name .. 'Settings', addon.displayName, self.sv)

	GetControl('IMP_STATS_VersionLabel'):SetText('v.' .. addon.version)
end

local function OnAddonLoaded(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon:OnLoad()

	-- IMP_STATS = addon
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)