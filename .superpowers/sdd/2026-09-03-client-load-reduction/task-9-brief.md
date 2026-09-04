### Task 9: Teahouse `Persistent` — investigate, then decide by rule

**Files:**
- Investigate: `roblox/src/server/TreatmentApplier.luau:154-156`
- Investigate (read-only): `roblox/src/client/TeahouseController.client.luau`, `DecorationController.client.luau`, `EconomyController.client.luau`, `ShojiController.client.luau`, `roblox/src/shared/ShojiRun.luau`
- Modify: `roblox/src/server/TreatmentApplier.luau` — **only if step 2 clears it**

**Interfaces:**
- Consumes: nothing.
- Produces: nothing other tasks depend on. This task may correctly end in no code change at all.

Every materialized teahouse is marked `ModelStreamingMode.Persistent`, so it never streams out for any client. The cost scales with occupied pads across the whole server, for every player, uncapped by distance — the largest potential memory win here and the only change in this plan that could break other people's teahouses. The stage does this for a documented reason (`main.server.luau:123-127`: spawn-watchers 200 studs out, and controllers that capture parts once at startup). Teahouses are built at runtime, after those controllers have started, so that justification does not obviously transfer — but nothing in the file or the wiki says why the line is there.

⚠ **This is an investigation with a decision rule, not a predetermined edit.** A guess here is worse than the status quo: the status quo is merely expensive, and a wrong guess breaks structures other players own.

- [ ] **Step 1: Find every dependency on a distant teahouse's parts**

```bash
cd roblox
grep -rn "WaitForChild" src/client/TeahouseController.client.luau src/client/DecorationController.client.luau src/client/ShojiController.client.luau src/client/EconomyController.client.luau
grep -rn "Structure\|teahouse\|Teahouse" src/client/*.luau | grep -i "waitforchild\|findfirstchild\|getchildren\|descendant"
```

Write down, for each hit: does it act on the local player's **own** structure, on **any** structure, or on a structure it found by tag or attribute? A controller that only ever touches the player's own pad is not a blocker; one that walks every structure in the world at startup is.

- [ ] **Step 2: Apply the decision rule**

Exactly one of these, and record which in the commit message:

1. **Nothing depends on a distant teahouse's parts** → delete the three lines at `:154-156` and let teahouses stream like the rest of the far canyon.
2. **Something does** → narrow persistence rather than removing it: keep `Persistent` for the structure on the claiming player's own pad, drop it for everyone else's. Record in a comment what forced this.
3. **Neither can be established with confidence** → **change nothing.** Add a comment at `:154-156` recording what was checked and what remains unknown, and carry the finding to the phase-2 spec.

- [ ] **Step 3: If a change was made, verify with two clients**

Studio, two-player local test: both players claim pads, then walk one player far from the other's teahouse and back. Confirm the structure reappears intact, its shoji still slide via their `ProximityPrompt`, and its decorations are still present. If any of that fails, revert to outcome 3 rather than patching around it.

- [ ] **Step 4: Commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/server/TreatmentApplier.luau
git commit -m "perf(server): <what you actually did, naming the decision-rule outcome>"
```

If the outcome was 3 and nothing changed but the comment, say so plainly in the message — a recorded non-change is a result, not a failure.

---

## After the tasks

- [ ] **Push, and watch CI go green.** A push is not done until its run is seen green.
- [ ] **Hand the owner the walk list**, which is the real gate for this plan:
  - the waterwheel, watched from the arena and from behind, for a frozen shadow or a stale phase;
  - the bonshō — does it still ring while you are looking away from it;
  - the machiya row, for noren that visibly start moving as they come into view;
  - a teahouse chōchin at arm's length, confirming the remaining sway is intact;
  - a path chōchin, confirming it is now still and that the round glyph on it still changes;
  - the canyon paths at speed, for content popping in at the edge of view (`StreamTargetRadius`);
  - the stats room, in and out, for boards that blank too early.
- [ ] **Tune live and record.** `AmbientRadius`, `AmbientBehindDot`, `AmbientHz`, `StreamMinRadius`, `StreamTargetRadius` are all `Workspace` attributes. Whatever lands goes into `docs/wiki/world/place-state.md`, and the day's entry goes into `docs/wiki/log.md`.
