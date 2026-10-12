Down = {}

local function bleedOutFor(s)
    local list = Config.Down.bleedOut or { 600, 420, 300, 180 }
    return list[Body.WorstBleed(s.injuries) + 1] or list[#list]
end

local function medicsOnDuty()
    return #Framework.Medics(true)
end

local function respawnDelay()
    local R = Config.Down.respawnAfter or {}
    return medicsOnDuty() > 0 and (R.ems or 300) or (R.noEms or 90)
end

local function knockoutCause(s, cause)
    local K = Config.Down.knockout or {}
    return K.enabled and cause == 'fist' and Body.WorstBleed(s.injuries) == 0
end

local function scheduleAutoCall(src, downAt)
    local A = Config.Down.autoCall or {}
    if not A.enabled or math.random() > (A.chance or 0) then return end
    local low, high = (A.delay or { 20, 50 })[1] or 20, (A.delay or { 20, 50 })[2] or 50
    SetTimeout(math.random(low, high) * 1000, function()
        local s = State.Peek(src)
        if not s or s.downAt ~= downAt or s.status == 'alive' or s.called then return end
        Calls.Create({ src = src, kind = 'witness', priority = 1 })
        s.called = true
    end)
end

function Down.Start(src, cause)
    local s = State.Get(src)
    if s.status ~= 'alive' then return false end
    if Standdown.Active(src) then return false end
    local now = os.time()
    s.cause = cause or s.lastCause or 'unknown'
    s.downAt, s.called = now, false
    s.rhythm, s.arrestAt = nil, nil
    s.respawnAt = now + respawnDelay()
    if knockoutCause(s, cause) then
        s.status = 'knockout'
        s.wakeAt = now + ((Config.Down.knockout or {}).seconds or 40)
        s.bleedOutAt = nil
    else
        s.status = 'down'
        s.wakeAt = nil
        s.bleedOutAt = now + bleedOutFor(s)
        scheduleAutoCall(src, now)
    end
    Compat.Status(src, s.status)
    State.Sync(src, s)
    TriggerClientEvent('XS-Medical:client:down', src, State.Public(src, s))
    Patients.Downed(src)
    return true
end

function Down.Retime(src)
    local s = State.Get(src)
    if s.status ~= 'down' then return end
    local now = os.time()
    local fresh = now + bleedOutFor(s)
    if not s.bleedOutAt or fresh > s.bleedOutAt + 5 and Body.WorstBleed(s.injuries) < (s.lastWorst or 3) then
        s.bleedOutAt = fresh
    else
        s.bleedOutAt = math.min(s.bleedOutAt, fresh)
    end
    s.lastWorst = Body.WorstBleed(s.injuries)
    State.Sync(src, s)
    TriggerClientEvent('XS-Medical:client:down', src, State.Public(src, s))
end

function Down.Arrest(src, reason)
    local s = State.Get(src)
    if s.status == 'arrest' or s.status == 'dead' then return end
    local now = os.time()
    if s.status == 'alive' then
        s.downAt = now
        s.respawnAt = now + respawnDelay()
    end
    s.status = 'arrest'
    s.arrestAt = now
    s.rhythm = 'vf'
    s.bleedOutAt, s.wakeAt = nil, nil
    s.cause = s.cause or reason
    Compat.Status(src, 'arrest')
    State.Sync(src, s)
    TriggerClientEvent('XS-Medical:client:down', src, State.Public(src, s))
    Patients.Downed(src)
end

function Down.Dead(src)
    local s = State.Get(src)
    if s.status == 'dead' then return end
    s.status = 'dead'
    s.rhythm = 'asystole'
    s.bleedOutAt = nil
    Compat.Status(src, 'dead')
    State.Sync(src, s)
    TriggerClientEvent('XS-Medical:client:down', src, State.Public(src, s))
    Records.Log(Framework.GetCitizenId(src), 'death', Text('log_died'), { cause = s.cause }, nil)
end

function Down.Restart(src, by)
    local s = State.Get(src)
    if s.status ~= 'arrest' then return false end
    local now = os.time()
    s.status = 'down'
    s.rhythm, s.arrestAt = nil, nil
    s.bleedOutAt = now + bleedOutFor(s)
    s.lastWorst = Body.WorstBleed(s.injuries)
    Compat.Status(src, 'down')
    State.Sync(src, s)
    TriggerClientEvent('XS-Medical:client:down', src, State.Public(src, s))
    Patients.Log(src, Text('log_rosc'), by)
    return true
end

local HEALTH = { full = 200, field = 150, self = 130, wake = 140 }

function Down.Revive(src, mode, by)
    local s = State.Get(src)
    mode = mode or 'full'
    if mode == 'full' then
        s.injuries, s.blood, s.iv, s.opioid = {}, 100.0, nil, 0.0
        s.relief, s.reliefUntil = 0, 0
    else
        s.blood = math.max(s.blood, mode == 'field' and 62 or 58)
    end
    local was = s.status
    s.status = 'alive'
    s.downAt, s.bleedOutAt, s.arrestAt, s.rhythm, s.respawnAt, s.wakeAt, s.cause, s.called = nil, nil, nil, nil, nil, nil, nil, false
    Compat.Status(src, 'alive')
    State.Sync(src, s)
    TriggerClientEvent('XS-Medical:client:revived', src, { mode = mode, health = HEALTH[mode] or 150, was = was })
    if was ~= 'alive' then Patients.Log(src, Text('log_revived'), by) end
    return true
end

function Down.Wake(src)
    local s = State.Get(src)
    if s.status ~= 'knockout' then return end
    s.status = 'alive'
    s.downAt, s.wakeAt, s.respawnAt, s.cause = nil, nil, nil, nil
    Compat.Status(src, 'alive')
    State.Sync(src, s)
    TriggerClientEvent('XS-Medical:client:revived', src, { mode = 'wake', health = HEALTH.wake, was = 'knockout' })
end

function Down.Respawn(src)
    local s = State.Get(src)
    if s.status == 'alive' then return false, 'err_not_down' end
    if s.respawnAt and s.respawnAt > os.time() then return false, 'err_respawn_wait' end
    if not Compat.RunHooks('respawn', { source = src }) then return false, 'err_cannot_now' end

    local R = Config.Respawn
    local bill = math.floor(tonumber(R.bill) or 0)
    if bill > 0 then
        local paid = Framework.Charge(src, bill, R.account or 'bank', 'hospital-bill')
        if paid then
            Banking.Deposit((Config.Jobs or {}).society or 'ambulance', bill, 'Hospital bill')
        else
            Framework.Notify(src, Text('bill_unpaid', { amount = bill }), 'error')
        end
    end

    if R.wipeInventory then Inventory.Clear(src, R.keepItems or {}) end

    local cid = Framework.GetCitizenId(src)
    Records.Log(cid, 'respawn', Text('log_respawned'), { cause = s.cause }, nil)

    s.injuries, s.blood, s.iv, s.opioid, s.relief, s.reliefUntil = {}, 100.0, nil, 0.0, 0, 0
    s.status = 'alive'
    s.downAt, s.bleedOutAt, s.arrestAt, s.rhythm, s.respawnAt, s.wakeAt, s.cause, s.called = nil, nil, nil, nil, nil, nil, nil, false
    Compat.Status(src, 'alive')
    Framework.RestoreNeeds(src)
    State.Sync(src, s)

    local spot = Hospitals.RespawnSpot(src)
    TriggerClientEvent('XS-Medical:client:respawn', src, spot)
    if spot.jail then
        SetTimeout(4000, function()
            if GetPlayerName(src) then TriggerClientEvent('prison:client:Enter', src, spot.jail) end
        end)
    end
    TriggerEvent('qbx_medical:server:playerRespawned', src)
    Calls.ClearFor(src)
    return true
end

function Down.CallForHelp(src, message)
    local s = State.Get(src)
    local now = os.time()
    if now - (s.lastCall or 0) < (Config.Down.callCooldown or 45) then
        return false, 'err_call_cooldown', (Config.Down.callCooldown or 45) - (now - s.lastCall)
    end
    s.lastCall, s.called = now, true
    Calls.Create({ src = src, kind = s.status == 'alive' and 'request' or 'down', message = message, priority = s.status == 'alive' and 2 or 1 })
    return true
end

lib.callback.register('XS-Medical:server:fatal', function(src, info)
    info = type(info) == 'table' and info or {}
    if Standdown.Active(src) then return false end
    local s = State.Get(src)
    if s.status ~= 'alive' then
        if Config.Down.finishable and s.status ~= 'arrest' and s.status ~= 'dead' then Down.Arrest(src, 'finished') end
        return true
    end
    return Down.Start(src, tostring(info.cause or s.lastCause or 'unknown'))
end)

lib.callback.register('XS-Medical:server:respawn', function(src)
    local ok, err = Down.Respawn(src)
    if not ok and err then Framework.Notify(src, Text(err), 'error') end
    return ok
end)

lib.callback.register('XS-Medical:server:callHelp', function(src)
    local ok, err, wait = Down.CallForHelp(src)
    if not ok then return false, Text(err, { seconds = wait or 0 }) end
    return true
end)
