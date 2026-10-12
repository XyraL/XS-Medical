Calls = { blips = {}, list = {} }

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

RegisterNetEvent('XS-Medical:client:call', function(call)
    if type(call) ~= 'table' or not Me.IsMedic() then return end
    Calls.list[call.id] = call
    addBlip(call)
    local dist = nil
    if call.coords then dist = math.floor(#(GetEntityCoords(PlayerPedId()) - vector3(call.coords.x, call.coords.y, call.coords.z))) end
    UI.Send('pager', 'call', { call = call, dist = dist })
    if (Config.Dispatch or {}).sound ~= false then PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false) end
    if Tablet.open then UI.Send('tablet', 'calls', { call = call }) end
end)

RegisterNetEvent('XS-Medical:client:callUpdate', function(call)
    if type(call) ~= 'table' then return end
    if call.status == 'closed' then
        Calls.list[call.id] = nil
        removeBlip(call.id)
    else
        Calls.list[call.id] = call
    end
    if Tablet.open then UI.Send('tablet', 'calls', { call = call }) end
end)

RegisterNetEvent('XS-Medical:client:page', function(page)
    if type(page) ~= 'table' or not Me.IsMedic() then return end
    UI.Send('pager', 'page', page)
    PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', false)
end)

function Calls.Assigned(call)
    if call and call.id then addBlip(call) end
end

lib.callback.register('XS-Medical:client:street', function()
    local c = GetEntityCoords(PlayerPedId())
    local a, b = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(a)
    local cross = b ~= 0 and GetStreetNameFromHashKey(b) or nil
    if cross and cross ~= '' then return ('%s / %s'):format(street, cross) end
    return street
end)

Framework.OnJob(function(job)
    if not Framework.IsMedic(job) then
        for id in pairs(Calls.blips) do removeBlip(id) end
        Calls.list = {}
    end
end)
