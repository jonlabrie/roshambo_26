# Task 2 report — ChochinSway: path poles stop swaying, the rest get culled

## Status: DONE

## Commit
`c88690b` — perf(client): path chochin stop swaying; the rest animate only in view

## What changed

`roblox/src/client/ChochinSway.client.luau` (whole file rewritten per the brief, with the two
owner corrections applied):

1. **`hangPointFor` → `isPoleHung`.** Deleted the cross-arm-derived hang-point function and its
   comment block; replaced with the `isPoleHung(m: Model): boolean` predicate, verbatim from the
   brief including the full history comment (WorldPivot/cross-arm drift bug, 3.4-stud float,
   "in git if it is ever needed again").
2. **Early return in `add()`.** `isPoleHung(m)` is checked immediately after the `IsA("Model")`
   guard, before the duplicate scan over `entries` — a pole lantern cannot enter `entries` by any
   path. The old `WorldPivot` assignment and its comment are gone with the function it depended on.
3. **Config source.** Per the owner's corrections, did NOT add local `num()`/`cfg()` helpers.
   Instead required both modules through `ReplicatedStorage.RoshamboShared` (`AmbientBudget`) and
   `script.Parent` (`AmbientConfig`, the sibling client module from Task 1). `AmbientConfig.get()`
   is called exactly once per `Heartbeat`, assigned to local `c`, never inside the per-lantern
   loop.
4. **Culled Heartbeat loop.** Matches the brief's Step 4 verbatim except for the config call: a
   fixed-interval accumulator (`AmbientBudget.step`) gates the whole per-frame walk; for lanterns
   that fire, distance-squared range test (`AmbientBudget.inRange`) runs before the `math.sqrt`,
   then a forward-dot in-view test (`AmbientBudget.inView`) before any `PivotTo`. Pose remains a
   pure function of `os.clock()`, so culled lanterns resume at the correct phase with no reset
   logic needed.
5. **Header rewrite.** First paragraph now describes the file as animating the teahouse and
   hanabiya chōchin, notes path poles are excluded by owner ruling (pointing at `isPoleHung`), and
   keeps the existing clause that the swinging body carries the RoundLantern glyph.

No amplitude, speed, phase, or colour values were touched — `AMP` and `SPEED` constants and the
sine/cross-axis-drift math are byte-for-byte what they were before.

## Gates run (from `roblox/`)

```
stylua src tests tools   → 0 errors, 0 warnings, 0 parse errors
selene src tools         → clean
lune run tests/run       → 1844 passed, 0 failed, 1844 total
rojo build -o /tmp/build.rbxl → succeeded
```

The two `[WARN]` lines in the `lune run` output (`HandlerQueue.spec`, "dropping request for u:
queue full" / "handler error for u: ... boom") are expected stderr from that spec's own
fault-injection test cases, not failures — final tally is 1844/1844 passed.

## Test summary
1844/1844 Lune tests passed (no new tests added — no harness in this repo can load a
`.client.luau` file, consistent with why the policy math lives in the already-tested
`AmbientBudget` module).

## Concerns
None. Did not touch `buildChochinPole.luau`, `buildTeahouseChochin.luau`, or
`buildHanabiyaChochin.luau` (per the brief: un-tagging belongs to the builders' job, not this
task's). Did not touch `roblox/assets/*.model.json`. No subagents were dispatched.
