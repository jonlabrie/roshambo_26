--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")
local harness = require("./harness")

for _, name in fs.readDir("tests") do
    local moduleName = name:match("^(.*%.spec)%.luau$")
    if moduleName then
        require("./" .. moduleName)
    end
end

if harness.count() == 0 then
    print("No tests found")
    process.exit(1)
end

process.exit(harness.run() and 0 or 1)
