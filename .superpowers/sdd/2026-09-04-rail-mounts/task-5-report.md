# Task 5 Report: FireworkController — flight along the heading

## Implementation per contract point

**1. `dir` computed once beside `origin` (line ~352-359):**
```lua
local origin = payload.origin
local dir = if payload.heading
    then Vector3.new(payload.heading.x, payload.heading.y, payload.heading.z).Unit
    else Vector3.new(0, 1, 0)
```

**2. Apex (line ~360-366):**
```lua
local scatterX = rng:NextNumber(-8, 8)
local heightJitter = rng:NextNumber(-6, 6)
local scatterZ = rng:NextNumber(-8, 8)
local apex = origin + dir * (60 + heightJitter) + Vector3.new(scatterX, 0, scatterZ)
```
**RNG draw order statement:** the original expression was
`Vector3.new(rng:NextNumber(-8,8), 60 + rng:NextNumber(-6,6), rng:NextNumber(-8,8))` — Lua/Luau
evaluates a function call's arguments left to right, so the stream order was **X-scatter, then
height-jitter, then Z-scatter**. The new code draws into `scatterX`, `heightJitter`, `scatterZ`
locals in that exact same order before assembling the vectors, so the rng stream consumed by
every downstream draw (bonusRoll already drawn before this point, boost rolls, sound-variant
picks after) is byte-identical to today's for every client, heading or not.

**Nil-heading equivalence:** with `dir = (0,1,0)`, `dir * (60 + heightJitter) = (0, 60+heightJitter, 0)`,
and adding `Vector3.new(scatterX, 0, scatterZ)` gives `(scatterX, 60+heightJitter, scatterZ)` —
exactly the old `Vector3.new(x, 60+height, z)`.

**3. Bonus (line ~384-391):**
```lua
apex = origin + (apex - origin) + dir * ((apex - origin):Dot(dir) * (BurstStyles.BONUS.apexScale - 1))
```
**Equivalence check:** with `dir = (0,1,0)`, `(apex-origin):Dot(dir) = apex.Y - origin.Y` (the
scatter's X/Z components don't project onto the vertical axis). Old code:
`origin + (apex-origin) * (1, apexScale, 1)`, i.e. Y-component becomes
`(apex.Y-origin.Y) * apexScale`, X/Z unchanged. New code's Y-component:
`(apex.Y-origin.Y) + 1*((apex.Y-origin.Y) * (apexScale-1)) = (apex.Y-origin.Y) * apexScale` —
identical. X/Z: `dir`'s X/Z components are 0, so the added term contributes nothing to X/Z,
leaving them at their pre-bonus scatter values, same as the old expression (which only ever
scaled the Y axis, never X/Z). So the two are byte-equivalent when `dir` is vertical, and for a
tilted `dir` the same law holds along the heading axis while lateral scatter is left alone, as
specified.

**4. Bezier control (line ~449-450):**
```lua
local run = (apex - origin):Dot(dir)
local control = origin + dir * (run * 0.9)
```
With vertical `dir`, `run = apex.Y - origin.Y` and `control = origin + (0, run*0.9, 0)` —
byte-equivalent to the old `origin + Vector3.new(0, (apex.Y - origin.Y) * 0.9, 0)`.

**5. Everything else unchanged.** Sound timing, muzzle flash at `origin`, trail, LOD, and slot
lifecycle code were not touched — verified below.

## Test/lint results

```
$ cd roblox && lune run tests/run
[WARN] [QUEUE] dropping request for u: queue full (8)     <- pre-existing expected test noise
[WARN] [QUEUE] handler error for u: .../HandlerQueue.spec:80: boom   <- pre-existing expected test noise
1652 passed, 0 failed, 1652 total

$ stylua --check src tests tools
(no output, exit 0)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```
`.client.luau` is untested by design (no dedicated flight-path unit test exists or was added,
per the task's constraint); the full 1652-test suite covering the rest of the codebase passes
unchanged.

## Files changed

- `roblox/src/client/FireworkController.client.luau` (1 file, 27 insertions, 9 deletions)

## Self-review: other uses of `apex`/`origin` for verticality assumptions

Grepped every use of `apex`, `origin`, `anchorPos`, and any `.Y`/hardcoded-vertical
`Vector3.new(0, …, 0)` in the file:

- `local anchorPos = if ev.anchor == "apex" then apex else origin` — opaque world position,
  used only for sound (`playSound`), particle CFrame offsets (`anchorPos + Vector3.new(...)`),
  and camera-distance magnitude checks. None assume a vertical relationship between `apex` and
  `origin`; they treat both as plain points. Unaffected by tilt.
- Muzzle flash (`fp.CFrame = CFrame.new(origin)`) and its particle `Acceleration = Vector3.new(0,
  -4, 0)` — this is world-down gravity on the flash sparks, not a heading-relative direction; by
  design sparks fall under real gravity regardless of which way the shell flies. Correctly
  unchanged.
- Burst-phase particle `Acceleration = Vector3.new(0, -4, 0)` / kamuro `(0, -28, 0)` — same
  world-down gravity for burst stars, independent of flight heading. Correctly unchanged; the
  brief's scope was the flight arc (apex/bonus/control), not burst-particle physics.
- LOD distance checks (`(cam.CFrame.Position - anchorPos).Magnitude`, and the payload-admission
  `(cam.CFrame.Position - payload.origin).Magnitude`) — plain Euclidean distance to a point,
  no verticality assumption.
- No other file location references `apex`, `origin`, or a hardcoded vertical axis tied to the
  flight math.

No stale verticality assumptions found outside the four formulas the brief named. Also updated
two comments (lines ~440-441, ~446-448) that described the bezier control point as "vertical at
the tube" — those were now misleading given a tilted heading is possible; reworded to describe
the control point as riding the heading, vertical being the no-heading default. This is a
comment-only change alongside the formula edits, not a new behavior.

## Concerns

None. The diff is surgical (three formula sites + two comment updates), the nil-heading path is
provably byte-identical to the pre-existing behavior (verified algebraically for both apex/bonus
and the bezier control), and the rng draw order is preserved by construction (three sequential
`rng:NextNumber` calls in the same order the old inline expression evaluated its arguments).
