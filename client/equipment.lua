Equip = { held = nil, heldKind = nil, onIt = false, onNet = nil, carrying = false, carriedBy = nil, known = {} }

local BOX = { dict = 'anim@heists@box_carry@', clip = 'idle' }
local PUSHES = {
    { dict = 'amb@prop_human_bum_shopping_cart@male@base', clip = 'base' },
    BOX,
}
local LIE = { dict = 'anim@gangops@morgue@table@', clip = 'body_search' }
local SIT = { dict = 'missfinale_c2leadinoutfin_c_int', clip = '_leadin_loop2_lester' }
local CARRIER = { dict = 'missfinale_c2mcs_1', clip = 'fin_c2_mcs_1_camman' }
local CARRIED = { dict = 'nm', clip = 'firemans_carry' }
local picked = nil
local models = nil

local function equipModels()
    if models then return models end
    models = {
        [joaat((Config.Stretcher or {}).model or 'v_med_emptybed')] = 'stretcher',
        [joaat((Config.Wheelchair or {}).model or 'prop_wheelchair_01')] = 'wheelchair',
    }
    return models
end

local function pushAnim(kind)
    if kind == 'wheelchair' then return BOX end
    if picked then return picked end
    local list = {}
    local custom = (Config.Stretcher or {}).anim
    if type(custom) == 'table' and custom.dict then list[1] = custom end
    for _, a in ipairs(PUSHES) do list[#list + 1] = a end
    picked = BOX
    for _, a in ipairs(list) do
        if DoesAnimDictExist(a.dict) then picked = a break end
    end
    return picked
end

local function bounds(ent)
    local mn, mx = GetModelDimensions(GetEntityModel(ent))
    return mn, mx, (mx.x - mn.x) > (mx.y - mn.y)
end

local function pushShape(ent, kind)
    if kind == 'wheelchair' then
        return (Config.Wheelchair or {}).push or { offset = vec3(0.0, -0.3, -0.73), rotation = vec3(195.0, 180.0, 180.0), bone = 28422 }
    end
    local P = (Config.Stretcher or {}).push or {}
    if P.offset and P.rotation then return P end
    local mn, mx, alongX = bounds(ent)
    local cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    local reach = tonumber(P.reach) or 0.45
    local x, y, rz
    if alongX then
        rz, x, y = 90.0, cy, (mx.x - mn.x) / 2 + reach - cx
    else
        rz, x, y = 0.0, -cx, (mx.y - mn.y) / 2 + reach - cy
    end
    return { offset = vec3(x, y, -0.98 - mn.z + (tonumber(P.lift) or 0.0)), rotation = vec3(0.0, 0.0, rz + (tonumber(P.turn) or 0.0)) }
end

local function seatShape(ent, kind)
    if kind == 'wheelchair' then
        return (Config.Wheelchair or {}).seat or { offset = vec3(0.0, 0.0, 0.4), rotation = vec3(0.0, 0.0, 180.0) }
    end
    local L = (Config.Stretcher or {}).lie or {}
    if L.offset and L.rotation then return L end
    local mn, mx, alongX = bounds(ent)
    return {
        offset = vec3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z + (tonumber(L.lift) or 1.0)),
        rotation = vec3(0.0, 0.0, (alongX and 90.0 or 180.0) + (tonumber(L.turn) or 0.0)),
    }
end

local function entityFromNet(netId, timeoutMs)
    local untilAt = GetGameTimer() + (timeoutMs or 5000)
    while GetGameTimer() < untilAt do
        if NetworkDoesNetworkIdExist(netId) then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent ~= 0 and DoesEntityExist(ent) then return ent end
        end
        Wait(50)
    end
    return 0
end

local function control(ent)
    local untilAt = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < untilAt do
        NetworkRequestControlOfEntity(ent)
        Wait(20)
    end
    return NetworkHasControlOfEntity(ent)
end

