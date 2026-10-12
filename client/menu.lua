Menu = { open = false, handler = nil }

function Menu.Open(spec, handler)
    Menu.open = true
    Menu.handler = handler
    UI.Send('menu', 'open', spec)
    UI.Focus('menu', true)
end

function Menu.Close()
    if not Menu.open then return end
    Menu.open = false
    Menu.handler = nil
    UI.Send('menu', 'close', {})
    UI.Focus('menu', false)
end

UI.OnClose('menu', Menu.Close)

UI.Handle('menu:pick', function(payload)
    if not Menu.handler or type(payload) ~= 'table' then return false end
    local handler = Menu.handler
    local ok, result = pcall(handler, payload.id, tonumber(payload.qty))
    if ok and result ~= false then
        if not payload.keep then Menu.Close() end
        return true
    end
    return false
end)
