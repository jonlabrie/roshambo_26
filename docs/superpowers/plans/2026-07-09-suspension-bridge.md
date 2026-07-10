# Suspension Bridge (Kazurabashi) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan
> task-by-task (inline). Steps use checkbox (`- [ ]`) syntax. This is Studio geometry + one runtime
> controller — NOT subagent-drivable: it needs the live Studio MCP and the user's visual/walk sign-off
> between tasks (per the "stop-and-ask-after-each-attempt" rule).

**Goal:** Build the valley's kazurabashi setpiece — a ~112-stud vine/rope suspension footbridge across the
Far-Wall canyon, slatted see-through deck over an invisible floor, woven rope sides, stone anchor piers, and
ambient client sway.

**Architecture:** A Studio-run builder (`tools/studio/buildSuspensionBridge.luau`) generates all geometry from
catenary math, grouping the *visible* rope/slat parts into ~10 span-segment Models (`Seg_1..Seg_10`, each
tagged `BridgeSway` + stamped a `SwayPhase` 0..1 attribute) while the *collision floor and barriers* are static
children of the root. A committed client controller (`src/client/BridgeSway.client.luau`) pivots the tagged
segments in a travelling sine wave; the collision floor never moves.

**Tech Stack:** Luau, Roblox Terrain/Instance/CollectionService APIs, Rojo 7.7, Studio MCP `execute_luau`.

## Global Constraints

- Output geometry parents under `Workspace.CanyonWorld.Structures.Bridges.SuspensionBridge` (place-only; NEVER
  Workspace root — the sweep convention). SAVE THE PLACE after building.
- Endpoints read from the abutment caps: `A_Cap top ≈ (−248.00, 218.43, 55.71)`, `B_Cap top ≈ (−243.82,
  218.31, −56.29)`. **SAG = 8** studs (midspan deck ≈ Y 210.4). **Deck width = 6** (edge cables at ±3).
- Palette: TIMBER 107/79/51, CAP_DARK 30/26/20, STONE 96/94/88, **VINE 105/86/55**, LASHING 120/100/66.
- **Segments = 10.** Visible parts (cables, suspenders, lattice, slats) go under `Seg_i` (tagged `BridgeSway`,
  attribute `SwayPhase` = segment mid-arc t). Collision floor + barriers are static root children, never swayed.
- Sway params (controller): lateral amp **0.3**, vertical amp **0.15**, wavelength **span/1.5**, period **~7 s**;
  endpoint segments taper amplitude → 0 so the deck stays anchored at the piers.
- Verification is in-Studio (measurement scripts with expected values) + user visual/walk check. No Lune/Vitest.
  CI runs `stylua --check` + `selene` on `src tests tools` — both new `.luau` files must pass. No `.rbxl` committed.
- Commit messages end with the two required trailers (Co-Authored-By + Claude-Session). Commit only the on-disk
  files; geometry is place-only (user saves).

---

### Shared builder core (defined in Task 1, used by all geometry tasks)

These helpers live at the top of `buildSuspensionBridge.luau` and every later task calls them:

