local addon = {}

addon.name = 'IPM_DUELS_UI'

addon.listControl = nil
addon.statsControl = nil

addon.filters = {
    playerClass = {},
    opponentClass = {},
    playerName = '',
    opponentName = '',
    playerCharacters = {}
}

local Log = IPM_Log

--#region IPM DUESL STATISTICS
local IPM_DuelsStats = {}

function IPM_DuelsStats:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    o:Clear()

    return o
end

function IPM_DuelsStats:Clear()
    -- self.current = {
    --     totalDuels = 0,
    --     totalWon = 0,
    --     totalLost = 0,
    --     totalDamageDone = 0,
    --     totalDamageTaken = 0,
    --     totalHealingTaken = 0,
    --     totalDamageShielded = 0,
    --     totalDuration = 0,
    -- }
    self.totalDuels = 0
    self.totalWon = 0
    self.totalLost = 0
    self.totalDamageDone = 0
    self.totalDamageTaken = 0
    self.totalHealingTaken = 0
    self.totalDamageShielded = 0
    self.totalDuration = 0
    self.lastProceededIndex = nil
end

--#region HUMAN UNDERSTANDABLE RESULT
local WIN = 1
local LOSS = 2
local PLAYER_FORFEIT = 3
local OPPONENT_FORFEIT = 4
local UNDEFINED = 0

local DUEL_RESULT_TO_STRING = {
    [WIN] = 'Won',
    [LOSS] = 'Lost',
    [PLAYER_FORFEIT] = 'You run',
    [OPPONENT_FORFEIT] = 'Opponent run',
    [UNDEFINED] = '???',
}

local function GetHumanUnderstandableResult(result, wasLocalPlayersResult)
    local hrr = UNDEFINED

    if result == DUEL_RESULT_WON then
        if wasLocalPlayersResult then
            hrr = WIN
        else
            hrr = LOSS
        end
    elseif result == DUEL_RESULT_FORFEIT then
        if wasLocalPlayersResult then
            hrr = PLAYER_FORFEIT
        else
            hrr = OPPONENT_FORFEIT
        end
    end

    -- df('%s %s -> %s', result, tostring(wasLocalPlayersResult), hrr)

    return hrr
end
--#endregion HUMAN UNDERSTANDABLE RESULT

function IPM_DuelsStats:AddDuel(index, data)
    local duelIndex, duelData = index, data

    if self.lastProceededIndex and duelIndex <= self.lastProceededIndex then return end
    self.lastProceededIndex = duelIndex

    self.totalDuels             = self.totalDuels           + 1
    self.totalDamageDone        = self.totalDamageDone      + (duelData.damageDone      or 0)
    self.totalHealingTaken      = self.totalHealingTaken    + (duelData.healingTaken    or 0)
    self.totalDamageTaken       = self.totalDamageTaken     + (duelData.damageTaken     or 0)
    self.totalDamageShielded    = self.totalDamageShielded  + (duelData.damageShielded  or 0)
    self.totalDuration          = self.totalDuration        + (duelData.duration        or 0)

    local result = GetHumanUnderstandableResult(duelData.result, duelData.wasLocalPlayersResult)

    if result == WIN then
        self.totalWon = self.totalWon + 1
    elseif result == LOSS then
        self.totalLost = self.totalLost + 1
    end
end
--#endregion IPM DUELS STATISTICS

--#region IPM DUELS ADDON
function addon:SetShit(value)
    local shit = IPM_DuelsStatsBlockShit
    local r, g, b = IPM_Shared.Blend({1, 0, 0}, {0, 1, 0}, value)  -- {0.22, 0.08, 0.69}

    GetControl(shit, 'Bar'):StartFixedCooldown(value, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)  -- TODO
    GetControl(shit, 'Bar'):SetFillColor(r, g, b)
    GetControl(shit, 'Winrate'):SetText(string.format('%d%%', value * 100))
    GetControl(shit, 'Winrate'):SetColor(r, g, b)
end

function addon:UpdateStatsControl()
    self.statsControl:GetNamedChild('TotalDuelsValue'):SetText(self.stats.totalDuels)

    local winrate = IPM_Shared.PossibleNan(self.stats.totalWon / self.stats.totalDuels)
    self.statsControl:GetNamedChild('WinrateValue'):SetText(
        string.format('%.1f %% (|c00FF00%d|r / |cFF0000%d|r)', winrate * 100, self.stats.totalWon, self.stats.totalLost)
    )

    self.statsControl:GetNamedChild('TotalsValue'):SetText(
        string.format(
            '%s / %s / %s',
            IPM_Shared.FormatNumber(self.stats.totalDamageDone),
            IPM_Shared.FormatNumber(self.stats.totalDamageTaken),
            IPM_Shared.FormatNumber(self.stats.totalHealingTaken)
            -- IPM_Shared.FormatNumber(self.stats.totalDamageShielded),
            -- IPM_Shared.FormatNumber(self.stats.totalDuration)
        )
    )

    self:SetShit(winrate)
