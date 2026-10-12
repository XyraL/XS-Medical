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

function Builder.Open()
    local ok, data = lib.callback.await('XS-Medical:server:builderOpen', false)
    if not ok then return Framework.Notify(data or Text('err_not_admin'), 'error') end
    Builder.open = true
    UI.Send('builder', 'open', data)
    UI.Focus('builder', true)
    CreateThread(function()
        while Builder.open do
            if Builder.place and not Placement.active then
                for kind, list in pairs(Builder.place.points or {}) do
                    for _, p in ipairs(list) do
                        DrawMarker(28, p.x, p.y, p.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 61, 255, 122, 120, false, false, 2, false)
                        if Builder.hidden then
                            local onScreen, sx, sy = World3dToScreen2d(p.x, p.y, p.z + 0.35)
                            if onScreen then
                                SetTextScale(0.28, 0.28)
                                SetTextFont(0)
                                SetTextColour(220, 255, 230, 220)
                                SetTextCentre(true)
                                SetTextOutline()
                                BeginTextCommandDisplayText('STRING')
                                AddTextComponentSubstringPlayerName(Text('point_' .. kind))
                                EndTextCommandDisplayText(sx, sy)
                            end
                        end
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
    show()
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
