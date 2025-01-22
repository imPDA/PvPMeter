local addon = {}
addon.name = 'IPM_MATCH_SAVER'

addon.matches = nil
addon.world = nil

local Log = IPM_Log

--#region IPM MATCH
local IPM_Match = {}

function IPM_Match:New(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self

    return o
end

function IPM_Match.GetCurrentMatch(reconnected)
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
        reconnected = reconnected,
    }

    for i = 1, GetBattlegroundNumRounds(bgId) do
        currentMatch.rounds[i] = {
            startTimestamp = nil,
            players = {},
            scores = {},
            result = BATTLEGROUND_RESULT_INVALID,  -- TODO: check
            endTimestamp = nil,
            reconnected = nil,
        }
    end

    return IPM_Match:New(currentMatch)
end

function IPM_Match:UpdatePlayers(round)
    Log('Updating players')

    local localPlayerIndex

    for entryIndex = 1, GetNumScoreboardEntries(round) do
        local characterName, displayName, battlegroundTeam, isLocalPlayer = GetScoreboardEntryInfo(entryIndex, round)
        if isLocalPlayer then localPlayerIndex = entryIndex end

        Log('Saving player %s', displayName)

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
            characterId = isLocalPlayer and GetCurrentCharacterId() or nil,  -- TODO: get char id on player load
        }
    end

    self.rounds[round].players[1], self.rounds[round].players[localPlayerIndex] = self.rounds[round].players[localPlayerIndex], self.rounds[round].players[1]
end

function IPM_Match:UpdateScores(round)
    Log('Updating scores')
    -- TODO: get num teams?
    for i = BATTLEGROUND_TEAM_ITERATION_BEGIN, BATTLEGROUND_TEAM_ITERATION_END do
        self.rounds[round].scores[i] = GetCurrentBattlegroundScore(round, i)
    end
end

function IPM_Match:UpdateResult(round)
    --[[
    * BATTLEGROUND_RESULT_INVALID
    * BATTLEGROUND_RESULT_LOSS
    * BATTLEGROUND_RESULT_TIE
    * BATTLEGROUND_RESULT_WIN
    ]]
    Log('Updating result')
    self.rounds[round].result = GetCurrentBattlegroundRoundResult(round)
end

function IPM_Match:UpdateRound(round)
    Log('Updating %d round', round)

    -- self.rounds[round].endTimestamp = GetTimeStamp()
    if self.rounds[round].result ~= nil and self.rounds[round].result ~= BATTLEGROUND_RESULT_INVALID then
        Log('Round already saved, skipping')
        return
    end

    self:UpdatePlayers(round)
    self:UpdateScores(round)
    self:UpdateResult(round)

    Log('Round %d updated', round)
end

function IPM_Match:UpdateCurrentRound()
    local round = GetCurrentBattlegroundRoundIndex()
    self:UpdateRound(round)
end

function IPM_Match:FinalizeMatch()
    self.result = GetBattlegroundResultForTeam(GetUnitBattlegroundTeam('player'))
    self.locked = true -- TODO: utilize?

    Log('Match finalized')
end

function IPM_Match:IsCurrentMatch()
    local started = self.entryTimestamp or 0

    return
    self.type == GetCurrentBattlegroundGameType() and
    self.battlegroundId == GetCurrentBattlegroundId() and
    (GetTimeStamp() - started) <= 60 * 30
end

function IPM_Match:RestoreCurrentMatch()
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
--#endregion IPM MATCH

--#region ADDON
local BG_STATE = {
    [BATTLEGROUND_STATE_NONE] = 'none',           -- 0
    [BATTLEGROUND_STATE_PREROUND] = 'preround',   -- 1
    [BATTLEGROUND_STATE_STARTING] = 'starting',   -- 2
    [BATTLEGROUND_STATE_RUNNING] = 'running',     -- 3
    [BATTLEGROUND_STATE_POSTROUND] = 'postround', -- 4
    [BATTLEGROUND_STATE_FINISHED] = 'finished',   -- 5
}

