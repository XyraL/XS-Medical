Util = {}

function Util.Clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

function Util.Round(value, places)
    local mult = 10 ^ (places or 0)
    return math.floor((tonumber(value) or 0) * mult + 0.5) / mult
end

function Util.Truthy(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

function Util.U32(hash)
    hash = tonumber(hash) or 0
    if hash < 0 then hash = hash + 4294967296 end
    return math.floor(hash)
end

function Util.Hash(name)
    return Util.U32(joaat(name))
end

function Util.Now()
    if IsDuplicityVersion() then return os.time() end
    return math.floor(GetCloudTimeAsInt())
end

function Util.Copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Util.Copy(v) end
    return out
end

function Util.Text(value, max)
    if value == nil then return '' end
    value = tostring(value):gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if max and #value > max then value = value:sub(1, max) end
    return value
end

function Util.Lines(value, max)
    if value == nil then return '' end
    value = tostring(value):gsub('\r', ''):gsub('[\0-\9\11-\31\127]', ' ')
    if max and #value > max then value = value:sub(1, max) end
    return value
end

function Util.Id(prefix)
    local stamp
    if IsDuplicityVersion() then stamp = os.time() else stamp = math.floor(GetGameTimer() / 1000) end
    return ('%s%x%04x'):format(prefix or '', stamp, math.random(0, 65535))
end

function Util.Vec(value)
    if type(value) == 'vector3' or type(value) == 'vector4' then return vector3(value.x, value.y, value.z) end
    if type(value) == 'table' and value.x then return vector3(tonumber(value.x) or 0.0, tonumber(value.y) or 0.0, tonumber(value.z) or 0.0) end
    return nil
end

function Util.Point(value)
    if not value then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z then return nil end
    return { x = Util.Round(x, 3), y = Util.Round(y, 3), z = Util.Round(z, 3), w = Util.Round(tonumber(value.w or value.h) or 0.0, 2) }
end

function Util.Distance(a, b)
    if not a or not b then return math.huge end
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Util.Clock(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return ('%d:%02d'):format(seconds // 60, seconds % 60)
end

function Util.Escape(value)
    return (tostring(value):gsub('%%', '%%%%'))
end

function Util.IsMedicJob(job)
    if not job or not job.name then return false end
    local J = Config.Jobs or {}
    for _, name in ipairs(J.names or {}) do
        if name == job.name then return true end
    end
    for _, kind in ipairs(J.types or {}) do
        if kind == job.type then return true end
    end
    return false
end
