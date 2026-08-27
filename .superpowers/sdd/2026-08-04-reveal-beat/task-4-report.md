# Task 4 report — the ring's glyph becomes a fadeable group

Commit `1f0a3f5` — `feat(roblox): the ring's glyph fades, and stops hiding behind its own disc`.
One file touched: `roblox/src/client/HudController.client.luau` (+60 / −26). Not pushed.

## What changed

1. **Require added** (line 55): `local RevealBeat = require(shared:WaitForChild("RevealBeat"))`,
   beside the other `src/shared` requires (`RingTimer` is the line above it).

2. **The ring's glyph block** (lines 1280–1305) now builds `CanvasGroup`s via
   `Glyphs.renderGroup(box, sym, INK_CREAM, Color3.new(1, 1, 1))` instead of `Glyphs.render`'s bare
   frame. The hand-lifted per-`ImageLabel` ZIndex loop (this morning's stopgap) is deleted; the
   group carries `ZIndex = 5`, `GroupTransparency = 1`, `Visible = false`. The verbatim comment
   from the brief is in place, including the paragraph on the explicit outline colour.

3. **`setRingGlyph`** (lines 1548–1579), verbatim from the brief, with its three latch locals
   (`shownGlyph`, `glyphFading`, `glyphTween`) declared immediately above it, and immediately below
   `countersSeeded` — i.e. inside the existing "Render" block of module state, above `render`.

4. **The swap in `render`** (line 1705) is now `setRingGlyph(worldThrow, aux.worldThrowFading == true)`,
   replacing the three-line `Visible` loop.

5. Two comment updates, no behaviour: the file-header `aux` contract now lists
   `worldThrowFading = boolean?` and says absent means not fading; the glyph-swap comment in
   `render` now says the going is a fade owned by `setRingGlyph`, latched because `render` is 10Hz.

## Gate output

From `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`:

```
lune run tests/run   -> 984 passed, 0 failed, 984 total
stylua --check src tests tools -> clean (no output)
selene src tools     -> 0 errors, 0 warnings, 0 parse errors
```

(The `[WARN] [QUEUE] dropping request` / `handler error ... boom` lines in the test output are
`tests/HandlerQueue.spec`'s own deliberate fixtures, present before this change.)

No gate loads this file — `tests/run` never requires a `.client.luau` — so the gates prove only
that nothing else broke. The checks below are the real review.

## Step 3, the standing check, item by item

**1. Every `RevealBeat.X` and `aux.X` read resolves.**

- `RevealBeat.FADE_SECONDS` — exists, `src/shared/RevealBeat.luau:25`, value `0.4`. It is the only
  `RevealBeat` member this file reads.
- `RevealBeat` itself resolves at runtime: `default.project.json:10` maps `src/shared` to
  `ReplicatedStorage.RoshamboShared`, so `RevealBeat.luau` is a child of the folder the file
  already does `WaitForChild` on.
- `aux.worldThrow` — already produced by the wiring (`main.client.luau:259`, `worldThrow = revealedWorldThrow`).
- `aux.worldThrowFading` — **expected-missing until Task 5.** `main.client.luau` does not set it
  today, so it reads `nil`. The call site is `aux.worldThrowFading == true`, so `nil` is `false`:
  until Task 5 lands, the glyph appears at `GroupTransparency = 0` and is hidden by the `Visible`
  swap when `worldThrow` goes `nil` — i.e. exactly today's behaviour, no fade, no regression. This
  is the interface note from the brief, not a defect.

**2. Declared above first use** (line numbers as committed):

| name | declared | first use |
| --- | --- | --- |
| `TweenService` | 46 | 1571 (`TweenService:Create`) |
| `RevealBeat` | 55 | 1573 (`RevealBeat.FADE_SECONDS`) |
| `THROWS` | 89 | 186 (`glyphSet`); in the new code, 1281 and 1563 |
| `glyphBox` | 170 | 184; for the ring, 1282 |
| `ringGlyphs` | 1280 | 1303 (assignment), then 1564/1569 inside `setRingGlyph` |
| `setRingGlyph` | 1554 | 1705, inside `render` (declared 1582) |
| `shownGlyph` / `glyphFading` / `glyphTween` | 1550 / 1551 / 1552 | 1555 / 1555 / 1559 |

Every one is a `local` that lexically precedes its use; nothing resolves to a global.

**3. `ringGlyphs` typed `CanvasGroup`.** `grep -rn ringGlyphs src tests tools` returns exactly four
lines, all in this file: the declaration (1280, now `{ [string]: CanvasGroup }`) and three
subscripted uses (1303, 1564, 1569) that carry no annotation of their own. No stale `Frame`
remains for this table. The two other `Frame` annotations in the file — `glyphBox`'s return (170)
and `glyphSet`'s `{ [string]: Frame }` (185) — are the **tape tiles**, which still use
`Glyphs.render` and genuinely still return `Frame`; they are correct and untouched.

**4. The group's `ZIndex` is set.** Line 1301, `g.ZIndex = 5`, on the `CanvasGroup` itself.

**5. Nothing else in the ring moved.** The full diff is the five items listed above; `git diff`
shows no hunk in the pie block. Verified unchanged: `ringCircle(RING_OD, RING_TRACK, 1, "Track")`,
`SweepA` 2, `SweepB` 3, `ringDisc` at ZIndex 4 with `BackgroundTransparency = 0`, `ringCount.ZIndex = 5`,
`COUNT_NUDGE`, and `box.ZIndex = 5` on the glyph box.

## What actually composites, in order

`Visible = true` is not pixels, so here is the paint order rather than the flags.

The ScreenGui is `Instance.new("ScreenGui")` with `ZIndexBehavior` never assigned — so **Global**.
Under Global there is no parent-child precedence at all: every element in the gui is sorted by its
own `ZIndex` against every other, and ties are undefined. Within the ring, back to front:

1. `Track` — ZIndex 1, opaque `RING_TRACK`.
2. `SweepA` — ZIndex 2, half-disc.
3. `SweepB` — ZIndex 3, half-disc painting back over A.
4. `Disc` — ZIndex 4, `WASHI` at `BackgroundTransparency = 0`. **Opaque.** This is what buried the
   old glyph: `Glyphs.render` built its root frame and both `ImageLabel`s at the default ZIndex 1,
   so all three sorted *below* 4 and the disc painted straight over them. `ringCount` survived only
   because it sets `ZIndex = 5` on itself, which is precisely what made the bug look like "the
   glyph is broken" rather than "the disc is in front".
5. `GlyphBox` — ZIndex 5, `BackgroundTransparency = 1`: it paints no pixels; it exists only to
   inset and centre. Its ZIndex is therefore inert to the fix, which was the trap.
6. The three glyph `CanvasGroup`s — ZIndex 5. **A `CanvasGroup` renders its descendants into an
   offscreen buffer and then draws that buffer as a single element at its own ZIndex.** The two
   `ImageLabel`s inside are still at the default ZIndex 1, and that is now irrelevant: they are not
   sorted against the gui at all, only against each other inside the buffer (outline parented
   first, core second — `Glyphs.luau:103–104` — so the core sits in front of its keyline, which is
   the whole point of the two-layer glyph). The buffer composites at 5, above the ZIndex-4 disc.
   That is why the hand-lifted layer ZIndexes are safe to delete rather than merely redundant.
7. `ringCount` — ZIndex 5, same as the groups. A tie under Global is undefined order, but it never
   matters: `render` sets `ringCount.Visible = worldThrow == nil` and `setRingGlyph` shows a glyph
   only when `symbol ~= nil`, so the digits and the glyph are strictly mutually exclusive and never
   coexist as painted pixels.

Transparency, separately from order: the groups are constructed at `GroupTransparency = 1`, so a
group that were ever shown without going through `setRingGlyph` would be invisible. Nothing shows
one that way — the only writer of `.Visible` on these instances is `setRingGlyph`, and every path
in it that leaves a group visible also writes `GroupTransparency` (`0` on arrival, or a tween
toward `1` on the way out). So "visible" and "opaque" are set together, which is the property the
old code lacked.

Latching: `render` fires on every `EventBus.HudState`, 10Hz. `setRingGlyph` returns early unless
the `(symbol, fading)` pair actually changed, so across a hold the tween is created exactly once
and runs its full `FADE_SECONDS`. Without the latch it would be cancelled and recreated ~4 times
per rendered frame of its own travel and would look frozen — the failure mode the brief names.

## Concerns

1. **`aux.worldThrowFading` is nil until Task 5** (expected, per the brief's interface note). Until
   then the fade branch is dead code and the glyph still leaves by a `Visible` toggle. Nothing in
   this task can demonstrate the fade; the Studio gate for it belongs to the round, after Task 5.
2. **`Tween:Cancel()` leaves the property where it stopped.** If `worldThrow` drops to `nil`
   mid-fade, the group is hidden at, say, `GroupTransparency = 0.6`. That is not observable —
   `setRingGlyph` writes `GroupTransparency = 0` on every non-fading arrival, so the stale value is
   always overwritten before the group is shown again. Worth knowing if anyone later adds a path
   that shows a group without going through `setRingGlyph`.
3. **Global `ZIndexBehavior` is still wrong file-wide**, deliberately untouched per the brief. This
   change removes the ring glyph from the blast radius (a `CanvasGroup` is correct under either
   behaviour), but the same trap is live for anything else in this gui that relies on parent-child
   precedence. It wants its own pass.
4. **No automated gate can see any of this.** The three gates prove the file parses, formats and
   lints; the glyph's appearance is only verifiable at a Studio gate. In particular, the outline
   colour — passed explicitly as `Color3.new(1, 1, 1)` — would silently collapse the keyline into
   the cream core if it were ever dropped, and nothing would fail.
