### Task 1: Retract the early splash

**Files:**
- Modify: `roblox/src/shared/DrumStep.luau`
- Modify: `roblox/src/client/DrumController.client.luau`
- Modify: `roblox/src/client/main.client.luau`
- Modify: `roblox/tests/DrumStep.spec.luau`
- Modify: `roblox/src/client/EventBus.luau` (its `NAMES` comment describes the cue)

**Interfaces:**
- Consumes: nothing.
- Produces: `maybeShowReveal` becomes the single drum-rest gate again. Task 5 rebuilds on it.

**Context:** Round four fired the result splash ahead of `drumRest` — first at a fixed 0.7s lead, then refined to a residual-angle trigger. Both violate the rule. The refinement was precisely correct about a question that should never have been asked, which is why the spec records the retraction as a rule rather than a note.

- [ ] **Step 1: Delete the arithmetic**

In `roblox/src/shared/DrumStep.luau`, delete `SPLASH_RESIDUAL_RADIANS` and `glideResidual` together with their comment blocks.

**KEEP** `DrumStep.KICK_OMEGA` and the corrected Hermite characterisation in the header. Both were genuine improvements, independent of the retraction: the kick lived in a client file where a stage attribute could retune it with no test able to see it, and the header previously described a curve the module does not have. Add a line to the header recording that the glide's residual is no longer computed here and why — so the next person does not rebuild it.

- [ ] **Step 2: Delete the cue**

In `roblox/src/client/DrumController.client.luau`, delete:
- the `SPLASH_RESIDUAL` local
- the `settlingFired` latch **and both of its reset points** (beside `glideT0` where `mode = "glide"` is assigned, and in the `gongHit` handler)
- the `EventBus.Cue:Fire({ kind = "drumSettling" })` block inside the glide's still-travelling arm

`drumRest` is untouched. After this, `grep -rn "drumSettling" roblox/src roblox/tests` must return nothing.

Watch for a local left unused by the deletion — selene fails on warnings.

- [ ] **Step 3: Restore the single gate**

In `roblox/src/client/main.client.luau`:
- delete the `drumSettling` and `splashDone` locals
- delete `maybeShowSplash` and fold its `EventBus.Splash:Fire({...})` block back into `maybeShowReveal`, in the position it occupied before round four — after the badge/`revealedRoundId` assignments, guarded by `if p.result then`
- delete the `drumSettling` branch from the `EventBus.Cue` handler; `drumRest` sets only `drumAtRest` again
- delete the `drumSettling` / `splashDone` resets from the `RoundUpdate` handler
- the `REVEAL_SAFETY` fallback sets only `drumAtRest` again
- rewrite the "Two gates, not one" comment block: there is one gate, and it is `drumRest`

Task 5 will move the splash again — but to a different place for a different reason, and starting from the restored state keeps that diff honest.

- [ ] **Step 4: Delete the tests and fix the doc comment**

Remove the `SPLASH_RESIDUAL_RADIANS` / `glideResidual` describe block from `roblox/tests/DrumStep.spec.luau`. Keep every test covering `KICK_OMEGA`, `SETTLE_SECONDS` and the face arithmetic.

In `roblox/src/client/EventBus.luau`, correct the `"Splash"` entry in `NAMES` — it currently describes the `drumSettling` gate.

- [ ] **Step 5: Verify and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
grep -rn "drumSettling\|glideResidual\|SPLASH_RESIDUAL\|splashDone" roblox/src roblox/tests
```
Expected: no output.

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/DrumStep.luau roblox/src/client/DrumController.client.luau \
        roblox/src/client/main.client.luau roblox/tests/DrumStep.spec.luau roblox/src/client/EventBus.luau
git commit -m "revert(roblox): the drum is authoritative — the splash waits for rest"
```

---

