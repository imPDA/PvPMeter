local Log = IMP_STATS_Logger('MATCHES_MANAGER')

-- ----------------------------------------------------------------------------

local EVENT_NAMESPACE = 'IMP_STATS_MATCHES_MANAGER'

-- ----------------------------------------------------------------------------

local MATCH_STATE_NONE      = 0
local MATCH_STATE_ONGOING   = 1
local MATCH_STATE_ENDED     = 2

local STATE_NAME = {
    [MATCH_STATE_NONE] = 'none',
    [MATCH_STATE_ONGOING] = 'ongoing',
    [MATCH_STATE_ENDED] = 'ended',
}

local EVENT_MATCH_STATE_CHANGED = 1
local EVENT_ROUND_ENDED = 2

-- ----------------------------------------------------------------------------

local TEAM_TYPE_4_SOLO = 1
local TEAM_TYPE_8_SOLO = 2
local TEAM_TYPE_4_GROUP = 3
local TEAM_TYPE_8_GROUP = 4

local function getTeamType(lfgActivityId, teamSize)
    local groupType = GetActivityGroupType(lfgActivityId)

    local teamType

    if teamSize == 8 then
        if groupType == LFG_GROUP_TYPE_NONE then
            teamType = TEAM_TYPE_8_SOLO
        -- elseif groupType == LFG_GROUP_TYPE_REGULAR then
        --     teamType = TEAM_TYPE_8_GROUP
        elseif groupType == LFG_GROUP_TYPE_BIG_TEAM_BATTLE then
            teamType = TEAM_TYPE_8_GROUP
        else
            Log('Problem with GetMatchGroupType, teamSize: %d, groupType: %d', teamSize, groupType)
        end
    elseif teamSize == 4 then
        if groupType == LFG_GROUP_TYPE_NONE then
            teamType = TEAM_TYPE_4_SOLO
        elseif groupType == LFG_GROUP_TYPE_REGULAR then
            teamType = TEAM_TYPE_4_GROUP
        else
            Log('Problem with GetMatchGroupType, teamSize: %d, groupType: %d', teamSize, groupType)
        end
    else
        Log('Problem with GetMatchGroupType, teamSize: %d, groupType: %d', teamSize, groupType)
    end

    return teamType
end

