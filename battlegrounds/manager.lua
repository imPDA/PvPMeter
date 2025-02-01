local addon = {}
addon.name = 'IPM_MATCH_MANAGER'

local Log = IPM_Log

--#region MATCH
local function GetNewMatchFromCurrentMatch()
    local bgId = GetCurrentBattlegroundId()
    local unitZoneIndex = GetUnitZoneIndex('player')

    local currentMatch = {
        type = GetCurrentBattlegroundGameType(),
        battlegroundId = bgId,
        playerRace = GetUnitRaceId('player'),
        playerClass = GetUnitClassId('player'),
        zoneIndex = unitZoneIndex,
        zoneId = GetZoneId(unitZoneIndex),
        zoneName = GetUnitZone('player'),
        entryTimestamp = GetTimeStamp(),
        rounds = {},
        result = BATTLEGROUND_RESULT_INVALID,
        lfgActivityId = GetCurrentLFGActivityId(),
        teamSize = GetBattlegroundTeamSize(GetCurrentBattlegroundId()),
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

-- addon.GetCurrentMatch = GetNewMatchFromCurrent

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

    players[1], players[localPlayerIndex] = players[localPlayerIndex], players[1]

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

function addon:UpdateCurrentMatchRound(round)
    local currentRound = self.currentMatch.rounds[round]

    -- self.rounds[round].endTimestamp = GetTimeStamp()
    if currentRound.result ~= nil and currentRound.result ~= BATTLEGROUND_RESULT_INVALID then
        Log('[MATCH MANAGER] Round %d of current match was already saved, skipping', round)
        return
    end

    currentRound.players = GetPlayersFromCurrentMatchRound(round)
    currentRound.scores = GetScoresFromCurrentMatchRound(round)
    currentRound.result = GetResultFromCurrentMatchRound(round)

    Log('[MATCH MANAGER] Round %d of current match updated', round)
end

function addon:UpdateCurrentRound()
    local round = GetCurrentBattlegroundRoundIndex()
    self:UpdateCurrentMatchRound(round)
end

function addon:FinalizeCurrentMatch()
    self.currentMatch.result = GetBattlegroundResultForTeam(GetUnitBattlegroundTeam('player'))
    self.currentMatch.locked = true -- TODO: utilize?
end

local function IsCurrentMatch(match)
    local started = match.entryTimestamp or 0

    return
    match.type == GetCurrentBattlegroundGameType() and
    match.battlegroundId == GetCurrentBattlegroundId() and
    (GetTimeStamp() - started) <= 60 * 30
end

function addon:RestoreCurrentMatch()
    local battlegroundState = GetCurrentBattlegroundState()
    local currentRoundIndex = GetCurrentBattlegroundRoundIndex()

    for i = 1, GetBattlegroundNumRounds(self.currentMatch.bgId) do
        if battlegroundState ~= BATTLEGROUND_STATE_FINISHED and i == currentRoundIndex then return end
        self:UpdateCurrentMatchRound(i)
    end

    if battlegroundState == BATTLEGROUND_STATE_FINISHED then
        self:FinalizeCurrentMatch()
    end
end
--#endregion MATCH

local MATCH_STATE = {
    [BATTLEGROUND_STATE_NONE]       = 'none',       -- 0
    [BATTLEGROUND_STATE_PREROUND]   = 'preround',   -- 1
    [BATTLEGROUND_STATE_STARTING]   = 'starting',   -- 2
    [BATTLEGROUND_STATE_RUNNING]    = 'running',    -- 3
    [BATTLEGROUND_STATE_POSTROUND]  = 'postround',  -- 4
    [BATTLEGROUND_STATE_FINISHED]   = 'finished',   -- 5
}

local function GetMatchStateName(matchState)
    return MATCH_STATE[matchState] or 'unknown'
end

function addon:IsCurrentMatchFinished()
    local battlegroundId = self.currentMatch.bgId

    return
    not DoesBattlegroundHaveRounds(battlegroundId) or
    GetCurrentBattlegroundRoundIndex() == GetBattlegroundNumRounds(battlegroundId) or
    HasTeamWonBattlegroundEarly()
end

function addon:SaveCurrentMatch()
    self.matches[#self.matches+1] = self.currentMatch
    self.currentMatch = nil
    ImpPvPMeterMatchBackup = nil
end

function addon:MatchStateChanged(previousState, currentState)
    Log('[MATCH MANAGER] State: %s -> %s', GetMatchStateName(previousState), GetMatchStateName(currentState))

    if currentState == BATTLEGROUND_STATE_STARTING then
        self.currentMatch = GetNewMatchFromCurrentMatch()
        ImpPvPMeterMatchBackup = self.currentMatch
    elseif currentState == BATTLEGROUND_STATE_POSTROUND then
        self:UpdateCurrentRound()

        if self:IsCurrentMatchFinished() then
            self:FinalizeCurrentMatch()
            self:SaveCurrentMatch()
            IPM_BATTLEGROUNDS_UI:Update()
        end
    elseif currentState == BATTLEGROUND_STATE_FINISHED then
        if self.currentMatch then
            self:FinalizeCurrentMatch()
            self:SaveCurrentMatch()
            IPM_BATTLEGROUNDS_UI:Update()
        end
    end
end

function addon:PlayerActivated(initial)
    if initial then
        if IsActiveWorldBattleground() then
            -- TODO: mark if it is backed up data or not, check if it is good
            self.currentMatch = ImpPvPMeterMatchBackup or GetNewMatchFromCurrentMatch()
            self:RestoreCurrentMatch()

            local battlegroundState = GetCurrentBattlegroundState()
            if battlegroundState == BATTLEGROUND_STATE_FINISHED then
                self:SaveCurrentMatch()
            end
        end

        local function OnBattlegroundStateChanged(_, previousState, currentState)
            self:MatchStateChanged(previousState, currentState)
        end

        -- EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BATTLEGROUND_STATE_CHANGED, OnBattlegroundStateChanged)
    end

    if not IsActiveWorldBattleground() then
        -- TODO: check if it is already saved match
        -- TODO: check if it is a good match
        if ImpPvPMeterMatchBackup then
            Log('[MATCH MANAGER] There is unsaved backup, saving it')
            self.matches[#self.matches+1] = ImpPvPMeterMatchBackup
            ImpPvPMeterMatchBackup = nil
        end
    end
end

function addon:GetDataRows()
    return self.matches
end

addon.GetMatches = IPM_Shared.Get

local function OnPlayerActivated(_, initial)
    addon:PlayerActivated(initial)
    IPM_BATTLEGROUNDS_UI:Update()
end

local function PerformanceTesting()
    local function ProcessSlashCommand(cmd)
        Log('Command %s received', cmd)

        if cmd == 'x2' then
            local matches = IPM_BATTLEGROUNDS_MANAGER.matches
            local len = #matches
            for i = 1, len do
                matches[#matches+1] = matches[i]
            end
            Log('New lenght: %d', #matches)
            IPM_BATTLEGROUNDS_UI:Update()
        elseif cmd == ':2' then
            local matches = IPM_BATTLEGROUNDS_MANAGER.matches
            for i = #matches, zo_round(#matches/2), -1 do
                matches[i] = nil
            end
            IPM_BATTLEGROUNDS_UI:Update()
        end
    end

    SLASH_COMMANDS['/ipmbg'] = ProcessSlashCommand
end

function IPM_InitializeMatchSaver(settings, characterSettings)
    IPM_BATTLEGROUNDS_MANAGER = addon

    local server = string.sub(GetWorldName(), 1, 2)

    PvPMeterBattlegroundsData = PvPMeterBattlegroundsData or {}
    PvPMeterBattlegroundsData[server] = PvPMeterBattlegroundsData[server] or {}
    IPM_BATTLEGROUNDS_MANAGER.matches = PvPMeterBattlegroundsData[server]

    Log('[MATCH MANAGER] There are %d matches saved', #IPM_BATTLEGROUNDS_MANAGER.matches)

    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    IPM_BATTLEGROUNDS_UI:Initialize(settings.namingMode, characterSettings.selectedCharacters)

    -- PerformanceTesting()
end