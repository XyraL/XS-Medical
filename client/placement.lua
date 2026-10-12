Placement = { active = false }

local cam, ghost, resolve
local opts
local preview

local KEYS = {
    confirm = 191, cancel = 194, forward = 32, back = 33, left = 34, right = 35, up = 22, down = 36,
    fast = 21, slow = 19, grow = 96, shrink = 97, snap = 23, drop = 73, flip = 47,
}

local function camForward()
    local rot = GetCamRot(cam, 2)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local cosX = math.abs(math.cos(x))
    return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

local function aim(distance)
    local from = GetCamCoord(cam)
    local to = from + camForward() * distance
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16 + 256, PlayerPedId(), 4)
    local _, hit, coords, normal, entity = GetShapeTestResult(ray)
    if hit == true or hit == 1 then return coords, normal, entity end
    return to, nil, 0
end

local function stopPreview()
    if preview and DoesEntityExist(preview) then
        if IsEntityAVehicle(preview) then DeleteVehicle(preview) else DeleteObject(preview) end
    end
    preview = nil
end

local function startPreview(model, vehicle)
    stopPreview()
    if not model or model == '' then return end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return end
    lib.requestModel(hash, 6000)
    if not HasModelLoaded(hash) then return end
    if vehicle then
        preview = CreateVehicle(hash, ghost.x, ghost.y, ghost.z, ghost.h, false, false)
        SetVehicleDoorsLocked(preview, 4)
    else
        preview = CreateObjectNoOffset(hash, ghost.x, ghost.y, ghost.z, false, false, false)
    end
    SetEntityAlpha(preview, 160, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    SetModelAsNoLongerNeeded(hash)
end

local function drawExisting()
    if (Config.Builder or {}).showExisting == false then return end
    for _, p in ipairs(opts.existing or {}) do
        DrawMarker(28, p.x, p.y, p.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, 120, 160, 140, 110, false, false, 2, false)
    end
end

local function drawQuad(center, heading, width, height)
    local h = math.rad(heading)
    local right = vector3(-math.cos(h), -math.sin(h), 0.0)
    local up = vector3(0.0, 0.0, 1.0)
    local hw, hh = width / 2, height / 2
    local tl, tr = center - right * hw + up * hh, center + right * hw + up * hh
    local bl, br = center - right * hw - up * hh, center + right * hw - up * hh
    for _, edge in ipairs({ { tl, tr }, { tr, br }, { br, bl }, { bl, tl } }) do
        DrawLine(edge[1].x, edge[1].y, edge[1].z, edge[2].x, edge[2].y, edge[2].z, 61, 255, 122, 255)
    end
    DrawPoly(tl.x, tl.y, tl.z, bl.x, bl.y, bl.z, tr.x, tr.y, tr.z, 61, 255, 122, 50)
    DrawPoly(tr.x, tr.y, tr.z, bl.x, bl.y, bl.z, br.x, br.y, br.z, 61, 255, 122, 50)
    DrawPoly(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, bl.x, bl.y, bl.z, 61, 255, 122, 50)
    DrawPoly(tr.x, tr.y, tr.z, br.x, br.y, br.z, bl.x, bl.y, bl.z, 61, 255, 122, 50)
end

local function hint()
    local lines = { ('**%s**'):format(opts.label or Text('builder_placing')) }
    if opts.mode == 'wall' then
        lines[#lines + 1] = Text('placement_wall_hint')
    else
        lines[#lines + 1] = Text('placement_point_hint')
    end
    lines[#lines + 1] = Text('placement_common_hint')
    lib.showTextUI(table.concat(lines, '\n'), { position = 'left-center' })
end

local function finish(result)
    if cam then
        RenderScriptCams(false, true, 300, true, true)
        SetCamActive(cam, false)
        DestroyCam(cam, true)
        cam = nil
    end
    stopPreview()
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
    lib.hideTextUI()
    Placement.active = false
    local done = resolve
    resolve = nil
    if done then done(result) end
end

function Placement.Start(options)
    if Placement.active then return nil end
    opts = options or {}
    opts.mode = opts.mode or 'point'
    local ped = PlayerPedId()
    local origin = opts.origin and vector3(opts.origin.x, opts.origin.y, opts.origin.z) or GetEntityCoords(ped)
    ghost = { x = origin.x, y = origin.y, z = origin.z, h = (opts.origin and (opts.origin.w or opts.origin.h)) or GetEntityHeading(ped), width = opts.width or 1.0, snapped = false }

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, origin.x, origin.y, origin.z + 1.8)
    SetCamRot(cam, -15.0, 0.0, GetEntityHeading(ped), 2)
    SetCamFov(cam, 60.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 300, true, true)
    FreezeEntityPosition(ped, true)
    Placement.active = true
    hint()

    if opts.previewModel then startPreview(opts.previewModel, opts.previewVehicle) end

    local promised = promise.new()
    resolve = function(value) promised:resolve(value) end

    CreateThread(function()
        local speeds = (Config.Builder or {}).cameraSpeed or { normal = 6.0, fast = 18.0, slow = 1.5 }
        while Placement.active do
            Wait(0)
            DisableAllControlActions(0)
            EnableControlAction(0, KEYS.confirm, true)
            EnableControlAction(0, KEYS.cancel, true)

            local pos = GetCamCoord(cam)
            local rot = GetCamRot(cam, 2)
            local dx = GetDisabledControlNormal(0, 1) * 6.0
            local dy = GetDisabledControlNormal(0, 2) * 6.0
            SetCamRot(cam, math.max(-89.0, math.min(89.0, rot.x - dy)), 0.0, rot.z - dx, 2)

            local speed = speeds.normal
            if IsDisabledControlPressed(0, KEYS.fast) then speed = speeds.fast end
            if IsDisabledControlPressed(0, KEYS.slow) then speed = speeds.slow end
            speed = speed * GetFrameTime()
            local fwd = camForward()
            local right = vector3(fwd.y, -fwd.x, 0.0)
            local move = vector3(0.0, 0.0, 0.0)
            if IsDisabledControlPressed(0, KEYS.forward) then move = move + fwd end
            if IsDisabledControlPressed(0, KEYS.back) then move = move - fwd end
            if IsDisabledControlPressed(0, KEYS.right) then move = move + right end
            if IsDisabledControlPressed(0, KEYS.left) then move = move - right end
            if IsDisabledControlPressed(0, KEYS.up) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, KEYS.down) then move = move - vector3(0.0, 0.0, 1.0) end
            if #move > 0.0 then
                pos = pos + move * speed
                SetCamCoord(cam, pos.x, pos.y, pos.z)
                ghost.snapped = false
            end
            SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)

            local hit, normal, entity = aim(30.0)
            if not ghost.snapped then
                ghost.x, ghost.y, ghost.z = hit.x, hit.y, hit.z
                if opts.mode == 'wall' and normal and math.abs(normal.z) < 0.7 then
                    ghost.h = math.deg(math.atan(-normal.x, normal.y)) % 360
                    ghost.z = hit.z
                end
            end

            if opts.mode == 'wall' then
                if IsDisabledControlPressed(0, KEYS.grow) then ghost.width = math.min(8.0, ghost.width + 0.02) end
                if IsDisabledControlPressed(0, KEYS.shrink) then ghost.width = math.max(0.2, ghost.width - 0.02) end
                local ratio = opts.ratio or 0.5625
                local h = math.rad(ghost.h)
                local center = vector3(ghost.x, ghost.y, ghost.z) + vector3(-math.sin(h), math.cos(h), 0.0) * 0.012
                drawQuad(center, ghost.h, ghost.width, ghost.width * ratio)
            else
                if IsDisabledControlPressed(0, KEYS.grow) then ghost.h = (ghost.h + 1.5) % 360 end
                if IsDisabledControlPressed(0, KEYS.shrink) then ghost.h = (ghost.h - 1.5) % 360 end
                if IsDisabledControlJustPressed(0, KEYS.flip) then ghost.h = (ghost.h + 180.0) % 360 end
                if IsDisabledControlJustPressed(0, KEYS.snap) and entity and entity ~= 0 and GetEntityType(entity) == 3 then
                    local c = GetEntityCoords(entity)
                    ghost.x, ghost.y, ghost.z, ghost.h = c.x, c.y, c.z, GetEntityHeading(entity)
                    ghost.snapped = true
                    ghost.model = GetEntityModel(entity)
                end
                if IsDisabledControlJustPressed(0, KEYS.drop) then
                    local ray = StartExpensiveSynchronousShapeTestLosProbe(ghost.x, ghost.y, ghost.z + 1.0, ghost.x, ghost.y, ghost.z - 6.0, 1 + 16, PlayerPedId(), 4)
                    local _, floorHit, floor = GetShapeTestResult(ray)
                    if floorHit == true or floorHit == 1 then ghost.z = floor.z ghost.snapped = true end
                end
                local r = math.rad(ghost.h)
                local tip = vector3(ghost.x - math.sin(r) * 0.8, ghost.y + math.cos(r) * 0.8, ghost.z + 0.05)
                DrawMarker(28, ghost.x, ghost.y, ghost.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 61, 255, 122, 160, false, false, 2, false)
                DrawLine(ghost.x, ghost.y, ghost.z + 0.05, tip.x, tip.y, tip.z, 61, 255, 122, 255)
                DrawLine(ghost.x, ghost.y, ghost.z, ghost.x, ghost.y, ghost.z + 1.6, 61, 255, 122, 200)
                if preview and DoesEntityExist(preview) then
                    SetEntityCoordsNoOffset(preview, ghost.x, ghost.y, ghost.z + (opts.previewVehicle and 0.3 or 0.0), false, false, false)
                    SetEntityHeading(preview, ghost.h)
                end
            end

            drawExisting()

            if IsDisabledControlJustPressed(0, KEYS.confirm) then
                finish({ x = ghost.x, y = ghost.y, z = ghost.z, w = ghost.h, width = ghost.width, snapped = ghost.snapped == true and ghost.model ~= nil })
                break
            end
            if IsDisabledControlJustPressed(0, KEYS.cancel) then
                finish(nil)
                break
            end
        end
    end)

    return Citizen.Await(promised)
end

function Placement.Abort()
    if Placement.active then finish(nil) end
end
