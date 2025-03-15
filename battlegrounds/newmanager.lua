local Log = IMP_STATS_Logger('MATCHES_MANAGER')

-- ----------------------------------------------------------------------------

local EVENT_NAMESPACE = 'IMP_STATS_MATCHES_MANAGER'

-- ----------------------------------------------------------------------------

local MATCH_STATE_NONE      = 0
-- local MATCH_STATE_RDY_CHECK = 1
-- local MATCH_STATE_WAITING   = 2
-- local MATCH_STATE_PREROUND  = 3
-- local MATCH_STATE_IDLE      = 1
local MATCH_STATE_ONGOING   = 1
local MATCH_STATE_ENDED     = 2

local STATE_NAME = {
    [MATCH_STATE_NONE] = 'none',
    -- [MATCH_STATE_IDLE] = 'idle',
    -- [MATCH_STATE_RDY_CHECK] = 'rdy check',
    -- [MATCH_STATE_WAITING] = 'waiting',
    -- [MATCH_STATE_PREROUND] = 'preround',
    [MATCH_STATE_ONGOING] = 'ongoing',
    [MATCH_STATE_ENDED] = 'ended',
}

local EVENT_MATCH_STATE_CHANGED = 1
local EVENT_ROUND_ENDED = 2
-- local EVENT_READY_CHECK = 3

local MatchManager = {}
MatchManager.__index = MatchManager

MatchManager.events = {
    EVENT_MATCH_STATE_CHANGED   = EVENT_MATCH_STATE_CHANGED,
    EVENT_ROUND_ENDED           = EVENT_ROUND_ENDED,
}

MatchManager.states = {
    MATCH_STATE_NONE    = MATCH_STATE_NONE,
    MATCH_STATE_ONGOING = MATCH_STATE_ONGOING,
    MATCH_STATE_ENDED   = MATCH_STATE_ENDED,
}

function MatchManager.New()
    local instance = setmetatable({}, MatchManager)

    instance.callbacks = {
        [EVENT_MATCH_STATE_CHANGED] = {},
        [EVENT_ROUND_ENDED] = {},
        -- [EVENT_READY_CHECK] = {},
    }

    instance.state = nil
    if ImpressiveStatsMatchBackup then
        instance.currentMatch = ImpressiveStatsMatchBackup
    end

    instance:StartListening()

    return instance
end

MatchManager.GetMatches = IMP_STATS_SHARED.Get

function MatchManager:GetDataRows()
    return self.matches
end

function MatchManager:SetState(newState)
    if newState == self.state then
        -- TODO: is it OK?
        return
    end

    local oldState = self.state
    self.state = newState

    Log('State: %s -> %s', tostring(STATE_NAME[oldState]), tostring(STATE_NAME[newState]))
    if Zgoo then Zgoo.CommandHandler('IMP_STATS_NEW_MATCHES_MANAGER') end

    self:FireCallbacks(EVENT_MATCH_STATE_CHANGED, oldState, newState)
end

local STATES_MAPPING = {
    [BATTLEGROUND_STATE_NONE]       = MATCH_STATE_NONE,
    [BATTLEGROUND_STATE_PREROUND]   = MATCH_STATE_ONGOING,
    [BATTLEGROUND_STATE_STARTING]   = MATCH_STATE_ONGOING,
    [BATTLEGROUND_STATE_RUNNING]    = MATCH_STATE_ONGOING,
    [BATTLEGROUND_STATE_POSTROUND]  = MATCH_STATE_ONGOING,
    [BATTLEGROUND_STATE_FINISHED]   = MATCH_STATE_ENDED,
}

function MatchManager:GetMatchStateFromBattlegroundState(battlegoroundState)
    local matchState = STATES_MAPPING[battlegoroundState]

    if battlegoroundState == BATTLEGROUND_STATE_POSTROUND and self:IsMatchEnded() then
        matchState = MATCH_STATE_ENDED
    end

    return matchState
end

function MatchManager:ResolveCurrentState()
    local currentState

    if not IsActiveWorldBattleground() then
        currentState = MATCH_STATE_NONE
    else
        local currentBattlegrounState = GetCurrentBattlegroundState()
        currentState = self:GetMatchStateFromBattlegroundState(currentBattlegrounState)
    end

    self:SetState(currentState)
end

function MatchManager:IsMatchEnded()
    local battlegroundId = GetCurrentBattlegroundId()
    if not battlegroundId then return end

    -- TODO: compare with ZO function
    local matchEnded = GetCurrentBattlegroundRoundIndex() == GetBattlegroundNumRounds(battlegroundId) or HasTeamWonBattlegroundEarly()

    return matchEnded
