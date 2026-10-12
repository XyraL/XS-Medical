Screens = { list = {}, live = {}, pool = { board = {}, sign = {}, monitor = {} }, drawing = false, counter = 0 }

local SIZES = {
    board = { 1280, 720 },
    sign = { 640, 400 },
    monitor = { 800, 500 },
}

local function url(kind)
    return ('nui://%s/html/dui/screen.html?kind=%s'):format(GetCurrentResourceName(), kind)
end

local function corners(s)
    local h = math.rad(s.h or 0.0)
    local right = vector3(-math.cos(h), -math.sin(h), 0.0)
    local up = vector3(0.0, 0.0, 1.0)
    local normal = vector3(-math.sin(h), math.cos(h), 0.0)
    local c = vector3(s.x, s.y, s.z) + normal * 0.012
    local hw, hh = s.width / 2, s.height / 2
    return c - right * hw + up * hh, c + right * hw + up * hh, c - right * hw - up * hh, c + right * hw - up * hh, normal, c
end

local function newDui(kind)
    Screens.counter = Screens.counter + 1
    local size = SIZES[kind]
    local dui = CreateDui(url(kind), size[1], size[2])
    if not dui then return nil end
    local untilAt = GetGameTimer() + 3000
    while not IsDuiAvailable(dui) and GetGameTimer() < untilAt do Wait(50) end
    local tag = ('%s_%d_%d'):format(kind, GetGameTimer(), Screens.counter)
    local txdName, txnName = 'xsm_txd_' .. tag, 'xsm_tex_' .. tag
    local txd = CreateRuntimeTxd(txdName)
    CreateRuntimeTextureFromDuiHandle(txd, txnName, GetDuiHandle(dui))
    return { dui = dui, txd = txdName, txn = txnName, kind = kind }
end

function Screens.Attach(screen)
    local pool = Screens.pool[screen.kind]
    local handle = table.remove(pool) or newDui(screen.kind)
    if not handle then return end
    handle.screen, handle.sent, handle.attachedAt = screen, nil, GetGameTimer()
    Screens.live[screen.id] = handle
end

