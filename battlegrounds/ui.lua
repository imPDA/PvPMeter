local PossibleNan = IMP_STATS_SHARED.PossibleNan

-- ----------------------------------------------------------------------------

local addon = {}

addon.name = 'IMP_STATS_MATCHES_UI'

local EVENT_NAMESPACE = addon.name

-- addon.listControl = nil
-- addon.statsControl = nil

-- TODO: some global to avoid duplication, it also present in newMatchManager
local TEAM_TYPE_4_SOLO = 1
local TEAM_TYPE_8_SOLO = 2
local TEAM_TYPE_4_GROUP = 3
local TEAM_TYPE_8_GROUP = 4

addon.filters = {
    -- teamTypes = {
    --     TEAM_TYPE_4_SOLO,
    --     TEAM_TYPE_8_SOLO,
    --     TEAM_TYPE_4_GROUP,
    --     TEAM_TYPE_8_GROUP,
    -- },
    -- modes = {
    --     BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG,
    --     BATTLEGROUND_GAME_TYPE_CRAZY_KING,
    --     BATTLEGROUND_GAME_TYPE_DEATHMATCH,
    --     BATTLEGROUND_GAME_TYPE_DOMINATION,
    --     BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL,
    --     BATTLEGROUND_GAME_TYPE_MURDERBALL,
    -- },
    -- selectedCharacters = {}
}

addon.selections = {
    teamTypes = {
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
    characters = {}
}

local Log = IMP_STATS_Logger('MATCHES_UI')

--#region IMP STATS MATCHES STATS
local MatchesStats = {}

function MatchesStats:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    return o
end

function MatchesStats:Clear()
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

    -- self.lastProceededIndex = 0
end

function MatchesStats:AddMatch(index, data)
      -- TODO: make actual use of it or remove
    -- if self.lastProceededIndex and index <= self.lastProceededIndex then return end
    -- self.lastProceededIndex = index

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

    -- self.lastProceededIndex = 0
end
--#endregion

--#region IMP STATS MATCHES ADDON
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

function addon:UpdateStatsControl()
    local totalMatches = #self.matches  -- self.stats.totalMatches

    self.statsControl:GetNamedChild('TotalMatchesValue'):SetText(totalMatches)

    local N = self.stats.totalMatches
    if IMP_STATS_MATCHES_MANAGER.sv.last150 then N = math.min(N, 150) end
    self.statsControl:GetNamedChild('MatchesCount'):SetText(zo_strformat("Stats over last <<1>> <<m:2>>", N, 'match^n'))

    local winrate = PossibleNan(self.stats.totalWon / self.stats.totalMatches)
    self.statsControl:GetNamedChild('WinrateValue'):SetText(
        string.format(
            '%.1f %% (|c00FF00%d|r / |cFF0000%d|r / |c555555%d|r)',
            winrate * 100,
            IMP_STATS_SHARED.FormatNumber(self.stats.totalWon),
            IMP_STATS_SHARED.FormatNumber(self.stats.totalLost),
            IMP_STATS_SHARED.FormatNumber(self.stats.totalTied)
        )
    )

    self.statsControl:GetNamedChild('KDValue'):SetText(
        string.format('%.1f', PossibleNan(self.stats.totalKills / self.stats.totalDeaths))
    )

    -- TODO: left

    local KDAStatsControl = self.statsControl:GetNamedChild('KDAStats')
    KDAStatsControl:GetNamedChild('KSum'):SetText(IMP_STATS_SHARED.FormatNumber(self.stats.totalKills))
    KDAStatsControl:GetNamedChild('DSum'):SetText(IMP_STATS_SHARED.FormatNumber(self.stats.totalDeaths))
    KDAStatsControl:GetNamedChild('ASum'):SetText(IMP_STATS_SHARED.FormatNumber(self.stats.totalAssists))

    KDAStatsControl:GetNamedChild('KAvg'):SetText(string.format('%.1f', PossibleNan(self.stats.totalKills / self.stats.totalMatches)))
    KDAStatsControl:GetNamedChild('DAvg'):SetText(string.format('%.1f', PossibleNan(self.stats.totalDeaths / self.stats.totalMatches)))
    KDAStatsControl:GetNamedChild('AAvg'):SetText(string.format('%.1f', PossibleNan(self.stats.totalAssists / self.stats.totalMatches)))

    IMP_STATS_SHARED.SetGaugeKDAMeter(self.statsControl:GetNamedChild('GaugeKDAMeter'), winrate)
end

function addon:CreateControls()
    local matchesControl = IMP_STATS_MATCHES

    assert(matchesControl ~= nil, 'Matches control was not created')

    local listControl = matchesControl:GetNamedChild('Listing'):GetNamedChild('ScrollableList')
    local statsControl = matchesControl:GetNamedChild('TopBlock'):GetNamedChild('Stats')
    local filtersControl = matchesControl:GetNamedChild('TopBlock'):GetNamedChild('Filters')

    self.matchesControl = matchesControl
    self.listControl = listControl
    self.statsControl = statsControl
    self.filtersControl = filtersControl

    matchesControl:SetHandler("OnShow", function()
        if self.dirty then self:Update() end
    end)

    Log('Controls created')
end

function addon:InitializeSortingHeaders()
    local headersControl = self.matchesControl:GetNamedChild('Listing'):GetNamedChild('Headers')

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
    -- [BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL] = 'KOtH',  -- not present in the game rn
    [BATTLEGROUND_GAME_TYPE_MURDERBALL] = 'CB',  -- Chaosball
    -- [BATTLEGROUND_GAME_TYPE_NONE] = 'None',
}

