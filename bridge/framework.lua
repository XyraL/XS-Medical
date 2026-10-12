if not IsDuplicityVersion() and type(RegisterNUICallback) == 'function' then
    local registerNui = RegisterNUICallback

    RegisterNUICallback = function(name, handler)
        return registerNui(name, function(data, cb)
            CreateThread(function()
                handler(data, function(payload, ...)
                    if payload == nil then payload = false end
                    cb(payload, ...)
                end)
            end)
        end)
    end
end

Framework = { name = nil, core = nil }

if not Config then
    print(('^1[XS-Medical]^0 config.lua did not load, so this resource cannot start.\n'
        .. '  Almost always start order. In server.cfg, these must come first:\n'
        .. '    ensure ox_lib\n'
        .. '    ensure oxmysql\n'
        .. '    ensure %s'):format(GetCurrentResourceName()))
    return
end

local forced = Config.Bridges and Config.Bridges.framework or 'auto'

if forced == 'qbox' or (forced == 'auto' and GetResourceState('qbx_core') == 'started') then
    Framework.name = 'qbox'
elseif forced == 'qbcore' or (forced == 'auto' and GetResourceState('qb-core') == 'started') then
    Framework.name = 'qbcore'
    Framework.core = exports['qb-core']:GetCoreObject()
else
    print('^1[XS-Medical]^0 No supported framework found. Start qbx_core or qb-core before XS-Medical.')
end

local IS_SERVER = IsDuplicityVersion()

local function gradeLevel(grade)
    if type(grade) == 'table' then return tonumber(grade.level) or 0 end
    return tonumber(grade) or 0
end

local function fullName(ci)
    ci = ci or {}
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

local function sortedGrades(grades)
    local out = {}
    for level, grade in pairs(grades or {}) do
        out[#out + 1] = {
            level = tonumber(level) or 0,
            label = type(grade) == 'table' and (grade.name or grade.label) or tostring(grade),
            isboss = type(grade) == 'table' and grade.isboss == true,
        }
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end

local function jobOf(data)
    local j = data and data.job
    if not j or not j.name then return nil end
    return {
        name = j.name,
        label = j.label or j.name,
        type = j.type,
        grade = gradeLevel(j.grade),
        gradeLabel = type(j.grade) == 'table' and (j.grade.name or j.grade.label) or nil,
        onDuty = j.onduty ~= false,
        isBoss = j.isboss == true or (type(j.grade) == 'table' and j.grade.isboss == true),
    }
end

Framework.JobOf = jobOf
Framework.FullName = fullName

function Framework.IsMedic(job, ignoreDuty)
    if not Util.IsMedicJob(job) then return false end
    if ignoreDuty or not (Config.Jobs and Config.Jobs.requireDuty) then return true end
    return job.onDuty == true
end

