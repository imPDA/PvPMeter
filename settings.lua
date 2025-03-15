local addon = {}

local LAM = LibAddonMenu2

--#region COPY OLD DATA TO NEW ADDON
local dataMapping = {
    ['ImpPvPMeterSV'] = 'ImpressiveStatsSV',
    ['ImpPvPMeterCSV'] = 'ImpressiveStatsCSV',
    ['PvPMeterBattlegroundsData'] = 'ImpressiveStatsMatchesData',
    -- ['ImpPvPMeterMatchBackup'] = 'ImpressiveStatsMatchBackup',
    ['PvPMeterDuelsData'] = 'ImpressiveStatsDuelsData',
    ['PvPMeterTOTData'] = 'ImpressiveStatsTributeData',
}
local function IsDataFromImpPvPMeterAvailable()
    for oldName, _ in pairs(dataMapping) do
        if _G[oldName] ~= nil then return true end
    end
end

local function CopyDataFromImpPvPMeter()
    for oldSV, newSV in pairs(dataMapping) do
        _G[newSV] = _G[oldSV]
        _G[oldSV] = nil
    end
    ReloadUI()
end
--#endregion

function addon:Initialize(settingsName, settingsDisplayName, sv)
    local panelData = {
        type = 'panel',
        name = settingsDisplayName,
        author = '@impda',
    }

    local panel = LAM:RegisterAddonPanel(settingsName, panelData)

    local optionsData = {
        {
            type = 'submenu',
            name = 'Battlegrounds module',
            tooltip = 'This is the tab for battlegrounds panel',
            controls = {
                {
                    type = 'checkbox',
                    name = 'Enable',
                    getFunc = function() return sv.battlegrounds.enabled end,
                    setFunc = function(value) sv.battlegrounds.enabled = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = '[EXPERIMENTAL]New manager',
                    getFunc = function() return sv.battlegrounds.newManager end,
                    setFunc = function(value) sv.battlegrounds.newManager = value end,
                    requiresReload = true,
                },
            },
        },
        {
            type = 'submenu',
            name = 'Duels module',
            tooltip = 'For braviest',
            controls = {
                {
                    type = 'checkbox',
                    name = 'Enable',
                    getFunc = function() return sv.duels.enabled end,
                    setFunc = function(value) sv.duels.enabled = value end,
                    requiresReload = true,
                },
                {
                    type = "dropdown",
                    name = "Naming options",
                    tooltip = "How to display names",
                    choices = {
                        "Character Name",
                        "@id",
                        "@id (Character Name)"
                    },
                    choicesValues = {
                        1, 2, 3
                    },
                    getFunc = function() return sv.duels.namingMode end,
                    setFunc = function(var) sv.duels.namingMode = var end,
                    width = "full",
                    requiresReload = true,
                    -- warning = "Will need to reload the UI.",	--(optional)
                  },
            },
        },
        {
            type = 'submenu',
            name = 'Tribute module',
            tooltip = 'That is real PvP, no doubts allowed!',
            controls = {
                {
                    type = 'checkbox',
                    name = 'Enable',
                    getFunc = function() return sv.tot.enabled end,
                    setFunc = function(value) sv.tot.enabled = value end,
                    requiresReload = true,
                },
                {
                    type = 'checkbox',
                    name = '[EXPERIMENTAL]Add leaderboard',
                    getFunc = function() return sv.tot.leaderboard end,
                    setFunc = function(value) sv.tot.leaderboard = value end,
                    requiresReload = true,
                },
            },
        },
        {
            type = "button",
            name = "Copy from ImpPvPMeter",
            tooltip = "For testers! It will make a full copy of saved data.",
            func = CopyDataFromImpPvPMeter,
            width = "full",
            warning = "ALL DATA WILL BE IRREVERSIBLY REPLACED\n\nUse it only ONCE and BEFORE any new bgs/duels/tribute games.\n\nUI will be automatically reloaded.",
            isDangerous	= true,
            disabled = function() return not IsDataFromImpPvPMeterAvailable() end,
        },
    }

    LAM:RegisterOptionControls(settingsName, optionsData)
end

function IMP_STATS_InitializeSettings(...)
    addon:Initialize(...)
end