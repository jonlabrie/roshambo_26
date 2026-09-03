--!strict
-- THE PROVING RANGE'S WORKING FILE. Families of candidate recipes, same format as
-- FireworkCatalog.RECIPES (see its header), fired at the range as "draft:<family>/<variant>".
-- Claude authors here; the owner judges in Play; an approved variant MOVES to FireworkCatalog
-- (plus the shared fixture and server/src/fireworks.ts) and the rest of its family is pruned in
-- the same or a following commit — git history is the archive, this file stays short.
--
-- NEVER add a draft to shared-fixtures/firework-shells.json: the CI contract would then demand
-- the server price it. Every entry here is schema-checked by FireworkDrafts.spec against
-- FireworkRecipes, so a typo fails `lune run tests/run` rather than rendering a blank sky.
-- Pure data + string parsing, no Roblox globals; runs under Lune.
local FireworkDrafts = {}

-- THE WORKSHEET IS EMPTY (2026-09-06): every family judged at the range has shipped or
-- been reframed -- wa, yashi, kamuro, hotaru, janken (born "dan") to the catalog;
-- ao/midori/murasaki to collections (colorway ruling; archive at `2cd90b4`). The next
-- family starts here.
FireworkDrafts.FAMILIES = {} :: { [string]: { [string]: any } }

function FireworkDrafts.resolve(id: string): any?
    local family, variant = id:match("^draft:([%w_]+)/([%w_]+)$")
    if family == nil or variant == nil then
        return nil
    end
    local fam = FireworkDrafts.FAMILIES[family :: string]
    return fam and fam[variant :: string] or nil
end

function FireworkDrafts.variantsOf(family: string): { string }
    local out: { string } = {}
    local fam = FireworkDrafts.FAMILIES[family]
    if fam then
        for name in fam do
            table.insert(out, name)
        end
        table.sort(out)
    end
    return out
end

function FireworkDrafts.familyNames(): { string }
    local out: { string } = {}
    for name in FireworkDrafts.FAMILIES do
        table.insert(out, name)
    end
    table.sort(out)
    return out
end

return FireworkDrafts
