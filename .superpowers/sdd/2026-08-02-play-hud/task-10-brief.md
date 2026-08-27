### Task 10: `HudController` — minimal, and retire the old UI

The swap. `HudController` renders `HudModel`; `main.client.luau` loses every `Instance.new` and
keeps only remote wiring and the drum-rest spoiler gate. Both happen in one commit — shipping
`HudController` while the old HUD still builds itself would put two HUDs on screen.

**Files:**
- Create: `roblox/src/client/HudController.client.luau`
- Modify: `roblox/src/client/EventBus.luau:4`
- Modify: `roblox/src/client/main.client.luau` (strip to wiring)

**Interfaces:**
- Consumes: `HudModel`, `Glyphs`.
- Produces: EventBus channels `HudState` (fired with `HudModel.Inputs`), `HudPick` (client→wiring, the chosen throw), `Toast` (transient minimal notice).

- [ ] **Step 1: Add the EventBus channels**

```luau
local NAMES = { "Cue", "TickerMessage", "MoveTeahouse", "MoveDecoration", "DayNight",
    "HudState", "HudPick", "HudResolve", "Toast", "OpenLedger", "Onboard" }
```

- [ ] **Step 2: Build `HudController`**

Layout, from the approved design:

- **Plate** — top-centre, `AnchorPoint (0.5, 0)`, `Position UDim2.new(0.5, 0, 0, 12)`. Three cells
  (STREAK / POT / POINTS). It is a `TextButton` (the only interactive information element —
  it is the door to maximal) firing `EventBus.OpenLedger`.
- **Throw area** — bottom-right, `AnchorPoint (1, 1)`, `Position UDim2.new(1, -<jump clearance>, 1, -12)`.
  Tape row **above** three throw buttons. Glyphs via `Glyphs.render(button, sym, INK)`.
- **Timer** — a `Frame` hairline pinned to the bottom edge, width scaled to `secondsLeft`.
- **Escalation** — a large centred `TextLabel`, `Active = false`, shown when `view.escalate`.

Non-negotiable in this file:

```luau
-- Every information element MUST stay Active = false. Frames and labels default to false, but
-- setting it true anywhere here punches a permanent hole in the camera-drag surface, which is
-- the whole right side of the screen on touch. Only the three throw buttons, the two choice
-- buttons and the plate may sink input.
```

Right-edge clearance: the Roblox jump button occupies roughly the right 3–13% of the screen.
Anchor the throw area inboard of it and verify in the device emulator (Task 15) — do not
hand-tune pixel offsets before seeing it on a real aspect ratio.

- [ ] **Step 3: Strip `main.client.luau`**

Delete every `Instance.new` UI construction, the `GLYPH`/`BTN_GLYPH` tables, the palette
constants now owned by `HudController`, and both `ScreenGui`s. **Keep**: the remote requires,
the `tape`/`badgeById`/`currentRoundId`/`revealedRoundId` state, `renderHistory`'s
*spoiler-gating logic* (recast to fire `EventBus.HudState` rather than paint tiles), the
`pendingReveal`/`drumAtRest`/`maybeShowReveal` machinery, and the 3-second safety `task.delay`.

The spoiler gate is subtle and currently correct — a reveal must not paint until the drum
settles. Do not re-derive it; move it.

Add a `HudModel.Session` held here, advanced on every round end:

```luau
local session = HudModel.newSession()

-- couldThrow mirrors the server's own refusal conditions: a round the player was refused is not
-- a round they ignored.
local function roundEnded(couldThrow: boolean, picked: boolean)
    session = HudModel.onRoundEnded(session, { couldThrow = couldThrow, picked = picked })
end
```

- [ ] **Step 4: Verify in Studio**

Connect Rojo, enter Play. Confirm: exactly one HUD on screen; plate top-centre; throws
bottom-right clear of the jump button; tape above the throws with the real glyph shapes; timer
hairline depletes; tapping a throw still submits (watch the server `[PICK]` print).

- [ ] **Step 5: Run the gates and commit**

```bash
stylua --check src tests tools && selene src tools
lune run tests/run
git add roblox/src/client/HudController.client.luau roblox/src/client/EventBus.luau roblox/src/client/main.client.luau
git commit -m "feat(roblox): HudController replaces the provisional play UI"
```

---

