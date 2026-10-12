Hospital = { blips = {}, keys = {}, entities = {} }

local function v3(p) return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end

local function medic() return Me.IsMedic() end

local function clearBlips()
    for _, blip in ipairs(Hospital.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Hospital.blips = {}
end

local function firstPoint(place)
    for _, kind in ipairs({ 'checkin', 'pharmacist', 'bed', 'duty', 'garage' }) do
        local p = place.points[kind] and place.points[kind][1]
        if p then return p end
    end
    for _, list in pairs(place.points) do
        if list[1] then return list[1] end
    end
    return nil
end

local function addBlip(place)
    if not place.blip then return end
    local p = firstPoint(place)
    if not p then return end
    local B = (Config.Blips or {})[place.kind] or { sprite = 61, colour = 2, scale = 0.8 }
    local blip = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(blip, B.sprite or 61)
    SetBlipColour(blip, B.colour or 2)
    SetBlipScale(blip, B.scale or 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(place.name)
    EndTextCommandSetBlipName(blip)
    Hospital.blips[#Hospital.blips + 1] = blip
end

local function key(place, kind, p) return ('%s_%s_%s'):format(place.id, kind, p.id) end

local function stashOpen(place, p)
    local ok, info = lib.callback.await('XS-Medical:server:stash', false, place.id, p.id)
    if not ok then return Framework.Notify(info or Text('err_failed'), 'error') end
    Inventory.OpenStash(info.mode, info.id, info.label, info.slots, info.weight)
end

local function cabinet(place, p)
    local ok, items = lib.callback.await('XS-Medical:server:cabinet', false, place.id, p.id)
    if not ok then return Framework.Notify(items or Text('err_failed'), 'error') end
    Menu.Open({
        title = Text('cabinet_title'), subtitle = place.name,
        items = (function()
            local out = {}
            for _, e in ipairs(items) do
                out[#out + 1] = { id = e.item, label = e.label, right = e.price > 0 and ('$' .. e.price) or Text('free'), qty = true }
            end
            return out
        end)(),
    }, function(choice, qty)
        local okTake, message = lib.callback.await('XS-Medical:server:cabinetTake', false, place.id, p.id, choice, qty or 1)
        Framework.Notify(message or '', okTake and 'success' or 'error')
        return okTake
    end)
end

local function vehicleType(model)
    local hash = joaat(model)
    if IsThisModelAHeli(hash) then return 'heli' end
    if IsThisModelAPlane(hash) then return 'plane' end
    if IsThisModelABike(hash) or IsThisModelAQuadbike(hash) then return 'bike' end
    if IsThisModelABoat(hash) then return 'boat' end
    return 'automobile'
end

local function garage(place, kind, p)
    local ok, list = lib.callback.await('XS-Medical:server:garage', false, place.id, p.id, kind)
    if not ok then return Framework.Notify(list or Text('err_failed'), 'error') end
    local items = {}
    for _, v in ipairs(list) do items[#items + 1] = { id = v.model, label = v.label, right = v.model } end
    Menu.Open({ title = kind == 'helipad' and Text('helipad_title') or Text('garage_title'), subtitle = place.name, items = items }, function(model)
        local spawn = p.spawn or p
        if IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 3.0) then
            Framework.Notify(Text('err_spawn_blocked'), 'error')
            return false
        end
        local hash = joaat(model)
        if not IsModelInCdimage(hash) then
            Framework.Notify(Text('err_bad_model', { model = model }), 'error')
            return false
        end
        local okSpawn, info = lib.callback.await('XS-Medical:server:spawnVehicle', false, place.id, p.id, kind, model, vehicleType(model))
        if not okSpawn then
            Framework.Notify(info or Text('err_failed'), 'error')
            return false
        end
        CreateThread(function() Hospital.TakeVehicle(info.netId) end)
        return true
    end)
end

function Hospital.TakeVehicle(netId)
    DoScreenFadeOut(300)
    local vehicle = 0
    local timeout = GetGameTimer() + 10000
    while GetGameTimer() < timeout do
        if NetworkDoesNetworkIdExist(netId) then
            vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then break end
        end
        Wait(100)
    end
    if vehicle ~= 0 then
        Fuel.Set(vehicle, (Config.Vehicles or {}).fuel or 100.0)
        SetVehicleEngineOn(vehicle, true, true, false)
        local ped = PlayerPedId()
        local until_ = GetGameTimer() + 5000
        while GetVehiclePedIsIn(ped, false) ~= vehicle and GetGameTimer() < until_ do
            SetPedIntoVehicle(ped, vehicle, -1)
            Wait(100)
        end
    else
        Framework.Notify(Text('err_vehicle_vanished'), 'error')
    end
    DoScreenFadeIn(400)
end

local function storeVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then vehicle = lib.getClosestVehicle(GetEntityCoords(ped), 8.0, true) or 0 end
    if vehicle == 0 then return Framework.Notify(Text('err_no_vehicle'), 'error') end
    if GetVehiclePedIsIn(ped, false) == vehicle then TaskLeaveVehicle(ped, vehicle, 0) Wait(1200) end
    local ok, err = lib.callback.await('XS-Medical:server:storeVehicle', false, NetworkGetNetworkIdFromEntity(vehicle))
    Framework.Notify(ok and Text('vehicle_stored') or (err or Text('err_failed')), ok and 'success' or 'error')
end

local function elevator(place, p)
    local floors = {}
    for _, other in ipairs(place.points.elevator or {}) do
        if other.group == p.group and other.id ~= p.id then floors[#floors + 1] = { id = other.id, label = other.floor, point = other } end
    end
    if #floors == 0 then return Framework.Notify(Text('err_no_floors'), 'error') end
    local items = {}
    for _, f in ipairs(floors) do items[#items + 1] = { id = f.id, label = f.label } end
    Menu.Open({ title = p.group, subtitle = Text('elevator_here', { floor = p.floor }), items = items }, function(id)
        for _, f in ipairs(floors) do
            if f.id == id then
                CreateThread(function()
                    local ms = (Config.Elevators or {}).fadeMs or 450
                    DoScreenFadeOut(ms)
                    while not IsScreenFadedOut() do Wait(10) end
                    local ped = PlayerPedId()
                    SetEntityCoords(ped, f.point.x, f.point.y, f.point.z, false, false, false, false)
                    SetEntityHeading(ped, f.point.w or 0.0)
                    Wait(350)
                    DoScreenFadeIn(ms)
                end)
                return true
            end
        end
        return false
    end)
end

local function checkIn(place, p)
    local medics = GlobalState['xsm:medics'] or 0
    Menu.Open({
        title = Text('checkin_title'), subtitle = place.name,
        note = medics >= ((Config.CheckIn or {}).nurseWhenMedicsBelow or 1) and Text('checkin_queue_note') or Text('checkin_nurse_note', { price = (Config.CheckIn or {}).price or 0 }),
        items = { { id = 'checkin', label = Text('checkin_confirm') } },
    }, function()
        local ok, info = lib.callback.await('XS-Medical:server:checkIn', false, place.id, p.id)
        if not ok then
            Framework.Notify(info or Text('err_failed'), 'error')
            return false
        end
        if info and info.mode == 'queue' then Framework.Notify(Text('checkin_queued'), 'success') end
        return true
    end)
end

local function claimBed(place, bed)
    local ok, err = lib.callback.await('XS-Medical:server:claimBed', false, place.id, bed.id)
    if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
end

local function equipment(place, p)
    local ok, info = lib.callback.await('XS-Medical:server:equipmentTake', false, place.id, p.id)
    if not ok then return Framework.Notify(info or Text('err_failed'), 'error') end
    Equip.Hold(info.netId, info.kind)
end

local function surgeryAt(place, p)
    Surgery.Begin(nil, place, p)
end

local function bedFree(place, bed)
    local occ = Me.beds[('%s:%s'):format(place.id, bed.id)]
    return occ == nil
end

function Hospital.NearestFreeBed(range)
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestPlace, bestDist = nil, nil, range or 4.0
    for _, place in ipairs(Me.places or {}) do
        for _, bed in ipairs(place.points.bed or {}) do
            local d = #(coords - v3(bed))
            if d < bestDist and bedFree(place, bed) then best, bestPlace, bestDist = bed, place, d end
        end
    end
    return best, bestPlace
end

function Hospital.NearestSurgery(range)
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestPlace, bestDist = nil, nil, range or 4.0
    for _, place in ipairs(Me.places or {}) do
        for _, p in ipairs(place.points.surgery or {}) do
            local d = #(coords - v3(p))
            if d < bestDist then best, bestPlace, bestDist = p, place, d end
        end
    end
    return best, bestPlace
end

function Hospital.PutInBed(target)
    local bed, place = Hospital.NearestFreeBed(5.0)
    if not bed then return Framework.Notify(Text('err_no_bed_near'), 'error') end
    local ok, err = lib.callback.await('XS-Medical:server:putInBed', false, target, place.id, bed.id)
    if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
end

function Hospital.Build(places)
    for _, k in ipairs(Hospital.keys) do Target.Remove(k) end
    for k in pairs(Hospital.entities) do Target.RemoveEntity(k) end
    Hospital.keys, Hospital.entities = {}, {}
    clearBlips()
    local props = {}
    local isMedic = medic()

    for _, place in ipairs(places or {}) do
        addBlip(place)
        local P = place.points

        for _, p in ipairs(P.checkin or {}) do
            local k = key(place, 'checkin', p)
            if p.npc then
                props[#props + 1] = {
                    key = k, kind = 'ped', model = p.ped, x = p.x, y = p.y, z = p.z, w = p.w, scenario = 'WORLD_HUMAN_CLIPBOARD',
                    onSpawn = function(ent)
                        Hospital.entities[k] = true
                        Target.AddEntity(k, ent, { { label = Text('opt_checkin'), icon = 'fas fa-clipboard-user', distance = 2.5, onSelect = function() checkIn(place, p) end } })
                    end,
                    onDespawn = function() Target.RemoveEntity(k) Hospital.entities[k] = nil end,
                }
            else
                Target.AddPoint(k, v3(p), 1.2, { { label = Text('opt_checkin'), icon = 'fas fa-clipboard-user', onSelect = function() checkIn(place, p) end } })
                Hospital.keys[#Hospital.keys + 1] = k
            end
        end

        for _, p in ipairs(P.pharmacist or {}) do
            local k = key(place, 'pharmacist', p)
            props[#props + 1] = {
                key = k, kind = 'ped', model = p.ped, x = p.x, y = p.y, z = p.z, w = p.w, scenario = 'PROP_HUMAN_STAND_IMPATIENT',
                onSpawn = function(ent)
                    Hospital.entities[k] = true
                    Target.AddEntity(k, ent, { { label = Text('opt_pharmacy'), icon = 'fas fa-prescription-bottle-medical', distance = 2.5, onSelect = function() Pharmacy.Open(place, p) end } })
                end,
                onDespawn = function() Target.RemoveEntity(k) Hospital.entities[k] = nil end,
            }
        end

        for _, bed in ipairs(P.bed or {}) do
            local k = key(place, 'bed', bed)
            if bed.prop and bed.prop ~= '' then
                props[#props + 1] = { key = k .. '_prop', kind = 'object', model = bed.prop, x = bed.x, y = bed.y, z = bed.z, w = bed.w, skipIfMap = true }
            end
            Target.AddPoint(k, v3(bed), 1.1, {
                { label = Text('opt_lie_down'), icon = 'fas fa-bed', canInteract = function() return bedFree(place, bed) and not Bed.active end, onSelect = function() claimBed(place, bed) end },
            })
            Hospital.keys[#Hospital.keys + 1] = k
        end

        local simple = {
            { kind = 'storage', label = 'opt_storage', icon = 'fas fa-box-archive', medicOnly = true, fn = stashOpen },
            { kind = 'cabinet', label = 'opt_cabinet', icon = 'fas fa-briefcase-medical', medicOnly = true, fn = cabinet },
            { kind = 'boss', label = 'opt_boss', icon = 'fas fa-user-tie', medicOnly = true, fn = function() Tablet.Open('roster') end },
            { kind = 'elevator', label = 'opt_elevator', icon = 'fas fa-elevator', fn = elevator },
            { kind = 'equipment', label = 'opt_equipment', icon = 'fas fa-wheelchair', fn = equipment },
            { kind = 'surgery', label = 'opt_surgery', icon = 'fas fa-syringe', medicOnly = true, fn = surgeryAt },
        }
        for _, def in ipairs(simple) do
            for _, p in ipairs(P[def.kind] or {}) do
                local k = key(place, def.kind, p)
                local label = Text(def.label)
                if def.kind == 'equipment' then label = Text(p.kind == 'wheelchair' and 'opt_take_wheelchair' or 'opt_take_stretcher') end
                Target.AddPoint(k, v3(p), 1.1, {
                    { label = label, icon = def.icon, canInteract = function() return not def.medicOnly or medic() end, onSelect = function() def.fn(place, p) end },
                })
                Hospital.keys[#Hospital.keys + 1] = k
            end
        end

        for _, p in ipairs(P.duty or {}) do
            local k = key(place, 'duty', p)
            Target.AddPoint(k, v3(p), 1.1, {
                {
                    label = Text('opt_duty'), icon = 'fas fa-clipboard-check', canInteract = function() return Util.IsMedicJob(Framework.Job()) end,
                    onSelect = function()
                        local ok, onDuty = lib.callback.await('XS-Medical:server:duty', false, place.id, p.id)
                        if ok then Framework.Notify(onDuty and Text('duty_on') or Text('duty_off'), 'success') else Framework.Notify(onDuty or Text('err_failed'), 'error') end
                    end,
                },
            })
            Hospital.keys[#Hospital.keys + 1] = k
        end

        for _, kind in ipairs({ 'garage', 'helipad' }) do
            for _, p in ipairs(P[kind] or {}) do
                local k = key(place, kind, p)
                Target.AddPoint(k, v3(p), 1.4, {
                    { label = Text(kind == 'helipad' and 'opt_helipad' or 'opt_garage'), icon = kind == 'helipad' and 'fas fa-helicopter' or 'fas fa-truck-medical', canInteract = medic, onSelect = function() garage(place, kind, p) end },
                    { label = Text('opt_store_vehicle'), icon = 'fas fa-square-parking', canInteract = medic, onSelect = storeVehicle },
                })
                Hospital.keys[#Hospital.keys + 1] = k
            end
        end
    end

    Props.Set(props)
    if Screens and Screens.Build then Screens.Build(places) end
    if not isMedic and Tablet and Tablet.open then Tablet.Close() end
end