function addon:CreateScrollListDataType()
    -- TODO: make it global because it is used in at least one another place(?)
    local COLOR_OF_RESULT = {
        [BATTLEGROUND_RESULT_WIN] = {0, 1, 0, 1},
        [BATTLEGROUND_RESULT_LOSS] = {1, 0, 0, 1},
        [BATTLEGROUND_RESULT_TIE] = {55/255, 55/255, 55/255, 1},
    }

    local function LayoutRow(rowControl, data, scrollList)
        local summary = self:GetMatchSummary(data.matchIndex)

        GetControl(rowControl, 'Index'):SetText(data.index)
        -- if not self.matches[data.matchIndex].playedFromStart then
        GetControl(rowControl, 'Warning'):SetHidden(self.matches[data.matchIndex].playedFromStart)
        -- end

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

        GetControl(rowControl, 'DamageDone'):SetText(IMP_STATS_SHARED.FormatNumber(summary.damageDone))
        GetControl(rowControl, 'HealingDone'):SetText(IMP_STATS_SHARED.FormatNumber(summary.healingDone))
        GetControl(rowControl, 'DamageTaken'):SetText(IMP_STATS_SHARED.FormatNumber(summary.damageTaken))

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

                -- if particularMatch.superstar then
                --     AddCustomMenuItem('Open SuperStar', function()
                --         Log('Open SuperStar clicked')
                --         Log(ZO_LinkHandler_ParseLink(particularMatch.superstar))
                --         LINK_HANDLER:FireCallbacks(LINK_HANDLER.LINK_MOUSE_UP_EVENT, particularMatch.superstar, MOUSE_BUTTON_INDEX_LEFT, ZO_LinkHandler_ParseLink(particularMatch.superstar))
                --     end)
                -- end

                ShowMenu()
            end
        end)

        rowControl:SetHandler('OnMouseEnter', function()
            local tooltip = BuildTooltip()
            ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, tooltip)
        end)
        rowControl:SetHandler('OnMouseExit', function() ZO_Tooltips_HideTextTooltip() end)

        GetControl(rowControl, 'Build'):SetHidden(self.matches[data.matchIndex].superstar == nil )
    end

	local control = self.listControl
	local typeId = 1
	local templateName = 'IMP_STATS_MatchSummaryRow'
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
        zone = GetZoneNameById(matchData.zoneId),
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

        -- should I check first player is actually local player?
        if roundPlayerData then
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

-- function addon:PassFilters(data)
--     for _, filter in ipairs(self.filters) do
--         if not filter(data) then return end
--     end

--     return true
-- end

function addon:CalculateStats(task)
    self.stats:Clear()

    local function AddMatch(index, matchIndex)
        matchIndex = self.dataRows[index]
        self.stats:AddMatch(matchIndex, self:GetMatchSummary(matchIndex))
    end

    local LAST_N = #self.dataRows
    if IMP_STATS_MATCHES_MANAGER.sv.last150 then LAST_N = 150 end

    local stopIndex = #self.dataRows
    local startIndex = math.max(1, stopIndex - LAST_N + 1)

    Log('Calculating stats, start: %d, stop: %s', startIndex, stopIndex)

    return task:Call(function() task:For(startIndex, stopIndex):Do(AddMatch) end)  -- ipairs(self.dataRows)
end

function addon:IsHidden()
    return self.matchesControl:IsHidden()
end

function addon:Update()
    -- TODO ShowWarning

    if self:IsHidden() then
        self.dirty = true
        return
    end

    -- TODO: clear via ZO_ClearTable etc.?
    self.dataRows = {}

    -- local function UpdateSummaries(task)
    --     return task:For(ipairs(self.dataRows)):Do(function(index, matchIndex) self:UpdateMatchSummary(matchIndex) end)
    -- end

    local task = LibAsync:Create('UpdateBattlegroundsDataRows')

    IMP_STATS_MATCHES_MANAGER
    :GetMatches(task, self.filters, self.dataRows)
    -- :Then(function() UpdateSummaries(task) end)
    :Then(function()
        self:UpdateScrollListControl(task)
        self:CalculateStats(task):Then(function() self:UpdateStatsControl() end)
    end)
    :Then(function() self:ApplySorting(true) end)
    :Then(function() ZO_ScrollList_Commit(self.listControl) end)
    :Then(function() self.dirty = false end)
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

InitializeFilter = IMP_STATS_SHARED.InitializeFilter

