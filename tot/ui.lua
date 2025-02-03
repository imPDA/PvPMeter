local addon = {}

addon.name = 'IPM_TOT_UI'

addon.listControl = nil
addon.statsControl = nil

addon.filters = {
    opponentName = '',
    playerCharacters = {},
}

local Log = IPM_Logger('TOT_UI')

--#region IPM TOT STATISTICS
IPM_TOTStats = {}

function IPM_TOTStats:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    return o
end

function IPM_TOTStats:Clear()
    self.totalGames = 0
    self.totalFP = 0
    self.totalSP = 0
    self.totalWonFP = 0
    self.totalLostFP = 0
    self.totalWonSP = 0
    self.totalLostSP = 0
    self.totalDuration = 0
    self.lastProceededIndex = nil
end

-- h5. TributeVictoryType
local WIN = 1
local LOSS = 2

function IPM_TOTStats:AddGame(index, data)
    if self.lastProceededIndex and index <= self.lastProceededIndex then return end
    self.lastProceededIndex = index

    self.totalGames             = self.totalGames           + 1
    -- self.totalDuration          = self.totalDuration        + (data.duration        or 0)

    if data.win then
        if data.fp then
            self.totalWonFP = self.totalWonFP + 1
            self.totalFP = self.totalFP + 1
        else
            self.totalWonSP = self.totalWonSP + 1
            self.totalSP = self.totalSP + 1
        end
    else
        if data.fp then
            self.totalLostFP = self.totalLostFP + 1
            self.totalFP = self.totalFP + 1
        else
            self.totalLostSP = self.totalLostSP + 1
            self.totalSP = self.totalSP + 1
        end
    end
end
--#endregion IPM TOT STATISTICS

--#region IPM DUELS ADDON
function addon:SetShit(value)
    local shit = IPM_TOTStatsBlockShit
    local r, g, b = IPM_Shared.Blend({1, 0, 0}, {0, 1, 0}, value)  -- {0.22, 0.08, 0.69}

    GetControl(shit, 'Bar'):StartFixedCooldown(value, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)  -- TODO
    GetControl(shit, 'Bar'):SetFillColor(r, g, b)
    GetControl(shit, 'Winrate'):SetText(string.format('%d%%', value * 100))
    GetControl(shit, 'Winrate'):SetColor(r, g, b)
end

function addon:UpdateStatsControl()
    local totalGames = self.stats.totalFP + self.stats.totalSP
    self.statsControl:GetNamedChild('TotalGamesValue'):SetText(totalGames)

    local totalWon = self.stats.totalWonFP + self.stats.totalWonSP
    local totalLost = self.stats.totalLostFP + self.stats.totalLostSP
    local winrate = IPM_Shared.PossibleNan(totalWon / totalGames)
    self.statsControl:GetNamedChild('WinrateValue'):SetText(
        string.format('%.1f %% (|c00FF00%d|r / |cFF0000%d|r)', winrate * 100, totalWon, totalLost)
    )

    -- self.statsControl:GetNamedChild('TotalsValue'):SetText(
    --     string.format(
    --         '%s / %s / %s',
    --         IPM_Shared.FormatNumber(self.stats.totalDamageDone),
    --         IPM_Shared.FormatNumber(self.stats.totalDamageTaken),
    --         IPM_Shared.FormatNumber(self.stats.totalHealingTaken)
    --     )
    -- )

    self:SetShit(winrate)
end

-- TODO: make color uniforme and global
local COLOR_OF_RESULT = {
    [WIN] = ZO_ColorDef:New(0, 1, 0, 1),
    [LOSS] = ZO_ColorDef:New(1, 0, 0, 1),
    -- [PLAYER_FORFEIT] = {35/255, 35/255, 35/255, 1},
    -- [OPPONENT_FORFEIT] = {75/255, 75/255, 75/255, 1},
}
local NEUTRAL = ZO_ColorDef:New(75/255, 75/255, 75/255, 1)

function addon.GetName(data)
    assert(false, 'Must be owerritten!')
end

