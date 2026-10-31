State = { players = {} }

local META = 'xsmedical'
local LIVE = { down = true, knockout = true, arrest = true, dead = true }

local function blank()
    return {
        status = 'alive', blood = 100.0, injuries = {}, relief = 0, reliefUntil = 0, opioid = 0.0,
        downAt = nil, bleedOutAt = nil, arrestAt = nil, rhythm = nil, respawnAt = nil, wakeAt = nil,
        cause = nil, lastCall = 0, nextId = 1, adrenalineAt = 0, dirty = false, savedAt = 0, bed = nil,
    }
end

function State.Get(src)
    src = tonumber(src)
    if not src then return blank() end
    local s = State.players[src]
    if not s then
        s = blank()
        State.players[src] = s
    end
    return s
end

function State.Peek(src)
    return State.players[tonumber(src) or -1]
end

function State.IsDown(src)
    local s = State.Peek(src)
    return s ~= nil and LIVE[s.status] == true
end

local function cleanInjury(raw, id)
    if type(raw) ~= 'table' then return nil end
    local part = tostring(raw.part or '')
    local valid = false
    for _, p in ipairs(Body.Parts) do if p == part then valid = true break end end
    if not valid then return nil end
    local treated = {}
    for _, key in ipairs({ 'bandage', 'tourniquet', 'gauze', 'splint', 'dressing' }) do
        if raw.treated and raw.treated[key] then treated[key] = true end
    end
    return {
        id = tonumber(raw.id) or id, part = part, kind = tostring(raw.kind or 'blunt'),
        sev = Util.Clamp(math.floor(tonumber(raw.sev) or 1), 1, 3), bleed = Util.Clamp(math.floor(tonumber(raw.bleed) or 0), 0, 3),
        bulletIn = raw.bulletIn == true, fracture = raw.fracture == true, internal = raw.internal == true,
        infected = raw.infected == true, openAt = tonumber(raw.openAt), treated = treated, at = tonumber(raw.at) or os.time(),
    }
end

