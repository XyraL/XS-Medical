Vitals = {}

local function wobble(t, seed, amp)
    return math.sin(t * 0.37 + seed) * amp + math.sin(t * 0.11 + seed * 1.7) * amp * 0.5
end

local function hasLungWound(injuries)
    for _, injury in ipairs(injuries or {}) do
        if injury.part == 'torso' and (injury.kind == 'gunshot' or injury.kind == 'stab') then return true end
    end
    return false
end

local function infected(injuries)
    for _, injury in ipairs(injuries or {}) do
        if injury.infected then return true end
    end
    return false
end

local function burns(injuries)
    local total = 0
    for _, injury in ipairs(injuries or {}) do
        if injury.kind == 'burn' then total = total + (injury.sev or 1) end
    end
    return total
end

function Vitals.Compute(state, now, seed)
    state = state or {}
    now = tonumber(now) or 0
    seed = tonumber(seed) or 1
    local status = state.status or 'alive'
    local blood = Util.Clamp(state.blood or 100, 0, 100)
    local deficit = 100 - blood
    local pain = Body.Pain(state.injuries, state.relief)
    local opioid = Util.Clamp(state.opioid or 0, 0, 12)

    if status == 'arrest' or status == 'dead' then
        return {
            hr = 0, sys = 0, dia = 0, spo2 = 0, resp = 0,
            temp = Util.Round(36.4 - deficit * 0.02, 1),
            rhythm = (status == 'arrest' and state.rhythm == 'vf') and 'vf' or 'asystole',
            avpu = 'U', pain = pain, blood = Util.Round(blood, 0), status = status,
            alarms = { 'arrest' }, acuity = 1,
        }
    end

    local hr = 72 + pain * 2.5 + deficit * 1.1 - opioid * 1.5
    if status ~= 'alive' and blood < 45 then hr = 130 - (45 - blood) * 3 end
    hr = Util.Clamp(hr + wobble(now, seed, 2), 30, 185)

    local sys = Util.Clamp(122 - deficit * 1.25 + pain * 1.5 - opioid * 2 + wobble(now, seed + 3, 2), 50, 190)
    local dia = Util.Clamp(78 - deficit * 0.75 + pain * 0.8 - opioid * 1.2 + wobble(now, seed + 5, 1.5), 25, 120)

    local spo2 = 98 - (hasLungWound(state.injuries) and 4 or 0) - math.max(0, deficit - 25) * 0.25 - opioid * 1.5
    if status ~= 'alive' then spo2 = spo2 - 2 end
    spo2 = Util.Clamp(spo2 + wobble(now, seed + 7, 0.6), 62, 100)

    local resp = 14 + deficit * 0.18 + pain * 0.6 - opioid * 2.2
    if status ~= 'alive' then resp = resp + 2 end
    if opioid >= 8 then resp = math.min(resp, 6) end
    resp = Util.Clamp(resp + wobble(now, seed + 11, 0.8), 4, 40)

    local temp = 36.8 - deficit * 0.02 + (infected(state.injuries) and 1.6 or 0) + burns(state.injuries) * 0.1

    local rhythm = 'sinus'
    if hr > 100 then rhythm = 'tachy' elseif hr < 55 then rhythm = 'brady' end

    local avpu = 'A'
    if status == 'knockout' then
        avpu = 'U'
    elseif status == 'down' then
        avpu = blood >= 50 and 'P' or 'U'
    elseif blood < 70 or opioid >= 6 then
        avpu = 'V'
    end

    local out = {
        hr = math.floor(hr + 0.5), sys = math.floor(sys + 0.5), dia = math.floor(dia + 0.5),
        spo2 = math.floor(spo2 + 0.5), resp = math.floor(resp + 0.5), temp = Util.Round(temp, 1),
        rhythm = rhythm, avpu = avpu, pain = pain, blood = Util.Round(blood, 0), status = status,
        alarms = {},
    }

    if out.spo2 < 92 then out.alarms[#out.alarms + 1] = 'spo2' end
    if out.hr > 120 then out.alarms[#out.alarms + 1] = 'hr_high' end
    if out.hr < 50 then out.alarms[#out.alarms + 1] = 'hr_low' end
    if out.sys < 90 then out.alarms[#out.alarms + 1] = 'bp' end
    if out.resp < 8 then out.alarms[#out.alarms + 1] = 'resp' end

    local acuity = 5
    if status ~= 'alive' then
        acuity = 1
    elseif blood < 70 or out.sys < 90 or out.spo2 < 90 then
        acuity = 2
    elseif Body.WorstBleed(state.injuries) > 0 then
        acuity = 3
    else
        for _, injury in ipairs(state.injuries or {}) do
            if injury.fracture or Body.NeedsSurgery(injury) then acuity = 3 break end
        end
        if acuity == 5 and pain >= 4 then acuity = 4 end
    end
    out.acuity = acuity

    return out
end
