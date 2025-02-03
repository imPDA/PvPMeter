local addon = {}
addon.name = 'IPM_MATCH_MANAGER'

local Log = IPM_Logger('MATCHES_MANAGER')

--#region MATCH
local function GetNewMatchFromCurrentMatch()
    Log('Creating new match')

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
        grouped = IPM_BATTLEGROUNDS_MANAGER:IsGrouped(),
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
        Log('Round %d of current match was already saved, skipping', round)
        return
    end

    currentRound.players = GetPlayersFromCurrentMatchRound(round)
    currentRound.scores = GetScoresFromCurrentMatchRound(round)
    currentRound.result = GetResultFromCurrentMatchRound(round)

    Log('Round %d of current match updated', round)
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
    if not match then return end

    local started = match.entryTimestamp or 0

    return
    match.type == GetCurrentBattlegroundGameType() and
    match.battlegroundId == GetCurrentBattlegroundId() and
    (GetTimeStamp() - started) <= 60 * 20
end

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

function addon:RestoreCurrentMatch()
    local battlegroundState = GetCurrentBattlegroundState()
    local currentRoundIndex = GetCurrentBattlegroundRoundIndex()

    if battlegroundState and battlegroundState == BATTLEGROUND_STATE_NONE then return end

    Log('Restoring BG, round: %d, state: %s', currentRoundIndex, GetMatchStateName(battlegroundState))
    -- self.currentMatch = ImpPvPMeterMatchBackup or GetNewMatchFromCurrentMatch()

    for i = 1, GetBattlegroundNumRounds(self.currentMatch.battlegroundId) do
        if battlegroundState ~= BATTLEGROUND_STATE_FINISHED and i == currentRoundIndex then return end
        self:UpdateCurrentMatchRound(i)
    end

    if battlegroundState == BATTLEGROUND_STATE_FINISHED then
        self:FinalizeCurrentMatch()
        self:SaveCurrentMatch()
        IPM_BATTLEGROUNDS_UI:Update()
    end
end
--#endregion MATCH

function addon:IsCurrentMatchFinished()
    -- Log('Lets decide if current match finished')
    local battlegroundId = self.currentMatch.battlegroundId

    -- Log('BG is: %d (%d)', self.currentMatch.battlegroundId, GetCurrentBattlegroundId())
    -- Log('Has rounds: %s', tostring(not DoesBattlegroundHaveRounds(battlegroundId)))
    -- Log('Was the last round: %s', tostring(GetCurrentBattlegroundRoundIndex() == GetBattlegroundNumRounds(battlegroundId)))
    -- Log('Won early: %s', tostring(HasTeamWonBattlegroundEarly()))

    return
    -- not DoesBattlegroundHaveRounds(battlegroundId) or
    GetCurrentBattlegroundRoundIndex() == GetBattlegroundNumRounds(battlegroundId) or
    HasTeamWonBattlegroundEarly()
end