function Equip.KindOf(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if not equipModels()[GetEntityModel(ent)] or not NetworkGetEntityIsNetworked(ent) then return nil end
    return Entity(ent).state.xsmEquipment
end

function Equip.RiderOf(ent)
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= 0 and IsEntityAttachedToEntity(ped, ent) then return GetPlayerServerId(player) end
    end
    return nil
end

function Equip.Under(ped)
    if not ped or ped == 0 then return nil end
    local ent = GetEntityAttachedTo(ped)
    if ent ~= 0 and Equip.KindOf(ent) then return ent end
    return nil
end

function Equip.Nearest(kind, range, free)
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, range or 4.0
    for ent, k in pairs(Equip.known) do
        if DoesEntityExist(ent) and (not kind or k == kind) and not IsEntityAttached(ent) then
            local d = #(GetEntityCoords(ent) - coords)
            if d < bestDist and (not free or not Equip.RiderOf(ent)) then best, bestDist = ent, d end
        end
    end
    if Equip.held and (not kind or Equip.heldKind == kind) then
        local ent = NetworkDoesNetworkIdExist(Equip.held) and NetworkGetEntityFromNetworkId(Equip.held) or 0
        if ent ~= 0 and (not free or not Equip.RiderOf(ent)) then return ent end
    end
    return best
end

function Equip.Patient(range)
    local me = PlayerPedId()
    local coords = GetEntityCoords(me)
    local best, bestDist = nil, range or 3.0
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= me and ped ~= 0 and not IsEntityAttached(ped) and not IsPedInAnyVehicle(ped, false) then
            local d = #(GetEntityCoords(ped) - coords)
            if d < bestDist then best, bestDist = GetPlayerServerId(player), d end
        end
    end
    return best
end

CreateThread(function()
    while true do
        local found = {}
        local wanted = equipModels()
        for _, obj in ipairs(GetGamePool('CObject')) do
            if wanted[GetEntityModel(obj)] and NetworkGetEntityIsNetworked(obj) then
                local kind = Entity(obj).state.xsmEquipment
                if kind then found[obj] = kind end
            end
        end
        Equip.known = found
        Wait(1000)
    end
end)

function Equip.Hold(netId, kind)
    Equip.Drop()
    local ent = entityFromNet(netId)
    if ent == 0 then return Framework.Notify(Text('err_spawn_failed'), 'error') end
    control(ent)
    local ped = PlayerPedId()
    local shape = pushShape(ent, kind)
    local o, r = shape.offset, shape.rotation
    local bone = shape.bone and GetPedBoneIndex(ped, shape.bone) or 0
    AttachEntityToEntity(ent, ped, bone, o.x, o.y, o.z, r.x, r.y, r.z, false, false, false, false, 2, true)
    Equip.held, Equip.heldKind = netId, kind
    Equip.known[ent] = kind
    local anim = pushAnim(kind)
    lib.requestAnimDict(anim.dict, 3000)
    CreateThread(function()
        lib.showTextUI(Text('equipment_hint'), { position = 'right-center' })
        while Equip.held == netId do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, anim.dict, anim.clip, 3) then
                TaskPlayAnim(p, anim.dict, anim.clip, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            if IsControlJustReleased(0, 73) or IsPedRagdoll(p) or IsPedInAnyVehicle(p, false) or Down.active then
                Equip.Drop()
            elseif IsControlJustReleased(0, 47) then
                Equip.Store()
            end
            Wait(0)
        end
        lib.hideTextUI()
        StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.0)
    end)
end

function Equip.Grab(ent)
    if Equip.held then return end
    local ok, info = lib.callback.await('XS-Medical:server:equipmentGrab', false, NetworkGetNetworkIdFromEntity(ent))
    if not ok then return Framework.Notify(info or Text('err_failed'), 'error') end
    Equip.Hold(info.netId, info.kind)
end

function Equip.Drop()
    if not Equip.held then return end
    local netId = Equip.held
    local ent = entityFromNet(netId, 500)
    Equip.held, Equip.heldKind = nil, nil
    if ent ~= 0 then
        DetachEntity(ent, true, true)
        PlaceObjectOnGroundProperly(ent)
    end
    TriggerServerEvent('XS-Medical:server:equipmentDrop', netId)
end

function Equip.Store(netId)
    netId = netId or Equip.held
    if not netId then return end
    if netId == Equip.held then Equip.held, Equip.heldKind = nil, nil end
    local ok, err = lib.callback.await('XS-Medical:server:equipmentStore', false, netId)
    if not ok and err then Framework.Notify(err, 'error') end
end

function Equip.PutOn(ent, target)
    local ok, err = lib.callback.await('XS-Medical:server:placeOn', false, target, NetworkGetNetworkIdFromEntity(ent))
    if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
end

function Equip.PlaceOn(target, kind)
    kind = kind or 'stretcher'
    local ent = Equip.Nearest(kind, 4.0, true)
    if not ent then return Framework.Notify(Text(kind == 'wheelchair' and 'err_no_wheelchair' or 'err_no_equipment'), 'error') end
    Equip.PutOn(ent, target)
end

function Equip.TakeOff(target)
    local ok, err = lib.callback.await('XS-Medical:server:takeOff', false, target)
    if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
end

