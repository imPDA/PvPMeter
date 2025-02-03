local addon = {}

addon.name = 'IPM_BATTLEGROUNDS_UI'

addon.listControl = nil
addon.statsControl = nil

local TEAM_TYPE_4_SOLO = 1
local TEAM_TYPE_8_SOLO = 2
local TEAM_TYPE_4_GROUP = 3
local TEAM_TYPE_8_GROUP = 4

addon.filters = {
    size = {
        TEAM_TYPE_4_SOLO,
        TEAM_TYPE_8_SOLO,
        TEAM_TYPE_4_GROUP,
        TEAM_TYPE_8_GROUP,
    },
    modes = {
        BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG,
        BATTLEGROUND_GAME_TYPE_CRAZY_KING,
        BATTLEGROUND_GAME_TYPE_DEATHMATCH,
        BATTLEGROUND_GAME_TYPE_DOMINATION,
        BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL,
        BATTLEGROUND_GAME_TYPE_MURDERBALL,
    },
    playerCharacters = {}
}

local Log = IPM_Logger('MATCHES_UI')

--#region IPM BATTLEGROUNDS STATS
local IPM_BattlegroundsStats = {}

function IPM_BattlegroundsStats:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    return o
end

function IPM_BattlegroundsStats:Clear()
    self.totalMatches = 0
    self.totalWon = 0
    self.totalLost = 0
    self.totalTied = 0
    -- self.totalLeft = 0
    self.totalKills = 0
    self.totalDeaths = 0
    self.totalAssists = 0
    self.totalDamageDone = 0
    self.totalHealingDone = 0
    self.totalDamageTaken = 0

    self.lastProceededIndex = 0
end

function IPM_BattlegroundsStats:AddMatch(index, data)
    if self.lastProceededIndex and index <= self.lastProceededIndex then return end
    self.lastProceededIndex = index

    self.totalMatches       = self.totalMatches     + 1
    self.totalKills         = self.totalKills       + data.kills
    self.totalDeaths        = self.totalDeaths      + data.deaths
    self.totalAssists       = self.totalAssists     + data.assists
    self.totalDamageDone    = self.totalDamageDone  + data.damageDone
    self.totalHealingDone   = self.totalHealingDone + data.healingDone
    self.totalDamageTaken   = self.totalDamageTaken + data.damageTaken

    if data.result == BATTLEGROUND_RESULT_WIN then
        self.totalWon = self.totalWon + 1
    elseif data.result == BATTLEGROUND_RESULT_LOSS then
        self.totalLost = self.totalLost + 1
    elseif data.result == BATTLEGROUND_RESULT_TIE then
        self.totalTied = self.totalTied + 1
    end

    -- self.totalLeft = self.totalLeft + 1

    self.lastProceededIndex = 0
end
--#endregion IPM BATTLEGROUNDS STAT

--#region IPM BATTLEGROUNDS ADDON
local SORTABLE_HEADERS = {
    ['Index'] = 'index',
    ['Score'] = 'score',
    ['Kills'] = 'kills',
    ['Deaths'] = 'deaths',
    ['Assists'] = 'assists',
    ['DamageDone'] = 'damageDone',
    ['HealingDone'] = 'healingDone',
    ['DamageTaken'] = 'damageTaken',
}

local IS_LESS_THAN = -1
local IS_EQUAL_TO = 0
local IS_GREATER_THAN = 1

local function SortingFunction(left, right, sortingKey, sortingOrder, tiebreaker)
    local value1, value2 = left[sortingKey], right[sortingKey]

    -- Log(value1, value2)

    local compareResult
    if value1 < value2 then
        compareResult = IS_LESS_THAN
    elseif value1 > value2 then
        compareResult = IS_GREATER_THAN
    else
        compareResult = IS_EQUAL_TO
    end

    if compareResult == IS_EQUAL_TO then
        if tiebreaker then
            return SortingFunction(left, right, tiebreaker)
        end
    else
        if sortingOrder == ZO_SORT_ORDER_UP then
            return compareResult == IS_LESS_THAN
        end

        return compareResult == IS_GREATER_THAN
    end