end

function MatchManager:RegisterCallback(name, event, callback)
    self.callbacks[event][name] = callback
end

function MatchManager:UnregisterCallback(name, event)
    self.callbacks[event][name] = nil
end

function MatchManager:FireCallbacks(event, ...)
    for name, callback in pairs(self.callbacks[event]) do
        callback(...)
        -- TODO Log('%s fired', name)
    end
end

-- ----------------------------------------------------------------------------

function MatchManager:OnActivityFinderStatusUpdate(state)
    -- TODO: clear state if ready check failed
    if state ~= ACTIVITY_FINDER_STATUS_READY_CHECK then
        return
    end

    local isGrouped = ZO_ACTIVITY_FINDER_ROOT_MANAGER.playerIsGrouped

    Log(isGrouped and 'Joining as group' or 'Joining as solo')
    self.grouped = isGrouped
end

function MatchManager:OnPlayerActivated(initial)
    self:ResolveCurrentState()
    Log('Player activated, state: %s', STATE_NAME[self.state])
end

function MatchManager:MarkPlayedFromStart()
    self.playedFromStart = true
    if self.currentMatch then
        self.currentMatch.playedFromStart = true
    end
end

function MatchManager:OnBattlegroundStateChanged(oldState, newState)
    if oldState == BATTLEGROUND_STATE_NONE and newState == BATTLEGROUND_STATE_PREROUND then
        self:MarkPlayedFromStart()
        Log('Marked as played from start: loaded at very beginning')
    end

    if newState == BATTLEGROUND_STATE_STARTING and GetCurrentBattlegroundRoundIndex() == 1 then
        self:MarkPlayedFromStart()
        Log('Marked as played from start: start of first round')
    end

    if newState == BATTLEGROUND_STATE_POSTROUND then
        self:FireCallbacks(EVENT_ROUND_ENDED)
    end

    local matchState = self:GetMatchStateFromBattlegroundState(newState)
    self:SetState(matchState)

    Log('BG state changed, state: %s', STATE_NAME[self.state])
end

function MatchManager:StartListening()
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, function(_, state) self:OnActivityFinderStatusUpdate(state) end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function(_, initial) self:OnPlayerActivated(initial) end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_BATTLEGROUND_STATE_CHANGED, function(_, old, new) self:OnBattlegroundStateChanged(old, new) end)
end

-- ----------------------------------------------------------------------------

local function GetNewMatchFromCurrentMatch()
    local bgId = GetCurrentBattlegroundId()
    local unitZoneIndex = GetUnitZoneIndex('player')

    Log('Creating new match, battlegorundId: %d', bgId)

    local currentMatch = {
        type = GetCurrentBattlegroundGameType(),
        battlegroundId = bgId,
        playerRace = GetUnitRaceId('player'),
        playerClass = GetUnitClassId('player'),
        playerCharacterId = GetCurrentCharacterId(),
        zoneIndex = unitZoneIndex,
        zoneId = GetZoneId(unitZoneIndex),
        zoneName = GetUnitZone('player'),
        entryTimestamp = GetTimeStamp(),
        rounds = {},
        result = BATTLEGROUND_RESULT_INVALID,
        lfgActivityId = GetCurrentLFGActivityId(),
        teamSize = GetBattlegroundTeamSize(GetCurrentBattlegroundId()),
        -- grouped = IMP_STATS_NEW_MATCHES_MANAGER:IsGrouped(),
    }

    -- TODO: do i really nee to add rounds like this? 
    -- Would it be better to add on demand?
    for i = 1, GetBattlegroundNumRounds(bgId) do
        currentMatch.rounds[i] = {
            startTimestamp = nil,
            players = {},
            scores = {},
            result = BATTLEGROUND_RESULT_INVALID,  -- TODO: check
            endTimestamp = nil,
        }
    end

    return currentMatch
end

