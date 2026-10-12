Patients = { visits = {}, dirty = {} }

local STATUSES = { field = true, incoming = true, waiting = true, seen = true, surgery = true, recovering = true, ready = true }

local function initials(first, last)
    local a = (first or ''):sub(1, 1):upper()
    local b = (last or ''):sub(1, 1):upper()
    if a == '' and b == '' then return '?' end
    return (a ~= '' and (a .. '.') or '') .. (b ~= '' and (b .. '.') or '')
end

function Patients.Display(v)
    if not v then return '' end
    local S = Config.Screens or {}
    if not v.identified and S.unknownNames ~= false then return v.alias end
    local mode = S.names or 'full'
    if mode == 'initials' then return initials(v.first, v.last) end
    if mode == 'initial' then
        local last = (v.last or ''):sub(1, 1):upper()
        return (('%s %s'):format(v.first or '', last ~= '' and (last .. '.') or ''):gsub('%s+$', ''))
    end
    return v.name
end

local function aliasFor(female, src)
    local base = female and Text('alias_female') or Text('alias_male')
    local count = 0
    for _, v in pairs(Patients.visits) do
        if v.src ~= src and not v.identified and v.female == female then count = count + 1 end
    end
    return count > 0 and ('%s %d'):format(base, count + 1) or base
end

function Patients.Get(src, create)
    src = tonumber(src)
    if not src then return nil end
    local v = Patients.visits[src]
    if v or not create then return v end
    local ci = Framework.GetCharInfo(src)
    v = {
        src = src, cid = Framework.GetCitizenId(src), name = ci.name, first = ci.firstname, last = ci.lastname,
        female = ci.female, identified = false, alias = aliasFor(ci.female, src), hospital = nil, room = nil, bed = nil,
        status = 'field', medic = nil, since = os.time(), touched = os.time(), timeline = {},
    }
    Patients.visits[src] = v
    Patients.Changed(v)
    return v
end

function Patients.Changed(v)
    if not v then return end
    v.touched = os.time()
    Patients.dirty[v.hospital or 'field'] = true
    Patients.dirty.any = true
end

function Patients.Touch(src)
    local v = Patients.visits[tonumber(src) or -1]
    if v then Patients.Changed(v) end
end

function Patients.Unknown(src)
    local v = Patients.Get(src, true)
    return not v.identified
end

function Patients.Identify(src, by)
    local v = Patients.Get(src, true)
    v.identified = true
    Patients.Changed(v)
end

function Patients.SetStatus(src, status)
    if not STATUSES[status] then return end
    local v = Patients.Get(src, true)
    v.status = status
    Patients.Changed(v)
end

function Patients.Downed(src)
    local v = Patients.Get(src, true)
    if v.status == 'recovering' or v.status == 'ready' or v.status == 'waiting' then v.status = 'seen' end
    Patients.Changed(v)
end

function Patients.Attend(src, medic)
    local v = Patients.Get(src, true)
    if not v.medic or v.medic.src ~= medic then
        v.medic = { src = medic, name = Framework.GetName(medic) or '', cid = Framework.GetCitizenId(medic) }
    end
    if v.status == 'waiting' or v.status == 'field' and v.hospital then v.status = 'seen' end
    Patients.Changed(v)
end

function Patients.Log(src, text, by, key)
    local v = Patients.Get(src, true)
    local entry = { t = os.time(), text = Util.Text(text, 160), by = by and Framework.GetName(by) or nil }
    v.timeline[#v.timeline + 1] = entry
    if #v.timeline > 40 then table.remove(v.timeline, 1) end
    Patients.Changed(v)
    if by and by ~= src and Framework.IsMedicSource(by) then
        Records.Log(v.cid, 'treatment', entry.text, { key = key }, by)
    end
end

function Patients.CheckIn(src, hospitalId)
    local v = Patients.Get(src, true)
    v.identified = true
    v.hospital = hospitalId
    v.room = Text('room_lobby')
    v.bed = nil
    v.status = 'waiting'
    Patients.Changed(v)
    return v
end

function Patients.Bed(src, hospitalId, bed, status)
    local v = Patients.Get(src, true)
    if v.hospital ~= hospitalId then Patients.dirty[v.hospital or 'field'] = true end
    v.hospital = hospitalId
    v.bed = bed and bed.id or nil
    v.room = bed and (bed.room ~= '' and bed.room or bed.label) or v.room
    if status then v.status = status end
    Patients.Changed(v)
    return v
end

function Patients.Leave(src)
    local v = Patients.visits[tonumber(src) or -1]
    if not v then return end
    v.bed = nil
    Patients.Changed(v)
end

function Patients.Discharge(src, by)
    src = tonumber(src)
    local v = Patients.visits[src or -1]
    if not v then return false end
    if by and Framework.IsMedicSource(by) then
        Records.Log(v.cid, 'visit', Text('log_visit', { hospital = Hospitals.Name(v.hospital) }), { timeline = v.timeline }, by)
    end
    Patients.dirty[v.hospital or 'field'] = true
    Patients.dirty.any = true
    Patients.visits[src] = nil
    Hospitals.FreeBedOf(src)
    return true
end

function Patients.Row(v)
    local xsm = Player(v.src).state.xsm
    return {
        src = v.src, name = Patients.Display(v), realName = v.identified and v.name or nil, identified = v.identified, room = v.room or '',
        status = v.status, medic = v.medic and v.medic.name or '', since = v.since, acuity = xsm and xsm.acuity or 5,
        hospital = v.hospital, bed = v.bed,
    }
end

function Patients.Board(hospitalId)
    local rows = {}
    for _, v in pairs(Patients.visits) do
        if v.hospital == hospitalId and v.status ~= 'field' then
            local row = Patients.Row(v)
            row.realName = nil
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b)
        if a.acuity ~= b.acuity then return a.acuity < b.acuity end
        return a.since < b.since
    end)
    return rows
end

function Patients.List()
    local rows = {}
    for _, v in pairs(Patients.visits) do rows[#rows + 1] = Patients.Row(v) end
    table.sort(rows, function(a, b) return a.since > b.since end)
    return rows
end

function Patients.Timeline(src)
    local v = Patients.visits[tonumber(src) or -1]
    return v and v.timeline or {}
end

CreateThread(function()
    while true do
        Wait(1000)
        if Patients.dirty.any then
            local dirty = Patients.dirty
            Patients.dirty = {}
            for key in pairs(dirty) do
                if key ~= 'any' and key ~= 'field' then
                    GlobalState['xsm:board:' .. tostring(key)] = Patients.Board(key)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for src, v in pairs(Patients.visits) do
            if not GetPlayerName(src) then
                Patients.dirty[v.hospital or 'field'] = true
                Patients.dirty.any = true
                Patients.visits[src] = nil
            else
                local s = State.Peek(src)
                local healthy = not s or (s.status == 'alive' and #s.injuries == 0 and s.blood >= 95)
                if healthy and not v.bed and now - (v.touched or now) > 600 then
                    Patients.Discharge(src)
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local v = Patients.visits[source]
    if v then
        Patients.dirty[v.hospital or 'field'] = true
        Patients.dirty.any = true
        Patients.visits[source] = nil
    end
end)
