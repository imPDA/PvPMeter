local addon = {}
addon.name = 'IMP_STATS_Duels_MANAGER'

addon.playerData = nil

local Log = IMP_STATS_Logger('DUELS_MANAGER')

local function Close(timems1, timems2, diff)
    if timems1 == nil or timems2 == nil then return error('Time cant be nil') end

    diff = diff or 1000
    Log('Diff: %d', math.abs(timems1 - timems2))
    if math.abs(timems1 - timems2) < diff then return true end
end

local function IfFightBelongsToDuel(fight, duel)
    return Close(fight.combatstart, duel.duelStart, 3000)  -- Close(lastDuel.duelEnd, fight.combatend)
end

--#region IMP STATS DUEL
local Duel = {}

function Duel:New(o)
    o = o or {}

    o.timestamp = GetTimeStamp()
    o.duelStart = GetGameTimeMilliseconds()

    setmetatable(o, self)
    self.__index = self

    return o
end

function Duel:AddFightData(fight)
    self.damageDone = fight.damageOutTotal
    self.damageTaken = fight.damageInTotal
    self.healingTaken = fight.healingInTotal
    self.damageShilded = fight.damageInShielded
    self.DPSOut = fight.DPSOut
    self.DPSIn = fight.DPSIn
    self.HPSIn = fight.HPSIn
    self.duration = fight.combattime
end

function Duel:AddResult(duelResult, wasLocalPlayersResult)
    self.duelEnd = GetGameTimeMilliseconds()
    self.result = duelResult
    self.wasLocalPlayersResult = wasLocalPlayersResult
end

function Duel:AddOpponentData(opponentData)
    self.opponent = opponentData
end

function Duel:AddPlayerData(playerData)
    self.player = playerData
end
--#endregion

--#region IMP STATS DUELS
function addon:TryToSaveCurrentDuel()
    if self.resultAdded and self.fightDataAdded then
        self.duels[#self.duels+1] = self.currentDuel
        self.currentDuel = nil
        self.resultAdded = nil
        self.fightDataAdded = nil
        Log('Duel data saved #%d', #self.duels)

        IMP_STATS_Duels_UI:Update()
    end
end

function addon:OnFightSummary(fight)
    Log('Fight summary available')

    LibCombat:UnregisterCallbackType(LIBCOMBAT_EVENT_FIGHTSUMMARY, _, addon.name)

    if IfFightBelongsToDuel(fight, self.currentDuel) then
        self.currentDuel:AddFightData(fight)
        self.fightDataAdded = true
    end

    self:TryToSaveCurrentDuel()
end

function addon:OnDuelStarted()
    Log('Duel started')

    self.currentDuel = Duel:New()
    LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_FIGHTSUMMARY, function(_, ...) self:OnFightSummary(...) end, addon.name)
end

function addon:OnDuelFinished(duelResult, wasLocalPlayersResult, opponentCharacterName, opponentDisplayName, opponentAlliance, opponentGender, opponentClassId, opponentRaceId)
    Log('Duel finished')

    self.currentDuel:AddPlayerData(self.playerData)

    self.currentDuel:AddOpponentData({
        characterName = opponentCharacterName,
        displayName = opponentDisplayName,
        alliance = opponentAlliance,
        gender = opponentGender,
        classId = opponentClassId,
        raceId = opponentRaceId,
    })

    self.currentDuel:AddResult(duelResult, wasLocalPlayersResult)
    self.resultAdded = true

    self:TryToSaveCurrentDuel()
end

function addon:PlayerActivated(initial)
    local function OnDuelStarted(_)
        self:OnDuelStarted()
    end

    local function OnDuelFinished(_, ...)
        self:OnDuelFinished(...)
    end

    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_DUEL_STARTED, OnDuelStarted)
    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_DUEL_FINISHED, OnDuelFinished)

    IMP_STATS_Duels_UI:Update()
end
--#endregion

local function OnPlayerActivated(_, initial)
    addon:PlayerActivated(initial)
end

function IMP_STATS_InitializeDuelsManager(settings, characterSettings)
    IMP_STATS_Duels_MANAGER = addon

    local server = string.sub(GetWorldName(), 1, 2)
    IMP_STATS_Duels_MANAGER.playerData = {
        characterName = GetRawUnitName('player'),
        displayName = GetDisplayName(),
        characterId = GetCurrentCharacterId(),
        alliance = GetUnitAlliance('player'),
        gender = GetUnitGender('player'),
        classId = GetUnitClassId('player'),
        raceId = GetUnitRaceId('player'),
    }

    ImpressiveStatsDuelsData = ImpressiveStatsDuelsData or {}
    ImpressiveStatsDuelsData[server] = ImpressiveStatsDuelsData[server] or {}

    IMP_STATS_Duels_MANAGER.duels = ImpressiveStatsDuelsData[server]
    Log('There are %d duels saved', #addon.duels)

    EVENT_MANAGER:RegisterForEvent(IMP_STATS_Duels_MANAGER.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    IMP_STATS_Duels_UI:Initialize(settings.namingMode, characterSettings.selectedCharacters)
end