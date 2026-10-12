Bed = { active = false, safe = false, bed = nil, untilAt = 0, treat = false }

local LIE = { dict = 'anim@gangops@morgue@table@', clip = 'body_search' }
local GETUP = { dict = 'switch@franklin@bed', clip = 'sleep_getup_rubeyes' }

local function loadDict(dict)
    lib.requestAnimDict(dict, 3000)
    return HasAnimDictLoaded(dict)
end

local function lieDown()
    local ped = PlayerPedId()
    local b = Bed.bed
    if not b then return end
    SetEntityCoords(ped, b.x, b.y, b.z + 0.02, false, false, false, false)
    SetEntityHeading(ped, (b.w or 0.0) + 180.0)
    FreezeEntityPosition(ped, true)
    if loadDict(LIE.dict) then
        TaskPlayAnim(ped, LIE.dict, LIE.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function heal()
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local per = (Config.Recovery or {}).bedHealPerSecond or 2
    if health > 0 and health < 200 and Me.state.status == 'alive' and Body.WorstBleed(Me.state.injuries) == 0 then
        SetEntityHealth(ped, math.min(200, health + per))
    end
end

local function loop()
    local healed = false
    local nextHeal = 0
    while Bed.active do
        local ped = PlayerPedId()
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        local now = GetGameTimer()
        if now > nextHeal then
            nextHeal = now + 1000
            heal()
            if not IsEntityPlayingAnim(ped, LIE.dict, LIE.clip, 3) and not (Down.active and Down.status ~= 'down') then lieDown() end
            local left = math.max(0, (Bed.untilAt - now) // 1000)
            UI.Send('bed', 'tick', { left = left, treat = Bed.treat, canLeave = left == 0 and Me.state.status == 'alive' })
            if Bed.treat and left == 0 and not healed then
                healed = true
                CreateThread(function() lib.callback.await('XS-Medical:server:bedDone', false) end)
            end
        end
        if Me.state.status == 'alive' and now >= Bed.untilAt and IsControlJustReleased(0, 38) then
            Bed.Leave()
        end
        Wait(0)
    end
end

function Bed.Start(bed, opts)
    opts = opts or {}
    Bed.bed = bed
    Bed.treat = opts.treat == true or opts.respawn == true
    Bed.untilAt = GetGameTimer() + math.floor((opts.seconds or 0) * 1000)
    Bed.safe = Bed.treat
    local first = not Bed.active
    Bed.active = true
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    lieDown()
    Wait(300)
    DoScreenFadeIn(600)
    UI.Send('bed', 'open', { seconds = opts.seconds or 0, treat = Bed.treat, label = bed.room ~= '' and bed.room or bed.label })
    if first then CreateThread(loop) end
end

function Bed.Leave()
    if not Bed.active then return end
    local ok, err = lib.callback.await('XS-Medical:server:leaveBed', false)
    if not ok then
        if err then Framework.Notify(err, 'error') end
        return
    end
    Bed.Stop()
end

function Bed.Stop(quick)
    if not Bed.active then return end
    Bed.active = false
    Bed.safe = false
    UI.Send('bed', 'close', {})
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    if not quick and Me.state.status == 'alive' and loadDict(GETUP.dict) then
        local b = Bed.bed
        if b then
            local rad = math.rad(b.w or 0.0)
            SetEntityCoords(ped, b.x + math.cos(rad) * 0.9, b.y + math.sin(rad) * 0.9, b.z, false, false, false, false)
        end
        TaskPlayAnim(ped, GETUP.dict, GETUP.clip, 8.0, -8.0, 3500, 0, 0.0, false, false, false)
    end
    Bed.bed = nil
end

RegisterNetEvent('XS-Medical:client:toBed', function(bed, opts)
    if type(bed) ~= 'table' then return end
    if Equip and Equip.Release then Equip.Release() end
    Bed.Start(bed, opts or {})
end)

RegisterNetEvent('XS-Medical:client:leaveBed', function()
    Bed.Stop()
end)