function Equip.LoadInto(target)
    local vehicle = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 7.0, false)
    if not vehicle then return Framework.Notify(Text('err_no_vehicle'), 'error') end
    if Equip.held then
        local ent = entityFromNet(Equip.held, 300)
        Equip.held, Equip.heldKind = nil, nil
        if ent ~= 0 then DetachEntity(ent, true, true) end
    end
    local ok, err = lib.callback.await('XS-Medical:server:loadPatient', false, target, NetworkGetNetworkIdFromEntity(vehicle))
    if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
end

function Equip.Unload(vehicle)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then
            local id = Treat.ServerId(ped)
            if id and Treat.StatusOf(id) ~= 'alive' then
                local ok, err = lib.callback.await('XS-Medical:server:unloadPatient', false, id)
                if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
                return
            end
        end
    end
    Framework.Notify(Text('err_no_patient_inside'), 'error')
end

function Equip.Carry(target)
    local ok, err = lib.callback.await('XS-Medical:server:carry', false, target, true)
    if not ok then return Framework.Notify(err or Text('err_failed'), 'error') end
    Equip.carrying = target
    lib.requestAnimDict(CARRIER.dict, 3000)
    CreateThread(function()
        lib.showTextUI(Text('carry_hint'), { position = 'right-center' })
        while Equip.carrying == target do
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, CARRIER.dict, CARRIER.clip, 3) then
                TaskPlayAnim(ped, CARRIER.dict, CARRIER.clip, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            if IsControlJustReleased(0, 73) then Equip.PutDown() end
            Wait(0)
        end
        lib.hideTextUI()
        StopAnimTask(PlayerPedId(), CARRIER.dict, CARRIER.clip, 1.0)
    end)
end

function Equip.PutDown()
    if not Equip.carrying then return end
    Equip.carrying = false
    lib.callback.await('XS-Medical:server:carry', false, nil, false)
end

function Equip.Release()
    local ped = PlayerPedId()
    if Equip.onIt or Equip.carriedBy then
        DetachEntity(ped, true, false)
        ClearPedTasks(ped)
    end
    Equip.onIt, Equip.onNet, Equip.carriedBy = false, nil, nil
    if Down.active then Down.carried = false end
end

RegisterNetEvent('XS-Medical:client:placeOn', function(netId, kind)
    local ent = entityFromNet(netId)
    if ent == 0 then return end
    if Down and Down.ClearCrawl then Down.ClearCrawl() end
    local ped = PlayerPedId()
    local seat = seatShape(ent, kind)
    Equip.onIt, Equip.onNet = true, netId
    if Down.active then Down.carried = true end
    local anim = kind == 'wheelchair' and SIT or LIE
    lib.requestAnimDict(anim.dict, 3000)
    AttachEntityToEntity(ped, ent, 0, seat.offset.x, seat.offset.y, seat.offset.z, seat.rotation.x, seat.rotation.y, seat.rotation.z, false, false, false, false, 2, true)
    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    if kind == 'wheelchair' and not Down.active then lib.showTextUI(Text('wheelchair_hint'), { position = 'right-center' }) end
    CreateThread(function()
        while Equip.onIt and Equip.onNet == netId do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, anim.dict, anim.clip, 3) then TaskPlayAnim(p, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false) end
            if kind == 'wheelchair' and not Down.active and IsControlJustReleased(0, 73) then
                TriggerServerEvent('XS-Medical:server:leaveEquipment')
                Equip.Release()
            end
            Wait(0)
        end
        if kind == 'wheelchair' then lib.hideTextUI() end
    end)
end)

RegisterNetEvent('XS-Medical:client:takeOff', function()
    Equip.Release()
end)

RegisterNetEvent('XS-Medical:client:carried', function(carrier)
    local other = GetPlayerFromServerId(carrier)
    if other == -1 then return end
    if Down and Down.ClearCrawl then Down.ClearCrawl() end
    local carrierPed = GetPlayerPed(other)
    local ped = PlayerPedId()
    Equip.carriedBy = carrier
    if Down.active then Down.carried = true end
    lib.requestAnimDict(CARRIED.dict, 3000)
    AttachEntityToEntity(ped, carrierPed, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180.0, false, false, false, false, 2, false)
    TaskPlayAnim(ped, CARRIED.dict, CARRIED.clip, 8.0, -8.0, -1, 33, 0.0, false, false, false)
    CreateThread(function()
        while Equip.carriedBy == carrier do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, CARRIED.dict, CARRIED.clip, 3) then TaskPlayAnim(p, CARRIED.dict, CARRIED.clip, 8.0, -8.0, -1, 33, 0.0, false, false, false) end
            Wait(300)
        end
    end)
end)