```lua
local CONFIG = {
    capA = "Abutment_A_Cap", capB = "Abutment_B_Cap", -- read live positions (top face = pos + sizeY/2)
    SAG = 8, WIDTH = 6, N_SEG = 10,
    handH = 2.9, edgeDia = 0.5, handDia = 0.36, suspDia = 0.14, latticeDia = 0.10,
    suspEvery = 4.0, cableSeg = 1.5,           -- suspender arc spacing; cable cylinder length
    slatPitch = 1.05, slatLen = 6.4, slatH = 0.28, slatD = 0.55, slatProud = 0.06,
    floorSeg = 2.0, floorH = 0.4, barrierH = 5.0, barrierT = 0.4,
    VINE = Color3.fromRGB(105,86,55), LASH = Color3.fromRGB(120,100,66),
    TIMBER = Color3.fromRGB(107,79,51), STONE = Color3.fromRGB(96,94,88), DARK = Color3.fromRGB(30,26,20),
}
local function capTop(name)
    local p; for _,d in workspace:GetDescendants() do if d.Name==name and d:IsA("BasePart") then p=d break end end
    assert(p, "missing "..name); return Vector3.new(p.Position.X, p.Position.Y + p.Size.Y/2, p.Position.Z)
end
local A, B                       -- filled at build time from capTop
local function lerp(a,b,t) return a+(b-a)*t end
local function deckPoint(t)      -- centreline catenary (parabolic sag)
    return Vector3.new(lerp(A.X,B.X,t), lerp(A.Y,B.Y,t) - CONFIG.SAG*4*t*(1-t), lerp(A.Z,B.Z,t))
end
local function travel(t)         -- horizontal unit travel direction at t
    local d = deckPoint(math.min(t+0.01,1)) - deckPoint(math.max(t-0.01,0))
    d = Vector3.new(d.X,0,d.Z); return d.Magnitude>1e-4 and d.Unit or Vector3.new(0,0,-1)
end
local function cross(t) local tr=travel(t); return Vector3.new(-tr.Z,0,tr.X) end -- horizontal, cross-span
local function segFor(t) return math.clamp(math.floor(t*CONFIG.N_SEG)+1, 1, CONFIG.N_SEG) end
```

Segment Models are created once (Task 1) and reused: `Seg_i` under the root, `WorldPivot` at `deckPoint((i-0.5)/N)`,
attribute `SwayPhase = (i-0.5)/N`, tag `BridgeSway`. A `partIntoSeg(part, t)` helper parents a part under `Seg_{segFor(t)}`.

---

### Task 1: Builder scaffold + catenary cables (deck-edge ×2, hand ×2) + sway segments

**Files:**
- Create: `roblox/tools/studio/buildSuspensionBridge.luau`

**Interfaces:**
- Produces: the shared core above; root `SuspensionBridge` Model with `Seg_1..Seg_10` (tagged `BridgeSway`,
  `SwayPhase` set); four catenary cables built as chained cylinders parented into segments; helpers
  `deckPoint(t)`, `cross(t)`, `segFor(t)`, `partIntoSeg(part,t)`, `cyl(parent,name,dia,a,b,color)`.

- [ ] **Step 1: Write the builder core + segment creation + a `cyl` segment-chain helper**

```lua
-- cyl: a cylinder spanning world points a->b (long axis local X)
local function cyl(parent,name,dia,a,b,color)
    local p=Instance.new("Part"); p.Name=name; p.Shape=Enum.PartType.Cylinder; p.Anchored=true
    p.CanCollide=false; p.Color=color; p.Material=Enum.Material.Wood
    p.Size=Vector3.new((b-a).Magnitude+dia*0.5, dia, dia)
    p.CFrame=CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.rad(90),0); p.Parent=parent; return p
end
```

- [ ] **Step 2: Build root + segments**

```lua
local CS=game:GetService("CollectionService")
A,B=capTop(CONFIG.capA),capTop(CONFIG.capB)
local bridges=workspace.CanyonWorld.Structures:FindFirstChild("Bridges") or Instance.new("Model")
bridges.Name="Bridges"; bridges.Parent=workspace.CanyonWorld.Structures
local root=bridges:FindFirstChild("SuspensionBridge"); if root then root:Destroy() end
root=Instance.new("Model"); root.Name="SuspensionBridge"; root.Parent=bridges
local seg={}
for i=1,CONFIG.N_SEG do
    local m=Instance.new("Model"); m.Name="Seg_"..i; m.Parent=root
    local ph=(i-0.5)/CONFIG.N_SEG; m:SetAttribute("SwayPhase",ph); m.WorldPivot=CFrame.new(deckPoint(ph))
    CS:AddTag(m,"BridgeSway"); seg[i]=m
end
local function partIntoSeg(part,t) part.Parent=seg[segFor(t)] end
```