end

function addon:ApplySorting(preventCommit)
    if not self.currentSortingKey then return end

    Log('[B] Sorting requested by %s (%s)', self.currentSortingKey, tostring(self.currentSortOrder))

    local scrollData = ZO_ScrollList_GetDataList(self.listControl)
    assert(scrollData ~= nil, 'Scroll data is nil')

    table.sort(scrollData, function(entry1, entry2)
        local left, right = self.matchSummaries[entry1.data.matchIndex], self.matchSummaries[entry2.data.matchIndex]
        return SortingFunction(left, right, self.currentSortingKey, self.currentSortOrder, 'index')
    end)

    if not preventCommit then
        ZO_ScrollList_Commit(self.listControl)
    end
end

function addon:SetShit(value)
    local shit = IPM_BGsStatsBlockShit
    local r, g, b = IPM_Shared.Blend({1, 0, 0}, {0, 1, 0}, value)

    GetControl(shit, 'Bar'):StartFixedCooldown(value, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)  -- TODO
    GetControl(shit, 'Bar'):SetFillColor(r, g, b)
    GetControl(shit, 'Winrate'):SetText(string.format('%d%%', value * 100))
    GetControl(shit, 'Winrate'):SetColor(r, g, b)
end

function addon:UpdateStatsControl()
    self.statsControl:GetNamedChild('TotalMatchesValue'):SetText(IPM_Shared.FormatNumber(self.stats.totalMatches))

    local winrate = IPM_Shared.PossibleNan(self.stats.totalWon / self.stats.totalMatches)
    self.statsControl:GetNamedChild('WinrateValue'):SetText(
        string.format(
            '%.1f %% (|c00FF00%d|r / |cFF0000%d|r / |c555555%d|r)',
            winrate * 100,
            IPM_Shared.FormatNumber(self.stats.totalWon),
            IPM_Shared.FormatNumber(self.stats.totalLost),
            IPM_Shared.FormatNumber(self.stats.totalTied)
        )
    )

    self.statsControl:GetNamedChild('KDValue'):SetText(
        string.format('%.1f', IPM_Shared.PossibleNan(self.stats.totalKills / self.stats.totalDeaths))
    )

    -- TODO: total left
    -- self.statsControl:GetNamedChild('TotalKDAValue'):SetText(
    --     string.format('%d / %d / %d', self.stats.totalKills, self.stats.totalDeaths, self.stats.totalAssists)
    -- )

    -- self.statsControl:GetNamedChild('KDAValue'):SetText(
    --     string.format(
    --         '%.1f / %.1f / %.1f',
    --         IPM_Shared.PossibleNan(self.stats.totalKills / self.stats.totalMatches),
    --         IPM_Shared.PossibleNan(self.stats.totalDeaths / self.stats.totalMatches),
    --         IPM_Shared.PossibleNan(self.stats.totalAssists / self.stats.totalMatches)
    --     )
    -- )
    -- self.statsControl:GetNamedChild('TotalsValue'):SetText(
    --     string.format(
    --         '%s / %s / %s',
    --         IPM_Shared.FormatNumber(self.stats.totalDamageDone),
    --         IPM_Shared.FormatNumber(self.stats.totalHealingDone),
    --         IPM_Shared.FormatNumber(self.stats.totalDamageTaken)
    --     )
    -- )

    local KDAStatsControl = self.statsControl:GetNamedChild('KDAStats')
    KDAStatsControl:GetNamedChild('KSum'):SetText(self.stats.totalKills)
    KDAStatsControl:GetNamedChild('DSum'):SetText(self.stats.totalDeaths)
    KDAStatsControl:GetNamedChild('ASum'):SetText(self.stats.totalAssists)

    KDAStatsControl:GetNamedChild('KAvg'):SetText(string.format('%.1f', IPM_Shared.PossibleNan(self.stats.totalKills / self.stats.totalMatches)))
    KDAStatsControl:GetNamedChild('DAvg'):SetText(string.format('%.1f', IPM_Shared.PossibleNan(self.stats.totalDeaths / self.stats.totalMatches)))
    KDAStatsControl:GetNamedChild('AAvg'):SetText(string.format('%.1f', IPM_Shared.PossibleNan(self.stats.totalAssists / self.stats.totalMatches)))

    self:SetShit(winrate)
