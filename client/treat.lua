Treat = { busy = false }

local ANIMS = {
    other = { dict = 'amb@medic@standing@tendtodead@base', clip = 'base', flag = 1 },
    kneel = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 },
    self = { dict = 'anim@amb@business@weed@weed_inspecting_high_dry@', clip = 'weed_inspecting_high_base_inspector', flag = 49 },
    pill = { dict = 'mp_suicide', clip = 'pill', flag = 49 },
    cpr = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest', flag = 1 },
    inject = { dict = 'anim@heists@narcotics@funding@gang_idle', clip = 'gang_chatting_idle01', flag = 49 },
    look = { dict = 'amb@medic@standing@kneel@idle_a', clip = 'idle_a', flag = 1 },
}

local PILL = { painkillers = true, oxycodone = true, amoxicillin = true, diazepam = true }

function Treat.ServerId(ped)
    if not ped or ped == 0 then return nil end
    local player = NetworkGetPlayerIndexFromPed(ped)
    if player == -1 then return nil end
    return GetPlayerServerId(player)
end

function Treat.BagOf(serverId)
    if not serverId then return {} end
    return Player(serverId).state.xsm or {}
end

function Treat.StatusOf(serverId)
    return Treat.BagOf(serverId).status or 'alive'
end

function Treat.Nearest(range, needDown)
    local me = PlayerPedId()
    local coords = GetEntityCoords(me)
    local best, bestDist = nil, range or 2.5
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= me and ped ~= 0 then
            local dist = #(GetEntityCoords(ped) - coords)
            if dist < bestDist then
                local id = GetPlayerServerId(player)
                if not needDown or Treat.StatusOf(id) ~= 'alive' then best, bestDist = id, dist end
            end
        end
    end
    return best, bestDist
end

local function supplyKeyFor(item)
    for key, s in pairs(Config.Supplies or {}) do
        if s.item == item then return key end
    end
    return nil
end

local function animFor(key, self)
    if key == 'cpr' or key == 'defibrillator' then return ANIMS.cpr end
    if key == 'checkid' or key == 'examine' then return ANIMS.look end
    if self then
        if PILL[key] then return ANIMS.pill end
        return ANIMS.self
    end
    if key == 'morphine' or key == 'adrenaline' or key == 'saline' then return ANIMS.kneel end
    return ANIMS.other
end

function Treat.Run(target, key, injury)
    if Treat.busy then return false end
    Treat.busy = true
    local me = GetPlayerServerId(PlayerId())
    target = target or me
    local ok, info = lib.callback.await('XS-Medical:server:treatBegin', false, { target = target, supply = key, injury = injury })
    if not ok then
        Treat.busy = false
        Framework.Notify(info or Text('err_failed'), 'error')
        return false
    end

    if target ~= me then
        local targetPed = GetPlayerPed(GetPlayerFromServerId(target))
        if targetPed ~= 0 then TaskTurnPedToFaceEntity(PlayerPedId(), targetPed, 600) Wait(500) end
    end

    local anim = animFor(key, target == me)
    local done = lib.progressBar({
        duration = math.floor((info.seconds or 5) * 1000), label = info.label, useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = Util.LoadAnim(anim.dict, 3000) and { dict = anim.dict, clip = anim.clip, flag = anim.flag } or nil,
    })
    ClearPedTasks(PlayerPedId())
    local finished, note = lib.callback.await('XS-Medical:server:treatEnd', false, done == true)
    Treat.busy = false
    if done and finished and note then
        Framework.Notify(note, 'success')
    elseif done and not finished and note then
        Framework.Notify(note, 'error')
    end
    if Tablet and Tablet.open then Tablet.RefreshPatient() end
    return finished
end

