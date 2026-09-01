--!strict
-- A RECIPE IS A LIST OF PHASES; THIS TURNS ONE INTO A TIMED SCHEDULE. Pure, so it runs under Lune —
-- which matters because the rule it carries cannot be checked any other way.
--
-- THE RULE: the particle budget is PER SHELL. A nested shell divides it across its burst phases and
-- across each phase's break points; it never multiplies. Six break points at the full near-budget
-- is six times the fill-rate the mobile floor was measured against, and it would be authored in
-- perfectly good faith by someone assuming each break looks like a normal break. The recipe cannot
-- opt out of the division, which is why `share` is a weight and not a count.
local FireworkSchedule = {}

export type Phase = {
    at: number,
    kind: string, -- "report" | "ascent" | "burst"
    anchor: string, -- "origin" (the tube) | "apex" (where the shell broke)
    points: number?, -- break points; 1 = a simple break, 6 = a nested one
    scatter: number?, -- how far those points spread from the anchor, in studs
    share: number?, -- this burst's weight in the shell's budget
    sound: string?,
    texture: string?,
    color: { number }?,
    edgeColor: { number }?,
    spread: number?,
    droop: boolean?,
    style: string?,
}
export type Recipe = { phases: { Phase } }

export type Event = {
    at: number,
    kind: string,
    anchor: string,
    points: number,
    scatter: number,
    particles: number, -- PER BREAK POINT, not per phase
    sound: string?,
    texture: string?,
    color: { number }?,
    edgeColor: { number }?,
    spread: number?,
    droop: boolean?,
    style: string?,
}

function FireworkSchedule.compile(recipe: Recipe, budget: number): { Event }
    local totalShare = 0
    for _, ph in recipe.phases do
        if ph.kind == "burst" then
            totalShare += ph.share or 1
        end
    end

    local out: { Event } = {}
    for _, ph in recipe.phases do
        local points = ph.points or 1
        local particles = 0
        if ph.kind == "burst" and totalShare > 0 then
            local slice = budget * ((ph.share or 1) / totalShare)
            -- Floor, then floor again per point: rounding UP anywhere here would let a nested
            -- shell creep over the budget the floor measurement bought.
            particles = math.floor(slice / points)
            -- ...but never to nothing. At the far LOD a heavily nested shell would otherwise round
            -- to zero and vanish silently, which reads as a bug rather than as distance. This is
            -- the one place the budget may be fractionally exceeded, and it is deliberate: one
            -- particle per point is the difference between "far away" and "broken".
            if particles < 1 then
                particles = 1
            end
        end
        table.insert(out, {
            at = ph.at,
            kind = ph.kind,
            anchor = ph.anchor,
            points = points,
            scatter = ph.scatter or 0,
            particles = particles,
            sound = ph.sound,
            texture = ph.texture,
            color = ph.color,
            edgeColor = ph.edgeColor,
            spread = ph.spread,
            droop = ph.droop,
            style = ph.style,
        })
    end
    table.sort(out, function(a, b)
        return a.at < b.at
    end)
    return out
end

return FireworkSchedule
