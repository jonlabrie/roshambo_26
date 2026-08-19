--!strict
-- THE 14 CRESTS. A player's kamon: their mark on a lantern, a noren, a banner.
--
-- ⚠ EVERY CREST IS BUILT FROM THREE PRIMITIVES — ring, disc, bar — AND NOTHING ELSE. That is not
-- minimalism for its own sake: all three are plain Roblox UI Frames (a ring and a disc are frames
-- with UICorner; a bar is a frame with Rotation), so the whole catalog draws with NO IMAGE
-- UPLOADS AT ALL.
--
-- That property is load-bearing, not incidental. Roblox moderation REMOVED a green palmate leaf
-- from this account on 2026-08-01 (see practice/image-moderation.md) — and the commonest kamon
-- motifs are plants: maple, paulownia, ginger, wisteria. A drawn geometric catalog has no upload,
-- so it has no moderation surface at all. `Machiya.luau`'s shop mon already proves the technique:
-- "the ring is a corner-rounded frame... No image uploads."
--
-- ⚠ AND A CHEVRON IS TWO ROTATED BARS. That is why `bar` carries a rotation: it keeps triangles
-- and hexagons inside the same three primitives instead of forcing an image for the one family
-- that would otherwise need one.
--
-- ===== WHY THESE FOURTEEN =====
-- The game's throw glyphs are ○ ─ ∧ — circle, bar, chevron — which are exactly the primitives
-- Japanese geometric heraldry is built from. Each glyph names a real crest family, so a catalog
-- drawn from this game's own vocabulary lands on historical mon rather than inventions.
--
-- ⚠ THE RHYME IS AESTHETIC AND MUST STAY THAT WAY (owner, 2026-08-18). A crest is NOT linked to
-- the throws a player makes. Tying them would put a permanent visible affiliation on every player
-- in a game whose entire skill is reading the crowd — either a false tell or a real one, and both
-- are worse than none. It also leaves the houses/factions layer the metagame spec deferred still
-- available, rather than accidentally half-built.
local Kamon = {}

-- Normalised to a -0.5..0.5 square. The renderer scales to whatever surface it is drawing on.
export type Shape =
    { kind: "ring", r: number, t: number, x: number?, y: number? }
    | { kind: "disc", r: number, x: number?, y: number? }
    | { kind: "bar", x: number?, y: number?, w: number, h: number, rot: number? }

export type Crest = { id: string, name: string, family: string, shapes: { Shape } }

local function ring(r: number, t: number, x: number?, y: number?): Shape
    return { kind = "ring", r = r, t = t, x = x, y = y }
end
local function disc(r: number, x: number?, y: number?): Shape
    return { kind = "disc", r = r, x = x, y = y }
end
local function bar(w: number, h: number, x: number?, y: number?, rot: number?): Shape
    return { kind = "bar", w = w, h = h, x = x, y = y, rot = rot }
end

-- A chevron: two bars meeting at the top. Used by the whole ∧ family.
local function chevron(y: number, span: number, t: number): { Shape }
    return {
        bar(span, t, -span * 0.25, y, -35),
        bar(span, t, span * 0.25, y, 35),
    }
end

local function concat(...: { Shape }): { Shape }
    local out: { Shape } = {}
    for _, list in { ... } do
        for _, s in list do
            table.insert(out, s)
        end
    end
    return out
end

