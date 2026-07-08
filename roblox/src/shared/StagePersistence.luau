--!strict
-- Pure helper for arena streaming persistence.
-- Given a list of root instances, returns every DIRECT-child Model across them.
-- main.server.luau marks each returned Model ModelStreamingMode = Persistent so the
-- arena is always replicated to spawn-watchers (~200 studs away). Kept pure so it is
-- Lune-testable; the workspace/WaitForChild resolution lives in main.server.luau.
local StagePersistence = {}

function StagePersistence.persistTargets(roots: { Instance }): { Instance }
    local out = {}
    for _, root in roots do
        for _, child in root:GetChildren() do
            if child:IsA("Model") then
                table.insert(out, child)
            end
        end
    end
    return out
end

return StagePersistence
