Fuel = { name = nil }

if IsDuplicityVersion() or not Config then return end

local SUPPORTED = { 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lc_fuel', 'Renewed-Fuel' }

do
    local forced = Config.Bridges and Config.Bridges.fuel or 'auto'
    if forced == 'none' then
        Fuel.name = nil
    elseif forced ~= 'auto' then
        Fuel.name = forced
    else
        for _, name in ipairs(SUPPORTED) do
            if GetResourceState(name) == 'started' then Fuel.name = name break end
        end
    end
end

function Fuel.Set(vehicle, amount)
    amount = (tonumber(amount) or 100.0) + 0.0
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    SetVehicleFuelLevel(vehicle, amount)
    pcall(function()
        if Fuel.name == 'ox_fuel' or Fuel.name == 'Renewed-Fuel' then
            Entity(vehicle).state:set('fuel', amount, true)
        elseif Fuel.name then
            exports[Fuel.name]:SetFuel(vehicle, amount)
        end
    end)
end