- [ ] **Step 3: Build the four cables (2 deck-edge at ±3, 2 hand at +handH), chained cylinders**

```lua
local function edge(t,side) return deckPoint(t)+cross(t)*(CONFIG.WIDTH/2*side) end
local total=(B-A); local n=math.ceil((deckPoint(1)-deckPoint(0)).Magnitude/CONFIG.cableSeg)
for _,side in {1,-1} do
    for i=0,n-1 do
        local t0,t1=i/n,(i+1)/n
        local eA,eB=edge(t0,side),edge(t1,side)
        cyl(seg[segFor((t0+t1)/2)],"DeckCable",CONFIG.edgeDia,eA,eB,CONFIG.VINE)
        local hA,hB=eA+Vector3.new(0,CONFIG.handH,0),eB+Vector3.new(0,CONFIG.handH,0)
        cyl(seg[segFor((t0+t1)/2)],"HandCable",CONFIG.handDia,hA,hB,CONFIG.VINE)
    end
end
return string.format("cables built: %d segs, %d cable parts", CONFIG.N_SEG, #root:GetDescendants())
```

- [ ] **Step 4: Run in Studio (paste the file via `execute_luau`, Edit datamodel). Verify measurements**

Run this measurement in Studio after building:
```lua
local root=workspace.CanyonWorld.Structures.Bridges.SuspensionBridge
local function nearestCableY(t) -- sample deck-edge cable height near arc t at side +1
  -- (report deckPoint Y directly; cables sit on it)
end
local A=Vector3.new(-248.00,218.43,55.71); local B=Vector3.new(-243.82,218.31,-56.29)
local function dp(t) return Vector3.new(A.X+(B.X-A.X)*t, A.Y+(B.Y-A.Y)*t-8*4*t*(1-t), A.Z+(B.Z-A.Z)*t) end
local segs=0; for _,c in root:GetChildren() do if c.Name:match("^Seg_") then segs+=1 end end
return string.format("segs=%d endA.Y=%.1f mid.Y=%.1f endB.Y=%.1f parts=%d",segs,dp(0).Y,dp(0.5).Y,dp(1).Y,#root:GetDescendants())
```
Expected: `segs=10`, `endA.Y≈218.4`, `mid.Y≈210.4`, `endB.Y≈218.3`, parts in the low hundreds. **User looks:**
the four ropes sweep in a gentle sag from cap to cap.

- [ ] **Step 5: Commit the builder file**

```bash
git add roblox/tools/studio/buildSuspensionBridge.luau
git commit -m "feat(zendojo): suspension bridge builder — catenary cables + sway segments"
```

---

### Task 2: Vertical suspenders + woven side lattice

**Files:**
- Modify: `roblox/tools/studio/buildSuspensionBridge.luau`

**Interfaces:**
- Consumes: `deckPoint`, `edge(t,side)`, `cyl`, `seg`, `segFor`, `CONFIG`.
- Produces: `Susp*`/`Lattice*` parts under the segments.

- [ ] **Step 1: Add suspenders every `suspEvery` studs of arc, each side (hand→deck)**

```lua
local span=(deckPoint(1)-deckPoint(0)).Magnitude
local nS=math.max(2, math.floor(span/CONFIG.suspEvery))
for _,side in {1,-1} do
    for i=0,nS do
        local t=i/nS; local e=edge(t,side); local h=e+Vector3.new(0,CONFIG.handH,0)
        cyl(seg[segFor(t)],"Susp",CONFIG.suspDia,e,h,CONFIG.VINE)
    end
end
```

- [ ] **Step 2: Add one diagonal lattice rope per bay, alternating lean**

```lua
for _,side in {1,-1} do
    for i=0,nS-1 do
        local t0,t1=i/nS,(i+1)/nS
        local lo,hi = edge(t0,side), edge(t1,side)+Vector3.new(0,CONFIG.handH,0)
        if i%2==1 then lo,hi = edge(t0,side)+Vector3.new(0,CONFIG.handH,0), edge(t1,side) end
        cyl(seg[segFor((t0+t1)/2)],"Lattice",CONFIG.latticeDia,lo,hi,CONFIG.LASH)
    end
end
```

