Target = { name = nil, zones = {}, entities = {}, players = nil, models = {} }

if IsDuplicityVersion() or not Config then return end

local SUPPORTED = { 'ox_target', 'qb-target', 'sleepless_interact', 'interact', 'qtarget' }
local PREFIX = 'xs_medical_'

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

function Target.Detect()
    if Target.name then return Target.name end
    local wanted = Config.Bridges and Config.Bridges.target or 'auto'
    if wanted == 'auto' then
        wanted = 'none'
        for _, name in ipairs(SUPPORTED) do
            if running(name) then wanted = name break end
        end
    elseif wanted ~= 'none' and not running(wanted) then
        print(('^3[XS-Medical]^0 Config.Bridges.target is %s but it is not running. Using [E] prompts instead.'):format(wanted))
        wanted = 'none'
    end
    Target.name = wanted
    return wanted
end

local function guarded(fn, entity)
    return function(data)
        local ent = entity or (type(data) == 'table' and data.entity) or (type(data) == 'number' and data) or 0
        CreateThread(function() fn(ent) end)
    end
end

local function check(fn, entity)
    if not fn then return nil end
    return function(a)
        local ent = entity or (type(a) == 'number' and a) or 0
        local ok, result = pcall(fn, ent)
        return ok and result == true
    end
end

local function oxOptions(key, options, entity)
    local list = {}
    for i, o in ipairs(options) do
        list[i] = {
            name = ('%s%s_%d'):format(PREFIX, key, i),
            icon = o.icon, label = o.label, distance = o.distance or 2.0,
            canInteract = check(o.canInteract, entity), onSelect = guarded(o.onSelect, entity),
        }
    end
    return list
end

local function qbOptions(options, entity)
    local list, reach = {}, 1.5
    for i, o in ipairs(options) do
        reach = math.max(reach, o.distance or 2.0)
        list[i] = { icon = o.icon, label = o.label, canInteract = check(o.canInteract, entity), action = guarded(o.onSelect, entity) }
    end
    return list, reach
end

local function names(key, options)
    local out = {}
    for i in ipairs(options) do out[i] = ('%s%s_%d'):format(PREFIX, key, i) end
    return out
end

local function labels(options)
    local out = {}
    for i, o in ipairs(options) do out[i] = o.label end
    return out
end

local Prompts = { points = {}, entities = {}, players = nil, models = {} }

function Target.AddPoint(key, coords, radius, options)
    Target.Remove(key)
    local mode = Target.Detect()
    if mode == 'none' then
        Prompts.points[key] = { coords = coords, radius = radius, options = options }
        return
    end
    local name = PREFIX .. key
    if mode == 'ox_target' then
        Target.zones[key] = exports.ox_target:addSphereZone({ coords = coords, radius = radius, debug = Config.Debug, options = oxOptions(key, options) })
    elseif mode == 'sleepless_interact' then
        Target.zones[key] = exports.sleepless_interact:addCoords(coords, oxOptions(key, options))
    elseif mode == 'interact' then
        local list = {}
        for i, o in ipairs(options) do list[i] = { label = o.label, canInteract = check(o.canInteract), action = guarded(o.onSelect) } end
        exports.interact:AddInteraction({ coords = coords, distance = radius + 4.0, interactDst = radius + 0.5, id = name, name = name, options = list })
        Target.zones[key] = name
    else
        local list, reach = qbOptions(options)
        exports[mode]:AddCircleZone(name, coords, radius, { name = name, debugPoly = Config.Debug, useZ = true }, { options = list, distance = reach })
        Target.zones[key] = name
    end
end

function Target.Remove(key)
    Prompts.points[key] = nil
    local zone = Target.zones[key]
    if not zone then return end
    Target.zones[key] = nil
    pcall(function()
        if Target.name == 'ox_target' then
            exports.ox_target:removeZone(zone)
        elseif Target.name == 'sleepless_interact' then
            exports.sleepless_interact:removeCoords(zone)
        elseif Target.name == 'interact' then
            exports.interact:RemoveInteraction(zone)
        elseif Target.name == 'qb-target' or Target.name == 'qtarget' then
            exports[Target.name]:RemoveZone(zone)
        end
    end)
end

