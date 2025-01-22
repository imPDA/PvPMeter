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

IPM_Shared = addon
