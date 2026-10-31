Compat = { hooks = { respawn = {}, checkIn = {} }, nextHook = 1, healedAt = {} }

local DEATH_STATE = { alive = 1, down = 2, knockout = 2, arrest = 3, dead = 3 }

local function provide(resource, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB) setCB(fn) end)
end

local function refreshPlayerData(src)
    if Framework.name ~= 'qbcore' then return end
    local player = Framework.GetPlayer(src)
    if player then TriggerClientEvent('QBCore:Player:SetPlayerData', src, player.PlayerData) end
end

function Compat.Status(src, status)
    local down = status == 'down' or status == 'knockout'
    local dead = status == 'arrest' or status == 'dead'
    if Framework.GetMetaData(src, 'inlaststand') ~= down then Framework.SetMetaData(src, 'inlaststand', down) end
    if Framework.GetMetaData(src, 'isdead') ~= dead then Framework.SetMetaData(src, 'isdead', dead) end
    local bag = Player(src).state
    bag:set('qbx_medical:deathState', DEATH_STATE[status] or 1, true)
    bag:set('isDead', down or dead, true)
    bag:set('dead', down or dead, true)
    refreshPlayerData(src)
end

function Compat.Bleed(src, level)
    local bag = Player(src).state
    if bag['qbx_medical:bleedLevel'] ~= level then bag:set('qbx_medical:bleedLevel', level, true) end
end

function Compat.RunHooks(name, payload)
    for _, hook in pairs(Compat.hooks[name] or {}) do
        local ok, result = pcall(hook.cb, payload)
        if ok and result == false then return false end
    end
    return true
end

local function each(target, fn)
    if target == -1 then
        for _, src in ipairs(Framework.Players()) do fn(src) end
        return
    end
    if type(target) == 'table' then target = target.PlayerData and target.PlayerData.source or target.source end
    target = tonumber(target)
    if target and GetPlayerName(target) then fn(target) end
end

local function reviveFull(src)
    local now = os.time()
    if Compat.healedAt[src] and now - Compat.healedAt[src] < 2 then return end
    Compat.healedAt[src] = now
    Down.Revive(src, 'full')
    Framework.RestoreNeeds(src)
    Framework.SetStress(src, -100)
end

