Pharmacy = { open = false, place = nil, point = nil }

function Pharmacy.Open(place, point)
    if Down.active then return end
    local ok, data = lib.callback.await('XS-Medical:server:pharmacy', false, place.id, point.id)
    if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
    Pharmacy.open, Pharmacy.place, Pharmacy.point = true, place, point
    UI.Send('pharmacy', 'open', data)
    UI.Focus('pharmacy', true)
end

function Pharmacy.Close()
    if not Pharmacy.open then return end
    Pharmacy.open = false
    UI.Send('pharmacy', 'close', {})
    UI.Focus('pharmacy', false)
end

UI.OnClose('pharmacy', Pharmacy.Close)

local function refresh()
    local ok, data = lib.callback.await('XS-Medical:server:pharmacy', false, Pharmacy.place.id, Pharmacy.point.id)
    if ok then UI.Send('pharmacy', 'update', data) end
end

UI.Handle('pharmacy:fill', function(payload)
    if not Pharmacy.open or type(payload) ~= 'table' then return false end
    local ok, message = lib.callback.await('XS-Medical:server:pharmacyFill', false, Pharmacy.place.id, Pharmacy.point.id, tonumber(payload.id))
    if ok then refresh() end
    return ok, message
end)

UI.Handle('pharmacy:buy', function(payload)
    if not Pharmacy.open or type(payload) ~= 'table' then return false end
    local ok, message = lib.callback.await('XS-Medical:server:pharmacyBuy', false, Pharmacy.place.id, Pharmacy.point.id, payload.item, tonumber(payload.qty) or 1)
    if ok then refresh() end
    return ok, message
end)
