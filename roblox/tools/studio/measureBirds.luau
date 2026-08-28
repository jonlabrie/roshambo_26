--!strict
-- measureBirds.luau — print the familiar roster's as-built facts, from the assets themselves.
--
-- ⚠ THIS EXISTS SO THE WIKI DOES NOT HAVE TO CARRY NUMBERS. `familiars.md` recorded the uguisu at
-- 0.552 studs for a week; the shipped asset is 0.828, and nothing rescales the clone. That was the
-- size the bird was DESIGNED at, transcribed into an as-built page — and no currency check can
-- catch it, because the page and the artifact never agreed, so there is no "change" to detect.
-- A number in prose has no source. A command has one, and it cannot go stale without failing.
--
-- Paste into the Studio command bar in EDIT. Reads only; changes nothing.
--
-- ⚠ TRIANGLE COUNTS ARE NOT HERE, and cannot be: Roblox exposes no vertex or face count for a
-- MeshPart at runtime. They come from the Blender side (`karasu_retarget.run()` reports them), and
-- are the one bird fact that still has to be recorded rather than queried.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local birds = ReplicatedStorage:FindFirstChild("RoshamboBirds")
if not birds then
    -- Rojo-managed (default.project.json). Absent means the place was saved before the birds
    -- were declared, or Rojo has never synced into this place since they were added.
    print("measureBirds: no ReplicatedStorage.RoshamboBirds — connect Rojo and re-sync, or open")
    print("              a place saved after 2026-08-26. Nothing measured.")
    return
end

-- Accept a MeshPart or the Model the 3D Importer wraps it in, exactly as BirdController does.
local function meshOf(a: Instance?): BasePart?
    if not a then
        return nil
    end
    return (if a:IsA("BasePart") then a else a:FindFirstChildWhichIsA("MeshPart", true)) :: BasePart?
end

local rows: { string } = {}
local function line(s: string)
    table.insert(rows, s)
end

line("| asset | size (studs) | length | bones | skinned | MeshId | TextureID |")
line("|---|---|---|---|---|---|---|")

local names: { string } = {}
for _, c in birds:GetChildren() do
    table.insert(names, c.Name)
end
table.sort(names)

local lengths: { [string]: number } = {}
for _, n in names do
    local m = meshOf(birds:FindFirstChild(n))
    if not m then
        line(("| %s | ⚠ no MeshPart | | | | | |"):format(n))
        continue
    end
    local bones = 0
    for _, d in m:GetDescendants() do
        if d:IsA("Bone") then
            bones += 1
        end
    end
    -- ⚠ LENGTH IS THE Z EXTENT. The FBX axis conversion puts nose-to-tail on z, so Size.X is width
    -- and Size.Y is height — reading Size.X as "how long is the bird" is how a wingspan gets
    -- mistaken for a body.
    lengths[n] = m.Size.Z
    line(
        ("| `%s` | %.3f × %.3f × %.3f | %.3f | %d | %s | %s | %s |"):format(
            n,
            m.Size.X,
            m.Size.Y,
            m.Size.Z,
            m.Size.Z,
            bones,
            tostring(m.HasSkinnedMesh),
            string.match(m.MeshId, "%d+") or "—",
            string.match(m.TextureID, "%d+") or "—"
        )
    )
end

line("")
-- The ratio the wiki kept getting wrong, derived rather than typed.
local u, k = lengths.UguisuBody, lengths.KarasuBody
if u and k and u > 0 then
    line(("karasu / uguisu body length = %.2f×  (%.3f vs %.3f)"):format(k / u, k, u))
end

-- ⚠ The feet-at-origin contract, which `perch.WorldPosition` depends on: PivotOffset.Position is
-- the offset from the part CENTRE to the authored origin, so its y should be about half the
-- bird's height, negative. A body and its wings must agree, or the two halves separate in flight.
line("")
line("origin offsets (PivotOffset.Position — body and wings must agree):")
for _, n in names do
    local m = meshOf(birds:FindFirstChild(n))
    if m then
        local o = m.PivotOffset.Position
        line(("  %-14s (%+.3f, %+.3f, %+.3f)"):format(n, o.X, o.Y, o.Z))
    end
end

-- ⚠ PRINT, DO NOT RETURN. The command bar executes the chunk and DISCARDS its return value,
-- so the first version of this file built the whole table and showed nothing — and the wiki had
-- been pointed at it as the authority for bird sizes without anyone ever running it. A tool that
-- produces no output is worse than no tool: it reads as "measured" in a citation.
print("\n" .. table.concat(rows, "\n") .. "\n")