end

function addon:CreateControls()
    local battlegroundsControl = CreateControlFromVirtual('IPM_BGs', IPM_BGs_Container, 'IPM_BGs_Template')

    assert(battlegroundsControl ~= nil, 'Battlegrounds control was not created')

    local listControl = battlegroundsControl:GetNamedChild('Listing'):GetNamedChild('ScrollableList')
    local statsControl = battlegroundsControl:GetNamedChild('StatsBlock')

    self.battlegroundsControl = battlegroundsControl
    self.listControl = listControl
    self.statsControl = statsControl

    Log('Controls created')
end

function addon:InitializeSortingHeaders()
    local headersControl = self.battlegroundsControl:GetNamedChild('Listing'):GetNamedChild('Headers')

    local function InitializeSortableHeader(headerName)
        local header = headersControl:GetNamedChild(headerName)
        header:SetMouseEnabled(true)
        header:SetHandler('OnMouseDown', function()
            local sortingKey = SORTABLE_HEADERS[headerName]
            if self.currentSortingKey == sortingKey then
                self.currentSortOrder = not self.currentSortOrder
                -- Log('Changing sort order')
            else
                self.currentSortOrder = ZO_SORT_ORDER_UP
                self.currentSortingKey = sortingKey
            end
            self:ApplySorting()
        end)
    end

    for headerName, _ in pairs(SORTABLE_HEADERS) do
        InitializeSortableHeader(headerName)
    end
end

local GAME_TYPE_ABBREVIATION = {
    [BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG] = 'CR',
    [BATTLEGROUND_GAME_TYPE_CRAZY_KING] = 'CK',
    [BATTLEGROUND_GAME_TYPE_DEATHMATCH] = 'DM',
    [BATTLEGROUND_GAME_TYPE_DOMINATION] = 'Dom',
    [BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL] = 'KOtH',
    [BATTLEGROUND_GAME_TYPE_MURDERBALL] = 'CB',  -- Chaosball
    [BATTLEGROUND_GAME_TYPE_NONE] = 'None',
}