local function chooseTarget(key)
    local supply = Config.Supplies[key]
    local other = Treat.Nearest(2.5, false)
    if supply.self and not other then return GetPlayerServerId(PlayerId()) end
    if not supply.self then
        if not other then
            Framework.Notify(Text('err_no_patient_near'), 'error')
            return nil
        end
        return other
    end
    local picked = promise.new()
    lib.registerContext({
        id = 'xs_medical_target', title = Text('supply_' .. key),
        options = {
            { title = Text('use_on_self'), icon = 'user', onSelect = function() picked:resolve('self') end },
            { title = Text('use_on_other'), icon = 'user-nurse', onSelect = function() picked:resolve('other') end },
        },
        onExit = function() picked:resolve(nil) end,
    })
    lib.showContext('xs_medical_target')
    local choice = Citizen.Await(picked)
    if choice == 'self' then return GetPlayerServerId(PlayerId()) end
    if choice == 'other' then return other end
    return nil
end

function Treat.UseItem(item)
    if Down.active then return end
    if item and item == (Config.Tablet or {}).item then
        Tablet.Open('patient')
        return
    end
    local key = supplyKeyFor(item)
    if key then
        local target = chooseTarget(key)
        if target then Treat.Run(target, key) end
        return
    end
    for _, med in ipairs(Config.Medicines or {}) do
        if med.item == item then
            local done = lib.progressBar({
                duration = 2500, label = med.label, canCancel = true, disable = { combat = true },
                anim = Util.LoadAnim(ANIMS.pill.dict, 3000) and { dict = ANIMS.pill.dict, clip = ANIMS.pill.clip, flag = ANIMS.pill.flag } or nil,
            })
            if done then
                local ok, message = lib.callback.await('XS-Medical:server:takeMedicine', false, item)
                Framework.Notify(message or '', ok and 'success' or 'error')
            end
            return
        end
    end
end

RegisterNetEvent('XS-Medical:client:useItem', function(item)
    Treat.UseItem(item)
end)

Framework.OnUnloaded(function()
    if Treat.busy and lib.progressActive() then lib.cancelProgress() end
end)

exports('useItem', function(data)
    local name = type(data) == 'table' and data.name or data
    Treat.UseItem(name)
end)