end

-- TODO: make color uniforme and global
local COLOR_OF_RESULT = {
    [WIN] = {0, 1, 0, 1},
    [LOSS] = {1, 0, 0, 1},
    [PLAYER_FORFEIT] = {35/255, 35/255, 35/255, 1},
    [OPPONENT_FORFEIT] = {75/255, 75/255, 75/255, 1},
}

function addon.GetName(data)
    assert(false, 'Must be owerritten!')
end

function addon:CreateScrollListDataType()
    local function LayoutRow(rowControl, data, scrollList)
        local result = UNDEFINED
        if data.result then
            -- TODO: make human understandable result on duel save
            result = GetHumanUnderstandableResult(data.result, data.wasLocalPlayersResult)
            if result ~= UNDEFINED then
                GetControl(rowControl, 'BG'):SetHidden(false)
                GetControl(rowControl, 'BG'):SetColor(unpack(COLOR_OF_RESULT[result]))
            end
        end
        GetControl(rowControl, 'Index'):SetText(data.index)

        local duration = ImpTools.SecondsToTime(data.duration or 0)
        GetControl(rowControl, 'Duration'):SetText(duration)

        local playerClassIcon = data.playerClass and ZO_GetClassIcon(data.playerClass) or 'EsoUI/Art/Icons/icon_missing.dds'
        local playerRaceIcon = data.playerRace and IPM_Shared.GetRaceIcon(data.playerRace) or 'EsoUI/Art/Icons/icon_missing.dds'
        GetControl(rowControl, 'PlayerClass'):GetNamedChild('ClassIcon'):SetTexture(playerClassIcon)
        GetControl(rowControl, 'PlayerRace'):GetNamedChild('RaceIcon'):SetTexture(playerRaceIcon)
        GetControl(rowControl, 'PlayerCharacterName'):SetText(zo_strformat('<<1>>', data.playerName))

        local opponentClassIcon = data.opponentClass and ZO_GetClassIcon(data.opponentClass) or 'EsoUI/Art/Icons/icon_missing.dds'
        local opponentRaceIcon = data.opponentRace and IPM_Shared.GetRaceIcon(data.opponentRace) or 'EsoUI/Art/Icons/icon_missing.dds'
        GetControl(rowControl, 'OpponentClass'):GetNamedChild('ClassIcon'):SetTexture(opponentClassIcon)
        GetControl(rowControl, 'OpponentRace'):GetNamedChild('RaceIcon'):SetTexture(opponentRaceIcon)
        GetControl(rowControl, 'OpponentCharacterName'):SetText(zo_strformat('<<1>>', data.opponentName))

        GetControl(rowControl, 'DamageDone'):SetText(IPM_Shared.FormatNumber(data.damageDone or 0))
        GetControl(rowControl, 'DamageTaken'):SetText(IPM_Shared.FormatNumber(data.damageTaken or 0))
        GetControl(rowControl, 'HealingTaken'):SetText(IPM_Shared.FormatNumber(data.healingTaken or 0))
        GetControl(rowControl, 'DamageShielded'):SetText(IPM_Shared.FormatNumber(data.damageShielded or 0))

        -- rowControl:SetHandler('OnMouseUp', function()
        --     d('click')
        --     ZO_ScrollList_MouseClick(scrollList, rowControl)
        -- end)

        local tooltip = ''

        if data.startTimestamp then
            local formattedTime = os.date('%d.%m.%Y %H:%M', data.startTimestamp)
            tooltip = tooltip .. formattedTime
        end
        tooltip = tooltip .. '\n'
        tooltip = tooltip .. zo_iconFormat(playerClassIcon) .. ' ' .. GetRaceName(0, data.playerRace)
        -- tooltip = tooltip .. '\n\n|cFF0000VS|r\n\n'
        tooltip = tooltip .. ' |cFF0000VS|r '
        tooltip = tooltip .. zo_iconFormat(opponentClassIcon) .. ' ' .. GetRaceName(0, data.opponentRace)
        tooltip = tooltip .. '\n'
        tooltip = tooltip .. 'Duration: ' .. duration

        tooltip = tooltip .. '\n'
        tooltip = tooltip .. 'Result: ' .. DUEL_RESULT_TO_STRING[result]

        rowControl:SetHandler('OnMouseEnter', function() ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, tooltip) end)
        rowControl:SetHandler('OnMouseExit', function() ZO_Tooltips_HideTextTooltip() end)
    end

	local control = self.listControl
	local typeId = 1
	local templateName = 'IPM_DuelSummaryRow'  -- TODO: change
	local height = 32
	local setupFunction = LayoutRow
	local hideCallback = nil
	local dataTypeSelectSound = nil
	local resetControlCallback = nil

	ZO_ScrollList_AddDataType(control, typeId, templateName, height, setupFunction, hideCallback, dataTypeSelectSound, resetControlCallback)

    -- local selectTemplate = 'ZO_ThinListHighlight'
	-- local selectCallback = nil
	-- ZO_ScrollList_EnableSelection(control, selectTemplate, selectCallback)
