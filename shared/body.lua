Body = {}

Body.Parts = { 'head', 'torso', 'stomach', 'larm', 'rarm', 'lleg', 'rleg' }

Body.Limbs = { larm = true, rarm = true, lleg = true, rleg = true }
Body.Legs = { lleg = true, rleg = true }
Body.Arms = { larm = true, rarm = true }
Body.Core = { torso = true, stomach = true }

Body.Bones = {
    [31086] = 'head', [12844] = 'head', [39317] = 'head', [35731] = 'head', [46240] = 'head',
    [24818] = 'torso', [24817] = 'torso', [64729] = 'torso', [10706] = 'torso', [57597] = 'stomach',
    [24816] = 'stomach', [23553] = 'stomach', [11816] = 'stomach', [0] = 'torso',
    [45509] = 'larm', [61163] = 'larm', [18905] = 'larm', [5232] = 'larm', [61007] = 'larm', [22711] = 'larm', [60309] = 'larm', [36029] = 'larm',
    [40269] = 'rarm', [28252] = 'rarm', [57005] = 'rarm', [37119] = 'rarm', [43810] = 'rarm', [2992] = 'rarm', [28422] = 'rarm', [6286] = 'rarm',
    [58271] = 'lleg', [63931] = 'lleg', [14201] = 'lleg', [2108] = 'lleg', [23639] = 'lleg', [46078] = 'lleg',
    [51826] = 'rleg', [36864] = 'rleg', [52301] = 'rleg', [20781] = 'rleg', [6442] = 'rleg', [16335] = 'rleg',
}

function Body.PartFromOffset(offset)
    if not offset then return 'torso' end
    local x, z = offset.x or 0.0, offset.z or 0.0
    if z > 0.52 then return 'head' end
    if z > 0.05 then
        if math.abs(x) > 0.24 then return x < 0 and 'larm' or 'rarm' end
        return z > 0.28 and 'torso' or 'stomach'
    end
    if z > -0.12 then
        if math.abs(x) > 0.3 then return x < 0 and 'larm' or 'rarm' end
        return 'stomach'
    end
    return x < 0 and 'lleg' or 'rleg'
end

Body.Kinds = { 'gunshot', 'stab', 'cut', 'blunt', 'burn', 'crush', 'concussion' }

local SHARP = {
    'WEAPON_KNIFE', 'WEAPON_DAGGER', 'WEAPON_MACHETE', 'WEAPON_SWITCHBLADE', 'WEAPON_BOTTLE',
    'WEAPON_HATCHET', 'WEAPON_BATTLEAXE', 'WEAPON_STONE_HATCHET',
}
local STAB = { WEAPON_KNIFE = true, WEAPON_DAGGER = true, WEAPON_SWITCHBLADE = true, WEAPON_BOTTLE = true }

local GROUPS = {
    GROUP_PISTOL = 'gunshot', GROUP_SMG = 'gunshot', GROUP_RIFLE = 'gunshot', GROUP_MG = 'gunshot',
    GROUP_SHOTGUN = 'gunshot', GROUP_SNIPER = 'gunshot', GROUP_HEAVY = 'blast', GROUP_THROWN = 'blast',
    GROUP_MELEE = 'blunt', GROUP_UNARMED = 'fist', GROUP_STUNGUN = 'stun', GROUP_PETROLCAN = 'burn',
}

