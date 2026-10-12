Effects = { limp = false, shaky = 0, concussion = 0, pain = 0, blood = 100, bleeding = 0, suspended = false }

local E = Config.Effects or {}
local clipsetOn = false
local desaturated = false
local nextBlur, nextStumble, nextPulse, nextDrop, nextDrain = 0, 0, 0, 0, 0

local function loadClipset(name)
    if HasAnimSetLoaded(name) then return true end
    RequestAnimSet(name)
    local timeout = GetGameTimer() + 2000
    while not HasAnimSetLoaded(name) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimSetLoaded(name)
end

function Effects.Refresh(pub)
    local limp, shaky, concussion = false, 0, 0
    for _, injury in ipairs(pub.injuries or {}) do
        local splinted = injury.treated and injury.treated.splint
        if Body.Legs[injury.part] and not splinted and (injury.fracture or (injury.sev or 1) >= 2) then limp = true end
        if Body.Arms[injury.part] and not splinted and (injury.fracture or (injury.sev or 1) >= 2) then
            shaky = math.max(shaky, injury.fracture and 2 or 1)
        end
        if injury.kind == 'concussion' then concussion = math.max(concussion, injury.sev or 1) end
    end
    local relieved = (pub.relief or 0) >= 4
    Effects.limp = E.limp ~= false and limp and not relieved
    Effects.shaky = E.shakyAim ~= false and (relieved and 0 or shaky) or 0
    Effects.concussion = E.concussion ~= false and concussion or 0
    Effects.pain = E.pain ~= false and (pub.vitals and pub.vitals.pain or 0) or 0
    Effects.blood = pub.blood or 100
    Effects.bleeding = Body.WorstBleed(pub.injuries)
    Effects.infected = false
    for _, injury in ipairs(pub.injuries or {}) do
        if injury.infected then Effects.infected = true end
    end
end

local function clearClipset(ped)
    if clipsetOn then
        ResetPedMovementClipset(ped, 0.5)
        clipsetOn = false
    end
end

local function female(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01`
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local active = Me.loaded and not Effects.suspended and not (Down and Down.active) and not (Bed and Bed.active) and not Me.Paused()

        if active and Effects.limp then
            sleep = 0
            local set = female(ped) and 'move_f@injured' or 'move_m@injured'
            if not clipsetOn and loadClipset(set) then
                SetPedMovementClipset(ped, set, 0.5)
                clipsetOn = true
            end
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            SetPlayerSprint(PlayerId(), false)
        elseif clipsetOn then
            clearClipset(ped)
            SetPlayerSprint(PlayerId(), true)
        end

        if active and Effects.shaky > 0 then
            sleep = math.min(sleep, 100)
            if IsPlayerFreeAiming(PlayerId()) then
                if not IsGameplayCamShaking() then ShakeGameplayCam('HAND_SHAKE', Effects.shaky == 2 and 1.6 or 0.8) end
            elseif IsGameplayCamShaking() then
                StopGameplayCamShaking(true)
            end
        end

        local now = GetGameTimer()

        if active and Effects.concussion > 0 and now > nextBlur then
            nextBlur = now + math.random(25000, 55000) // Effects.concussion
            AnimpostfxPlay('DrugsDrivingIn', 0, false)
            SetTimeout(2500, function() AnimpostfxStop('DrugsDrivingIn') end)
            if Effects.concussion >= 3 and not IsPedInAnyVehicle(ped, false) and math.random() < 0.3 then
                SetPedToRagdoll(ped, 1500, 2000, 0, false, false, false)
            end
        end

        if active and Effects.pain >= 6 and now > nextPulse then
            nextPulse = now + math.random(14000, 26000)
            AnimpostfxPlay('DeathFailMPIn', 0, false)
            SetTimeout(900, function() AnimpostfxStop('DeathFailMPIn') end)
        end

        if E.bloodLoss ~= false and Me.loaded and Effects.blood < 85 and not Me.Paused() then
            if not desaturated then
                SetTimecycleModifier('rply_saturation_neg')
                desaturated = true
            end
            SetTimecycleModifierStrength(math.min(1.0, (85 - Effects.blood) / 35))
            if active and Effects.blood < 68 and now > nextStumble and GetEntitySpeed(ped) > 1.2 and not IsPedInAnyVehicle(ped, false) then
                nextStumble = now + math.random(25000, 45000)
                SetPedToRagdoll(ped, 1200, 1600, 0, false, false, false)
            end
        elseif desaturated then
            ClearTimecycleModifier()
            desaturated = false
        end

        if active and Effects.infected and (Config.Infection or {}).enabled ~= false and now > nextDrain then
            nextDrain = now + 60000
            local health = GetEntityHealth(ped)
            local drain = (Config.Infection or {}).drainPerMinute or 2
            if health > 110 + drain then SetEntityHealth(ped, health - drain) end
        end

        if (Config.Bleeding or {}).drops ~= false and Me.loaded and Effects.bleeding > 0 and now > nextDrop and not Me.Paused() then
            nextDrop = now + (5000 // Effects.bleeding)
            local c = GetEntityCoords(ped)
            AddDecal(1010, c.x, c.y, c.z - 0.98, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 0.3 + Effects.bleeding * 0.1, 1.0, 1.0, 1.0, 1.0, 120.0, false, false, false)
            if GetEntitySpeed(ped) > 0.5 and math.random() < 0.35 then TriggerServerEvent('XS-Medical:server:bloodDrop') end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if clipsetOn then ResetPedMovementClipset(PlayerPedId(), 0.0) end
    if desaturated then ClearTimecycleModifier() end
    StopGameplayCamShaking(true)
end)
