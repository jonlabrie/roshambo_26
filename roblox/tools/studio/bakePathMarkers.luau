-- MCP/Edit: read workspace.PathDraft markers -> print a paste-ready ArenaLayout.paths
-- table. Groups markers by route name (the part name before the "_NN" suffix), sorts
-- by index, and emits one { name, class, points } entry per route.
local folder = workspace:FindFirstChild("PathDraft")
if not folder then
    return "no PathDraft folder — run draftPathMarkers.luau first"
end
-- route -> path class. Add/adjust if you rename or add routes.
local CLASS = { NearWall = "trunk", FarWall = "trunk", Floor = "trunk", Overlook = "spur" }
local routes = {}
local bridges = {} -- "Bridge" / "Bridge2" / ... -> { A = pos, B = pos }
for _, m in folder:GetChildren() do
    local bname, ab = m.Name:match("^(Bridge%d*)_([AB])$")
    if bname then
        bridges[bname] = bridges[bname] or {}
        bridges[bname][ab] = m.Position
    else
        local name, idx = m.Name:match("^(.-)_(%d+)$")
        if name then
            routes[name] = routes[name] or {}
            table.insert(routes[name], { idx = tonumber(idx), p = m.Position })
        end
    end
end

local lines = { "    paths = {" }
for name, pts in routes do
    table.sort(pts, function(a, b)
        return a.idx < b.idx
    end)
    local parts = {}
    for _, e in pts do
        table.insert(parts, ("{ %.1f, %.1f, %.1f }"):format(e.p.X, e.p.Y, e.p.Z))
    end
    table.insert(
        lines,
        ("        { name = %q, class = %q, points = { %s } },"):format(
            name,
            CLASS[name] or "trunk",
            table.concat(parts, ", ")
        )
    )
end
table.insert(lines, "    },")

-- bridge abutment crossings (the bridge structure is built in the bridge sub-project;
-- paths just terminate at these a/b endpoints).
table.insert(lines, "    bridges = {")
for name, ends in bridges do
    if ends.A and ends.B then
        table.insert(
            lines,
            ("        { name = %q, a = { %.1f, %.1f, %.1f }, b = { %.1f, %.1f, %.1f } },"):format(
                name,
                ends.A.X,
                ends.A.Y,
                ends.A.Z,
                ends.B.X,
                ends.B.Y,
                ends.B.Z
            )
        )
    end
end
table.insert(lines, "    },")
return table.concat(lines, "\n")
