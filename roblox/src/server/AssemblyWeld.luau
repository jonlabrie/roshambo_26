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
-- pivot so the assembly turns about roughly the point the animation pivots around. Sets
-- `model.PrimaryPart` to that root, which is how a client finds it without duplicating the choice
-- (and whose absence is a client's signal that this model has NOT been welded yet).
-- Returns the root and the number bound, or nil when the model holds no parts.
function AssemblyWeld.bindModel(model: Model): (BasePart?, number)
    local parts: { BasePart } = {}
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            table.insert(parts, d)
        end
    end
    if #parts == 0 then
        return nil, 0
    end
    local pivot = model:GetPivot().Position
    local root = parts[1]
    local best = (root.Position - pivot).Magnitude
    for i = 2, #parts do
        local d = (parts[i].Position - pivot).Magnitude
        if d < best then
            root, best = parts[i], d
        end
    end
    local bound = AssemblyWeld.bind(root, parts)
    model.PrimaryPart = root
    return root, bound
end

return AssemblyWeld
