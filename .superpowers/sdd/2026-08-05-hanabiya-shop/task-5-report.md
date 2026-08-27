# Task 5 report: the kanban

## State from Task 4 (confirmed, kept)

`Kanban` remains at `Z0 + 0.2` (44.2), *inside* the frontage line, as the assignment
required. The brief's own snippet said `Z0 - 0.2`; that was stale and was not used.

## Hazard 1 — `toRojo`'s handling of nested non-part children

Read `roblox/tools/genmodels.luau`:

```lua
local function toRojo(spec): any
    local node: any = { className = spec.className, properties = spec.properties }
    if spec.children then
        node.children = {}
        for _, child in spec.children do
            local c = toRojo(child)
            c.name = child.name
            table.insert(node.children, c)
        end
    end
    return node
end
```

This walker is **fully generic** — it only reads `spec.className`, `spec.properties`,
`spec.children`, and (on each child) `child.name`. It never checks that a node came from
`Spec.part`; a bare Luau table with those four fields is indistinguishable from one built by
`Spec.part`/`Spec.model`. So the brief's nested raw tables (`{ name = "Face", className =
"SurfaceGui", properties = {...}, children = {...} }`) recurse correctly with no changes to
`genmodels.luau` needed. Confirmed by generating and inspecting the output (see JSON fragment
below) — `Face` and `Text` both appear as proper nested children of `Kanban`.

`Spec.part`'s own `children` passthrough (`local kids = props.children`) also plays along: it
copies whatever was in `props.children` verbatim onto the returned spec, string keys and all,
without requiring elements to be `PartSpec`-shaped. `Spec.PartSpec`'s type annotation says
`children: { PartSpec }?`, which is technically imprecise for this call site (the elements are
raw tables, not `Spec.part` results) — but Luau's `--!strict` didn't reject it in practice
(stylua/selene both ran clean), likely because the literal table passed to `Spec.part` predates
strict-mode inference reaching into that nested table shape, or `PartSpec`'s fields structurally
match closely enough. Flagging this as a soft type-hole, not a runtime problem — the generator
output is correct either way.

## Hazard 2 — UDim2 encoding: the brief's snippet is wrong, verified and fixed

**Nothing in the repo encodes a UDim2 in a `.model.json` file before this task** — grepped all
`*.model.json` and every `.luau`/`.json` file in `roblox/` for `UDim2`; the only hits are
*runtime* `UDim2.new(...)` calls in Studio-only tooling scripts (`buildFireworkBench.luau`,
`buildChochinPole.luau`, `foliageArrangements.luau`), which go through the real Roblox API, not
this JSON pipeline. So this was genuinely untested — I did not take the brief's `{ 1, 0, 1, 0 }`
on faith. I installed-binary-tested it directly against `rojo build` (rojo 7.7.0, the version
pinned in `rokit.toml`):

- `{"Size": [1, 0, 1, 0]}` → **rejected**: `Wrong type of value for property TextLabel.Size.
  Expected UDim2, got an array of four numbers`. The brief's literal snippet, translated
  naively, does not build.
- `{"Size": {"UDim2": [[1, 0], [1, 0]]}}` → **accepted**. Built successfully, and I round-tripped
  an asymmetric value (`{"UDim2": [[0.25, 10], [0.75, -20]]}`) through `rojo build -o t.rbxmx`
  (XML output) and confirmed the XML shows `XS=0.25 XO=10 YS=0.75 YO=-20` — correct axis order,
  scale-then-offset per axis, X before Y.

This means Rojo's JSON-model format resolves ambiguous-shaped values (bare arrays) only for a
fixed set of types (Vector3, CFrame's 12-number form, Color3, etc. — all already used elsewhere
in this codebase) and requires an explicit `{"TypeName": value}` tag for UDim2 specifically,
since a flat 4-number array is ambiguous with other 4-number types in its reflection database.

**Fix applied**: `Machiya.luau`'s `Text.Size` is `{ UDim2 = { { 1, 0 }, { 1, 0 } } }` in Luau,
which `JsonEmit.encode` serializes as the `{"UDim2": [[1,0],[1,0]]}` shape confirmed above (not
the brief's flat `{1, 0, 1, 0}`).

**Verification beyond the brief's own test loop**: I additionally ran `rojo build
default.project.json` against the *whole* project (not just an isolated snippet) after
regenerating `Hanabiya.model.json`, confirming the full place file builds clean with the new
subtree in place, and grepped the built `.rbxlx` to confirm `花火屋` and the SurfaceGui/TextLabel
properties (TextColor3, Text) survived intact through Rojo's real parser. This is still not a
Studio visual check — whether the built-in fonts actually render these three specific kanji
glyphs (vs. tofu boxes) is a Studio-gate item per the brief's own fallback note ("If the built-in
font turns out not to cover these three characters..."). I could not verify glyph coverage
without opening Studio.

## Generated JSON fragment (Kanban subtree, from `assets/Hanabiya.model.json` after
`lune run tools/genmodels`)

```json
{
  "children": [
    {
      "children": [
        {
          "className": "TextLabel",
          "name": "Text",
          "properties": {
            "BackgroundTransparency": 1,
            "Font": "GothamBold",
            "Size": { "UDim2": [[1, 0], [1, 0]] },
            "Text": "花火屋",
            "TextColor3": [0.87, 0.84, 0.76],
            "TextSize": 90
          }
        }
      ],
      "className": "SurfaceGui",
      "name": "Face",
      "properties": {
        "AlwaysOnTop": false,
        "Face": "Front",
        "PixelsPerStud": 20,
        "ZIndexBehavior": "Sibling"
      }
    }
  ],
  "className": "Part",
  "name": "Kanban",
  "properties": {
    "Anchored": true,
    "CFrame": [7.295, 117.5, 44.2, 1, 0, 0, 0, 1, 0, 0, 0, 1],
    "CanCollide": false,
    "CanQuery": false,
    "CanTouch": false,
    "CastShadow": false,
    "Color": [0.18, 0.19, 0.22],
    "Material": "WoodPlanks",
    "Size": [9.8615, 2.6, 0.25]
  }
}
```

CFrame Z = 44.2 = `Z0 + 0.2` (Z0 = 44.00), confirming the part stayed inside the frontage line
as required — not moved to the brief's stale `Z0 - 0.2`.

## Test / lint output

```
$ lune run tools/genmodels
wrote assets/Hanabiya.model.json
... (15 other assets, unchanged content)

