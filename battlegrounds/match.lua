local addon = {}

Log = IPM_Log

function addon:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    return o
end

local function GetCurrentMatch()
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

addon.GetCurrentMatch = GetCurrentMatch

function addon:UpdatePlayers(round)
    Log('[Match] Updating players')

    local localPlayerIndex

    for entryIndex = 1, GetNumScoreboardEntries(round) do
        local characterName, displayName, battlegroundTeam, isLocalPlayer = GetScoreboardEntryInfo(entryIndex, round)
        if isLocalPlayer then localPlayerIndex = entryIndex end

        Log('[Match] Saving player %s', displayName)

        local lives = GetScoreboardEntryNumLivesRemaining(entryIndex, round)
        local medalScore = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_SCORE, round)
        local kills = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_KILL, round)
        local deaths = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_DEATH, round)
        local assists = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_ASSISTS, round)

        local damageDone = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_DAMAGE_DONE, round)
        local damageTaken = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_DAMAGE_TAKEN, round)
		local healingDone = GetScoreboardEntryScoreByType(entryIndex, SCORE_TRACKER_TYPE_HEALING_DONE, round)
        local classId = GetScoreboardEntryClassId(entryIndex, round)

        self.rounds[round].players[entryIndex] = {
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

    self.rounds[round].players[1], self.rounds[round].players[localPlayerIndex] = self.rounds[round].players[localPlayerIndex], self.rounds[round].players[1]
end

function addon:UpdateScores(round)
    Log('[Match] Updating scores')

    for i = BATTLEGROUND_TEAM_ITERATION_BEGIN, BATTLEGROUND_TEAM_ITERATION_END do
        self.rounds[round].scores[i] = GetCurrentBattlegroundScore(round, i)
    end
end

function addon:UpdateResult(round)
    --[[
    * BATTLEGROUND_RESULT_INVALID
    * BATTLEGROUND_RESULT_LOSS
    * BATTLEGROUND_RESULT_TIE
    * BATTLEGROUND_RESULT_WIN
    ]]
    Log('[Match] Updating result')
    self.rounds[round].result = GetCurrentBattlegroundRoundResult(round)
end

function addon:UpdateRound(round)
    Log('[Match] Updating %d round', round)

    -- self.rounds[round].endTimestamp = GetTimeStamp()
    if self.rounds[round].result ~= nil and self.rounds[round].result ~= BATTLEGROUND_RESULT_INVALID then
        Log('[Match] Round already saved, skipping')
        return
    end

    self:UpdatePlayers(round)
    self:UpdateScores(round)
    self:UpdateResult(round)

    Log('[Match] Round %d updated', round)
end

function addon:UpdateCurrentRound()
    local round = GetCurrentBattlegroundRoundIndex()
    self:UpdateRound(round)
end

function addon:FinalizeMatch()
    self.result = GetBattlegroundResultForTeam(GetUnitBattlegroundTeam('player'))
    self.locked = true -- TODO: utilize?

    Log('[Match] Match finalized')
end

function addon:IsCurrentMatch()
    local started = self.entryTimestamp or 0

    return
    self.type == GetCurrentBattlegroundGameType() and
    self.battlegroundId == GetCurrentBattlegroundId() and
    (GetTimeStamp() - started) <= 60 * 30
end

function addon:RestoreCurrentMatch()
    local battlegroundState = GetCurrentBattlegroundState()
    local currentRoundIndex = GetCurrentBattlegroundRoundIndex()

    for i = 1, GetBattlegroundNumRounds(self.bgId) do
        if battlegroundState ~= BATTLEGROUND_STATE_FINISHED and i == currentRoundIndex then return end
        self:UpdateRound(i)
    end

    if battlegroundState == BATTLEGROUND_STATE_FINISHED then
        self:FinalizeMatch()
    end
end

IPM_MATCH = addon