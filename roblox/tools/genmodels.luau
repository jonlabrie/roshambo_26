--!strict
-- Generates roblox/assets/*.model.json from builder modules. Output is
-- committed; never hand-edit. Run from roblox/: lune run tools/genmodels
local fs = require("@lune/fs")
local JsonEmit = require("./builders/JsonEmit")
local Graybox = require("./builders/Graybox")
local Bonsho = require("./builders/Bonsho")
local Shoro = require("./builders/Shoro")
local Waterwheel = require("./builders/Waterwheel")
local ThrowDrum = require("./builders/ThrowDrum")
local Sozu = require("./builders/Sozu")
local Creek = require("./builders/Creek")
local TerraceDressing = require("./builders/TerraceDressing")
local Teahouse = require("./builders/Teahouse")
local ArenaLayout = require("./builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")

local function toRojo(spec): any
    local node: any = { className = spec.className, properties = spec.properties }
    if spec.children then
        node.children = {}
        for _, child in spec.children do
            local c = toRojo(child)
            c.name = child.name
            table.insert(node.children, c)
        end
    end
    return node
end

local OUTPUTS: { [string]: any } = {
    ["Graybox"] = Graybox.build(ArenaLayout),
    ["BonshoRig"] = Bonsho.build(ZenDojo.palette, ArenaLayout),
    ["Shoro"] = Shoro.build(ZenDojo.palette, ArenaLayout),
    ["Waterwheel"] = Waterwheel.build(ZenDojo.palette, ArenaLayout),
    ["ThrowDrum"] = ThrowDrum.build(ZenDojo.palette, ArenaLayout),
    ["Sozu"] = Sozu.build(ZenDojo.palette, ArenaLayout),
    ["Creek"] = Creek.build(ZenDojo.palette, ArenaLayout),
    ["TerraceDressing"] = TerraceDressing.build(ZenDojo.palette, ArenaLayout),
    ["Teahouses"] = Teahouse.build(ZenDojo.palette, ArenaLayout),
}

if not fs.isDir("assets") then
    fs.writeDir("assets")
end
for name, spec in OUTPUTS do
    local rojo = toRojo(spec)
    fs.writeFile(`assets/{name}.model.json`, JsonEmit.encode(rojo) .. "\n")
    print(`wrote assets/{name}.model.json`)
end
