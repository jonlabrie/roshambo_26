---
shelf: practice
updated: 2026-08-15
checked: 2026-08-31
---

# Visible Is Not Pixels

Standing rule: reading `Visible`/opacity/enabled off a Roblox instance is NOT evidence
it renders. *"The property says so"* is not *"the user sees it."*

## The incident

**A Roblox UI element can be `Visible = true`, correctly sized, fully opaque, with a
loaded image, and render nothing at all.** On 2026-08-04 a HUD glyph probe read all
those properties back and was reported working. The owner had watched several rounds
and saw only a black disc. They were right; the probe measured the wrong thing.

**Why:** `Instance.new("ScreenGui")` defaults `ZIndexBehavior` to **`Global`**, not
`Sibling`. Studio's *insert* action sets Sibling; scripts do not. Under Global, ZIndex
is compared across the whole ScreenGui and **a child does NOT draw above its parent** —
a ZIndex-1 image inside a ZIndex-4 opaque parent is simply hidden. Setting the
*container's* ZIndex does not propagate to what's inside it.

## How to check it properly

- prove the assets load — `ContentProvider:PreloadAsync` + `IsLoaded` (works in Edit)
- enumerate the actual render order: every element's ZIndex, its parent chain, and
  which ones are opaque
- read `ZIndexBehavior` rather than assuming; a comment claiming "Sibling" is not
  evidence
- best: force the element on and **look at it**

## Do NOT reach for a CanvasGroup here

**This rule originally recommended one and it was wrong.** A `CanvasGroup` was used for
the ring's glyph — it looked ideal (rasterises descendants into one buffer, so only its
own ZIndex participates in the global sort, and one `GroupTransparency` fades it).
**It rendered nothing at all**, for several more rounds of work, while reporting
`Visible = true`, `GroupTransparency = 0` and a correct `AbsoluteSize`.

The isolating test that finally settled it, and the shape to copy for this class of
bug: **two probes built in the SAME call — same parent, size, position, ZIndex and
assets — differing in exactly one thing.** One from `Glyphs.render` (plain Frame + two
ImageLabels), one from `Glyphs.renderGroup` (CanvasGroup). The plain one drew; the
CanvasGroup drew nothing. Whatever the limitation is (offscreen-buffer budget, nesting,
driver), **no property on a CanvasGroup admits it** — which is why every instrumented
check said the glyph was fine.

**So: plain `Frame` + `ImageLabel`s, with ZIndex lifted on the root AND each layer**
(Global ZIndexBehavior means a child does not draw above its parent). Fade by tweening
both layers on identical `TweenInfo` started on the same frame — the drift
`renderGroup` exists to prevent comes from different curves or start times, not from
there being two tweens.

Watch the related trap: `Glyphs.render` defaults its outline to WHITE, `renderGroup`
to the CORE colour, so swapping builders without passing the outline explicitly
silently flattens the art.

## The general form, which cost more than the bug

No gate in this repo loads a `.client.luau`, so nothing automated can see any of it. A
reviewer asserted Sibling, it got recorded as verified, and the regression shipped
through several rounds of review with every test green. Same class as green tests not
meaning working software. When someone reports not seeing something, believe the report
over the instrumentation, and go find what the instrumentation is failing to measure.

Related: [[round-and-hud]] carries the HUD chain this came from;
[[perf-harness-contamination]] and [[duplicated-server-constants]] are the same family
of error — reading a property, or a number, and believing it describes what is
actually happening. A related far-distance trap: a SurfaceGui CanvasGroup at
`GroupTransparency=1` still DRAWS beyond ~120 studs (the far SurfaceGui path skips
group compositing) — when a fade completes, flip `Visible=false` (a true render-off);
`Transparency=1` on a BasePart is a true skip. Debug tip: a culled thing can't ECLIPSE
what's behind it — if a dark shape occludes, it's being drawn.
