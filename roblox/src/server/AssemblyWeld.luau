--!strict
-- Bind a group of parts into ONE anchored assembly, so moving the root moves all of them and a
-- client animating the group writes a single CFrame instead of one per part.
--
-- ⚠ THE CHILDREN MUST BE UNANCHORED. Two ANCHORED parts welded together remain two independent
-- anchored roots: moving one does not move the other and the weld buys nothing. An anchored root
-- with unanchored parts welded to it is a single ANCHORED assembly -- not physically simulated,
-- not replicated as motion -- which is what makes this safe underneath a client-side animation:
-- the server never pushes a correcting CFrame, exactly as when every part was anchored alone.
--
-- ⚠ WELD FIRST, UNANCHOR SECOND, per part. Reversed, a part whose weld fails for any reason is a
-- loose unanchored board in the middle of the world. This order means the worst case is a part
-- that stays anchored and simply does not follow -- visible, but not falling.
--
-- ⚠ AND THIS BELONGS ON THE SERVER, not in the client controller that does the animating. These
-- assemblies stream, and on a CLIENT a model's parts arrive piecemeal -- welding at tag time there
-- would bind whatever had arrived and leave the rest behind, tearing the model apart in view. On
-- the server the model is complete before it is parented, so the tag fires against a whole object.
-- The same class of bug as the ChochinSway registration race (2026-09-06).
local AssemblyWeld = {}

-- Welds every part in `parts` (except `root`) to `root` and unanchors it. `root` is forced
-- Anchored so the finished assembly is static. Returns the number of parts bound.
function AssemblyWeld.bind(root: BasePart, parts: { BasePart }): number
    root.Anchored = true
    local bound = 0
    for _, p in parts do
        if p ~= root and p.Anchored then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = root
            weld.Part1 = p
            weld.Parent = root
            p.Anchored = false
            bound += 1
        end
    end
    return bound
end

-- Collect a model's BaseParts and bind them to one root, chosen as the part nearest the model's
-- pivot so the assembly turns about roughly the point the animation pivots around.
--
-- Publishes two things a client needs to drive the assembly the way `Model:PivotTo` would:
--   * an `AssemblyRoot` ObjectValue pointing at the root part, and
--   * an `AssemblyRootOffset` CFrame attribute = the root's pose RELATIVE TO THE AUTHORED PIVOT.
-- A client then writes `root.CFrame = targetPivot * offset` and gets exactly PivotTo's result for
-- one property write instead of one per part.
--
-- ⚠ DO NOT SET `model.PrimaryPart` TO THE ROOT, AND DO NOT DERIVE THE OFFSET AFTER DOING SO.
-- `GetPivot()` returns the PrimaryPart's CFrame once one is set, so the offset computes as the
-- IDENTITY and silently discards the ROTATION difference between the authored `WorldPivot` and the
-- root part's own orientation. The positions coincide here -- the hang loop sits on the hang point
-- -- so this reads correct in every position check and is wrong only in orientation. Shipped
-- 2026-09-06 and the owner saw it immediately: the hanabiya chōchin hung with their bottoms 0.51
-- studs east, swinging +/-0.045 about that lean, while at rest they are plumb to 0.03. Take the
-- pivot BEFORE touching the model, and keep the full CFrame offset, rotation included.
function AssemblyWeld.bindModel(model: Model): (BasePart?, number)
    -- Read the authored pivot FIRST: nothing below may have moved or re-rooted the model yet.
    local pivot = model:GetPivot()
    local parts: { BasePart } = {}
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            table.insert(parts, d)
        end
    end
    if #parts == 0 then
        return nil, 0
    end
    local root = parts[1]
    local best = (root.Position - pivot.Position).Magnitude
    for i = 2, #parts do
        local d = (parts[i].Position - pivot.Position).Magnitude
        if d < best then
            root, best = parts[i], d
        end
    end
    local offset = pivot:ToObjectSpace(root.CFrame)
    local bound = AssemblyWeld.bind(root, parts)
    model:SetAttribute("AssemblyRootOffset", offset)
    local ref = Instance.new("ObjectValue")
    ref.Name = "AssemblyRoot"
    ref.Value = root
    ref.Parent = model
    return root, bound
end

return AssemblyWeld
