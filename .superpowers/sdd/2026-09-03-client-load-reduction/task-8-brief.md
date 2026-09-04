### Task 8: Stats-room `MaxDistance`

**Files:**
- Modify: `roblox/src/client/FlapBoard.luau:173-179`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

The stats room holds roughly 8,400 GUI instances (about seven per flap cell) and none of them stop rendering when the player leaves. `StatsController.client.luau` is `FlapBoard`'s only caller and it returns early for `isRoundDisplay(id)` at `:257`, so a default set here reaches exactly the in-room wall boards and **cannot** touch the cavern round display. No new `Config` field is needed.

- [ ] **Step 1: Set the distance**

Add the constant beside the file's other top-level constants:

```lua
-- The wall boards live in an enclosed room and are read from a few studs away; nothing outside the
-- room can make out a flap. Without this they render from anywhere in the canyon -- ~8,400 GUI
-- instances at roughly seven per cell, and the A13 measured this room as costing what the whole
-- arena square costs (docs/wiki/world/stats-room.md, 2026-08-17).
--
-- FlapBoard's only caller is StatsController, which returns early for the round display, so this
-- reaches the wall boards and cannot reach the cavern display.
local BOARD_MAX_DISTANCE = 150
```

and in `buildFace`, after `gui.CanvasSize = ...`:

```lua
    gui.MaxDistance = BOARD_MAX_DISTANCE
```

- [ ] **Step 2: Verify in Studio**

Play, walk into the stats room and confirm every board still paints normally at reading distance. Then walk out to the arena square and confirm the boards go blank rather than rendering across the canyon. If a board blanks while still legible from inside the room, raise the constant — do not remove it.

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/FlapBoard.luau
git commit -m "perf(client): stats-room boards stop rendering from outside the room"
```

---