function addon:CreateScrollListDataType()
    -- TODO: make it global because it is used in at least one another place(?)
    local COLOR_OF_RESULT = {
        [BATTLEGROUND_RESULT_WIN] = {0, 1, 0, 1},
        [BATTLEGROUND_RESULT_LOSS] = {1, 0, 0, 1},
        [BATTLEGROUND_RESULT_TIE] = {55/255, 55/255, 55/255, 1},
    }

    local function LayoutRow(rowControl, data, scrollList)
        local summary = self.matchSummaries[data.matchIndex]

        GetControl(rowControl, 'Index'):SetText(data.index)
        if not self.matches[data.matchIndex].playedFromStart then
            GetControl(rowControl, 'Warning'):SetHidden(false)
        end

        if COLOR_OF_RESULT[summary.result] then
            GetControl(rowControl, 'BG'):SetHidden(false)
            GetControl(rowControl, 'BG'):SetColor(unpack(COLOR_OF_RESULT[summary.result]))
        end
        GetControl(rowControl, 'Mode'):SetText(GAME_TYPE_ABBREVIATION[summary.mode])
        GetControl(rowControl, 'Map'):SetText(summary.zone)
        -- GetControl(rowControl, 'Team'):SetText(data.team)
        local classIcon = summary.playerClass and ZO_GetClassIcon(summary.playerClass) or 'EsoUI/Art/Icons/icon_missing.dds'
        GetControl(rowControl, 'Class'):GetNamedChild('ClassIcon'):SetTexture(classIcon)
        GetControl(rowControl, 'Score'):SetText(summary.score)

        GetControl(rowControl, 'Kills'):SetText(summary.kills)
        GetControl(rowControl, 'Deaths'):SetText(summary.deaths)
        GetControl(rowControl, 'Assists'):SetText(summary.assists)

        GetControl(rowControl, 'DamageDone'):SetText(IPM_Shared.FormatNumber(summary.damageDone))
        GetControl(rowControl, 'HealingDone'):SetText(IPM_Shared.FormatNumber(summary.healingDone))
        GetControl(rowControl, 'DamageTaken'):SetText(IPM_Shared.FormatNumber(summary.damageTaken))

        -- TODO is it ok to have selectCallback with EnableSelection or I need to merge them?
        rowControl:SetHandler('OnMouseUp', function(control, button)
            Log('click: ' .. button)
            ZO_ScrollList_MouseClick(scrollList, rowControl)
        end)

        local function BuildTooltip()
            local tooltip = ''

            if summary.entryTimestamp then
                local formattedTime = os.date('%d.%m.%Y %H:%M', summary.entryTimestamp)
                tooltip = tooltip .. formattedTime
            else
                tooltip = tooltip .. '-'
            end
            tooltip = tooltip .. '\n'
            tooltip = tooltip .. zo_strformat('<<1>> (<<2>>)', summary.displayName, summary.characterName)
            tooltip = tooltip .. '\n'
            tooltip = tooltip .. GetRaceName(0, summary.playerRace) .. ' / ' .. GetClassName(0, summary.playerClass)
            tooltip = tooltip .. '\n'
            tooltip = tooltip .. (self.matches[data.matchIndex].playedFromStart == true and 'Played from beginning' or self.matches[data.matchIndex].playedFromStart == false and 'Played NOT from beginning' or '(?) Played from beginning')
            tooltip = tooltip .. '\n'
            tooltip = tooltip .. (self.matches[data.matchIndex].grouped == true and 'Grouped' or self.matches[data.matchIndex].grouped == false and 'Solo' or '(?) Solo/Grouped')
            return tooltip
        end

        -- TODO IMPORTANT: I dont like idea to add custom hadler to every row
        -- it would be better to make some unified callback ?possible
        rowControl:SetHandler('OnMouseDown', function(control, button)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                ClearMenu()
                local particularMatch = self.matches[control.dataEntry.data.matchIndex]  -- data.matchIndex
                if particularMatch.playedFromStart == true then
                    AddCustomMenuItem('Mark as played NOT from beginning', function()
                        particularMatch.playedFromStart = false
                        -- TODO: DRY
                        GetControl(control, 'Warning'):SetHidden(self.matches[data.matchIndex].playedFromStart)
                    end)
                else
                    AddCustomMenuItem('Mark as played from beginning', function()
                        particularMatch.playedFromStart = true
                        -- TODO: DRY
                        GetControl(control, 'Warning'):SetHidden(self.matches[data.matchIndex].playedFromStart)
                    end)
                end
                -- local tooltip = BuildTooltip()
                -- rowControl:SetHandler('OnMouseEnter', function() ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, tooltip) end)
                ShowMenu()
            end
        end)

        rowControl:SetHandler('OnMouseEnter', function()
            local tooltip = BuildTooltip()
            ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, tooltip)
        end)
        rowControl:SetHandler('OnMouseExit', function() ZO_Tooltips_HideTextTooltip() end)
    end

	local control = self.listControl
	local typeId = 1
	local templateName = 'IPM_MatchSummaryRow'
	local height = 32
	local setupFunction = LayoutRow
	local hideCallback = nil
	local dataTypeSelectSound = nil
	local resetControlCallback = nil

	ZO_ScrollList_AddDataType(control, typeId, templateName, height, setupFunction, hideCallback, dataTypeSelectSound, resetControlCallback)

    -- local selectTemplate = 'ZO_ThinListHighlight'
	-- local selectCallback = nil
	-- ZO_ScrollList_EnableSelection(control, selectTemplate, selectCallback)
    Log('Scroll list data type created')
end

