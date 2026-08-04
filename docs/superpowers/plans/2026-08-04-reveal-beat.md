# The Reveal Beat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the drum authoritative — nothing reflects the world throw until it is fully at rest — and give the reveal a sequence: glyph, hold, fade, then the tape tile.

**Architecture:** Retract round four's early-splash machinery, lengthen the server's REVEAL phase to make room, put the beat's timings in a pure `src/shared` module, and split two client variables that currently fire on the same line.

**Tech Stack:** Luau, Rojo, Lune test harness; TypeScript/Vitest for the server.

**Spec:** `docs/superpowers/specs/2026-08-04-reveal-beat-design.md`

## Global Constraints

- **THE RULE.** The drum is authoritative. Nothing may reflect the world throw anywhere until `drumRest`. Anything reading it earlier is wrong regardless of how good the reason sounds — round four's early splash was retracted for exactly this.
- **THE TAPE TILE IS NEVER DROPPED.** It is the round's permanent record; losing one to a timing edge leaves a gap in the tape that no later round repairs.
- **Every ScreenGui in this client runs in `ZIndexBehavior.Global`**, because `Instance.new("ScreenGui")` defaults to Global and nothing sets it — while much of the code is commented as though it were Sibling. Under Global a child does **not** draw above its parent; every element orders by its own ZIndex against every other. This is what hid the ring's glyph behind an opaque disc for a whole round of work. Do not assume Sibling anywhere, and do not "fix" it globally in this plan — that is its own pass.
- **`Active` discipline.** `TextButton`/`ImageButton` always sink touch; `Frame`/`TextLabel` only when `Active = true`. `undoPill` must still never have `Active` assigned.
- **`src/shared` modules hold no Roblox globals** — no `Instance`, `Color3`, `UDim2`, `Enum`, `task`, `os`, `TweenService`, `RunService`.
- **No automated gate loads a client file.** `lune run tests/run` never loads a `.client.luau`; `selene` does not resolve cross-module field types; `stylua` only formats. Reading is the gate. And **`Visible = true` is not the same as pixels on screen** — that substitution is what made a reviewer and the orchestrator both report a glyph as working while it was invisible.
- **Never restart a tween every frame** — use a state latch.
- **Every local declared above its first use**; a forward reference resolves to a nil global.
- selene fails on warnings.
- **Luau gates green:** from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox` run `lune run tests/run`, `stylua --check src tests tools`, `selene src tools`.
- **Server gates green:** from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/server` run `npm test`.
- Use **absolute paths** in every Bash call; the working directory persists between calls.

---

### Task 1: Retract the early splash

**Files:**
- Modify: `roblox/src/shared/DrumStep.luau`
- Modify: `roblox/src/client/DrumController.client.luau`
- Modify: `roblox/src/client/main.client.luau`
- Modify: `roblox/tests/DrumStep.spec.luau`
- Modify: `roblox/src/client/EventBus.luau` (its `NAMES` comment describes the cue)

**Interfaces:**
- Consumes: nothing.
- Produces: `maybeShowReveal` becomes the single drum-rest gate again. Task 5 rebuilds on it.

**Context:** Round four fired the result splash ahead of `drumRest` — first at a fixed 0.7s lead, then refined to a residual-angle trigger. Both violate the rule. The refinement was precisely correct about a question that should never have been asked, which is why the spec records the retraction as a rule rather than a note.

- [ ] **Step 1: Delete the arithmetic**

In `roblox/src/shared/DrumStep.luau`, delete `SPLASH_RESIDUAL_RADIANS` and `glideResidual` together with their comment blocks.

**KEEP** `DrumStep.KICK_OMEGA` and the corrected Hermite characterisation in the header. Both were genuine improvements, independent of the retraction: the kick lived in a client file where a stage attribute could retune it with no test able to see it, and the header previously described a curve the module does not have. Add a line to the header recording that the glide's residual is no longer computed here and why — so the next person does not rebuild it.

- [ ] **Step 2: Delete the cue**