local SPECIAL = {
    WEAPON_FALL = 'fall', WEAPON_RUN_OVER_BY_CAR = 'vehicle', WEAPON_RAMMED_BY_CAR = 'vehicle',
    WEAPON_FIRE = 'burn', WEAPON_MOLOTOV = 'burn', WEAPON_FLARE = 'burn', WEAPON_ELECTRIC_FENCE = 'burn',
    WEAPON_EXPLOSION = 'blast', WEAPON_HELI_CRASH = 'vehicle', WEAPON_GRENADE = 'blast', WEAPON_STICKYBOMB = 'blast',
    WEAPON_PIPEBOMB = 'blast', WEAPON_PROXMINE = 'blast', WEAPON_RPG = 'blast', WEAPON_GRENADELAUNCHER = 'blast',
    WEAPON_DROWNING = 'drown', WEAPON_DROWNING_IN_VEHICLE = 'drown', WEAPON_ANIMAL = 'bite', WEAPON_COUGAR = 'bite',
    WEAPON_BARBED_WIRE = 'cut', WEAPON_UNARMED = 'fist', WEAPON_STUNGUN = 'stun', WEAPON_STUNGUN_MP = 'stun',
    WEAPON_BLEEDING = 'ignore', WEAPON_EXHAUSTION = 'ignore', WEAPON_HIT_BY_WATER_CANNON = 'blunt',
    WEAPON_BZGAS = 'gas', WEAPON_SMOKEGRENADE = 'gas', WEAPON_SNOWBALL = 'ignore', WEAPON_BALL = 'ignore',
}

local special, sharp, groups

local function build()
    special, sharp, groups = {}, {}, {}
    for name, kind in pairs(SPECIAL) do special[Util.Hash(name)] = kind end
    for _, name in ipairs(SHARP) do sharp[Util.Hash(name)] = STAB[name] and 'stab' or 'cut' end
    for name, kind in pairs(GROUPS) do groups[Util.Hash(name)] = kind end
end

function Body.Cause(weapon, group)
    if not special then build() end
    weapon = Util.U32(weapon)
    if special[weapon] then return special[weapon] end
    if sharp[weapon] then return sharp[weapon] end
    if group then
        local kind = groups[Util.U32(group)]
        if kind then return kind end
    end
    return 'blunt'
end

function Body.IsFirearm(cause)
    return cause == 'gunshot'
end

Body.Severity = { 'minor', 'serious', 'critical' }

function Body.WorstBleed(injuries)
    local worst = 0
    for _, injury in ipairs(injuries or {}) do
        local level = Body.ActiveBleed(injury)
        if level > worst then worst = level end
    end
    return worst
end

function Body.ActiveBleed(injury)
    if not injury then return 0 end
    if injury.treated and injury.treated.tourniquet then return 0 end
    return math.max(0, math.floor(tonumber(injury.bleed) or 0))
end

function Body.NeedsSurgery(injury)
    return injury and (injury.bulletIn == true or injury.internal == true or (injury.fracture == true and (injury.sev or 1) >= 3))
end

function Body.Painful(injury)
    if not injury then return 0 end
    local base = ({ gunshot = 3, stab = 3, cut = 1, blunt = 1, burn = 3, crush = 3, concussion = 2 })[injury.kind] or 1
    local pain = base * (injury.sev or 1)
    if injury.fracture then pain = pain + (injury.treated and injury.treated.splint and 1 or 3) end
    if injury.treated and (injury.treated.bandage or injury.treated.gauze or injury.treated.dressing) then pain = pain - 1 end
    if injury.infected then pain = pain + 2 end
    return math.max(0, pain)
end

function Body.Pain(injuries, relief)
    local total = 0
    for _, injury in ipairs(injuries or {}) do total = total + Body.Painful(injury) end
    total = math.min(10, math.floor(total * 0.7 + 0.5))
    return math.max(0, total - math.floor(tonumber(relief) or 0))
end

function Body.Summary(injuries)
    local parts = {}
    for _, injury in ipairs(injuries or {}) do
        parts[injury.part] = parts[injury.part] or { part = injury.part, worst = 0, bleed = 0 }
        local p = parts[injury.part]
        p.worst = math.max(p.worst, injury.sev or 1)
        p.bleed = math.max(p.bleed, Body.ActiveBleed(injury))
        if injury.fracture then p.fracture = true end
        if Body.NeedsSurgery(injury) then p.surgery = true end
    end
    return parts
end