$ lune run tests/run
1070 passed, 0 failed, 1070 total
(two WARN lines from an unrelated pre-existing test, HandlerQueue.spec's intentional
queue-overflow/handler-error assertions — not from this change)

$ stylua --check src tests tools
(clean, exit 0)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

Additionally (not required by the brief, done to close out Hazard 2):
```
$ rojo build default.project.json -o full.rbxlx
Building project 'roshambo-roblox'
Built project to full.rbxlx
$ grep 花火屋 full.rbxlx
<string name="Text">花火屋</string>
```

## Files changed

- `roblox/tools/builders/Machiya.luau` — Kanban part now carries `Face` (SurfaceGui) →
  `Text` (TextLabel) children; kept `Z0 + 0.2`; fixed the UDim2 encoding to the tagged
  `{"UDim2": [[...],[...]]}` form Rojo actually accepts.
- `roblox/tests/Machiya.spec.luau` — added "the Kanban carries the shop's name" test, as
  specified in the brief, verbatim.
- `roblox/assets/Hanabiya.model.json` — regenerated.

## Open item for the Studio gate

Whether the built-in Roblox fonts render 花火屋 without tofu boxes is unverified — this needs a
Studio look, per the brief's own stated fallback (uploaded PNG) if coverage is missing. This is
the one thing in this task that could not be confirmed from the CLI/test harness alone.
