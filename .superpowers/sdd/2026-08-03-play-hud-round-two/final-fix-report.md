# Final whole-branch fix wave — report

Branch `m4b-zendojo-art-pass`. All five findings from the final review addressed.

## FIX 1 (CRITICAL) — LAST ROUND band starving the body

Root cause confirmed by arithmetic: with the band as fixed chrome between the header and the
hero (`bodyTop() = HEADER_H + LAST_ROUND_H + GAP + HERO_H + GAP = 300`), the body's remaining
height went negative on both landscape-phone sizes tested, clamped to 0 by Roblox.

**Fix applied**: reverted `heroTop()`/`bodyTop()` to their pre-band constants (`BODY_TOP = 160`,
fixed chrome untouched). The LAST ROUND content is no longer a panel-level band; it is now
`lastRoundCard`, the first `LayoutOrder` child of a new `UIListLayout` on `lifetimeBody` (the
LIFETIME card's own `ScrollingFrame`), with `lifetimeBody.AutomaticCanvasSize = Enum.AutomaticSize.Y`
(the same pattern the FEED card already used). `LIFETIME_ROWS` and the WIN/SAFE/LOSS bar (now
wrapped in one `barBlock` list item) lost their manual Y-offset math and became list items too.
`lastRoundCard.Visible` is toggled in `render()`; `UIListLayout` skips invisible children and
closes the gap for free, so hiding the card can never leave a hole, and as scrolling content it
can never starve the panel's fixed chrome again at any viewport.

### Body height, before → after (computed from the layout constants, not measured in Studio)

| Viewport   | Before (bug)      | After (fix) |
|------------|--------------------|-------------|
| 844×390    | **-57.4px** (clamped to 0 — dead) | **82.6px** |
| 844×354    | **-91.24px** (clamped to 0 — dead) | **48.76px** |
| 1280×720   | 290.8px (already fine) | **430.8px** |

All three are positive after the fix; the two phone sizes match what the panel produced before
Task 9 ever added the band (BODY_TOP=160 is byte-identical to the pre-Task-9 constant). The
LIFETIME card's own scrolling content (band 128px + 5 rows + bar block, ~323–331px total) exceeds
the 48.76–82.6px viewport on both phone sizes, exactly as YOUR THROWS/FEED content already did
before this round — it scrolls, nothing is clipped to zero.

**Band contents fit, no overlap**: internal band layout is unchanged (only its parent changed).
Deepest content bottom is `roundBarLegend` at y=112, height 14 → bottom 126, inside the 128px
card. No overlap introduced.

## FIX 2 — stale "hamburger" reference

`SplashController.client.luau:15-16` and `docs/superpowers/specs/2026-08-03-play-hud-round-two-design.md:76`
both corrected to name "the round-timer ring" instead of the deleted hamburger.

## FIX 3 — plate label overflow onto the tape

`HudController.client.luau`'s `plateLabel`: added a `UISizeConstraint` (`MaxSize.X = PLATE_MAX_W - 16`,
mirroring the plate's own 100px cap minus its 16px padding) plus `TextScaled = true` and a
`UITextSizeConstraint(MaxTextSize = 15)`. `AutomaticSize.X` alone measured the label's uncapped
natural text width, blind to the plate's own clamp; the added size constraint gives the label the
same hard ceiling, and `TextScaled` shrinks the font to fit inside it instead of clipping the tail
digits (`ClipsDescendants` was explicitly avoided per the review).

## FIX 4 — stale comments (batch)

- `main.client.luau:184-186`: "HAIRLINE" → "RING".
- `HudModel.luau:130-132`: "four-second question" → "one-second question" (`SWITCH_PROMPT_SECONDS = 1`).
- `HudController.client.luau:587`: "same pattern as `bankButton` above" → "below" (bankButton is at :781, now :796 after FIX 3's insert).
- `HudController.client.luau:~1086`: "same pattern as `switchLabel` below" → "above" (switchLabel is at :576).
- `Takeover.luau:37`: line reference for `OpenLedger` updated from `:782` to `:979` (current line after all edits).

## FIX 5 — splash preference symmetry

`main.client.luau`'s `EventBus.HudPreference` handler now calls both `publish()` and
`publishLedger()`. `resultSplash` is read by `SplashController` from `EventBus.LedgerState`
(fired by `publishLedger`), not `EventBus.HudState` (fired by `publish`) — the toggle previously
worked only by coincidence (a `ProfileUpdate` echo landing before the next drum rest).

## Gates (all four)

- `lune run tests/run` — **962 passed, 0 failed, 962 total**
- `stylua --check src tests tools` — clean, no diff
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors
- `npm test` (server/) — **211 passed** (13 test files)

## Not touched (per instructions)

First win firing both the splash and the `win` onboarding beat on one tick; `HudModel.View.bankVisible`
going unread; the escalation prompt being the one sinking non-control element.

## Concerns

- FIX 1's body-height table is computed from the layout constants (verified against the actual
  file), not measured live in Roblox Studio — no Studio session was available in this task. The
  arithmetic is straightforward (panel scale × viewport, minus fixed offsets) and cross-checked
  against the pre-Task-9 commit's constants, but a Studio screenshot at 844×390 would be the
  stronger confirmation.
- FIX 3's `UISizeConstraint` on `plateLabel` is a new addition beyond the review's literal wording
  ("TextScaled plus a UITextSizeConstraint") — `TextScaled` alone cannot bound an
  `AutomaticSize`-driven label's width, so a size cap was required to give it something concrete
  to shrink into. Reasoning is documented inline at the fix site.