function State.Load(src)
    local s = blank()
    local saved = Framework.GetMetaData(src, META)
    if type(saved) == 'table' then
        s.blood = Util.Clamp(tonumber(saved.blood) or 100, 1, 100)
        s.opioid = Util.Clamp(tonumber(saved.opioid) or 0, 0, 12)
        for _, raw in ipairs(saved.injuries or {}) do
            local injury = cleanInjury(raw, s.nextId)
            if injury and not (Body.Treated(injury) and Body.Done(injury)) then
                s.injuries[#s.injuries + 1] = injury
                s.nextId = math.max(s.nextId, injury.id) + 1
            end
        end
        if saved.status and LIVE[saved.status] then s.restoreDown = saved.status end
    end
    State.players[src] = s
    return s
end

function State.Save(src, force)
    local s = State.Peek(src)
    if not s then return end
    local now = os.time()
    if not force and (not s.dirty or now - (s.savedAt or 0) < 5) then return end
    local out = { status = s.status, blood = Util.Round(s.blood, 1), opioid = Util.Round(s.opioid, 1), injuries = {} }
    for i, injury in ipairs(s.injuries) do
        out.injuries[i] = {
            id = injury.id, part = injury.part, kind = injury.kind, sev = injury.sev, bleed = injury.bleed,
            bulletIn = injury.bulletIn or nil, fracture = injury.fracture or nil, internal = injury.internal or nil,
            infected = injury.infected or nil, openAt = injury.openAt, treated = injury.treated, at = injury.at,
        }
    end
    Framework.SetMetaData(src, META, out)
    s.dirty, s.savedAt = false, now
end

function State.Forget(src)
    State.Save(src, true)
    State.players[tonumber(src) or -1] = nil
    local bag = Player(src).state
    if bag.xsm ~= nil then bag:set('xsm', nil, true) end
end

local function relevant(s)
    return s.status ~= 'alive' or #s.injuries > 0 or s.blood < 99.5 or s.relief > 0 or s.opioid > 0.1 or s.bed ~= nil
end

function State.Relief(s)
    if s.reliefUntil and s.reliefUntil > os.time() then return s.relief end
    return 0
end

function State.Vitals(src, s)
    s = s or State.Get(src)
    return Vitals.Compute({
        status = s.status, blood = s.blood, injuries = s.injuries, relief = State.Relief(s),
        opioid = s.opioid, rhythm = s.rhythm,
    }, os.time(), src % 97)
end

function State.Public(src, s)
    s = s or State.Get(src)
    local now = os.time()
    local injuries = {}
    for i, injury in ipairs(s.injuries) do
        injuries[i] = {
            id = injury.id, part = injury.part, kind = injury.kind, sev = injury.sev, bleed = Body.ActiveBleed(injury),
            rawBleed = injury.bleed, bulletIn = injury.bulletIn, fracture = injury.fracture, internal = injury.internal,
            infected = injury.infected, treated = injury.treated, surgery = Body.NeedsSurgery(injury) == true,
        }
    end
    return {
        status = s.status, blood = Util.Round(s.blood, 0), injuries = injuries, vitals = State.Vitals(src, s),
        relief = State.Relief(s), opioid = Util.Round(s.opioid, 1),
        bleedOutIn = s.bleedOutAt and math.max(0, s.bleedOutAt - now) or nil,
        arrestLeft = s.arrestAt and math.max(0, s.arrestAt + (Config.Arrest.seconds or 240) - now) or nil,
        respawnIn = s.respawnAt and math.max(0, s.respawnAt - now) or nil,
        wakeIn = s.wakeAt and math.max(0, s.wakeAt - now) or nil,
        cause = s.cause, rhythm = s.rhythm, bed = s.bed,
        ems = s.status ~= 'alive' and #Framework.Medics(true) or nil,
    }
end

function State.Sync(src, s)
    s = s or State.Get(src)
    s.dirty = true
    local pub = State.Public(src, s)
    TriggerClientEvent('XS-Medical:client:state', src, pub)
    State.Broadcast(src, s, pub.vitals)
    if Patients and Patients.Touch then Patients.Touch(src) end
end

function State.Broadcast(src, s, vitals)
    local bag = Player(src).state
    if Compat and Compat.Bleed then Compat.Bleed(src, Body.WorstBleed(s.injuries)) end
    if not relevant(s) then
        if bag.xsm ~= nil then bag:set('xsm', nil, true) end
        return
    end
    vitals = vitals or State.Vitals(src, s)
    bag:set('xsm', {
        status = s.status, hr = vitals.hr, sys = vitals.sys, dia = vitals.dia, spo2 = vitals.spo2, resp = vitals.resp,
        temp = vitals.temp, rhythm = vitals.rhythm, avpu = vitals.avpu, pain = vitals.pain, blood = vitals.blood,
        acuity = vitals.acuity, alarms = vitals.alarms, bleeding = Body.WorstBleed(s.injuries),
    }, true)
end

local function findInjury(s, part, kind)
    for _, injury in ipairs(s.injuries) do
        if injury.part == part and injury.kind == kind then return injury end
    end
    return nil
end

function State.AddInjury(s, part, kind, sev, extra)
    extra = extra or {}
    local injury = findInjury(s, part, kind)
    local count = 0
    for _, i in ipairs(s.injuries) do if i.part == part then count = count + 1 end end
    if injury and (count >= (Config.Damage.maxPerPart or 3) or kind == 'concussion' or kind == 'burn' or kind == 'blunt') then
        injury.sev = math.min(3, math.max(injury.sev, sev) + (sev >= 2 and 1 or 0))
        injury.bleed = math.max(injury.bleed, extra.bleed or 0)
        if extra.bleed and extra.bleed > 0 then injury.treated.bandage, injury.treated.gauze = nil, nil end
        injury.bulletIn = injury.bulletIn or extra.bulletIn == true
        injury.fracture = injury.fracture or extra.fracture == true
        injury.internal = injury.internal or extra.internal == true
        if extra.fracture then injury.treated.splint = nil end
        injury.at = os.time()
        return injury
    end
    injury = {
        id = s.nextId, part = part, kind = kind, sev = Util.Clamp(sev, 1, 3), bleed = extra.bleed or 0,
        bulletIn = extra.bulletIn == true, fracture = extra.fracture == true, internal = extra.internal == true,
        infected = false, openAt = (extra.bleed or 0) > 0 and os.time() or nil, treated = {}, at = os.time(),
    }
    s.nextId = s.nextId + 1
    s.injuries[#s.injuries + 1] = injury
    return injury
end

function State.RemoveInjury(s, id)
    for i, injury in ipairs(s.injuries) do
        if injury.id == id then
            table.remove(s.injuries, i)
            return true
        end
    end
    return false
end

function State.Close(src, s, injury)
    if not State.RemoveInjury(s, injury.id) then return false end
    if Patients and Patients.Cleared then
        Patients.Cleared(src, Text('log_wound_done', { part = Text('part_' .. injury.part), kind = Text('kind_' .. injury.kind) }))
    end
    return true
end

function State.Sweep(src, s)
    local closed = 0
    for i = #s.injuries, 1, -1 do
        local injury = s.injuries[i]
        if Body.Treated(injury) and Body.Done(injury) and State.Close(src, s, injury) then closed = closed + 1 end
    end
    return closed
end

function State.FindInjury(s, id)
    id = tonumber(id)
    for _, injury in ipairs(s.injuries) do
        if injury.id == id then return injury end
    end
    return nil
end

function State.Heal(src, opts)
    opts = opts or {}
    local s = State.Get(src)
    s.injuries = opts.keepInjuries and s.injuries or {}
    s.blood = opts.blood or 100.0
    s.opioid = opts.keepInjuries and s.opioid or 0.0
    if not opts.keepInjuries then s.relief, s.reliefUntil = 0, 0 end
    State.Sync(src, s)
end

local function chance(p)
    return math.random() < (tonumber(p) or 0)
end

function State.Hit(src, hit)
    local s = State.Get(src)
    if Standdown.Active(src) then return end
    local cause = tostring(hit.cause or 'blunt')
    if cause == 'ignore' or cause == 'stun' or cause == 'gas' or cause == 'drown' then return end

    local part = tostring(hit.part or 'torso')
    local known = false
    for _, p in ipairs(Body.Parts) do if p == part then known = true break end end
    if not known then part = 'torso' end

    local amount = Util.Clamp(tonumber(hit.amount) or 0, 0, 400)
    if amount < (Config.Damage.ignoreBelow or 3) and not hit.fatal then return end
    local sev = amount >= 40 and 3 or (amount >= 15 and 2 or 1)
    local D = Config.Damage
    local core = Body.Core[part]
    local downNow = false

    if cause == 'gunshot' then
        if core and hit.armour and chance(D.armourStops) then
            State.AddInjury(s, part, 'blunt', 1)
        else
            local bleed = 2
            if part == 'head' then bleed = 3 elseif Body.Limbs[part] and sev >= 2 then bleed = 3 end
            local stays = core and (D.bulletStaysIn[part] or D.bulletStaysIn.torso) or (Body.Limbs[part] and D.bulletStaysIn.limb or 0)
            State.AddInjury(s, part, 'gunshot', sev, {
                bleed = bleed, bulletIn = chance(stays),
                fracture = Body.Limbs[part] and chance(D.fracture.gunshot) or false,
                internal = core and sev >= 2 and chance(0.5) or false,
            })
            if part == 'head' and D.headshotDowns then downNow = true end
        end
    elseif cause == 'stab' then
        State.AddInjury(s, part, 'stab', sev, { bleed = sev >= 2 and 2 or 1, internal = core and sev >= 2 and chance(0.4) or false })
    elseif cause == 'cut' or cause == 'bite' then
        State.AddInjury(s, part, 'cut', sev, { bleed = sev >= 3 and 2 or 1 })
    elseif cause == 'blunt' or cause == 'fist' then
        if part == 'head' and (sev >= 2 or cause == 'blunt') then
            State.AddInjury(s, 'head', 'concussion', sev)
        else
            local fracture = Body.Limbs[part] and chance((D.fracture.blunt or 0) * (cause == 'fist' and 0.4 or 1)) or false
            State.AddInjury(s, part, 'blunt', sev, { fracture = fracture, internal = core and chance(D.internal.blunt) or false })
        end
    elseif cause == 'fall' then
        local legs = amount >= 30 and { 'lleg', 'rleg' } or { Body.Legs[part] and part or (math.random() < 0.5 and 'lleg' or 'rleg') }
        for _, leg in ipairs(legs) do
            State.AddInjury(s, leg, 'blunt', sev, { fracture = chance((D.fracture.fall or 0) * sev / 2) })
        end
        if amount >= 60 then State.AddInjury(s, 'head', 'concussion', 2) end
    elseif cause == 'vehicle' then
        State.AddInjury(s, part, 'crush', sev, {
            bleed = sev >= 3 and 1 or 0, fracture = Body.Limbs[part] and chance(D.fracture.vehicle) or false,
            internal = core and chance(D.internal.vehicle) or false,
        })
        if sev >= 3 then State.AddInjury(s, 'head', 'concussion', 2) end
    elseif cause == 'burn' then
        State.AddInjury(s, part, 'burn', sev)
    elseif cause == 'blast' then
        State.AddInjury(s, part, 'burn', sev)
        State.AddInjury(s, core and part or 'torso', 'cut', math.max(1, sev - 1), { bleed = 1, internal = chance(D.internal.blast) })
        if Body.Limbs[part] and chance(D.fracture.blast) then State.AddInjury(s, part, 'blunt', sev, { fracture = true }) end
    else
        State.AddInjury(s, part, 'blunt', sev)
    end

    s.lastCause = cause

    if LIVE[s.status] then
        if s.status ~= 'arrest' and s.status ~= 'dead' and Config.Down.finishable and (hit.fatal or (sev >= 2 and cause ~= 'fist')) then
            Down.Arrest(src, 'finished')
            return
        end
        if s.status == 'down' then Down.Retime(src) end
    elseif downNow then
        Down.Start(src, cause)
        return
    end

    State.Sync(src, s)
end

local function tickPlayer(src, s, now)
    local changed = false
    local B = Config.Bleeding

    local bleed = 0
    for _, injury in ipairs(s.injuries) do
        local level = Body.ActiveBleed(injury)
        if level > 0 then bleed = bleed + (B.rates[level] or 0) end
        if Config.Infection.enabled and not injury.infected and injury.openAt and level == 0 and not injury.treated.bandage
            and not injury.treated.gauze and not injury.treated.dressing and now - injury.openAt > (Config.Infection.afterMinutes or 30) * 60 then
            injury.infected = true
            changed = true
        end
    end

    if s.status == 'down' or s.status == 'knockout' then bleed = bleed * 0.5 end
    if s.status == 'arrest' or s.status == 'dead' then bleed = 0 end

    if bleed > 0 then
        s.blood = math.max(0, s.blood - bleed)
        changed = true
    elseif s.blood < 100 and s.status == 'alive' then
        s.blood = math.min(100, s.blood + (B.regenPerMinute or 1.5) / 60)
    end

    if s.opioid > 0 then s.opioid = math.max(0, s.opioid - 1 / 180) end
    if s.reliefUntil > 0 and s.reliefUntil <= now then
        s.relief, s.reliefUntil = 0, 0
        changed = true
    end

    if s.status == 'alive' and s.blood <= (B.collapseAt or 55) then
        Down.Start(src, 'blood')
        return
    end

    if s.status == 'down' and s.bleedOutAt and now >= s.bleedOutAt then
        Down.Arrest(src, 'bleedout')
        return
    end

    if s.status == 'knockout' and s.wakeAt and now >= s.wakeAt then
        Down.Wake(src)
        return
    end

    if s.status == 'arrest' and s.arrestAt then
        local A = Config.Arrest
        if s.rhythm == 'vf' and now - s.arrestAt >= (A.shockable or 120) then
            s.rhythm = 'asystole'
            changed = true
        end
        if now - s.arrestAt >= (A.seconds or 240) then
            Down.Dead(src)
            return
        end
    end

    if changed then s.dirty = true end
    return changed
end

CreateThread(function()
    local beat = 0
    while true do
        Wait(1000)
        beat = beat + 1
        local now = os.time()
        for src, s in pairs(State.players) do
            if GetPlayerPing(src) == 0 and not GetPlayerName(src) then
                State.players[src] = nil
            elseif relevant(s) then
                local ok, err = pcall(tickPlayer, src, s, now)
                if not ok then print(('^1[XS-Medical]^0 tick failed for %s: %s'):format(src, tostring(err))) end
                if beat % 2 == 0 and State.players[src] then State.Broadcast(src, s) end
                if beat % 5 == 0 and State.players[src] then
                    TriggerClientEvent('XS-Medical:client:state', src, State.Public(src, s))
                    State.Save(src)
                end
            end
        end
    end
end)
