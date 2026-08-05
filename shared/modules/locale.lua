TSS = TSS or {}
TSS.Locale = TSS.Locale or {}
TSS.Locales = TSS.Locales or {}

local language = tostring(TSS.Config.Locale or 'en'):lower()
if not language:match('^[%w_-]+$') then language = 'en' end

if language ~= 'en' and not TSS.Locales[language] then
    local path = ('shared/locales/%s.lua'):format(language)
    local contents = LoadResourceFile(GetCurrentResourceName(), path)
    if contents then
        local chunk, loadError = load(contents, ('@@%s/%s'):format(GetCurrentResourceName(), path))
        if chunk then
            local ok, runtimeError = pcall(chunk)
            if not ok then TSS.Warn(('Unable to load locale %s: %s'):format(language, runtimeError)) end
        else
            TSS.Warn(('Unable to compile locale %s: %s'):format(language, loadError))
        end
    else
        TSS.Warn(('Locale %s was not found; using English fallback'):format(language))
    end
end

function TSS.Locale.Language()
    return language
end

function TSS.Locale.Translate(key, ...)
    local selected = TSS.Locales[language] or TSS.Locales.en or {}
    local fallback = TSS.Locales.en or {}
    local value = selected[key] or fallback[key] or key

    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end

    return value
end

function TSS.Locale.Exists(key)
    local selected = TSS.Locales[language] or {}
    return selected[key] ~= nil or (TSS.Locales.en and TSS.Locales.en[key] ~= nil) or false
end

TSS.Locale.T = TSS.Locale.Translate
