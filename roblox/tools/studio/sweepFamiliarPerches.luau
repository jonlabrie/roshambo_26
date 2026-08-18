--!strict
-- sweepFamiliarPerches.luau — stamps invisible perch anchors for the familiars.
-- PASTE INTO THE STUDIO COMMAND BAR. Idempotent: re-running clears its own output first.
--
-- Spec: docs/superpowers/specs/2026-08-18-familiar-perches-design.md
--
-- ⚠ THIS TOOL OWNS ONLY PLACE-ONLY GEOMETRY, and that is the whole design. Perches are stamped
-- onto things whose lifetime nothing else controls. There are THREE categories in this world and
-- only one of them is ours (survey, 2026-08-18):
--
--   1. ROJO-OWNED — every roof. Hanabiya, MachiyaApparel/Accessories/Stats and Chaya are all
--      RoshamboStage children built from assets/*.model.json, so an attachment stamped on their
--      `Ridge` would be destroyed by the next sync. Roof perches must be emitted by the BUILDER
--      into the model.json. NOT swept here.
--   2. RUNTIME-BUILDER-OWNED — deck railings. `PadOps.buildRailing` runs on every pad claim, so a
--      swept perch on a deck `RailCap` survives until the next player claims that pad. Emitted by
--      PadOps. NOT swept here.
--   3. PLACE-ONLY — path railings, the two hand-built landings, and the hero trees. Nothing
--      regenerates them. THIS is what the sweep owns.
--
-- Getting 1 or 2 wrong is the worst kind of bug: it works when you test it and degrades silently
-- in normal play.
local CollectionService = game:GetService("CollectionService")

local TAG = "FamiliarPerch"

-- ⚠ THE KIND RIDES THE NAME (`FamiliarPerch_rail`), matching `Spec.perch` in the builders. The
-- builder path cannot use an attribute -- `genmodels` maps className/properties/children and does
-- not plumb attributes -- so both paths use the name and a perch reads the same whether it was
-- emitted or swept.

-- One perch roughly every this many studs of railing. Path rails are ~1.62 studs each and there
-- are 1250 of them; one perch per segment would be a row of birds along every path in the canyon.
-- GUESS, and the first thing to change after a look.
local RAIL_SPACING = 14

-- ⚠ MATCH BY PATTERN, NOT BY EXACT NAME. The first version matched "RailCap" literally and missed
-- almost everything, because this world suffixes: the Overlook has `RailNUpperDeckCap1` and six
-- `Newel...Cap` post tops, Bridge3 has `RailCapN_1..20`, SwitchbackDeck has `RailEastCap` and
-- `StairCapN`. Only the canyon path railings use a bare `Rail`.
--
-- Newel caps are IN, at the owner's call: a post top at the corner of a railing is the most
-- bird-like surface in the world. Mid-rails and balusters are out -- a bird does not land on those.
local PERCHABLE = {
    -- "Cap" ANYWHERE after the prefix, not anchored to the tail: Bridge3 names its cap rails
    -- `RailCapN_1..20`, which an anchored pattern rejects. Mid-rails and balusters still never
    -- match, which is the only thing the pattern has to get right.
    { pat = "^Rail.*Cap", kind = "rail" },
    { pat = "^Newel.*Cap$", kind = "post" },
    { pat = "^StairCap", kind = "rail" },
    { pat = "^Rail$", kind = "rail" }, -- the canyon path railings
    { pat = "^HandCable$", kind = "rail" }, -- the suspension bridge's hand line
}

-- Ground plants a bird would not land on. Everything else under Foliage.Heroes is a tree.
local NOT_A_TREE = { "Iris", "Reed", "Fern", "Weed", "Grass" }

local world = workspace:FindFirstChild("CanyonWorld") or error("[perches] Workspace.CanyonWorld missing")

local function isGroundPlant(name: string): boolean
    for _, frag in NOT_A_TREE do
        if string.find(name, frag) then
            return true
        end
    end
    return false
end

-- Clear ONLY our own output, and only under the roots we sweep — a perch emitted by a builder
-- elsewhere is not ours to remove.
local cleared = 0
for _, inst in CollectionService:GetTagged(TAG) do
    if inst:IsDescendantOf(world) then
        inst:Destroy()
        cleared += 1
    end
end

local function perch(parent: BasePart, localCF: CFrame, kind: string)
    local a = Instance.new("Attachment")
    a.Name = `FamiliarPerch_{kind}`
    a.CFrame = localCF
    a.Parent = parent
    CollectionService:AddTag(a, TAG)
end

local made: { [string]: number } = { rail = 0, post = 0, branch = 0 }

local function kindFor(name: string): string?
    for _, rule in PERCHABLE do
        if string.match(name, rule.pat) then
            return rule.kind
        end
    end
    return nil
end

-- ===== RAILINGS, POSTS AND CABLES =====
-- Sampled ALONG EACH RUN rather than globally: a run is the natural unit (one stair, one bridge
-- span), and sampling globally would cluster perches wherever the descendant order happened to be
-- dense. A post cap is never sampled away — there are few of them and each one is a good perch.
local function sweep(root: Instance)
    local runs: { [string]: { BasePart } } = {}
    for _, d in root:GetDescendants() do
        if d:IsA("BasePart") then
            local kind = kindFor(d.Name)
            if kind == "post" then
                perch(d, CFrame.new(0, d.Size.Y / 2, 0), "post")
                made.post += 1
            elseif kind then
                local key = `{d.Parent and d.Parent:GetFullName() or "?"}|{kind}`
                runs[key] = runs[key] or {}
                table.insert(runs[key], d)
            end
        end
    end
    for _, segs in runs do
        local len = 0
        for _, p in segs do
            len += math.max(p.Size.X, p.Size.Z)
        end
        local avg = if #segs > 0 then len / #segs else 1
        local stride = math.max(1, math.floor(RAIL_SPACING / math.max(0.5, avg) + 0.5))
        for i = 1, #segs, stride do
            local p = segs[i]
            perch(p, CFrame.new(0, p.Size.Y / 2, 0), "rail")
            made.rail += 1
        end
    end
end

-- ⚠ CanyonWorld ONLY. RoshamboStage is Rojo-owned and its perches are emitted by the builders
-- (`Spec.perch`); sweeping there would be undone by the next sync.
sweep(world)

-- ===== TREES =====
-- ⚠ DERIVED FROM THE BOUNDING BOX, NOT AUTHORED. The spec assumed ~7 species templates; the place
-- actually holds 78 FoliageKit templates and 40 hero instances whose names do not map cleanly onto
-- them (`SugiC`, `DockHero_1`, `Hero_11_PineNiwakiA`). Authoring per template is still the better
-- answer and stays in the spec — this is the cheap approximation that lets the idea be LOOKED at
-- first. If birds in trees read well, replace this with authored anchors; if they do not, we have
-- spent an afternoon rather than a week.
--
-- Two per tree, on opposite sides, at 62% of height: high enough to be in the canopy, low enough
-- not to sit on the very tip.
local heroes = world:FindFirstChild("Foliage") and (world.Foliage :: Instance):FindFirstChild("Heroes")
if heroes then
    for _, tree in (heroes :: Instance):GetChildren() do
        if not tree:IsA("Model") or isGroundPlant(tree.Name) then
            continue
        end
        local ok, cf, size = pcall(function()
            return tree:GetBoundingBox()
        end)
        if not ok or not cf then
            continue
        end
        cf, size = tree:GetBoundingBox()
        local anchorPart = tree.PrimaryPart or tree:FindFirstChildWhichIsA("BasePart", true)
        if not anchorPart then
            continue
        end
        for _, ang in { 0.7, 3.9 } do
            local r = math.max(size.X, size.Z) * 0.28
            local world3 = cf.Position + Vector3.new(math.cos(ang) * r, size.Y * 0.12, math.sin(ang) * r)
            perch(anchorPart, anchorPart.CFrame:ToObjectSpace(CFrame.new(world3)), "branch")
            made.branch += 1
        end
    end
end

print(
    string.format(
        "[perches] cleared %d, made %d (rail %d, post %d, branch %d). Spacing %d studs.",
        cleared,
        made.rail + made.post + made.branch,
        made.rail,
        made.post,
        made.branch,
        RAIL_SPACING
    )
)
print("[perches] RoshamboStage props emit their own via Spec.perch; deck railings via PadOps.")
print("[perches] SAVE THE PLACE — these attachments are place-only.")
