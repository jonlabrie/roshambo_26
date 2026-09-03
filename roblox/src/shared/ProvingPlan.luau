--!strict
-- HOW A FAMILY OF DRAFTS BECOMES A FIRING PLAN. Pure: the panel controller executes these
-- plans (one RequestProvingFire per entry); the server never learns about modes. Ladder
-- fires across all five stations at once; sequence is for shells whose read needs clean air.
--
-- The five stations were SCATTERED and renamed 2026-09-06 (owner placement, superseding
-- the bridge line): each station's tube orientation is its LAUNCH HEADING, and the future
-- plan is public access with jukebox-style play queueing (see backlog). Order below keeps
-- the A..E lineage.
local ProvingPlan = {}

ProvingPlan.RACKS = { "north arena", "bridge", "upper north", "mid pool", "hi west" }
-- "mid pool": the central, lowest, near-vertical station -- the most neutral tube for
-- clean-air repeats, visible from the arena basin.
ProvingPlan.SEQUENCE_RACK = "mid pool"
ProvingPlan.SEQUENCE_GAP = 2 -- seconds between sequence launches

local function draftId(family: string, variant: string): string
    return "draft:" .. family .. "/" .. variant
end

function ProvingPlan.ladder(family: string, variants: { string }): { { id: string, rack: string } }
    local plan = {}
    for i = 1, math.min(#variants, #ProvingPlan.RACKS) do
        table.insert(plan, { id = draftId(family, variants[i]), rack = ProvingPlan.RACKS[i] })
    end
    return plan
end

function ProvingPlan.sequence(family: string, variants: { string }): { { id: string, delaySeconds: number } }
    local plan = {}
    for i, variant in variants do
        table.insert(
            plan,
            { id = draftId(family, variant), delaySeconds = (i - 1) * ProvingPlan.SEQUENCE_GAP }
        )
    end
    return plan
end

-- A SHIPPED shell has one recipe, but the modes still earn their keep (owner,
-- 2026-09-06): sequence gives it clean-air repeats. (The one-day shippedLadder was
-- superseded the same day by the panel's MULTI-SELECT rack row -- "choose any or all
-- of the racks to launch a selection, simultaneously" -- select-all IS the volley.)
ProvingPlan.SHIPPED_SEQUENCE_COUNT = 3

function ProvingPlan.shippedSequence(id: string): { { id: string, delaySeconds: number } }
    local plan = {}
    for i = 1, ProvingPlan.SHIPPED_SEQUENCE_COUNT do
        table.insert(plan, { id = id, delaySeconds = (i - 1) * ProvingPlan.SEQUENCE_GAP })
    end
    return plan
end

return ProvingPlan
