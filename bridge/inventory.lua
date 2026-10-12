Inventory = { name = nil }

if not Config then return end

local CANDIDATES = { 'ox_inventory', 'qb-inventory', 'qs-inventory', 'ps-inventory', 'codem-inventory', 'core_inventory' }

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

do
    local forced = Config.Bridges and Config.Bridges.inventory or 'auto'
    if forced ~= 'auto' then
        Inventory.name = forced
    else
        for _, res in ipairs(CANDIDATES) do
            if running(res) then Inventory.name = res break end
        end
    end
end

local function frameworkItems()
    if Framework.name == 'qbox' then return {} end
    return Framework.core and Framework.core.Shared and Framework.core.Shared.Items or {}
end

function Inventory.Label(item)
    if not item then return '' end
    if Inventory.name == 'ox_inventory' then
        local ok, items = pcall(function() return exports.ox_inventory:Items(item) end)
        if ok and type(items) == 'table' and items.label then return items.label end
    end
    local def = frameworkItems()[item]
    return def and def.label or item
end

if IsDuplicityVersion() then
    function Inventory.Count(src, item)
        if not item or item == '' then return 0 end
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:Search(src, 'count', item) or 0
        end
        if Inventory.name == 'qs-inventory' then
            local ok, total = pcall(function() return exports['qs-inventory']:GetItemTotalAmount(src, item) end)
            if ok then return tonumber(total) or 0 end
        end
        local player = Framework.GetPlayer(src)
        if not player then return 0 end
        local found = player.Functions.GetItemByName(item)
        return found and (found.amount or found.count) or 0
    end

    function Inventory.Has(src, item, amount)
        return Inventory.Count(src, item) >= (amount or 1)
    end

    function Inventory.CanCarry(src, item, amount)
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:CanCarryItem(src, item, amount or 1) == true
        end
        if Inventory.name == 'qb-inventory' then
            local ok, can = pcall(function() return exports['qb-inventory']:CanAddItem(src, item, amount or 1) end)
            if ok then return can ~= false end
        end
        return true
    end

    function Inventory.Add(src, item, amount, metadata)
        amount = amount or 1
        if not item then return false end
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:AddItem(src, item, amount, metadata) and true or false
        end
        if Inventory.name == 'qb-inventory' then
            local ok, added = pcall(function() return exports['qb-inventory']:AddItem(src, item, amount, false, metadata, 'XS-Medical') end)
            if ok then
                if added then TriggerClientEvent('qb-inventory:client:ItemBox', src, frameworkItems()[item] or { name = item, label = item }, 'add', amount) end
                return added and true or false
            end
        end
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddItem(item, amount, nil, metadata) and true or false
    end

    function Inventory.Remove(src, item, amount, metadata)
        amount = amount or 1
        if not item then return false end
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:RemoveItem(src, item, amount, metadata) and true or false
        end
        if Inventory.name == 'qb-inventory' then
            local ok, removed = pcall(function() return exports['qb-inventory']:RemoveItem(src, item, amount, false, 'XS-Medical') end)
            if ok then
                if removed then TriggerClientEvent('qb-inventory:client:ItemBox', src, frameworkItems()[item] or { name = item, label = item }, 'remove', amount) end
                return removed and true or false
            end
        end
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.RemoveItem(item, amount) and true or false
    end

    function Inventory.Clear(src, keep)
        keep = keep or {}
        if Inventory.name == 'ox_inventory' then
            exports.ox_inventory:ClearInventory(src, keep)
            return true
        end
        if Inventory.name == 'qb-inventory' then
            local ok = pcall(function() exports['qb-inventory']:ClearInventory(src, keep) end)
            if ok then return true end
        end
        local player = Framework.GetPlayer(src)
        if not player then return false end
        player.Functions.ClearInventory(keep)
        return true
    end

    function Inventory.Items()
        local out = {}
        if Inventory.name == 'ox_inventory' then
            local ok, items = pcall(function() return exports.ox_inventory:Items() end)
            for name, def in pairs(ok and items or {}) do out[#out + 1] = { name = name, label = def.label or name } end
        else
            for name, def in pairs(frameworkItems()) do out[#out + 1] = { name = name, label = def.label or name } end
        end
        table.sort(out, function(a, b) return a.label < b.label end)
        return out
    end

    function Inventory.Useable(item, handler)
        if not item or item == '' or Inventory.name == 'ox_inventory' then return end
        if Framework.name == 'qbox' then
            pcall(function() exports.qbx_core:CreateUseableItem(item, handler) end)
        elseif Framework.core then
            Framework.core.Functions.CreateUseableItem(item, handler)
        end
    end

    function Inventory.OpenStash(src, id, label, slots, weight)
        if Inventory.name == 'ox_inventory' then
            exports.ox_inventory:RegisterStash(id, label, slots, weight, false)
            return 'client'
        end
        if Inventory.name == 'qb-inventory' then
            local ok = pcall(function()
                exports['qb-inventory']:OpenInventory(src, id, { label = label, maxweight = weight, slots = slots })
            end)
            if ok then return 'server' end
        end
        return 'legacy'
    end

    lib.callback.register('XS-Medical:server:itemCount', function(src, item)
        return Inventory.Count(src, tostring(item or ''))
    end)
else
    local cache, cacheAt = {}, {}

    function Inventory.Count(item)
        if not item or item == '' then return 0 end
        if Inventory.name == 'ox_inventory' then
            return exports.ox_inventory:Search('count', item) or 0
        end
        local now = GetGameTimer()
        if cacheAt[item] and now - cacheAt[item] < 1500 then return cache[item] or 0 end
        local count = lib.callback.await('XS-Medical:server:itemCount', false, item) or 0
        cache[item], cacheAt[item] = count, now
        return count
    end

    function Inventory.Has(item, amount)
        return Inventory.Count(item) >= (amount or 1)
    end

    function Inventory.Invalidate()
        cache, cacheAt = {}, {}
    end

    function Inventory.OpenStash(mode, id, label, slots, weight)
        if mode == 'client' then
            exports.ox_inventory:openInventory('stash', id)
        elseif mode == 'legacy' then
            if Inventory.name == 'qs-inventory' then
                pcall(function() exports['qs-inventory']:RegisterStash(id, slots, weight) end)
            end
            TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, { maxweight = weight, slots = slots })
            TriggerEvent('inventory:client:SetCurrentStash', id)
        end
    end

    RegisterNetEvent('XS-Medical:client:invalidateInventory', function()
        Inventory.Invalidate()
    end)
end
