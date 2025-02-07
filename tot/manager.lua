local addon = {}

addon.name = 'IMP_STATS_TRIBUTE_MANAGER'
addon.playerData = nil

local Log = IMP_STATS_Logger('TRIBUTE_MANAGER')

local function GetOpponentData(opponentName)
    local numEntries = GetNumTributeLeaderboardEntries(TRIBUTE_LEADERBOARD_TYPE_RANKED)
    for i = 1, numEntries do
        local rank, displayName, characterName, score = GetTributeLeaderboardEntryInfo(TRIBUTE_LEADERBOARD_TYPE_RANKED, i)
        if displayName == opponentName then return true, rank, displayName, characterName, score end
    end

    return false
end

--#region IGameManager
local PENDING = 1
local READY = 2

local GameManager = {}

function GameManager:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    self.Initialize(o)

    return o
end

function GameManager.Initialize(game)
    game.timestamp = GetTimeStamp()
    game.gameOver = false

    local name, playerType = GetTributePlayerInfo(TRIBUTE_PLAYER_PERSPECTIVE_SELF)

    game.player = {
        name = name,
        atStart = {},
        atEnd = {},
    }

    local oppName, oppPlayerType = GetTributePlayerInfo(TRIBUTE_PLAYER_PERSPECTIVE_OPPONENT)

    -- TODO: oppPlayerType

    game.opponent = {
        name = oppName,
    }

    game:UpdatePlayerRank()
    game:UpdatePlayerMMR()

    -- TODO: opp rank
end

function GameManager:UpdatePlayerRank(skipRequest)
    local type = self.gameOver and 'final' or 'starting'
    -- Log('[GameManager] Updating player\'s %s rank', type)
    local tbl = self.gameOver and self.player.atEnd or self.player.atStart

    if not tbl.rankStatus then
        tbl.rankStatus = PENDING
        EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_RANK_RECEIVED, function()
            Log('!!!!!!!!!! Rank received')
            self:UpdatePlayerRank(true)
            Log('MMR status: %d', tbl.mmrStatus)
            if not tbl.mmrStatus == READY then self:UpdatePlayerMMR() end
        end)
        Log('[GameManager] Waiting for player\'s %s rank update', type)
    end

    if not skipRequest then Log('[GameManager] Sending request for rank') end

    if skipRequest or RequestTributeLeaderboardRank() == LEADERBOARD_DATA_READY then
        local playerLeaderboardRank, totalLeaderboardPlayers = GetTributeLeaderboardRankInfo()
        local topPercent = playerLeaderboardRank == 0 and 1 or playerLeaderboardRank / totalLeaderboardPlayers

        tbl.rank = math.abs(playerLeaderboardRank)
        tbl.topP = math.abs(topPercent)

        tbl.rankStatus = READY
        Log('[GameManager] Player\'s %s rank updated', type)
        EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_RANK_RECEIVED)
    end
end

function GameManager:UpdatePlayerMMR(skipRequest)
    local type = self.gameOver and 'final' or 'starting'
    -- Log('[GameManager] Updating player\'s %s MMR', type)
    local tbl = self.gameOver and self.player.atEnd or self.player.atStart

    if not tbl.mmrStatus then
        tbl.mmrStatus = PENDING
        EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED, function()
            self:UpdatePlayerMMR(true)
            Log('[GameManager] Rank status: %d', tbl.rankStatus)
            -- if tbl.rankStatus ~= READY then self:UpdatePlayerRank() end
            self:UpdatePlayerRank()
        end)
        Log('[GameManager] Waiting for player\'s %s MMR updates', type)
    end

    if not skipRequest then Log('[GameManager] Sending request for MMR') end

    if skipRequest or QueryTributeLeaderboardData(TRIBUTE_LEADERBOARD_TYPE_RANKED) == LEADERBOARD_DATA_READY then
        local _, score = GetTributeLeaderboardLocalPlayerInfo(TRIBUTE_LEADERBOARD_TYPE_RANKED)

        tbl.mmr = math.abs(score)

        tbl.mmrStatus = READY
        Log('[GameManager] Player\'s %s MMR updated', type)
        EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED)
    end
end

-- function GameManager:UpdateScore(name)
--     local found, rank, displayName, characterName, score = GetOpponentData(name)
--     Log('Updated rank: %d (#%d)', score, rank)
--     EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED)
-- end