local function healPartially(src)
    local s = State.Get(src)
    local keep = {}
    for _, injury in ipairs(s.injuries) do
        if injury.sev >= 3 then keep[#keep + 1] = injury end
    end
    s.injuries = keep
    for _, injury in ipairs(s.injuries) do
        if injury.bleed <= 2 then injury.bleed = 0 end
    end
    State.Sync(src, s)
end

local function statusFor(src)
    local s = State.Get(src)
    local injuries = {}
    for _, injury in ipairs(s.injuries) do
        injuries[#injuries + 1] = ('%s (%s)'):format(Text('part_' .. injury.part), Text('kind_' .. injury.kind))
    end
    local worst = Body.WorstBleed(s.injuries)
    return { injuries = injuries, bleedLevel = worst > 0 and worst + 1 or 0, bleedState = worst > 0 and Text('bleed_' .. worst) or nil, damageCauses = {} }
end

local function register(name, fn)
    provide('qbx_medical', name, fn)
    exports(name, fn)
end

register('Revive', function(target) each(target, reviveFull) end)
register('Heal', function(target) each(target, function(src) State.Heal(src) end) end)
register('HealPartially', function(target) each(target, healPartially) end)
register('ResetHungerAndThirst', function(target) each(target, Framework.RestoreNeeds) end)
register('GetPlayerStatus', function(src) return statusFor(tonumber(src)) end)
register('IsDead', function(src)
    local s = State.Peek(src)
    return s ~= nil and (s.status == 'arrest' or s.status == 'dead')
end)
register('IsLaststand', function(src)
    local s = State.Peek(src)
    return s ~= nil and (s.status == 'down' or s.status == 'knockout')
end)
register('IsDown', function(src) return State.IsDown(src) end)
register('GetVitals', function(src) return State.Vitals(tonumber(src)) end)
register('GetInjuries', function(src) return State.Public(tonumber(src)).injuries end)
register('registerHook', function(event, cb)
    if not Compat.hooks[event] or type(cb) ~= 'function' then return nil end
    local id = Compat.nextHook
    Compat.nextHook = id + 1
    Compat.hooks[event][id] = { cb = cb, resource = GetInvokingResource() }
    return id
end)
register('removeHooks', function(id)
    for _, list in pairs(Compat.hooks) do
        if id then list[id] = nil else
            local resource = GetInvokingResource()
            for key, hook in pairs(list) do if hook.resource == resource then list[key] = nil end end
        end
    end
end)

provide('qbx_ambulancejob', 'CheckIn', function(src, patient, hospitalName)
    patient = tonumber(patient) or tonumber(src)
    local place
    for _, p in pairs(Hospitals.places) do
        if p.kind == 'hospital' and (not hospitalName or p.name == hospitalName) then place = p break end
    end
    if not place then return false end
    return Hospitals.CheckIn(patient, place, nil, true) ~= false
end)

local function doctorCount() return #Framework.Medics(true) end
provide('qb-ambulancejob', 'GetDoctorCount', doctorCount)
exports('GetDoctorCount', doctorCount)

AddEventHandler('txAdmin:events:healedPlayer', function(data)
    if GetInvokingResource() ~= 'monitor' or type(data) ~= 'table' or type(data.id) ~= 'number' then return end
    each(data.id, reviveFull)
end)

AddEventHandler('txAdmin:events:playerHealed', function(data)
    if GetInvokingResource() ~= 'monitor' or type(data) ~= 'table' then return end
    local target = tonumber(data.target)
    if target then each(target, reviveFull) end
end)

RegisterNetEvent('hospital:server:ambulanceAlert', function(text)
    local src = source
    if GetInvokingResource() then return end
    Calls.Create({ src = src, kind = 'officer', message = Util.Text(text, 120), priority = 1 })
end)

RegisterNetEvent('hospital:server:emergencyAlert', function()
    local src = source
    if GetInvokingResource() then return end
    Calls.Create({ src = src, kind = 'officer', priority = 1 })
end)

RegisterNetEvent('hospital:server:SetArmor', function(amount)
    local src = source
    local value = Util.Clamp(math.floor(tonumber(amount) or 0), 0, 100)
    Framework.SetMetaData(src, 'armor', value)
end)

RegisterNetEvent('XS-Medical:server:armour', function(amount)
    local src = source
    Framework.SetMetaData(src, 'armor', Util.Clamp(math.floor(tonumber(amount) or 0), 0, 100))
end)

local painAt = {}
RegisterNetEvent('XS-Medical:server:compatPainkiller', function(doses)
    local src = source
    local now = os.time()
    if painAt[src] and now - painAt[src] < 20 then return end
    painAt[src] = now
    local s = State.Get(src)
    local minutes = Util.Clamp(tonumber(doses) or 1, 1, 3)
    s.relief = math.max(s.relief, 2)
    s.reliefUntil = math.max(s.reliefUntil, now + math.floor(minutes * 60))
    State.Sync(src, s)
end)

lib.callback.register('hospital:GetDoctors', function() return doctorCount() end)
lib.callback.register('XS-Medical:server:compatStatus', function(src, target)
    target = tonumber(target)
    if not target or not Framework.IsMedicSource(src) then return nil end
    return statusFor(target)
end)

if Framework.name == 'qbcore' and Framework.core then
    Framework.core.Functions.CreateCallback('hospital:GetDoctors', function(_, cb) cb(doctorCount()) end)
end

local trusted = {}
local function trustClient(src, kind)
    if Framework.IsAdmin(src) then return true end
    if (Config.Compat or {}).trustClientRevive == false then return false end
    local now = os.time()
    local last = trusted[src .. kind]
    if last and now - last < 60 then return false end
    trusted[src .. kind] = now
    print(('^3[XS-Medical]^0 %s (%s) was revived or healed by another resource through a client event (%s).'):format(GetPlayerName(src) or src, src, kind))
    return true
end

lib.callback.register('XS-Medical:server:compatRevive', function(src)
    if not State.IsDown(src) and #State.Get(src).injuries == 0 then return true end
    if not trustClient(src, 'revive') then return false end
    reviveFull(src)
    return true
end)

lib.callback.register('XS-Medical:server:compatHeal', function(src, kind)
    if not trustClient(src, 'heal') then return false end
    if kind == 'full' then State.Heal(src) else healPartially(src) end
    return true
end)

RegisterNetEvent('XS-Medical:server:compatPain', function()
    local src = source
    local now = os.time()
    if trusted[src .. 'pain'] and now - trusted[src .. 'pain'] < 30 then return end
    trusted[src .. 'pain'] = now
    local s = State.Get(src)
    State.AddInjury(s, 'torso', 'blunt', math.random(1, 2))
    State.AddInjury(s, 'rarm', 'cut', 1, { bleed = 1 })
    State.Sync(src, s)
end)

RegisterNetEvent('XS-Medical:server:compatRemoveBleed', function(level)
    local src = source
    local now = os.time()
    if trusted[src .. 'bleed'] and now - trusted[src .. 'bleed'] < 20 then return end
    trusted[src .. 'bleed'] = now
    local s = State.Get(src)
    local worst
    for _, injury in ipairs(s.injuries) do
        if Body.ActiveBleed(injury) > 0 and (not worst or injury.bleed > worst.bleed) then worst = injury end
    end
    if worst then
        worst.bleed = math.max(0, worst.bleed - Util.Clamp(math.floor(tonumber(level) or 1), 1, 2))
        State.Sync(src, s)
    end
end)

Framework.OnUnloaded(function(src)
    local bag = Player(src).state
    if bag.isDead or bag.dead then
        bag:set('qbx_medical:deathState', DEATH_STATE.alive, true)
        bag:set('isDead', false, true)
        bag:set('dead', false, true)
    end
    if (bag['qbx_medical:bleedLevel'] or 0) > 0 then Compat.Bleed(src, 0) end
end)

AddEventHandler('playerDropped', function()
    for _, kind in ipairs({ 'revive', 'heal', 'pain', 'bleed' }) do trusted[source .. kind] = nil end
    Compat.healedAt[source] = nil
    painAt[source] = nil
end)
