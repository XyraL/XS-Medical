local function society()
    return (Config.Jobs or {}).society or 'ambulance'
end

local function placePoint(placeId, kind, pointId)
    local place = Hospitals.Get(placeId)
    if not place then return nil end
    return place, Hospitals.Point(place, kind, tostring(pointId or ''))
end

local function bedPublic(place, bed)
    return { place = place.id, id = bed.id, x = bed.x, y = bed.y, z = bed.z, w = bed.w, label = bed.label, room = bed.room, prop = bed.prop }
end

local function pageMedics(title, text, coords)
    for _, medic in ipairs(Framework.Medics(true)) do
        TriggerClientEvent('XS-Medical:client:page', medic, { title = title, text = text, coords = coords })
    end
end

function Hospitals.CheckIn(src, place, point, bypass)
    if not bypass and not Hospitals.Near(src, point, 4.0) then return false, 'err_too_far' end
    local s = State.Get(src)
    if s.status ~= 'alive' and not bypass then return false, 'err_cannot_now' end
    if not Compat.RunHooks('checkIn', { source = src, hospitalName = place.name }) then return false, 'err_cannot_now' end

    local C = Config.CheckIn or {}
    if not bypass and #Framework.Medics(true) >= (C.nurseWhenMedicsBelow or 1) then
        Patients.CheckIn(src, place.id)
        if C.pageMedics ~= false then
            pageMedics(Text('page_checkin_title'), Text('page_checkin_text', { name = Framework.GetName(src) or '', hospital = place.name }), point and { x = point.x, y = point.y, z = point.z } or nil)
        end
        return true, { mode = 'queue' }
    end

    local bed = Hospitals.FreeBed(place, false)
    if not bed then return false, 'err_no_beds' end

    local price = math.floor(tonumber(C.price) or 0)
    if price > 0 and not bypass then
        if not Framework.Charge(src, price, C.account or 'bank', 'hospital-checkin') then return false, 'err_no_money', { amount = price } end
        Banking.Deposit(place.society ~= '' and place.society or society(), price, 'Hospital check-in')
    end

    Hospitals.Occupy(src, place, bed)
    Patients.CheckIn(src, place.id)
    Patients.Bed(src, place.id, bed, 'recovering')
    s.treatUntil = os.time() + (C.treatSeconds or 20)
    TriggerClientEvent('XS-Medical:client:toBed', src, bedPublic(place, bed), { seconds = C.treatSeconds or 20, treat = true })
    return true, { mode = 'bed' }
end

lib.callback.register('XS-Medical:server:checkIn', function(src, placeId, pointId)
    local place, point = placePoint(placeId, 'checkin', pointId)
    if not point then return false, Text('err_unknown_place') end
    local ok, err, vars = Hospitals.CheckIn(src, place, point, false)
    if not ok then return false, Text(err, vars) end
    return true, vars
end)

lib.callback.register('XS-Medical:server:bedDone', function(src)
    local s = State.Get(src)
    if not s.treatUntil or os.time() < s.treatUntil - 2 then return false end
    local place = Hospitals.BedOf(src)
    if not place then return false end
    s.treatUntil = nil
    Down.Revive(src, 'full')
    Patients.SetStatus(src, 'ready')
    Patients.Log(src, Text('log_nurse_treated'))
    return true
end)

lib.callback.register('XS-Medical:server:putInBed', function(src, target, placeId, bedId)
    target = tonumber(target)
    if not Framework.IsMedicSource(src) then return false, Text('err_medics_only') end
    local place, bed = placePoint(placeId, 'bed', bedId)
    if not bed then return false, Text('err_unknown_place') end
    if not target or not GetPlayerName(target) then return false, Text('err_no_patient') end
    if not Hospitals.Near(src, bed, 5.0) or not Hospitals.Near(target, bed, 6.0) then return false, Text('err_too_far') end
    local other = Hospitals.Occupant(place.id, bed.id)
    if other and other ~= target then return false, Text('err_bed_taken') end
    Hospitals.Occupy(target, place, bed)
    Patients.Attend(target, src)
    Patients.Bed(target, place.id, bed, 'seen')
    Patients.Log(target, Text('log_in_bed', { bed = bed.room ~= '' and bed.room or bed.label }), src)
    TriggerClientEvent('XS-Medical:client:toBed', target, bedPublic(place, bed), { treat = false })
    return true
end)