local function GetPlayersFromCurrentMatchRound(round)
    local players = {}
    local localPlayerIndex

    for entryIndex = 1, GetNumScoreboardEntries(round) do
        local characterName, displayName, battlegroundTeam, isLocalPlayer = GetScoreboardEntryInfo(entryIndex, round)
        if isLocalPlayer then localPlayerIndex = entryIndex end

        local lives = GetScoreboardEntryNumLivesRemaining(entryIndex, round)
        local medalScore = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_SCORE, round)
        local kills = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_KILL, round)
        local deaths = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_DEATH, round)
        local assists = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_ASSISTS, round)

        local damageDone = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_DAMAGE_DONE, round)
        local damageTaken = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_DAMAGE_TAKEN, round)
		local healingDone = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_HEALING_DONE, round)
        local classId = GetScoreboardEntryClassId(entryIndex, round)

        players[entryIndex] = {
            characterName = characterName,
            displayName = displayName,
            battlegroundTeam = battlegroundTeam,
            lives = lives,
            medalScore = medalScore,
            kills = kills,
            deaths = deaths,
            assists = assists,
            damageDone = damageDone,
            damageTaken = damageTaken,
            healingDone = healingDone,
            classId = classId,
            characterId = isLocalPlayer and GetCurrentCharacterId() or nil,
        }
    end

    if localPlayerIndex then
        players[1], players[localPlayerIndex] = players[localPlayerIndex], players[1]
    end

    return players
end

local function GetScoresFromCurrentMatchRound(round)
    local scores = {}

    for i = BATTLEGROUND_TEAM_ITERATION_BEGIN, BATTLEGROUND_TEAM_ITERATION_END do
        scores[i] = GetCurrentBattlegroundScore(round, i)
    end

    return scores
end

local function GetResultFromCurrentMatchRound(round)
    --[[
    * BATTLEGROUND_RESULT_INVALID
    * BATTLEGROUND_RESULT_LOSS
    * BATTLEGROUND_RESULT_TIE
    * BATTLEGROUND_RESULT_WIN
    ]]

    return GetCurrentBattlegroundRoundResult(round)
end

local function IsCurrentMatch(match)
    if not match then return end

    local started = match.entryTimestamp or 0

    Log('Type, previous: %d, current: %d, eq: %s', match.type, GetCurrentBattlegroundGameType(), tostring(match.type == GetCurrentBattlegroundGameType()))
    Log('Id, previous: %d, current: %d, eq: %s', match.battlegroundId, GetCurrentBattlegroundId(), tostring(match.battlegroundId == GetCurrentBattlegroundId()))
    Log('Started %d ago', GetTimeStamp() - started)

    return
    -- TODO: some type of hash for fast comparison
    match.type == GetCurrentBattlegroundGameType() and
    match.battlegroundId == GetCurrentBattlegroundId() and
    (GetTimeStamp() - started) <= 60 * 20
end

local function UpdateMatchRound(match, round)
    local currentRound = match.rounds[round]

    -- self.rounds[round].endTimestamp = GetTimeStamp()
    if currentRound.result ~= nil and currentRound.result ~= BATTLEGROUND_RESULT_INVALID then
        Log('Round %d of current match was already saved, skipping', round)
        return
    end

    currentRound.players = GetPlayersFromCurrentMatchRound(round)
    currentRound.scores = GetScoresFromCurrentMatchRound(round)
    currentRound.result = GetResultFromCurrentMatchRound(round)

    Log('Round %d of current match updated', round)
end

local function FinalizeMatch(match)
    match.result = GetBattlegroundResultForTeam(GetUnitBattlegroundTeam('player'))
    match.locked = true -- TODO: utilize?
end

local function CheckMatch(match)
    local battlegroundState = GetCurrentBattlegroundState()
    if battlegroundState and battlegroundState == BATTLEGROUND_STATE_NONE then return end

    local currentRoundIndex = GetCurrentBattlegroundRoundIndex()

    for i = 1, GetBattlegroundNumRounds(match.battlegroundId) do
        if battlegroundState ~= BATTLEGROUND_STATE_FINISHED and i == currentRoundIndex then return end
        UpdateMatchRound(match, i)
    end

    if battlegroundState == BATTLEGROUND_STATE_FINISHED then
        FinalizeMatch(match)
    end
end

-- ----------------------------------------------------------------------------

function MatchManager:CreateMatch()
    local currentMatchAlreadyCreated = IsCurrentMatch(self.currentMatch)
    if not currentMatchAlreadyCreated then
        self.currentMatch = GetNewMatchFromCurrentMatch()

        if self.grouped ~= nil then
            Log('There is grouped flag: %s', tostring(self.grouped))
            self.currentMatch.grouped = self.grouped
        end
        if self.playedFromStart then self.currentMatch.playedFromStart = self.playedFromStart end

        ImpressiveStatsMatchBackup = self.currentMatch
    end
end

