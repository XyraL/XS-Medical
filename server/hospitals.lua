Hospitals = { places = {}, order = {}, beds = {}, vehicles = {} }

local KINDS = { hospital = true, pharmacy = true }

Hospitals.Types = {
    checkin = true, bed = true, surgery = true, storage = true, cabinet = true, duty = true, garage = true,
    helipad = true, equipment = true, elevator = true, boss = true, board = true, sign = true, pharmacist = true,
}

local function str(value, max, fallback)
    local out = Util.Text(value, max)
    if out == '' then return fallback or '' end
    return out
end

local function point(raw)
    local p = Util.Point(raw)
    if not p then return nil end
    return p
end

local function sanitizePoint(kind, raw)
    local p = point(raw)
    if not p then return nil end
    p.id = str(raw.id, 24, Util.Id('p'))
    if kind == 'checkin' then
        p.ped = str(raw.ped, 48, (Config.Peds or {}).checkin or 's_f_y_scrubs_01')
        p.npc = raw.npc ~= false
    elseif kind == 'bed' then
        p.room = str(raw.room, 24, '')
        p.label = str(raw.label, 24, 'Bed')
        p.prop = raw.prop ~= false and str(raw.prop, 48, '') or false
        p.respawn = raw.respawn ~= false
        if type(raw.monitor) == 'table' and point(raw.monitor) then
            local m = point(raw.monitor)
            m.width = Util.Clamp(tonumber(raw.monitor.width) or 0.55, 0.2, 2.0)
            p.monitor = m
        end
    elseif kind == 'surgery' then
        p.room = str(raw.room, 24, 'OR')
        p.label = str(raw.label, 24, 'Table')
    elseif kind == 'storage' then
        p.label = str(raw.label, 32, 'Storage')
        p.slots = Util.Clamp(math.floor(tonumber(raw.slots) or 50), 5, 200)
        p.weight = Util.Clamp(math.floor(tonumber(raw.weight) or 200000), 1000, 5000000)
        p.grade = Util.Clamp(math.floor(tonumber(raw.grade) or 0), 0, 50)
    elseif kind == 'garage' or kind == 'helipad' then
        p.spawn = point(raw.spawn) or point(raw)
        p.grade = Util.Clamp(math.floor(tonumber(raw.grade) or 0), 0, 50)
        p.vehicles = {}
        local seen = {}
        for _, model in ipairs(type(raw.vehicles) == 'table' and raw.vehicles or {}) do
            local m = (tostring(model or ''):lower():gsub('[^%w_%-]', '')):sub(1, 48)
            if m ~= '' and not seen[m] and #p.vehicles < 30 then
                seen[m] = true
                p.vehicles[#p.vehicles + 1] = m
            end
        end
    elseif kind == 'equipment' then
        p.kind = raw.kind == 'wheelchair' and 'wheelchair' or 'stretcher'
    elseif kind == 'elevator' then
        p.group = str(raw.group, 32, 'Elevator')
        p.floor = str(raw.floor, 24, 'Floor')
    elseif kind == 'board' or kind == 'sign' then
        p.width = Util.Clamp(tonumber(raw.width) or (kind == 'board' and 2.2 or 0.6), 0.2, 8.0)
        p.title = str(raw.title, 40, '')
        if kind == 'board' then
            p.rooms = {}
            for _, room in ipairs(type(raw.rooms) == 'table' and raw.rooms or {}) do
                local r = str(room, 24, '')
                if r ~= '' and #p.rooms < 40 then p.rooms[#p.rooms + 1] = r end
            end
        else
            p.room = str(raw.room, 24, '')
        end
    elseif kind == 'pharmacist' then
        p.ped = str(raw.ped, 48, (Config.Peds or {}).pharmacist or 's_m_m_doctor_01')
    end
    return p
end

function Hospitals.Sanitize(raw)
    if type(raw) ~= 'table' then return nil end
    local kind = KINDS[raw.kind] and raw.kind or 'hospital'
    local place = {
        id = tonumber(raw.id), kind = kind, name = str(raw.name, 48, kind == 'pharmacy' and 'Pharmacy' or 'Hospital'),
        blip = raw.blip ~= false, points = {},
        society = str(raw.society, 32, ''),
    }
    for t in pairs(Hospitals.Types) do
        local list = {}
        for _, rawPoint in ipairs(type(raw.points) == 'table' and type(raw.points[t]) == 'table' and raw.points[t] or {}) do
            local p = sanitizePoint(t, rawPoint)
            if p and #list < 120 then list[#list + 1] = p end
        end
        place.points[t] = list
    end
    return place
end

function Hospitals.Load()
    Hospitals.places, Hospitals.order = {}, {}
    local rows = MySQL.query.await('SELECT `id`, `kind`, `name`, `data` FROM `xs_medical_places` ORDER BY `id`') or {}
    for _, row in ipairs(rows) do
        local data = Db.Decode(row.data, {})
        data.id, data.kind, data.name = row.id, row.kind, row.name
        local place = Hospitals.Sanitize(data)
        if place then
            Hospitals.places[place.id] = place
            Hospitals.order[#Hospitals.order + 1] = place.id
        end
    end
    Hospitals.Publish()
end

function Hospitals.List()
    local out = {}
    for _, id in ipairs(Hospitals.order) do out[#out + 1] = Hospitals.places[id] end
    return out
end

function Hospitals.Publish()
    TriggerClientEvent('XS-Medical:client:places', -1, Hospitals.List())
end

function Hospitals.Save(place)
    local data = Db.Json({ blip = place.blip, points = place.points, society = place.society })
    if place.id and Hospitals.places[place.id] then
        MySQL.update.await('UPDATE `xs_medical_places` SET `kind` = ?, `name` = ?, `data` = ? WHERE `id` = ?', { place.kind, place.name, data, place.id })
    else
        place.id = MySQL.insert.await('INSERT INTO `xs_medical_places` (`kind`, `name`, `data`) VALUES (?, ?, ?)', { place.kind, place.name, data })
        if not place.id then return nil end
        Hospitals.order[#Hospitals.order + 1] = place.id
    end
    Hospitals.places[place.id] = place
    Hospitals.Publish()
    return place
end

function Hospitals.Delete(id)
    id = tonumber(id)
    if not id or not Hospitals.places[id] then return false end
    MySQL.query.await('DELETE FROM `xs_medical_places` WHERE `id` = ?', { id })
    Hospitals.places[id] = nil
    for i, value in ipairs(Hospitals.order) do
        if value == id then table.remove(Hospitals.order, i) break end
    end
    for key, occ in pairs(Hospitals.beds) do
        if occ.place == id then Hospitals.beds[key] = nil end
    end
    GlobalState['xsm:beds'] = Hospitals.BedMap()
    Hospitals.Publish()
    return true
end

function Hospitals.Get(id)
    return Hospitals.places[tonumber(id) or -1]
end

function Hospitals.Name(id)
    local place = Hospitals.Get(id)
    return place and place.name or Text('hospital_unknown')
end

function Hospitals.Point(place, kind, id)
    if not place then return nil end
    for _, p in ipairs(place.points[kind] or {}) do
        if p.id == id then return p end
    end
    return nil
end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Hospitals.Near(src, p, max)
    local c = coordsOf(src)
    if not c or not p then return false end
    return #(c - vector3(p.x, p.y, p.z)) <= (max or 3.0)
end

function Hospitals.Nearest(coords, kind)
    local best, bestDist = nil, math.huge
    for _, place in pairs(Hospitals.places) do
        if place.kind == (kind or 'hospital') then
            for _, list in pairs(place.points) do
                for _, p in ipairs(list) do
                    local d = #(coords - vector3(p.x, p.y, p.z))
                    if d < bestDist then best, bestDist = place, d end
                end
            end
        end
    end
    return best, bestDist
end

local function bedKey(placeId, bedId)
    return ('%s:%s'):format(placeId, bedId)
end

function Hospitals.BedMap()
    local out = {}
    for key, occ in pairs(Hospitals.beds) do out[key] = occ.src end
    return out
end

function Hospitals.Occupant(placeId, bedId)
    local occ = Hospitals.beds[bedKey(placeId, bedId)]
    if occ and GetPlayerName(occ.src) then return occ.src end
    return nil
end

function Hospitals.FreeBed(place, respawnOnly)
    for _, bed in ipairs(place.points.bed or {}) do
        if (not respawnOnly or bed.respawn) and not Hospitals.Occupant(place.id, bed.id) then return bed end
    end
    return nil
end

function Hospitals.Occupy(src, place, bed)
    Hospitals.FreeBedOf(src, true)
    Hospitals.beds[bedKey(place.id, bed.id)] = { src = src, place = place.id, bed = bed.id, at = os.time() }
    local s = State.Get(src)
    s.bed = bedKey(place.id, bed.id)
    GlobalState['xsm:beds'] = Hospitals.BedMap()
end

function Hospitals.FreeBedOf(src, quiet)
    local changed = false
    for key, occ in pairs(Hospitals.beds) do
        if occ.src == src then
            Hospitals.beds[key] = nil
            changed = true
        end
    end
    local s = State.Peek(src)
    if s then s.bed = nil end
    if changed and not quiet then GlobalState['xsm:beds'] = Hospitals.BedMap() end
    return changed
end

function Hospitals.BedOf(src)
    for _, occ in pairs(Hospitals.beds) do
        if occ.src == src then
            local place = Hospitals.Get(occ.place)
            return place, Hospitals.Point(place, 'bed', occ.bed), occ
        end
    end
    return nil
end

function Hospitals.RespawnSpot(src)
    local c = coordsOf(src) or vector3(0, 0, 0)
    local jailed = tonumber(Framework.GetMetaData(src, 'injail')) or 0
    local P = (Config.Respawn or {}).prison
    if jailed > 0 and P and P.enabled and P.coords then
        return { coords = { x = P.coords.x, y = P.coords.y, z = P.coords.z, w = P.coords.w }, inBed = false, recover = 0, jail = jailed }
    end

    local candidates = {}
    for _, place in pairs(Hospitals.places) do
        if place.kind == 'hospital' and #(place.points.bed or {}) > 0 then
            local first = place.points.bed[1]
            candidates[#candidates + 1] = { place = place, dist = #(c - vector3(first.x, first.y, first.z)) }
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    for _, entry in ipairs(candidates) do
        local bed = Hospitals.FreeBed(entry.place, true)
        if bed then
            Hospitals.Occupy(src, entry.place, bed)
            local v = Patients.Bed(src, entry.place.id, bed, 'recovering')
            v.identified = true
            return {
                coords = { x = bed.x, y = bed.y, z = bed.z, w = bed.w }, inBed = true, place = entry.place.id, bed = bed.id,
                recover = (Config.Respawn or {}).recoverSeconds or 25, prop = bed.prop,
            }
        end
    end

    local f = (Config.Respawn or {}).fallback or vec4(298.65, -584.5, 43.26, 72.0)
    return { coords = { x = f.x, y = f.y, z = f.z, w = f.w }, inBed = false, recover = 0 }
end

CreateThread(function()
    while true do
        Wait(1000)
        local changed = false
        for key, occ in pairs(Hospitals.beds) do
            if not GetPlayerName(occ.src) then
                Hospitals.beds[key] = nil
                changed = true
            else
                local s = State.Peek(occ.src)
                if s and s.status == 'alive' and Body.WorstBleed(s.injuries) == 0 and s.blood < 100 then
                    s.blood = math.min(100, s.blood + 0.25)
                end
            end
        end
        if changed then GlobalState['xsm:beds'] = Hospitals.BedMap() end
    end
end)

lib.callback.register('XS-Medical:server:places', function()
    return Hospitals.List()
end)
