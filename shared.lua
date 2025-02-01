local Log = IPM_Log

local addon = {}

function addon.FormatNumber(number)
    if number > 1e9 then
        return string.format('%.1f B', number / 1e9)
    elseif number > 1e6 then
        return string.format('%.1f M', number / 1e6)
    elseif number > 1e3 then
        return string.format('%.1f K', number / 1e3)
    else
        return string.format('%d', number)
    end
end

local RACE_ICONS = {
    [1] = 'esoui/art/charactercreate/charactercreate_bretonicon_up.dds',
    [2] = 'esoui/art/charactercreate/charactercreate_redguardicon_up.dds',
    [3] = 'esoui/art/charactercreate/charactercreate_orcicon_up.dds',
    [4] = 'esoui/art/charactercreate/charactercreate_dunmericon_up.dds',
    [5] = 'esoui/art/charactercreate/charactercreate_nordicon_up.dds',
    [6] = 'esoui/art/charactercreate/charactercreate_argonianicon_up.dds',
    [7] = 'esoui/art/charactercreate/charactercreate_altmericon_up.dds',
    [8] = 'esoui/art/charactercreate/charactercreate_bosmericon_up.dds',
    [9] = 'esoui/art/charactercreate/charactercreate_khajiiticon_up.dds',
    [10] = 'esoui/art/charactercreate/charactercreate_imperialicon_up.dds',
}

function addon.GetRaceIcon(raceId)
    return RACE_ICONS[raceId]
end

function addon.PossibleNan(value)
    return value == value and value or 0
end

local function HSV2RGB(h, s, v)
    local k1 = v*(1-s)
    local k2 = v - k1
    local r = math.min (math.max (3*math.abs (((h      )/180)%2-1)-1, 0), 1)
    local g = math.min (math.max (3*math.abs (((h  -120)/180)%2-1)-1, 0), 1)
    local b = math.min (math.max (3*math.abs (((h  +120)/180)%2-1)-1, 0), 1)

    return k1 + k2 * r, k1 + k2 * g, k1 + k2 * b
end

function addon.Blend(A, B, value)
    local Ah, As, Av = ConvertRGBToHSV(unpack(A))
    local Bh, Bs, Bv = ConvertRGBToHSV(unpack(B))

    Ah = Ah % 360
    Bh = Bh % 360

    -- df('A - h:%f s:%f v:%f', Ah, As, Av)

    local Ch = Ah + (Bh - Ah) * value
    -- local Cs = As + (Bs - As) * value
    -- local Cv = Av + (Bv - Av) * value

    local r, g, b = HSV2RGB(Ch, 1, 1)

    -- df('r:%.2f, g:%.2f, b:%.2f', r, g, b)

    return r, g, b
    --[[
    local Ar, Ag, Ab = unpack(A)
    local Aa = 1
    local Br, Bg, Bb = unpack(B)
    local Ba = 1

    local w, a, w1, w2
    w = value * 2 - 1
    a = Aa - Ba

    w1 = ((w * a == -1 and w or (w + a)/(1 + w * a)) + 1) / 2
    w2 = 1 - w1

    return
        w1 * Ar + w2 * Br,
        w1 * Ag + w2 * Bg,
        w1 * Ab + w2 * Bb
    ]]
end

function addon.TableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function addon.Get(self, task, filters, tbl)
    local function PassFilters(data)
        for _, filter in ipairs(filters) do
            if not filter(data) then return end
        end

        return true
    end

    local function Filter(index, data)
        if PassFilters(data) then table.insert(tbl, index) end
    end

    return task:For(ipairs(self:GetDataRows())):Do(Filter)
end

local function InitializeFilter(contorl, entriesData, setFiltersCallback)
    local comboBox = ZO_ComboBox_ObjectFromContainer(contorl)

    comboBox:SetSortsItems(false)
    comboBox:SetFont('ZoFontWinT1')
    comboBox:SetSpacing(4)

    local function OnFilterChanged(comboBox, entryText, entry)
        local newFilters = {}

        for i, itemData in ipairs(comboBox.m_selectedItemData) do
            table.insert(newFilters, itemData.filterType)
        end

        setFiltersCallback(newFilters)
    end

    for i, entry in ipairs(entriesData) do
        local item = comboBox:CreateItemEntry(entry.text, OnFilterChanged)
        item.filterType = entry.type

        comboBox:AddItem(item)
    end

    return comboBox
end

addon.InitializeFilter = InitializeFilter

