Records = {}

local BLOOD = { 'O+', 'O+', 'O+', 'A+', 'A+', 'B+', 'O-', 'A-', 'AB+', 'B-', 'AB-' }

local function cidOk(cid)
    return type(cid) == 'string' and cid ~= '' and #cid <= 64
end

function Records.Log(cid, kind, summary, data, by)
    if not cidOk(cid) or not Db.ready then return end
    local medicCid, medicName = '', ''
    if by then
        medicCid = Framework.GetCitizenId(by) or ''
        medicName = Framework.GetName(by) or ''
    end
    MySQL.insert('INSERT INTO `xs_medical_history` (`citizenid`, `kind`, `summary`, `data`, `medic_cid`, `medic_name`) VALUES (?, ?, ?, ?, ?, ?)', {
        cid, Util.Text(kind, 24), Util.Text(summary, 255), data and Db.Json(data) or nil, medicCid, medicName,
    })
end

function Records.Ensure(cid, src)
    if not cidOk(cid) then return nil end
    local row = MySQL.single.await('SELECT * FROM `xs_medical_records` WHERE `citizenid` = ?', { cid })
    if row then return row end
    local name, dob, female = '', '', false
    if src then
        local ci = Framework.GetCharInfo(src)
        name, dob, female = ci.name, ci.dob, ci.female
    else
        local player = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { cid })
        local ci = player and Db.Decode(player.charinfo, {}) or {}
        name = Framework.FullName(ci)
        dob = ci.birthdate or ''
        female = tonumber(ci.gender) == 1
    end
    local blood = BLOOD[math.random(1, #BLOOD)]
    MySQL.insert.await('INSERT IGNORE INTO `xs_medical_records` (`citizenid`, `name`, `dob`, `female`, `blood`, `allergies`, `conditions`, `notes`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        cid, name, dob, female and 1 or 0, blood, '', '', '',
    })
    return MySQL.single.await('SELECT * FROM `xs_medical_records` WHERE `citizenid` = ?', { cid })
end

local function shape(row)
    if not row then return nil end
    return {
        cid = row.citizenid, name = row.name, dob = row.dob, female = Util.Truthy(row.female), blood = row.blood,
        allergies = row.allergies or '', conditions = row.conditions or '', notes = row.notes or '',
        updatedBy = row.updated_by or '', updatedAt = row.updated_at,
    }
end

function Records.Search(term)
    term = Util.Text(term, 48)
    if #term < 2 then return {} end
    local like = '%' .. term:gsub('[%%_]', '') .. '%'
    local rows = MySQL.query.await([[
        SELECT `citizenid`, `charinfo` FROM `players`
        WHERE `citizenid` LIKE ? OR CONCAT(JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.lastname'))) LIKE ?
        LIMIT 25
    ]], { like, like }) or {}
    local out = {}
    for _, row in ipairs(rows) do
        local ci = Db.Decode(row.charinfo, {})
        out[#out + 1] = { cid = row.citizenid, name = Framework.FullName(ci), dob = ci.birthdate or '' }
    end
    return out
end

function Records.Open(cid)
    local row = Records.Ensure(cid)
    if not row then return nil end
    local record = shape(row)
    record.history = MySQL.query.await('SELECT `id`, `kind`, `summary`, `medic_name`, `created_at` FROM `xs_medical_history` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 60', { cid }) or {}
    record.prescriptions = Records.Prescriptions(cid, false)
    record.reports = MySQL.query.await('SELECT `id`, `title`, `author_name`, `created_at`, `data` FROM `xs_medical_reports` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 30', { cid }) or {}
    for _, row in ipairs(record.reports) do
        local d = Db.Decode(row.data, {})
        row.incidentAt, row.category, row.outcome = d.incidentAt, d.category, d.outcome
        row.data = nil
    end
    return record
end

function Records.Update(cid, fields, by)
    if not cidOk(cid) then return false end
    Records.Ensure(cid)
    MySQL.update.await('UPDATE `xs_medical_records` SET `allergies` = ?, `conditions` = ?, `notes` = ?, `blood` = ?, `updated_by` = ? WHERE `citizenid` = ?', {
        Util.Lines(fields.allergies, 500), Util.Lines(fields.conditions, 800), Util.Lines(fields.notes, 2000),
        Util.Text(fields.blood, 4), Framework.GetName(by) or '', cid,
    })
    Records.Log(cid, 'record', Text('log_record_edit'), nil, by)
    return true
end

function Records.Prescriptions(cid, activeOnly)
    if not cidOk(cid) then return {} end
    MySQL.update.await("UPDATE `xs_medical_prescriptions` SET `status` = 'expired' WHERE `citizenid` = ? AND `status` = 'active' AND `expires_at` IS NOT NULL AND `expires_at` < NOW()", { cid })
    local sql = 'SELECT * FROM `xs_medical_prescriptions` WHERE `citizenid` = ?' .. (activeOnly and " AND `status` = 'active'" or '') .. ' ORDER BY `id` DESC LIMIT 40'
    local rows = MySQL.query.await(sql, { cid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = r.id, item = r.item, label = r.label, dose = r.dose, qty = r.qty, refills = r.refills, notes = r.notes,
            prescriber = r.prescriber_name, status = r.status, createdAt = r.created_at, expiresAt = r.expires_at,
        }
    end
    return out
end

function Records.Medicine(item)
    for _, m in ipairs(Config.Medicines or {}) do
        if m.item == item then return m end
    end
    return nil
end

function Records.Prescribe(by, cid, data)
    local med = Records.Medicine(tostring(data.item or ''))
    if not med then return false, 'err_unknown_medicine' end
    if not cidOk(cid) then return false, 'err_no_patient' end
    local record = Records.Ensure(cid)
    local qty = Util.Clamp(math.floor(tonumber(data.qty) or 1), 1, 30)
    local refills = Util.Clamp(math.floor(tonumber(data.refills) or 0), 0, (Config.Prescriptions or {}).maxRefills or 5)
    local days = (Config.Prescriptions or {}).expiresDays or 14
    local id = MySQL.insert.await([[
        INSERT INTO `xs_medical_prescriptions` (`citizenid`, `patient_name`, `item`, `label`, `dose`, `qty`, `refills`, `notes`, `prescriber_cid`, `prescriber_name`, `status`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', DATE_ADD(NOW(), INTERVAL ? DAY))
    ]], {
        cid, record and record.name or '', med.item, med.label, Util.Text(data.dose ~= '' and data.dose or med.dose, 32), qty, refills,
        Util.Text(data.notes, 255), Framework.GetCitizenId(by) or '', Framework.GetName(by) or '', days,
    })
    Records.Log(cid, 'prescription', Text('log_prescribed', { label = med.label, qty = qty }), { id = id }, by)
    return id ~= nil, id
end

function Records.Void(by, id)
    local row = MySQL.single.await('SELECT `citizenid`, `label` FROM `xs_medical_prescriptions` WHERE `id` = ?', { id })
    if not row then return false end
    MySQL.update.await("UPDATE `xs_medical_prescriptions` SET `status` = 'void' WHERE `id` = ?", { id })
    Records.Log(row.citizenid, 'prescription', Text('log_voided', { label = row.label }), { id = id }, by)
    return true
end

function Records.Fill(id, cid)
    local row = MySQL.single.await("SELECT * FROM `xs_medical_prescriptions` WHERE `id` = ? AND `citizenid` = ? AND `status` = 'active' AND (`expires_at` IS NULL OR `expires_at` > NOW())", { id, cid })
    if not row then return nil end
    if (tonumber(row.refills) or 0) > 0 then
        MySQL.update.await('UPDATE `xs_medical_prescriptions` SET `refills` = `refills` - 1 WHERE `id` = ?', { id })
    else
        MySQL.update.await("UPDATE `xs_medical_prescriptions` SET `status` = 'filled' WHERE `id` = ?", { id })
    end
    return row
end

local CATEGORIES = { trauma = true, medical = true, traffic = true, assault = true, overdose = true, fire = true, other = true }
local OUTCOMES = { scene = true, transported = true, admitted = true, refused = true, deceased = true }

local function lines(list, most, size)
    local out = {}
    for _, value in ipairs(type(list) == 'table' and list or {}) do
        local text = Util.Text(value, size)
        if text ~= '' and #out < most then out[#out + 1] = text end
    end
    return out
end

local function reportData(raw)
    local v = type(raw.vitals) == 'table' and raw.vitals or {}
    local crew = {}
    for _, c in ipairs(type(raw.crew) == 'table' and raw.crew or {}) do
        local name = type(c) == 'table' and Util.Text(c.name, 96) or ''
        if name ~= '' and #crew < 8 then crew[#crew + 1] = { cid = Util.Text(c.cid, 64), name = name, callsign = Util.Text(c.callsign, 16) } end
    end
    local now = os.time()
    local at = math.floor(tonumber(raw.incidentAt) or now)
    if at < now - 86400 * 3650 or at > now + 86400 then at = now end
    return {
        v = 2, incidentAt = at,
        category = CATEGORIES[raw.category] and raw.category or 'other',
        outcome = OUTCOMES[raw.outcome] and raw.outcome or 'scene',
        location = Util.Text(raw.location, 80), destination = Util.Text(raw.destination, 64),
        complaint = Util.Text(raw.complaint, 160), callId = tonumber(raw.callId) and math.floor(tonumber(raw.callId)) or nil,
        crew = crew,
        vitals = {
            hr = Util.Text(v.hr, 8), bp = Util.Text(v.bp, 12), spo2 = Util.Text(v.spo2, 8), resp = Util.Text(v.resp, 8),
            temp = Util.Text(v.temp, 8), pain = Util.Text(v.pain, 8), avpu = Util.Text(v.avpu, 2),
        },
        injuries = lines(raw.injuries, 30, 160),
        treatments = lines(raw.treatments, 40, 160),
    }
end

function Records.SaveReport(by, raw)
    local cid = Util.Text(raw.cid, 64)
    local data = reportData(raw)
    local id = tonumber(raw.id)
    if id then
        data.editedBy = Framework.GetName(by) or ''
        data.editedAt = os.time()
        MySQL.update.await('UPDATE `xs_medical_reports` SET `citizenid` = ?, `patient_name` = ?, `title` = ?, `body` = ?, `data` = ? WHERE `id` = ?', {
            cid, Util.Text(raw.patient, 96), Util.Text(raw.title, 128), Util.Lines(raw.body, 6000), Db.Json(data), id,
        })
        return id
    end
    id = MySQL.insert.await('INSERT INTO `xs_medical_reports` (`citizenid`, `patient_name`, `title`, `body`, `data`, `author_cid`, `author_name`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        cid, Util.Text(raw.patient, 96), Util.Text(raw.title, 128), Util.Lines(raw.body, 6000), Db.Json(data),
        Framework.GetCitizenId(by) or '', Framework.GetName(by) or '',
    })
    if cid ~= '' and id then Records.Log(cid, 'report', Text('log_report', { title = Util.Text(raw.title, 80) }), { id = id }, by) end
    return id
end

function Records.Reports(term)
    term = Util.Text(term, 48)
    local rows
    local cols = 'SELECT `id`, `citizenid`, `patient_name`, `title`, `author_name`, `author_cid`, `created_at`, `data` FROM `xs_medical_reports`'
    if term ~= '' then
        local like = '%' .. term:gsub('[%%_]', '') .. '%'
        rows = MySQL.query.await(cols .. ' WHERE `patient_name` LIKE ? OR `title` LIKE ? OR `citizenid` = ? OR `author_name` LIKE ? ORDER BY `id` DESC LIMIT 40', { like, like, term, like })
    else
        rows = MySQL.query.await(cols .. ' ORDER BY `id` DESC LIMIT 40')
    end
    rows = rows or {}
    for _, row in ipairs(rows) do
        local d = Db.Decode(row.data, {})
        row.incidentAt, row.category, row.outcome = d.incidentAt, d.category, d.outcome
        row.data = nil
    end
    return rows
end

function Records.Report(id)
    local row = MySQL.single.await('SELECT * FROM `xs_medical_reports` WHERE `id` = ?', { id })
    if not row then return nil end
    row.data = Db.Decode(row.data, {})
    return row
end

function Records.DeleteReport(id)
    MySQL.query.await('DELETE FROM `xs_medical_reports` WHERE `id` = ?', { id })
    return true
end
