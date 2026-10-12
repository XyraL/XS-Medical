local hits = {}
local drops = {}

local function restore(src, s)
    local status = s.restoreDown
    s.restoreDown = nil
    if not status then return end
    if status == 'arrest' or status == 'dead' then
        Down.Arrest(src, 'restored')
    else
        Down.Start(src, 'restored')
    end
end

Framework.OnLoaded(function(src)
    State.Load(src)
end)

Framework.OnUnloaded(function(src)
    if State.Peek(src) then State.Forget(src) end
    hits[src] = nil
    drops[src] = nil
end)

lib.callback.register('XS-Medical:server:hello', function(src)
    local s = State.Peek(src)
    if not s then s = State.Load(src) end
    local pending = s.restoreDown
    SetTimeout(1500, function()
        if GetPlayerName(src) and State.Peek(src) == s then restore(src, s) end
    end)
    Compat.Status(src, pending and 'down' or s.status)
    State.Sync(src, s)
    return {
        state = State.Public(src, s), places = Hospitals.List(),
        health = tonumber(Framework.GetMetaData(src, 'health')), armour = tonumber(Framework.GetMetaData(src, 'armor')) or 0,
        beds = GlobalState['xsm:beds'] or {},
    }
end)

RegisterNetEvent('XS-Medical:server:hit', function(hit)
    local src = source
    if type(hit) ~= 'table' then return end
    local now = GetGameTimer()
    local h = hits[src]
    if not h or now - h.at > 1000 then
        h = { at = now, count = 0 }
        hits[src] = h
    end
    h.count = h.count + 1
    if h.count > 25 then return end
    State.Hit(src, hit)
end)

RegisterNetEvent('XS-Medical:server:bloodDrop', function()
    local src = source
    local now = os.time()
    if drops[src] and now - drops[src] < 8 then return end
    drops[src] = now
    local s = State.Peek(src)
    if not s or Body.WorstBleed(s.injuries) == 0 then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    TriggerEvent('evidence:server:CreateBloodDrop', Framework.GetCitizenId(src), Framework.GetMetaData(src, 'bloodtype') or 'O+', vector3(c.x, c.y, c.z - 0.9))
end)

local function useable(item, handler)
    if item and item ~= '' then Inventory.Useable(item, handler) end
end

local function registerItems()
    for _, supply in pairs(Config.Supplies or {}) do
        useable(supply.item, function(src)
            TriggerClientEvent('XS-Medical:client:useItem', src, supply.item)
        end)
    end
    for _, med in ipairs(Config.Medicines or {}) do
        useable(med.item, function(src)
            TriggerClientEvent('XS-Medical:client:useItem', src, med.item)
        end)
    end
    if (Config.Tablet or {}).item then
        useable(Config.Tablet.item, function(src)
            TriggerClientEvent('XS-Medical:client:openTablet', src)
        end)
    end
end

CreateThread(function()
    if not Db.Setup() then return end
    Hospitals.Load()
    registerItems()
    for _, src in ipairs(Framework.Players()) do
        if not State.Peek(src) then State.Load(src) end
    end
    GlobalState['xsm:beds'] = Hospitals.BedMap()
    print(('^2[XS-Medical]^0 ready: %s, %d place(s), inventory %s, target on clients, dispatch %s.'):format(
        Framework.name or 'no framework', #Hospitals.order, Inventory.name or 'none', Dispatch.name or 'built in only'))
end)

CreateThread(function()
    while true do
        GlobalState['xsm:medics'] = #Framework.Medics(true)
        Wait(10000)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src in pairs(State.players) do State.Save(src, true) end
end)