In `roblox/src/client/DrumController.client.luau`, delete:
- the `SPLASH_RESIDUAL` local
- the `settlingFired` latch **and both of its reset points** (beside `glideT0` where `mode = "glide"` is assigned, and in the `gongHit` handler)
- the `EventBus.Cue:Fire({ kind = "drumSettling" })` block inside the glide's still-travelling arm

`drumRest` is untouched. After this, `grep -rn "drumSettling" roblox/src roblox/tests` must return nothing.

Watch for a local left unused by the deletion — selene fails on warnings.

- [ ] **Step 3: Restore the single gate**

In `roblox/src/client/main.client.luau`:
- delete the `drumSettling` and `splashDone` locals
- delete `maybeShowSplash` and fold its `EventBus.Splash:Fire({...})` block back into `maybeShowReveal`, in the position it occupied before round four — after the badge/`revealedRoundId` assignments, guarded by `if p.result then`
- delete the `drumSettling` branch from the `EventBus.Cue` handler; `drumRest` sets only `drumAtRest` again
- delete the `drumSettling` / `splashDone` resets from the `RoundUpdate` handler
- the `REVEAL_SAFETY` fallback sets only `drumAtRest` again
- rewrite the "Two gates, not one" comment block: there is one gate, and it is `drumRest`

Task 5 will move the splash again — but to a different place for a different reason, and starting from the restored state keeps that diff honest.

- [ ] **Step 4: Delete the tests and fix the doc comment**

Remove the `SPLASH_RESIDUAL_RADIANS` / `glideResidual` describe block from `roblox/tests/DrumStep.spec.luau`. Keep every test covering `KICK_OMEGA`, `SETTLE_SECONDS` and the face arithmetic.

In `roblox/src/client/EventBus.luau`, correct the `"Splash"` entry in `NAMES` — it currently describes the `drumSettling` gate.

- [ ] **Step 5: Verify and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
grep -rn "drumSettling\|glideResidual\|SPLASH_RESIDUAL\|splashDone" roblox/src roblox/tests
```
Expected: no output.

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/DrumStep.luau roblox/src/client/DrumController.client.luau \
        roblox/src/client/main.client.luau roblox/tests/DrumStep.spec.luau roblox/src/client/EventBus.luau
git commit -m "revert(roblox): the drum is authoritative — the splash waits for rest"
```

---

### Task 2: Lengthen REVEAL

**Files:**
- Modify: `server/src/index.ts:43`

**Interfaces:**
- Consumes: nothing. Produces: ~2s more runway after the drum rests.

**Context:** Measured live: the drum rests roughly 3.2s into a ~6.2s gap between rounds, leaving 1.8–4.2s — and the beat needs ~2.4s. The owner chose lengthening REVEAL over compressing the ceremony or moving the strike, because the drum's suspense is the part worth protecting.

- [ ] **Step 1: Change the value**

```ts
        revealSeconds: 5,
```

Add a comment above the three phase durations recording why REVEAL is longer than it looks:

```ts
        // REVEAL is 5, not 3: the Roblox arena plays a sequence after the drum stops — the world
        // throw shows in the ring, holds, fades, and only then does the tape tile land (see
        // docs/superpowers/specs/2026-08-04-reveal-beat-design.md). At 3 the drum was resting with
        // as little as 1.8s left and the beat had nowhere to run. The PWA has no drum and simply
        // gets a longer reveal.
```

- [ ] **Step 2: Check nothing assumes 3**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
grep -rn "revealSeconds\|revealMs" server/src src
```
The test fixtures in `server/src/engine/RoundEngine.test.ts`, `socketAdapter.test.ts` and `routes/apiV1.test.ts` supply their own values — leave them. Report anything in the PWA (`src/`) that treats the reveal length as a constant.

- [ ] **Step 3: Run the server suite and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/server && npm test
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add server/src/index.ts
git commit -m "feat(server): REVEAL is five seconds, so the reveal has room to be a sequence"
```

---

### Task 3: RevealBeat — the beat's timings, in one place