Kamon.CRESTS = {
    -- ○ — the circle families
    { id = "janome", name = "Janome", family = "circle", shapes = { ring(0.46, 0.13) } },
    { id = "kokumochi", name = "Kokumochi", family = "circle", shapes = { ring(0.46, 0.06), disc(0.30) } },
    -- two interlocking rings; the overlap is what names it
    {
        id = "wachigai",
        name = "Wachigai",
        family = "circle",
        shapes = {
            ring(0.28, 0.08, -0.14, 0),
            ring(0.28, 0.08, 0.14, 0),
        },
    },
    {
        id = "mitsudomoe",
        name = "Mitsudomoe",
        family = "circle",
        shapes = {
            ring(0.46, 0.06),
            disc(0.16, 0, -0.16),
            disc(0.16, -0.15, 0.10),
            disc(0.16, 0.15, 0.10),
        },
    },
    -- ─ — the bar families
    { id = "ichimonji", name = "Ichimonji", family = "bar", shapes = { ring(0.46, 0.06), bar(0.62, 0.13) } },
    {
        id = "futatsuhikiryo",
        name = "Futatsu-hikiryo",
        family = "bar",
        shapes = {
            ring(0.46, 0.06),
            bar(0.62, 0.10, 0, -0.13),
            bar(0.62, 0.10, 0, 0.13),
        },
    },
    {
        id = "mitsuhikiryo",
        name = "Mitsu-hikiryo",
        family = "bar",
        shapes = {
            ring(0.46, 0.06),
            bar(0.62, 0.09, 0, -0.20),
            bar(0.62, 0.09),
            bar(0.62, 0.09, 0, 0.20),
        },
    },
    {
        id = "ichimonjimitsuboshi",
        name = "Ichimonji-mitsuboshi",
        family = "bar",
        shapes = {
            bar(0.66, 0.11, 0, -0.20),
            disc(0.11, -0.20, 0.16),
            disc(0.11, 0.20, 0.16),
            disc(0.11, 0, 0.16),
        },
    },
    -- ∧ — the chevron families
    { id = "yamagata", name = "Yamagata", family = "chevron", shapes = chevron(0, 0.46, 0.12) },
    {
        id = "mitsuuroko",
        name = "Mitsu-uroko",
        family = "chevron",
        shapes = concat(chevron(-0.18, 0.34, 0.10), chevron(0.16, 0.34, 0.10)),
    },
    {
        id = "yahazu",
        name = "Yahazu",
        family = "chevron",
        shapes = concat({ ring(0.46, 0.06) }, chevron(0.04, 0.40, 0.11)),
    },
    {
        id = "chigaiyama",
        name = "Chigai-yama",
        family = "chevron",
        shapes = {
            bar(0.62, 0.11, 0, 0, -35),
            bar(0.62, 0.11, 0, 0, 35),
        },
    },
    -- neutral geometrics
    {
        id = "kikko",
        name = "Kikko",
        family = "neutral",
        shapes = {
            bar(0.30, 0.10, 0, -0.24),
            bar(0.30, 0.10, 0, 0.24),
            bar(0.30, 0.10, -0.22, -0.11, 60),
            bar(0.30, 0.10, 0.22, -0.11, -60),
            bar(0.30, 0.10, -0.22, 0.11, -60),
            bar(0.30, 0.10, 0.22, 0.11, 60),
        },
    },
    {
        id = "igeta",
        name = "Igeta",
        family = "neutral",
        shapes = {
            bar(0.62, 0.10, 0, -0.16),
            bar(0.62, 0.10, 0, 0.16),
            bar(0.62, 0.10, -0.16, 0, 90),
            bar(0.62, 0.10, 0.16, 0, 90),
        },
    },
} :: { Crest }

function Kamon.byId(id: string?): Crest?
    for _, c in Kamon.CRESTS do
        if c.id == id then
            return c
        end
    end
    return nil
end

-- ⚠ DETERMINISTIC, so a player has a crest from their first second and nothing has to be stored
-- until they change it. The same id always yields the same crest, on every server and every
-- client, with no round trip.
--
-- COLLISIONS ARE CORRECT, not a flaw to design away: Edo kamon were shared freely across
-- unrelated households — a mon identified a HOUSE, not a person. Fourteen crests across fifty
-- players will repeat, and that is the period being right.
function Kamon.forUserId(userId: string): Crest
    local sum = 0
    for i = 1, #userId do
        sum = (sum * 31 + string.byte(userId, i)) % 100003
    end
    return Kamon.CRESTS[(sum % #Kamon.CRESTS) + 1]
end

return Kamon
