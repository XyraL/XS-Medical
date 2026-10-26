local function admin(src)
    return Framework.IsAdmin(src)
end

lib.callback.register('XS-Medical:server:builderOpen', function(src)
    if not admin(src) then return false, Text('err_not_admin') end
    return true, {
        places = Hospitals.List(), vehicles = Framework.Vehicles(),
        peds = { checkin = (Config.Peds or {}).checkin, pharmacist = (Config.Peds or {}).pharmacist },
        bedProp = (Config.Beds or {}).prop, blips = Config.Blips or {},
    }
end)

lib.callback.register('XS-Medical:server:builderSave', function(src, raw)
    if not admin(src) then return false, Text('err_not_admin') end
    local place = Hospitals.Sanitize(raw)
    if not place then return false, Text('err_failed') end
    if raw.id and not Hospitals.Get(raw.id) then place.id = nil end
    local saved = Hospitals.Save(place)
    if not saved then return false, Text('err_db') end
    print(('^2[XS-Medical]^0 %s saved %s "%s" (#%s).'):format(GetPlayerName(src) or src, saved.kind, saved.name, saved.id))
    return true, saved
end)

lib.callback.register('XS-Medical:server:builderDelete', function(src, id)
    if not admin(src) then return false, Text('err_not_admin') end
    local ok = Hospitals.Delete(id)
    if ok then print(('^3[XS-Medical]^0 %s deleted place #%s.'):format(GetPlayerName(src) or src, tostring(id))) end
    return ok
end)