**Files:**
- Create: `roblox/src/shared/RevealBeat.luau`
- Create: `roblox/tests/RevealBeat.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, for Tasks 4 and 5:
  - `RevealBeat.HOLD_SECONDS` — how long the glyph sits before it starts to go
  - `RevealBeat.FADE_SECONDS` — how long it takes to go
  - `RevealBeat.TAPE_DELAY_SECONDS` — when the tape tile lands, measured from `drumRest`
  - `RevealBeat.RUNWAY_SECONDS` — the measured budget, for the headroom test

**Context:** Two files must agree about this beat: `main.client.luau` schedules it, `HudController` animates the fade. A duration hand-copied into both is the drift this module exists to prevent. Small, pure, Lune-testable.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/RevealBeat.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RevealBeat = require("../src/shared/RevealBeat")

describe("RevealBeat — the sequence after the drum stops", function()
    test("the glyph gets a real beat, not a flash", function()
        -- The owner asked for "a few seconds". Before this, the glyph lived on leftover time and
        -- measured 3.03s, 1.81s and 4.15s across three consecutive rounds — the variance is what
        -- made it read as absent.
        expect(RevealBeat.HOLD_SECONDS >= 1.5).toBe(true)
        expect(RevealBeat.FADE_SECONDS > 0).toBe(true)
    end)

    test("the tape lands AFTER the glyph has fully gone", function()
        -- THE ORDERING THE WHOLE BEAT EXISTS FOR. The tape tile arriving with the glyph is what
        -- made the glyph invisible: three things in one frame and the smallest loses.
        expect(RevealBeat.TAPE_DELAY_SECONDS).toBe(RevealBeat.HOLD_SECONDS + RevealBeat.FADE_SECONDS)
    end)

    test("the whole beat fits the runway, with headroom", function()
        -- RUNWAY_SECONDS is measured, not guessed: the drum rests ~3.2s into the gap between
        -- rounds, and Task 2 made that gap TALLY(2) + REVEAL(5) = 7s.
        expect(RevealBeat.TAPE_DELAY_SECONDS < RevealBeat.RUNWAY_SECONDS).toBe(true)
        -- Not merely fitting: the tape must be readable before the next round opens.
        expect(RevealBeat.RUNWAY_SECONDS - RevealBeat.TAPE_DELAY_SECONDS >= 1).toBe(true)
    end)

    test("it holds no Roblox globals — numbers only", function()
        for key, value in RevealBeat do
            expect(typeof(key)).toBe("string")
            expect(typeof(value)).toBe("number")
        end
    end)
end)
```

- [ ] **Step 2: Run and watch it fail**

`cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox && lune run tests/run`
Expected: FAIL — the module does not exist.

- [ ] **Step 3: Create the module**

```lua
--!strict
-- THE REVEAL BEAT. What happens after the drum comes fully to rest, and when.
--
-- THE RULE THIS SERVES (owner, 2026-08-04): the drum is authoritative, and must always be fully at
-- rest before the world throw is reflected anywhere else. Everything here is measured from
-- `drumRest` — nothing in this module may ever be used to show something earlier.
--
-- WHY A BEAT AT ALL. The glyph in the ring and the new tape tile used to appear in the same frame,
-- so three things arrived at one instant and the smallest lost — which is why the glyph read as
-- missing even while it was rendering. And its lifetime was leftover time, not a designed span:
-- 3.03s, 1.81s and 4.15s across three consecutive measured rounds, ending abruptly with no fade
-- whenever the next round happened to open.
--
-- TWO FILES MUST AGREE about these numbers — main.client.luau schedules the beat, HudController
-- animates the fade — so they live here rather than as a literal in each. No Roblox globals; this
-- runs under Lune like everything else in src/shared.
local RevealBeat = {}

-- How long the glyph sits before it begins to go. The owner asked for "a few seconds"; this is the
-- first thing to tune at a Studio gate, which is why it is named rather than inline.
RevealBeat.HOLD_SECONDS = 2

-- A real fade, not a Visible toggle. A toggle is what it did before, and part of why it read as a
-- flicker rather than a reveal.
RevealBeat.FADE_SECONDS = 0.4

-- When the tape tile lands, measured from drumRest. AFTER the glyph is fully gone — the tape is the
-- round's RECORD, and a record arriving with the announcement is what buried the announcement.
RevealBeat.TAPE_DELAY_SECONDS = RevealBeat.HOLD_SECONDS + RevealBeat.FADE_SECONDS

-- How much time actually exists after the drum stops, MEASURED (Studio, 2026-08-04) rather than
-- derived: the drum rests ~3.2s into the gap between rounds, and that gap is TALLY(2) + REVEAL(5)
-- = 7s once the server change lands. Held here only so the spec test can assert the beat fits with
-- room to read the tape afterwards. If the server's phase durations change, this changes with them.
RevealBeat.RUNWAY_SECONDS = 3.8

return RevealBeat
```