function Treat.Menu(target)
    local options = {}
    local status = Treat.StatusOf(target)
    local medic = Me.IsMedic()
    for key, s in pairs(Config.Supplies or {}) do
        if (s.anyone or medic) and Inventory.Count(s.item) > 0 then
            options[#options + 1] = {
                title = Text('supply_' .. key), description = Text('supply_hint_' .. key), icon = 'kit-medical',
                onSelect = function() CreateThread(function() Treat.Run(target, key) end) end,
            }
        end
    end
    if status == 'arrest' then
        options[#options + 1] = { title = Text('supply_cpr'), icon = 'heart-pulse', onSelect = function() CreateThread(function() Treat.Run(target, 'cpr') end) end }
    end
    if #options == 0 then
        Framework.Notify(Text('err_no_supplies'), 'error')
        return
    end
    table.sort(options, function(a, b) return a.title < b.title end)
    lib.registerContext({ id = 'xs_medical_treat', title = Text('treat_menu_title'), options = options })
    lib.showContext('xs_medical_treat')
end

function Treat.Glance(target)
    local info = lib.callback.await('XS-Medical:server:glance', false, target)
    if not info then return end
    local lines = {}
    for _, line in ipairs(info.lines or {}) do lines[#lines + 1] = '• ' .. line end
    lib.alertDialog({ header = info.header or Text('glance_title'), content = #lines > 0 and table.concat(lines, '  \n') or Text('glance_fine'), centered = true })
end


local supplyCheck = { at = 0, has = false }

function Treat.HasSupplies()
    local now = GetGameTimer()
    if now - supplyCheck.at < 2000 then return supplyCheck.has end
    supplyCheck.at = now
    supplyCheck.has = false
    local medic = Me.IsMedic()
    for _, s in pairs(Config.Supplies or {}) do
        if (s.anyone or medic) and Inventory.Count(s.item) > 0 then
            supplyCheck.has = true
            break
        end
    end
    return supplyCheck.has
end

local function pedTarget(entity)
    return Treat.ServerId(entity)
end

local function down(entity)
    return Treat.StatusOf(pedTarget(entity)) ~= 'alive'
end

local function free(entity)
    return not IsEntityAttached(entity) and not IsPedInAnyVehicle(entity, false)
end

local function run(fn)
    return function(entity)
        local id = pedTarget(entity)
        if id then fn(id, entity) end
    end
end

function Treat.RegisterTargets()
    Target.AddPlayers({
        {
            label = Text('opt_examine'), icon = 'fas fa-stethoscope', distance = 2.5,
            onSelect = run(function(id)
                if Me.IsMedic() then Tablet.Open('patient', id) else Treat.Glance(id) end
            end),
        },
        {
            label = Text('opt_treat'), icon = 'fas fa-kit-medical', distance = 2.5,
            canInteract = function() return Me.IsMedic() or Treat.HasSupplies() end,
            onSelect = run(function(id) Treat.Menu(id) end),
        },
        {
            label = Text('opt_cpr'), icon = 'fas fa-heart-pulse', distance = 2.0,
            canInteract = function(entity) return Treat.StatusOf(pedTarget(entity)) == 'arrest' end,
            onSelect = run(function(id) Treat.Run(id, 'cpr') end),
        },
        {
            label = Text('opt_checkid'), icon = 'fas fa-id-card', distance = 2.0,
            canInteract = function(entity) return Me.IsMedic() and down(entity) end,
            onSelect = run(function(id) Treat.Run(id, 'checkid') end),
        },
        {
            label = Text('opt_stretcher'), icon = 'fas fa-bed-pulse', distance = 3.0,
            canInteract = function(entity) return Me.IsMedic() and free(entity) and Equip.Nearest('stretcher', 4.0, true) ~= nil end,
            onSelect = run(function(id) Equip.PlaceOn(id, 'stretcher') end),
        },
        {
            label = Text('opt_wheelchair'), icon = 'fas fa-wheelchair', distance = 3.0,
            canInteract = function(entity) return free(entity) and Equip.Nearest('wheelchair', 3.5, true) ~= nil end,
            onSelect = run(function(id) Equip.PlaceOn(id, 'wheelchair') end),
        },
        {
            label = Text('opt_take_off'), icon = 'fas fa-person-walking-arrow-right', distance = 3.0,
            canInteract = function(entity) return Equip.Under(entity) ~= nil end,
            onSelect = run(function(id) Equip.TakeOff(id) end),
        },
        {
            label = Text('opt_carry'), icon = 'fas fa-person-walking', distance = 2.0,
            canInteract = function(entity) return down(entity) and free(entity) and not Equip.carrying and not Equip.held end,
            onSelect = run(function(id) Equip.Carry(id) end),
        },
        {
            label = Text('opt_bed'), icon = 'fas fa-bed', distance = 3.0,
            canInteract = function() return Me.IsMedic() and Hospital.NearestFreeBed(5.0) ~= nil end,
            onSelect = run(function(id) Hospital.PutInBed(id) end),
        },
        {
            label = Text('opt_surgery'), icon = 'fas fa-syringe', distance = 3.0,
            canInteract = function() return Me.IsMedic() and Hospital.NearestSurgery(5.0) ~= nil end,
            onSelect = run(function(id) Surgery.Begin(id) end),
        },
        {
            label = Text('opt_vehicle_in'), icon = 'fas fa-truck-medical', distance = 3.0,
            canInteract = function(entity)
                if not (down(entity) or Equip.Under(entity)) then return false end
                return lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 6.0, false) ~= nil
            end,
            onSelect = run(function(id) Equip.LoadInto(id) end),
        },
        {
            label = Text('opt_bill'), icon = 'fas fa-file-invoice-dollar', distance = 3.0,
            canInteract = function() return Me.IsMedic() end,
            onSelect = run(function(id) Tablet.Bill(id) end),
        },
    })
end
