Damage = { lastHealth = 200, lastArmour = 0 }

local function partOf(ped)
    local found, bone = GetPedLastDamageBone(ped)
    ClearPedLastDamageBone(ped)
    if (found == true or found == 1) and bone then
        local part = Body.Bones[bone]
        if part then return part end
        local index = GetPedBoneIndex(ped, bone)
        if index and index ~= -1 then
            local world = GetWorldPositionOfEntityBone(ped, index)
            local offset = GetOffsetFromEntityGivenWorldCoords(ped, world.x, world.y, world.z)
            return Body.PartFromOffset(offset)
        end
    end
    return 'torso'
end

function Damage.Reset()
    local ped = PlayerPedId()
    Damage.lastHealth = GetEntityHealth(ped)
    Damage.lastArmour = GetPedArmour(ped)
end

local function report(ped, weapon, fatal, headshot)
    local health = GetEntityHealth(ped)
    local armour = GetPedArmour(ped)
    local lost = math.max(0, Damage.lastHealth - health)
    local armourHit = armour < Damage.lastArmour
    Damage.lastHealth, Damage.lastArmour = health, armour
    if fatal and lost < 1 then lost = 50 end

    local group = GetWeapontypeGroup(weapon)
    local cause = Body.Cause(weapon, group)
    if cause == 'ignore' then return cause end

    local part = partOf(ped)
    if headshot then part = 'head' end
    TriggerServerEvent('XS-Medical:server:hit', {
        part = part, cause = cause, amount = lost, armour = armourHit, fatal = fatal == true, weapon = Util.U32(weapon),
    })
    return cause
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if not Me.loaded or not (Config.Damage or {}).enabled then return end
    local ped = PlayerPedId()
    if args[1] ~= ped then return end
    if Me.Paused() then
        Damage.Reset()
        return
    end
    if Bed and Bed.active and Bed.safe then
        Damage.Reset()
        return
    end

    local died = args[6] == 1 or IsEntityDead(ped) or IsPedFatallyInjured(ped)
    local cause = report(ped, args[7] or 0, died, args[11] == 1 and (args[12] or 0) ~= 1)

    if died then
        Down.Fatal(cause)
    elseif Down.active then
        Down.TopUp()
    end
end)

CreateThread(function()
    while true do
        Wait(400)
        if Me.loaded then
            local ped = PlayerPedId()
            local health = GetEntityHealth(ped)
            if health > Damage.lastHealth then Damage.lastHealth = health end
            local armour = GetPedArmour(ped)
            if armour > Damage.lastArmour then Damage.lastArmour = armour end
            if not Down.active and not Me.Paused() and (IsEntityDead(ped) or health <= 0) and not Down.pending then
                Down.Fatal('unknown')
            end
        end
    end
end)
