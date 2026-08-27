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