function addon:CreateScrollListDataType()
    local function LayoutRow(rowControl, data, scrollList)
        local game = IPM_TOT_MANAGER.games[data.gameIndex]

        local upIcon = zo_iconFormatInheritColor('/esoui/art/tooltips/arrow_up.dds', 12, 12)
        local downIcon = zo_iconFormatInheritColor('/esoui/art/tooltips/arrow_down.dds', 12, 12)
        if game.win ~= nil then
            local result = game.win and WIN or LOSS
            GetControl(rowControl, 'BG'):SetHidden(false)
            GetControl(rowControl, 'Result'):SetText(game.win and 'W' or 'L')
            GetControl(rowControl, 'Result'):SetColor(COLOR_OF_RESULT[result]:UnpackRGBA())
        end
        GetControl(rowControl, 'Index'):SetText(data.index)

        local duration = ImpTools.SecondsToTime(zo_round(game.duration / 1000))
        GetControl(rowControl, 'Duration'):SetText(duration)

        GetControl(rowControl, 'OpponentName'):SetText(game.opponent.name)

        local fp = (game.fp == nil and 'U') or (game.fp and 'Y' or 'N')
        GetControl(rowControl, 'FirstPick'):SetText(fp)
        GetControl(rowControl, 'Score'):SetText(string.format('%d/%d', game.player.score or 0, game.opponent.score or 0))

        local THE_LESS_THE_BETTER = -1
        local function IconSighColor(before, after, direction)
            direction = direction or 1
            if after then
                if before then
                    local diff = (after - before) * direction

                    local icon = diff >= 0 and upIcon or downIcon
                    local sign = diff >= 0 and '+' or ''
                    local color = diff >= 0 and COLOR_OF_RESULT[WIN] or COLOR_OF_RESULT[LOSS]

                    return color:Colorize(string.format('%s%d (%s%d)', icon, after, sign, diff))
                else
                    return after
                end
            else
                return '?'
            end
        end

        GetControl(rowControl, 'PlayerMMR'):SetText(IconSighColor(game.player.atStart.mmr, game.player.atEnd.mmr))
        GetControl(rowControl, 'Rank'):SetText(IconSighColor(game.player.atStart.rank, game.player.atEnd.rank, THE_LESS_THE_BETTER))

        GetControl(rowControl, 'TopPercent'):SetText(string.format('%.1f%%', (game.player.atEnd.topP or 0) * 100))

        -- rowControl:SetHandler('OnMouseUp', function()
        --     d('click')
        --     ZO_ScrollList_MouseClick(scrollList, rowControl)
        -- end)

        local tooltip = ''

        if game.timestamp then
            local formattedTime = os.date('%d.%m.%Y %H:%M', game.timestamp)
            tooltip = tooltip .. formattedTime
        end

        rowControl:SetHandler('OnMouseEnter', function() ZO_Tooltips_ShowTextTooltip(rowControl, LEFT, tooltip) end)
        rowControl:SetHandler('OnMouseExit', function() ZO_Tooltips_HideTextTooltip() end)
    end

	local control = self.listControl
	local typeId = 1
	local templateName = 'IPM_TOTSummaryRow'  -- TODO: change
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