if IS_SERVER then
    function Framework.GetPlayer(src)
        src = tonumber(src)
        if not src then return nil end
        if Framework.name == 'qbox' then
            return exports.qbx_core:GetPlayer(src)
        elseif Framework.core then
            return Framework.core.Functions.GetPlayer(src)
        end
    end

    function Framework.GetPlayerByCitizenId(cid)
        if not cid then return nil end
        if Framework.name == 'qbox' then
            return exports.qbx_core:GetPlayerByCitizenId(cid)
        elseif Framework.core then
            return Framework.core.Functions.GetPlayerByCitizenId(cid)
        end
    end

    function Framework.Players()
        local out = {}
        if Framework.name == 'qbox' then
            for src in pairs(exports.qbx_core:GetQBPlayers() or {}) do out[#out + 1] = tonumber(src) end
        elseif Framework.core then
            for _, src in ipairs(Framework.core.Functions.GetPlayers() or {}) do out[#out + 1] = tonumber(src) end
        end
        return out
    end

    function Framework.GetCitizenId(src)
        local player = Framework.GetPlayer(src)
        return player and player.PlayerData.citizenid or nil
    end

    function Framework.GetName(src)
        local player = Framework.GetPlayer(src)
        if not player then return nil end
        return fullName(player.PlayerData.charinfo)
    end

    function Framework.GetCharInfo(src)
        local player = Framework.GetPlayer(src)
        local ci = player and player.PlayerData.charinfo or {}
        local gender = tonumber(ci.gender)
        if gender == nil then gender = (ci.gender == 'female' or ci.gender == 'f') and 1 or 0 end
        return {
            name = fullName(ci), firstname = ci.firstname or '', lastname = ci.lastname or '',
            dob = ci.birthdate or ci.dob or '', female = gender == 1, phone = ci.phone or '',
        }
    end

    function Framework.GetJob(src)
        local player = Framework.GetPlayer(src)
        return player and jobOf(player.PlayerData) or nil
    end

    function Framework.IsMedicSource(src, ignoreDuty)
        return Framework.IsMedic(Framework.GetJob(src), ignoreDuty)
    end

    function Framework.Medics(onDutyOnly)
        local out = {}
        for _, src in ipairs(Framework.Players()) do
            local job = Framework.GetJob(src)
            if Util.IsMedicJob(job) and (not onDutyOnly or Framework.IsMedic(job)) then out[#out + 1] = src end
        end
        return out
    end

    function Framework.Grades(name)
        local list
        if Framework.name == 'qbox' then
            list = exports.qbx_core:GetJobs()
        elseif Framework.core then
            list = Framework.core.Shared.Jobs
        end
        local def = list and list[name]
        return def and sortedGrades(def.grades) or {}, def and def.label or name
    end

    function Framework.GetMetaData(src, key)
        local player = Framework.GetPlayer(src)
        local meta = player and player.PlayerData.metadata or {}
        return meta[key]
    end

    function Framework.SetMetaData(src, key, value)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        if Framework.name == 'qbox' then
            local ok = pcall(function() exports.qbx_core:SetMetadata(src, key, value) end)
            if ok then return true end
        end
        player.Functions.SetMetaData(key, value)
        return true
    end

    function Framework.SetDuty(src, onDuty)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        player.Functions.SetJobDuty(onDuty == true)
        TriggerClientEvent('QBCore:Client:SetDuty', src, onDuty == true)
        TriggerEvent('QBCore:Server:SetDuty', src, onDuty == true)
        return true
    end

    function Framework.SetJob(src, name, grade)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.SetJob(name, grade) ~= false
    end

    function Framework.GetMoney(src)
        local player = Framework.GetPlayer(src)
        local m = player and player.PlayerData.money or {}
        return { cash = math.floor(tonumber(m.cash) or 0), bank = math.floor(tonumber(m.bank) or 0) }
    end

    function Framework.RemoveMoney(src, account, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return true end
        local player = Framework.GetPlayer(src)
        if not player then return false end
        local have = tonumber(player.PlayerData.money and player.PlayerData.money[account]) or 0
        if have < amount then return false end
        if Framework.name == 'qbox' then
            local ok, removed = pcall(function() return exports.qbx_core:RemoveMoney(src, account, amount, reason) end)
            if ok then return removed ~= false end
        end
        return player.Functions.RemoveMoney(account, amount, reason) ~= false
    end

    function Framework.AddMoney(src, account, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return true end
        local player = Framework.GetPlayer(src)
        if not player then return false end
        if Framework.name == 'qbox' then
            local ok, added = pcall(function() return exports.qbx_core:AddMoney(src, account, amount, reason) end)
            if ok then return added ~= false end
        end
        return player.Functions.AddMoney(account, amount, reason) ~= false
    end

    function Framework.Charge(src, amount, preferred, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return true, nil end
        local order = preferred == 'cash' and { 'cash', 'bank' } or { 'bank', 'cash' }
        for _, account in ipairs(order) do
            if Framework.RemoveMoney(src, account, amount, reason) then return true, account end
        end
        return false, nil
    end

    function Framework.SetStress(src, delta)
        local player = Framework.GetPlayer(src)
        if not player then return end
        local now = tonumber(player.PlayerData.metadata and player.PlayerData.metadata.stress) or 0
        local value = Util.Clamp(now + delta, 0, 100)
        Framework.SetMetaData(src, 'stress', value)
        TriggerClientEvent('hud:client:UpdateStress', src, value)
    end

    function Framework.RestoreNeeds(src)
        Framework.SetMetaData(src, 'hunger', 100)
        Framework.SetMetaData(src, 'thirst', 100)
        TriggerClientEvent('hud:client:UpdateNeeds', src, 100, 100)
    end

    function Framework.Vehicles()
        local list = {}
        local source = nil
        if Framework.name == 'qbox' then
            local ok, vehicles = pcall(function() return exports.qbx_core:GetVehiclesByName() end)
            source = ok and vehicles or nil
        elseif Framework.core then
            source = Framework.core.Shared.Vehicles
        end
        for model, v in pairs(source or {}) do
            list[#list + 1] = {
                model = v.model or model,
                label = ((v.brand and v.brand ~= '' and (v.brand .. ' ') or '') .. (v.name or model)),
                category = v.category or '',
            }
        end
        table.sort(list, function(a, b) return a.label < b.label end)
        return list
    end

    function Framework.IsAdmin(src)
        local A = Config.Admin or {}
        if A.acePermission and IsPlayerAceAllowed(src, A.acePermission) then return true end

        local license = GetPlayerIdentifierByType(src, 'license')
        for _, lic in ipairs(A.licenses or {}) do
            if license == lic then return true end
        end

        for _, g in ipairs(A.groups or {}) do
            if Framework.name == 'qbox' then
                if IsPlayerAceAllowed(src, 'group.' .. g) then return true end
                local ok, allowed = pcall(function() return exports.qbx_core:HasPermission(src, g) end)
                if ok and allowed then return true end
            elseif Framework.core then
                if Framework.core.Functions.HasPermission(src, g) then return true end
            end
        end
        return false
    end

    local loadedHooks, unloadedHooks = {}, {}

    function Framework.OnLoaded(fn) loadedHooks[#loadedHooks + 1] = fn end
    function Framework.OnUnloaded(fn) unloadedHooks[#unloadedHooks + 1] = fn end

    local function fireLoaded(src)
        for _, fn in ipairs(loadedHooks) do
            local ok, err = pcall(fn, src)
            if not ok then print(('^1[XS-Medical]^0 player load hook failed: %s'):format(tostring(err))) end
        end
    end

    local function fireUnloaded(src)
        for _, fn in ipairs(unloadedHooks) do
            local ok, err = pcall(fn, src)
            if not ok then print(('^1[XS-Medical]^0 player unload hook failed: %s'):format(tostring(err))) end
        end
    end

    AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
        local src = player and player.PlayerData and player.PlayerData.source
        if src then fireLoaded(src) end
    end)

    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
        fireUnloaded(tonumber(src) or source)
    end)

    AddEventHandler('playerDropped', function()
        fireUnloaded(source)
    end)
else
    function Framework.PlayerData()
        if Framework.name == 'qbox' then
            local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
            return ok and data or {}
        elseif Framework.core then
            return Framework.core.Functions.GetPlayerData() or {}
        end
        return {}
    end

    function Framework.CitizenId()
        return Framework.PlayerData().citizenid
    end

    function Framework.Job()
        return jobOf(Framework.PlayerData())
    end

    function Framework.Name()
        return fullName(Framework.PlayerData().charinfo)
    end

    function Framework.IsMedicLocal(ignoreDuty)
        return Framework.IsMedic(Framework.Job(), ignoreDuty)
    end

    function Framework.Loaded()
        return Framework.PlayerData().citizenid ~= nil
    end

    local loadedHooks, unloadedHooks, jobHooks = {}, {}, {}

    function Framework.OnLoaded(fn) loadedHooks[#loadedHooks + 1] = fn end
    function Framework.OnUnloaded(fn) unloadedHooks[#unloadedHooks + 1] = fn end
    function Framework.OnJob(fn) jobHooks[#jobHooks + 1] = fn end

    local function run(list, ...)
        for _, fn in ipairs(list) do
            local ok, err = pcall(fn, ...)
            if not ok then print(('^1[XS-Medical]^0 hook failed: %s'):format(tostring(err))) end
        end
    end

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() run(loadedHooks) end)
    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() run(unloadedHooks) end)
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function() SetTimeout(200, function() run(jobHooks, Framework.Job()) end) end)
    RegisterNetEvent('QBCore:Client:SetDuty', function() SetTimeout(200, function() run(jobHooks, Framework.Job()) end) end)
end

function Framework.Notify(...)
    local args = { ... }
    if IS_SERVER then
        local src, msg, kind = args[1], args[2], args[3]
        if not src or src <= 0 then return end
        TriggerClientEvent('ox_lib:notify', src, { title = Text('notify_title'), description = msg, type = kind or 'inform' })
        return
    end
    lib.notify({ title = Text('notify_title'), description = args[1], type = args[2] or 'inform' })
end