- [ ] **Step 4: Run, then verify the ordering test is not vacuous**

`lune run tests/run` — expected: PASS.

Then set `TAPE_DELAY_SECONDS = RevealBeat.HOLD_SECONDS` (i.e. the tape landing mid-fade) and re-run. Expected: the ordering test fails. Restore. Quote the output in your report — that test is the entire point of the module and nothing else can catch it.

- [ ] **Step 5: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RevealBeat.luau roblox/tests/RevealBeat.spec.luau
git commit -m "feat(roblox): the reveal beat's timings, where both files can see them"
```

---

### Task 4: The ring's glyph becomes a fadeable group

**Files:**
- Modify: `roblox/src/client/HudController.client.luau` — the `ringGlyphs` construction and the glyph swap in `render`

**Interfaces:**
- Consumes: `RevealBeat.FADE_SECONDS` from Task 3; `aux.worldThrow` and a new `aux.worldThrowFading` from Task 5.
- Produces: a ring glyph that fades rather than blinking out.

**Context:** Two things are wrong with the current glyph. It disappears with a `Visible` toggle, and it was invisible entirely until a fix earlier today — its `ImageLabel`s sat at the default ZIndex 1 behind an opaque ZIndex-4 disc, because this ScreenGui runs in **Global** `ZIndexBehavior` where a child does not draw above its parent.

`Glyphs.renderGroup` already exists for precisely this fade problem — its own comment says the lanterns need it "because tweening two ImageLabels independently drifts them out of step at the edges of the fade". It returns a `CanvasGroup`, which composites its descendants as one element, so a single `GroupTransparency` drives the fade **and** the ZIndex trap disappears: only the group's own ZIndex matters.

- [ ] **Step 1: Build the glyphs as groups**

Replace the ring's glyph block. The current version lifts each layer's ZIndex by hand (today's fix); the `CanvasGroup` makes that unnecessary — one ZIndex on the group covers it.

```lua
local ringGlyphs: { [string]: CanvasGroup } = {}
do
    local box = glyphBox(ringDisc, 0.82)
    box.ZIndex = 5 -- with the digits, above the disc
    for _, sym in THROWS do
        -- A CanvasGroup, not `Glyphs.render`'s bare frame, for two reasons that happen to have the
        -- same fix. It gives ONE `GroupTransparency` to fade — `Glyphs.renderGroup` exists because
        -- tweening the outline and core independently drifts them out of step at the edges.
        --
        -- And it closes the ZIndex trap that hid this glyph completely (2026-08-04): this ScreenGui
        -- runs in GLOBAL ZIndexBehavior, where a child does NOT draw above its parent, so the
        -- default-ZIndex-1 image layers rendered behind the opaque ZIndex-4 disc. A CanvasGroup
        -- composites its descendants as a single element, so only ITS ZIndex matters.
        --
        -- THE OUTLINE COLOUR IS PASSED EXPLICITLY, and it must be. The two builders disagree on
        -- their default: `render` falls back to WHITE, `renderGroup` falls back to the CORE colour.
        -- The ring has always had a white keyline (measured live: the outline layer renders at
        -- 1,1,1), so swapping builders without this argument would silently flatten the glyph to a
        -- single cream shape — a visual regression no gate could see.
        local g = Glyphs.renderGroup(box, sym, INK_CREAM, Color3.new(1, 1, 1))
        g.ZIndex = 5
        g.GroupTransparency = 1
        g.Visible = false
        ringGlyphs[sym] = g
    end