function addon:MatchStateChanged(previousState, currentState)
    Log('bg state: %s -> %s', tostring(BG_STATE[previousState]), tostring(BG_STATE[currentState]))

    if currentState == BATTLEGROUND_STATE_STARTING then
        self.sv.currentMatch = IPM_Match.GetCurrentMatch()
    elseif currentState == BATTLEGROUND_STATE_POSTROUND then
        self.sv.currentMatch:UpdateCurrentRound()
    elseif currentState == BATTLEGROUND_STATE_FINISHED then
        self.sv.currentMatch:FinalizeMatch()
        self.matches[#self.matches+1] = self.sv.currentMatch
        self.sv.currentMatch = nil
        IPM_BATTLEGROUNDS_UI:Update()
    end
end

function addon:UpdateDataVersion()
    if not PvPMeterBattlegroundsSV.dataVersion then
        PvPMeterBattlegroundsSV.dataVersion = 0
    end

    Log('Data version: %d', PvPMeterBattlegroundsSV.dataVersion)

    if PvPMeterBattlegroundsSV.dataVersion == 0 then
        local function ReplacePlayersTableWithArrays()
            local newMatches = ZO_DeepTableCopy(self.matches)

            for i, matchData in ipairs(PvPMeterBattlegroundsData) do
                Log('Match id#%d, %d rounds', i, tostring(matchData.rounds and #matchData.rounds))
                for j, roundData in ipairs(matchData.rounds) do
                    local players = {}
                    local playerId = GetDisplayName()

                    if roundData.players.startTimestamp then roundData.players.startTimestamp = nil end

                    local k = 2
                    for _, player in pairs(roundData.players) do
                        if player.displayName == playerId then
                            players[1] = ZO_DeepTableCopy(player)
                        else
                            players[k] = ZO_DeepTableCopy(player)
                            k = k + 1
                        end
                    end

                    newMatches[i].rounds[j].players = players
                end
            end

            PvPMeterBattlegroundsData = newMatches
        end

        ReplacePlayersTableWithArrays()
        Log('Data version: 0 -> 1')
        PvPMeterBattlegroundsSV.dataVersion = 1
    end

    if PvPMeterBattlegroundsSV.dataVersion == 1 then
        local total = 0

        local function SplitByMegaservers()
            local newMatches = {}

            local characterNameToId = {}
            for i = 1, GetNumCharacters() do
                local name, _, _, _, _, _, characterId, _ = GetCharacterInfo(i)
                characterNameToId[name] = characterId
            end

            for i, matchData in pairs(PvPMeterBattlegroundsData) do
                if i ~= 'NA' and i ~= 'EU' then
                    local round = matchData.rounds[1]
                    if round then
                        local player = round.players[1]
                        if player then
                            Log('Match id#%d, character id: %s, character name: %s', i, tostring(player.characterId), player.characterName)

                            if characterNameToId[player.characterName] then
                                player.characterId = characterNameToId[player.characterName]
                                newMatches[#newMatches+1] = ZO_DeepTableCopy(matchData)
                            end

                            total = total + 1
                        else
                            PvPMeterBattlegroundsData[i] = nil
                        end
                    else
                        PvPMeterBattlegroundsData[i] = nil
                    end
                end
            end

            PvPMeterBattlegroundsData[self.server] = newMatches
        end

        SplitByMegaservers()

        local onNA = PvPMeterBattlegroundsData['NA'] and #PvPMeterBattlegroundsData['NA'] or 0
        local onEU = PvPMeterBattlegroundsData['EU'] and #PvPMeterBattlegroundsData['EU'] or 0

        Log('Total: %d, on NA: %d, on EU: %d', total, onNA, onEU)

        if total == onNA + onEU then
            for i, _ in pairs(PvPMeterBattlegroundsData) do
                if i ~= 'NA' and i ~= 'EU' then
                    PvPMeterBattlegroundsData[i] = nil
                end
            end
            Log('Data version: 1 -> 2')
            PvPMeterBattlegroundsSV.dataVersion = 2
        end

        -- Log('Data version: 1 -> 2')
        -- PvPMeterBattlegroundsSV.dataVersion = 2
    end
end

function addon:PlayerActivated(initial)
    Log('Player activated (initial:%s)', tostring(initial))
    Log('There are %d matches saved', #self.matches)
    self.sv = PvPMeterBattlegroundsSV

    if not IsActiveWorldBattleground() then
        Log('Outside of bg')

        if self.sv.currentMatch then
            self.matches[#self.matches+1] = self.sv.currentMatch
            self.sv.currentMatch = nil
        end
    else
        Log('Loaded on bg, restoring match')

        self.sv.currentMatch = IPM_Match:New(self.sv.currentMatch)
        self.sv.currentMatch:RestoreCurrentMatch()

        local battlegroundState = GetCurrentBattlegroundState()

        if battlegroundState == BATTLEGROUND_STATE_FINISHED then
            self.matches[#self.matches+1] = self.sv.currentMatch
            self.sv.currentMatch = nil

            Log('bg ended, restored match saved')
        end
    end

    local function OnBattlegroundStateChanged(_, previousState, currentState)
        self:MatchStateChanged(previousState, currentState)
    end

    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BATTLEGROUND_STATE_CHANGED, OnBattlegroundStateChanged)

    IPM_BATTLEGROUNDS_UI:Update()
end
--#endregion ADDON

local function OnPlayerActivated(_, initial)
    addon:PlayerActivated(initial)
end

function IPM_InitializeMatchSaver(settings, characterSettings)
    IPM_BATTLEGROUNDS_SAVER = addon

    local server = string.sub(GetWorldName(), 1, 2)
    if server ~= 'EU' and server ~= 'NA' then
        Log(server)
        Log('Loaded in a strange world (%s)', GetWorldName())
        return
    end

    PvPMeterBattlegroundsData = PvPMeterBattlegroundsData or {}
    PvPMeterBattlegroundsData[server] = PvPMeterBattlegroundsData[server] or {}

    PvPMeterBattlegroundsSV = PvPMeterBattlegroundsSV or {}

    -- addon:UpdateDataVersion()

    IPM_BATTLEGROUNDS_SAVER.matches = PvPMeterBattlegroundsData[server]

    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    IPM_BATTLEGROUNDS_UI:Initialize(settings.namingMode, characterSettings.selectedCharacters)
end