local function CreateMatchSummary(matchIndex, matchData)
    local matchSummary = {
        index = matchIndex,
        mode = matchData.type,
        result = matchData.result,
        playerRace = matchData.playerRace,
        playerClass =  matchData.playerClass,
        zone = matchData.zoneName,
        score = 0,
        kills = 0,
        deaths = 0,
        assists = 0,
        damageDone = 0,
        healingDone = 0,
        damageTaken = 0,
        entryTimestamp = matchData.entryTimestamp,
    }

    for roundIndex, roundData in ipairs(matchData.rounds) do
        -- if roundData then
        local roundPlayerData = roundData.players[1]  -- player 1 = always local player

        if roundPlayerData then  -- is it possible player data not be present?
            matchSummary.kills      = matchSummary.kills            + roundPlayerData.kills
            matchSummary.deaths     = matchSummary.deaths           + roundPlayerData.deaths
            matchSummary.assists    = matchSummary.assists          + roundPlayerData.assists
            matchSummary.damageDone     = matchSummary.damageDone   + roundPlayerData.damageDone
            matchSummary.healingDone    = matchSummary.healingDone  + roundPlayerData.healingDone
            matchSummary.damageTaken    = matchSummary.damageTaken  + roundPlayerData.damageTaken
            matchSummary.score      = matchSummary.score            + roundPlayerData.medalScore

            matchSummary.displayName = roundPlayerData.displayName
            matchSummary.characterName = roundPlayerData.characterName
        end
        -- end
    end

    return matchSummary
end

function addon:UpdateMatchSummary(matchIndex)
    if self.matchSummaries[matchIndex] then return end

    self.matchSummaries[matchIndex] = CreateMatchSummary(matchIndex, self.matches[matchIndex])
end

function addon:GetMatchSummary(matchIndex)
    if not self.matchSummaries[matchIndex] then
        self.matchSummaries[matchIndex] = CreateMatchSummary(matchIndex, self.matches[matchIndex])
    end

    return self.matchSummaries[matchIndex]
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

function addon:CalculateStats(task)
    self.stats:Clear()

    local function AddMatch(index, matchIndex)
        self.stats:AddMatch(matchIndex, self:GetMatchSummary(matchIndex))
    end

    return task:Call(function() task:For(ipairs(self.dataRows)):Do(AddMatch) end)
end

function addon:Update()
    -- TODO ShowWarning

    self.dataRows = {}

    local function UpdateSummaries(task)
        return task:For(ipairs(self.dataRows)):Do(function(index, matchIndex) self:UpdateMatchSummary(matchIndex) end)
    end

    local task = LibAsync:Create('UpdateBattlegroundsDataRows')
    IPM_BATTLEGROUNDS_MANAGER
    :GetMatches(task, self.filters, self.dataRows)
    -- :Then(function() UpdateSummaries(task) end)
    :Then(function()
        self:UpdateScrollListControl(task)
        self:CalculateStats(task):Then(function() self:UpdateStatsControl() end)
    end)
    :Then(function() self:ApplySorting(true) end)
    :Then(function() ZO_ScrollList_Commit(self.listControl) end)
end