function addon:SaveCurrentMatch()
    if not self.currentMatch then return end

    -- can create some kind of hash to check if this is the same matches and avoid duplication
    local function SameDamageDone()
        if not self.matches[#self.matches] then return end
        local previousMatchLocalPlayer = self.matches[#self.matches].rounds[1].players[1]
        if not previousMatchLocalPlayer then return end

        if not self.currentMatch then return end
        local currentMatchLocalPlayer = self.currentMatch.rounds[1].players[1]
        if not currentMatchLocalPlayer then return end

        return previousMatchLocalPlayer.damageDone == currentMatchLocalPlayer.damageDone
    end

    if not IsCurrentMatch(self.matches[#self.matches]) and not SameDamageDone() then
        self.matches[#self.matches+1] = self.currentMatch
        Log('Match saved as #%d', #self.matches)
    end

    self.currentMatch = nil
    ImpPvPMeterMatchBackup = nil
end

function addon:MatchStateChanged(previousState, currentState)
    Log('State: %s -> %s', GetMatchStateName(previousState), GetMatchStateName(currentState))

    if not self.currentMatch then
        Log('!Match state changed but there is no data about current match!')  -- TODO: throw error/can try to restore
        return
    end

    if previousState == BATTLEGROUND_STATE_NONE then
        self.currentMatch.playedFromStart = true
    end

    if currentState == BATTLEGROUND_STATE_POSTROUND then
        self:UpdateCurrentRound()

        if self:IsCurrentMatchFinished() then
            Log('Current match finished')
            self:FinalizeCurrentMatch()
            self:SaveCurrentMatch()
            IPM_BATTLEGROUNDS_UI:Update()
        end
    -- elseif currentState == BATTLEGROUND_STATE_FINISHED then
    --     if self.currentMatch then
    --         Log('There is match to save, saving')
    --         self:FinalizeCurrentMatch()
    --         self:SaveCurrentMatch()
    --         IPM_BATTLEGROUNDS_UI:Update()
    --     end
    end
end

function addon:IsGrouped()
    return self.sv.grouped
end

function addon:PlayerActivated(initial)
    Log('Initial: %s', tostring(initial))
    -- local battlegroundState = GetCurrentBattlegroundState()

    if IsActiveWorldBattleground() then
        if ImpPvPMeterMatchBackup then
            Log('There is a backup, same BG: %s', tostring(IsCurrentMatch(ImpPvPMeterMatchBackup)))
            if IsCurrentMatch(ImpPvPMeterMatchBackup) then
                self.currentMatch = ImpPvPMeterMatchBackup
                -- TODO: mark if it is backed up data or not, check if it is good
                -- self:RestoreCurrentMatch()
            else
                self.currentMatch = GetNewMatchFromCurrentMatch()
                -- self:RestoreCurrentMatch()

                self.matches[#self.matches+1] = ImpPvPMeterMatchBackup
                ImpPvPMeterMatchBackup = self.currentMatch
            end
        else
            self.currentMatch = GetNewMatchFromCurrentMatch()
            ImpPvPMeterMatchBackup = self.currentMatch
        end
        self:RestoreCurrentMatch()
    else
        -- TODO: check if it is already saved match
        -- TODO: check if it is a good match
        if ImpPvPMeterMatchBackup then
            Log('There is a backup outside of BG')
            self.matches[#self.matches+1] = ImpPvPMeterMatchBackup
            ImpPvPMeterMatchBackup = nil
        end
    end

-- if initial then
    local function OnBattlegroundStateChanged(_, previousState, currentState)
        self:MatchStateChanged(previousState, currentState)
    end

    -- EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BATTLEGROUND_STATE_CHANGED, OnBattlegroundStateChanged)
-- end
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

    Log('There are %d matches saved', #IPM_BATTLEGROUNDS_MANAGER.matches)

    if PvPMeterBattlegroundsData.version == nil then PvPMeterBattlegroundsData.version = 0 end
    if PvPMeterBattlegroundsData.version < 1010019 then  -- before 0.1.0b19
        for key, data in pairs(PvPMeterBattlegroundsData) do
            if key ~= 'version' then
                for _, matchData in ipairs(data) do
                    if matchData.api == nil then matchData.api = 101044 end
                    if matchData.playedFromStart == nil then matchData.playedFromStart = true end
                end
            end
        end

        PvPMeterBattlegroundsData.version = 1010019
    end

    -- local GROUP_TYPE_TO_STRING = {
    --     [LFG_GROUP_TYPE_BIG_TEAM_BATTLE] = 'BIG_TEAM_BATTLE',
    --     [LFG_GROUP_TYPE_LARGE] = 'LARGE',
    --     [LFG_GROUP_TYPE_MEDIUM] = 'MEDIUM',
    --     [LFG_GROUP_TYPE_NONE] = 'NONE',
    --     [LFG_GROUP_TYPE_REGULAR] = 'REGULAR',
    -- }
    -- for i, data in ipairs(ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData[7]) do
    --     local name, levelMin, levelMax, championPointsMin, championPointsMax, groupType, minGroupSize, description, sortOrder = GetActivityInfo(data.id)
    --     if groupType == LFG_GROUP_TYPE_NONE then
    --         Log('#%d, groupType: %s, minGroupSize: %d, maxGroupSize: %d', i, GROUP_TYPE_TO_STRING[groupType], minGroupSize, data.maxGroupSize)
    --     end
    -- end

    -- EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_GROUP_UPDATE, function() Log('Group update') end)
    -- ZO_PostHook(ZO_ACTIVITY_FINDER_ROOT_MANAGER, 'StartSearch', function(zo_activity_finder_root_manager)
    --     IPM_BATTLEGROUNDS_MANAGER.sv.grouped = zo_activity_finder_root_manager.playerIsGrouped
    --     Log(zo_activity_finder_root_manager.playerIsGrouped and 'Searching as group' or 'Searching as solo')
    -- end)
    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, function(_, state)
        if state ~= ACTIVITY_FINDER_STATUS_READY_CHECK then return end

        IPM_BATTLEGROUNDS_MANAGER.sv.grouped = ZO_ACTIVITY_FINDER_ROOT_MANAGER.playerIsGrouped
        Log(ZO_ACTIVITY_FINDER_ROOT_MANAGER.playerIsGrouped and 'Joining as group' or 'Joining as solo')
    end)

    IPM_BATTLEGROUNDS_MANAGER.sv = settings

    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    IPM_BATTLEGROUNDS_UI:Initialize(settings.namingMode, characterSettings.selectedCharacters)

    -- PerformanceTesting()
end