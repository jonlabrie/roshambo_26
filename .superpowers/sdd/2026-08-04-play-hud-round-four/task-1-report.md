# Task 1 Report: The ring's digits sit up, and UNDO becomes a card

## What changed

File: `roblox/src/client/HudController.client.luau` (1 file, +15/-2)

**Step 1 — seat the digits.** After `ringCount.TextSize`, `ringCount.Font`, `ringCount.Text`, and
`ringCount.Parent` are all assigned (still above the glyph-box block), added:

```lua
-- OPTICAL CENTRING, not a fudge. Roblox centres the LINE BOX, which reserves room for
-- descenders; digits have none, so a vertically centred box seats them low by roughly half a
-- descender. Every value this label ever shows is digits, so the correction is unconditional.
-- Derived from TextSize rather than a literal pair, so a future size change carries its own
-- correction: 2px at 34 (desktop), 1px at 20 (touch).
local COUNT_NUDGE = math.max(1, math.round(ringCount.TextSize * 0.06))
ringCount.AnchorPoint = Vector2.new(0.5, 0.5)
ringCount.Position = UDim2.new(0.5, 0, 0.5, -COUNT_NUDGE)
```

Verbatim per the brief. `ringCount.TextSize` (`if TOUCH then 20 else 34`) is assigned several
lines above this block, so `COUNT_NUDGE` never reads a forward reference.

**Step 2 — repaint the UNDO overlay.** Two colour assignments changed:

- `undoPill.BackgroundColor3 = WASHI` → `undoPill.BackgroundColor3 = IVORY`, with the brief's
  verbatim comment inserted above it (replacing nothing — there was no comment immediately above
  that specific line; the existing `Active = false` warning above it was left untouched).
- `undoLabel.TextColor3 = INK_CREAM` → `undoLabel.TextColor3 = INK`.

Nothing else on `undoPill`/`undoLabel` touched: `Size`, corner radius 8, `ZIndex` 4/5, the
`SEL_BLUE` 2px stroke, `TextScaled`, `MaxTextSize = 22`, `GothamBold` all unchanged.

## Computed nudge value at each tier

- Touch: `TextSize = 20` → `20 * 0.06 = 1.2` → `math.round = 1` → `max(1, 1) = 1px`.
- Desktop: `TextSize = 34` → `34 * 0.06 = 2.04` → `math.round = 2` → `max(1, 2) = 2px`.

Both match the brief's stated "2px at 34 (desktop), 1px at 20 (touch)".

## Gate output

- `lune run tests/run`: **970 passed, 0 failed, 970 total.** (Two `[WARN]` lines about a dropped
  queue request and a handler error are expected noise from `HandlerQueue.spec:80`'s
  deliberately-failing test case, not new failures.)
- `stylua --check src tests tools`: exit 0, no diff.
- `selene src tools`: 0 errors, 0 warnings, 0 parse errors.

## Standing-check items

1. **`ringCount.TextSize` assigned above `COUNT_NUDGE`.** Confirmed by reading the file: `TextSize`
   is set at what is now line 1042 (`if TOUCH then 20 else 34`); `COUNT_NUDGE` is declared at line
   ~1051, after `Font`, `Text`, and `Parent` are also assigned. No forward reference.
2. **`IVORY`, `INK`, `Vector2`, `UDim2` all resolve.** `INK` is declared at line 57
   (`Color3.fromRGB(60, 45, 28)`), `IVORY` at line 59 (`Color3.fromRGB(244, 238, 222)`), both well
   above their use points (~line 594 and ~line 607). `Vector2`/`UDim2` are Roblox engine globals.
3. **`grep -n "undoPill" ...` — `Active` never assigned.** Ran it; 13 matches, none set
   `.Active`. Full match list: construction/property lines (`Instance.new`, `Name`,
   `AnchorPoint`, `Size`, `BackgroundColor3`, `BackgroundTransparency`, `BorderSizePixel`,
   `ZIndex`, `Visible`, `Parent`, `corner(...)`, `stroke(...)`), plus later
   `undoPill.Visible = symbol ~= nil` and `undoPill.Position = ...` in the render pass, plus two
   comment-only mentions inside `paintThrows`'s fallback branch. `Active` appears nowhere.
4. **Glyph box construction untouched.** Confirmed by reading lines around `glyphBox(ringDisc,
   0.82)` (now ~line 1057): identical to before — no edits in or near that block, and the new
   nudge block sits entirely above it, separated by the existing "No UIStroke on this label"
   comment.

## Concerns

One pre-existing comment elsewhere in the file (in `paintThrows`'s currently-unreachable fallback
branch, around what is now line 668) still says `` `undoPill` is opaque WASHI at this exact rect
and ZIndex ``. That branch is documented as fully occluded/dead code (a fallback for if the pill
is ever shrunk or made translucent) and is out of scope for this task — the brief specified
exactly two colour changes and one comment replacement, both of which target the pill's own
construction, not this dead-code comment. Flagging it here rather than touching it, since it's a
minor staleness in a comment on unreachable code, not a defect in the shipped behavior.

No other concerns. Both repaints are cosmetic, isolated, and match the brief verbatim.

## Commit

`aede666` — "fix(roblox): seat the ring's digits, and lay UNDO on the HUD rather than through it"
(not pushed).

## Review round 1 fix (Important finding)

Review ruled the flagged staleness in scope after all: the `paintThrows` `prompted`-branch
comment (around line 668) still called `undoPill` "opaque WASHI" after the repaint, and — more
than trivia — its instruction to future maintainers ("look at this branch first" if the pill is
ever shrunk/made translucent) was now actively misleading, since the branch's own fallback fill
(`IVORY`) and the pill's new fill (`IVORY`) are the same colour: the "lifted out of the dimmed
state" contrast this branch exists to provide would be IVORY-on-IVORY if it were ever exposed.

Changed, comment-only, code untouched:
- `` `undoPill` is opaque WASHI `` → `` `undoPill` is opaque IVORY `` (corrects the stated fact).
- Appended a clause to the existing "look at this branch first" sentence: anyone changing the
  pill's size/opacity should also re-pick this branch's fill first, because the pill and this
  branch's lifted treatment are now the same colour (IVORY) and the old contrast is gone.

No paint values changed; the branch remains unreachable/dead exactly as before.

Gates re-run from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`:
- `lune run tests/run`: 970 passed, 0 failed, 970 total (same two expected `[WARN]` lines from
  `HandlerQueue.spec:80`'s deliberate failure case).
- `stylua --check src tests tools`: clean, exit 0.
- `selene src tools`: 0 errors, 0 warnings, 0 parse errors.

Committed separately (not amended, since round one's commit was already reported to the
coordinator): `7f013f7` — "fix(roblox): correct stale WASHI reference in undo-prompt fallback
comment" (not pushed).
