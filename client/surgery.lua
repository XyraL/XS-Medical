Surgery = { active = false, key = nil, onTable = false }

local TABLE = { dict = 'anim@gangops@morgue@table@', clip = 'body_search' }
local DOCTOR = { dict = 'mini@repair', clip = 'fixing_a_ped' }

local function pickPatient(point)
    local best, bestDist = nil, 4.5
    local origin = vector3(point.x, point.y, point.z)
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= PlayerPedId() then
            local d = #(GetEntityCoords(ped) - origin)
            if d < bestDist then best, bestDist = GetPlayerServerId(player), d end
        end
    end
    return best
end

function Surgery.Begin(target, place, point)
    if Surgery.active then return end
    if not place or not point then
        point, place = Hospital.NearestSurgery(6.0)
        if not point then return Framework.Notify(Text('err_no_table_near'), 'error') end
    end
    target = target or pickPatient(point)
    if not target then return Framework.Notify(Text('err_no_patient_near'), 'error') end
    local ok, info = lib.callback.await('XS-Medical:server:surgeryStart', false, target, place.id, point.id)
    if not ok then return Framework.Notify(info or Text('err_failed'), 'error') end
    Surgery.active = true
    Surgery.key = info.key
    lib.requestAnimDict(DOCTOR.dict, 3000)
    TaskPlayAnim(PlayerPedId(), DOCTOR.dict, DOCTOR.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    UI.Send('surgery', 'open', info)
    UI.Focus('surgery', true)
    CreateThread(function()
        while Surgery.active do
            Wait(2000)
            local vitals = lib.callback.await('XS-Medical:server:surgeryVitals', false, Surgery.key)
            if vitals then UI.Send('surgery', 'vitals', vitals) end
        end
    end)
end

local function finish(results)
    if not Surgery.active then return false end
    Surgery.active = false
    UI.Focus('surgery', false)
    ClearPedTasks(PlayerPedId())
    local ok, summary = lib.callback.await('XS-Medical:server:surgeryEnd', false, Surgery.key, results or {})
    Surgery.key = nil
    if summary then Framework.Notify(summary, ok and 'success' or 'error') end
    return ok, summary
end

UI.Handle('surgery:end', function(payload)
    local ok, summary = finish(type(payload) == 'table' and payload.results or {})
    return ok, summary
end)

UI.OnClose('surgery', function()
    UI.Send('surgery', 'close', {})
    finish({})
end)

RegisterNetEvent('XS-Medical:client:toTable', function(point)
    if type(point) ~= 'table' then return end
    Surgery.onTable = true
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(ped, point.x, point.y, point.z + 0.02, false, false, false, false)
    SetEntityHeading(ped, (point.w or 0.0) + 180.0)
    FreezeEntityPosition(ped, true)
    lib.requestAnimDict(TABLE.dict, 3000)
    TaskPlayAnim(ped, TABLE.dict, TABLE.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    UI.Send('bed', 'open', { seconds = 0, treat = false, label = Text('surgery_under'), sedated = true })
    Wait(300)
    DoScreenFadeIn(400)
end)

RegisterNetEvent('XS-Medical:client:offTable', function()
    if not Surgery.onTable then return end
    Surgery.onTable = false
    UI.Send('bed', 'close', {})
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    if not Down.active then ClearPedTasks(ped) end
end)