local CHARACTER_SELECTION_TYPE_ALL = 1
local CHARACTER_SELECTION_TYPE_CURRENT = 2
local CHARACTER_SELECTION_TYPE_NONE = 3
local CHARACTER_SELECTION_TYPE_CUSTOM = 4

local CHARACTER_SELECTION_MESSAGE = {
    [CHARACTER_SELECTION_TYPE_ALL] = 'Deselect All',
    [CHARACTER_SELECTION_TYPE_CURRENT] = 'Select All',
    [CHARACTER_SELECTION_TYPE_NONE] = 'Select Current',
    [CHARACTER_SELECTION_TYPE_CUSTOM] = 'Select All',
}

local function GetTextIf(selectionType)
    return CHARACTER_SELECTION_MESSAGE[selectionType]
end

function addon.InitializePlayerCharactersFilter(self, filterControl)
    local filter

    local numCharacters = GetNumCharacters()
    local entriesData = {}

    local function GetSelectionType()
        local numCharactersSelected = filter:GetNumSelectedEntries()
        -- Log('Characters selected: %d', numCharactersSelected)

        if numCharactersSelected == numCharacters then
            return CHARACTER_SELECTION_TYPE_ALL
        end

        if numCharactersSelected == 1 and self.filters.playerCharacters[GetCurrentCharacterId()] then
            return CHARACTER_SELECTION_TYPE_CURRENT
        end

        if numCharactersSelected == 0 then
            return CHARACTER_SELECTION_TYPE_NONE
        end

        return CHARACTER_SELECTION_TYPE_CUSTOM
    end

    for i = 1, numCharacters do
        local name, _, _, classId, _, _, characterId, _ = GetCharacterInfo(i)
        local classIcon = zo_iconFormatInheritColor(ZO_GetClassIcon(classId), 24, 24)
        local formattedName = zo_strformat('<<1>> <<2>>', classIcon, name)

        entriesData[i] = {
            text = formattedName,
            type = characterId,
        }
    end
    
    local function callback(newFilters)
        for characterId, _ in pairs(self.filters.playerCharacters) do
            self.filters.playerCharacters[characterId] = false
        end

        for _, characterId in ipairs(newFilters) do
            self.filters.playerCharacters[characterId] = true
        end

        self:Update()

        local selectButton = GetControl(filterControl, 'SelectButton')
        if selectButton then
            selectButton:SetText(GetTextIf(GetSelectionType()))
        end
    end

    -- local filterControl = GetControl(self.battlegroundsControl, 'FilterPlayerCharacters')
    filter = InitializeFilter(filterControl, entriesData, callback)

    filter:SetNoSelectionText('|cFF0000Select Character|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Character/$d Characters]>> Selected')

    for i, item in ipairs(filter.m_sortedItems) do
        -- Log('%d - %s', i, item.name)
        if self.filters.playerCharacters[item.filterType] then
            filter:SelectItem(item, true)
            -- Log('[B] Selecting %s', item.text)
        end
    end

    local function SelectCharacter(characterId)
        for i, item in ipairs(filter.m_sortedItems) do
            if item.filterType == characterId then
                filter:SelectItem(item, true)
                return
            end
        end
    end

    local function SelectUnselect(button)
        local selectionType = GetSelectionType()

        filter:ClearAllSelections()  -- seems it reverse selection if SelectItem called on selected item
        if selectionType == CHARACTER_SELECTION_TYPE_ALL then
            -- filter:ClearAllSelections()
            for i, item in ipairs(filter.m_sortedItems) do
                self.filters.playerCharacters[item.filterType] = false
            end
        elseif selectionType == CHARACTER_SELECTION_TYPE_CURRENT or selectionType == CHARACTER_SELECTION_TYPE_CUSTOM then
            -- filter:ClearAllSelections() 
            for i, item in ipairs(filter.m_sortedItems) do
                self.filters.playerCharacters[item.filterType] = true
                filter:SelectItem(item, true)
            end
        elseif selectionType == CHARACTER_SELECTION_TYPE_NONE then
            local currentCharacterId = GetCurrentCharacterId()
            self.filters.playerCharacters[currentCharacterId] = true
            SelectCharacter(currentCharacterId)
        end

        selectionType = GetSelectionType() -- TODO: optimize?
        -- Log('Selection type: %d, text to set: %s', selectionType, GetTextIf(selectionType))
        button:SetText(GetTextIf(selectionType))

        self:Update()
    end

    local selectButton = GetControl(filterControl, 'SelectButton')
    if selectButton then
        selectButton:SetHandler('OnMouseDown', SelectUnselect)
        selectButton:SetText(GetTextIf(GetSelectionType()))
    end
end

IPM_Shared = addon
