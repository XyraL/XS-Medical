local function noop() end

local OPTIONAL = {
    Effects = { file = 'client/effects.lua', stub = { Refresh = noop, limp = false, shaky = 0, concussion = 0, pain = 0, blood = 100, bleeding = 0 } },
    Menu = { file = 'client/menu.lua', stub = { Open = noop, Close = noop, open = false } },
    Props = { file = 'client/props.lua', stub = { Set = noop, Clear = noop, Entity = noop } },
    Bed = { file = 'client/bed.lua', stub = { Start = noop, Stop = noop, Leave = noop, active = false, safe = false } },
    Pharmacy = { file = 'client/pharmacy.lua', stub = { Open = noop, Close = noop, open = false } },
    Surgery = { file = 'client/surgery.lua', stub = { Begin = noop, active = false, onTable = false } },
    Equip = { file = 'client/equipment.lua', stub = {
        Hold = noop, Drop = noop, Store = noop, PlaceOn = noop, LoadInto = noop, Unload = noop, Carry = noop,
        PutDown = noop, Release = noop, RegisterTargets = noop, onIt = false, carrying = false,
    } },
    Calls = { file = 'client/calls.lua', stub = { Assigned = noop, list = {}, blips = {} } },
    Screens = { file = 'client/screens.lua', stub = { Build = noop, DestroyAll = noop, list = {}, live = {} } },
    Placement = { file = 'client/placement.lua', stub = { Start = function() return nil end, Abort = noop, active = false } },
    Builder = { file = 'client/builder.lua', stub = { Open = noop, Close = noop, open = false } },
}

for name, entry in pairs(OPTIONAL) do
    if _G[name] == nil then
        _G[name] = entry.stub
        print(('^1[XS-Medical]^0 %s is missing, so that feature is switched off. Re-upload the resource.'):format(entry.file))
    end
end
