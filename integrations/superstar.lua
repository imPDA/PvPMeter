local addon = {}

local MUNDUS_BOONS = {
    [13940] = 1, -- Boon: The Warrior
    [13943] = 2, -- Boon: The Mage
    [13974] = 3, -- Boon: The Serpent
    [13975] = 4, -- Boon: The Thief
    [13976] = 5, -- Boon: The Lady
    [13977] = 6, -- Boon: The Steed
    [13978] = 7, -- Boon: The Lord
    [13979] = 8, -- Boon: The Apprentice
    [13980] = 9, -- Boon: The Ritual
    [13981] = 10, -- Boon: The Lover
    [13982] = 11, -- Boon: The Atronach
    [13984] = 12, -- Boon: The Shadow
    [13985] = 13 -- Boon: The Tower
}

local VAMP_OR_WW = {
    [35658] = 5, -- Lycantropy
    [135397] = 1, -- Vampirism: Stage 1
    [135399] = 2, -- Vampirism: Stage 2
    [135400] = 3, -- Vampirism: Stage 3
    [135402] = 4 -- Vampirism: Stage 4
}

local function Concat(...)
    local text = ''

    for _, value in ipairs({...}) do
        text = tostring(value) .. text
    end

    return text
end

local BASE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz123456789!@#&=_{};,<>`~'

local function DecStringToBase(decStr)
    local num = tonumber(decStr)
    if not num then return end

    local text = ''
    while num > 0 do
        local remainder = (num - 1) % string.len(BASE)
        text = BASE:sub(remainder + 1, remainder + 1) .. text
        num = math.floor((num - 1) / string.len(BASE))
    end

    return text
end

local function LongDecToBase(input)
    local CHUNK_SIZE = 15

    local text = ''
    for i = #input, 1, -CHUNK_SIZE do
        local chunk = string.sub(input, math.max(i - CHUNK_SIZE + 1, 1), i)
        local baseChunk = DecStringToBase(chunk)
        if baseChunk then
            if (i - CHUNK_SIZE + 1) > 1 then
                text = string.format('%08s', baseChunk) .. text
            else
                text = baseChunk .. text
            end
        end
    end

    return text
end

local function GetWeaponIconPair(firstWeapon, secondWeapon)
    if firstWeapon ~= WEAPONTYPE_NONE then
        if firstWeapon == WEAPONTYPE_FIRE_STAFF then
            return '/esoui/art/progression/icon_firestaff.dds', 0
        elseif firstWeapon == WEAPONTYPE_FROST_STAFF then
            return '/esoui/art/progression/icon_icestaff.dds', 1
        elseif firstWeapon == WEAPONTYPE_LIGHTNING_STAFF then
            return '/esoui/art/progression/icon_lightningstaff.dds', 2
        elseif firstWeapon == WEAPONTYPE_HEALING_STAFF then
            return '/esoui/art/progression/icon_healstaff.dds', 3
        elseif firstWeapon == WEAPONTYPE_TWO_HANDED_AXE or firstWeapon == WEAPONTYPE_TWO_HANDED_HAMMER or firstWeapon == WEAPONTYPE_TWO_HANDED_SWORD then
            return '/esoui/art/progression/icon_2handed.dds', 4
        elseif firstWeapon == WEAPONTYPE_BOW then
            return '/esoui/art/progression/icon_bows.dds', 5
        elseif secondWeapon ~= WEAPONTYPE_NONE and secondWeapon ~= WEAPONTYPE_SHIELD then
            return '/esoui/art/progression/icon_dualwield.dds', 6
        elseif secondWeapon == WEAPONTYPE_SHIELD then
            return '/esoui/art/progression/icon_1handed.dds', 7
        else
            return '/esoui/art/progression/icon_1handplusrune.dds', 8
        end
    else
        return '', 9
    end
end