lib.callback.register('XS-Medical:server:claimBed', function(src, placeId, bedId)
    local place, bed = placePoint(placeId, 'bed', bedId)
    if not bed then return false, Text('err_unknown_place') end
    if not Hospitals.Near(src, bed, 3.0) then return false, Text('err_too_far') end
    local occ = Hospitals.Occupant(place.id, bed.id)
    if occ and occ ~= src then return false, Text('err_bed_taken') end
    local s = State.Get(src)
    if s.status ~= 'alive' then return false, Text('err_cannot_now') end
    Hospitals.Occupy(src, place, bed)
    if #s.injuries > 0 or s.blood < 95 then Patients.Bed(src, place.id, bed, 'waiting') end
    TriggerClientEvent('XS-Medical:client:toBed', src, bedPublic(place, bed), { treat = false })
    return true
end)

lib.callback.register('XS-Medical:server:leaveBed', function(src)
    local s = State.Get(src)
    if s.status ~= 'alive' then return false end
    if s.treatUntil and os.time() < s.treatUntil then return false, Text('err_treatment_running') end
    s.treatUntil = nil
    Hospitals.FreeBedOf(src)
    local v = Patients.Get(src)
    if v and (v.status == 'ready' or (#s.injuries == 0 and s.blood >= 95)) then
        Patients.Discharge(src)
    else
        Patients.Leave(src)
    end
    return true
end)

lib.callback.register('XS-Medical:server:discharge', function(src, target)
    target = tonumber(target)
    if not Framework.IsMedicSource(src) then return false, Text('err_medics_only') end
    if not target or not Patients.Get(target) then return false, Text('err_no_patient') end
    local s = State.Get(target)
    if s.status ~= 'alive' then return false, Text('err_cannot_discharge') end
    Patients.Discharge(target, src)
    TriggerClientEvent('XS-Medical:client:leaveBed', target)
    return true
end)

lib.callback.register('XS-Medical:server:duty', function(src, placeId, pointId)
    local _, point = placePoint(placeId, 'duty', pointId)
    if not point or not Hospitals.Near(src, point, 3.0) then return false, Text('err_too_far') end
    local job = Framework.GetJob(src)
    if not Util.IsMedicJob(job) then return false, Text('err_medics_only') end
    Framework.SetDuty(src, not job.onDuty)
    return true, not job.onDuty
end)

lib.callback.register('XS-Medical:server:stash', function(src, placeId, pointId)
    local place, point = placePoint(placeId, 'storage', pointId)
    if not point or not Hospitals.Near(src, point, 3.0) then return false, Text('err_too_far') end
    local job = Framework.GetJob(src)
    if not Framework.IsMedic(job) then return false, Text('err_medics_only') end
    if (job.grade or 0) < (point.grade or 0) and not job.isBoss then return false, Text('err_grade') end
    local id = ('xsmedical_%s_%s'):format(place.id, point.id)
    local mode = Inventory.OpenStash(src, id, point.label, point.slots, point.weight)
    return true, { mode = mode, id = id, label = point.label, slots = point.slots, weight = point.weight }
end)

local function cabinetItems(job)
    local out = {}
    for _, entry in ipairs(Config.Cabinet or {}) do
        if (job.grade or 0) >= (entry.grade or 0) or job.isBoss then
            out[#out + 1] = { item = entry.item, label = Inventory.Label(entry.item), price = entry.price or 0 }
        end
    end
    return out
end

lib.callback.register('XS-Medical:server:cabinet', function(src, placeId, pointId)
    local _, point = placePoint(placeId, 'cabinet', pointId)
    if not point or not Hospitals.Near(src, point, 3.0) then return false, Text('err_too_far') end
    local job = Framework.GetJob(src)
    if not Framework.IsMedic(job) then return false, Text('err_medics_only') end
    return true, cabinetItems(job)
end)

lib.callback.register('XS-Medical:server:cabinetTake', function(src, placeId, pointId, item, qty)
    local _, point = placePoint(placeId, 'cabinet', pointId)
    if not point or not Hospitals.Near(src, point, 3.0) then return false, Text('err_too_far') end
    local job = Framework.GetJob(src)
    if not Framework.IsMedic(job) then return false, Text('err_medics_only') end
    qty = Util.Clamp(math.floor(tonumber(qty) or 1), 1, 20)
    local entry
    for _, e in ipairs(cabinetItems(job)) do
        if e.item == item then entry = e break end
    end
    if not entry then return false, Text('err_not_stocked') end
    if not Inventory.CanCarry(src, entry.item, qty) then return false, Text('err_full') end
    local cost = (entry.price or 0) * qty
    if cost > 0 and not Framework.Charge(src, cost, 'bank', 'medical-supplies') then return false, Text('err_no_money', { amount = cost }) end
    if not Inventory.Add(src, entry.item, qty) then return false, Text('err_full') end
    TriggerClientEvent('XS-Medical:client:invalidateInventory', src)
    return true, Text('cabinet_took', { qty = qty, label = entry.label })
end)

local VEHICLE_TYPES = { automobile = true, heli = true, plane = true, bike = true, boat = true }

lib.callback.register('XS-Medical:server:garage', function(src, placeId, pointId, kind)
    kind = kind == 'helipad' and 'helipad' or 'garage'
    local _, point = placePoint(placeId, kind, pointId)
    if not point or not Hospitals.Near(src, point, 4.0) then return false, Text('err_too_far') end
    local job = Framework.GetJob(src)
    if not Framework.IsMedic(job) then return false, Text('err_medics_only') end
    if (job.grade or 0) < (point.grade or 0) and not job.isBoss then return false, Text('err_grade') end
    local labels = {}
    for _, v in ipairs(Framework.Vehicles()) do labels[v.model] = v.label end
    local list = {}
    local models = #point.vehicles > 0 and point.vehicles or (kind == 'helipad' and (Config.Vehicles.helicopters or {}) or (Config.Vehicles.defaults or {}))
    for _, model in ipairs(models) do list[#list + 1] = { model = model, label = labels[model] or model } end
    return true, list
end)

local function plate()
    local prefix = ((Config.Vehicles or {}).platePrefix or 'EMS'):upper():sub(1, 4)
    local digits = 8 - #prefix
    local number = tostring(math.random(10 ^ (digits - 1), 10 ^ digits - 1))
    return prefix .. number
end

lib.callback.register('XS-Medical:server:spawnVehicle', function(src, placeId, pointId, kind, model, vehicleType)
    kind = kind == 'helipad' and 'helipad' or 'garage'
    local _, point = placePoint(placeId, kind, pointId)
    if not point or not Hospitals.Near(src, point, 4.0) then return false, Text('err_too_far') end
    local job = Framework.GetJob(src)
    if not Framework.IsMedic(job) then return false, Text('err_medics_only') end
    if (job.grade or 0) < (point.grade or 0) and not job.isBoss then return false, Text('err_grade') end

    local models = #point.vehicles > 0 and point.vehicles or (kind == 'helipad' and (Config.Vehicles.helicopters or {}) or (Config.Vehicles.defaults or {}))
    local allowed = false
    for _, m in ipairs(models) do if m == model then allowed = true break end end
    if not allowed then return false, Text('err_vehicle_not_here') end
    vehicleType = VEHICLE_TYPES[vehicleType] and vehicleType or (kind == 'helipad' and 'heli' or 'automobile')

    for netId, entry in pairs(Hospitals.vehicles) do
        if entry.owner == src then
            local old = NetworkGetEntityFromNetworkId(netId)
            if old ~= 0 and DoesEntityExist(old) then DeleteEntity(old) end
            Hospitals.vehicles[netId] = nil
        end
    end

    local spawn = point.spawn or point
    local hash = joaat(model)
    local vehicle = 0
    pcall(function() vehicle = CreateVehicleServerSetter(hash, vehicleType, spawn.x, spawn.y, spawn.z, spawn.w or 0.0) end)
    if not vehicle or vehicle == 0 then
        pcall(function() vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, true) end)
    end
    local waited = 0
    while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_spawn_failed') end

    local text = plate()
    SetVehicleNumberPlateText(vehicle, text)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    Hospitals.vehicles[netId] = { owner = src, place = placeId, point = pointId, model = model }
    Entity(vehicle).state:set('xsmVehicle', true, true)
    Entity(vehicle).state:set('fuel', (Config.Vehicles or {}).fuel or 100.0, true)
    SetTimeout(600, function()
        if DoesEntityExist(vehicle) then Keys.Give(src, vehicle, text) end
    end)
    return true, { netId = netId, plate = text }
end)

lib.callback.register('XS-Medical:server:storeVehicle', function(src, netId)
    netId = tonumber(netId)
    local entry = netId and Hospitals.vehicles[netId]
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if not entry then
        if vehicle == 0 or not Entity(vehicle).state.xsmVehicle then return false, Text('err_not_ours') end
    end
    if not Framework.IsMedicSource(src) then return false, Text('err_medics_only') end
    local ped = GetPlayerPed(src)
    if vehicle ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > ((Config.Vehicles or {}).returnDistance or 25.0) then
        return false, Text('err_too_far')
    end
    if vehicle ~= 0 and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    Hospitals.vehicles[netId] = nil
    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    Hospitals.FreeBedOf(src)
    for netId, entry in pairs(Hospitals.vehicles) do
        if entry.owner == src then
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
            Hospitals.vehicles[netId] = nil
        end
    end
end)
