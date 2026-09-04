# Task 5 report: HammerController split timing from rendering

## Status: DONE_WITH_CONCERNS

(Concern is only the owner-required Studio play-test, which per instructions I skipped — see below.)

## Commit

`41fe7f8` — perf(client): bell engine splits timing from rendering; only the CFrames are culled

## What was done

Modified `roblox/src/client/HammerController.client.luau` per the brief, with the owner's
correction (used `AmbientBudget`/`AmbientConfig.get()` instead of local `num()`/`cfg()` helpers):

1. Added requires: `AmbientBudget` (`ReplicatedStorage/RoshamboShared/AmbientBudget`) and
   `AmbientConfig` (`script.Parent/AmbientConfig`).
2. Added shared `machineDrawable(c)` helper, anchored on `arm` (the ShuMoku), used by all
   three loops.
3. **Draw loop** (`:355` orig): added `drawAcc`, `dt` param, gate as the first statement
   (before the `DrawHold` read), unchanged otherwise.
4. **Cam/driver/jack loop** (`:398` orig): added `dt` param. Hoisted `driverDir` read and
   the `stage:SetAttribute("DriveOmega", ...)` write to just above the gate, immediately
   after the `camNet` computation — everything from `captureSpinners()` retry through the
   `DriveOmega` write remains unconditional every frame. Only the three CFrame write loops
   (cam spinners, driver spinners, jack spinners) sit behind
   `AmbientBudget.step` + `machineDrawable`.
5. **Suspension loop** (`:457` orig): added `suspAcc`, `dt` param, gated call to
   `updateSuspension()`.

## Self-check (per brief instructions)

Ran `git diff` on the file before committing. Confirmed the only changes are:
(a) the two added requires, (b) the added `machineDrawable` helper, (c) three added
accumulators (`drawAcc`/`spinAcc`/`suspAcc`) and their gates, (d) `dt` parameters added to
all three Heartbeat callbacks, (e) `driverDir` + `DriveOmega` hoisted above the gate in the
middle loop (with the explanatory comment split accordingly — no logic moved). Nothing else
in the timing half changed.

## Gates run (all green)

```
cd roblox
stylua src tests tools          # ran clean; only HammerController.client.luau touched
selene src tools                 # 0 errors, 0 warnings, 0 parse errors
lune run tests/run               # 1844 passed, 0 failed, 1844 total
rojo build -o /tmp/build.rbxl    # built successfully
```

`git status` after `stylua` confirmed no other file was reformatted.

## Outstanding

**Step 5 (Studio play-test) was skipped as instructed** — no harness here can load a
`.client.luau` or drive Roblox Studio's Play mode. This is on the owner's walk list: walk
behind the drum so the bonshō machine is out of view and confirm (a) the bell still strikes
on schedule (audio/console) and (b) `RoshamboStage.DriveOmega` keeps changing live in the
Explorer while the machine is culled.

## Concerns

None beyond the outstanding Studio verification. The diff is minimal and matches the brief's
Step 3 code literally; `DriveOmega` publish is confirmed unconditional (it precedes the gate
in source order), and the strike-detection/backstop logic is untouched and unconditional.

---

## Review round 1 fix

## Status: DONE_WITH_CONCERNS (same outstanding item as above)

## Commit

`e57f7e7` — fix(client): refresh dowel pose + suspension before strike, not just when drawable

## The finding

Round 1 review of `41fe7f8` approved the split (spec, quality, all four traced failure modes,
and the `DriveOmega` hoist specifically confirmed correct) but found one Important regression:
`strike()` (`:314-316` at review time) samples `dowels[1].Position` to compute `anchorNet`.
`dowels[1]` is written only by `updateSuspension`, now behind the suspension gate; the arm it
hangs from is posed only by the now-gated draw loop. `strike()` itself still runs
unconditionally from the middle loop. So a culled machine strikes against a frozen (or, before
the first `updateSuspension` call ever ran, built-rest-pose) dowel, pinning the cam's high
point tens of degrees out of phase with the log — self-healing at the next strike the player
watches, but a real regression introduced by the split (previously `updateSuspension` ran every
frame unconditionally).

## Fix applied

Applied exactly the call-site fix specified by the reviewer/coordinator, no reordering of
existing code:

1. Extracted the arm-posing math out of the draw loop into `local function poseArm(p: number)`,
   declared immediately above the draw loop (right after `DRAW_STUDS`). The draw loop now calls
   `poseArm(p)` in place of the three lines that used to inline it — behaviour identical.
2. In the middle loop, inside the `strikesBetween(...) > 0` branch, added
   `poseArm(r.drawP)` and `updateSuspension()` immediately before `strike(r.prevStrikeAt)`, with
   a comment explaining why the refresh is needed and why it's cheap enough (once per round) to
   need no gate. `strike()` itself and `DRAW_STUDS` were not moved.

## Gates run (all green)

```
cd roblox
stylua src tests tools           # ran clean; only HammerController.client.luau touched
selene src tools                  # 0 errors, 0 warnings, 0 parse errors
lune run tests/run                # 1844 passed, 0 failed, 1844 total
rojo build -o /tmp/build.rbxl     # built successfully (902715 bytes)
```

## Diff verification

`git diff 41fe7f8 -- roblox/src/client/HammerController.client.luau` shows exactly three
hunks: the extracted `poseArm` function, the draw loop's three inline lines replaced by
`poseArm(p)`, and the three added lines (`poseArm(r.drawP)`, `updateSuspension()`, plus
explanatory comment) immediately before `strike(r.prevStrikeAt)` in the middle loop. Nothing
else changed.

## Concerns

Same as before: the Studio play-test (Step 5) remains outstanding — no harness here can drive
Roblox Studio. Worth adding to that walk-test: after the fix, confirm the cam's high point
still lands on the dowel correctly for a strike that occurs while the player has been looking
away the whole round (the exact scenario the review's repro described).
