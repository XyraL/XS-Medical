Props = { wanted = {}, live = {}, generation = 0 }

local SPAWN, DESPAWN, BUDGET = 55.0, 75.0, 60

local function signature(e)
    return ('%s|%s|%.2f|%.2f|%.2f|%.1f'):format(e.kind, e.model, e.x, e.y, e.z, e.w or 0.0)
end

local function remove(key)
    local live = Props.live[key]
    if not live then return end
    Props.live[key] = nil
    if live.entry.onDespawn then pcall(live.entry.onDespawn, live.entity) end
    if live.entity and DoesEntityExist(live.entity) then
        if live.entry.kind == 'ped' then DeletePed(live.entity) else DeleteObject(live.entity) end
    end
end

local function hasMapObject(entry)
    local hash = joaat(entry.model)
    local found = GetClosestObjectOfType(entry.x, entry.y, entry.z, 0.9, hash, false, false, false)
    return found ~= 0
end

local function spawn(key, entry, generation)
    local hash = joaat(entry.model)
    if not IsModelInCdimage(hash) then return end
    lib.requestModel(hash, 5000)
    if generation ~= Props.generation or not Props.wanted[key] or Props.live[key] then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    local entity
    if entry.kind == 'ped' then
        entity = CreatePed(4, hash, entry.x, entry.y, entry.z, entry.w or 0.0, false, true)
        SetEntityInvincible(entity, true)
        SetBlockingOfNonTemporaryEvents(entity, true)
        SetPedCanRagdoll(entity, false)
        SetPedFleeAttributes(entity, 0, false)
        FreezeEntityPosition(entity, true)
        if entry.scenario then TaskStartScenarioInPlace(entity, entry.scenario, 0, true) end
    else
        if entry.skipIfMap and hasMapObject(entry) then
            SetModelAsNoLongerNeeded(hash)
            Props.live[key] = { entry = entry, entity = nil, sig = signature(entry), map = true }
            return
        end
        entity = CreateObjectNoOffset(hash, entry.x, entry.y, entry.z, false, false, false)
        SetEntityHeading(entity, entry.w or 0.0)
        FreezeEntityPosition(entity, true)
    end
    SetModelAsNoLongerNeeded(hash)
    if generation ~= Props.generation or not Props.wanted[key] then
        if entry.kind == 'ped' then DeletePed(entity) else DeleteObject(entity) end
        return
    end
    Props.live[key] = { entry = entry, entity = entity, sig = signature(entry) }
    if entry.onSpawn then pcall(entry.onSpawn, entity) end
end

function Props.Set(list)
    Props.generation = Props.generation + 1
    local wanted = {}
    for _, entry in ipairs(list or {}) do wanted[entry.key] = entry end
    for key, live in pairs(Props.live) do
        local want = wanted[key]
        if not want or signature(want) ~= live.sig then remove(key) end
    end
    Props.wanted = wanted
end

function Props.Entity(key)
    local live = Props.live[key]
    return live and live.entity or nil
end

function Props.Clear()
    Props.generation = Props.generation + 1
    for key in pairs(Props.live) do remove(key) end
    Props.wanted = {}
end

CreateThread(function()
    while true do
        Wait(1000)
        local generation = Props.generation
        local origin = GetFinalRenderedCamCoord()
        local count = 0
        for _ in pairs(Props.live) do count = count + 1 end
        local candidates = {}
        for key, entry in pairs(Props.wanted) do
            local dist = #(origin - vector3(entry.x, entry.y, entry.z))
            local live = Props.live[key]
            if live and dist > DESPAWN then
                remove(key)
                count = count - 1
            elseif not live and dist < SPAWN then
                candidates[#candidates + 1] = { key = key, entry = entry, dist = dist }
            end
        end
        table.sort(candidates, function(a, b) return a.dist < b.dist end)
        for _, c in ipairs(candidates) do
            if count >= BUDGET or generation ~= Props.generation then break end
            spawn(c.key, c.entry, generation)
            count = count + 1
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Props.Clear() end
end)