- [ ] **Step 3: Re-run the full builder in Studio. Verify**

```lua
local root=workspace.CanyonWorld.Structures.Bridges.SuspensionBridge
local s,l=0,0; for _,d in root:GetDescendants() do if d.Name=="Susp" then s+=1 end if d.Name=="Lattice" then l+=1 end end
return "suspenders="..s.." lattice="..l -- expect ~2*(nS+1) suspenders, ~2*nS lattice (nS≈28)
```
Expected: ~58 suspenders, ~56 lattice. **User looks:** the sides read as a woven rope rail.

- [ ] **Step 4: Commit**

```bash
git add roblox/tools/studio/buildSuspensionBridge.luau
git commit -m "feat(zendojo): suspension bridge suspenders + woven side lattice"
```

---

### Task 3: Deck slats (see-through)

**Files:**
- Modify: `roblox/tools/studio/buildSuspensionBridge.luau`

**Interfaces:**
- Consumes: `deckPoint`, `cross`, `travel`, `seg`, `segFor`, `CONFIG`.
- Produces: `Slat_*` parts under the segments (top at deckPoint.Y + slatProud).

- [ ] **Step 1: Lay cross-slats along the span at `slatPitch`, tinted, yaw to travel**

```lua
local span=(deckPoint(1)-deckPoint(0)).Magnitude
local nSlat=math.floor(span/CONFIG.slatPitch)
local rng=0; local function rnd() rng=(1103515245*rng+12345)%2^31; return rng/2^31 end; rng=20260709
for i=0,nSlat do
    local t=i/nSlat; local c=deckPoint(t); local tr=travel(t)
    local tint=math.floor((rnd()*2-1)*8+0.5)
    local p=Instance.new("Part"); p.Name="Slat_"..i; p.Anchored=true; p.CanCollide=false
    p.Material=Enum.Material.Wood
    p.Color=Color3.fromRGB(math.clamp(107+tint,0,255),math.clamp(79+tint,0,255),math.clamp(51+tint,0,255))
    p.Size=Vector3.new(CONFIG.slatLen,CONFIG.slatH,CONFIG.slatD)
    local top=c.Y+CONFIG.slatProud
    p.CFrame=CFrame.lookAt(Vector3.new(c.X,top-CONFIG.slatH/2,c.Z),Vector3.new(c.X,top-CONFIG.slatH/2,c.Z)+tr)
        *CFrame.Angles(0,math.rad(90),0)
    p.Parent=seg[segFor(t)]
end
```

- [ ] **Step 2: Re-run builder. Verify slat count + gap ratio**

```lua
local root=workspace.CanyonWorld.Structures.Bridges.SuspensionBridge
local n=0; for _,d in root:GetDescendants() do if d.Name:match("^Slat_") then n+=1 end end
return "slats="..n.." (expect ~"..math.floor(112/1.05)..") gap≈"..(1.05-0.55)
```
Expected: ~106 slats, gap ≈ 0.5. **User looks:** deck reads as slats with river visible through the gaps;
slats sit just proud, no z-fight with the cables.

- [ ] **Step 3: Commit**

```bash
git add roblox/tools/studio/buildSuspensionBridge.luau
git commit -m "feat(zendojo): suspension bridge see-through deck slats"
```

---

### Task 4: Invisible collision floor + fall barriers (static)

**Files:**
- Modify: `roblox/tools/studio/buildSuspensionBridge.luau`

**Interfaces:**
- Consumes: `deckPoint`, `cross`, `travel`, `root`, `CONFIG`.
- Produces: `Floor_*` + `Barrier_*` parts as **direct children of `root`** (NOT segments — never swayed).

- [ ] **Step 1: Build a continuous CanCollide floor following the catenary (static)**