end

function addon:AddFilter(filterCallback)
    table.insert(self.filters, filterCallback)
end

function addon:PassFilters(data)
    for _, filter in ipairs(self.filters) do
        if not filter(data) then return end
    end

    return true
end

local function HideWarning(hidden)
    hidden = hidden == nil or hidden
    GetControl(IPM_Duels, 'Warning'):SetHidden(hidden)
end

local function ShowWarning()
    return HideWarning(false)
end

local function UpdateScrollListControl(control, data, rowType)
	-- local dataCopy = ZO_DeepTableCopy(data)
    local dataCopy = data
	local dataList = ZO_ScrollList_GetDataList(control)

	ZO_ScrollList_Clear(control)

    local task = LibAsync:Create('UpdateDuelsScrollList')

    local function CreateAndAddDataEntry(index)
        local value = dataCopy[index]
        local entry = ZO_ScrollList_CreateDataEntry(rowType, value)

		table.insert(dataList, entry)
    end

	-- table.sort(dataList, function(a,b) return a.data.index > b.data.index end)

    task:For(#dataCopy, 1, -1):Do(CreateAndAddDataEntry):Then(function() ZO_ScrollList_Commit(control) end):Then(HideWarning)
end

function addon:UpdateUI()
    local SOME_ID = 1
    UpdateScrollListControl(self.listControl, self.dataRows, SOME_ID)
    self:UpdateStatsControl()

    Log('[D] UI updated')
end

function addon:Update()
    if #self.duels > 60000 then ShowWarning() end

    self.dataRows = {}
    self.stats:Clear()

    local function HandleDuelData(duelIndex, duelData)
        if not self:PassFilters(duelData) then return end

        table.insert(self.dataRows, {
            index = #self.dataRows + 1,
            result = duelData.result,
            wasLocalPlayersResult = duelData.wasLocalPlayersResult,
            playerClass =  duelData.player.classId,
            playerRace = duelData.player.raceId,
            opponentClass =  duelData.opponent.classId,
            opponentRace = duelData.opponent.raceId,
            playerName = self.GetName(duelData.player),
            opponentName = self.GetName(duelData.opponent),
            damageDone = duelData.damageDone,
            damageTaken = duelData.damageTaken,
            healingTaken = duelData.healingTaken or duelData.healingDone,  -- TODO: delete in the future
            damageShielded = duelData.damageShilded,
            startTimestamp = duelData.timestamp,
            duration = duelData.duration,
        })

        self.stats:AddDuel(duelIndex, duelData)
    end

    local task = LibAsync:Create('UpdateDuelsDataRows')

    task:For(ipairs(self.duels)):Do(HandleDuelData):Then(function() self:UpdateUI() end)

    Log('[D] Updated')
end

function addon:CreateControls()
    local duelsControl = CreateControlFromVirtual('IPM_Duels', IPM_Duels_Container, 'IPM_Duels_Template')

    assert(duelsControl ~= nil, 'Duels control was not created')

    local listControl = duelsControl:GetNamedChild('Listing'):GetNamedChild('ScrollableList')
    local statsControl = duelsControl:GetNamedChild('StatsBlock')

    local function OnSearchTextChanged(editBox, field)
        local newText = string.lower(editBox:GetText())

        Log('[D] New search: ', newText)

        if newText == self.filters[field] then return end

        self.filters[field] = newText
        self:Update()
    end

    local oppSearchBox = duelsControl:GetNamedChild('OpponentSearchBox')
    oppSearchBox:SetHandler('OnTextChanged', function(editBox) OnSearchTextChanged(editBox, 'opponentName') end)

    self.duelsControl = duelsControl
    self.listControl = listControl
    self.statsControl = statsControl
end

local function SelectAllElements(filter)
    for i, item in ipairs(filter.m_sortedItems) do
        filter:SelectItem(item, true)
    end
end

--[[
function addon:InitializePlayerCharactersFilter()
    -- TODO: basically copied from bgs and replaced highlighter fucntions, so can make universal function
    local function InitializeFilter(contorl, entriesData, setFiltersCallback)
        local comboBox = ZO_ComboBox_ObjectFromContainer(contorl)

        comboBox:SetSortsItems(false)
        comboBox:SetFont('ZoFontWinT1')
        comboBox:SetSpacing(4)

        local function OnFilterChanged(comboBox, entryText, entry)
            local newFilters = {}

            for i, itemData in ipairs(comboBox.m_selectedItemData) do
                table.insert(newFilters, itemData.filterType)
            end

            setFiltersCallback(newFilters)

            Log('[D] Selection changed: ', table.concat(comboBox.m_selectedItemData, ','))
        end

        for i, entry in ipairs(entriesData) do
            local item = comboBox:CreateItemEntry(entry.text, OnFilterChanged)
            item.filterType = entry.type

            comboBox:AddItem(item)
        end

        return comboBox
    end

    local numCharacters = GetNumCharacters()
    local entriesData = {}

    for i = 1, numCharacters do
        local name, _, _, _, _, _, characterId, _ = GetCharacterInfo(i)
        local formattedName = zo_strformat('<<1>>', name)

        entriesData[i] = {
            text = formattedName,
            type = characterId,
        }
    end

    local function callback(newFilters)
        -- TODO: clear table instead
        for characterId, _ in pairs(self.filters.playerCharacters) do
            self.filters.playerCharacters[characterId] = false
        end

        for _, characterId in ipairs(newFilters) do
            self.filters.playerCharacters[characterId] = true
        end

        self:Update()
    end

    local filterControl = GetControl(self.duelsControl, 'FilterPlayerCharacters')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Character|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Character/$d Characters]>> Selected')

    for i, item in ipairs(filter.m_sortedItems) do
        -- Log('[D] %d - %s', i, item.name)
        if self.filters.playerCharacters[item.filterType] then
            filter:SelectItem(item, true)
            Log('[D] Selecting %s', item.name)
        end
    end
end
]]

