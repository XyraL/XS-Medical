Dispatch = { name = nil }

if not IsDuplicityVersion() or not Config then return end

local CANDIDATES = {
    'XS-Dispatch', 'ps-dispatch', 'qs-dispatch', 'cd_dispatch', 'core_dispatch', 'rcore_dispatch', 'linden_outlawalert',
}

do
    local forced = Config.Bridges and Config.Bridges.dispatch or 'auto'
    if forced == 'none' then
        Dispatch.name = nil
    elseif forced ~= 'auto' then
        Dispatch.name = forced
    else
        for _, r in ipairs(CANDIDATES) do
            if GetResourceState(r) == 'started' then Dispatch.name = r break end
        end
    end
end

local function jobs()
    local out = {}
    for _, name in ipairs((Config.Jobs or {}).names or { 'ambulance' }) do out[#out + 1] = name end
    return out
end

local function vec(c)
    return vector3((tonumber(c.x) or 0.0) + 0.0, (tonumber(c.y) or 0.0) + 0.0, (tonumber(c.z) or 0.0) + 0.0)
end

local Senders = {}

Senders['XS-Dispatch'] = function(a)
    exports['XS-Dispatch']:CreateCall({
        type = 'medical', code = a.code, title = a.title, description = a.description, priority = a.priority,
        coords = vec(a.coords), sprite = a.sprite, color = a.colour, caller = a.caller, origin = GetCurrentResourceName(),
    })
end

Senders['ps-dispatch'] = function(a)
    local list = jobs()
    list[#list + 1] = 'ems'
    local alert = {
        message = a.title, codeName = 'xs_medical', code = a.code, icon = 'fas fa-heart-pulse',
        priority = a.priority == 1 and 1 or 2, coords = vec(a.coords), information = a.description,
        jobs = list, addToList = true,
        alert = {
            radius = 0, sprite = a.sprite, color = a.colour, scale = 1.0, length = 3,
            sound = 'Lose_1st', sound2 = 'GTAO_FM_Events_Soundset', offset = false, flash = a.priority == 1,
        },
    }
    local sent = pcall(function() exports['ps-dispatch']:SendTargetedAlert(Framework.Medics(true), alert) end)
    if not sent then TriggerEvent('ps-dispatch:server:notify', alert) end
end

Senders['qs-dispatch'] = function(a)
    TriggerEvent('qs-dispatch:server:CreateDispatchCall', {
        job = jobs(), callLocation = vec(a.coords), callCode = { code = a.code, snippet = a.title },
        message = a.description, flashes = a.priority == 1, image = nil,
        blip = { sprite = a.sprite, scale = 1.0, colour = a.colour, flashes = a.priority == 1, text = a.title, time = (a.blipTime or 300) * 1000 },
    })
end

Senders['cd_dispatch'] = function(a)
    TriggerClientEvent('cd_dispatch:AddNotification', -1, {
        job_table = jobs(), coords = vec(a.coords), title = ('%s - %s'):format(a.code, a.title), message = a.description,
        flash = a.priority == 1 and 1 or 0, unique_id = tostring(math.random(1000000, 9999999)), sound = 1,
        blip = {
            sprite = a.sprite, scale = 1.0, colour = a.colour, flashes = a.priority == 1,
            text = ('%s - %s'):format(a.code, a.title), time = math.max(1, math.floor((a.blipTime or 300) / 60)), radius = 0,
        },
    })
end

Senders['core_dispatch'] = function(a)
    local extra = { { icon = 'fa-circle-info', info = a.description } }
    local sent = pcall(function()
        exports['core_dispatch']:sendAlert({
            code = a.code, message = a.title, extraInfo = extra, coords = vec(a.coords), priority = a.priority == 1,
            job = jobs(), time = 10000, blip = a.sprite, color = a.colour,
        })
    end)
    if sent then return end
    local c = vec(a.coords)
    for _, job in ipairs(jobs()) do
        TriggerEvent('core_dispatch:addCall', a.code, a.title, extra, { c.x, c.y, c.z }, job, 10000, a.sprite, a.colour, a.priority == 1)
    end
end

Senders['rcore_dispatch'] = function(a)
    TriggerEvent('rcore_dispatch:server:sendAlert', {
        code = ('%s - %s'):format(a.code, a.title), default_priority = a.priority == 1 and 'high' or 'medium',
        coords = vec(a.coords), job = jobs(), text = a.description, type = 'alerts',
        blip = { sprite = a.sprite, colour = a.colour, scale = 1.0, text = a.title, flashes = a.priority == 1, radius = 0 },
    })
end

Senders['linden_outlawalert'] = function(a)
    TriggerEvent('wf-alerts:svNotify', {
        dispatchData = {
            displayCode = a.code, description = a.title, isImportant = a.priority == 1 and 1 or 0, recipientList = jobs(),
            length = 10000, infoM = 'fa-info-circle', info = a.description, blipSprite = a.sprite, blipColour = a.colour, blipScale = 1.0,
        },
        caller = a.caller, coords = vec(a.coords),
    })
end

function Dispatch.Forward(a)
    local sender = Dispatch.name and Senders[Dispatch.name]
    if not sender or GetResourceState(Dispatch.name) ~= 'started' then return false end
    a.code = a.code or (Config.Dispatch and Config.Dispatch.code) or '10-52'
    a.sprite = a.sprite or 153
    a.colour = a.colour or 1
    a.priority = a.priority or 1
    a.caller = a.caller or 'Anonymous'
    local ok, err = pcall(sender, a)
    if not ok then
        print(('^3[XS-Medical]^0 %s refused the medical call (%s).'):format(Dispatch.name, tostring(err)))
    end
    return ok
end