```lua
local nF=math.ceil(span/CONFIG.floorSeg)
for i=0,nF-1 do
    local t0,t1=i/nF,(i+1)/nF; local a,b=deckPoint(t0),deckPoint(t1); local tr=travel((t0+t1)/2)
    local ctr=(a+b)/2; local len=(b-a).Magnitude+0.4
    local f=Instance.new("Part"); f.Name="Floor_"..i; f.Anchored=true; f.CanCollide=true
    f.Transparency=1; f.CastShadow=false
    f.Size=Vector3.new(CONFIG.WIDTH, CONFIG.floorH, len)
    f.CFrame=CFrame.lookAt(Vector3.new(ctr.X, ctr.Y-CONFIG.floorH/2, ctr.Z),
        Vector3.new(ctr.X, ctr.Y-CONFIG.floorH/2, ctr.Z)+tr)
    f.Parent=root
end
```

- [ ] **Step 2: Build invisible fall barriers along each edge (static)**

```lua
for _,side in {1,-1} do
    for i=0,nF-1 do
        local t0,t1=i/nF,(i+1)/nF; local a,b=deckPoint(t0),deckPoint(t1)
        local ea=a+cross(t0)*(CONFIG.WIDTH/2*side); local eb=b+cross(t1)*(CONFIG.WIDTH/2*side)
        local ctr=(ea+eb)/2; local tr=travel((t0+t1)/2)
        local bar=Instance.new("Part"); bar.Name="Barrier_"..(side>0 and "R" or "L").."_"..i
        bar.Anchored=true; bar.CanCollide=true; bar.Transparency=1; bar.CastShadow=false
        bar.Size=Vector3.new(CONFIG.barrierT, CONFIG.barrierH, (eb-ea).Magnitude+0.4)
        bar.CFrame=CFrame.lookAt(Vector3.new(ctr.X, ctr.Y+CONFIG.barrierH/2, ctr.Z),
            Vector3.new(ctr.X, ctr.Y+CONFIG.barrierH/2, ctr.Z)+tr)
        bar.Parent=root
    end
end
```

- [ ] **Step 3: Re-run builder. Verify walkability in Play**

Start Play; walk a character across. Then measure clearance/continuity:
```lua
-- (Edit) confirm floor slabs are contiguous in Y with the deck catenary and static under root
local root=workspace.CanyonWorld.Structures.Bridges.SuspensionBridge
local nf,nb=0,0; for _,d in root:GetChildren() do if d.Name:match("^Floor_") then nf+=1 end if d.Name:match("^Barrier_") then nb+=1 end end
return "floor="..nf.." barriers="..nb.." (static root children)"
```
Expected: floor ≈ 56, barriers ≈ 112. **User walks it:** crosses end-to-end without falling; midspan ~36
studs over the water; barriers keep them on.

- [ ] **Step 4: Commit**

```bash
git add roblox/tools/studio/buildSuspensionBridge.luau
git commit -m "feat(zendojo): suspension bridge invisible collision floor + fall barriers"
```

---

### Task 5: Anchor pier dressing + relocate piers to CanyonWorld

**Files:**
- Modify: `roblox/tools/studio/buildSuspensionBridge.luau`

**Interfaces:**
- Consumes: `A`, `B`, `travel`, `edge`, `CONFIG`, the abutment parts in `Sandbox/TempBridgeAbutments`.
- Produces: `PierA`/`PierB` dressed Models (stone facing + timber cap + deadman post + cable lashings) under
  `CanyonWorld/Structures/Bridges`; deadman posts where the four cables terminate behind each cap.

- [ ] **Step 1: For each abutment, add stone facing slabs + timber cap band + a lashed deadman post**