function MatchManager:UpdateCurrentMatchRound(round)
    UpdateMatchRound(self.currentMatch, round)
end

function MatchManager:FinalizeCurrentMatch()
    FinalizeMatch(self.currentMatch)
end

function MatchManager:CheckCurrentMatch()
    CheckMatch(self.currentMatch)
end

function MatchManager:SaveMatch()
    self:CheckCurrentMatch()

    local lastSavedMatchLooksSimilarToWhatIsBeingSaved = IsCurrentMatch(self.matches[#self.matches])
    -- dont save if last saved looks identical to avoid duplication
    if not lastSavedMatchLooksSimilarToWhatIsBeingSaved then
        self.matches[#self.matches+1] = self.currentMatch
        Log('Match saved as #%d', #self.matches)
    end

    self.currentMatch = nil
    ImpressiveStatsMatchBackup = nil
end

function MatchManager:Clean()
    if self.currentMatch then
        self:SaveMatch()
    end

    self.playedFromStart = nil
    self.grouped = nil
end

function MatchManager:OnRoundEnded()
    local round = GetCurrentBattlegroundRoundIndex()
    self:UpdateCurrentMatchRound(round)
end

function MatchManager:OnMatchStateChanged(oldState, newState)
    if newState == MATCH_STATE_ONGOING then
        self:CreateMatch()
    elseif newState == MATCH_STATE_ENDED then
        self:FinalizeCurrentMatch()
        self:SaveMatch()
    elseif newState == MATCH_STATE_NONE then
        self:Clean()
    end
end

-- ----------------------------------------------------------------------------

local function UpdateSavedVariablesVersion()
    Log('Data version: %d', ImpressiveStatsMatchesData.version)

    if ImpressiveStatsMatchesData.version == nil then
        ImpressiveStatsMatchesData.version = 0
        Log('Bumped to %d', ImpressiveStatsMatchesData.version)
    end

    if ImpressiveStatsMatchesData.version < 1010019 then  -- before 0.1.0b19
        for key, data in pairs(ImpressiveStatsMatchesData) do
            if key ~= 'version' then
                for _, matchData in ipairs(data) do
                    if matchData.api == nil then matchData.api = 101044 end
                    if matchData.playedFromStart == nil then matchData.playedFromStart = true end
                end
            end
        end

        ImpressiveStatsMatchesData.version = 1010019
        Log('Bumped to %d', ImpressiveStatsMatchesData.version)
    end

    if ImpressiveStatsMatchesData.version < 1102000 then
        for key, data in pairs(ImpressiveStatsMatchesData) do
            if key ~= 'version' then
                for _, matchData in ipairs(data) do
                    if matchData.playerCharacterId == nil then
                        if matchData.rounds[1] and matchData.rounds[1].players[1] then
                            local player = matchData.rounds[1].players[1]
                            matchData.playerCharacterId = player.characterId
                        end
                    end
                end
            end
        end

        ImpressiveStatsMatchesData.version = 1102000
        Log('Bumped to %d', ImpressiveStatsMatchesData.version)
    end
end

-- ----------------------------------------------------------------------------

function IMP_STATS_InitializeNewMatchManager(settings, characterSettings)
    local server = string.sub(GetWorldName(), 1, 2)
    ImpressiveStatsMatchesData = ImpressiveStatsMatchesData or {}
    ImpressiveStatsMatchesData[server] = ImpressiveStatsMatchesData[server] or {}
    UpdateSavedVariablesVersion()

    IMP_STATS_MATCHES_MANAGER = MatchManager.New()
    if Zgoo then Zgoo.CommandHandler('IMP_STATS_NEW_MATCHES_MANAGER') end

    IMP_STATS_MATCHES_MANAGER.matches = ImpressiveStatsMatchesData[server]
    Log('There are %d matches saved', #IMP_STATS_MATCHES_MANAGER.matches)

    IMP_STATS_MATCHES_MANAGER.sv = settings

    IMP_STATS_MATCHES_MANAGER:RegisterCallback(EVENT_NAMESPACE, EVENT_MATCH_STATE_CHANGED, function(...) IMP_STATS_MATCHES_MANAGER:OnMatchStateChanged(...) end)
    IMP_STATS_MATCHES_MANAGER:RegisterCallback(EVENT_NAMESPACE, EVENT_ROUND_ENDED, function() IMP_STATS_MATCHES_MANAGER:OnRoundEnded() end)

    IMP_STATS_MATCHES_UI:Initialize(settings.namingMode, characterSettings)
end