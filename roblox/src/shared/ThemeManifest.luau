--!strict
-- Validates ArenaTheme data modules at boot: a missing key is a loud failure,
-- never a silent gray prop (spec §8).
local ThemeManifest = {}

ThemeManifest.REQUIRED_SOUNDS = { "clack", "gong", "drumroll", "latch", "splash", "bank", "waterAmbience" }
ThemeManifest.REQUIRED_MODELS = { "boulder", "paperSheet", "shears", "umbrella" }
ThemeManifest.REQUIRED_PALETTE = { "moss", "ivory", "vermilion", "ink", "gold", "water", "gravel", "timber" }
ThemeManifest.REQUIRED_LIGHTING = { "clockTime", "brightness", "ambient", "outdoorAmbient" }

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
    local palette = if type(theme.palette) == "table" then theme.palette else {}
    for _, key in ThemeManifest.REQUIRED_PALETTE do
        local c = palette[key]
        if type(c) ~= "table" or #c ~= 3 then
            table.insert(errs, `missing palette.{key}`)
        end
    end
    local lighting = if type(theme.lighting) == "table" then theme.lighting else {}
    for _, key in ThemeManifest.REQUIRED_LIGHTING do
        if lighting[key] == nil then
            table.insert(errs, `missing lighting.{key}`)
        end
    end
    return #errs == 0, errs
end

return ThemeManifest