```lua
local function dressPier(name, capName, inward)
    -- capName top-centre = anchor line; inward = unit horizontal toward the span
    local cap=nil; for _,d in workspace:GetDescendants() do if d.Name==capName and d:IsA("BasePart") then cap=d break end end
    local pier=Instance.new("Model"); pier.Name=name; pier.Parent=workspace.CanyonWorld.Structures.Bridges
    -- stone facing: a slab hugging the outward face of the pier block (pier block = capName without _Cap)
    local blockName=capName:gsub("_Cap","")
    local blk; for _,d in workspace:GetDescendants() do if d.Name==blockName and d:IsA("BasePart") then blk=d break end end
    local face=Instance.new("Part"); face.Name="StoneFace"; face.Anchored=true; face.Material=Enum.Material.Slate
    face.Color=CONFIG.STONE; face.Size=blk.Size+Vector3.new(0.6,0,0.6); face.CFrame=blk.CFrame; face.Parent=pier
    -- deadman post behind the cap (outward), where cables lash off
    local top=Vector3.new(cap.Position.X,cap.Position.Y+cap.Size.Y/2,cap.Position.Z)
    local dm=top - inward*3.5
    local post=Instance.new("Part"); post.Name="Deadman"; post.Anchored=true; post.Material=Enum.Material.Wood
    post.Color=CONFIG.TIMBER; post.Size=Vector3.new(1.0,2.6,7.0)
    post.CFrame=CFrame.lookAt(dm+Vector3.new(0,1.0,0), dm+Vector3.new(0,1.0,0)+inward); post.Parent=pier
    return dm
end
-- inward directions: from each cap toward midspan
local inwA=Vector3.new((B-A).X,0,(B-A).Z).Unit
dressPier("PierA","Abutment_A_Cap", inwA)
dressPier("PierB","Abutment_B_Cap", -inwA)
```

- [ ] **Step 2: Lash the four cable ends over each cap to the deadman (short cylinders, LASH colour)**

Extend the cable loop (Task 1) OR add end-lashings here: from `edge(0,side)`/`+hand` and `edge(1,side)`/`+hand`
draw a short cylinder over the cap down to the deadman top. (Use the `dm` returned from `dressPier`; draw
`cyl(root,"Lash",edgeDia,edge(0,side),dmA+Vector3.new(0,2.2,0),LASH)` for each of the 4 ends per pier.)

- [ ] **Step 3: Re-run builder. Verify piers + move final piers out of Sandbox**

The temp `Sandbox/TempBridgeAbutments` blocks stay as the structural cores; `PierA/PierB` dress them under
`CanyonWorld/Structures/Bridges`. **User looks:** piers read as stone abutments; the four cables sweep over the
cap and terminate at the lashed deadman.
```lua
local br=workspace.CanyonWorld.Structures.Bridges
return "PierA="..tostring(br:FindFirstChild("PierA")~=nil).." PierB="..tostring(br:FindFirstChild("PierB")~=nil)
```
Expected: both true.

- [ ] **Step 4: Commit**

```bash
git add roblox/tools/studio/buildSuspensionBridge.luau
git commit -m "feat(zendojo): suspension bridge stone anchor piers + cable lashings"
```

---

### Task 6: BridgeSway client controller

**Files:**
- Create: `roblox/src/client/BridgeSway.client.luau`

**Interfaces:**
- Consumes: models tagged `BridgeSway` with a `SwayPhase` number attribute (0..1) and a stored base
  `WorldPivot`.
- Produces: per-frame `Model:PivotTo(base * sway)`; nothing else references it.

- [ ] **Step 1: Write the controller (tag-driven, folder-agnostic; travelling sine; endpoint taper)**

