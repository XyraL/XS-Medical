Standdown = { paused = {} }

function Standdown.Active(src)
    src = tonumber(src)
    if not src then return false end
    if Standdown.paused[src] then return true end
    if (Config.Standdown or {}).arena ~= false and GetResourceState('XS-Arena') == 'started' then
        local ok, inMatch = pcall(function() return exports['XS-Arena']:IsInMatch(src) end)
        if ok and inMatch then return true end
    end
    return false
end

function Standdown.Set(src, paused)
    src = tonumber(src)
    if not src then return end
    Standdown.paused[src] = paused == true or nil
    Player(src).state:set('xsmPaused', paused == true, true)
end

exports('SetPaused', function(src, paused)
    Standdown.Set(src, paused)
end)

Framework.OnUnloaded(function(src)
    if Standdown.paused[src] then Standdown.Set(src, false) end
end)
