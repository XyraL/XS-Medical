Down = { active = false, pending = false, status = nil, data = nil, base = 0, escorted = false, carried = false, holding = 0 }

local ANIMS = {
    down = { 'combat@damage@writhe', 'writhe_loop' },
    knockout = { 'dead', 'dead_a' },
    arrest = { 'dead', 'dead_a' },
    dead = { 'dead', 'dead_a' },
    vehicle = { 'veh@low@front_ps@idle_duck', 'sit' },
}

local CRAWL = { dict = 'move_crawl', fwd = 'onfront_fwd', bwd = 'onfront_bwd' }

local KEEP = { 1, 2, 245, 38, 0, 322, 288, 213, 249, 46, 47, 199, 200 }

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function resurrect()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local seat = nil
    if vehicle ~= 0 then
        for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
            if GetPedInVehicleSeat(vehicle, i) == ped then seat = i break end
        end
    end
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.5, heading, true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, 150)
    ClearPedTasksImmediately(ped)
    if vehicle ~= 0 and seat then SetPedIntoVehicle(ped, vehicle, seat) end
    Damage.Reset()
end

local function currentAnim()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return ANIMS.vehicle end
    return ANIMS[Down.status] or ANIMS.down
end

function Down.ClearCrawl()
    if Down.crawlDir or Down.prone then ClearPedTasks(PlayerPedId()) end
    Down.crawlDir, Down.prone, Down.crawling = nil, false, false
end

