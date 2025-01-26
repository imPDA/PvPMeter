local addon = {}
addon.name = 'IPM_MATCH_MANAGER'

local Log = IPM_Log

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
        self.sv.currentMatch = IPM_MATCH:New(IPM_MATCH.GetCurrentMatch())
    elseif currentState == BATTLEGROUND_STATE_POSTROUND then
        self.sv.currentMatch:UpdateCurrentRound()
    elseif currentState == BATTLEGROUND_STATE_FINISHED then
        self.sv.currentMatch:FinalizeMatch()
        self.matches[#self.matches+1] = self.sv.currentMatch
        self.sv.currentMatch = nil
        IPM_BATTLEGROUNDS_UI:Update()
    end
end

function addon:PlayerActivated(initial)
    Log('[B] There are %d matches saved', #self.matches)
    self.sv = PvPMeterBattlegroundsSV

    if not IsActiveWorldBattleground() then
        if self.sv.currentMatch then
            self.matches[#self.matches+1] = self.sv.currentMatch
            self.sv.currentMatch = nil
        end
    else
        self.sv.currentMatch = IPM_MATCH:New(self.sv.currentMatch)
        self.sv.currentMatch:RestoreCurrentMatch()

        local battlegroundState = GetCurrentBattlegroundState()

        if battlegroundState == BATTLEGROUND_STATE_FINISHED then
            self.matches[#self.matches+1] = self.sv.currentMatch
            self.sv.currentMatch = nil

        end
    end

    local function OnBattlegroundStateChanged(_, previousState, currentState)
        self:MatchStateChanged(previousState, currentState)
    end

    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_BATTLEGROUND_STATE_CHANGED, OnBattlegroundStateChanged)

    IPM_BATTLEGROUNDS_UI:Update()
end

function addon:GetDataRows()
    return self.matches
end

addon.GetMatches = IPM_Shared.Get

local function OnPlayerActivated(_, initial)
    addon:PlayerActivated(initial)
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

    PvPMeterBattlegroundsSV = PvPMeterBattlegroundsSV or {}

    IPM_BATTLEGROUNDS_MANAGER.matches = PvPMeterBattlegroundsData[server]

    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    IPM_BATTLEGROUNDS_UI:Initialize(settings.namingMode, characterSettings.selectedCharacters)

    -- PerformanceTesting()
end