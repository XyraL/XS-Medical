Treat = { pending = {} }

local ACTIONS = {
    cpr = { seconds = 10, anyone = true, self = false },
    checkid = { seconds = 3, anyone = false, self = false },
    examine = { seconds = 2, anyone = true, self = true },
}

local OPEN = { gunshot = true, stab = true, cut = true, crush = true }

local function supplyOf(key)
    local s = Config.Supplies[key]
    if s then return s, false end
    local a = ACTIONS[key]
    if a then return a, true end
    return nil
end

local function near(a, b, max)
    if a == b then return true end
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= (max or 3.0)
end

local function bestInjury(s, test, id)
    if id then
        local injury = State.FindInjury(s, id)
        if injury and test(injury) then return injury end
    end
    local best, score = nil, -1
    for _, injury in ipairs(s.injuries) do
        if test(injury) then
            local value = (injury.bleed or 0) * 10 + Body.ActiveBleed(injury) * 5 + (injury.sev or 1)
            if value > score then best, score = injury, value end
        end
    end
    return best
end

local TESTS = {
    bandage = function(i) return (i.bleed or 0) > 0 and OPEN[i.kind] and not i.treated.bandage end,
    tourniquet = function(i) return Body.Limbs[i.part] and Body.ActiveBleed(i) > 0 end,
    gauze = function(i) return (i.bleed or 0) > 0 and not i.treated.gauze end,
    splint = function(i) return Body.Limbs[i.part] and i.fracture and not i.treated.splint end,
    burncream = function(i) return i.kind == 'burn' and not i.treated.dressing end,
}

local REFUSE = {
    bandage = 'err_nothing_bandage', tourniquet = 'err_nothing_tourniquet', gauze = 'err_nothing_bleeding',
    splint = 'err_nothing_splint', burncream = 'err_nothing_burn',
}

local function check(src, target, key, injuryId)
    local supply, isAction = supplyOf(key)
    if not supply then return false, 'err_unknown_supply' end
    if not GetPlayerName(target) then return false, 'err_no_patient' end
    if not near(src, target, 3.5) then return false, 'err_too_far' end

    local medic = Framework.IsMedicSource(src)
    if target == src and not supply.self then return false, 'err_not_on_self' end
    if not supply.anyone and not medic then return false, 'err_medics_only' end

    if not isAction and supply.item and not Inventory.Has(src, supply.item, 1) then
        return false, 'err_no_item', { item = Inventory.Label(supply.item) }
    end

    local s = State.Get(target)

    if TESTS[key] then
        if s.status == 'dead' then return false, 'err_patient_gone' end
        local injury = bestInjury(s, TESTS[key], injuryId)
        if not injury then return false, REFUSE[key] end
        return true, nil, nil, supply, injury
    end

    if key == 'painkillers' or key == 'morphine' or key == 'ifaks' then
        if s.status == 'arrest' or s.status == 'dead' then return false, 'err_patient_gone' end
    elseif key == 'saline' then
        if s.status == 'dead' then return false, 'err_patient_gone' end
        if s.blood >= 99 then return false, 'err_blood_full' end
    elseif key == 'adrenaline' then
        if s.status == 'down' or s.status == 'knockout' then
            if Body.WorstBleed(s.injuries) > 0 then return false, 'err_still_bleeding' end
        elseif s.status ~= 'arrest' then
            return false, 'err_adrenaline_awake'
        end
    elseif key == 'defibrillator' then
        if s.status ~= 'arrest' then return false, 'err_has_pulse' end
        if s.rhythm ~= 'vf' then return false, 'err_not_shockable' end
    elseif key == 'firstaid' then
        if s.status == 'arrest' or s.status == 'dead' then return false, 'err_patient_gone' end
        if (s.status == 'down' or s.status == 'knockout') and Body.WorstBleed(s.injuries) > 1 then return false, 'err_still_bleeding' end
    elseif key == 'cpr' then
        if s.status ~= 'arrest' then return false, 'err_has_pulse' end
    elseif key == 'checkid' then
        if not Patients.Unknown(target) then return false, 'err_already_known' end
    end

    return true, nil, nil, supply, nil
