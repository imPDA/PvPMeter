local addon = {}

addon.name = 'IPM_BATTLEGROUNDS_UI'

addon.listControl = nil
addon.statsControl = nil

local TEAM_SIZE_4 = 4
local TEAM_SIZE_8 = 8
addon.filters = {
    size = {TEAM_SIZE_4, TEAM_SIZE_8},
    type = {
        BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG,
        BATTLEGROUND_GAME_TYPE_CRAZY_KING,
        BATTLEGROUND_GAME_TYPE_DEATHMATCH,
        BATTLEGROUND_GAME_TYPE_DOMINATION,
        BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL,
        BATTLEGROUND_GAME_TYPE_MURDERBALL,
    },
    playerCharacters = {}
}

local Log = IPM_Log

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
function addon:SetShit(value)
    local shit = IPM_BGsStatsBlockShit
    local r, g, b = IPM_Shared.Blend({1, 0, 0}, {0, 1, 0}, value)

    GetControl(shit, 'Bar'):StartFixedCooldown(value, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)  -- TODO
    GetControl(shit, 'Bar'):SetFillColor(r, g, b)
    GetControl(shit, 'Winrate'):SetText(string.format('%d%%', value * 100))
    GetControl(shit, 'Winrate'):SetColor(r, g, b)
end

function addon:UpdateStatsControl()
    self.statsControl:GetNamedChild('TotalMatchesValue'):SetText(self.stats.totalMatches)

    local winrate = IPM_Shared.PossibleNan(self.stats.totalWon / self.stats.totalMatches)
    self.statsControl:GetNamedChild('WinrateValue'):SetText(
        string.format('%.1f %% (|c00FF00%d|r / |cFF0000%d|r / |c555555%d|r)', winrate * 100, self.stats.totalWon, self.stats.totalLost, self.stats.totalTied)
    )

    -- TODO: total left
    self.statsControl:GetNamedChild('TotalKDAValue'):SetText(
        string.format('%d / %d / %d', self.stats.totalKills, self.stats.totalDeaths, self.stats.totalAssists)
    )

    self.statsControl:GetNamedChild('KDAValue'):SetText(
        string.format(
            '%.1f / %.1f / %.1f',
            IPM_Shared.PossibleNan(self.stats.totalKills / self.stats.totalMatches),
            IPM_Shared.PossibleNan(self.stats.totalDeaths / self.stats.totalMatches),
            IPM_Shared.PossibleNan(self.stats.totalAssists / self.stats.totalMatches)
        )
    )
    self.statsControl:GetNamedChild('TotalsValue'):SetText(
        string.format(
            '%s / %s / %s',
            IPM_Shared.FormatNumber(self.stats.totalDamageDone),
            IPM_Shared.FormatNumber(self.stats.totalHealingDone),
            IPM_Shared.FormatNumber(self.stats.totalDamageTaken)
        )
    )

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
        if COLOR_OF_RESULT[data.result] then
            GetControl(rowControl, 'BG'):SetHidden(false)
            GetControl(rowControl, 'BG'):SetColor(unpack(COLOR_OF_RESULT[data.result]))
        end
        GetControl(rowControl, 'Index'):SetText(data.index)
        GetControl(rowControl, 'Type'):SetText(GAME_TYPE_ABBREVIATION[data.type])
        GetControl(rowControl, 'Map'):SetText(data.zone)
        -- GetControl(rowControl, 'Team'):SetText(data.team)
        local classIcon = data.class and ZO_GetClassIcon(data.class) or 'EsoUI/Art/Icons/icon_missing.dds'
        GetControl(rowControl, 'Class'):GetNamedChild('ClassIcon'):SetTexture(classIcon)
        GetControl(rowControl, 'Score'):SetText(data.score)

        GetControl(rowControl, 'Kills'):SetText(data.kills)
        GetControl(rowControl, 'Deaths'):SetText(data.deaths)
        GetControl(rowControl, 'Assists'):SetText(data.assists)

        GetControl(rowControl, 'DamageDone'):SetText(IPM_Shared.FormatNumber(data.damageDone))
        GetControl(rowControl, 'HealingDone'):SetText(IPM_Shared.FormatNumber(data.healingDone))
        GetControl(rowControl, 'DamageTaken'):SetText(IPM_Shared.FormatNumber(data.damageTaken))

        -- TODO is it ok to have selectCallback with EnableSelection or I need to merge them?
        rowControl:SetHandler('OnMouseUp', function(control, button)
            Log('click: ' .. button)
            ZO_ScrollList_MouseClick(scrollList, rowControl)
        end)

        local tooltip = ''

        if data.startTimestamp then
            local formattedTime = os.date('%d.%m.%Y %H:%M', data.startTimestamp)
            tooltip = tooltip .. formattedTime
        else
            tooltip = tooltip .. '-'
        end
        tooltip = tooltip .. '\n'
        tooltip = tooltip .. zo_strformat('<<1>> (<<2>>)', data.displayName, data.characterName)
        tooltip = tooltip .. '\n'
        tooltip = tooltip .. GetRaceName(0, data.race) .. ' / ' .. GetClassName(0, data.class)

        rowControl:SetHandler('OnMouseEnter', function() ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, tooltip) end)
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