local function GetEnchantQuality(itemLink)	-- From Enchanted Quality (Rhyono, votan)
    local subIdToQuality = {}

	local itemId, itemIdSub, enchantSub = itemLink:match("|H[^:]+:item:([^:]+):([^:]+):[^:]+:[^:]+:([^:]+):")
	if not itemId then return 0 end

	enchantSub = tonumber(enchantSub)

	if enchantSub == 0 and not IsItemLinkCrafted(itemLink) then
		local hasSet = GetItemLinkSetInfo(itemLink, false)
		if hasSet then enchantSub = tonumber(itemIdSub) end -- For non-crafted sets, the "built-in" enchantment has the same quality as the item itself
	end

	if enchantSub > 0 then
		local quality = subIdToQuality[enchantSub]

		if not quality then
			-- Create a fake itemLink to get the quality from built-in function
			local itemLink = string.format("|H1:item:%i:%i:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h", itemId, enchantSub)
			quality = GetItemLinkQuality(itemLink)
			subIdToQuality[enchantSub] = quality
		end

		return quality
	end

	return 0
end

function addon.CreateShareData()
    local baseStr = ''

    local playerAlliance = GetUnitAlliance('player') -- 1 digit

    local race = GetUnitRaceId('player') -- 2
    if race == 10 then
        race = 0
    end

    local class = GetUnitClassId('player') -- 1
    if class == 117 then
        class = 7
    end

    local rank = GetUnitAvARank('player') -- 2
    local skillPoints = GetAvailableSkillPoints() -- 3

    local championPointsOrLevel = GetUnitChampionPoints('player') or 0 -- 4
    if championPointsOrLevel == 0 then
        championPointsOrLevel = '88' .. string.format('%02d', GetUnitLevel('player'))
    end

    baseStr = Concat(
        string.format('%01d', playerAlliance),
        string.format('%01d', race),
        string.format('%01d', class),
        string.format('%02d', rank),
        string.format('%03d', skillPoints),
        string.format('%04d', championPointsOrLevel)
    ) .. baseStr

    local mainFirstWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_MAIN_HAND) -- 2 each
    local mainSecondWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_OFF_HAND)
    local _, mainIconIndex = GetWeaponIconPair(mainFirstWeapon, mainSecondWeapon)
    local offFirstWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN)
    local offSecondWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_OFF)
    local _, offIconIndex = GetWeaponIconPair(offFirstWeapon, offSecondWeapon)

    baseStr = Concat(
        string.format('%01d', mainIconIndex),
        string.format('%01d', offIconIndex)
    ) .. baseStr

    local skillPri1 = GetSlotBoundId(3, HOTBAR_CATEGORY_PRIMARY) -- 6 each
    local skillPri2 = GetSlotBoundId(4, HOTBAR_CATEGORY_PRIMARY)
    baseStr = Concat(
        string.format('%06d', skillPri1),
        string.format('%06d', skillPri2)
    ) .. baseStr

    local skillPri3 = GetSlotBoundId(5, HOTBAR_CATEGORY_PRIMARY)
    local skillPri4 = GetSlotBoundId(6, HOTBAR_CATEGORY_PRIMARY)
    baseStr = Concat(
        string.format('%06d', skillPri3),
        string.format('%06d', skillPri4)
    ) .. baseStr

    local skillPri5 = GetSlotBoundId(7, HOTBAR_CATEGORY_PRIMARY)
    local skillPri6 = GetSlotBoundId(8, HOTBAR_CATEGORY_PRIMARY)
    baseStr = Concat(
        string.format('%06d', skillPri5),
        string.format('%06d', skillPri6)
    ) .. baseStr

    local skillBac1 = GetSlotBoundId(3, HOTBAR_CATEGORY_BACKUP)
    local skillBac2 = GetSlotBoundId(4, HOTBAR_CATEGORY_BACKUP)
    baseStr = Concat(
        string.format('%06d', skillBac1),
        string.format('%06d', skillBac2)
    ) .. baseStr

    local skillBac3 = GetSlotBoundId(5, HOTBAR_CATEGORY_BACKUP)
    local skillBac4 = GetSlotBoundId(6, HOTBAR_CATEGORY_BACKUP)
    baseStr = Concat(
        string.format('%06d', skillBac3),
        string.format('%06d', skillBac4)
    ) .. baseStr

    local skillBac5 = GetSlotBoundId(7, HOTBAR_CATEGORY_BACKUP)
    local skillBac6 = GetSlotBoundId(8, HOTBAR_CATEGORY_BACKUP)
    baseStr = Concat(
        string.format('%06d', skillBac5),
        string.format('%06d', skillBac6)
    ) .. baseStr

    -- local skillWW1 = GetSlotBoundId(3, HOTBAR_CATEGORY_WEREWOLF)
    -- local skillWW2 = GetSlotBoundId(4, HOTBAR_CATEGORY_WEREWOLF)
    -- base52Str = base52Str .. get9BitBase52Str(
    --     string.format( '%06d', skillWW1), 
    --     string.format( '%06d', skillWW2)
    -- )
    -- --------------------------
    -- local skillWW3 = GetSlotBoundId(5, HOTBAR_CATEGORY_WEREWOLF)
    -- local skillWW4 = GetSlotBoundId(6, HOTBAR_CATEGORY_WEREWOLF)
    -- base52Str = base52Str .. get9BitBase52Str(
    --     string.format( '%06d', skillWW3), 
    --     string.format( '%06d', skillWW4)
    -- )
    -- --------------------------
    -- local skillWW5 = GetSlotBoundId(7, HOTBAR_CATEGORY_WEREWOLF)
    -- local skillWW6 = GetSlotBoundId(8, HOTBAR_CATEGORY_WEREWOLF)
    -- base52Str = base52Str .. get9BitBase52Str(
    --     string.format( '%06d', skillWW5), 
    --     string.format( '%06d', skillWW6)
    -- )

    local activeBoons = 0
    local vampWWId = 0
    local activeVampWW = {}

    local numBuffs = GetNumBuffs('player')
    local hasActiveEffects = numBuffs > 0

    if hasActiveEffects then
        for i = 1, numBuffs do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo('player', i)
            if MUNDUS_BOONS[abilityId] then
                activeBoons = MUNDUS_BOONS[abilityId]
            end
            if VAMP_OR_WW[abilityId] then
                vampWWId = VAMP_OR_WW[abilityId]
            end
        end
    end
    baseStr = Concat(
        string.format( '%02d', activeBoons),
        string.format( '%01d', vampWWId)
    ) .. baseStr

    local magAttr = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA) -- 2 each
    local heaAttr = GetAttributeSpentPoints(ATTRIBUTE_HEALTH)
    local staAttr = GetAttributeSpentPoints(ATTRIBUTE_STAMINA)
    baseStr = Concat(
        string.format( '%02d', magAttr),
        string.format( '%02d', heaAttr),
        string.format( '%02d', staAttr)
    ) .. baseStr

    local staMax = GetPlayerStat(STAT_MAGICKA_MAX) -- 5 each
    local heaMax = GetPlayerStat(STAT_HEALTH_MAX)
    local magMax = GetPlayerStat(STAT_STAMINA_MAX)
    baseStr = Concat(
        string.format( '%05d', staMax),
        string.format( '%05d', heaMax),
        string.format( '%05d', magMax)
    ) .. baseStr

    local magReg = GetPlayerStat(STAT_MAGICKA_REGEN_COMBAT) -- 4 each
    local heaReg = GetPlayerStat(STAT_HEALTH_REGEN_COMBAT)
    local staReg = GetPlayerStat(STAT_STAMINA_REGEN_COMBAT)
    baseStr = Concat(
        string.format( '%04d', magReg), 
        string.format( '%04d', heaReg), 
        string.format( '%04d', staReg)
    ) .. baseStr

    local magDmg = GetPlayerStat(STAT_SPELL_POWER) -- 5 each
    local staDmg = GetPlayerStat(STAT_POWER)
    local magCri = GetPlayerStat(STAT_SPELL_CRITICAL)
    baseStr = Concat(
        string.format( '%05d', magDmg),
        string.format( '%05d', staDmg),
        string.format( '%05d', magCri)
    ) .. baseStr

    local staCri = GetPlayerStat(STAT_CRITICAL_STRIKE) -- 5 each
    local magPen = GetPlayerStat(STAT_SPELL_PENETRATION)
    local staPen = GetPlayerStat(STAT_PHYSICAL_PENETRATION)
    baseStr = Concat(
        string.format( '%05d', staCri), 
        string.format( '%05d', magPen), 
        string.format( '%05d', staPen)
    ) .. baseStr

    local magRes = GetPlayerStat(STAT_SPELL_RESIST) -- 5 each
    local staRes = GetPlayerStat(STAT_PHYSICAL_RESIST)
    baseStr = Concat(
        string.format( '%05d', magRes), 
        string.format( '%05d', staRes)
    ) .. baseStr

    local slots = {
        [EQUIP_SLOT_HEAD] = true,
        [EQUIP_SLOT_NECK] = true,
        [EQUIP_SLOT_CHEST] = true,
        [EQUIP_SLOT_SHOULDERS] = true,
        [EQUIP_SLOT_MAIN_HAND] = true,
        [EQUIP_SLOT_OFF_HAND] = true,
        [EQUIP_SLOT_WAIST] = true,
        [EQUIP_SLOT_LEGS] = true,
        [EQUIP_SLOT_FEET] = true,
        [EQUIP_SLOT_RING1] = true,
        [EQUIP_SLOT_RING2] = true,
        [EQUIP_SLOT_HAND] = true,
        [EQUIP_SLOT_BACKUP_MAIN] = true,
        [EQUIP_SLOT_BACKUP_OFF] = true
    }

    for slotId in pairs(slots) do
        local itemLink = GetItemLink(BAG_WORN, slotId)
        if itemLink ~= '' then
            local itemId = GetItemLinkItemId(itemLink)
            local itemQuality = GetItemLinkDisplayQuality(itemLink)
            local itemTrait = GetItemLinkTraitInfo(itemLink)
            local itemEnchantId  = itemLink:match('|H[^:]+:item:[^:]+:[^:]+:[^:]+:([^:]+):')
            local itemEnchantQuality = GetEnchantQuality(itemLink)
            baseStr = Concat(
                string.format( '%06d', itemId), 
                string.format( '%01d', itemQuality),
                string.format( '%02d', itemTrait), 
                string.format( '%06d', itemEnchantId),
                string.format( '%01d', itemEnchantQuality)
            ) .. baseStr
        else
            baseStr = '0000000000000000' .. baseStr
        end
    end

    local cBarStart, cBarEnd = GetAssignableChampionBarStartAndEndSlots()
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineStr = ''
        for CSlotIndex = cBarStart, cBarEnd do
            if disciplineIndex == GetRequiredChampionDisciplineIdForSlot(CSlotIndex, HOTBAR_CATEGORY_CHAMPION) then
                local CSlotId = GetSlotBoundId(CSlotIndex, HOTBAR_CATEGORY_CHAMPION) -- 3 each
                disciplineStr = string.format( '%04d', CSlotId)
                baseStr = disciplineStr .. baseStr
            end
        end
    end

    -- d('dec: '.. base52Str)
    -- d('base: '.. longDecToBase(base52Str))
    -- d('turned back dec: '.. baseToLongDec(longDecToBase(base52Str)))
    -- local shareLink = ZO_LinkHandler_CreateLink(string.sub(GetUnitDisplayName('player'), 2, 12) .. ''s SuperStar', nil, SUPERSTAR_SHARE, longDecToBase(base52Str) )

    return LongDecToBase(baseStr)
end

function addon.CreateSuperStarLink(data)
    return ZO_LinkHandler_CreateLink('SuperStar', nil, ';', data)
end

IMP_IS_INTEGRATIONS = IMP_IS_INTEGRATIONS or {}
IMP_IS_INTEGRATIONS['superstar'] = addon