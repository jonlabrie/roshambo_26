# Task 3 report: RevealBeat

## Status

Complete. Commit `19eacb7` on `m4b-zendojo-art-pass`.

## Module as built

`roblox/src/shared/RevealBeat.luau` (verbatim from the brief, no changes):

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

`roblox/tests/RevealBeat.spec.luau` was created verbatim from the brief (four tests: real beat not
a flash, tape-lands-after-glyph ordering, runway headroom, no-Roblox-globals shape check).

## Step 2 — failing before the module existed

```
error requiring module "../src/shared/RevealBeat": could not resolve child component "RevealBeat"
[Stack Begin]
    Script '[C]' - function 'proxyrequire'
    Script '__mlua_require', Line 13
    Script '/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/RevealBeat.spec', Line 4
[Stack End]
```
Confirms the test was exercising real absence of the module, not a typo.

## Step 3 — green after the module was created

```
984 passed, 0 failed, 984 total
```
(Two unrelated `[WARN]` lines about a queue-full/handler-error fixture appear on every run in this
suite — pre-existing noise from `HandlerQueue.spec`, not related to this change.)

## Step 4 — mutation test (the point of the task)

Set `RevealBeat.TAPE_DELAY_SECONDS = RevealBeat.HOLD_SECONDS` (tape landing mid-fade, dropping the
`+ FADE_SECONDS` term) and reran:

```
FAIL  RevealBeat — the sequence after the drum stops > the tape lands AFTER the glyph has fully gone
      /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/RevealBeat.spec:18: expected 2 to be 2.4
983 passed, 1 failed, 984 total
```

The ordering test caught the regression exactly as intended: `TAPE_DELAY_SECONDS` (2) no longer
equalled `HOLD_SECONDS + FADE_SECONDS` (2.4). Restored the line and reran — back to
`984 passed, 0 failed, 984 total`.

## Gates (final state, module restored)

```
$ lune run tests/run
984 passed, 0 failed, 984 total

$ stylua --check src tests tools
(no output — OK)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

All three gates green.

## Commit

```
19eacb7 feat(roblox): the reveal beat's timings, where both files can see them
 2 files changed, 72 insertions(+)
 create mode 100644 roblox/src/shared/RevealBeat.luau
 create mode 100644 roblox/tests/RevealBeat.spec.luau
```
Not pushed, per instructions.

## Concerns

None. The mutation test behaved exactly as the brief predicted — it is not vacuous, and it is
genuinely the only place in the codebase that can catch a drift in this ordering, since neither
`main.client.luau` nor `HudController.client.luau` is under test. `RUNWAY_SECONDS = 3.8` was kept
as a literal measured value with its provenance comment intact, per the explicit instruction not to
derive it from a formula.