local function playAnim(force)
    if Down.escorted or Down.carried or (Bed and Bed.active) or (Equip and Equip.onIt) or (Surgery and Surgery.onTable) then return end
    local ped = PlayerPedId()
    if IsPedRagdoll(ped) then return end
    if Down.crawlDir then return end
    if Down.prone and not force then return end
    local anim = currentAnim()
    if not force and IsEntityPlayingAnim(ped, anim[1], anim[2], 3) then return end
    if loadDict(anim[1]) then
        if Down.prone then
            ClearPedTasks(ped)
            Down.prone = false
        end
        TaskPlayAnim(ped, anim[1], anim[2], 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

local function crawlTo(ped, dir, loop)
    local c = GetEntityCoords(ped)
    local anim = dir == 'fwd' and CRAWL.fwd or CRAWL.bwd
    TaskPlayAnimAdvanced(ped, CRAWL.dict, anim, c.x, c.y, c.z, 0.0, 0.0, GetEntityHeading(ped), 1.0, 1.0, 1.0, loop and 47 or 46, 1.0, 0, 0)
end

local function secondsLeft(key)
    local d = Down.data
    if not d or d[key] == nil then return nil end
    return math.max(0, d[key] - (GetGameTimer() - Down.base) // 1000)
end

function Down.Seconds()
    return {
        bleedOut = secondsLeft('bleedOutIn'), arrest = secondsLeft('arrestLeft'),
        respawn = secondsLeft('respawnIn'), wake = secondsLeft('wakeIn'),
    }
end

local function pushUI(open)
    if not Down.data then return end
    local payload = {
        status = Down.status, seconds = Down.Seconds(), vitals = Down.data.vitals, rhythm = Down.data.rhythm,
        cause = Down.data.cause, injuries = Down.data.injuries, ems = Down.data.ems, blood = Down.data.blood,
    }
    UI.Send('down', open and 'open' or 'update', payload)
end

local function disarm()
    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    TriggerEvent('ox_inventory:disarm', PlayerId(), true)
    LocalPlayer.state:set('invBusy', true, false)
end

function Down.Fatal(cause)
    if Me.Paused() then return end
    if Down.active then
        resurrect()
        playAnim(true)
        return
    end
    if Down.pending then return end
    Down.pending = true
    CreateThread(function()
        Wait(250)
        local ped = PlayerPedId()
        local waited = 0
        while (GetEntitySpeed(ped) > 0.5 or IsPedRagdoll(ped)) and waited < 1500 do
            Wait(100)
            waited = waited + 100
        end
        resurrect()
        local ok = lib.callback.await('XS-Medical:server:fatal', false, { cause = cause })
        Down.pending = false
        if not ok and not Down.active then
            local p = PlayerPedId()
            SetEntityHealth(p, 120)
            ClearPedTasks(p)
        end
    end)
end

function Down.TopUp()
    if not Down.active then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        resurrect()
        playAnim(true)
        return
    end
    if GetEntityHealth(ped) < 130 then SetEntityHealth(ped, 150) end
    Damage.Reset()
end

local function loop()
    local holdStart = nil
    local lastUi = 0
    while Down.active do
        local ped = PlayerPedId()
        DisableAllControlActions(0)
        for _, control in ipairs(KEEP) do EnableControlAction(0, control, true) end
        DisablePlayerFiring(PlayerId(), true)
        local now = GetGameTimer()

        local seconds = Down.Seconds()

        if Down.status == 'down' and (Config.Down or {}).crawl and not Down.escorted and not Down.carried
            and not (Bed and Bed.active) and not IsPedInAnyVehicle(ped, false) and not (Equip and Equip.onIt) and not (Surgery and Surgery.onTable) then
            EnableControlAction(0, 32, true)
            EnableControlAction(0, 33, true)
            EnableControlAction(0, 34, true)
            EnableControlAction(0, 35, true)
            local want = nil
            if IsControlPressed(0, 32) then want = 'fwd' elseif IsControlPressed(0, 33) then want = 'bwd' end
            if IsControlPressed(0, 34) then SetEntityHeading(ped, GetEntityHeading(ped) + 1.2) end
            if IsControlPressed(0, 35) then SetEntityHeading(ped, GetEntityHeading(ped) - 1.2) end
            if want ~= Down.crawlDir and loadDict(CRAWL.dict) then
                if want then
                    crawlTo(ped, want, true)
                    Down.prone = false
                else
                    crawlTo(ped, Down.crawlDir, false)
                    Down.prone = true
                end
                Down.crawlDir = want
                Down.crawling = want ~= nil
            end
        elseif Down.crawlDir or Down.prone then
            Down.ClearCrawl()
        end

        if IsDisabledControlJustReleased(0, 47) or IsControlJustReleased(0, 47) then
            CreateThread(function()
                local ok, message = lib.callback.await('XS-Medical:server:callHelp', false)
                UI.Send('down', 'called', { ok = ok, message = message })
            end)
        end

        if seconds.respawn == 0 and Down.status ~= 'knockout' and not Down.respawnBlocked then
            if IsControlPressed(0, 38) then
                holdStart = holdStart or now
                local need = ((Config.Down or {}).holdToRespawn or 3) * 1000
                Down.holding = math.min(1, (now - holdStart) / need)
                if now - holdStart >= need then
                    holdStart = nil
                    Down.holding = 0
                    CreateThread(function() lib.callback.await('XS-Medical:server:respawn', false) end)
                    Wait(1500)
                end
            elseif holdStart then
                holdStart = nil
                Down.holding = 0
            end
        end

        if now - lastUi > 500 then
            lastUi = now
            playAnim(false)
            UI.Send('down', 'tick', { seconds = seconds, holding = Down.holding })
            if GetEntityHealth(ped) < 130 and not IsEntityDead(ped) then SetEntityHealth(ped, 150) end
        end
        Wait(0)
    end
end

function Down.Start(pub)
    Down.data = pub
    Down.base = GetGameTimer()
    Down.status = pub.status
    if Down.active then
        pushUI(false)
        playAnim(true)
        return
    end
    Down.active = true
    Down.pending = false
    Down.crawlDir, Down.prone, Down.crawling = nil, false, false
    disarm()
    if UI.HasFocus('tablet') and Tablet and Tablet.Close then Tablet.Close() end
    pushUI(true)
    playAnim(true)
    TriggerEvent('qbx_medical:client:onPlayerLaststand')
    TriggerServerEvent('qbx_medical:server:onPlayerLaststand')
    Down.laststand = true
    if pub and (pub.status == 'arrest' or pub.status == 'dead') then
        Down.laststand = false
        TriggerServerEvent('qbx_medical:server:onPlayerLaststandEnd')
        TriggerEvent('qbx_medical:client:onPlayerDied')
        TriggerServerEvent('qbx_medical:server:onPlayerDied')
    end
    CreateThread(loop)
end

function Down.Update(pub)
    if not Down.active then
        Down.Start(pub)
        return
    end
    local changed = Down.status ~= pub.status
    Down.data = pub
    Down.base = GetGameTimer()
    Down.status = pub.status
    pushUI(false)
    if changed then
        Down.ClearCrawl()
        playAnim(true)
        if pub.status == 'arrest' then
            if Down.laststand then
                Down.laststand = false
                TriggerServerEvent('qbx_medical:server:onPlayerLaststandEnd')
            end
            TriggerEvent('qbx_medical:client:onPlayerDied')
            TriggerServerEvent('qbx_medical:server:onPlayerDied')
        end
    end
end

function Down.Stop(silent)
    if not Down.active then return end
    Down.active = false
    Down.crawlDir, Down.prone, Down.crawling = nil, false, false
    Down.escorted, Down.carried = false, false
    Down.holding = 0
    if Down.laststand then
        Down.laststand = false
        TriggerServerEvent('qbx_medical:server:onPlayerLaststandEnd')
    end
    LocalPlayer.state:set('invBusy', false, false)
    UI.Send('down', 'close', {})
    if not silent then
        local ped = PlayerPedId()
        ClearPedTasks(ped)
    end
end

RegisterNetEvent('XS-Medical:client:down', function(pub)
    if type(pub) ~= 'table' then return end
    Me.state = pub
    if pub.status == 'alive' then
        Down.Stop()
        return
    end
    Down.Update(pub)
end)

RegisterNetEvent('XS-Medical:client:revived', function(info)
    info = info or {}
    local wasActive = Down.active
    Down.Stop(true)
    Down.pending = false
    local ped = PlayerPedId()
    if IsEntityDead(ped) then resurrect() ped = PlayerPedId() end
    SetEntityInvincible(ped, false)
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, math.min(200, math.floor(tonumber(info.health) or 150)))
    if info.mode == 'full' then ClearPedBloodDamage(ped) end
    ResetPedMovementClipset(ped, 0.0)
    SetPlayerSprint(PlayerId(), true)
    TriggerEvent('police:client:DeEscort')
    Damage.Reset()
    if wasActive and not IsPedInAnyVehicle(ped, false) and not (Bed and Bed.active) then
        ClearPedTasks(ped)
        if loadDict('get_up@directional@movement@from_knees@action') then
            TaskPlayAnim(ped, 'get_up@directional@movement@from_knees@action', 'getup_r_0', 8.0, -8.0, -1, 0, 0.0, false, false, false)
        end
    end
end)

RegisterNetEvent('XS-Medical:client:respawn', function(spot)
    spot = spot or {}
    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(10) end
    Down.Stop(true)
    if Equip and Equip.Release then Equip.Release() end
    TriggerEvent('police:client:DeEscort')
    local meta = Framework.PlayerData().metadata or {}
    if meta.ishandcuffed then TriggerEvent('police:client:GetCuffed', -1) end
    local c = spot.coords or {}
    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(c.x or 0.0, c.y or 0.0, (c.z or 0.0) + 0.3, c.w or 0.0, true, false)
    ped = PlayerPedId()
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    ResetPedMovementClipset(ped, 0.0)
    Damage.Reset()
    if spot.inBed and Bed then
        Bed.Start({ x = c.x, y = c.y, z = c.z, w = c.w, place = spot.place, id = spot.bed, prop = spot.prop }, { seconds = spot.recover or 20, respawn = true })
    else
        SetEntityCoords(ped, c.x or 0.0, c.y or 0.0, c.z or 0.0, false, false, false, false)
        SetEntityHeading(ped, c.w or 0.0)
    end
    Wait(400)
    DoScreenFadeIn(800)
end)

AddEventHandler('hospital:client:isEscorted', function(state)
    Down.escorted = state == true
    if not Down.escorted then playAnim(true) end
end)

exports('IsDown', function() return Down.active end)