end

local function relieve(s, amount, minutes)
    local now = os.time()
    local untilAt = now + math.floor((minutes or 5) * 60)
    if (s.reliefUntil or 0) > now then
        s.relief = math.max(s.relief, amount)
        s.reliefUntil = math.max(s.reliefUntil, untilAt)
    else
        s.relief, s.reliefUntil = amount, untilAt
    end
end

local function apply(src, target, key, supply, injury)
    local s = State.Get(target)
    local note

    if key == 'bandage' then
        injury.bleed = math.max(0, injury.bleed - (injury.bleed >= 3 and 1 or 2))
        injury.treated.bandage = true
        note = Body.ActiveBleed(injury) > 0 and 'treat_bandage_partial' or 'treat_bandage'
    elseif key == 'tourniquet' then
        injury.treated.tourniquet = true
        note = 'treat_tourniquet'
    elseif key == 'gauze' then
        injury.bleed = math.max(0, injury.bleed - 2)
        injury.treated.gauze = true
        note = 'treat_gauze'
    elseif key == 'splint' then
        injury.treated.splint = true
        note = 'treat_splint'
    elseif key == 'burncream' then
        injury.treated.dressing = true
        note = 'treat_burn'
    elseif key == 'painkillers' then
        relieve(s, supply.relief or 2, supply.minutes or 6)
        note = 'treat_painkillers'
    elseif key == 'morphine' then
        relieve(s, supply.relief or 6, supply.minutes or 12)
        s.opioid = math.min(12, s.opioid + (supply.opioid or 3))
        note = 'treat_morphine'
    elseif key == 'saline' then
        s.blood = math.min(100, s.blood + (supply.blood or 30))
        note = 'treat_saline'
    elseif key == 'ifaks' then
        local worst = bestInjury(s, function(i) return Body.ActiveBleed(i) > 0 and Body.ActiveBleed(i) < 3 end)
        if worst then
            worst.bleed = math.max(0, worst.bleed - 1)
            worst.treated.bandage = true
            if Body.Done(worst) then State.Close(target, s, worst) end
        end
        relieve(s, supply.relief or 2, supply.minutes or 4)
        TriggerClientEvent('XS-Medical:client:addHealth', target, supply.heal or 25)
        note = 'treat_ifaks'
    elseif key == 'firstaid' then
        for n = #s.injuries, 1, -1 do
            local i = s.injuries[n]
            if Body.ActiveBleed(i) == 1 then
                i.bleed = 0
                i.treated.bandage = true
                if Body.Done(i) then State.Close(target, s, i) end
            end
        end
        if (s.status == 'down' or s.status == 'knockout') and supply.revives then
            Down.Revive(target, 'self', src)
            note = 'treat_firstaid_revive'
        else
            TriggerClientEvent('XS-Medical:client:addHealth', target, 20)
            note = 'treat_firstaid'
        end
    elseif key == 'adrenaline' then
        if s.status == 'arrest' then
            s.adrenalineAt = os.time()
            note = 'treat_adrenaline_arrest'
        else
            Down.Revive(target, 'field', src)
            note = 'treat_adrenaline_revive'
        end
    elseif key == 'defibrillator' then
        local bonus = (os.time() - (s.adrenalineAt or 0) < 120) and (Config.Arrest.adrenalineBonus or 0.2) or 0
        if math.random() < (Config.Arrest.shockChance or 0.65) + bonus then
            Down.Restart(target, src)
            note = 'treat_shock_ok'
        else
            note = 'treat_shock_fail'
        end
    elseif key == 'cpr' then
        local bonus = (os.time() - (s.adrenalineAt or 0) < 120) and (Config.Arrest.adrenalineBonus or 0.2) or 0
        s.arrestAt = math.min(os.time(), (s.arrestAt or os.time()) + 15)
        if math.random() < (Config.Arrest.cprChance or 0.2) + bonus then
            Down.Restart(target, src)
            note = 'treat_cpr_ok'
        else
            note = 'treat_cpr_continue'
        end
    elseif key == 'checkid' then
        Patients.Identify(target, src)
        note = 'treat_checkid'
    elseif key == 'examine' then
        note = nil
    end

    if injury and TESTS[key] and Body.Done(injury) then State.Close(target, s, injury) end
    if s.status == 'down' and (TESTS[key] or key == 'gauze') then Down.Retime(target) end

    if note then Patients.Log(target, Text(note, { part = Text('part_' .. (injury and injury.part or 'torso')) }), src, key) end
    State.Sync(target, s)
    return note
