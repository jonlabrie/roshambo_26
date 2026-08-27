# Task 6 report: UNDO? covers the button, and lasts long enough to read

Commit: `c447ed2ab7bbfd56c4eeac4fe75debe70a1248ff`
"feat(roblox): UNDO? covers the button it questions, and waits to be read"

## What changed

### 1. `roblox/tests/HudModel.spec.luau`
Renamed the `describe` block at (originally) line 459 from "a one-second fuse" to "a two-second
fuse" and replaced its two tests with the brief's exact text: `UNDO_PROMPT_SECONDS` now expected
to be `2`, and a new boundary test (`t+1.99` → false, `t+2` → true) replacing the old `t+0.99`/`t+1`
pair. Left the generic boundary test at `:389-393` untouched, per the brief and per your note —
it reads the constant symbolically and proves the predicate tracks the constant, not a literal.

### 2. `roblox/src/shared/HudModel.luau`
`HudModel.UNDO_PROMPT_SECONDS` changed from `1` to `2`. Rewrote the comment above it to the
brief's exact "TWO SECONDS..." text.

**Deviation from the brief, and why:** the brief's Step 3 says "Keep the word-change note added
in Task 4" — but that note (as it stood) read *"The word changed from SWITCH? to UNDO? on
2026-08-04 because SWITCH? described..."*, containing the literal string `SWITCH?` twice. That
directly conflicts with the brief's own Step 7 checklist item 4 ("The `SWITCH?` string appears
nowhere") and with your final verification grep, both of which demand `grep -rn "SWITCH"` return
nothing in `src`/`tests`. I resolved the contradiction in favor of the explicit, doubly-stated
"no output at all" requirement: reworded the note to drop the literal word while keeping its
informational content —

> "The prompt's copy changed to UNDO? on 2026-08-04 because the previous word described something
> this button has never done: answering it CLEARS the choice, it does not move the choice to the
> glyph that was tapped. That is what makes either unchosen button a back-out proxy."

No test depends on the comment text, so this is safe.

### 3. `roblox/src/client/HudController.client.luau`
- `undoPill.Size`: `UDim2.fromOffset(BTN_W, 24)` → `UDim2.fromOffset(BTN_W, BTN_H)`.
- `corner(undoPill, 6)` → `corner(undoPill, 8)`.
- Sizing comment above replaced with the brief's exact text, including the `Active = false`
  warning verbatim.
- `undoLabel.Text`: `"SWITCH?"` → `"UNDO?"`.
- `constraint.MaxTextSize`: `13` → `22`.
- Comment above the `TextScaled` block replaced with the brief's exact text.
- Left `undoLabel.TextSize = 13` (initial pre-scale value), `Enum.Font.GothamBold`, `ZIndex`s (4/5),
  `WASHI` fill, `SEL_BLUE` stroke, and `setUndoPrompt`'s position arithmetic untouched, per the
  brief's explicit "do not change" list.
- Did not touch `undoPill.Active` anywhere — it is still never assigned.

## Gate output

```
$ cd roblox && lune run tests/run
970 passed, 0 failed, 970 total
(pre-existing unrelated [WARN] queue-full / handler-error lines from HandlerQueue.spec, present before this task too)

$ stylua --check src tests tools
(no output — clean)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

Before the constant change, the two new tests failed as expected:
```
FAIL  HudModel.UNDO_PROMPT_SECONDS — a two-second fuse > it is two seconds
      expected 1 to be 2
FAIL  HudModel.UNDO_PROMPT_SECONDS — a two-second fuse > the fuse burns for the whole two seconds
      expected true to be false
