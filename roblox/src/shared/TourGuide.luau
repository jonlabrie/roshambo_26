--!strict
-- The tour's step machine, derived ENTIRELY from the persisted seenBeats list — no state of
-- its own, which is what makes the tour survive a rejoin for free (spec §4): the same acks
-- that stop a card re-firing also place the beam. Pure; no Roblox globals (Lune-tested).
--
-- Seen ids are marked at card DISMISSAL, so each id below means "the guest has read the card
-- for this leg". The FURTHEST milestone dominates: dropped cards can leave holes in the list,
-- and a resumed session must never walk the guest backwards.
local TourGuide = {}

-- milestone id -> the step the tour is on once that card has been seen, in rank order.
local MILESTONES: { { id: string, step: string } } = {
    { id = "bank", step = "SHOP" },
    { id = "shopDoor", step = "SHOP" },
    { id = "launchDoor", step = "LAUNCH" },
    { id = "modelDoor", step = "MODEL" },
    { id = "modelHome", step = "DONE" },
}

local BEAM_TAGS: { [string]: string } = {
    SHOP = "TourStop_Shop",
    LAUNCH = "TourStop_Launch",
    MODEL = "TourStop_Model",
}

function TourGuide.step(seen: { string }): string
    local seenSet: { [string]: boolean } = {}
    for _, id in seen do
        seenSet[id] = true
    end
    local step = "NONE"
    for _, m in MILESTONES do
        if seenSet[m.id] then
            step = m.step
        end
    end
    return step
end

function TourGuide.beamTag(step: string): string?
    return BEAM_TAGS[step]
end

return TourGuide
