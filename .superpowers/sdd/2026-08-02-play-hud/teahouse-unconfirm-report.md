# Teahouse rehome + un-confirm — report

Branch `m4b-zendojo-art-pass`. Two commits:

- `5b45925` fix(roblox): the ledger is the teahouse door, not a corner toggle
- `f40ad10` feat(roblox): a confirmed throw stays changeable until the round locks

Gates, all green after both commits:

- `roblox/`: `stylua --check src tests tools` clean, `selene src tools` — 0 errors,
  0 warnings, 0 parse errors; `lune run tests/run` — **918 passed, 0 failed**
  (900 before item 2, so item 2 adds 18 tests).
- `server/`: `npm test` — 13 files, **209 passed**. Untouched by this work; run to
  confirm no drift.
- Commit `5b45925` was gated **in isolation** (item 2's files stashed) before being
  made: stylua/selene clean, 900 passed. Neither commit depends on the other.

---

## 1. The teahouse toggle

### Every entry point to the teahouse panel

I grepped the whole `roblox/` tree — `src/`, `tools/`, `tests/` — for `TeahousePanel`,
`OpenTeahouse`, `Toggle`, `toggleButton`, and for any other controller touching that
ScreenGui.

| Entry point | Where | What I did |
|---|---|---|
| The persistent `Toggle` button | `TeahouseController.client.luau:106-108` (was) | **Deleted.** It was the *only* way in. |
| `EventBus.OpenTeahouse` | new channel | **Added.** Now the only way in. Fired by the ledger. |

**There were no other entry points, and there are no stale references.** After the
deletion, `grep -rn "Toggle\|toggleButton" src/ tools/studio/*.luau` returns nothing at
all, and no tool or verifier names `TeahousePanel`.

Two things that *look* like entry points and are not:

- `EconomyController.client.luau:86` sets `prompt.ObjectText = "Teahouse"` — that is a
  world **ProximityPrompt** on a claim pad. It fires the claim remote; it has never
  opened this panel.
- `BackDoorController` / `PerchPreferenceController` handle the back-door and
  favourite-add world prompts. Both put up their own UI. Neither touches this ScreenGui.

The panel is therefore reachable, by exactly one door: **THE LEDGER → MY TEAHOUSE**.

### The panel had no way to close itself, so it got one

The toggle was doing double duty as the open *and* the close. Deleting it would have
left a panel that opens and never shuts. I added a 34px `Close` button — hidden with the
panel, so it adds nothing to the always-on interactive count.

It is a **sibling of the panel, not a child**: everything parented to `panel` is laid out
by its `UIListLayout` and scrolls with the canvas, and a close control you have to scroll
back up to find is not a close control. It is pinned to the panel's top-right corner,
derived from the panel geometry constants (which I lifted out of the two inline literals
they were, so the two cannot drift). The header label was shortened by the close button's
width so a long `"1240 pts · Perch: <padId>"` cannot run under it.

`setOpen` now paints both, and the internal `open` flag is gone — the toggle was the only
caller that needed to know the current state in order to invert it; every remaining caller
(`OpenTeahouse`, the ✕, the move button's `setOpen(false)`) states what it wants.

This is not a restructure of the panel. Its position, size, sections, scrolling and every
render path are byte-for-byte what they were.

### The panel's contents are NOT standing dead zones when it is closed — verified

The runtime census that showed ~26 buttons under `TeahousePanel` with `Visible = true` was
reading each button's *own* property. The relevant question is the ancestor, and the answer
is in the source:

`TeahouseController.client.luau:137` — `panel.Visible = false` at construction.

Every one of those ~26 buttons is a descendant of `panel`. A Roblox `GuiObject` with a
non-visible ancestor is not rendered and takes no input, whatever its own `Visible` says.
So the census reading was the expected one, the ancestor *is* hidden, and the panel's
contents cost nothing while it is closed. Same for the new close button, which is
additionally `Visible = false` in its own right.

### Where MY TEAHOUSE went, and why

**The ledger header, immediately left of the ✕** (`LedgerController.client.luau:319-336`),
160×44 — the same 44px touch height as the ✕ it sits beside.

The brief allowed the preferences footer or its own footer row. I went with the header:

- **The footer has no room.** Its two switches already span `2 × PREF_COL_W = 472px`. There
  is no third column at the width this design targets, so the footer option collapses into
  the second-row option.
- **A second footer row costs the BODY 48px**, and the body is the squeezed dimension on
  exactly the tier this design is for. On a landscape phone it is 68–83px today; a second
  row takes it to 20–35px — a reading window smaller than one statistic.
- **The header is free at every size** and cannot crowd the two preference switches at all,
  which was the brief's explicit constraint.
- It puts "go somewhere else" beside the ✕, **where navigation belongs**. The header's right
  end is now the navigation end: one way out, one door onward.

The title and the `MOVEMENT SUSPENDED WHILE OPEN` note were pulled in by a single derived
`NAV_W = CLOSE_W + 8 + TEA_W + 8`, so nothing can run under either control, and resizing any
of the three keeps them clear automatically.

### The ledger closes first, through `close()`

```lua
teahouseButton.MouseButton1Click:Connect(function()
    close()
    EventBus.OpenTeahouse:Fire()
end)
```

Not `gui.Enabled = false` — `close()`. Two takeover surfaces at once is bad on its own, but
the reason this is load-bearing rather than tidy is that **the ledger suspends movement**.
`close()` is the one exit that calls `restore()`, so the player always gets their legs back
on the way through. Opening the teahouse panel over a still-open ledger would leave someone
reading it frozen, with the ✕ behind the panel they are looking at.

### `Active` discipline

`.Active = true` still appears **exactly once** in the branch —
`LedgerController.client.luau:252`, the ledger panel's takeover carve-out. Verified by grep.
Neither the new MY TEAHOUSE button nor the new teahouse close button sets `Active`; both are
`TextButton`s, which take input by being buttons. The always-on interactive count goes
**down by one**: the persistent corner toggle is gone and nothing persistent replaced it.
Camera drag is not touched.

---

## 2. Un-confirm

### The transition table as implemented

`HudModel.tapAction(inputs, symbol)` returns one of four actions. `main.client.luau`'s
`HudPick` handler is the only interpreter of them, and it is the only place a pick leaves
the client.

| From | Tap | Action returned | Selection after | Committed after | Talks to server |
|---|---|---|---|---|---|
| (nothing) | X | `select` | X | — | no |
| X selected | X | `commit` | X | X | **yes** |
| X CONFIRMED | X | `release` | X | — | no |
| X selected | Y | `select` | Y | — | no |
| X CONFIRMED | Y | `select` | Y | — | no |
| any, no pot / pref off | X | `commit` | X | X | **yes** |
| any, no pot, already committed | anything | `ignore` | unchanged | unchanged | no |
| lockout (`secondsLeft ≤ AUTO_COMMIT_AT`) | — | `autoCommit` → selected | X | X | **yes** |
| TALLY/REVEAL, `secondsLeft = 0`, or fate-bound | anything | `ignore` | unchanged | unchanged | no |

The rule, in three lines of `tapAction`: a tap on a glyph that is **not** the selection
always `select`s (a mis-tap correction must never itself count as the confirmation); a tap
on the selection `release`s if there is a committed pick and `commit`s if there is not; and
with no pot, or the preference off, `confirmRequired` is false and the first tap `commit`s
with no confirm step at all.

`throwsEnabledFor` was rewritten to make the release gesture reachable: a committed pick no
longer closes the round for that player **while confirmation is in play**, because tapping
the lit glyph is how a confirmation is released. Without confirmation there is no release
gesture to make, so a commit is the end of it exactly as before.

### Test names covering each transition

All in `roblox/tests/HudModel.spec.luau`.

`describe("HudModel — the full transition table")` runs the owner's table **as a sequence**,
with a tiny state machine that mirrors `main.client.luau`'s handler and counts server fires:

- `nothing -> X selected -> X CONFIRMED -> X selected -> Y selected` — rows 1–4, and asserts
  `fires` stays at 1 across the release (a release never talks to the server).
- `X CONFIRMED --tap Y--> Y selected, and only a commit talks to the server` — row 5, then
  re-confirms Y and asserts the second fire (the later pick overwrites the earlier).
- `no pot: one tap throws, and there is no confirm step at all` — row 6 and row 7.
- `lockout throws whatever is selected, including a released one` — row 8, driven through
  `HudModel.autoCommit` after a release.

`describe("HudModel.tapAction — releasing a confirmed throw")` covers the transitions
individually:

- `CONFIRMED --tap the same glyph--> released back to selected`
- `CONFIRMED --tap a different glyph--> that glyph selected`
- `the tiles stay live while a pick is confirmed, so it CAN be released`
- `a released selection can be re-confirmed`
- `the round closing ends it — a confirmed pick is not releasable past the lockout` (row 9)
- `NO TAP CAN EVER EMPTY THE SELECTION — exhaustive over the whole tap matrix`

`describe("HudModel.tapAction — one tap, or two")`:

- `with no confirmation to release, a committed pick is final and further taps are ignored`
  — both ways confirmation can be absent (no pot; preference off).

`describe("HudModel.view — the confirm affordance")`:

- `a CONFIRMED pick asks nothing further, but says it can still be changed`
- `releasing puts the prompt back`
- `nothing is releasable when confirmation was never required`

`describe("HudModel — pickedThisRound after a release")`:

- `a confirmed pick silences the escalation`
- `a RELEASED pick does not — the player has nothing in`
- `a released pick is auto-committed rather than lost`
- `a still-confirmed pick is never re-sent at the lockout`

### A release can never leave an empty selection — the check

This is the one failure the feature could introduce: a player visibly takes their throw
back, the screen shows nothing chosen, and the server still holds the pick.

**It is closed structurally, not by convention.** `tapAction` returns `"release"` on
exactly one branch, and that branch is reached only after
`if inputs.selectedThrow ~= symbol then return "select" end` — so `"release"` is *only ever
returned for the glyph that is already the selection*. The handler's release arm clears
`myPick` and does not touch `selectedThrow`. The other two acting arms (`select`, `commit`)
both set the selection to the glyph tapped, which is never nil. **There is no action in the
model that returns the player to "nothing chosen."**

The test `NO TAP CAN EVER EMPTY THE SELECTION` asserts this **exhaustively** rather than by
example: it walks 2 × 2 × 2 × 4 × 3 = 96 combinations of `pickedThisRound` × `confirmThrows`
× pot × current selection (including *none*) × glyph tapped, and for every one either the
action is `ignore` (nothing changes) or the resulting selection is the glyph tapped — with
`release` additionally asserted to name the glyph that was already selected.

I also closed the one path that could have *stranded* a pick from the other direction. Since
`commitPick` now leaves the selection standing (that is what a release falls back to), a
whiff that cleared only the committed pick would leave `autoCommit`'s past-ACTIVE branch
looking at an apparently-uncommitted selection and **re-firing the very pick the server had
just refused**. The `RevealTheater` whiff handler now clears `selectedThrow` too. The
round-open handler clears both as belt-and-braces, so a stale glyph can never be lit into
the next round.

### `pickedThisRound`, both consumers re-checked

It now means **"has a committed pick right now"**, not "has tapped". Both consumers move
with it, and they want opposite things from a release:

- **`throwsEnabled`** — the tiles must stay **live** after a commit while confirmation is in
  play, or a release could not be re-confirmed. `throwsEnabledFor` returns true when
  `pickedThisRound and confirmRequired(inputs)`.
- **Escalation arming** — a player who released has nothing in, so `armed` (which reads
  `not pickedThisRound`) correctly comes back. Covered by the two paired tests above.

### The round-boundary `picked` flag

`main.client.luau`'s ACTIVE→non-ACTIVE transition now passes
`myPick ~= nil or selectedThrow ~= nil`. The lockout's auto-commit normally converts a
standing selection half a second before this fires, but a player who releases inside that
last sliver would otherwise be scored as having ignored the round — and three of those start
the escalation nagging someone who is demonstrably playing. A standing selection counts as
picked.

### The affordance

The tile treatment for *chosen* and *thrown* is deliberately identical, so the confirm strip
is the only thing that distinguishes them — which means it has to carry the release
affordance too, or a confirmed throw would look exactly like an unconfirmed one with no way
to tell that tapping again takes it back rather than throwing twice.

**Two messages, one strip, never both:**

- `TAP AGAIN TO THROW` while a selection is waiting on its second tap (`view.confirmPending`)
- `THROWN — TAP TO CHANGE` once it has gone and the round has not locked (`view.releasable`)

Saying both at once would be a wall of ~9px type on a 44px row — the exact failure the strip
exists to avoid. `HudModel` decides which; `HudController` only paints. In the releasable
state the "don't ask again" checkbox is hidden and the label takes the full strip width: a
preference switch is not what someone reaching to change their throw is looking for, and
turning it off *there* would silently make the pick final. No new geometry — the strip's row
is already reserved in `HudLayout`'s safe band whether or not it is showing, so nothing moves
and onboarding cards still cannot land on it.

Fit check: `HINT_W_WIDE = CONFIRM_W - 2×CONFIRM_PAD = 268px`; `THROWN — TAP TO CHANGE` is 22
characters at 14px GothamBold, ≈176px. Comfortable.

`.Active` untouched: the strip and its labels are Frames/TextLabels at the default false.

---

## Self-review notes

- **Nothing in `shared/` gained a Roblox global or a `require` of a sibling.** `HudModel`
  stays pure and Lune-testable; all four new tests run headless.
- **`shared-fixtures/game-rules.json`, both `GameRules`, `DayNightLockT`,
  `PreNightTestLockT`** — untouched. No `.rbxl`/`.rbxlx` committed (`git status` clean).
- **No new `EventBus` channel beyond `OpenTeahouse`.** A "selected" channel was considered
  and rejected: a select is just a publish with `selectedThrow` set, and a second channel
  would be a second place to forget the rule.
- **Ledger header at narrow widths.** `NAV_W` is 220px. The ledger panel is `0.94` of the
  viewport, and its footer already presumes ≥ ~500px (two 236px preference columns). At that
  floor the header still leaves ~250px for the title and the suspend note, which needs ~212px.
  No regression within the widths the ledger already supports; below them the footer breaks
  first, as it did before this change.
- **Studio verification is the controller's.** Nothing here was checked in Studio.
