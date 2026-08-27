## Task 10: Tunnel-gate survey tool + authored data

**Files:**
- Create: `roblox/tools/studio/surveyAccessGates.luau`
- Modify: `roblox/src/server/PadSites.luau`

**Interfaces:**
- Consumes: `PadSites` shape (existing per-pad tables).
- Produces: `PadSites[padId].accessGates: { { cframe: {number}, size: {number} } }` (optional per pad); a Studio survey tool that bakes it. Task 5's `gatesForPad` already reads this field, so no server logic changes.

> This task authors DATA via an in-Studio survey (like the deck-placement survey). The tool and the baked values are the deliverable; there is no Lune test for authored geometry.

- [ ] **Step 1: Write the survey tool `roblox/tools/studio/surveyAccessGates.luau`**

```lua
--!strict
-- Studio survey tool for teahouse tunnel-mouth access gates (2026-07-19). Run in Edit mode. For
-- each pad that is reached via a tunnel ("where appropriate"), it spawns a draggable slab at the
-- pad's deck position; drag/scale each slab to fill its tunnel mouth, then run the tool again with
-- MODE="bake" to print the PadSites[padId].accessGates literals to paste into PadSites.luau.
-- Mirrors tools/studio/surveyDeckPlacements.luau. Place-only; values are baked into PadSites.
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- EDIT THESE for the run:
local MODE = "place" -- "place" spawns draggable slabs; "bake" reads them back and prints literals
local PAD_IDS = { "T03", "T14" } -- the pads whose access is a tunnel (author "where appropriate")

local PadSites = require(ServerScriptService:WaitForChild("Server"):WaitForChild("PadSites"))

local FOLDER_NAME = "AccessGateSurvey"

local function place()
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder then
        folder:Destroy()
    end
    folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    folder.Parent = Workspace
    for _, padId in PAD_IDS do
        local spec = PadSites[padId]
        if spec == nil then
            warn(`[survey] unknown pad {padId}`)
            continue
        end
        local place12 = spec.deckPlacements[spec.deckSize] or spec.deckPlacements[spec.maxSize]
        local slab = Instance.new("Part")
        slab.Name = padId
        slab.Anchored = true
        slab.CanCollide = false
        slab.Color = Color3.fromRGB(200, 60, 60)
        slab.Transparency = 0.4
        slab.Size = Vector3.new(8, 8, 1)
        slab.CFrame = CFrame.new(place12[1], place12[2] + 4, place12[3])
        slab.Parent = folder
    end
    print(`[survey] placed {#PAD_IDS} draggable slabs under Workspace.{FOLDER_NAME}; drag each into its tunnel mouth, then set MODE="bake"`)
end

local function bake()
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder == nil then
        warn(`[survey] no {FOLDER_NAME} folder; run MODE="place" first`)
        return
    end
    for _, slab in folder:GetChildren() do
        if slab:IsA("BasePart") then
            local c = { slab.CFrame:GetComponents() }
            -- GetComponents returns x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22 (12 numbers)
            local cf = string.format(
                "{ %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f }",
                c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]
            )
            local sz = string.format("{ %.4f, %.4f, %.4f }", slab.Size.X, slab.Size.Y, slab.Size.Z)
            print(`["${slab.Name}"] accessGates = { { cframe = {cf}, size = {sz} } },`)
        end
    end
    print("[survey] paste each printed accessGates line into the matching PadSites entry")
end

if MODE == "place" then
    place()
else
    bake()
end
```

- [ ] **Step 2: Add `accessGates` to the surveyed pads in `PadSites.luau`**

Run the tool in Studio (`MODE="place"`, drag slabs into the tunnel mouths of the tunnel-accessed pads, then `MODE="bake"`), and paste the printed `accessGates` line into each matching pad entry. For example, `T03` gains:

```lua
    ["T03"] = {
        id = "T03",
        displayName = "Near Perch 03",
        deckPlacements = { --[[ ...existing... ]] },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
        accessGates = { { cframe = { --[[ 12 surveyed numbers ]] }, size = { --[[ 3 ]] } } },
    },
```

Pads reached only by open paths (no tunnel) get no `accessGates` — the derived deck-back gate + backstop already cover them.

- [ ] **Step 3: Verify the data parses + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS (PadSites still loads; no test asserts the new field).
Run: `cd roblox && rojo build -o /tmp/ac-t10-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add roblox/tools/studio/surveyAccessGates.luau roblox/src/server/PadSites.luau
git commit -m "feat(roblox): tunnel-mouth access-gate survey tool + authored data"
```

---

## Visual gate (after Task 10 — run in Studio via Rojo, not a task)

Deploy the backend (push the branch → dev App Runner) and `rojo serve`, then with two players (or a second account/test client):
1. Owner opens the panel Access section; toggles **Public → Private** — a second player standing on the deck is bounced (backstop) and sees the noren gate at the deck back; a non-owner walking up is stopped at the gate.
2. **Friends** mode — a Roblox friend of the owner walks straight in; a non-friend is stopped.
3. **Invite by username** (online and offline) — the named player passes; a bad name shows the notice, no change.
4. **Revoke** — the evicted player is bounced next tick and the gate reappears for them.
5. A **side jump-in** onto the deck is bounced by the backstop.
6. The **tunnel-mouth gate** stops a blocked player at the tunnel (surveyed pads).
7. Owner and allowed guests always pass; Public decks have no gate at all.

---

## Self-Review notes (for the executor)

- **Spec coverage:** policy + persistence (T1,T2), `canEnter` (T3), gate/eviction geometry (T4), server stash/compute/push + remotes (T5), the three mutating handlers + username/name resolution (T6), backstop (T7), client gates (T8), panel UI (T9), tunnel survey (T10) — all spec sections covered.
- **Type consistency:** `teahouseAccess = { mode, invited: number[] }` and the `AccessBlocked { blocked: {{ padId, gates: {{ cframe, size }} }} }` / `AccessState { mode, invited: {{ userId, name }}, notice? }` shapes match across producer (T5/T6) and consumers (T8/T9); `canEnter` and `AccessGates` signatures match their call sites in T5/T7.
- **Known deferred (do NOT build):** guest-pass / portal-to-friend, block/ban lists, per-decoration/per-floor/time-limited access, gate art.
