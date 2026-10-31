Calls = { blips = {}, list = {}, alerted = nil }

local function removeBlip(id)
    local blip = Calls.blips[id]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    Calls.blips[id] = nil
end

local function addBlip(call)
    removeBlip(call.id)
    local c = call.coords
    if not c then return end
    local blip = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, call.priority == 1 and 1 or 47)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, call.priority == 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s %s'):format(call.code or '', call.title or ''))
    EndTextCommandSetBlipName(blip)
    Calls.blips[call.id] = blip
    local seconds = (Config.Dispatch or {}).blipSeconds or 300
    SetTimeout(seconds * 1000, function() removeBlip(call.id) end)
end

local function distTo(coords)
    if not coords then return nil end
    return math.floor(#(GetEntityCoords(PlayerPedId()) - vector3(coords.x, coords.y, coords.z)))
end

RegisterNetEvent('XS-Medical:client:call', function(call)
    if type(call) ~= 'table' or not Me.IsMedic() then return end
    Calls.list[call.id] = call
    addBlip(call)
    call.dist = distTo(call.coords)
    Calls.alerted = { id = call.id, at = GetGameTimer() }
    UI.Send('alert', 'call', { call = call, dist = call.dist, keys = Calls.Keys() })
    if (Config.Dispatch or {}).sound ~= false then PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false) end
    if Tablet.open then UI.Send('tablet', 'calls', { call = call }) end
end)

RegisterNetEvent('XS-Medical:client:callUpdate', function(call)
    if type(call) ~= 'table' then return end
    call.dist = distTo(call.coords)
    if call.status == 'closed' then
        Calls.list[call.id] = nil
        removeBlip(call.id)
        if Calls.alerted and Calls.alerted.id == call.id then Calls.alerted = nil end
        UI.Send('alert', 'gone', { id = call.id })
    else
        Calls.list[call.id] = call
    end
    if Tablet.open then UI.Send('tablet', 'calls', { call = call }) end
end)

RegisterNetEvent('XS-Medical:client:page', function(page)
    if type(page) ~= 'table' or not Me.IsMedic() then return end
    UI.Send('alert', 'page', page)
    PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', false)
end)

function Calls.Assigned(call)
    if call and call.id then addBlip(call) end
end

local function bound(command, fallback)
    local ok, label = pcall(GetControlInstructionalButton, 0, joaat(command) | 0x80000000, true)
    if ok and type(label) == 'string' and label:sub(1, 2) == 't_' then return label:sub(3) end
    return fallback or nil
end

function Calls.Keys()
    local C = Config.Commands or {}
    return {
        respond = C.respond and C.respond ~= '' and bound(C.respond, C.respondKey) or nil,
        hide = C.hideAlert and C.hideAlert ~= '' and bound(C.hideAlert, C.hideKey) or nil,
    }
end

function Calls.Live()
    local a = Calls.alerted
    local seconds = (Config.Dispatch or {}).alertSeconds or 15
    if a and Calls.list[a.id] and GetGameTimer() - a.at <= seconds * 1000 then return a.id end
    return nil
end

function Calls.Respond()
    local id = Calls.Live()
    if not id or not Me.IsMedic() then return end
    Calls.alerted = nil
    local ok, call = lib.callback.await('XS-Medical:server:callTake', false, id)
    if ok and type(call) == 'table' then
        if call.coords then SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0) end
        Calls.Assigned(call)
        UI.Send('alert', 'taken', { id = id })
    else
        UI.Send('alert', 'gone', { id = id })
        Framework.Notify(type(call) == 'string' and call or Text('err_call_gone'), 'error')
    end
end

function Calls.Hide()
    local id = Calls.Live()
    Calls.alerted = nil
    UI.Send('alert', 'hide', { id = id })
end

local C = Config.Commands or {}
if C.respond and C.respond ~= '' then
    RegisterCommand(C.respond, function() CreateThread(Calls.Respond) end, false)
    if C.respondKey and C.respondKey ~= '' then RegisterKeyMapping(C.respond, Text('keybind_respond'), 'keyboard', C.respondKey) end
end
if C.hideAlert and C.hideAlert ~= '' then
    RegisterCommand(C.hideAlert, function() Calls.Hide() end, false)
    if C.hideKey and C.hideKey ~= '' then RegisterKeyMapping(C.hideAlert, Text('keybind_hide'), 'keyboard', C.hideKey) end
end

function Calls.Street()
    local c = GetEntityCoords(PlayerPedId())
    local a, b = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(a)
    local cross = b ~= 0 and GetStreetNameFromHashKey(b) or nil
    if cross and cross ~= '' then return ('%s / %s'):format(street, cross) end
    return street
end

lib.callback.register('XS-Medical:client:street', function()
    return Calls.Street()
end)

Framework.OnJob(function(job)
    if not Framework.IsMedic(job) then
        for id in pairs(Calls.blips) do removeBlip(id) end
        Calls.list = {}
    end
end)

Framework.OnUnloaded(function()
    for id in pairs(Calls.blips) do removeBlip(id) end
    Calls.list, Calls.alerted = {}, nil
end)
