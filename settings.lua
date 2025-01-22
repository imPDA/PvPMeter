local addon = {}

local LAM = LibAddonMenu2

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
                }
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
            },
        },
    }

    LAM:RegisterOptionControls(settingsName, optionsData)
end

function IPM_InitializeSettings(...)
    addon:Initialize(...)
end