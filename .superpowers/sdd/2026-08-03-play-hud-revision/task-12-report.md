# Task 12 report — the teahouse becomes a takeover

## Root cause

`PANEL_W, PANEL_H = 340, 520` fixed the panel's absolute size, anchored bottom-right at
`PANEL_MARGIN`/`PANEL_BOTTOM` offsets from the viewport edge. The close button was positioned
from that same fixed math (`viewportHeight − (PANEL_BOTTOM + PANEL_H) + CLOSE_INSET`), which is
negative — i.e. above the top of the screen — on any viewport shorter than 580px, with no clamp
anywhere in the path.

## Fix

1. `panel` is now a viewport-relative `Frame` (`AnchorPoint(0.5,0.5)`, `Position fromScale(0.5,0.5)`,
   `Size = UDim2.new(1, -2*PANEL_MARGIN, 1, -2*PANEL_MARGIN)`) — always centered, always inset
   `PANEL_MARGIN` (12px) from every edge, so it cannot exceed the viewport at any size.
2. `gui.DisplayOrder = 20` — same layer as the ledger; the two takeovers never conflict since
   only one is ever open (the ledger closes itself before firing `EventBus.OpenTeahouse`).
3. `closeButton` is now a child of `panel`, anchored to the panel's own top-right corner, inside
   a fixed `HEADER_H` (44px) header strip: `Position = UDim2.new(1, -PANEL_MARGIN, 0, (HEADER_H -
   CLOSE_W) / 2)`. It is reachable and correctly sized at every viewport, because it is placed
   against the panel's own geometry rather than a viewport-edge offset.
4. Movement suspension: `require(script.Parent:WaitForChild("Takeover"))`; `setOpen` now tracks
   `isOpen`, guards on it (idempotent — a redundant open can't double-acquire, a redundant close
   can't drive the reference count negative), and calls `Takeover.acquire()`/`Takeover.release()`
   on the true open/close transitions.
5. `Takeover.luau:115`'s warn message was genericized (no longer says "reopen the ledger") since
   the teahouse is now a second holder of the same mechanism.

## Structural necessity: a new `scroll` ScrollingFrame

The brief's literal snippet says "parent [the close button] to panel, not to gui." But `panel`
used to be a `ScrollingFrame` with a `UIListLayout` driving every one of its ~20 content children
directly. A `UIListLayout` repositions **every** GuiObject child it has — there is no per-child
exemption — so parenting the close button alongside the scrolling content would drag it into the
list instead of letting it float over the panel's top-right corner.

So `panel` split into two instances:
- `panel` (Frame): the outer viewport-relative card — background, corner, and now also the home
  for `closeButton`.
- `scroll` (ScrollingFrame, new): owns the `UIListLayout`/`UIPadding`/`AutomaticCanvasSize`
  machinery that used to live directly on `panel`, positioned below a `HEADER_H`-tall strip
  (`Position = UDim2.fromOffset(0, HEADER_H)`, `Size = UDim2.new(1, 0, 1, -HEADER_H)`).

## Every child re-laid-out, and why

| Child | Old | New | Why |
|---|---|---|---|
| `panel` | Fixed `340×520`, anchored bottom-right at `(PANEL_MARGIN, PANEL_BOTTOM)` from the viewport | Viewport-relative, centered, `1,-24` both axes | The root defect — this is what made the ✕ go off-screen unconditionally below 580px |
| `closeButton` | Sibling of `panel` (parented to `gui`), positioned from a fixed viewport-edge offset (`viewportHeight − 572`) | Child of `panel`, anchored to the panel's own top-right corner inside the new `HEADER_H` strip | The exact off-screen defect; now derived from the panel's own geometry, which can never exceed the viewport |
| `scroll` (new) | N/A — content lived directly on `panel` | New `ScrollingFrame`, child of `panel`, offset below the header strip | Required so the close button (a `panel` child) isn't swept into the `UIListLayout` that drives the scrolling content |
| `layout`, `padding` | Parented to `panel` | Parented to `scroll` | Mechanical — these drive the scrolling content, which moved to `scroll` |
| `headerLabel` | `Size = UDim2.new(1, -(CLOSE_SIZE + CLOSE_INSET), 0, 28)` — narrowed to dodge the close button that used to share its row | `Size = UDim2.new(1, 0, 0, 28)` — full width | The close button no longer overlaps this row (it's in the separate header strip above); the old narrowing constant no longer exists |
| `sectionLabel`'s `label`, `claimNotice`, `needsClaimHint`, `loadingLabel`, ladder `row` (×2, deck/teahouse), display `row` (×2), `moveButton`, `portalButton`, `shownSmallerHint`, `favoritesContainer`, `backDoorLabel`, `decorContainer`, `accessModeRow`, `inviteRow`, `noticeLabel`, `inviteeContainer` (17 total) | `.Parent = panel` | `.Parent = scroll` | Mechanical reparent only — none of these had their own `Position`/`Size` computed from `PANEL_W`/`PANEL_H`/`PANEL_BOTTOM`; every one of them already used `UDim2.new(1, ...)`-style width-relative-to-parent sizing (or fixed pixel widths chosen independently of the old 340px panel width, e.g. the 3-across ladder/display/access-mode button rows), so they remain correct now that their parent's width tracks the viewport instead of a fixed 340px |

Everything in that last row was already parent-relative or self-contained (fixed pixel button
widths that don't reference the deleted constants), so none of it needed a geometry change beyond
the reparent — confirmed by grepping for `PANEL_W`/`PANEL_H`/`PANEL_BOTTOM`/`CLOSE_INSET`/
`CLOSE_SIZE` across the whole file (zero remaining references) and by inspection of every
`.Parent = panel` call site.

## Verification

- `grep -n "PANEL_W\|PANEL_H\|PANEL_BOTTOM\|CLOSE_INSET\|CLOSE_SIZE" src/client/TeahouseController.client.luau` → no matches
- No `HudLayout` module exists in `roblox/src/client`; this file never referenced one — N/A
- All locals (`PANEL_MARGIN`, `HEADER_H`, `CLOSE_W`, `panel`, `closeButton`, `scroll`, `layout`,
  `padding`, `isOpen`) declared before first use
- Zero `UIStroke` instances added; none of the new/changed instances are `TextLabel`s
- `stylua --check src tests tools` — pass; `selene src tools` — 0 warnings, 0 errors
- `lune run tests/run` — 921 passed, 0 failed

### ✕ position on a 390px-tall viewport

`PANEL_MARGIN = 12`, so `panel` top = `12px`, bottom = `viewportHeight - 12 = 378px` (height
`366px`, centered). `closeButton` top (absolute) = panel top + `(HEADER_H - CLOSE_W) / 2` =
`12 + 5 = 17px`; bottom = `17 + 34 = 51px`. Right edge is `PANEL_MARGIN` (12px) inset from the
panel's right edge, which is itself `12px` inset from the viewport's right edge, so the button's
right edge sits `24px` from the viewport's right edge, spanning left to `24 + 34 = 58px` from
the right edge. Fully on-screen and reachable regardless of viewport width — a direct contrast
with the old `viewportHeight − 572 = -182px` (170px+ above the top of a 390px screen).

### Panel never exceeds the viewport

`panel.Size = UDim2.new(1, -2*PANEL_MARGIN, 1, -2*PANEL_MARGIN)` is strictly smaller than the
full viewport in both axes for any viewport ≥ 24px in either dimension (true of every real
device), and `AnchorPoint(0.5,0.5)` + `Position fromScale(0.5,0.5)` centers it — so it always
sits with a 12px margin on all four sides and can never clip off any edge.