local function GetNewMatchFromCurrentMatch()
    local bgId = GetCurrentBattlegroundId()
    local unitZoneIndex = GetUnitZoneIndex('player')

    Log('Creating new match, battlegorundId: %d', bgId)

    local lfgActivityId = GetCurrentLFGActivityId()
    local teamSize = GetBattlegroundTeamSize(GetCurrentBattlegroundId())

    local currentMatch = {
        api = GetAPIVersion(),
        battlegroundId = bgId,
        entryTimestamp = GetTimeStamp(),
        lfgActivityId = lfgActivityId,
        -- grouped = IMP_STATS_NEW_MATCHES_MANAGER:IsGrouped(),
        playerCharacterId = GetCurrentCharacterId(),
        playerClass = GetUnitClassId('player'),
        playerRace = GetUnitRaceId('player'),
        result = BATTLEGROUND_RESULT_INVALID,
        rounds = {},
        teamSize = teamSize,
        teamType = getTeamType(lfgActivityId, teamSize),
        type = GetCurrentBattlegroundGameType(),
        -- zoneIndex = unitZoneIndex,
        -- zoneName = GetUnitZone('player'),
        zoneId = GetZoneId(unitZoneIndex),
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
            -- characterId = isLocalPlayer and GetCurrentCharacterId() or nil,
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
    return GetCurrentBattlegroundRoundResult(round)
end

local function samePlayersOfTheFirstRound(match1, match2)
    local players1 = match1.rounds[1].players
    local players2 = match2.rounds[1].players

    for player1Name, player1Stats in pairs(players1) do
        if not players2[player1Name] then return end
        if player1Stats.damageDone ~= players2[player1Name].damageDone then return end
    end

    return true
end

local function isSameMatches(match1, match2)
    return
    -- TODO: some type of hash for fast comparison
    match1.entryTimestamp == match2.entryTimestamp and
    match1.battlegroundId == match2.battlegroundId and
    match1.type == match2.type and
    samePlayersOfTheFirstRound(match1, match2)
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
    match.playedFromStart = match.playedFromStart or false
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

local function WorthSaving(match)
    -- partially copied from good filter from UI

    if not match.rounds or #match.rounds < 1 then
        return
    end

    if not match.rounds[1].players or #match.rounds[1].players < 1 then
        return
    end

    return true
end

-- ----------------------------------------------------------------------------

local MatchManager = IMP_STATS_SHARED.class()

MatchManager.events = {
    EVENT_MATCH_STATE_CHANGED   = EVENT_MATCH_STATE_CHANGED,
    EVENT_ROUND_ENDED           = EVENT_ROUND_ENDED,
}

MatchManager.states = {
    MATCH_STATE_NONE    = MATCH_STATE_NONE,
    MATCH_STATE_ONGOING = MATCH_STATE_ONGOING,
    MATCH_STATE_ENDED   = MATCH_STATE_ENDED,
}

function MatchManager:__init__(savedMatches)
    self.savedMatches = savedMatches
    self.matches = {}

    Log('There are %d matches saved', #savedMatches)

    self.callbacks = {
        [EVENT_MATCH_STATE_CHANGED] = {},
        [EVENT_ROUND_ENDED] = {},
    }

    self.state = nil
    if ImpressiveStatsMatchBackup then
        self.currentMatch = ImpressiveStatsMatchBackup
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, function(_, state) self:OnActivityFinderStatusUpdate(state) end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function(_, initial) self:OnPlayerActivated(initial) end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_BATTLEGROUND_STATE_CHANGED, function(_, old, new) self:OnBattlegroundStateChanged(old, new) end)

    function OnMatchStateChanged(oldState, newState)
        if newState == MATCH_STATE_ONGOING then
            self:CreateMatch()
        elseif newState == MATCH_STATE_ENDED then
            self:FinalizeCurrentMatch()
            self:SaveMatch()
        elseif newState == MATCH_STATE_NONE then
            self:Clean()
        end
    end

    function OnRoundEnded()
        local round = GetCurrentBattlegroundRoundIndex()
        self:UpdateCurrentMatchRound(round)
    end

    self:RegisterCallback(EVENT_NAMESPACE, EVENT_MATCH_STATE_CHANGED, OnMatchStateChanged)
    self:RegisterCallback(EVENT_NAMESPACE, EVENT_ROUND_ENDED, OnRoundEnded)
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

function MatchManager:SetState(newState)
    if newState == self.state then
        -- TODO: is it OK?
        return
    end

    local oldState = self.state
    self.state = newState

    Log('State: %s -> %s', tostring(STATE_NAME[oldState]), tostring(STATE_NAME[newState]))

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

function MatchManager:MarkPlayedFromStart()
    self.playedFromStart = true
    if self.currentMatch then
        self.currentMatch.playedFromStart = true
    end
end

-- ----------------------------------------------------------------------------

MatchManager.GetMatches = IMP_STATS_SHARED.Get

--[[
function MatchManager:GetLastNMatches(task, filters, tbl, n)
    local function PassFilters(data)
        for _, filter in ipairs(filters) do
            if not filter(data) then return end
        end

        return true
    end

    -- local function Filter(index, data)
    --     if PassFilters(data) then table.insert(tbl, index) end
    -- end

    local stop = #self.savedMatches
    local start = stop - n + 1

    local function loadAndCheck(index)
        if not self.matches[index] then
            local packedMatchData = self.savedMatches[index]
            if type(packedMatchData) == 'string' then
                self.matches[index] = self.UnpackMatch(packedMatchData)
            else
                self.matches[index] = {}
                ZO_DeepTableCopy(packedMatchData, self.matches[index])
            end
        end
        local matchData = self.matches[index]
        if PassFilters(matchData) then table.insert(tbl, index) end
    end

    return task:For(start, stop):Do(loadAndCheck)
end
--]]

function MatchManager:GetDataRows(task)
    --[[
    for i = #self.matches+1, #self.savedMatches do
        local matchData = self.savedMatches[i]
        if type(matchData) == 'string' then
            self.matches[i] = self.UnpackMatch(matchData)
        else
            self.matches[i] = {}
            ZO_DeepTableCopy(matchData, self.matches[i])
        end
    end
    --]]

    ---[[
    local matchesToLoad = #self.savedMatches - #self.matches
    Log('GetDataRows requested, going to load %s matches (%s -> %s)', matchesToLoad, #self.matches, #self.savedMatches)

    local function loadMatch(index)
        local matchData = self.savedMatches[index]
        if type(matchData) == 'string' then
            self.matches[index] = self.UnpackMatch(matchData)
        else
            self.matches[index] = {}
            ZO_DeepTableCopy(matchData, self.matches[index])
        end
    end

    local function loadMatches()
        task:For(#self.matches+1, #self.savedMatches):Do(loadMatch)
    end

    local start
    task
    :Call(function() start = GetGameTimeMilliseconds() end)
    :Then(loadMatches)
    :Then(function()
        local diff = GetGameTimeMilliseconds() - start
        Log('Loaded %d matches, %d ms, avg: %.2f ms', matchesToLoad, diff, diff / matchesToLoad)
    end)
    --]]

    return self.matches
end

-- ----------------------------------------------------------------------------

local function isCurrentMatch(match)
    if not match then return end

    local started = match.entryTimestamp or 0

    Log('Type, previous: %d, current: %d, eq: %s', match.type, GetCurrentBattlegroundGameType(), tostring(match.type == GetCurrentBattlegroundGameType()))
    Log('Id, previous: %d, current: %d, eq: %s', match.battlegroundId, GetCurrentBattlegroundId(), tostring(match.battlegroundId == GetCurrentBattlegroundId()))
    Log('Started %d ago', GetTimeStamp() - started)

    return
    match.type == GetCurrentBattlegroundGameType() and
    match.battlegroundId == GetCurrentBattlegroundId() and
    (GetTimeStamp() - started) <= 60 * 20
end

function MatchManager:CreateMatch()
    local currentMatchAlreadyCreated = isCurrentMatch(self.currentMatch)

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

    if self.currentMatch.wasPlayed then
        self.currentMatch.wasPlayed = nil  -- discard as no longer needed
        --[[
        local lastSavedMatchLooksSimilarToWhatIsBeingSaved = isSameMatches(self.matches[#self.matches], self.currentMatch)
        -- dont save if last saved looks identical to avoid duplication
        if not lastSavedMatchLooksSimilarToWhatIsBeingSaved then
            local index = #self.matches + 1
            self.matches[index] = self.currentMatch

            local success, result = pcall(self.PackMatch, self.currentMatch)
            if success then
                self.savedMatches[index] = result
            else
                self.savedMatches[index] = {}
                ZO_DeepTableCopy(self.currentMatch, self.savedMatches[index])
                Log('Error saving match: %s', result)
            end
            Log('Match saved as #%d', index)
        end
        --]]
        local index = #self.savedMatches

        local success, result = pcall(self.PackMatch, self.currentMatch)
        if success then
            if type(self.savedMatches[index]) ~= 'string' or self.savedMatches[index] ~= result then
                self.savedMatches[index+1] = result
                Log('Match saved as #%d (and packed successfully)', index)
            else
                Log('Match was not saved because it is similar to previous, most likely duplication')
            end
        else
            if type(self.savedMatches[index]) ~= 'table' or not isSameMatches(self.savedMatches[index], self.currentMatch) then
                self.savedMatches[index+1] = {}
                ZO_DeepTableCopy(self.currentMatch, self.savedMatches[index+1])
                Log('Match saved as #%d (but packing failed: %s)', index, result)
            else
                Log('Match was not saved because it is similar to previous, most likely duplication')
            end
        end
    else
        Log('Match was not played, skipping saving')
    end

    -- TODO: clear via ZO_ClearTable etc.?
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

local BATTLEGROUND_STATE_TO_NAME = {
    [BATTLEGROUND_STATE_NONE]       = 'none',       -- 0
    [BATTLEGROUND_STATE_PREROUND]   = 'preround',   -- 1
    [BATTLEGROUND_STATE_STARTING]   = 'starting',   -- 2
    [BATTLEGROUND_STATE_RUNNING]    = 'running',    -- 3
    [BATTLEGROUND_STATE_POSTROUND]  = 'postround',  -- 4
    [BATTLEGROUND_STATE_FINISHED]   = 'finished',   -- 5
}

function MatchManager:OnBattlegroundStateChanged(oldState, newState)
    Log('Battleground state changed: %s -> %s', BATTLEGROUND_STATE_TO_NAME[oldState], BATTLEGROUND_STATE_TO_NAME[newState])

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

    if newState > BATTLEGROUND_STATE_PREROUND or (newState == BATTLEGROUND_STATE_PREROUND and GetCurrentBattlegroundRoundIndex() > 1) then
        if self.currentMatch then
            self.currentMatch.wasPlayed = true
            Log('Marked as was played (=need to save this BG), roundIndex: %d, state: %s', GetCurrentBattlegroundRoundIndex(), BATTLEGROUND_STATE_TO_NAME[newState])
        else
            Log('Should be marked as was played, but there is no match, roundIndex: %d, state: %s', GetCurrentBattlegroundRoundIndex(), BATTLEGROUND_STATE_TO_NAME[newState])
        end
    end
end

-- ----------------------------------------------------------------------------

local LDP = LibDataPacker

local CLASSES_LOOKUP_TABLE = {
    1, 2, 3, 4, 5, 6, 117
}

local APIS_LOOKUP_TABLE = {
    101044, 101045
}

local RACES_LOOKUP_TABLE = {
    1,  -- Breton
    2,  -- Redguard
    3,  -- Orc
    4,  -- Dark Elf
    5,  -- Nord
    6,  -- Argonian
    7,  -- High Elf
    8,  -- Wood Elf
    9,  -- Khajiit
    10, -- Imperial
    -- 29,  -- Xivilai
}

local BATTLEGROUND_RESULT_LOOKUP_TABLE = {
    BATTLEGROUND_RESULT_INVALID,
    BATTLEGROUND_RESULT_LOSS,
    BATTLEGROUND_RESULT_TIE,
    BATTLEGROUND_RESULT_WIN,
}

local BATTLEGROUND_ROUND_RESULT_LOOKUP_TABLE = {
    BATTLEGROUND_ROUND_RESULT_ENEMY_LEFT,
    BATTLEGROUND_ROUND_RESULT_HIGHEST_SCORE_WIN,
    BATTLEGROUND_ROUND_RESULT_INVALID,
    BATTLEGROUND_ROUND_RESULT_LAST_TEAM_STANDING,
    BATTLEGROUND_ROUND_RESULT_SCORE_LIMIT_REACHED,
    BATTLEGROUND_ROUND_RESULT_STALEMATE,
    BATTLEGROUND_ROUND_RESULT_TIEBREAKER_LIVES_REMAINING,
    BATTLEGROUND_ROUND_RESULT_TIEBREAKER_MEDAL_SCORE,
    BATTLEGROUND_ROUND_RESULT_TIEBREAKER_PLAYERS_ALIVE,
}

local TEAM_SIZE_LOOKUP_TABLE = {
    4, 8,
}

local TEAM_TYPE_LOOKUP_TABLE = {
    1, 2, 3, 4,
}

local MATCH_TYPE_LOOKUP_TABLE = {
    BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG,
    BATTLEGROUND_GAME_TYPE_CRAZY_KING,
    BATTLEGROUND_GAME_TYPE_DEATHMATCH,
    BATTLEGROUND_GAME_TYPE_DOMINATION,
    BATTLEGROUND_GAME_TYPE_KING_OF_THE_HILL,
    BATTLEGROUND_GAME_TYPE_MURDERBALL,
}

local Field = LDP.Field
local INVERSED = true

--[[
local DamageNumber = setmetatable({}, { __index = Field.Number })
DamageNumber.__index = DamageNumber

function DamageNumber.New(name)
    local o = Field.Number(name, 0)

    return o
end

local function getLengthBits(number)
    if number <= 524287     then return {0, 0}, 19 end
    if number <= 1048575    then return {1, 0}, 20 end
    if number <= 4194303    then return {0, 1}, 22 end
    if number <= 67108863   then return {1, 1}, 26 end

    error(('Cant handle numbers bigger than 67108863, got %d'):format(number))
end

function DamageNumber:Serialize(data, binaryBuffer)
    local lengthBits, bitLength = getLengthBits(data)
    binaryBuffer:WriteBits(lengthBits)
    binaryBuffer:Write(data, bitLength)
end

function DamageNumber:Unserialize(binaryBuffer)
    local length = 18 + 2^(binaryBuffer:Read(2))
    return binaryBuffer:Read(length)
end
--]]

local PlayerSchema = Field.Table('player', {
    Field.String('characterName',   100),
    Field.String('displayName',     100),

    Field.Number('battlegroundTeam', 2),  -- max 3

    Field.Number('lives',       2),  -- max 3
    Field.Number('medalScore',  17),  -- ~131K
    Field.Number('kills',       8),  -- 255
    Field.Number('deaths',      8),  -- 255
    Field.Number('assists',     8),  -- 255
    ---[[
    Field.Number('damageDone',  19, -2),  -- ~52.4M @ 19&-2
    Field.Number('damageTaken', 19, -2),  -- ~52.4M @ 19&-2
    Field.Number('healingDone', 19, -2),  -- ~52.4M @ 19&-2
    --]]
    --[[
    Field.Number('damageDone',  25),  -- ~33.5M @ 25
    Field.Number('damageTaken', 25),  -- ~33.5M @ 25
    Field.Number('healingDone', 25),  -- ~33.5M @ 25
    --]]
    --[[
    DamageNumber.New('damageDone'),
    DamageNumber.New('damageTaken'),
    DamageNumber.New('healingDone'),
    --]]
    Field.Enum('classId', CLASSES_LOOKUP_TABLE, INVERSED)
})

local Players = Field.VLArray('players', 16, PlayerSchema)

function Players:Unserialize(binaryBuffer)
    local length = self.length:Unserialize(binaryBuffer)

    if length == 0 then return {} end

    local firstPlayer = self.subType:Unserialize(binaryBuffer)

    for _ = 2, length do
        self.subType:Skip(binaryBuffer)
    end

    return { firstPlayer }
end

local MatchSchema = Field.Table(nil, {
    --[[ 1]] Field.Enum('api', APIS_LOOKUP_TABLE, INVERSED),
    --[[ 2]] Field.Number('battlegroundId', 10),  -- U45 max id is 294
    --[[ 3]] Field.Number('entryTimestamp', 32),
    --[[ 4]] Field.Number('lfgActivityId', 12), -- U45 max id is 1041 (Vengeance)
    --[[ 5]] Field.Optional(Field.Bool('locked')),
    --[[ 6]] Field.Optional(Field.Bool('playedFromStart')),
    --[[ 7]] Field.Optional(Field.Bool('grouped')),
    -- Field.Number('playerCharacterId', 53),
    --[[ 8]] Field.String('playerCharacterId', 16),
    --[[ 9]] Field.Enum('playerClass', CLASSES_LOOKUP_TABLE, INVERSED),
    --[[10]] Field.Enum('playerRace', RACES_LOOKUP_TABLE, INVERSED),
    --[[11]] Field.Enum('result', BATTLEGROUND_RESULT_LOOKUP_TABLE, INVERSED),
    --[[12]] Field.VLArray('rounds', 3, Field.Table(nil, {
        Players,
        Field.Enum('result', BATTLEGROUND_ROUND_RESULT_LOOKUP_TABLE, INVERSED),
        Field.VLArray('scores', 3, Field.Number(nil, 10)),
    })),
    --[[13]] Field.Enum('teamSize', TEAM_SIZE_LOOKUP_TABLE, INVERSED),
    --[[14]] Field.Enum('teamType', TEAM_TYPE_LOOKUP_TABLE, INVERSED),
    --[[15]] Field.Enum('type', MATCH_TYPE_LOOKUP_TABLE, INVERSED),
    --[[16]] Field.Number('zoneId', 11),  -- TODO: check

    --[[17]] Field.Optional(Field.String('superstar', 230)),
})

-- IMP_STATS_MATCH_SCHEMA = MatchSchema

-- local ReadMatchSchema = {}
-- ZO_DeepTableCopy(MatchSchema, ReadMatchSchema)
-- ReadMatchSchema.fields[12].subType.fields[1] = ReadPlayers

local ENCODE_BASE = LDP.Base.Base64RCF4648

local function PackMatch(matchData)
    return LDP.Pack(matchData, MatchSchema, ENCODE_BASE)
end
MatchManager.PackMatch = PackMatch

local function UnpackMatch(packedMatch)
    return LDP.Unpack(packedMatch, MatchSchema, ENCODE_BASE)
end
MatchManager.UnpackMatch = UnpackMatch

-- ----------------------------------------------------------------------------

function MatchManager:OnPlayerActivated(initial)
    self:ResolveCurrentState()
    Log('Player activated, state: %s', STATE_NAME[self.state])
end

-- ----------------------------------------------------------------------------

local function UpdateSavedVariablesVersion(svTable, svProblemsTable)
    Log('WTF BRUHHH')
    Log('Data version: %d', svTable.version)
    Log('WTF BRUHHH 2')

    if svTable.version == nil then
        svTable.version = 0
        Log('Bumped to %d', svTable.version)
    end

    if svTable.version < 1010019 then  -- before 0.1.0b19
        for key, data in pairs(svTable) do
            if key ~= 'version' then
                for _, matchData in ipairs(data) do
                    if matchData.api == nil then matchData.api = 101044 end
                    if matchData.playedFromStart == nil then matchData.playedFromStart = true end
                end
            end
        end

        svTable.version = 1010019
        Log('Bumped to %d', svTable.version)
    end

    if svTable.version < 1102000 then
        for key, data in pairs(svTable) do
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

        svTable.version = 1102000
        Log('Bumped to %d', svTable.version)
    end

    local problems
    local function handleProblem(matchId, problem)
        if not problems then error('Problems tables was not created') end
        problems[matchId] = problems[matchId] or {}
        table.insert(problems[matchId], problem)
    end

    do
        local function deleteCharacterId(matchData)
            local playerCharacterId = matchData.playerCharacterId

            if not playerCharacterId or playerCharacterId == '' then
                for _, roundData in ipairs(matchData.rounds) do
                    if roundData.players and roundData.players[1] then
                        local player = roundData.players[1]
                        if player.characterId then
                            matchData.playerCharacterId = player.characterId
                            player.characterId = nil
                        end
                    else
                        return
                    end
                end
            else
                for _, roundData in ipairs(matchData.rounds) do
                    if roundData.players and roundData.players[1] then
                        local player = roundData.players[1]
                        if player.characterId and player.characterId == playerCharacterId then
                            player.characterId = nil
                        else
                            return
                        end
                    else
                        return
                    end
                end
            end

            return true
        end

        local function afterU45(timestamp)
            return 1741597200 <= timestamp  -- Mon Mar 10 2025 09:00:00 GMT+0000
        end

        local function setApiVersion(matchData)
            if not matchData.entryTimestamp then return end

            if matchData.api == 101044 and not afterU45(matchData.entryTimestamp) then return true end
            if matchData.api == 101045 and afterU45(matchData.entryTimestamp) then return true end

            matchData.api = afterU45(matchData.entryTimestamp) and 101045 or 101044

            return true
        end

        if svTable.version < 1108000 then
            svProblemsTable[1108000] = {}
            problems = svProblemsTable[1108000]

            for key, data in pairs(svTable) do
                if key ~= 'version' and type(key) == 'string' then
                    Log('Updating %s matches', key)
                    for matchId, matchData in ipairs(data) do
                        if not deleteCharacterId(matchData) then handleProblem(matchId, 'deleteCharacterIdFailed') end
                        if not setApiVersion(matchData) then handleProblem(matchId, 'api version not added') end
                    end
                end
            end

            svTable.version = 1108000
            Log('Bumped to %d', svTable.version)
        end
    end

    do
        local function deleteZoneIndexAndName(matchData)
            matchData.zoneName = nil
            matchData.zoneIndex = nil

            return true
        end

        if svTable.version < 1108001 then
            svProblemsTable[1108001] = {}
            problems = svProblemsTable[1108001]

            for key, data in pairs(svTable) do
                if key ~= 'version' and type(key) == 'string' then
                    Log('Updating %s matches', key)
                    for matchId, matchData in ipairs(data) do
                        if not deleteZoneIndexAndName(matchData) then handleProblem(matchId, 'deleteZoneIndexAndNameFailed') end
                    end
                end
            end

            svTable.version = 1108001
            Log('Bumped to %d', svTable.version)
        end
    end

    do
        local function deleteMatchesWithEmptyFirstRound(matchData)
            if matchData.rounds and matchData.rounds[1] and matchData.rounds[1].players and #matchData.rounds[1].players > 0 then return true end
        end

        if svTable.version < 1108002 then
            svProblemsTable[1108002] = {}
            problems = svProblemsTable[1108002]

            for key, data in pairs(svTable) do
                if key ~= 'version' and type(key) == 'string' then
                    Log('Updating %s matches', key)
                    local matchesToDelete = {}

                    for matchId, matchData in ipairs(data) do
                        if not deleteMatchesWithEmptyFirstRound(matchData) then
                            handleProblem(matchId, 'deletedBecauseFirstRoundEmpty')
                            table.insert(matchesToDelete, matchId)
                        end
                    end

                    Log('Deleting %d matches', #matchesToDelete)

                    table.sort(matchesToDelete, function(a, b) return a > b end)

                    for _, matchId in ipairs(matchesToDelete) do
                        table.remove(data, matchId)
                    end
                end
            end

            svTable.version = 1108002
            Log('Bumped to %d', svTable.version)
        end
    end

    ---[[
    do
        if svTable.version < 1108003 then
            svProblemsTable[1108003] = {}
            problems = svProblemsTable[1108003]

            for key, data in pairs(svTable) do
                if key ~= 'version' and type(key) == 'string' then
                    Log('Updating %s matches', key)
                    for matchId = 1, #data do
                        if type(data[matchId]) == 'table' then
                            local success, result = pcall(PackMatch, data[matchId])
                            if success then
                                data[matchId] = result
                            else
                                -- handleProblem(matchId, ('failedToPack: %s'):format(result))
                                handleProblem(matchId, 'failedToPack')
                                Log(result)
                            end
                        else
                            handleProblem(matchId, 'notATable')
                        end
                    end
                end
            end

            svTable.version = 1108003
            Log('Bumped to %d', svTable.version)
        end
    end
    --]]

    ---[[
    do
        local function addTeamType(match)
            match.teamType = getTeamType(match.lfgActivityId, match.teamSize)
        end

        if svTable.version < 1108004 then
            svProblemsTable[1108004] = {}
            problems = svProblemsTable[1108004]

            for key, data in pairs(svTable) do
                if key ~= 'version' and type(key) == 'string' then
                    Log('Updating %s matches', key)
                    for matchId = 1, #data do
                        if type(data[matchId]) == 'table' then
                            addTeamType(data[matchId])
                            local success, result = pcall(PackMatch, data[matchId])
                            if success then
                                data[matchId] = result
                            else
                                handleProblem(matchId, 'failedToPack')
                                Log(result)
                            end
                        else
                            local success, result = pcall(UnpackMatch, data[matchId])
                            if not success then
                                handleProblem(matchId, 'failed to unpack previously packed match')
                                Log(result)
                            end
                        end
                    end
                end
            end

            svTable.version = 1108004
            Log('Bumped to %d', svTable.version)
        end
    end
    --]]
end

-- ----------------------------------------------------------------------------

function IMP_STATS_InitializeNewMatchManager(settings, characterSettings)
    local server = string.sub(GetWorldName(), 1, 2)
    ImpressiveStatsMatchesData = ImpressiveStatsMatchesData or {}
    ImpressiveStatsMatchesData[server] = ImpressiveStatsMatchesData[server] or {}

    ImpressiveStatsMatchesUpgradesProblems = ImpressiveStatsMatchesUpgradesProblems or {}
    UpdateSavedVariablesVersion(ImpressiveStatsMatchesData, ImpressiveStatsMatchesUpgradesProblems)

    IMP_STATS_MATCHES_MANAGER = MatchManager(ImpressiveStatsMatchesData[server])

    IMP_STATS_MATCHES_MANAGER.sv = settings

    IMP_STATS_MATCHES_UI:Initialize(settings.namingMode, characterSettings, settings.showOnlyLastUpdateMatches)
end