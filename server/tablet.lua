Tablet = {}

local function medic(src)
    local job = Framework.GetJob(src)
    if not Framework.IsMedic(job) then return nil end
    return job
end

local function allowed(job, power)
    if not job then return false end
    if job.isBoss then return true end
    return (job.grade or 0) >= ((Config.Grades or {})[power] or 0)
end

local RECORD_PAGES = { 'records', 'prescribe', 'reports' }

local PAGES_OF = {
    recordsSearch = RECORD_PAGES, recordsOpen = RECORD_PAGES, recordsSave = { 'records' },
    rxCreate = { 'prescribe' }, rxVoid = { 'prescribe' },
    reportsList = { 'reports' }, reportsGet = { 'reports' }, reportsSave = { 'reports' }, reportsDelete = { 'reports' },
    roster = { 'roster' }, callsign = { 'roster' }, hire = { 'roster' }, setGrade = { 'roster' }, fire = { 'roster' },
}

function Tablet.PageOn(page)
    return (((Config.Tablet or {}).pages or {})[page]) ~= false
end

local function pagesOn(list)
    if not list then return true end
    for _, page in ipairs(list) do
        if Tablet.PageOn(page) then return true end
    end
    return false
end

local function guard(name, power, handler)
    local pages = PAGES_OF[name]
    lib.callback.register('XS-Medical:server:' .. name, function(src, ...)
        if not pagesOn(pages) then return false, Text('err_page_off') end
        local job = medic(src)
        if not job then return false, Text('err_medics_only') end
        if power and not allowed(job, power) then return false, Text('err_grade') end
        return handler(src, job, ...)
    end)
end

local function callsign(cid)
    local row = cid and MySQL.single.await('SELECT `callsign` FROM `xs_medical_staff` WHERE `citizenid` = ?', { cid })
    return row and row.callsign or ''
end

local function nearby(src, radius)
    local origin = GetEntityCoords(GetPlayerPed(src))
    local out = {}
    for _, other in ipairs(Framework.Players()) do
        if other ~= src then
            local ped = GetPlayerPed(other)
            if ped ~= 0 then
                local dist = #(GetEntityCoords(ped) - origin)
                if dist <= (radius or 10.0) then
                    local v = Patients.Get(other)
                    local s = State.Peek(other)
                    local name = v and Patients.Display(v) or nil
                    if not name then
                        local ci = Framework.GetCharInfo(other)
                        name = ci.female and Text('alias_female') or Text('alias_male')
                    end
                    out[#out + 1] = {
                        src = other, name = name, dist = Util.Round(dist, 1), status = s and s.status or 'alive',
                        acuity = (Player(other).state.xsm or {}).acuity or 5,
                    }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