968 passed, 2 failed, 970 total
```

## Verification greps

### `grep -rn "SWITCH" roblox/src roblox/tests`
```
roblox/src/client/LedgerController.client.luau:712:local SWITCH_W, SWITCH_H = 58, 28
roblox/src/client/LedgerController.client.luau:713:local SWITCH_KNOB = 22
roblox/src/client/LedgerController.client.luau:715:local PREF_COL_W = PREF_LABEL_W + 10 + SWITCH_W + 28 -- label + gap + switch + breathing room
roblox/src/client/LedgerController.client.luau:732:    switch.Size = UDim2.fromOffset(SWITCH_W, SWITCH_H)
roblox/src/client/LedgerController.client.luau:738:    corner(switch, SWITCH_H // 2)
roblox/src/client/LedgerController.client.luau:745:    knob.Size = UDim2.fromOffset(SWITCH_KNOB, SWITCH_KNOB)
roblox/src/client/LedgerController.client.luau:749:    corner(knob, SWITCH_KNOB // 2)
roblox/src/client/LedgerController.client.luau:867:    sw.knob.Position = if on then UDim2.new(1, -(SWITCH_KNOB + 3), 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
```

**This is not empty**, but every hit is a false-positive substring match: `LedgerController.client.luau`
implements a settings-panel toggle switch (`SWITCH_W`/`SWITCH_H`/`SWITCH_KNOB`), a completely
unrelated UI component that predates this task and is not in the brief's file list (`HudModel.luau`,
`HudController.client.luau`, `HudModel.spec.luau`). None of these are the HUD's old `"SWITCH?"`
button copy. I did not rename LedgerController's identifiers — that would be out-of-scope scope
creep on an unrelated, working component for a cosmetic grep. Restricting the search to the
literal button copy confirms the actual target is gone:

```
$ grep -rn "SWITCH?" roblox/src roblox/tests
(no output)
```

### `grep -n "undoPill" roblox/src/client/HudController.client.luau`
```
580:local undoPill = Instance.new("Frame")
581:undoPill.Name = "UndoPrompt"
582:undoPill.AnchorPoint = Vector2.new(0.5, 0.5)
589:undoPill.Size = UDim2.fromOffset(BTN_W, BTN_H)
590:undoPill.BackgroundColor3 = WASHI
591:undoPill.BackgroundTransparency = 0
592:undoPill.BorderSizePixel = 0
593:undoPill.ZIndex = 4
594:undoPill.Visible = false
595:undoPill.Parent = throwArea
596:corner(undoPill, 8)
597:stroke(undoPill, SEL_BLUE, 2, 0)
608:undoLabel.Parent = undoPill
630:    undoPill.Visible = symbol ~= nil
633:        undoPill.Position = UDim2.fromOffset((i - 1) * (BTN_W + BTN_GAP) + BTN_W / 2, BTN_H / 2)
```
`Active` is never assigned on `undoPill` anywhere in the file — confirmed by direct inspection of
every line above and by `grep -n "undoPill\.Active" ...` returning no matches.

## Overlay-covers-button arithmetic, both tiers

`BTN_H_TOUCH = math.round(BTN_H * THROW_TOUCH_SCALE)` in `roblox/src/shared/HudLayout.luau`, with
`HudLayout.BTN_H = 76` — confirmed touch value is `44` (`BTN_W = BTN_H` always, buttons are square).

- **Touch tier**: `BTN_W = BTN_H = 44`. Throw button: `Size = UDim2.fromOffset(44, 44)`,
  `Position = UDim2.fromOffset((i-1)*(44+GAP), 0)` (top-left anchored, AnchorPoint 0,0 implicit).
  `undoPill.Size = UDim2.fromOffset(44, 44)` now (was `44 × 24`), anchored `(0.5, 0.5)` at
  `Position = ((i-1)*(44+GAP) + 44/2, 44/2) = ((i-1)*(44+GAP) + 22, 22)` — i.e. centred exactly on
  the button's own centre, and since both are 44×44, the pill's edges land exactly on the button's
  edges in both axes. Exact cover, no clipping, no overhang.
- **Desktop tier**: `BTN_W = BTN_H = 76`. Same reasoning: `undoPill.Size = UDim2.fromOffset(76, 76)`,
  centred at `Position = ((i-1)*(76+GAP) + 38, 38)` — again exactly the button's centre, exact
  76×76 cover.

The centring math (`setUndoPrompt`) was untouched per the brief — it was already tier-agnostic
because it's expressed in terms of `BTN_W`/`BTN_H`, so growing `Size` alone (from a fixed 24px
height to `BTN_H`) is sufficient to make the pill an exact overlay at either tier.

Text constraint check: touch tier's undo pill content box is 44×44 (full square now, not the old
36px-wide inset); `MaxTextSize = 22` only caps growth on the *wider* desktop tier's 76×76 box —
on touch, `TextScaled` still lands well under 22px for "UNDO?" (5 chars) in a 44px box, consistent
with the brief's stated ~13px landing point at the narrow tier.

## Concerns

1. **The SWITCH-comment contradiction** (documented above) — I resolved it by favoring the
   explicit "no output at all" requirement over "keep the word-change note" verbatim, since the
   two brief instructions cannot both be literally true. Flagging in case the owner intended
   something else (e.g., a narrower grep pattern, or an exception for that one comment).
2. **LedgerController's `SWITCH_*` false positives** — the plain `grep -rn "SWITCH"` command as
   literally specified in the outer task will never return empty while that unrelated toggle-switch
   component exists under those names. I left it alone; renaming it wasn't in scope and risks an
   unrelated regression. If a truly-empty bare `SWITCH` grep is a hard requirement, that's a
   separate, unscoped task.
3. Everything else came back clean: 970/970 tests, stylua clean, selene 0/0/0, `undoPill.Active`
   never assigned, no `UIStroke` added to `undoLabel`, `BTN_W`/`BTN_H` declared well above the
   `undoPill` construction (lines 118-119 vs. construction at 580+).

## Post-task cleanup (per the brief's "After the last task" section)

Not performed by me — it requires a live Studio MCP session with `RingProto` parented under the
owner's `PlayerGui`, which is state in a running Studio instance, not the repo. Left for the
owner's gate as directed; noting it here so it isn't dropped. The Luau snippet to run is in the
brief verbatim.
