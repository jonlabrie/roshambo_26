### Task 7: Streaming radii

**Files:**
- Modify: `roblox/src/server/main.server.luau:141-143` (immediately after the `StagePersistence` loop)

**Interfaces:**
- Consumes: nothing.
- Produces: `Workspace` attributes `StreamMinRadius` and `StreamTargetRadius`, readable in the Explorer during a walk.

Nothing in git has ever set these; the place runs on engine defaults (min 64, target 1024). Setting them from the server at boot puts them in git and makes them self-healing, which is the same treatment `ArenaSpawn` and stage persistence already get.

- [ ] **Step 1: Set the radii at boot**

Insert after the `for _, model in StagePersistence.persistTargets(persistRoots) do ... end` loop:

```lua
-- STREAMING RADII, code-owned rather than left as place data. Nothing in git had ever set these and
-- the place ran on the engine defaults (min 64, target 1024). The stage and the horizon backdrop are
-- Persistent and unaffected; what tightens is the far canyon -- PathRailings (5,186 descendants),
-- PathLanterns (2,599), foliage -- which is precisely the bulk a low-end phone is carrying.
--
-- ⚠ THE TARGET IS AN OWNER-TUNED NUMBER, not a computed one. The canyon has long sightlines and the
-- failure mode is content popping in at the edge of view, which no test can see. Published as
-- attributes so it can be turned during a walk; record what lands in docs/wiki/world/place-state.md.
local STREAM_MIN, STREAM_TARGET = 64, 512
workspace.StreamingMinRadius = STREAM_MIN
workspace.StreamingTargetRadius = STREAM_TARGET
workspace:SetAttribute("StreamMinRadius", STREAM_MIN)
workspace:SetAttribute("StreamTargetRadius", STREAM_TARGET)
```

- [ ] **Step 2: Verify it applies**

Studio, Play, check `Workspace`'s properties: `StreamingTargetRadius` reads 512. If assigning it errors, `StreamingEnabled` is off in the place — stop and report, because three separate code comments assert it is on and that contradiction needs the owner, not a workaround.

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/server/main.server.luau
git commit -m "perf(server): own the streaming radii in code instead of engine defaults"
```

---

