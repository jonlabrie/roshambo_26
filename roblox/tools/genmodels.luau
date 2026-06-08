--!strict
-- Generates roblox/assets/*.model.json from builder modules. Output is
-- committed; never hand-edit. Run from roblox/: lune run tools/genmodels
local fs = require("@lune/fs")
local JsonEmit = require("./builders/JsonEmit")
local Graybox = require("./builders/Graybox")
local JumbotronFrame = require("./builders/JumbotronFrame")
local ArenaLayout = require("./builders/ArenaLayout")

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
    ["JumbotronFrame"] = JumbotronFrame.build(ArenaLayout),
}

if not fs.isDir("assets") then
    fs.writeDir("assets")
end
for name, spec in OUTPUTS do
    local rojo = toRojo(spec)
    fs.writeFile(`assets/{name}.model.json`, JsonEmit.encode(rojo) .. "\n")
    print(`wrote assets/{name}.model.json`)
end