function addon:UpdateScrollListControl(task)
    local control = self.listControl
    local data = self.dataRows

    local dataList = ZO_ScrollList_GetDataList(control)

    ZO_ScrollList_Clear(control)

    local function CreateAndAddDataEntry(index)
        local matchIndex = data[index]

        local value = {index = index, matchIndex = matchIndex}
        local entry = ZO_ScrollList_CreateDataEntry(1, value)

        table.insert(dataList, entry)
    end
    -- table.sort(dataList, function(a, b) return a.data.index > b.data.index end)

    return task:For(#data, 1, -1):Do(CreateAndAddDataEntry)
    -- ZO_ScrollList_Commit(control)
end

-- local function InitializeFilter(contorl, entriesData, setFiltersCallback)
--     local comboBox = ZO_ComboBox_ObjectFromContainer(contorl)

--     comboBox:SetSortsItems(false)
--     comboBox:SetFont('ZoFontWinT1')
--     comboBox:SetSpacing(4)

--     local function OnFilterChanged(comboBox, entryText, entry)
--         local newFilters = {}

--         for i, itemData in ipairs(comboBox.m_selectedItemData) do
--             table.insert(newFilters, itemData.filterType)
--         end

--         setFiltersCallback(newFilters)
--     end

--     for i, entry in ipairs(entriesData) do
--         local item = comboBox:CreateItemEntry(entry.text, OnFilterChanged)
--         item.filterType = entry.type

--         comboBox:AddItem(item)
--     end

--     return comboBox
-- end

InitializeFilter = IPM_Shared.InitializeFilter

local function SelectAllElements(filter)
    for i, item in ipairs(filter.m_sortedItems) do
        filter:SelectItem(item, true)
    end
end

function addon:InitializeTeamTypeFilter()
    local entriesData = {
        {
            text = '4x4 - Solo',
            type = TEAM_TYPE_4_SOLO,
        },
        {
            text = '8x8 - Solo',
            type = TEAM_TYPE_8_SOLO,
        },
        {
            text = '4x4 - Group',
            type = TEAM_TYPE_4_GROUP,
        },
        {
            text = '8x8 - Group',
            type = TEAM_TYPE_8_GROUP,
        },
    }

    local function callback(newFilters)
        self.filters.size = newFilters
        self:Update()
    end

    local filterControl = GetControl(self.battlegroundsControl, 'FilterTeamType')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Team Type|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Team Type/$d Team Types]>> Selected')

    SelectAllElements(filter)

    return filter
end

function addon:InitializeMatchModeFilter()
    local entriesData = {}

    -- TODO: game types
    for i = 1, 6 do
        table.insert(entriesData, {
            text = string.format(
                '%s (%s)',
                GetString("SI_BATTLEGROUNDGAMETYPE", i),
                GAME_TYPE_ABBREVIATION[i]
            ),
            type = i,
        })
    end

    local function callback(newFilters)
        self.filters.modes = newFilters
        self:Update()
    end

    local filterControl = GetControl(self.battlegroundsControl, 'FilterGameMode')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Match Mode|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Mode/$d Modes]>> Selected')

    SelectAllElements(filter)

    return filter
end

--[[
function addon:InitializePlayerCharactersFilter()
    local numCharacters = GetNumCharacters()
    local entriesData = {}

    for i = 1, numCharacters do
        local name, _, _, classId, _, _, characterId, _ = GetCharacterInfo(i)
        local classIcon = zo_iconFormatInheritColor(ZO_GetClassIcon(classId), 24, 24)
        local formattedName = zo_strformat('<<1>> <<2>>', classIcon, name)

        entriesData[i] = {
            text = formattedName,
            type = characterId,
        }
    end

    local function callback(newFilters)
        for characterId, _ in pairs(self.filters.playerCharacters) do
            self.filters.playerCharacters[characterId] = false
        end

        for _, characterId in ipairs(newFilters) do
            self.filters.playerCharacters[characterId] = true
        end

        self:Update()
    end

    local filterControl = GetControl(self.battlegroundsControl, 'FilterPlayerCharacters')
    local filter = InitializeFilter(filterControl, entriesData, callback)

    filter:SetNoSelectionText('|cFF0000Select Character|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Character/$d Characters]>> Selected')

    for i, item in ipairs(filter.m_sortedItems) do
        -- Log('%d - %s', i, item.name)
        if self.filters.playerCharacters[item.filterType] then
            filter:SelectItem(item, true)
            -- Log('[B] Selecting %s', item.text)
        end
    end

    local function GetTextIf(everyoneSelected)
        return everyoneSelected and 'Deselect All' or 'Select All'
    end

    local function IsEveryoneSelected()
        return filter:GetNumSelectedEntries() == numCharacters
    end

    local function SelectUnselect(button)
        local everyoneSelected = IsEveryoneSelected()

        if everyoneSelected then
            filter:ClearAllSelections()
            for i, item in ipairs(filter.m_sortedItems) do
                self.filters.playerCharacters[item.filterType] = false
            end
        else
            for i, item in ipairs(filter.m_sortedItems) do
                self.filters.playerCharacters[item.filterType] = true
                filter:SelectItem(item, true)
            end
        end

        button:SetText(GetTextIf(everyoneSelected))
        self:Update()
    end

    local selectButton = GetControl(filterControl, 'SelectButton')
    selectButton:SetText(GetTextIf(IsEveryoneSelected()))
    selectButton:SetHandler('OnMouseDown', SelectUnselect)
end
]]