function Target.AddEntity(key, entity, options)
    Target.RemoveEntity(key)
    local mode = Target.Detect()
    Target.entities[key] = { entity = entity, options = options }
    if mode == 'none' then
        Prompts.entities[key] = { entity = entity, options = options }
        return
    end
    pcall(function()
        if mode == 'ox_target' then
            exports.ox_target:addLocalEntity(entity, oxOptions(key, options, entity))
        elseif mode == 'sleepless_interact' then
            exports.sleepless_interact:addLocalEntity(entity, oxOptions(key, options, entity))
        elseif mode == 'interact' then
            local list = {}
            for i, o in ipairs(options) do list[i] = { label = o.label, canInteract = check(o.canInteract, entity), action = guarded(o.onSelect, entity) } end
            exports.interact:AddLocalEntityInteraction({ entity = entity, name = PREFIX .. key, id = PREFIX .. key, distance = 4.0, interactDst = 2.0, options = list })
        else
            local list, reach = qbOptions(options, entity)
            exports[mode]:AddTargetEntity(entity, { options = list, distance = reach })
        end
    end)
end

function Target.RemoveEntity(key)
    Prompts.entities[key] = nil
    local entry = Target.entities[key]
    if not entry then return end
    Target.entities[key] = nil
    pcall(function()
        if Target.name == 'ox_target' then
            exports.ox_target:removeLocalEntity(entry.entity, names(key, entry.options))
        elseif Target.name == 'sleepless_interact' then
            exports.sleepless_interact:removeLocalEntity(entry.entity, names(key, entry.options))
        elseif Target.name == 'interact' then
            exports.interact:RemoveLocalEntityInteraction(entry.entity, PREFIX .. key)
        elseif Target.name == 'qb-target' or Target.name == 'qtarget' then
            exports[Target.name]:RemoveTargetEntity(entry.entity, labels(entry.options))
        end
    end)
end

function Target.AddPlayers(options)
    local mode = Target.Detect()
    Target.players = options
    if mode == 'none' then
        Prompts.players = options
        return
    end
    pcall(function()
        if mode == 'ox_target' then
            exports.ox_target:addGlobalPlayer(oxOptions('player', options))
        elseif mode == 'sleepless_interact' then
            exports.sleepless_interact:addGlobalPlayer(oxOptions('player', options))
        elseif mode == 'interact' then
            local list = {}
            for i, o in ipairs(options) do list[i] = { label = o.label, canInteract = check(o.canInteract), action = guarded(o.onSelect) } end
            exports.interact:AddGlobalPlayerInteraction({ name = PREFIX .. 'player', id = PREFIX .. 'player', distance = 4.0, interactDst = 2.0, options = list })
        else
            local list, reach = qbOptions(options)
            exports[mode]:AddGlobalPlayer({ options = list, distance = reach })
        end
    end)
end

function Target.AddModels(key, models, options)
    local mode = Target.Detect()
    Target.models[key] = { models = models, options = options }
    if mode == 'none' then
        Prompts.models[key] = { models = models, options = options }
        return
    end
    pcall(function()
        if mode == 'ox_target' then
            exports.ox_target:addModel(models, oxOptions(key, options))
        elseif mode == 'sleepless_interact' then
            exports.sleepless_interact:addModel(models, oxOptions(key, options))
        elseif mode == 'interact' then
            local list = {}
            for i, o in ipairs(options) do list[i] = { label = o.label, canInteract = check(o.canInteract), action = guarded(o.onSelect) } end
            for _, model in ipairs(models) do
                exports.interact:AddModelInteraction({ model = model, name = PREFIX .. key, id = PREFIX .. key .. model, distance = 5.0, interactDst = 2.5, options = list })
            end
        else
            local list, reach = qbOptions(options)
            exports[mode]:AddTargetModel(models, { options = list, distance = reach })
        end
    end)
end

function Target.Clear()
    for key in pairs(Target.zones) do Target.Remove(key) end
    for key in pairs(Target.entities) do Target.RemoveEntity(key) end
    Prompts.points, Prompts.entities = {}, {}
    pcall(function()
        if Target.players then
            if Target.name == 'ox_target' then
                exports.ox_target:removeGlobalPlayer(names('player', Target.players))
            elseif Target.name == 'qb-target' or Target.name == 'qtarget' then
                exports[Target.name]:RemoveGlobalPlayer(labels(Target.players))
            elseif Target.name == 'sleepless_interact' then
                exports.sleepless_interact:removeGlobalPlayer(names('player', Target.players))
            end
        end
        for key, entry in pairs(Target.models) do
            if Target.name == 'ox_target' then
                exports.ox_target:removeModel(entry.models, names(key, entry.options))
            elseif Target.name == 'qb-target' or Target.name == 'qtarget' then
                exports[Target.name]:RemoveTargetModel(entry.models, labels(entry.options))
            elseif Target.name == 'sleepless_interact' then
                exports.sleepless_interact:removeModel(entry.models, names(key, entry.options))
            end
        end
    end)