local function CreateMatchSummary(matchData)
    local matchSummary = {
        battlegroundType = matchData.type,
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

function addon:AddFilter(filterCallback)
    table.insert(self.filters, filterCallback)
end

function addon:PassFilters(data)
    for _, filter in ipairs(self.filters) do
        if not filter(data) then return end
    end

    return true
end

function addon:Update()
    Log('[B] Updating')

    self.dataRows = {}
    self.stats:Clear()

    -- TODO: renaming
    -- TODO: move Formatting to RowLayout

    local function HandleMatchData(matchIndex, matchData)
        -- Log('Handling %d match', matchIndex)
        if not self:PassFilters(matchData) then return end

        local matchSummary = CreateMatchSummary(matchData)

        table.insert(self.dataRows, {
            index = #self.dataRows + 1,
            type = matchSummary.battlegroundType,
            result = matchSummary.result,
            score = matchSummary.score,
            race = matchSummary.playerRace,
            class =  matchSummary.playerClass,
            zone = matchSummary.zone,
            kills = matchSummary.kills,
            deaths = matchSummary.deaths,
            assists = matchSummary.assists,
            damageDone = matchSummary.damageDone,
            healingDone = matchSummary.healingDone,
            damageTaken = matchSummary.damageTaken,
            startTimestamp = matchSummary.entryTimestamp,
            displayName = matchSummary.displayName,
            characterName = matchSummary.characterName,
            -- TODO: rename startTimestamp to entry timestamp or make it really start (per round)
            -- TODO: battlegroundTeam = playerData.battlegroundTeam,
        })

        self.stats:AddMatch(matchIndex, matchSummary) -- TODO: move out here
    end

    for matchIndex, matchData in ipairs(self.matches) do
        HandleMatchData(matchIndex, matchData)
    end

    self:UpdateUI()
end

local function UpdateScrollList(control, data, rowType)
	local dataCopy = data
	local dataList = ZO_ScrollList_GetDataList(control)

	ZO_ScrollList_Clear(control)

	for i = #dataCopy, 1, -1 do
        local value = dataCopy[i]
		local entry = ZO_ScrollList_CreateDataEntry(rowType, value)
		table.insert(dataList, entry)
	end

	-- table.sort(dataList, function(a, b) return a.data.index > b.data.index end)

	ZO_ScrollList_Commit(control)
end

function addon:UpdateUI()
    Log('[B] Updating UI')
    local SOME_ID = 1
    UpdateScrollList(self.listControl, self.dataRows, SOME_ID)
    self:UpdateStatsControl()
end

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
    end

    for i, entry in ipairs(entriesData) do
        local item = comboBox:CreateItemEntry(entry.text, OnFilterChanged)
        item.filterType = entry.type

        comboBox:AddItem(item)
    end

    return comboBox
end

local function SelectAllElements(filter)
    for i, item in ipairs(filter.m_sortedItems) do
        filter:SelectItem(item, true)
    end
end

function addon:InitializeTeamSizeFilter()
    local entriesData = {
        {
            text = 'Matches 4x4',
            type = TEAM_SIZE_4,
        },
        {
            text = 'Matches 8x8',
            type = TEAM_SIZE_8,
        },
    }

    local function callback(newFilters)
        self.filters.size = newFilters
        self:Update()
    end

    local filterControl = GetControl(self.battlegroundsControl, 'FilterTeamSize')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Team Size|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Size/$d Sizes]>> Selected')

    SelectAllElements(filter)

    return filter
end

function addon:InitializeMatchTypeFilter()
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
        self.filters.type = newFilters
        self:Update()
    end

    local filterControl = GetControl(self.battlegroundsControl, 'FilterGameType')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Match Type|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Type/$d Types]>> Selected')

    SelectAllElements(filter)

    return filter
end

function addon:InitializePlayerCharactersFilter()
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
        Log('%d - %s', i, item.name)
        if self.filters.playerCharacters[item.filterType] then
            filter:SelectItem(item, true)
            Log('[B] Selecting %s', item.text)
        end
    end
end

function addon:Initialize(naming, selectedCharacters)
    local server = string.sub(GetWorldName(), 1, 2)
    self.matches = PvPMeterBattlegroundsData[server]
    self.stats = IPM_BattlegroundsStats:New()

    self:CreateControls()
    self:CreateScrollListDataType()

    local function GoodDataFilter(matchData)
        if not matchData.rounds then
            Log('matchData.rounds is not present')
            return
        end

        if #matchData.rounds < 1 then
            Log('Less than 1 round: %s', tostring(#matchData.rounds))
            return
        end

        if #matchData.rounds[1].players < 1 then
            Log('No players recorded')
            -- TODO: add players on BG start
            return
        end

        if not matchData.result then  -- shit to fix some errors
            Log('No match result')
            return
        end

        -- if matchData.result == BATTLEGROUND_RESULT_INVALID then
        --     df('Invalid result')
        --     return
        -- end

        return true
    end
    self:AddFilter(GoodDataFilter)

    local function TeamSizeFilter(matchData)
        for i, option in ipairs(self.filters.size) do
            if matchData.teamSize == option then return true end
        end
    end
    self:AddFilter(TeamSizeFilter)

    local function GameTypeFilter(matchData)
        for i, option in ipairs(self.filters.type) do
            if matchData.type == option then return true end
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

    self:InitializeTeamSizeFilter()
    self:InitializeMatchTypeFilter()

    self.filters.playerCharacters = selectedCharacters
    if IPM_Shared.TableLength(self.filters.playerCharacters) < 1 then
        self.filters.playerCharacters[GetCurrentCharacterId()] = true
    end
    self:InitializePlayerCharactersFilter()
end
--#endregion IPM BATTLEGROUNDS ADDON

do
    IPM_BATTLEGROUNDS_UI = addon
end