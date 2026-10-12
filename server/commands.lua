local C = Config.Commands or {}

local function targetOf(src, arg)
    local id = tonumber(arg)
    if id and GetPlayerName(id) then return id end
    if src > 0 then return src end
    return nil
end

local function adminCommand(name, handler)
    if not name or name == false or name == '' then return end
    RegisterCommand(name, function(src, args)
        if src > 0 and not Framework.IsAdmin(src) then
            Framework.Notify(src, Text('err_not_admin'), 'error')
            return
        end
        local target = targetOf(src, args[1])
        if not target then
            print(('[XS-Medical] /%s needs a player id from the console.'):format(name))
            return
        end
        handler(src, target)
    end, false)
end

adminCommand(C.revive, function(src, target)
    Down.Revive(target, 'full')
    Framework.RestoreNeeds(target)
    if src > 0 and src ~= target then Framework.Notify(src, Text('admin_revived', { id = target }), 'success') end
end)

adminCommand(C.heal, function(src, target)
    State.Heal(target)
    TriggerClientEvent('XS-Medical:client:addHealth', target, 200)
    if src > 0 and src ~= target then Framework.Notify(src, Text('admin_healed', { id = target }), 'success') end
end)

adminCommand(C.kill, function(_, target)
    if not State.IsDown(target) then
        State.Get(target).cause = 'admin'
        Down.Arrest(target, 'admin')
    else
        Down.Arrest(target, 'admin')
    end
end)

if C.ems and C.ems ~= '' then
    RegisterCommand(C.ems, function(src, args)
        if src <= 0 then return end
        local message = Util.Text(table.concat(args, ' '), 160)
        local ok, err, wait = Down.CallForHelp(src, message ~= '' and message or nil)
        if ok then
            Framework.Notify(src, Text('call_sent'), 'success')
        else
            Framework.Notify(src, Text(err, { seconds = wait or 0 }), 'error')
        end
    end, false)
end

lib.callback.register('XS-Medical:server:diag', function(src)
    local places = 0
    for _ in pairs(Hospitals.places) do places = places + 1 end
    return {
        framework = Framework.name or 'none', inventory = Inventory.name or 'none', keys = Keys.name or 'none',
        banking = Banking.name or 'none', dispatch = Dispatch.name or 'none', db = Db.ready, places = places,
        medics = #Framework.Medics(true), isMedic = Framework.IsMedicSource(src), admin = Framework.IsAdmin(src),
        job = Framework.GetJob(src), status = State.Get(src).status, paused = Standdown.Active(src),
    }
end)