--[[
function IMP_TOTGame:InitializeOpponent()
    local name, playerType = GetTributePlayerInfo(TRIBUTE_PLAYER_PERSPECTIVE_OPPONENT)

    self.opponent = {
        name = name,
    }

    -- if playerType == TRIBUTE_PLAYER_TYPE_PLAYER or playerType == TRIBUTE_PLAYER_TYPE_REMOTE_PLAYER then
    --     local found, rank, displayName, characterName, score = GetOpponentData(name)

    --     self.opponent.atStart = {
    --         mmr = found and score or 0,
    --         rank = found and rank or 0,
    --         -- topP = topPercent
    --     }
    --     Log('Rank: %d (#%d)', score, rank)
    -- end

    -- EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED, function() self:UpdateScore(name) end)
    -- QueryTributeLeaderboardData(TRIBUTE_LEADERBOARD_TYPE_RANKED)
end
]]

function GameManager:AddFirstPick()
    self.fp = GetActiveTributePlayerPerspective() == TRIBUTE_PLAYER_PERSPECTIVE_SELF
    Log('Fist pick: %s', tostring(self.fp))
end

function GameManager:WriteGameResults()
    Log('[GameManager] Getting results')
    --A
    local winner, victoryType = GetTributeResultsWinnerInfo()

    self.win = winner == TRIBUTE_PLAYER_PERSPECTIVE_SELF
    self.victoryType = victoryType

    -- B
    local matchDurationMS, goldAccumulated, cardsAcquired = GetTributeMatchStatistics()
    self.duration = matchDurationMS
    self.player.goldAccumulated = goldAccumulated
    self.player.cardsAcquired = cardsAcquired

    -- C
    local playerScore = GetTributePlayerPerspectiveResource(TRIBUTE_PLAYER_PERSPECTIVE_SELF, TRIBUTE_RESOURCE_PRESTIGE)
    local opponentScore = GetTributePlayerPerspectiveResource(TRIBUTE_PLAYER_PERSPECTIVE_OPPONENT, TRIBUTE_RESOURCE_PRESTIGE)
    self.player.score = playerScore
    self.opponent.score = opponentScore
end

function GameManager:OnGameOver()
    self.gameOver = true

    self:WriteGameResults()

    self:UpdatePlayerRank()
    self:UpdatePlayerMMR()
end
--#endregion GameManager

--#region ADDON
function addon:SaveCurrentGame()
    self.games[#self.games+1] = self.currentGame
    self.currentGame = nil
    Log('Game saved, id: %d', #self.games)
end

function addon:UpdateOpponentPreview()
    local statsVsCurrentOpponent = IMP_STATS_TRIBUTE_STATS:New()

    local games = {}
    local function CalculateStats(task)
        statsVsCurrentOpponent:Clear()
        Log('Previous games: %s', table.concat(games, ', '))
        task:For(ipairs(games)):Do(function(index, gameIndex) statsVsCurrentOpponent:AddGame(index, self.games[gameIndex]) end)
    end

    local function UpdateControl()
        local opponent = self.currentGame.opponent

        -- GetControl(self.previewControl, 'OpponentNameValue'):SetText(opponent.name)
        if statsVsCurrentOpponent.totalGames > 0 then
            GetControl(self.previewControl, 'PlayedBefore'):SetText(string.format('Played %d games', statsVsCurrentOpponent.totalGames))
            local winrate = IMP_STATS_SHARED.PossibleNan((statsVsCurrentOpponent.totalWonFP + statsVsCurrentOpponent.totalWonSP) / statsVsCurrentOpponent.totalGames)
            GetControl(self.previewControl, 'WinrateValue'):SetText(string.format('%.1f %%', winrate * 100))
        end

        if opponent.atStart and opponent.atStart.rank then
            -- GetControl(self.previewControl, 'OpponentRank'):SetText('Ladder #57 (754 MMR)')
            GetControl(self.previewControl, 'OpponentRank'):SetText(string.format('Ladder #%d (%d MMR)', opponent.atStart.rank, opponent.atStart.mmr))
        end
    end

    local task = LibAsync:Create('UpdateOpponentPreview')
    self:GetGamesWith(task, self.currentGame.opponent.name, games):Then(CalculateStats):Then(UpdateControl)
end

function addon:ShowOpponentPreview()
    -- update preview data
    self.previewControl:SetHidden(false)
end

function addon:HideOpponentPreview()
    self.previewControl:SetHidden(true)
end

function addon:OnIntro()
    Log('Game started')

    if GetTributeMatchType() ~= TRIBUTE_MATCH_TYPE_COMPETITIVE then
        Log('Not competitive game')
        -- return
    end

    self.currentGame = GameManager:New()

    -- self.currentGame:AddPlayerData()
    -- self.currentGame:AddOpponentData()
end

function addon:OnPatronDraft()
    self.currentGame:AddFirstPick()

    self:UpdateOpponentPreview()
    self:ShowOpponentPreview()
end

function addon:OnGameOver()
    Log('Game over')
    if not self.currentGame then return end

    self.currentGame:OnGameOver()
    -- self.currentGame:AddResults()
    self:SaveCurrentGame()
    self:HideOpponentPreview()

    -- TODO: find better solution
    -- since rating and mmr updated asyncronously, there is situation when
    -- ui starts to update but mmr or rank not updated yet and equal 'nil'
    zo_callLater(function() IMP_STATS_TRIBUTE_UI:Update() end, 2000)
end

function addon:OnGameState(state)
    Log('Game state: %d', state)
    if state == TRIBUTE_GAME_FLOW_STATE_INTRO then
        self:OnIntro()
    elseif state == TRIBUTE_GAME_FLOW_STATE_PATRON_DRAFT then
        self:OnPatronDraft()
    elseif state == TRIBUTE_GAME_FLOW_STATE_GAME_OVER then
        self:OnGameOver()
    end
end

function addon:PlayerActivated(initial)
    local function OnTributeGameFlowStateChanged(_, state)
        self:OnGameState(state)
    end

    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_GAME_FLOW_STATE_CHANGE, OnTributeGameFlowStateChanged)
    -- EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_TRIBUTE_PATRON_DRAFTED, function(...) Log(...) end)

    IMP_STATS_TRIBUTE_UI:Update()
