Tablet = { open = false, patient = nil, prop = nil }

function Tablet.PageOn(page)
    return (((Config.Tablet or {}).pages or {})[page]) ~= false
end

local function holdProp()
    if not (Config.Tablet or {}).prop then return end
    local ped = PlayerPedId()
    local model = `prop_cs_tablet`
    if not Util.LoadModel(model, 3000) then return end
    Tablet.prop = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(Tablet.prop, ped, GetPedBoneIndex(ped, 28422), 0.0, -0.03, 0.0, 20.0, -90.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
    if Util.LoadAnim('amb@code_human_in_bus_passenger_idles@female@tablet@base', 3000) then
        TaskPlayAnim(ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 3.0, 3.0, -1, 49, 0.0, false, false, false)
    end
end

local function dropProp()
    if Tablet.prop and DoesEntityExist(Tablet.prop) then DeleteEntity(Tablet.prop) end
    Tablet.prop = nil
    StopAnimTask(PlayerPedId(), 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
end

function Tablet.Open(page, patient)
    if Down.active then return end
    if not Me.IsMedic() then
        Framework.Notify(Text('err_medics_only'), 'error')
        return
    end
    local item = (Config.Tablet or {}).item
    if item and (Config.Tablet or {}).needItem and Inventory.Count(item) < 1 then
        Framework.Notify(Text('err_no_item', { item = Inventory.Label(item) }), 'error')
        return
    end
    local ok, data = lib.callback.await('XS-Medical:server:tablet', false)
    if not ok then
        Framework.Notify(data or Text('err_failed'), 'error')
        return
    end
    if page and not Tablet.PageOn(page) then page = 'patient' end
    Tablet.open = true
    Tablet.patient = patient
    data.page = page or 'patient'
    data.patient = patient
    UI.Send('tablet', 'open', data)
    UI.Focus('tablet', true)
    holdProp()
end

function Tablet.Close()
    if not Tablet.open then return end
    Tablet.open = false
    Tablet.patient = nil
    UI.Send('tablet', 'close', {})
    UI.Focus('tablet', false)
    dropProp()
end

function Tablet.RefreshPatient()
    if Tablet.open and Tablet.patient then UI.Send('tablet', 'refreshPatient', { src = Tablet.patient }) end
end

function Tablet.Bill(target)
    local input = lib.inputDialog(Text('bill_title'), {
        { type = 'number', label = Text('bill_amount'), required = true, min = 1, max = 50000 },
        { type = 'input', label = Text('bill_reason'), required = false, max = 80 },
    })
    if not input then return end
    local ok, err = lib.callback.await('XS-Medical:server:bill', false, target, input[1], input[2])
    Framework.Notify(ok and Text('bill_sent') or (err or Text('err_failed')), ok and 'success' or 'error')
end

UI.OnClose('tablet', Tablet.Close)
Framework.OnUnloaded(Tablet.Close)

local RELAY = {
    patient = 'patient', nearby = 'nearby', recordsSearch = 'recordsSearch', recordsOpen = 'recordsOpen',
    recordsSave = 'recordsSave', rxCreate = 'rxCreate', rxVoid = 'rxVoid', reportsList = 'reportsList',
    reportsGet = 'reportsGet', reportsSave = 'reportsSave', reportsDelete = 'reportsDelete', calls = 'calls',
    callLeave = 'callLeave', callClose = 'callClose', shift = 'shift', roster = 'roster', callsign = 'callsign', hire = 'hire',
    setGrade = 'setGrade', fire = 'fire', hospital = 'hospital', discharge = 'discharge',
}

for nuiName, serverName in pairs(RELAY) do
    UI.Handle('tablet:' .. nuiName, function(payload)
        payload = type(payload) == 'table' and payload or {}
        local args = payload.args or {}
        local result = table.pack(lib.callback.await('XS-Medical:server:' .. serverName, false, table.unpack(args, 1, 4)))
        return result[1], result[2]
    end)
end

UI.Handle('tablet:callTake', function(payload)
    local ok, call = lib.callback.await('XS-Medical:server:callTake', false, payload and payload.id)
    if ok and call and call.coords then
        SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0)
        Calls.Assigned(call)
    end
    return ok, call
end)

UI.Handle('tablet:street', function()
    return true, Calls.Street()
end)

UI.Handle('tablet:waypoint', function(payload)
    if payload and payload.x then SetNewWaypoint(payload.x + 0.0, payload.y + 0.0) end
    return true
end)

UI.Handle('tablet:treat', function(payload)
    if not payload then return false end
    Tablet.Close()
    CreateThread(function()
        Treat.Run(tonumber(payload.target), payload.supply, tonumber(payload.injury))
        if Tablet.patient == nil then Tablet.Open('patient', tonumber(payload.target)) end
    end)
    return true
end)

UI.Handle('tablet:action', function(payload)
    if not payload then return false end
    local target = tonumber(payload.target)
    local action = payload.action
    Tablet.Close()
    CreateThread(function()
        if action == 'bed' then
            Hospital.PutInBed(target)
        elseif action == 'stretcher' then
            Equip.PlaceOn(target)
        elseif action == 'surgery' then
            Surgery.Begin(target)
        elseif action == 'vehicle' then
            Equip.LoadInto(target)
        elseif action == 'bill' then
            Tablet.Bill(target)
        elseif action == 'checkid' then
            Treat.Run(target, 'checkid')
        elseif action == 'cpr' then
            Treat.Run(target, 'cpr')
        end
    end)
    return true
end)

UI.Handle('tablet:close', function()
    Tablet.Close()
    return true
end)

RegisterNetEvent('XS-Medical:client:openTablet', function()
    Tablet.Open('patient')
end)

local C = Config.Commands or {}
if C.tablet and C.tablet ~= '' then
    RegisterCommand(C.tablet, function()
        if Tablet.open then Tablet.Close() else Tablet.Open('patient') end
    end, false)
    if C.tabletKey and C.tabletKey ~= '' then
        RegisterKeyMapping(C.tablet, Text('keybind_tablet'), 'keyboard', C.tabletKey)
    end
end

RegisterNetEvent('XS-Medical:client:bill', function(bill)
    if type(bill) ~= 'table' then return end
    local answer = lib.alertDialog({
        header = Text('bill_incoming_title'),
        content = Text('bill_incoming_text', { from = bill.from or '', amount = bill.amount or 0, reason = bill.reason ~= '' and bill.reason or Text('bill_no_reason') }),
        centered = true, cancel = true, labels = { confirm = Text('bill_pay'), cancel = Text('bill_decline') },
    })
    local ok, err = lib.callback.await('XS-Medical:server:billAnswer', false, bill.id, answer == 'confirm')
    if answer == 'confirm' then
        Framework.Notify(ok and Text('bill_you_paid', { amount = bill.amount }) or (err or Text('err_failed')), ok and 'success' or 'error')
    end
end)
