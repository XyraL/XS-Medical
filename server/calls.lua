Calls = { list = {}, nextId = 1 }

local function public(call)
    local units = {}
    for src, name in pairs(call.units) do units[#units + 1] = { src = src, name = name } end
    return {
        id = call.id, kind = call.kind, title = call.title, description = call.description, street = call.street,
        coords = call.coords, caller = call.caller, priority = call.priority, status = call.status, units = units,
        createdAt = call.createdAt, patient = call.patient, code = call.code,
    }
end

local function toMedics(event, payload)
    if not (Config.Dispatch or {}).builtin then return end
    for _, src in ipairs(Framework.Medics(true)) do
        TriggerClientEvent(event, src, payload)
    end
end

local function describe(src)
    local s = State.Peek(src)
    if not s then return '' end
    local bits = {}
    if s.status == 'arrest' or s.status == 'dead' then bits[#bits + 1] = Text('call_not_breathing') end
    if s.status == 'knockout' then bits[#bits + 1] = Text('call_unconscious') end
    local worst = Body.WorstBleed(s.injuries)
    if worst >= 2 then bits[#bits + 1] = Text('call_bleeding_heavily') elseif worst == 1 then bits[#bits + 1] = Text('call_bleeding') end
    local kinds = {}
    for _, injury in ipairs(s.injuries) do
        if not kinds[injury.kind] and #bits < 4 then
            kinds[injury.kind] = true
            bits[#bits + 1] = Text('kind_' .. injury.kind)
        end
    end
    return table.concat(bits, ' · ')
end

function Calls.Create(data)
    data = data or {}
    local src = tonumber(data.src)
    local coords = data.coords
    if src and not coords then
        local ped = GetPlayerPed(src)
        if ped ~= 0 then
            local c = GetEntityCoords(ped)
            coords = { x = c.x, y = c.y, z = c.z }
        end
    end
    if not coords then return nil end

    for _, call in pairs(Calls.list) do
        if src and call.patient == src and call.status ~= 'closed' then
            call.description = describe(src)
            call.priority = math.min(call.priority, data.priority or call.priority)
            toMedics('XS-Medical:client:callUpdate', public(call))
            return call.id
        end
    end

    local street = data.street
    if src and not street then
        local ok, value = pcall(function() return lib.callback.await('XS-Medical:client:street', src) end)
        street = ok and value or nil
    end

    local kind = data.kind or 'custom'
    local call = {
        id = Calls.nextId, kind = kind, code = data.code or (Config.Dispatch or {}).code or '10-52',
        title = data.title or Text('call_title_' .. kind), description = Util.Text(data.message ~= nil and data.message ~= '' and data.message or (src and describe(src) or ''), 200),
        street = Util.Text(street or '', 80), coords = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 },
        caller = data.caller or (kind == 'witness' and Text('caller_witness') or (src and Framework.GetName(src)) or Text('caller_anonymous')),
        patient = src, priority = Util.Clamp(math.floor(tonumber(data.priority) or 2), 1, 3), status = 'open', units = {}, createdAt = os.time(),
    }
    Calls.nextId = Calls.nextId + 1
    Calls.list[call.id] = call

    toMedics('XS-Medical:client:call', public(call))
    Dispatch.Forward({
        code = call.code, title = call.title, description = (call.street ~= '' and (call.street .. ' — ') or '') .. call.description,
        coords = call.coords, priority = call.priority, caller = call.caller, blipTime = (Config.Dispatch or {}).blipSeconds or 300,
    })
    return call.id
end

function Calls.Take(medic, id)
    local call = Calls.list[tonumber(id) or -1]
    if not call or call.status == 'closed' then return false end
    call.units[medic] = Framework.GetName(medic) or ''
    call.status = 'assigned'
    toMedics('XS-Medical:client:callUpdate', public(call))
    if call.patient then
        Framework.Notify(call.patient, Text('call_help_coming'), 'success')
    end
    return true, public(call)
end

function Calls.Leave(medic, id)
    local call = Calls.list[tonumber(id) or -1]
    if not call then return false end
    call.units[medic] = nil
    if next(call.units) == nil and call.status == 'assigned' then call.status = 'open' end
    toMedics('XS-Medical:client:callUpdate', public(call))
    return true
end

function Calls.Close(id)
    local call = Calls.list[tonumber(id) or -1]
    if not call then return false end
    call.status = 'closed'
    toMedics('XS-Medical:client:callUpdate', public(call))
    Calls.list[call.id] = nil
    return true
end

function Calls.ClearFor(src)
    for id, call in pairs(Calls.list) do
        if call.patient == src then Calls.Close(id) end
    end
end

function Calls.List()
    local out = {}
    for _, call in pairs(Calls.list) do out[#out + 1] = public(call) end
    table.sort(out, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.createdAt > b.createdAt
    end)
    return out
end

exports('CreateCall', function(data)
    if type(data) ~= 'table' then return nil end
    return Calls.Create({
        coords = data.coords, kind = 'custom', title = data.title and Util.Text(data.title, 64) or nil,
        message = data.message or data.description, priority = data.priority, caller = data.caller, code = data.code,
        street = data.street,
    })
end)

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, call in pairs(Calls.list) do
            if now - call.createdAt > 1800 then Calls.Close(id) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, call in pairs(Calls.list) do
        if call.units[src] then
            call.units[src] = nil
            if next(call.units) == nil and call.status == 'assigned' then call.status = 'open' end
        end
        if call.patient == src then Calls.Close(id) end
    end
end)
