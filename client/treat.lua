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
        disable = { move = true, car = true, combat = true }, anim = { dict = anim.dict, clip = anim.clip, flag = anim.flag },
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
                anim = { dict = ANIMS.pill.dict, clip = ANIMS.pill.clip, flag = ANIMS.pill.flag },
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

local function pedTarget(entity)
    return Treat.ServerId(entity)
end

function Treat.RegisterTargets()
    Target.AddPlayers({
        {
            label = Text('opt_examine'), icon = 'fas fa-stethoscope', distance = 2.5,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if not id then return end
                if Me.IsMedic() then Tablet.Open('patient', id) else Treat.Glance(id) end
            end,
        },
        {
            label = Text('opt_treat'), icon = 'fas fa-kit-medical', distance = 2.5,
            canInteract = function(entity)
                local id = pedTarget(entity)
                local bag = Treat.BagOf(id)
                return bag.status ~= nil
            end,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if id then Treat.Menu(id) end
            end,
        },
        {
            label = Text('opt_cpr'), icon = 'fas fa-heart-pulse', distance = 2.0,
            canInteract = function(entity) return Treat.StatusOf(pedTarget(entity)) == 'arrest' end,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if id then Treat.Run(id, 'cpr') end
            end,
        },
        {
            label = Text('opt_checkid'), icon = 'fas fa-id-card', distance = 2.0,
            canInteract = function(entity)
                if not Me.IsMedic() then return false end
                return Treat.StatusOf(pedTarget(entity)) ~= 'alive'
            end,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if id then Treat.Run(id, 'checkid') end
            end,
        },
        {
            label = Text('opt_carry'), icon = 'fas fa-person-walking', distance = 2.0,
            canInteract = function(entity) return Treat.StatusOf(pedTarget(entity)) ~= 'alive' and not Equip.carrying end,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if id then Equip.Carry(id) end
            end,
        },
        {
            label = Text('opt_stretcher'), icon = 'fas fa-bed-pulse', distance = 3.0,
            canInteract = function() return Equip.held ~= nil end,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if id then Equip.PlaceOn(id) end
            end,
        },
        {
            label = Text('opt_bed'), icon = 'fas fa-bed', distance = 3.0,
            canInteract = function() return Me.IsMedic() and Hospital.NearestFreeBed(4.0) ~= nil end,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if id then Hospital.PutInBed(id) end
            end,
        },
        {
            label = Text('opt_vehicle_in'), icon = 'fas fa-truck-medical', distance = 3.0,
            canInteract = function(entity)
                local id = pedTarget(entity)
                return Treat.StatusOf(id) ~= 'alive' and lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 6.0, false) ~= nil
            end,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if id then Equip.LoadInto(id) end
            end,
        },
        {
            label = Text('opt_bill'), icon = 'fas fa-file-invoice-dollar', distance = 3.0,
            canInteract = function() return Me.IsMedic() end,
            onSelect = function(entity)
                local id = pedTarget(entity)
                if id then Tablet.Bill(id) end
            end,
        },
    })
end