end
```

`Glyphs.renderGroup(parent, symbol, coreColor, outlineColor?)` returns the `CanvasGroup` already parented to `parent` — same parameter order as `render`. `LanternController` is the existing caller if you want a reference use.

- [ ] **Step 2: Drive the fade**

Replace the glyph swap in `render`:

```lua
    for _, sym in THROWS do
        ringGlyphs[sym].Visible = sym == worldThrow
    end
```

with a latched fade. Add above `render`:

```lua
-- The glyph's own fade. LATCHED on the (symbol, fading) pair, because `render` runs at 10Hz and a
-- tween cancelled and restarted on every repaint gets a few percent of its travel and renders
-- static — the failure `setBank`'s pulse already had once in this file.
local shownGlyph: string? = nil
local glyphFading = false
local glyphTween: Tween? = nil

local function setRingGlyph(symbol: string?, fading: boolean)
    if symbol == shownGlyph and fading == glyphFading then
        return
    end
    shownGlyph, glyphFading = symbol, fading
    if glyphTween then
        glyphTween:Cancel()
        glyphTween = nil
    end
    for _, sym in THROWS do
        ringGlyphs[sym].Visible = sym == symbol
    end
    if symbol == nil then
        return
    end
    local g = ringGlyphs[symbol]
    if fading then
        glyphTween = TweenService:Create(
            g,
            TweenInfo.new(RevealBeat.FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { GroupTransparency = 1 }
        )
        glyphTween:Play()
    else
        g.GroupTransparency = 0 -- it arrives instantly; the drum was the build-up
    end
end
```

and call it in `render` where the swap used to be:

```lua
    setRingGlyph(worldThrow, aux.worldThrowFading == true)
```

Add `RevealBeat` to the file's requires, beside the other `src/shared` modules.

- [ ] **Step 3: The standing check for client files**

No gate loads this file, and **`Visible = true` is not pixels** — that mistake is exactly what let the invisible glyph be reported as working. So:

1. Every `RevealBeat.X` and `aux.X` read resolves to something those modules actually export — `worldThrowFading` arrives in Task 5, so note it as expected-missing until then.
2. `RevealBeat`, `TweenService`, `THROWS`, `ringGlyphs` and `glyphBox` are all declared above their first use. Give line numbers.
3. `ringGlyphs` is typed `CanvasGroup`, not `Frame`, everywhere it is referenced.
4. The group's `ZIndex` is set — under Global it is the only thing keeping the glyph in front of the disc.
5. Nothing else in the ring moved: the pie layers, the disc's opacity, `ringCount`'s ZIndex 5.

- [ ] **Step 4: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the ring's glyph fades, and stops hiding behind its own disc"
```

---

### Task 5: Sequence the beat

**Files:**
- Modify: `roblox/src/client/main.client.luau`

**Interfaces:**
- Consumes: `RevealBeat` from Task 3; the fade driver from Task 4.
- Produces: `aux.worldThrowFading`, published alongside `aux.worldThrow`.

**Context:** The two things that must now happen at different times already live in two different variables, set on adjacent lines inside `maybeShowReveal`:

- `revealedWorldThrow = p.worldThrow` — makes the ring show the glyph
- `revealedRoundId = p.roundId` — un-gates the newest tape entry in `visibleTape()`

Separating them in time *is* the feature. `badgeById[p.roundId] = p.result` carries the tape tile's outcome and moves with the tape.

- [ ] **Step 1: Split the gate in time**

In `maybeShowReveal`, at `drumRest`, keep immediately:
- `lastRound = {...}` (the ledger's LAST ROUND band — a separate screen, no spoiler risk, and the rule is satisfied because the drum has stopped)
- `revealedWorldThrow = p.worldThrow`
- the splash fire
- the first-win onboarding beat
- `publish()` / `publishLedger()`

**Defer** to `RevealBeat.TAPE_DELAY_SECONDS` after rest:
- `badgeById[p.roundId] = p.result`
- `revealedRoundId = p.roundId`
- clearing `revealedWorldThrow`
- a `publish()` so the tape and the ring both repaint

And schedule the fade to begin at `RevealBeat.HOLD_SECONDS`, by setting a `worldThrowFading` flag and publishing.

Use a generation counter, the same shape `plateGen` uses in `HudController`, so a superseded beat's scheduled work is discarded rather than firing late:

```lua
local beatGen = 0
local worldThrowFading = false
```

Increment `beatGen` at the start of every beat, capture it in each `task.delay`, and return early when it no longer matches.

- [ ] **Step 2: Publish the fade flag**

Add `worldThrowFading = worldThrowFading` to the `aux` table in `publish()`, beside `worldThrow`. Update the `aux` contract comment at the top of both `main.client.luau` and `HudController.client.luau` — that comment block is the only description of this interface and a stale one has cost this project a round before.

- [ ] **Step 3: The collapse path**

**This is the part no gate can see and the part that must not lose a tape tile.**

In the `RoundUpdate` handler's ACTIVE branch — which already clears `pendingReveal`, `drumAtRest` and `revealedWorldThrow` — the beat must collapse immediately and in order if it is still running:

- release the tape **now**: set `badgeById` and `revealedRoundId` for the round that was mid-beat
- clear `revealedWorldThrow` and `worldThrowFading`
- invalidate `beatGen` so the pending `task.delay`s do nothing

The ring returns to being a clock because `revealedWorldThrow` is nil and `ACTIVE` restores the countdown.

You will need the round id and result of the beat in flight — hold them in a small local record set when the beat starts and cleared when it completes or collapses. **Do not reach back into `pendingReveal`**: `maybeShowReveal` nils it, and a collapse that found nil would silently drop the tile.

State in your report exactly what happens, in order, when ACTIVE arrives (a) before the fade starts, (b) mid-fade, (c) after the tape has already landed.

- [ ] **Step 4: The standing check for client files**

1. `EventBus.Splash:Fire` appears exactly once.
2. Every `RevealBeat.X` read resolves; `RevealBeat` is required.
3. Every new local is declared above its first use.
4. `visibleTape()`'s spoiler skip still keys on `currentRoundId ~= revealedRoundId` — unchanged, and now it is what holds the tile back during the beat rather than during the spin.
5. Trace one full round and confirm **the tape tile is emitted exactly once** on every path: normal completion, collapse before the fade, collapse mid-fade, and a dropped `drumRest` releasing through `REVEAL_SAFETY`.

- [ ] **Step 5: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/main.client.luau
git commit -m "feat(roblox): the world throw shows, holds, fades, and only then goes on the tape"
```

---

## After the last task

Hand back for the owner's Studio gate. Nothing in this plan is verifiable by any automated gate, and the central item is one that was twice reported as working while invisible — so the gate is the only real check.

What needs eyes:

- **Does the glyph actually appear?** Not "is it Visible" — does a cream R/P/S show on the dark disc when the drum stops. This is the whole point.
- Does it hold long enough to register, and does the fade read as a fade?
- Does the tape tile land **after** the glyph has gone, as a separate beat?
- Does the splash still feel right arriving with the glyph rather than before it?
- The longer round: 27s instead of 25s. Does the reveal feel paced or slow?
- On a slow reveal, does the tape tile still land? That is the collapse path, and a missing tile is a permanent hole in the tape.

**Do not push without telling the owner first** — every push to `m4b-zendojo-art-pass` auto-deploys the `roshambo_server_dev` App Runner service, and this round changes a server-side phase duration, so the restart will also change round pacing under any live session.