RegisterNetEvent('XS-Medical:client:intoVehicle', function(vehNetId)
    local vehicle = entityFromNet(vehNetId)
    if vehicle == 0 then return end
    Equip.Release()
    if Down and Down.ClearCrawl then Down.ClearCrawl() end
    local ped = PlayerPedId()
    local seat = nil
    for _, s in ipairs({ 2, 1, 0 }) do
        if IsVehicleSeatFree(vehicle, s) then seat = s break end
    end
    if not seat then return Framework.Notify(Text('err_vehicle_full'), 'error') end
    TaskWarpPedIntoVehicle(ped, vehicle, seat)
end)

RegisterNetEvent('XS-Medical:client:outOfVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return end
    local c = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -4.6, 0.0)
    TaskLeaveVehicle(ped, vehicle, 16)
    Wait(300)
    SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
end)

RegisterNetEvent('hospital:client:SetEscortingState', function(state)
    Equip.escorting = state == true
end)

local function me() return GetPlayerServerId(PlayerId()) end

function Equip.RegisterTargets()
    local vehicles = (Config.Stretcher or {}).fromVehicles or { 'ambulance' }
    Target.AddModels('ambulance', vehicles, {
        {
            label = Text('opt_take_stretcher'), icon = 'fas fa-bed-pulse', distance = 4.0,
            canInteract = function() return Me.IsMedic() and not Equip.held end,
            onSelect = function(vehicle)
                local ok, info = lib.callback.await('XS-Medical:server:stretcherFromVehicle', false, NetworkGetNetworkIdFromEntity(vehicle))
                if not ok then return Framework.Notify(info or Text('err_failed'), 'error') end
                Equip.Hold(info.netId, info.kind)
            end,
        },
        {
            label = Text('opt_stow_stretcher'), icon = 'fas fa-truck-ramp-box', distance = 4.0,
            canInteract = function() return Me.IsMedic() and Equip.heldKind == 'stretcher' end,
            onSelect = function() Equip.Store() end,
        },
        {
            label = Text('opt_unload'), icon = 'fas fa-person-arrow-down-to-line', distance = 4.0,
            canInteract = function() return Me.IsMedic() end,
            onSelect = function(vehicle) Equip.Unload(vehicle) end,
        },
    })

    local S, W = Config.Stretcher or {}, Config.Wheelchair or {}
    Target.AddModels('equipment', { S.model or 'v_med_emptybed', W.model or 'prop_wheelchair_01' }, {
        {
            label = Text('opt_push_stretcher'), icon = 'fas fa-bed-pulse', distance = 2.5,
            canInteract = function(ent) return Equip.KindOf(ent) == 'stretcher' and Me.IsMedic() and not Equip.held and not IsEntityAttached(ent) end,
            onSelect = function(ent) Equip.Grab(ent) end,
        },
        {
            label = Text('opt_push_wheelchair'), icon = 'fas fa-wheelchair', distance = 2.5,
            canInteract = function(ent) return Equip.KindOf(ent) == 'wheelchair' and not Equip.held and not IsEntityAttached(ent) end,
            onSelect = function(ent) Equip.Grab(ent) end,
        },
        {
            label = Text('opt_patient_on'), icon = 'fas fa-person-arrow-down-to-line', distance = 2.5,
            canInteract = function(ent)
                local kind = Equip.KindOf(ent)
                if not kind or (kind == 'stretcher' and not Me.IsMedic()) then return false end
                return not Equip.RiderOf(ent) and Equip.Patient(3.0) ~= nil
            end,
            onSelect = function(ent)
                local target = Equip.Patient(3.0)
                if target then Equip.PutOn(ent, target) end
            end,
        },
        {
            label = Text('opt_sit_wheelchair'), icon = 'fas fa-chair', distance = 2.0,
            canInteract = function(ent) return Equip.KindOf(ent) == 'wheelchair' and not Equip.RiderOf(ent) and not IsEntityAttached(ent) and not Down.active end,
            onSelect = function(ent) Equip.PutOn(ent, me()) end,
        },
        {
            label = Text('opt_patient_off'), icon = 'fas fa-person-walking-arrow-right', distance = 2.5,
            canInteract = function(ent)
                if not Equip.KindOf(ent) then return false end
                local rider = Equip.RiderOf(ent)
                return rider ~= nil and rider ~= me()
            end,
            onSelect = function(ent)
                local rider = Equip.RiderOf(ent)
                if rider then Equip.TakeOff(rider) end
            end,
        },
        {
            label = Text('opt_put_away'), icon = 'fas fa-box-archive', distance = 2.5,
            canInteract = function(ent) return Equip.KindOf(ent) ~= nil and Me.IsMedic() and not IsEntityAttached(ent) and not Equip.RiderOf(ent) end,
            onSelect = function(ent) Equip.Store(NetworkGetNetworkIdFromEntity(ent)) end,
        },
    })
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    Equip.Release()
end)
