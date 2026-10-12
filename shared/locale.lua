local function replaceTokens(value, replacements)
    if not replacements then return value end
    for key, replacement in pairs(replacements) do
        value = value:gsub('%%{' .. key .. '}', (tostring(replacement):gsub('%%', '%%%%')))
    end
    return value
end

function Text(key, replacements)
    local selected = Locales[Config.Locale] or Locales.en or {}
    return replaceTokens(selected[key] or (Locales.en and Locales.en[key]) or ('<' .. key .. '>'), replacements)
end

function TextTable(prefix)
    local selected = Locales[Config.Locale] or Locales.en or {}
    local out = {}
    for key, value in pairs(Locales.en or {}) do
        if not prefix or key:sub(1, #prefix) == prefix then
            out[key] = selected[key] or value
        end
    end
    return out
end
