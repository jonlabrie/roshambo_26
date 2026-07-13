--!strict
-- Thin orchestrator: asks the pure planner what to do, then drives an injected
-- `ops` adapter to do it against real Instances. The adapter is faked in tests
-- (Lune) and implemented for real in the Studio demo / runtime. Requiring the
-- planner is fine — it is pure and Lune-loadable.
local StructurePlanner = require("./StructurePlanner")

local StructureBuilder = {}

export type Ops = {
    clonePrefab: (string) -> any,
    readManifest: (any) -> StructurePlanner.Manifest,
    applyBays: (any, any) -> (),
    recolor: (any, string, { number }) -> (),
    setTexture: (any, string, string) -> (),
    attachPrefab: (any, string, string) -> (),
    pivotTo: (any, { number }) -> (),
}

function StructureBuilder.build(
    loadout: StructurePlanner.Loadout,
    mount: StructurePlanner.Mount,
    catalog: any,
    ops: Ops
): any
    local model = ops.clonePrefab(loadout.baseStyle)
    local manifest = ops.readManifest(model)
    local plan = StructurePlanner.plan(loadout, mount, manifest, catalog)
    ops.applyBays(model, plan.bays)
    for _, r in plan.recolors do
        ops.recolor(model, r.role, r.color)
    end
    for _, t in plan.textures do
        ops.setTexture(model, t.target, t.assetId)
    end
    for _, a in plan.attachments do
        ops.attachPrefab(model, a.mount, a.prefabId)
    end
    ops.pivotTo(model, plan.pivotCF)
    return model
end

return StructureBuilder
