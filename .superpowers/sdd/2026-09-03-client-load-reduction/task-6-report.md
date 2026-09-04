# Task 6 report: the two proximity loops

## Status: DONE

## Commit
`6830823` — perf(client): proximity tests poll at 4Hz; the gate fade keeps its frame dt
(2 files changed, 46 insertions(+), 18 deletions(-))

## What was done

Both files require `AmbientBudget` via the corrected path
(`ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget")`, which in
`ShopController.client.luau` reuses the existing `shared` local since it already equals that
lookup). Neither file requires `AmbientConfig`; both use a local `POLL = 0.25` and call only
`AmbientBudget.step`.

1. **`ShopController.client.luau`** — converted wholesale. The `RunService.Heartbeat` body (the
   box inside/outside test, `dismissed`/`setOpen` state transitions) now runs behind
   `AmbientBudget.step(acc, dt, POLL)`, returning early when `fire` is false.

2. **`AccessGateController.client.luau`** — split, not converted:
   - Added `near: boolean` to the `Pad` type declaration (~line 32) and initialised it `false`
     in the pad entry built in `rebuild()` (~line 93), beside `collidable = false`.
   - The O(pads) planar (X/Z) distance test is now gated behind `AmbientBudget.step`, writing
     its result to `pad.near` each time it fires. Collision (`part.CanCollide`) still snaps
     immediately off the cached `pad.near`/`pad.collidable` comparison, inside the throttled
     branch.
   - The alpha fade loop (`pad.alpha += (target - pad.alpha) * math.clamp(dt * FADE_RATE, 0, 1)`)
     was moved to a second, unthrottled `for _, pad in pads` loop that runs every Heartbeat on
     the real frame `dt`, reading `pad.near` (not doing its own distance check). This preserves
     the frame-rate-coupled fade exactly as before.

## Gates run (from `roblox/`)

- `stylua src tests tools` — no diffs beyond the edits themselves.
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors.
- `lune run tests/run` — **1844 passed, 0 failed, 1844 total** (the `[WARN] QUEUE` lines are
  expected output from an existing `HandlerQueue.spec` fixture test, not new failures).
- `rojo build -o /tmp/build.rbxl` — built successfully.

## Notes

- Confirmed `AmbientBudget.step(acc, dt, interval)` signature matches the brief:
  `(boolean, number)`, remainder-carrying accumulator.
- Left the concurrently-modified `.superpowers/sdd/.gitignore`, `art/birds/uguisu/uguisu_authored.blend`,
  and the untracked `art/birds/uguisu/horizon meshes.blend` untouched and unstaged, per instructions —
  another session owns those.
- No subagents were dispatched.

## Concerns

None. Diff matches the brief's specified code exactly (aside from the corrected require path),
all gates green, only the two named files touched and committed together.
