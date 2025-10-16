KLocale = {}

local FALLBACK_LOCALE = 'en'
local payloadCache = {}

local function deepClone(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            copy[k] = deepClone(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function deepMerge(base, overlay)
    local result = deepClone(base)
    if type(overlay) ~= 'table' then return result end
    for k, v in pairs(overlay) do
        if type(v) == 'table' then
            result[k] = deepMerge(result[k] or {}, v)
        else
            result[k] = v
        end
    end
    return result
end

local function resolvePath(locale, path)
    local data = Config.Locales[locale]
    local fallback = Config.Locales[FALLBACK_LOCALE]
    if not data then data = fallback end
    local current = data
    local currentFallback = fallback
    for segment in string.gmatch(path, '([^.]+)') do
        if type(current) == 'table' then
            current = current[segment]
        else
            current = nil
        end
        if type(currentFallback) == 'table' then
            currentFallback = currentFallback[segment]
        else
            currentFallback = nil
        end
    end
    return current ~= nil and current or currentFallback
end

function KLocale.text(locale, path, replacements)
    local value = resolvePath(locale, path)
    if type(value) ~= 'string' then return nil end
    if replacements then
        for key, replacement in pairs(replacements) do
            value = value:gsub('{' .. key .. '}', tostring(replacement))
        end
    end
    return value
end

local function optionList(locale, optionConfig)
    local list = {}
    if type(optionConfig) ~= 'table' or type(optionConfig.order) ~= 'table' then
        return list
    end
    for _, key in ipairs(optionConfig.order) do
        local labels = optionConfig.labels[key] or {}
        local label = labels[locale] or labels[FALLBACK_LOCALE] or key
        list[#list + 1] = { value = key, label = label }
    end
    return list
end

local function presetButtons(locale)
    local buttons = {}
    for _, key in ipairs(Config.Presets.order) do
        local labels = Config.Presets.labels[key] or {}
        local label = labels[locale] or labels[FALLBACK_LOCALE] or key
        buttons[#buttons + 1] = {
            key = key,
            label = label,
            primary = Config.Presets.defaultPrimary == key
        }
    end
    return buttons
end

local function buildPayload(locale)
    local baseLocale = Config.Locales[locale]
    if not baseLocale then baseLocale = Config.Locales[FALLBACK_LOCALE] end
    local fallbackUI = (Config.Locales[FALLBACK_LOCALE] or {}).ui or {}
    local ui = deepMerge(fallbackUI, baseLocale and baseLocale.ui or {})
    ui.options = {
        valveMode = optionList(locale, Config.ValveModes),
        autoStrategy = optionList(locale, Config.AutoStrategies)
    }
    ui.presets = presetButtons(locale)
    ui.presetData = deepClone(Config.Presets.data)
    return ui
end

function KLocale.localePayload(locale)
    locale = locale or FALLBACK_LOCALE
    if not payloadCache[locale] then
        payloadCache[locale] = buildPayload(locale)
    end
    return deepClone(payloadCache[locale])
end

function KLocale.invalidateCache()
    payloadCache = {}
end

function KLocale.notify(locale, key, replacements)
    return KLocale.text(locale, 'notifications.' .. key, replacements)
end

function KLocale.commandDescription(locale)
    return KLocale.text(locale, 'command.description') or ''
end

return KLocale
