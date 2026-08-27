# Final fix wave: four Minor findings

Commit: `9a18224` — fix(roblox): four stale comments in the HUD round-three diff
Branch: m4b-zendojo-art-pass (not pushed)

## Findings addressed

1. **`roblox/src/shared/HudModel.luau:136`** — `undoPromptExpired`'s comment said
   "ample resolution for a one-second question"; changed to "two-second question"
   to match `HudModel.UNDO_PROMPT_SECONDS = 2`. Kept the point about the 10Hz
   heartbeat's resolution being the thing being justified.

2. **`roblox/src/client/HudController.client.luau:578-579, 610-615`** — the
   `undoLabel` sizing rationale cited the old pre-round pill's 36px/68px content
   boxes and a fixed 13px type size. Rewrote to state the real geometry: the pill
   is `BTN_W x BTN_H` with no padding, so the content boxes are 44px (touch,
   confirmed via `HudLayout.BTN_H_TOUCH = round(76 * 0.58) = 44`) and 76px
   (desktop, `HudLayout.BTN_H`), and the label is `TextScaled` capped at
   `MaxTextSize = 22`. Added a closing note that any future `MaxTextSize` change
   should be computed from these box widths, not the old pill's numbers. No
   values changed, only prose.

3. **`roblox/src/client/HudController.client.luau:659-669`** — `paintThrows`'
   `prompted` branch comment described a visible lift-out-of-dim effect that is
   actually fully occluded by the opaque `undoPill` (same rect, same ZIndex,
   plus its own `SEL_BLUE` stroke) every time it runs, since `paintThrows` and
   `setUndoPrompt` are always driven by the same value in the same `render`
   pass. Branch left intact (not deleted per instruction) — it's the correct
   fallback for a smaller/translucent pill. Comment now states it is currently
   invisible, why, that it's a fallback, and that nobody has seen it painted
   since 2026-08-02, with a pointer for anyone shrinking the pill to check this
   paint first.

4. **`roblox/src/client/HudController.client.luau:992-994` (now ~1004-1006)** —
   the three `RoundRing` layers were unnamed `Frame`s. Added an optional `name:
   string?` parameter to `ringCircle` (and threaded through `ringHalf`, which
   calls it), then named the three instances `Track`, `SweepA`, `SweepB` at
   their construction sites. `Disc` was already named. No geometry, color,
   ZIndex, or transparency changed.

## Verification

- `lune run tests/run` — 970 passed, 0 failed (from `roblox/`)
- `stylua --check src tests tools` — 0 errors, 0 warnings, 0 parse errors
- `selene src tools` — 0 errors, 0 warnings

## Scope confirmation

Only the two files named in the findings were touched
(`roblox/src/shared/HudModel.luau`, `roblox/src/client/HudController.client.luau`).
No refactors, no adjacent-code changes, no value/geometry/behavior changes —
comment text and instance names only. `undoPill.Active` was not touched (still
never assigned, stays `false` by default per the Frame's construction). Commit
not pushed.
