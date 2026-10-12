Me = { state = { status = 'alive', blood = 100, injuries = {}, vitals = {} }, loaded = false, paused = false, places = {}, beds = {} }

local lastArmour = -1

local function applyBase(info)
    local ped = PlayerPedId()
    SetEntityMaxHealth(ped, 200)
    if info and info.health and info.health > 100 then SetEntityHealth(ped, math.min(200, math.floor(info.health))) end
    if info and info.armour then
        SetPedArmour(ped, math.floor(info.armour))
        lastArmour = math.floor(info.armour)
    end
    if not (Config.Damage or {}).gameRegen then SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0) end
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
end

function Me.SetState(pub)
    if type(pub) ~= 'table' then return end
    local before = Me.state.status
    Me.state = pub
    UI.Send('self', 'state', pub)
    if Effects and Effects.Refresh then Effects.Refresh(pub) end
    if Down and Down.Update and pub.status ~= 'alive' then Down.Update(pub) end
    if before ~= 'alive' and pub.status == 'alive' and Down and Down.active then
        SetTimeout(1500, function()
            if Down.active and Me.state.status == 'alive' then Down.Stop() end
        end)
    end
end

function Me.Hello()
    local info = lib.callback.await('XS-Medical:server:hello', false)
    if not info then return end
    Me.loaded = true
    applyBase(info)
    Me.places = info.places or {}
    Me.beds = info.beds or {}
    if Hospital and Hospital.Build then Hospital.Build(Me.places) end
    Me.SetState(info.state)
end

function Me.IsMedic(ignoreDuty)
    return Framework.IsMedicLocal(ignoreDuty)
end

function Me.Paused()
    if Me.paused then return true end
    local bag = LocalPlayer.state.xsmPaused
    return bag == true
end

RegisterNetEvent('XS-Medical:client:state', function(pub)
    Me.SetState(pub)
end)

RegisterNetEvent('XS-Medical:client:places', function(places)
    Me.places = places or {}
    if Hospital and Hospital.Build then Hospital.Build(Me.places) end
end)

RegisterNetEvent('XS-Medical:client:addHealth', function(amount)
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    if health <= 0 then return end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), health + math.floor(tonumber(amount) or 0)))
end)

RegisterNetEvent('XS-Medical:client:treated', function(note)
    if note then Framework.Notify(note, 'inform') end
end)

RegisterNetEvent('XS-Arena:client:matchStart', function()
    if (Config.Standdown or {}).arena == false then return end
    Me.paused = true
end)

RegisterNetEvent('XS-Arena:client:matchStop', function()
    Me.paused = false
end)

exports('SetPaused', function(paused)
    Me.paused = paused == true
end)

AddStateBagChangeHandler('xsm:beds', 'global', function(_, _, value)
    Me.beds = value or {}
end)

Framework.OnLoaded(function()
    SetTimeout(800, Me.Hello)
end)

Framework.OnUnloaded(function()
    Me.loaded = false
    if Down and Down.active then Down.Stop(true) end
    if Bed and Bed.active then Bed.Stop(true) end
    UI.Send('self', 'reset', {})
end)

Framework.OnJob(function()
    if Hospital and Hospital.Build then Hospital.Build(Me.places) end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if Me.loaded then
            local armour = GetPedArmour(PlayerPedId())
            if armour ~= lastArmour then
                lastArmour = armour
                TriggerServerEvent('XS-Medical:server:armour', armour)
            end
        end
    end
end)

AddEventHandler('onClientResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    if Framework.Loaded() then SetTimeout(1200, Me.Hello) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    ResetPedMovementClipset(ped, 0.0)
    ClearTimecycleModifier()
    AnimpostfxStopAll()
end)