addon.InitializePlayerCharactersFilter = IPM_Shared.InitializePlayerCharactersFilter

function addon:Initialize(naming, selectedCharacters)
    local server = string.sub(GetWorldName(), 1, 2)
    self.matches = PvPMeterBattlegroundsData[server]
    self.matchSummaries = {}
    self.stats = IPM_BattlegroundsStats:New()

    self:CreateControls()
    self:InitializeSortingHeaders()
    self:CreateScrollListDataType()

    local function GoodDataFilter(matchData)
        if not matchData.rounds then
            -- Log('matchData.rounds is not present')
            return
        end

        if #matchData.rounds < 1 then
            -- Log('Less than 1 round: %s', tostring(#matchData.rounds))
            return
        end

        if #matchData.rounds[1].players < 1 then
            -- Log('No players recorded')
            -- TODO: add players on BG start
            return
        end

        if not matchData.result then  -- shit to fix some errors
            -- Log('No match result')
            return
        end

        -- if matchData.result == BATTLEGROUND_RESULT_INVALID then
        --     df('Invalid result')
        --     return
        -- end

        return true
    end
    self:AddFilter(GoodDataFilter)

    local function GetMatchTeamType(matchData)
        if not matchData.teamType then  -- COMPATIBILITY with matches b4 0.1.0b18
            local groupType = GetActivityGroupType(matchData.lfgActivityId)

            if matchData.teamSize == 8 then
                if groupType == LFG_GROUP_TYPE_NONE then
                    matchData.teamType = TEAM_TYPE_8_SOLO
                elseif groupType == LFG_GROUP_TYPE_REGULAR then
                    matchData.teamType = TEAM_TYPE_8_GROUP
                else
                    Log('Problem with GetMatchGroupType, teamSize: %d, groupType: %d', matchData.teamSize, groupType)
                end
            elseif matchData.teamSize == 4 then
                if groupType == LFG_GROUP_TYPE_NONE then
                    matchData.teamType = TEAM_TYPE_4_SOLO
                elseif groupType == LFG_GROUP_TYPE_REGULAR then
                    matchData.teamType = TEAM_TYPE_4_GROUP
                else
                    Log('Problem with GetMatchGroupType, teamSize: %d, groupType: %d', matchData.teamSize, groupType)
                end
            else
                Log('Problem with GetMatchGroupType, teamSize: %d, groupType: %d', matchData.teamSize, groupType)
            end
        end

        return matchData.teamType
    end

    local function TeamSizeFilter(matchData)
        for i, option in ipairs(self.filters.size) do
            if GetMatchTeamType(matchData) == option then return true end
        end
    end
    self:AddFilter(TeamSizeFilter)

    local function GameTypeFilter(matchData)
        for i, option in ipairs(self.filters.modes) do
            if matchData.type == option then return true end  -- type is old name for mode
        end
    end
    self:AddFilter(GameTypeFilter)

    local function PlayerCharactersFilter(matchData)
        local rounds = matchData.rounds
        local players = rounds[1].players
        local player = players[1]
        local chId = player.characterId

        return chId and self.filters.playerCharacters[chId]
    end
    self:AddFilter(PlayerCharactersFilter)

    self:InitializeTeamTypeFilter()
    self:InitializeMatchModeFilter()

    self.filters.playerCharacters = selectedCharacters
    if IPM_Shared.TableLength(self.filters.playerCharacters) < 1 then
        self.filters.playerCharacters[GetCurrentCharacterId()] = true
    end
    self:InitializePlayerCharactersFilter(GetControl(self.battlegroundsControl, 'FilterPlayerCharacters'))
end
--#endregion IPM BATTLEGROUNDS ADDON

do
    IPM_BATTLEGROUNDS_UI = addon
end