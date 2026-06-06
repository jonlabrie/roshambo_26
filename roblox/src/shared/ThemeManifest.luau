--!strict
-- Validates ArenaTheme data modules at boot: a missing key is a loud failure,
-- never a silent gray prop (spec §8).
local ThemeManifest = {}

ThemeManifest.REQUIRED_SOUNDS = { "clack", "gong", "drumroll", "latch", "splash", "bank" }
ThemeManifest.REQUIRED_MODELS = { "boulder", "paperSheet", "shears", "umbrella" }

function ThemeManifest.validate(theme: any): (boolean, { string })
    local errs: { string } = {}
    if type(theme) ~= "table" then
        return false, { "theme is not a table" }
    end
    if type(theme.name) ~= "string" then
        table.insert(errs, "missing name")
    end
    if type(theme.labels) ~= "table" or type(theme.labels.boardHeader) ~= "string" then
        table.insert(errs, "missing labels.boardHeader")
    end
    local sounds = if type(theme.sounds) == "table" then theme.sounds else {}
    for _, key in ThemeManifest.REQUIRED_SOUNDS do
        if type(sounds[key]) ~= "string" then
            table.insert(errs, `missing sound: {key}`)
        end
    end
    local models = if type(theme.models) == "table" then theme.models else {}
    for _, key in ThemeManifest.REQUIRED_MODELS do
        if type(models[key]) ~= "string" then
            table.insert(errs, `missing model: {key}`)
        end
    end
    return #errs == 0, errs
end

return ThemeManifest
