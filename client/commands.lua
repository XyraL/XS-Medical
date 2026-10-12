local C = Config.Commands or {}

local selfOpen = false

local function closeSelf()
    if not selfOpen then return end
    selfOpen = false
    UI.Send('self', 'close', {})
    UI.Focus('self', false)
end

UI.OnClose('self', closeSelf)

if C.injuries and C.injuries ~= '' then
    RegisterCommand(C.injuries, function()
        if Down.active then return end
        if selfOpen then return closeSelf() end
        selfOpen = true
        local have = {}
        for key, s in pairs(Config.Supplies or {}) do
            if s.self then have[key] = Inventory.Count(s.item) end
        end
        UI.Send('self', 'open', { state = Me.state, have = have })
        UI.Focus('self', true)
    end, false)
end

UI.Handle('self:use', function(payload)
    if type(payload) ~= 'table' then return false end
    closeSelf()
    CreateThread(function()
        Treat.Run(GetPlayerServerId(PlayerId()), payload.supply, tonumber(payload.injury))
    end)
    return true
end)

if C.diag and C.diag ~= '' then
    RegisterCommand(C.diag, function()
        local server = lib.callback.await('XS-Medical:server:diag', false) or {}
        local lines = {
            ('framework: %s · inventory: %s · target: %s'):format(Framework.name or 'none', Inventory.name or 'none', Target.Detect()),
            ('server sees: framework %s · inventory %s · keys %s · banking %s · dispatch %s'):format(server.framework, server.inventory, server.keys, server.banking, server.dispatch),
            ('database ready: %s · places: %s · medics on duty: %s'):format(tostring(server.db), tostring(server.places), tostring(server.medics)),
            ('you: medic %s · admin %s · status %s · stood down %s'):format(tostring(server.isMedic), tostring(server.admin), tostring(server.status), tostring(server.paused)),
            ('job: %s grade %s on duty %s'):format(server.job and server.job.name or 'none', server.job and server.job.grade or '-', server.job and tostring(server.job.onDuty) or '-'),
        }
        for _, line in ipairs(lines) do print('[XS-Medical] ' .. line) end
        lib.alertDialog({ header = 'XS-Medical', content = table.concat(lines, '  \n'), centered = true })
    end, false)
end

CreateThread(function()
    Treat.RegisterTargets()
    Equip.RegisterTargets()
end)