function Screens.Detach(id)
    local live = Screens.live[id]
    if not live then return end
    Screens.live[id] = nil
    live.screen, live.sent = nil, nil
    SendDuiMessage(live.dui, json.encode({ kind = live.kind, blank = true }))
    local pool = Screens.pool[live.kind]
    pool[#pool + 1] = live
end

function Screens.DestroyAll()
    for id in pairs(Screens.live) do Screens.Detach(id) end
    for kind, pool in pairs(Screens.pool) do
        for _, handle in ipairs(pool) do
            SetDuiUrl(handle.dui, 'about:blank')
            DestroyDui(handle.dui)
        end
        Screens.pool[kind] = {}
    end
end

function Screens.Build(places)
    for id in pairs(Screens.live) do Screens.Detach(id) end
    Screens.list = {}
    if (Config.Screens or {}).enabled == false then return end
    for _, place in ipairs(places or {}) do
        for _, p in ipairs(place.points.board or {}) do
            local tl, tr, bl, br, normal, center = corners({ x = p.x, y = p.y, z = p.z, h = p.w, width = p.width, height = p.width * 9 / 16 })
            Screens.list[#Screens.list + 1] = {
                id = ('b%s_%s'):format(place.id, p.id), kind = 'board', place = place.id, title = p.title ~= '' and p.title or place.name,
                rooms = p.rooms or {}, center = center, normal = normal, quad = { tl, tr, bl, br },
            }
        end
        for _, p in ipairs(place.points.sign or {}) do
            local tl, tr, bl, br, normal, center = corners({ x = p.x, y = p.y, z = p.z, h = p.w, width = p.width, height = p.width * 0.625 })
            Screens.list[#Screens.list + 1] = {
                id = ('s%s_%s'):format(place.id, p.id), kind = 'sign', place = place.id, room = p.room,
                center = center, normal = normal, quad = { tl, tr, bl, br },
            }
        end
        for _, bed in ipairs(place.points.bed or {}) do
            local m = bed.monitor
            if m then
                local width = m.width or 0.55
                local tl, tr, bl, br, normal, center = corners({ x = m.x, y = m.y, z = m.z, h = m.w, width = width, height = width * 0.625 })
                Screens.list[#Screens.list + 1] = {
                    id = ('m%s_%s'):format(place.id, bed.id), kind = 'monitor', place = place.id, bed = bed.id,
                    label = bed.room ~= '' and bed.room or bed.label, center = center, normal = normal, quad = { tl, tr, bl, br },
                }
            end
        end
    end
end

local function boardRows(screen)
    local rows = GlobalState['xsm:board:' .. tostring(screen.place)] or {}
    if not screen.rooms or #screen.rooms == 0 then return rows end
    local allowed = {}
    for _, r in ipairs(screen.rooms) do allowed[r:lower()] = true end
    local out = {}
    for _, row in ipairs(rows) do
        if allowed[(row.room or ''):lower()] then out[#out + 1] = row end
    end
    return out
end

local function payload(screen)
    local clock = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
    local labels = TextTable('screen_')
    if screen.kind == 'board' then
        return { kind = 'board', title = screen.title, rows = boardRows(screen), clock = clock, medics = GlobalState['xsm:medics'] or 0, labels = labels }
    elseif screen.kind == 'sign' then
        local found = nil
        for _, row in ipairs(GlobalState['xsm:board:' .. tostring(screen.place)] or {}) do
            if (row.room or ''):lower() == (screen.room or ''):lower() then found = row break end
        end
        return { kind = 'sign', room = screen.room, row = found, labels = labels }
    end
    local occupant = (Me.beds or {})[('%s:%s'):format(screen.place, screen.bed)]
    local vitals = occupant and Player(occupant).state.xsm or nil
    local name = nil
    if occupant then
        for _, row in ipairs(GlobalState['xsm:board:' .. tostring(screen.place)] or {}) do
            if row.src == occupant then name = row.name break end
        end
    end
    return { kind = 'monitor', label = screen.label, name = name, vitals = vitals, clock = clock, labels = labels }
end

local function send(live, force)
    if not live.screen then return end
    local encoded = json.encode(payload(live.screen))
    if not force and encoded == live.sent then return end
    live.sent = encoded
    SendDuiMessage(live.dui, encoded)
end

local function draw(live)
    local q = live.screen.quad
    local txd, txn = live.txd, live.txn
    local tl, tr, bl, br = q[1], q[2], q[3], q[4]
    DrawTexturedPoly(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, bl.x, bl.y, bl.z, 255, 255, 255, 255, txd, txn, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0)
    DrawTexturedPoly(tr.x, tr.y, tr.z, br.x, br.y, br.z, bl.x, bl.y, bl.z, 255, 255, 255, 255, txd, txn, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawTexturedPoly(tl.x, tl.y, tl.z, bl.x, bl.y, bl.z, tr.x, tr.y, tr.z, 255, 255, 255, 255, txd, txn, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0)
    DrawTexturedPoly(tr.x, tr.y, tr.z, bl.x, bl.y, bl.z, br.x, br.y, br.z, 255, 255, 255, 255, txd, txn, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)
end

local function drawLoop()
    Screens.drawing = true
    while next(Screens.live) do
        local cam = GetFinalRenderedCamCoord()
        local range = ((Config.Screens or {}).drawDistance or 16.0) + 4.0
        for _, live in pairs(Screens.live) do
            local s = live.screen
            if s then
                local toCam = cam - s.center
                if #toCam < range and (toCam.x * s.normal.x + toCam.y * s.normal.y) > -0.2 then draw(live) end
            end
        end
        Wait(0)
    end
    Screens.drawing = false
end

CreateThread(function()
    local tick = 0
    while true do
        Wait(500)
        tick = tick + 1
        local S = Config.Screens or {}
        if S.enabled ~= false and #Screens.list > 0 then
            local cam = GetFinalRenderedCamCoord()
            local range = S.drawDistance or 16.0
            local near = {}
            for _, screen in ipairs(Screens.list) do
                local d = #(cam - screen.center)
                if d < range then near[#near + 1] = { screen = screen, d = d } end
            end
            table.sort(near, function(a, b) return a.d < b.d end)
            local keep = {}
            for i = 1, math.min(#near, S.maxLive or 8) do keep[near[i].screen.id] = near[i].screen end
            for id, live in pairs(Screens.live) do
                if not keep[id] and (not live.screen or #(cam - live.screen.center) > range + 3.0) then Screens.Detach(id) end
            end
            for id, screen in pairs(keep) do
                if not Screens.live[id] then Screens.Attach(screen) end
            end
            local now = GetGameTimer()
            for _, live in pairs(Screens.live) do
                local fresh = now - (live.attachedAt or 0) < 3000
                if live.kind == 'monitor' or tick % 4 == 0 or fresh then send(live, fresh) end
            end
            if next(Screens.live) and not Screens.drawing then CreateThread(drawLoop) end
        elseif next(Screens.live) then
            for id in pairs(Screens.live) do Screens.Detach(id) end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    Screens.DestroyAll()
end)