-- local function SelectAllElements(filter)
--     for i, item in ipairs(filter.m_sortedItems) do
--         filter:SelectItem(item, true)
--     end
-- end

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

    local function callback(newSelection)
        self.selections.teamTypes = newSelection
        self:Update()
    end

    local filterControl = GetControl(self.filtersControl, 'FilterTeamType')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Team Type|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Team Type/$d Team Types]>> Selected')

    -- SelectAllElements(filter)
    -- TODO: hash table?
    local function SelectTeamType(teamType)
        for i, item in ipairs(filter.m_sortedItems) do
            if item.filterType == teamType then
                filter:SelectItem(item, true)
                return
            end
        end
    end
    for _, mode in ipairs(self.selections.teamTypes) do
        SelectTeamType(mode)
    end

    return filter
end

function addon:InitializeMatchModeFilter()
    local entriesData = {}

    -- TODO: game types
    for mode, modeName in pairs(GAME_TYPE_ABBREVIATION) do
        table.insert(entriesData, {
            text = string.format(
                '%s (%s)',
                GetString("SI_BATTLEGROUNDGAMETYPE", mode),
               modeName
            ),
            type = mode,
        })
    end

    --[[
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
    ]]

    local function callback(newSelection)
        self.selections.modes = newSelection
        self:Update()
    end

    local filterControl = GetControl(self.filtersControl, 'FilterGameMode')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Match Mode|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Mode/$d Modes]>> Selected')

    -- SelectAllElements(filter)
    -- TODO: hash table?
    local function SelectMode(mode)
        for i, item in ipairs(filter.m_sortedItems) do
            if item.filterType == mode then
                filter:SelectItem(item, true)
                return
            end
        end
    end
    for _, mode in ipairs(self.selections.modes) do
        SelectMode(mode)
    end

    return filter
end

addon.InitializePlayerCharactersFilter = IMP_STATS_SHARED.InitializePlayerCharactersFilter

function addon:Initialize(naming, selections, filterByApi)
    self.matches = IMP_STATS_MATCHES_MANAGER.matches
    self.matchSummaries = {}
    self.stats = MatchesStats:New()

    self:CreateControls()
    self:InitializeSortingHeaders()
    self:CreateScrollListDataType()

    local function GoodDataFilter(matchData)
        -- if not matchData.rounds then
        --     -- Log('matchData.rounds is not present')
        --     return
        -- end

        if not matchData.rounds or #matchData.rounds < 1 then
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
        --     return
        -- end

        return true
    end
    self:AddFilter(GoodDataFilter)

    local function GetMatchTeamType(matchData)
        -- teamType set function moved to MatchManager 1.1.0

        return matchData.teamType
    end

    local function TeamTypeFilter(matchData)
        for i, option in ipairs(self.selections.teamTypes) do
            -- Log('Match %d, teamType: %d', i, GetMatchTeamType(matchData))
            if GetMatchTeamType(matchData) == option then return true end
        end
    end
    self:AddFilter(TeamTypeFilter)

    local function ModeFilter(matchData)
        for i, option in ipairs(self.selections.modes) do
            if matchData.type == option then return true end  -- type is old name for mode
        end
    end
    self:AddFilter(ModeFilter)

    local function CharactersFilter(matchData)
        -- local rounds = matchData.rounds
        -- local players = rounds[1].players
        -- local player = players[1]
        -- local chId = player.characterId
        local chId = matchData.playerCharacterId

        return chId and self.selections.characters[chId]
    end
    -- self:AddFilter(CharactersFilter)  -- TODO: revert b4 production

    if filterByApi then
        local currentApiVerision = GetAPIVersion()
        local function ShowOnlyLastUpdateFilter(matchData)
            return matchData.api == currentApiVerision
        end
        self:AddFilter(ShowOnlyLastUpdateFilter)
    end

    for selectionName, defaultSelectionData in pairs(self.selections) do
        selections[selectionName] = selections[selectionName] or defaultSelectionData
    end
    self.selections = selections
    -- self.selections = selections or self.selections

    self:InitializeTeamTypeFilter()
    self:InitializeMatchModeFilter()

    if IMP_STATS_SHARED.TableLength(self.selections.characters) < 1 then
        self.selections.characters[GetCurrentCharacterId()] = true
    end
    self:InitializePlayerCharactersFilter(GetControl(self.filtersControl, 'CharactersFilter'), self.selections.characters)

    local manager = IMP_STATS_MATCHES_MANAGER
    if manager.states then
        local function OnMatchStateChanged(oldState, newState)
            if newState ~= manager.states.MATCH_STATE_ENDED then return end
            self:Update()
        end

        manager:RegisterCallback(EVENT_NAMESPACE, manager.events.EVENT_MATCH_STATE_CHANGED, OnMatchStateChanged)

        self:Update()
    end
end
--#endregion

function addon:LayoutBuildFor(row)
    if not (row and row.dataEntry and row.dataEntry.data.matchIndex) then return end

    local matchIndex = row.dataEntry.data.matchIndex

    LibDataPacker_Build_LayoutShortBuild(self.matches[matchIndex].superstar)
end

do
    IMP_STATS_MATCHES_UI = addon
end