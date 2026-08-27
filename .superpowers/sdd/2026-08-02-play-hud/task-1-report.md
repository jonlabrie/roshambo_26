# Task 1 Report: Real glyphs on the canyon lanterns

## Summary

`LanternController.client.luau` rendered lantern faces as Unicode `TextLabel`s (`○ ─ ∧`)
instead of the canonical SDF glyph assets in `Glyphs.luau`. `Glyphs` gained a new
`renderGroup` entry point (the existing two-layer render, wrapped in an aspect-locked
`CanvasGroup` for single-tween fading), and both `LanternController` face builders
(`buildFace` for block lanterns, `buildRoundFace` for round chōchin) were switched to call
it. `BoardController.client.luau`'s identical Unicode table (dead code — the file
early-returns, `JumbotronBoard` no longer exists) was left untouched per the brief.

Studio verification (brief Step 7) was intentionally **not** performed — the controller
owns Studio passes for this plan and will take it to the project owner.

## Files changed

- `roblox/src/shared/Glyphs.luau` — added `Glyphs.renderGroup`
- `roblox/src/client/LanternController.client.luau` — `require(Glyphs)`; `glyphGroups: {CanvasGroup}`
  replaces `glyphLabels: {TextLabel}`; `buildFace`/`buildRoundFace` build a `GlyphHolder` Frame +
  `Glyphs.renderGroup` instead of a `TextLabel`; `fadeBlank`/`fadeShown` tween `GroupTransparency`;
  new `setGroupSymbol` retargets the two `ImageLabel`s inside a group by child-insertion order;
  `showThrow` calls `setGroupSymbol` on each group instead of setting `.Text`. One stale doc-comment
  fix in a follow-up commit ("glyph label" → "glyph").
- `roblox/tests/Glyphs.spec.luau` — extended the existing spec (did not overwrite it — it already
  covered `IMAGE`/`PALETTE`/`NIGHT`/`renderDay`/`buildNightNeon`) with the brief's two missing
  assertions: a cross-symbol "no two layers share an asset id" check, and a `renderGroup` function
  existence check folded into the existing day/night API test.

Deviation from the brief's literal Step 1: the brief's test snippet assumes a fresh file, but
`roblox/tests/Glyphs.spec.luau` already existed (from earlier Glyphs work, commits `0bb491f`..`400262b`)
with substantially the same coverage plus `PALETTE`/`NIGHT`/`renderDay`/`buildNightNeon` tests the
brief doesn't mention. Rather than deleting that coverage, I added the brief's two new assertions
into the existing structure, matching its existing style (`type(...)` builtin, not `typeof(...)`).

## TDD evidence

**RED** — `cd roblox && lune run tests/run`:

```
FAIL  Glyphs day/night palette + API > renderDay + buildNightNeon + renderGroup are functions
      /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/Glyphs.spec:62: expected nil to be function
...
816 passed, 1 failed, 817 total
```

Expected: `Glyphs.renderGroup` didn't exist yet, so `type(Glyphs.renderGroup)` was `"nil"`,
not `"function"`.

**GREEN** — after adding `Glyphs.renderGroup`, `cd roblox && lune run tests/run`:

```
817 passed, 0 failed, 817 total
```

(The `[WARN] [QUEUE] ...` lines around both runs are pre-existing intentional-failure fixtures
in `HandlerQueue.spec` unrelated to this change — same in both RED and GREEN runs.)

## Gates

```
$ cd roblox && stylua --check src tests tools && selene src tools
Results:
0 errors
0 warnings
0 parse errors

$ lune run tests/run
817 passed, 0 failed, 817 total
```

Both clean, confirmed after the doc-comment follow-up too.

## Commits

- `92f7cd5` — `fix(roblox): lanterns render the real glyph assets, not Unicode stand-ins`
- `4ffb9f7` — `docs(roblox): fix stale comment after lanterns moved off TextLabel`

## Self-review notes

- Confirmed `git diff` on `BoardController.client.luau` across both commits is empty — left
  exactly as instructed.
- Confirmed no remaining references to `GLYPH`, `glyphLabels`, `TextLabel`, or `.Text`/`TextTransparency`
  anywhere in `LanternController.client.luau` (`grep` came back empty) — no Unicode stand-in survives
  in the touched file.
- `setGroupSymbol`'s reliance on `GetChildren()` insertion order (index 1 = outline, index 2 = core)
  is exactly as specified in the brief and matches `Glyphs.renderGroup`'s construction order
  (outline layer created before core layer) — verified by reading both functions side by side.
- Both face builders pass `INK` for both `coreColor` and `outlineColor`, matching the original
  single-color `TextLabel.TextColor3 = INK` look (no color regression).
- `ShownT` attribute values (0 for block, 0.2 for round) match the brief and the original
  `TextTransparency` resting values exactly.
- No YAGNI additions — `renderGroup` matches the brief's signature and body verbatim; no extra
  parameters, no speculative options.
