Builder = { open = false, hidden = false, place = nil }

local RATIOS = { board = 9 / 16, sign = 0.625, monitor = 0.625 }

local function show()
    Builder.hidden = false
    UI.Send('builder', 'show', {})
    UI.Focus('builder', true)
end

local function hide()
    Builder.hidden = true
    UI.Send('builder', 'hide', {})
    UI.Focus('builder', false)
end

local function label(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.28, 0.28)
    SetTextFont(0)
    SetTextColour(220, 255, 230, 220)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function spawnBox(p, s, kind)
    local heli = kind == 'helipad'
    local halfW, halfL = heli and 2.2 or 1.25, heli and 2.2 or 3.1
    local h = math.rad(s.w or 0.0)
    local fx, fy = -math.sin(h), math.cos(h)
    local rx, ry = fy, -fx
    local found, ground = GetGroundZFor_3dCoord(s.x, s.y, s.z + 1.5, false)
    local z = ((found == true or found == 1) and ground or s.z) + 0.05
    local c = {
        vector3(s.x + fx * halfL + rx * halfW, s.y + fy * halfL + ry * halfW, z),
        vector3(s.x + fx * halfL - rx * halfW, s.y + fy * halfL - ry * halfW, z),
        vector3(s.x - fx * halfL - rx * halfW, s.y - fy * halfL - ry * halfW, z),
        vector3(s.x - fx * halfL + rx * halfW, s.y - fy * halfL + ry * halfW, z),
    }
    for i = 1, 4 do
        local a, b = c[i], c[i % 4 + 1]
        DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, 47, 191, 107, 255)
    end
    local tip = vector3(s.x + fx * (halfL + 1.2), s.y + fy * (halfL + 1.2), z)
    DrawLine(s.x, s.y, z, tip.x, tip.y, tip.z, 47, 191, 107, 255)
    DrawMarker(heli and 34 or 36, s.x, s.y, z + 1.4, 0.0, 0.0, 0.0, 0.0, 0.0, s.w or 0.0, 1.2, 1.2, 1.2, 47, 191, 107, 170, false, false, 2, false)
    DrawLine(p.x, p.y, p.z + 0.1, s.x, s.y, z, 47, 191, 107, 90)
    if Builder.hidden then label(s.x, s.y, z + 2.2, Text('builder_spawn')) end
end

function Builder.Open()
    local ok, data = lib.callback.await('XS-Medical:server:builderOpen', false)
    if not ok then return Framework.Notify(data or Text('err_not_admin'), 'error') end
    Builder.open = true
    UI.Send('builder', 'open', data)
    UI.Focus('builder', true)
    CreateThread(function()
        while Builder.open do
            if Builder.place and not Placement.active then
                local at = Builder.place.blipAt
                if type(at) == 'table' and at.x then
                    DrawMarker(2, at.x, at.y, at.z + 1.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.5, 0.5, 0.5, 47, 191, 107, 200, true, true, 2, false)
                    if Builder.hidden then label(at.x, at.y, at.z + 1.7, Text('builder_blip_spot')) end
                end
                for kind, list in pairs(Builder.place.points or {}) do
                    for _, p in ipairs(list) do
                        if (kind == 'garage' or kind == 'helipad') and type(p.spawn) == 'table' and p.spawn.x then spawnBox(p, p.spawn, kind) end
                        DrawMarker(28, p.x, p.y, p.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 61, 255, 122, 120, false, false, 2, false)
                        if Builder.hidden then label(p.x, p.y, p.z + 0.35, Text('point_' .. kind)) end
                    end
                end
            end
            Wait(0)
        end
    end)
end

function Builder.Close()
    if not Builder.open then return end
    Builder.open = false
    Builder.place = nil
    Placement.Abort()
    UI.Send('builder', 'close', {})
    UI.Focus('builder', false)
end

UI.OnClose('builder', Builder.Close)
Framework.OnUnloaded(Builder.Close)

UI.Handle('builder:select', function(place)
    Builder.place = type(place) == 'table' and place or nil
    return true
end)

UI.Handle('builder:place', function(payload)
    payload = type(payload) == 'table' and payload or {}
    local existing = {}
    for _, list in pairs((Builder.place or {}).points or {}) do
        for _, p in ipairs(list) do existing[#existing + 1] = p end
    end
    hide()
    local result = Placement.Start({
        mode = payload.mode or 'point', label = payload.label, origin = payload.origin, width = payload.width,
        ratio = RATIOS[payload.screen or ''] or 0.5625, previewModel = payload.previewModel,
        previewVehicle = payload.previewVehicle == true, existing = existing,
    })
    if Builder.open then show() end
    if not result then return false, Text('builder_cancelled') end
    return true, result
end)

UI.Handle('builder:here', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(c.x, c.y, c.z, c.x, c.y, c.z - 3.0, 1 + 16, ped, 4)
    local _, hit, floor = GetShapeTestResult(ray)
    local z = (hit == true or hit == 1) and floor.z or (c.z - 0.98)
    return true, { x = c.x, y = c.y, z = z, w = GetEntityHeading(ped) }
end)

UI.Handle('builder:goto', function(p)
    if type(p) ~= 'table' or not p.x then return false end
    local ped = PlayerPedId()
    SetEntityCoords(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false)
    return true
end)

UI.Handle('builder:save', function(place)
    local ok, saved = lib.callback.await('XS-Medical:server:builderSave', false, place)
    if ok then Builder.place = saved end
    return ok, saved
end)

UI.Handle('builder:delete', function(payload)
    local ok = lib.callback.await('XS-Medical:server:builderDelete', false, payload and payload.id)
    if ok then Builder.place = nil end
    return ok
end)

UI.Handle('builder:close', function()
    Builder.Close()
    return true
end)

local command = (Config.Admin or {}).command
if command and command ~= '' then
    RegisterCommand(command, function()
        if Builder.open then Builder.Close() else Builder.Open() end
    end, false)
end