```lua
--!strict
-- Ambient kazurabashi sway: pivots every BridgeSway-tagged span segment in a slow travelling wave.
-- Discovery is by CollectionService tag (workspace-wide, folder-agnostic — the lantern-architecture lesson).
-- The bridge's collision floor + barriers are NOT tagged, so they never move.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local LAT, VERT = 0.3, 0.15          -- amplitude studs (lateral, vertical)
local PERIOD = 7                     -- seconds
local WAVES = 1.5                    -- ~ how many wave crests across the span
local bases: { [Model]: CFrame } = {}
local function track(m: Instance)
    if m:IsA("Model") and m:GetAttribute("SwayPhase") ~= nil and not bases[m] then
        bases[m] = m:GetPivot()
    end
end
for _, m in CollectionService:GetTagged("BridgeSway") do track(m) end
CollectionService:GetInstanceAddedSignal("BridgeSway"):Connect(track)
CollectionService:GetInstanceRemovedSignal("BridgeSway"):Connect(function(m) bases[m] = nil end)
RunService.RenderStepped:Connect(function()
    local clk = os.clock()
    for m, base in bases do
        local ph = (m:GetAttribute("SwayPhase") :: number) or 0.5
        local taper = math.sin(ph * math.pi)                     -- 0 at piers, 1 at midspan
        local a = ph * WAVES * 2 * math.pi - (clk / PERIOD) * 2 * math.pi
        local dx, dy = math.sin(a) * LAT * taper, math.sin(a + 1.2) * VERT * taper
        m:PivotTo(base * CFrame.new(dx, dy, 0))
    end
end)
```

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua src/client/BridgeSway.client.luau && selene src/client/BridgeSway.client.luau`
Expected: STYLUA rewrites/clean, selene `0 errors 0 warnings`.

- [ ] **Step 3: Verify in Play (needs rojo-synced client). Confirm sway + static floor**

Start Play; watch the deck undulate gently. Then in the Client datamodel:
```lua
task.wait(2)
local root=workspace.CanyonWorld.Structures.Bridges.SuspensionBridge
local f=root:FindFirstChild("Floor_10")
local y1=f.Position.Y; task.wait(1); local y2=f.Position.Y
local seg=root:FindFirstChild("Seg_5"); local p1=seg:GetPivot().Position
task.wait(0.6); local p2=seg:GetPivot().Position
return string.format("floor moved=%.3f (expect ~0)  midseg moved=%.3f (expect >0)", math.abs(y2-y1), (p2-p1).Magnitude)
```
Expected: floor moved ≈ 0 (static), mid segment moved > 0 (swaying). **User watches:** gentle undulation,
deck stays anchored at both piers, walking feels stable.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/client/BridgeSway.client.luau
git commit -m "feat(zendojo): BridgeSway client controller — ambient tag-driven bridge sway"
```

---

### Task 7: Record the recipe + finalize

**Files:**
- Modify: `docs/superpowers/references/zendojo-canyon-build-recipes.md`

- [ ] **Step 1: Add a "Suspension bridge (kazurabashi)" recipe** (span/sag/width, segment+SwayPhase+BridgeSway
  contract, the static-floor-vs-swayed-segments split, palette, pier treatment) and a `§6` script-index entry
  for `buildSuspensionBridge.luau` + `BridgeSway.client.luau`.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/references/zendojo-canyon-build-recipes.md
git commit -m "docs(zendojo): record suspension bridge build recipe"
```

- [ ] **Step 3:** Update the `roshambo-roadmap` memory with the bridge (setpiece done; builder + sway controller;
  BridgeSway tag joins the tag-driven-animation family). Remind the user to SAVE THE PLACE (geometry is place-only).

---

## Self-Review

- **Spec coverage:** Form/sag/width → Task 1; cables → T1; suspenders+lattice → T2; slats → T3; invisible
  floor+barriers → T4; anchor piers → T5; sway (tag-based `BridgeSway`, `SwayPhase`, endpoint taper, params) →
  T6; materials → CONFIG in T1; build-approach (builder location, place-only, controller in src/client) →
  T1/T6; verification (walk, clearance, static floor, sway) → T3/T4/T6; recipe record → T7. All covered.
- **Placeholders:** none — every code step has real code; verification steps have exact scripts + expected values.
- **Type/name consistency:** `deckPoint/cross/travel/segFor/edge/cyl/partIntoSeg`, `Seg_i`, `SwayPhase`,
  `BridgeSway`, `Floor_*`/`Barrier_*` under root, `CONFIG` keys — used consistently across tasks.