function addon:UpdateScrollListControl(task)
    local control = self.listControl
    local data = self.dataRows

	local dataList = ZO_ScrollList_GetDataList(control)

	ZO_ScrollList_Clear(control)

    local function CreateAndAddDataEntry(index)
        local value = {index = index, gameIndex = data[index]}
        local entry = ZO_ScrollList_CreateDataEntry(1, value)
		table.insert(dataList, entry)
    end

	-- table.sort(dataList, function(a,b) return a.data.index > b.data.index end)

    return task:Call(function() task:For(#data, 1, -1):Do(CreateAndAddDataEntry):Then(function() ZO_ScrollList_Commit(control) end) end)
end

function addon:CalculateStats(task)
    self.stats:Clear()

    local function AddGame(index, gameIndex)
        self.stats:AddGame(gameIndex, self.games[gameIndex])
    end

    return task:Call(function() task:For(ipairs(self.dataRows)):Do(AddGame) end)
end

local function HideWarning(hidden)
    hidden = hidden == nil or hidden
    GetControl(IPM_TOT, 'Warning'):SetHidden(hidden)
end

local function ShowWarning()
    return HideWarning(false)
end

function addon:Update()
    if #self.games > 60000 then ShowWarning() end

    self.dataRows = {}

    local task = LibAsync:Create('UpdateToTDataRows')

    IPM_TOT_MANAGER:GetGames(task, self.filters, self.dataRows):Then(function()
        self:UpdateScrollListControl(task)
        self:CalculateStats(task):Then(function() self:UpdateStatsControl() end)
    end):Then(HideWarning)
end

function addon:CreateControls()
    local totControl = CreateControlFromVirtual('IPM_TOT', IPM_TOT_Container, 'IPM_TOT_Template')

    assert(totControl ~= nil, 'Tribute control was not created')

    local listControl = totControl:GetNamedChild('Listing'):GetNamedChild('ScrollableList')
    local statsControl = totControl:GetNamedChild('StatsBlock')

    local function OnSearchTextChanged(editBox, field)
        local newText = string.lower(editBox:GetText())

        Log('[T] New search: ', newText)

        if newText == self.filters[field] then return end

        self.filters[field] = newText
        self:Update()
    end

    local oppSearchBox = totControl:GetNamedChild('OpponentSearchBox')
    oppSearchBox:SetHandler('OnTextChanged', function(editBox) OnSearchTextChanged(editBox, 'opponentName') end)

    self.totControl = totControl
    self.listControl = listControl
    self.statsControl = statsControl
end

local function SelectAllElements(filter)
    for i, item in ipairs(filter.m_sortedItems) do
        filter:SelectItem(item, true)
    end
end

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

            Log('Selection changed: ', table.concat(comboBox.m_selectedItemData, ','))
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

    local filterControl = GetControl(self.totControl, 'FilterPlayerCharacters')
    local filter = InitializeFilter(filterControl, entriesData, callback)
    filter:SetNoSelectionText('|cFF0000Select Character|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Character/$d Characters]>> Selected')

    for i, item in ipairs(filter.m_sortedItems) do
        -- Log('%d - %s', i, item.name)
        if self.filters.playerCharacters[item.filterType] then
            filter:SelectItem(item, true)
            Log('[T] Selecting %s', item.text)
        end
    end
end

function addon:Initialize(naming, selectedCharacters)
    self.games = IPM_TOT_MANAGER.games
    self.stats = IPM_TOTStats:New()

    -- local buffer = {}
    -- local NAMINGS = {
    --     [1] = function(data)
    --         if not buffer[data.characterName] then
    --             buffer[data.characterName] = zo_strformat('<<1>>', data.characterName)
    --         end
    --         return buffer[data.characterName]
    --     end,
    --     [2] = function(data)
    --         if not buffer[data.displayName] then
    --             buffer[data.displayName] = data.displayName
    --         end
    --         return buffer[data.displayName]
    --     end,
    --     [3] = function(data)
    --         if not buffer[data.displayName] then
    --             buffer[data.displayName] = zo_strformat('<<1>> (<<2>>)', data.displayName, data.characterName)
    --         end
    --         return buffer[data.displayName]
    --     end,
    -- }
    -- self.GetName = NAMINGS[naming]
    self.GetName = function(data) return data.name end

    self:CreateControls()
    self:CreateScrollListDataType()

    local function OpponentNameFilter(data)
        if self.filters.opponentName == '' then return true end

        -- local characterName = string.lower(data.opponent.characterName)
        -- local displayName = string.lower(data.opponent.displayName)

        -- if string.find(displayName, self.filters.opponentName) or string.find(characterName, self.filters.opponentName) then
        --     return true
        -- end

        local name = string.lower(data.opponent.name)
        return string.find(name, self.filters.opponentName) ~= nil
    end
    self:AddFilter(OpponentNameFilter)

    -- local function PlayerCharactersFilter(data)
    --     return self.filters.playerCharacters[data.player.characterId]
    -- end
    -- self:AddFilter(PlayerCharactersFilter)

    -- self.filters.playerCharacters = selectedCharacters
    -- if IPM_Shared.TableLength(self.filters.playerCharacters) < 1 then
    --     self.filters.playerCharacters[GetCurrentCharacterId()] = true
    -- end
    -- self:InitializePlayerCharactersFilter()
end
--#endregion IPM DUELS ADDON

do
    IPM_TOT_UI = addon
end

function IPM_OpponentPreview_OnMoveStop(control)
    assert(control ~= nil, 'No preview control')
    local point, relativeTo, relativePoint, offsetX, offsetY = select(2, control:GetAnchor(0))
    IPM_TOT_MANAGER.settings.opponentPreview = IPM_TOT_MANAGER.settings.opponentPreview or {}
    IPM_TOT_MANAGER.settings.opponentPreview.anchor = {point, nil, relativePoint, offsetX, offsetY}
end