end

function addon:GetGamesWith(task, opponentName, tbl)
    local function ContainsName(searchedName)
        searchedName = string.lower(searchedName)
        local function inner(data)
            return string.find(string.lower(data.opponent.name), searchedName)
        end

        return inner
    end

    local escapedOpponentName = opponentName:gsub('%-', '%%-')
    local nameFilter = ContainsName(escapedOpponentName)

    return self:GetGames(task, {nameFilter}, tbl)
end

function addon:GetGames(task, filters, tbl)
    local function PassFilters(data)
        for _, filter in ipairs(filters) do
            if not filter(data) then return end
        end

        return true
    end

    local function FilterGames(gameIndex, gameData)
        if PassFilters(gameData) then table.insert(tbl, gameIndex) end
    end

    return task:For(ipairs(self.games)):Do(FilterGames)
end
--#endregion ADDON

local function OnPlayerActivated(_, initial)
    addon:PlayerActivated(initial)
end

function IMP_STATS_InitializeTributeManager(settings, characterSettings)
    IMP_STATS_TRIBUTE_MANAGER = addon

    IMP_STATS_TRIBUTE_MANAGER.settings = settings

    local server = string.sub(GetWorldName(), 1, 2)
    IMP_STATS_TRIBUTE_MANAGER.playerData = {
        name = GetDisplayName(),
    }

    PvPMeterTOTData = PvPMeterTOTData or {}
    PvPMeterTOTData[server] = PvPMeterTOTData[server] or {}

    IMP_STATS_TRIBUTE_MANAGER.games = PvPMeterTOTData[server]
    Log('There are %d games saved', #addon.games)

    EVENT_MANAGER:RegisterForEvent(IMP_STATS_TRIBUTE_MANAGER.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    IMP_STATS_TRIBUTE_UI:Initialize(settings.namingMode, characterSettings.selectedCharacters)

    IMP_STATS_TRIBUTE_MANAGER.previewControl = IMP_STATS_TributeOpponentPreview
    do
        if settings.opponentPreview and settings.opponentPreview.anchor then
            local anchor = settings.opponentPreview.anchor
            IMP_STATS_TRIBUTE_MANAGER.previewControl:ClearAnchors()
            IMP_STATS_TRIBUTE_MANAGER.previewControl:SetAnchor(anchor[1], nil, anchor[3], anchor[4], anchor[5])
        end
    end
end

-- function FindGamesByName(name)
--     Log('Searching for %s', name)
--     local games = {}

--     local task = LibAsync:Create('TestOpponentSearch')
--     IMP_STATS_TRIBUTE_MANAGER:GetGamesWith(task, name, games):Then(function()
--         Log('%d found', #games)
--     end)
-- end

-- SLASH_COMMANDS['/imptotf'] = FindGamesByName