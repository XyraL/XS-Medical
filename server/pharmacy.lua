Pharmacy = {}

local function society()
    return (Config.Jobs or {}).society or 'ambulance'
end

local function counterPoint(src, placeId, pointId)
    local place = Hospitals.Get(placeId)
    if not place then return nil end
    local point = Hospitals.Point(place, 'pharmacist', tostring(pointId or ''))
    if not point or not Hospitals.Near(src, point, 3.5) then return nil end
    return place, point
end

local function counterItems()
    local out = {}
    for _, entry in ipairs((Config.Pharmacy or {}).counter or {}) do
        out[#out + 1] = { item = entry.item, label = Inventory.Label(entry.item), price = math.floor(tonumber(entry.price) or 0) }
    end
    return out
end

lib.callback.register('XS-Medical:server:pharmacy', function(src, placeId, pointId)
    local place = counterPoint(src, placeId, pointId)
    if not place then return false, Text('err_too_far') end
    local cid = Framework.GetCitizenId(src)
    local record = Records.Ensure(cid, src)
    local prescriptions = {}
    for _, rx in ipairs(Records.Prescriptions(cid, true)) do
        local med = Records.Medicine(rx.item)
        rx.price = med and med.price or 0
        prescriptions[#prescriptions + 1] = rx
    end
    return true, {
        store = place.name, patient = Framework.GetName(src) or '', dob = record and record.dob or '',
        allergies = record and record.allergies or '', blood = record and record.blood or '',
        prescriptions = prescriptions, counter = counterItems(), money = Framework.GetMoney(src),
    }
end)

lib.callback.register('XS-Medical:server:pharmacyFill', function(src, placeId, pointId, rxId)
    local place = counterPoint(src, placeId, pointId)
    if not place then return false, Text('err_too_far') end
    local cid = Framework.GetCitizenId(src)
    rxId = tonumber(rxId)
    local current
    for _, rx in ipairs(Records.Prescriptions(cid, true)) do
        if rx.id == rxId then current = rx break end
    end
    if not current then return false, Text('err_rx_missing') end
    local med = Records.Medicine(current.item)
    if not med then return false, Text('err_unknown_medicine') end
    if not Inventory.CanCarry(src, med.item, current.qty) then return false, Text('err_full') end
    local price = math.floor(tonumber(med.price) or 0)
    if price > 0 and not Framework.Charge(src, price, (Config.Pharmacy or {}).account or 'cash', 'pharmacy') then
        return false, Text('err_no_money', { amount = price })
    end
    local row = Records.Fill(rxId, cid)
    if not row then return false, Text('err_rx_missing') end
    if price > 0 then Banking.Deposit(place.society ~= '' and place.society or society(), price, 'Pharmacy') end
    Inventory.Add(src, med.item, current.qty, { prescription = rxId, prescriber = current.prescriber })
    TriggerClientEvent('XS-Medical:client:invalidateInventory', src)
    Records.Log(cid, 'pharmacy', Text('log_filled', { label = med.label, store = place.name }), { id = rxId }, nil)
    return true, Text('rx_filled', { qty = current.qty, label = med.label })
end)

lib.callback.register('XS-Medical:server:pharmacyBuy', function(src, placeId, pointId, item, qty)
    local place = counterPoint(src, placeId, pointId)
    if not place then return false, Text('err_too_far') end
    qty = Util.Clamp(math.floor(tonumber(qty) or 1), 1, 10)
    local entry
    for _, e in ipairs(counterItems()) do
        if e.item == item then entry = e break end
    end
    if not entry then return false, Text('err_not_stocked') end
    if not Inventory.CanCarry(src, entry.item, qty) then return false, Text('err_full') end
    local cost = entry.price * qty
    if cost > 0 and not Framework.Charge(src, cost, (Config.Pharmacy or {}).account or 'cash', 'pharmacy') then
        return false, Text('err_no_money', { amount = cost })
    end
    if cost > 0 then Banking.Deposit(place.society ~= '' and place.society or society(), cost, 'Pharmacy') end
    Inventory.Add(src, entry.item, qty)
    TriggerClientEvent('XS-Medical:client:invalidateInventory', src)
    return true, Text('cabinet_took', { qty = qty, label = entry.label })
end)

function Pharmacy.Take(src, item)
    local med = Records.Medicine(item)
    if not med then return false, 'err_unknown_medicine' end
    local s = State.Get(src)
    if s.status ~= 'alive' then return false, 'err_cannot_now' end
    if not Inventory.Remove(src, med.item, 1) then return false, 'err_no_item', { item = med.label } end
    TriggerClientEvent('XS-Medical:client:invalidateInventory', src)
    if med.effect == 'pain' then
        local now = os.time()
        s.relief = math.max(s.relief, med.relief or 4)
        s.reliefUntil = math.max(s.reliefUntil, now + math.floor((med.minutes or 20) * 60))
    elseif med.effect == 'infection' then
        for _, injury in ipairs(s.injuries) do
            injury.infected = false
            injury.openAt = nil
        end
    elseif med.effect == 'stress' then
        Framework.SetStress(src, -(med.amount or 40))
    end
    State.Sync(src, s)
    return true, 'took_medicine', { label = med.label }
end

lib.callback.register('XS-Medical:server:takeMedicine', function(src, item)
    local ok, key, vars = Pharmacy.Take(src, tostring(item or ''))
    return ok, Text(key, vars)
end)