end

lib.callback.register('XS-Medical:server:treatBegin', function(src, data)
    data = type(data) == 'table' and data or {}
    local target = tonumber(data.target) or src
    local key = tostring(data.supply or '')
    local ok, err, vars, supply, injury = check(src, target, key, tonumber(data.injury))
    if not ok then return false, Text(err, vars) end
    Treat.pending[src] = { target = target, key = key, injury = injury and injury.id or nil, at = GetGameTimer(), seconds = supply.seconds or 5 }
    if target ~= src and Framework.IsMedicSource(src) then Patients.Attend(target, src) end
    return true, { seconds = supply.seconds or 5, label = Text('supply_' .. key), key = key }
end)

lib.callback.register('XS-Medical:server:treatEnd', function(src, finished)
    local job = Treat.pending[src]
    Treat.pending[src] = nil
    if not job or finished ~= true then return false end
    if GetGameTimer() - job.at < job.seconds * 1000 * 0.75 then return false, Text('err_too_fast') end

    local ok, err, vars, supply, injury = check(src, job.target, job.key, job.injury)
    if not ok then return false, Text(err, vars) end

    if supply.item and supply.consume ~= false and Config.Supplies[job.key] then
        if not Inventory.Remove(src, supply.item, 1) then return false, Text('err_no_item', { item = Inventory.Label(supply.item) }) end
        TriggerClientEvent('XS-Medical:client:invalidateInventory', src)
    end

    local note = apply(src, job.target, job.key, supply, injury)
    if job.target ~= src then
        TriggerClientEvent('XS-Medical:client:treated', job.target, note and Text(note, { part = Text('part_' .. (injury and injury.part or 'torso')) }) or nil)
    end
    return true, note and Text(note, { part = Text('part_' .. (injury and injury.part or 'torso')) }) or nil
end)

lib.callback.register('XS-Medical:server:glance', function(src, target)
    target = tonumber(target)
    if not target or not GetPlayerName(target) or not near(src, target, 4.0) then return nil end
    local s = State.Get(target)
    local lines = {}
    if s.status == 'arrest' or s.status == 'dead' then
        lines[#lines + 1] = Text('glance_no_breath')
    elseif s.status == 'down' or s.status == 'knockout' then
        lines[#lines + 1] = Text('glance_unconscious')
    end
    for _, injury in ipairs(s.injuries) do
        local part = Text('part_' .. injury.part)
        local level = Body.ActiveBleed(injury)
        if level >= 2 then
            lines[#lines + 1] = Text('glance_bleeding_heavy', { part = part })
        elseif level == 1 then
            lines[#lines + 1] = Text('glance_bleeding', { part = part })
        end
        if injury.fracture and not injury.treated.splint then lines[#lines + 1] = Text('glance_broken', { part = part }) end
        if injury.kind == 'burn' then lines[#lines + 1] = Text('glance_burnt', { part = part }) end
        if #lines >= 8 then break end
    end
    return { header = Text('glance_title'), lines = lines }
end)

AddEventHandler('playerDropped', function()
    Treat.pending[source] = nil
end)