local function places()
    local out = {}
    for _, place in ipairs(Hospitals.List()) do
        if place.kind == 'hospital' then
            local beds, free, waiting = 0, 0, 0
            for _, bed in ipairs(place.points.bed or {}) do
                beds = beds + 1
                if not Hospitals.Occupant(place.id, bed.id) then free = free + 1 end
            end
            for _, row in ipairs(Patients.Board(place.id)) do
                if row.status == 'waiting' then waiting = waiting + 1 end
            end
            out[#out + 1] = { id = place.id, name = place.name, beds = beds, free = free, waiting = waiting }
        end
    end
    return out
end

local function units()
    local onCall = {}
    for _, c in ipairs(Calls.List()) do
        for _, u in ipairs(c.units) do
            if not onCall[u.src] then onCall[u.src] = c.id end
        end
    end
    local out = {}
    for _, other in ipairs(Framework.Players()) do
        local j = Framework.GetJob(other)
        if Util.IsMedicJob(j) then
            local otherCid = Framework.GetCitizenId(other)
            out[#out + 1] = {
                src = other, cid = otherCid, name = Framework.GetName(other) or '', callsign = callsign(otherCid),
                gradeLabel = j.gradeLabel or '', onDuty = Framework.IsMedic(j), call = onCall[other],
            }
        end
    end
    table.sort(out, function(a, b)
        if a.onDuty ~= b.onDuty then return a.onDuty end
        return a.name < b.name
    end)
    return out
end

local function callsFor(src)
    local list = Calls.List()
    local ped = GetPlayerPed(src)
    if ped == 0 then return list end
    local origin = GetEntityCoords(ped)
    for _, c in ipairs(list) do
        if c.coords then c.dist = math.floor(#(origin - vector3(c.coords.x, c.coords.y, c.coords.z))) end
    end
    return list
end

guard('tablet', nil, function(src, job)
    local cid = Framework.GetCitizenId(src)
    local grades = {}
    for power in pairs(Config.Grades or {}) do grades[power] = allowed(job, power) and true or false end
    return true, {
        me = { src = src, cid = cid, name = Framework.GetName(src) or '', callsign = callsign(cid), grade = job.grade, gradeLabel = job.gradeLabel or '', isBoss = job.isBoss, job = job.name, jobLabel = job.label, onDuty = Framework.IsMedic(job) },
        can = grades, patients = Patients.List(), calls = callsFor(src), places = places(), units = units(), nearby = nearby(src, 12.0),
        medicines = Config.Medicines or {}, supplies = (function()
            local out = {}
            for key, s in pairs(Config.Supplies or {}) do out[key] = { item = s.item, label = Inventory.Label(s.item), anyone = s.anyone } end
            return out
        end)(),
    }
end)

guard('nearby', nil, function(src)
    return true, nearby(src, 12.0)
end)

guard('patient', nil, function(src, job, target)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false, Text('err_no_patient') end
    local ped, mine = GetPlayerPed(target), GetPlayerPed(src)
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(mine))
    local v = Patients.Get(target)
    if dist > 25.0 and not v then return false, Text('err_too_far') end
    local s = State.Get(target)
    local pub = State.Public(target, s)
    local ci = Framework.GetCharInfo(target)
    local identified = v and v.identified or false
    local record = nil
    if identified then
        local row = Records.Ensure(Framework.GetCitizenId(target), target)
        if row then
            record = { blood = row.blood, allergies = row.allergies or '', conditions = row.conditions or '', dob = row.dob or '' }
            record.prescriptions = Records.Prescriptions(row.citizenid, true)
        end
    end
    return true, {
        src = target, name = v and Patients.Display(v) or (ci.female and Text('alias_female') or Text('alias_male')),
        realName = identified and ci.name or nil, cid = identified and Framework.GetCitizenId(target) or nil,
        identified = identified, female = ci.female, near = dist <= 4.0, dist = Util.Round(dist, 1),
        state = pub, visit = v and { room = v.room, status = v.status, hospital = v.hospital and Hospitals.Name(v.hospital) or nil, since = v.since, medic = v.medic and v.medic.name or nil } or nil,
        timeline = v and v.timeline or {}, cleared = v and v.cleared or {}, record = record,
    }
end)

guard('recordsSearch', nil, function(_, _, term)
    return true, Records.Search(term)
end)

guard('recordsOpen', nil, function(_, _, cid)
    local record = Records.Open(Util.Text(cid, 64))
    if not record then return false, Text('err_no_record') end
    return true, record
end)

guard('recordsSave', 'editRecords', function(src, _, cid, fields)
    if type(fields) ~= 'table' then return false end
    return Records.Update(Util.Text(cid, 64), fields, src), nil
end)

guard('rxCreate', 'prescribe', function(src, _, cid, data)
    if type(data) ~= 'table' then return false end
    local ok, id = Records.Prescribe(src, Util.Text(cid, 64), data)
    if not ok then return false, Text(id or 'err_failed') end
    local target = Framework.GetPlayerByCitizenId(cid)
    if target then Framework.Notify(target.PlayerData.source, Text('rx_waiting'), 'inform') end
    return true, id
end)

guard('rxVoid', 'prescribe', function(src, _, id)
    return Records.Void(src, tonumber(id)), nil
end)

guard('reportsList', nil, function(_, _, term)
    return true, Records.Reports(term)
end)

guard('reportsGet', nil, function(_, _, id)
    local row = Records.Report(tonumber(id))
    if not row then return false, Text('err_no_record') end
    return true, row
end)

guard('reportsSave', nil, function(src, job, data)
    if type(data) ~= 'table' or Util.Text(data.title, 128) == '' then return false, Text('err_report_title') end
    if data.id then
        local row = Records.Report(tonumber(data.id))
        if not row then return false, Text('err_no_record') end
        if row.author_cid ~= Framework.GetCitizenId(src) and not allowed(job, 'editReports') then return false, Text('err_grade') end
    end
    local id = Records.SaveReport(src, data)
    return id ~= nil, id
end)

guard('reportsDelete', 'deleteReports', function(_, _, id)
    return Records.DeleteReport(tonumber(id)), nil
end)

guard('calls', nil, function(src)
    return true, callsFor(src)
end)

guard('shift', nil, function()
    return true, { units = units(), places = places() }
end)

guard('callTake', nil, function(src, _, id)
    local ok, call = Calls.Take(src, id)
    if not ok then return false, Text('err_call_gone') end
    return true, call
end)

guard('callLeave', nil, function(src, _, id)
    return Calls.Leave(src, id), nil
end)

guard('callClose', nil, function(_, _, id)
    return Calls.Close(id), nil
end)

local function employees(job)
    local out = {}
    local ok = pcall(function()
        if Framework.name == 'qbox' then
            local rows = MySQL.query.await("SELECT pg.`citizenid`, pg.`grade`, p.`charinfo` FROM `player_groups` pg LEFT JOIN `players` p ON p.`citizenid` = pg.`citizenid` WHERE pg.`group` = ? AND pg.`type` = 'job'", { job }) or {}
            for _, r in ipairs(rows) do
                out[#out + 1] = { cid = r.citizenid, grade = tonumber(r.grade) or 0, name = Framework.FullName(Db.Decode(r.charinfo, {})) }
            end
        else
            error('use players table')
        end
    end)
    if not ok then
        local rows = MySQL.query.await("SELECT `citizenid`, `charinfo`, `job` FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(`job`, '$.name')) = ?", { job }) or {}
        for _, r in ipairs(rows) do
            local j = Db.Decode(r.job, {})
            local grade = type(j.grade) == 'table' and (tonumber(j.grade.level) or 0) or (tonumber(j.grade) or 0)
            out[#out + 1] = { cid = r.citizenid, grade = grade, name = Framework.FullName(Db.Decode(r.charinfo, {})) }
        end
    end
    return out
end

guard('roster', nil, function(src, job)
    local online = {}
    local onlineCids = {}
    for _, other in ipairs(Framework.Players()) do
        local j = Framework.GetJob(other)
        if Util.IsMedicJob(j) then
            local cid = Framework.GetCitizenId(other)
            onlineCids[cid or ''] = true
            online[#online + 1] = {
                src = other, cid = cid, name = Framework.GetName(other) or '', grade = j.grade, gradeLabel = j.gradeLabel or '',
                onDuty = j.onDuty, callsign = callsign(cid), job = j.name,
            }
        end
    end
    table.sort(online, function(a, b) return (a.onDuty and 1 or 0) > (b.onDuty and 1 or 0) end)
    local staff = {}
    if allowed(job, 'manage') then
        for _, e in ipairs(employees(job.name)) do
            e.online = onlineCids[e.cid] == true
            staff[#staff + 1] = e
        end
    end
    local grades = Framework.Grades(job.name)
    return true, { online = online, staff = staff, grades = grades, canManage = allowed(job, 'manage'), balance = Banking.Balance((Config.Jobs or {}).society or job.name) }
end)

guard('callsign', nil, function(src, _, value)
    local cid = Framework.GetCitizenId(src)
    value = Util.Text(value, 16):upper()
    MySQL.query.await('INSERT INTO `xs_medical_staff` (`citizenid`, `callsign`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `callsign` = VALUES(`callsign`)', { cid, value })
    return true, value
end)

guard('hire', 'manage', function(src, job, target, grade)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false, Text('err_no_player') end
    grade = Util.Clamp(math.floor(tonumber(grade) or 0), 0, job.isBoss and 50 or job.grade)
    if Framework.name == 'qbox' then
        pcall(function() exports.qbx_core:AddPlayerToJob(Framework.GetCitizenId(target), job.name, grade) end)
    end
    Framework.SetJob(target, job.name, grade)
    Framework.Notify(target, Text('hired', { job = job.label }), 'success')
    return true
end)

local function setOffline(cid, jobName, grade)
    if Framework.name == 'qbox' then
        local ok = pcall(function()
            if grade then exports.qbx_core:AddPlayerToJob(cid, jobName, grade) else exports.qbx_core:RemovePlayerFromJob(cid, jobName) end
        end)
        if ok then return true end
    end
    local row = MySQL.single.await('SELECT `job` FROM `players` WHERE `citizenid` = ?', { cid })
    if not row then return false end
    local current = Db.Decode(row.job, {})
    if grade then
        local grades = Framework.Grades(jobName)
        local label = ''
        for _, g in ipairs(grades) do if g.level == grade then label = g.label end end
        current.grade = { level = grade, name = label }
    else
        current = { name = 'unemployed', label = 'Civilian', payment = 10, onduty = false, isboss = false, grade = { name = 'Freelancer', level = 0 } }
    end
    MySQL.update.await('UPDATE `players` SET `job` = ? WHERE `citizenid` = ?', { json.encode(current), cid })
    return true
end

guard('setGrade', 'manage', function(src, job, cid, grade)
    cid = Util.Text(cid, 64)
    if cid == Framework.GetCitizenId(src) then return false, Text('err_not_self') end
    grade = Util.Clamp(math.floor(tonumber(grade) or 0), 0, job.isBoss and 50 or job.grade)
    local online = Framework.GetPlayerByCitizenId(cid)
    if online then
        if Framework.name == 'qbox' then pcall(function() exports.qbx_core:AddPlayerToJob(cid, job.name, grade) end) end
        Framework.SetJob(online.PlayerData.source, job.name, grade)
        return true
    end
    return setOffline(cid, job.name, grade), nil
end)

guard('fire', 'manage', function(src, job, cid)
    cid = Util.Text(cid, 64)
    if cid == Framework.GetCitizenId(src) then return false, Text('err_not_self') end
    local online = Framework.GetPlayerByCitizenId(cid)
    if online then
        if Framework.name == 'qbox' then pcall(function() exports.qbx_core:RemovePlayerFromJob(cid, job.name) end) end
        Framework.SetJob(online.PlayerData.source, 'unemployed', 0)
        Framework.Notify(online.PlayerData.source, Text('fired', { job = job.label }), 'error')
        return true
    end
    return setOffline(cid, job.name, nil), nil
end)

guard('hospital', nil, function(_, _, placeId)
    local place = Hospitals.Get(placeId)
    if not place then return false, Text('err_unknown_place') end
    local beds = {}
    for _, bed in ipairs(place.points.bed or {}) do
        local occ = Hospitals.Occupant(place.id, bed.id)
        local v = occ and Patients.Get(occ) or nil
        beds[#beds + 1] = {
            id = bed.id, label = bed.label, room = bed.room, occupant = occ,
            name = occ and (v and Patients.Display(v) or Text('hs_occupied')) or nil,
            status = v and v.status or nil, acuity = occ and (Player(occ).state.xsm or {}).acuity or nil,
        }
    end
    return true, { id = place.id, name = place.name, beds = beds, board = Patients.Board(place.id) }
end)

guard('bill', nil, function(src, _, target, amount, reason)
    target = tonumber(target)
    amount = math.floor(tonumber(amount) or 0)
    if not target or not GetPlayerName(target) then return false, Text('err_no_patient') end
    if amount <= 0 or amount > 50000 then return false, Text('err_bad_amount') end
    Tablet.bills = Tablet.bills or {}
    local id = Util.Id('b')
    Tablet.bills[id] = { from = src, to = target, amount = amount, reason = Util.Text(reason, 80), at = os.time() }
    TriggerClientEvent('XS-Medical:client:bill', target, { id = id, amount = amount, reason = Util.Text(reason, 80), from = Framework.GetName(src) or '' })
    return true
end)

lib.callback.register('XS-Medical:server:billAnswer', function(src, id, accept)
    local bill = Tablet.bills and Tablet.bills[id]
    if not bill or bill.to ~= src then return false end
    Tablet.bills[id] = nil
    if not accept then
        Framework.Notify(bill.from, Text('bill_declined'), 'error')
        return true
    end
    if not Framework.Charge(src, bill.amount, 'bank', 'medical-bill') then
        Framework.Notify(bill.from, Text('bill_cannot_pay'), 'error')
        return false, Text('err_no_money', { amount = bill.amount })
    end
    Banking.Deposit((Config.Jobs or {}).society or 'ambulance', bill.amount, 'Medical bill')
    Framework.Notify(bill.from, Text('bill_paid', { amount = bill.amount }), 'success')
    Records.Log(Framework.GetCitizenId(src), 'bill', Text('log_billed', { amount = bill.amount, reason = bill.reason }), nil, bill.from)
    return true
end)
