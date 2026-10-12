local function provide(resource, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB) setCB(fn) end)
end

local function qbx(name, fn)
    provide('qbx_medical', name, fn)
end

local status = function() return Me.state.status or 'alive' end

qbx('IsDead', function() return status() == 'arrest' or status() == 'dead' end)
qbx('IsLaststand', function() return status() == 'down' or status() == 'knockout' end)
qbx('GetDeathTime', function() return (Down.active and Down.Seconds().arrest) or 0 end)
qbx('GetLaststandTime', function() return (Down.active and (Down.Seconds().bleedOut or Down.Seconds().wake)) or 0 end)
qbx('IncrementDeathTime', function() end)
qbx('IncrementLaststandTime', function() end)
qbx('GetRespawnHoldTimeDeprecated', function()
    local hold = (Config.Down or {}).holdToRespawn or 3
    return math.ceil(hold * (1 - (Down.holding or 0)))
end)
qbx('MakePedLimp', function() Effects.limp = true end)
qbx('SendBleedAlert', function() end)
qbx('PlayDeadAnimation', function() if Down.active then Down.Update(Me.state) end end)
qbx('KillPlayer', function() SetEntityHealth(PlayerPedId(), 0) end)
qbx('StartLastStand', function() SetEntityHealth(PlayerPedId(), 0) end)
qbx('AllowRespawn', function() Down.respawnBlocked = false end)
qbx('DisableRespawn', function() Down.respawnBlocked = true end)
qbx('EnableDamageEffects', function() Effects.suspended = false end)
qbx('DisableDamageEffects', function() Effects.suspended = true end)
qbx('MakePlayerBlackout', function()
    DoScreenFadeOut(500)
    Wait(2000)
    DoScreenFadeIn(500)
end)
qbx('MakePlayerFadeOut', function()
    DoScreenFadeOut(500)
    Wait(500)
    DoScreenFadeIn(500)
end)
qbx('RemoveBleed', function(level) TriggerServerEvent('XS-Medical:server:compatRemoveBleed', tonumber(level) or 1) end)
qbx('EnableBleeding', function() end)
qbx('DisableBleeding', function() end)

provide('qb-ambulancejob', 'PainKillerLoop', function(amount)
    TriggerServerEvent('XS-Medical:server:compatPainkiller', tonumber(amount) or 1)
end)

exports('GetState', function() return Me.state end)
exports('GetVitals', function() return Me.state.vitals end)
exports('IsDead', function() return status() == 'arrest' or status() == 'dead' end)
exports('IsLaststand', function() return status() == 'down' or status() == 'knockout' end)

local function askRevive()
    lib.callback.await('XS-Medical:server:compatRevive', false)
end

RegisterNetEvent('hospital:client:Revive', function() CreateThread(askRevive) end)
RegisterNetEvent('qbx_medical:client:playerRevived', function() CreateThread(askRevive) end)

RegisterNetEvent('hospital:client:HealInjuries', function(kind)
    CreateThread(function() lib.callback.await('XS-Medical:server:compatHeal', false, kind == 'full' and 'full' or 'partial') end)
end)

RegisterNetEvent('qbx_medical:client:heal', function(kind)
    CreateThread(function() lib.callback.await('XS-Medical:server:compatHeal', false, kind == 'full' and 'full' or 'partial') end)
end)

RegisterNetEvent('hospital:client:KillPlayer', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

lib.callback.register('qbx_medical:client:killPlayer', function()
    SetEntityHealth(PlayerPedId(), 0)
    return true
end)

RegisterNetEvent('hospital:client:adminHeal', function()
    local ped = PlayerPedId()
    if GetEntityHealth(ped) > 0 and not Down.active then SetEntityHealth(ped, GetEntityMaxHealth(ped)) end
end)

RegisterNetEvent('hospital:client:SetPain', function()
    TriggerServerEvent('XS-Medical:server:compatPain')
end)

RegisterNetEvent('hospital:client:ambulanceAlert', function(coords, text)
    if not Me.IsMedic() then return end
    local c = coords and { x = coords.x, y = coords.y, z = coords.z } or nil
    UI.Send('pager', 'page', { title = Text('page_alert_title'), text = text or '', coords = c })
end)

RegisterNetEvent('hospital:client:RespawnAtHospital', function()
    if Down.active and (Down.Seconds().respawn or 1) == 0 then
        CreateThread(function() lib.callback.await('XS-Medical:server:respawn', false) end)
    end
end)

RegisterNetEvent('hospital:client:CheckStatus', function()
    local target = Treat.Nearest(5.0, false)
    if not target then return Framework.Notify(Text('err_no_patient_near'), 'error') end
    if Me.IsMedic() then Tablet.Open('patient', target) else Treat.Glance(target) end
end)

RegisterNetEvent('hospital:client:TreatWounds', function()
    local target = Treat.Nearest(5.0, false)
    if not target then return Framework.Notify(Text('err_no_patient_near'), 'error') end
    Treat.Menu(target)
end)

RegisterNetEvent('hospital:client:RevivePlayer', function()
    local target = Treat.Nearest(5.0, true)
    if not target then return Framework.Notify(Text('err_no_patient_near'), 'error') end
    local key = Me.IsMedic() and Inventory.Count((Config.Supplies.adrenaline or {}).item) > 0 and 'adrenaline' or 'firstaid'
    Treat.Run(target, key)
end)

local ITEM_EVENTS = {
    ['hospital:client:UseIfaks'] = 'ifaks', ['hospital:client:UseBandage'] = 'bandage',
    ['hospital:client:UsePainkillers'] = 'painkillers', ['hospital:client:UseFirstAid'] = 'firstaid',
}

for event, key in pairs(ITEM_EVENTS) do
    RegisterNetEvent(event, function()
        local supply = Config.Supplies[key]
        if supply then Treat.UseItem(supply.item) end
    end)
end
