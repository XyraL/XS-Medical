Surgery = { active = {} }

local function key(placeId, pointId)
    return ('%s:%s'):format(placeId, pointId)
end

local function allowed(job)
    if not Framework.IsMedic(job) then return false end
    return job.isBoss or (job.grade or 0) >= ((Config.Grades or {}).surgery or 0)
end

local function needs(s)
    local out = {}
    for _, injury in ipairs(s.injuries) do
        if Body.NeedsSurgery(injury) then
            out[#out + 1] = {
                id = injury.id, part = injury.part, kind = injury.kind, sev = injury.sev, bulletIn = injury.bulletIn,
                internal = injury.internal, fracture = injury.fracture,
            }
        end
    end
    return out
end

lib.callback.register('XS-Medical:server:surgeryStart', function(src, target, placeId, pointId)
    target = tonumber(target)
    local job = Framework.GetJob(src)
    if not allowed(job) then return false, Text('err_grade') end
    local place = Hospitals.Get(placeId)
    local point = place and Hospitals.Point(place, 'surgery', tostring(pointId or ''))
    if not point then return false, Text('err_unknown_place') end
    if not target or not GetPlayerName(target) then return false, Text('err_no_patient') end
    if not Hospitals.Near(src, point, 4.0) or not Hospitals.Near(target, point, 5.0) then return false, Text('err_too_far') end
    local k = key(place.id, point.id)
    local busy = Surgery.active[k]
    if busy and GetPlayerName(busy.medic) and busy.medic ~= src then return false, Text('err_table_busy') end
    local s = State.Get(target)
    if s.status == 'arrest' or s.status == 'dead' then return false, Text('err_patient_gone') end
    local list = needs(s)
    if #list == 0 then return false, Text('err_no_surgery_needed') end
    Surgery.active[k] = { medic = src, patient = target, at = os.time(), ids = {} }
    for _, i in ipairs(list) do Surgery.active[k].ids[i.id] = true end
    Patients.Attend(target, src)
    Patients.SetStatus(target, 'surgery')
    local v = Patients.Get(target, true)
    v.room = point.room
    Patients.Log(target, Text('log_surgery_start'), src)
    TriggerClientEvent('XS-Medical:client:toTable', target, { x = point.x, y = point.y, z = point.z, w = point.w })
    return true, { key = k, injuries = list, seconds = (Config.Surgery or {}).seconds or 45, patient = Patients.Display(v), vitals = State.Vitals(target, s) }
end)

lib.callback.register('XS-Medical:server:surgeryVitals', function(src, k)
    local op = Surgery.active[k]
    if not op or op.medic ~= src then return nil end
    return State.Vitals(op.patient)
end)

lib.callback.register('XS-Medical:server:surgeryEnd', function(src, k, results)
    local op = Surgery.active[k]
    if not op or op.medic ~= src then return false end
    Surgery.active[k] = nil
    local target = op.patient
    TriggerClientEvent('XS-Medical:client:offTable', target)
    if not GetPlayerName(target) then return false end
    if os.time() - op.at < 8 then results = {} end
    results = type(results) == 'table' and results or {}

    local s = State.Get(target)
    local fixed, failed = 0, 0
    for id in pairs(op.ids) do
        local injury = State.FindInjury(s, id)
        if injury then
            if results[tostring(id)] == true or results[id] == true then
                State.Close(target, s, injury)
                fixed = fixed + 1
            else
                injury.bleed = math.max(injury.bleed, (Config.Surgery or {}).failBleed or 2)
                injury.treated.bandage, injury.treated.gauze = nil, nil
                failed = failed + 1
            end
        end
    end

    local summary = Text('log_surgery_done', { fixed = fixed, failed = failed })
    Patients.Log(target, summary, src)
    Records.Log(Framework.GetCitizenId(target), 'surgery', summary, nil, src)
    Patients.SetStatus(target, 'recovering')
    if s.status == 'down' then Down.Retime(target) end
    State.Sync(target, s)
    return true, summary
end)

Framework.OnUnloaded(function(src)
    for k, op in pairs(Surgery.active) do
        if op.medic == src or op.patient == src then
            if op.patient ~= src then TriggerClientEvent('XS-Medical:client:offTable', op.patient) end
            Surgery.active[k] = nil
        end
    end
end)