end

local function usable(options, entity)
    local out = {}
    for _, o in ipairs(options or {}) do
        local ok = true
        if o.canInteract then
            local good, result = pcall(o.canInteract, entity or 0)
            ok = good and result == true
        end
        if ok then out[#out + 1] = o end
    end
    return out
end

local function choose(options, entity)
    if #options == 1 then
        CreateThread(function() options[1].onSelect(entity or 0) end)
        return
    end
    local list = {}
    for i, o in ipairs(options) do
        list[i] = { title = o.label, icon = o.icon, onSelect = function() CreateThread(function() o.onSelect(entity or 0) end) end }
    end
    lib.registerContext({ id = 'xs_medical_prompt', title = Text('notify_title'), options = list })
    lib.showContext('xs_medical_prompt')
end

local function nearestPlayer(ped, coords, range)
    local best, bestDist = nil, range
    for _, player in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(player)
        if other ~= ped and other ~= 0 then
            local dist = #(GetEntityCoords(other) - coords)
            if dist < bestDist then best, bestDist = other, dist end
        end
    end
    return best
end

local function candidate()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, bestDist, bestEntity = nil, 99.0, 0

    for _, p in pairs(Prompts.points) do
        local dist = #(coords - p.coords)
        if dist <= (p.radius + 0.6) and dist < bestDist then
            local list = usable(p.options)
            if #list > 0 then best, bestDist, bestEntity = list, dist, 0 end
        end
    end

    for _, e in pairs(Prompts.entities) do
        if DoesEntityExist(e.entity) then
            local dist = #(coords - GetEntityCoords(e.entity))
            if dist <= 2.2 and dist < bestDist then
                local list = usable(e.options, e.entity)
                if #list > 0 then best, bestDist, bestEntity = list, dist, e.entity end
            end
        end
    end

    if Prompts.players then
        local other = nearestPlayer(ped, coords, 2.0)
        if other then
            local dist = #(coords - GetEntityCoords(other))
            if dist < bestDist then
                local list = usable(Prompts.players, other)
                if #list > 0 then best, bestDist, bestEntity = list, dist, other end
            end
        end
    end

    for _, m in pairs(Prompts.models) do
        local vehicle = lib.getClosestVehicle(coords, 4.0, false)
        if vehicle then
            local model = GetEntityModel(vehicle)
            for _, name in ipairs(m.models) do
                if model == joaat(name) then
                    local dist = #(coords - GetEntityCoords(vehicle))
                    if dist < bestDist + 2.0 then
                        local list = usable(m.options, vehicle)
                        if #list > 0 then best, bestDist, bestEntity = list, dist, vehicle end
                    end
                end
            end
        end
        for _, name in ipairs(m.models) do
            local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.5, joaat(name), false, false, false)
            if obj and obj ~= 0 then
                local dist = #(coords - GetEntityCoords(obj))
                if dist < bestDist then
                    local list = usable(m.options, obj)
                    if #list > 0 then best, bestDist, bestEntity = list, dist, obj end
                end
            end
        end
    end

    return best, bestEntity
end

CreateThread(function()
    local shown = nil
    while Target.Detect() == 'none' do
        local list, entity = candidate()
        if list then
            local text = #list == 1 and ('[E] ' .. list[1].label) or ('[E] ' .. Text('prompt_options', { count = #list }))
            if shown ~= text then
                lib.showTextUI(text, { position = 'right-center' })
                shown = text
            end
            local untilAt = GetGameTimer() + 300
            while GetGameTimer() < untilAt do
                if IsControlJustReleased(0, 38) and not IsNuiFocused() then
                    choose(list, entity)
                    Wait(400)
                    break
                end
                Wait(0)
            end
        else
            if shown then
                lib.hideTextUI()
                shown = nil
            end
            Wait(350)
        end
    end
end)
