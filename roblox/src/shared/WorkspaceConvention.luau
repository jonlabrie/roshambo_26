--!strict
-- Pure invariants for the workspace Rojo/place-only convention
-- (spec 2026-07-08-roblox-workspace-organization). Backs the Studio pre-publish
-- verifier tools/studio/verifyWorkspaceConvention.luau.
local WorkspaceConvention = {}

-- The instances Rojo declares under Workspace.RoshamboStage in default.project.json.
-- RoshamboStage must contain EXACTLY these (no hand-built place-only content).
WorkspaceConvention.DECLARED_STAGE_CHILDREN = {
    "BonshoRig",
    "BonshoBell", -- the cast-bronze bell meshes (assets/meshes/BonshoBell.rbxm)
    "Shoro",
    "ShoroRoof", -- the slate eave-skirt roof mesh (assets/meshes/ShoroRoof.rbxm)
    "Waterwheel",
    "BellDrive",
    "ThrowDrum",
    "RanmaCarvings", -- the 8 pierced dragon-king ranma carvings (assets/meshes/RanmaCarvings.rbxm)
    "Overlook",
    "SwitchbackDeck",
    "FallsDock", -- the 6x8 posted timber dock on pool 2 (assets/FallsDock.model.json)
    "Karesansui",
    "Hanabiya", -- 花火屋, the firework shop machiya (assets/Hanabiya.model.json)
    "Torii", -- myōjin gate on the Overlook deck's west edge (assets/Torii.model.json)
    "ArenaSpawn",
}

export type Snapshot = {
    stageChildren: { string },
    hasCanyonWorld: boolean,
    hasArena: boolean,
    arenaCount: number,
}

function WorkspaceConvention.check(snapshot: Snapshot): (boolean, { string })
    local failures = {}
    local declared = {}
    for _, name in WorkspaceConvention.DECLARED_STAGE_CHILDREN do
        declared[name] = true
    end
    local seen = {}
    for _, name in snapshot.stageChildren do
        seen[name] = true
        if not declared[name] then
            table.insert(
                failures,
                `RoshamboStage has undeclared child '{name}' — place-only content belongs in CanyonWorld/Sandbox`
            )
        end
    end
    for _, name in WorkspaceConvention.DECLARED_STAGE_CHILDREN do
        if not seen[name] then
            table.insert(failures, `RoshamboStage is missing declared child '{name}'`)
        end
    end
    if not snapshot.hasCanyonWorld then
        table.insert(failures, "Workspace.CanyonWorld is missing")
    end
    if not snapshot.hasArena then
        table.insert(failures, "Workspace.CanyonWorld.Arena is missing")
    end
    if snapshot.hasArena and snapshot.arenaCount <= 0 then
        table.insert(failures, "CanyonWorld.Arena is empty — arena VFX/rocks not relocated?")
    end
    return #failures == 0, failures
end

return WorkspaceConvention
