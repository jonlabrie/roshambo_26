--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Remotes = require("../src/server/Remotes")

-- The RemoteEvents contract is default.project.json's RoshamboRemotes block. Every name the server
-- binds must exist there, or the server would hang at boot on a WaitForChild that never resolves.
local project = serde.decode("json", fs.readFile("default.project.json"))
local function findRemotesBlock(node: any): any?
    if type(node) ~= "table" then
        return nil
    end
    if node.RoshamboRemotes ~= nil then
        return node.RoshamboRemotes
    end
    for _, child in node do
        local found = findRemotesBlock(child)
        if found then
            return found
        end
    end
    return nil
end
local contract = findRemotesBlock(project)

describe("Remotes -- the names are the contract", function()
    test("the project declares a RoshamboRemotes block", function()
        expect(contract).toBeTruthy()
    end)
    test("every bound name is declared in the contract as a RemoteEvent", function()
        for _, name in Remotes.NAMES do
            local decl = contract[name]
            expect(decl).toBeTruthy()
            expect(decl["$className"]).toBe("RemoteEvent")
        end
    end)
    test("no name is bound twice", function()
        local seen = {}
        for _, name in Remotes.NAMES do
            expect(seen[name]).toBeNil()
            seen[name] = true
        end
    end)
    test("bind returns one handle per name, from the folder given", function()
        local asked = {}
        local folder = {
            WaitForChild = function(_self, name: string)
                table.insert(asked, name)
                return { Name = name }
            end,
        }
        local R = Remotes.bind(folder :: any)
        expect(#asked).toBe(#Remotes.NAMES)
        for _, name in Remotes.NAMES do
            expect(R[name].Name).toBe(name)
        end
    end)
end)
