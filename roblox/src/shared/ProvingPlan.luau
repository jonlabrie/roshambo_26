--!strict
-- HOW A FAMILY OF DRAFTS BECOMES A FIRING PLAN. Pure: the panel controller executes these
-- plans (one RequestProvingFire per entry); the server never learns about modes. Ladder is
-- the range's whole reason to have five racks — variants burst side by side for comparison;
-- sequence is for shells whose read needs clean air.
local ProvingPlan = {}

ProvingPlan.RACKS = { "Rack_A", "Rack_B", "Rack_C", "Rack_D", "Rack_E" }
ProvingPlan.SEQUENCE_RACK = "Rack_C"
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

return ProvingPlan