addon.InitializePlayerCharactersFilter = IPM_Shared.InitializePlayerCharactersFilter

function addon:Initialize(naming, selectedCharacters)
    self.duels = IPM_DUELS_MANAGER.duels
    self.stats = IPM_DuelsStats:New()

    local buffer = {}
    local NAMINGS = {
        [1] = function(data)
            if not buffer[data.characterName] then
                buffer[data.characterName] = zo_strformat('<<1>>', data.characterName)
            end
            return buffer[data.characterName]
        end,
        [2] = function(data)
            if not buffer[data.displayName] then
                buffer[data.displayName] = data.displayName
            end
            return buffer[data.displayName]
        end,
        [3] = function(data)
            if not buffer[data.displayName] then
                buffer[data.displayName] = zo_strformat('<<1>> (<<2>>)', data.displayName, data.characterName)
            end
            return buffer[data.displayName]
        end,
    }
    self.GetName = NAMINGS[naming]

    self:CreateControls()
    self:CreateScrollListDataType()

    local function OpponentNameFilter(duelData)
        if self.filters.opponentName == '' then return true end

        local characterName = string.lower(duelData.opponent.characterName)
        local displayName = string.lower(duelData.opponent.displayName)

        if string.find(displayName, self.filters.opponentName) or string.find(characterName, self.filters.opponentName) then
            return true
        end
    end
    self:AddFilter(OpponentNameFilter)

    local function PlayerCharactersFilter(duelData)
        return self.filters.playerCharacters[duelData.player.characterId]
    end
    self:AddFilter(PlayerCharactersFilter)

    self.filters.playerCharacters = selectedCharacters
    if IPM_Shared.TableLength(self.filters.playerCharacters) < 1 then
        self.filters.playerCharacters[GetCurrentCharacterId()] = true
    end
    self:InitializePlayerCharactersFilter(GetControl(self.duelsControl, 'FilterPlayerCharacters'))

    Log('[D] UI initialized')
end
--#endregion IPM DUELS ADDON

do
    IPM_DUELS_UI = addon
end

--[[
-- ZO_GetBattlegroundTeamIcon
]]

function ProcessSlashCommand(cmd)
    Log('Command %s received', cmd)

	if cmd == 'update' or cmd == 'u' then
		addon:Update()
    elseif cmd == 'x2' then
        local len = #PvPMeterDuelsData['EU']
        local duels = PvPMeterDuelsData['EU']
        for i = 1, len do
            duels[#duels+1] = duels[i]
        end
        Log('New lenght: %d', #duels)
        addon:Update()
    elseif cmd == 'one' then
        local firstDuel = ZO_DeepTableCopy(PvPMeterDuelsData['EU'][1])
        PvPMeterDuelsData['EU'] = {firstDuel}
        addon:Update()
    elseif cmd == ':2' then
        local duels = PvPMeterDuelsData['EU']
        for i = #duels, zo_round(#duels/2), -1 do
            PvPMeterDuelsData['EU'][i] = nil
        end
        addon:Update()
    end
end

SLASH_COMMANDS['/ipmd'] = ProcessSlashCommand