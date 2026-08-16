---
shelf: program
status: parked
updated: 2026-08-16
---

# Parked Defects

Defects known and deliberately parked rather than fixed. (a)–(c) are parked at item 6 of
[[friends-family-baseline]] by owner direction (2026-08-02: "log them for item 6").
Every code claim below was re-verified against the working tree on 2026-08-15.

## (a) `POST /players/:id/purchase` is a read-modify-write race

- **Where:** `server/src/routes/apiV1.ts` (route at line 286): `resolveUser` →
  `readEconomy` → `validatePurchase` → `applyPurchase` → `user.save()`. No
  `optimisticConcurrency`, `$inc`, or conditional `findOneAndUpdate`.
- **Repro:** a retry or double-tap lets two purchases both read the pre-purchase balance;
  the second `save()` overwrites — two items for one item's points.
- **Fix sketch:** conditional atomic update,
  `findOneAndUpdate({_id, totalPoints:{$gte:price}}, {$inc:{totalPoints:-price}})`. The
  pattern already exists in this file: `POST /fireworks/spend` (line 274) does exactly
  this, and its own comment indicts `/purchase` ("The existing /purchase route's
  read-then-save pattern would let both read 1 and both write 0").
- Verified present 2026-08-15. Behind `requireApiKey`.

## (b) `PUT /players/:id/decorations` never checks ownership

- **Where:** `apiV1.ts:356` — `validateDecorations` (`server/src/loadout.ts:58`) checks
  shape only (unknown keys, unique ids, propId in catalog, offset bounds, facing), then
  the list is assigned wholesale to `user.deckDecorations`. Nothing verifies the props
  were bought.
- **Reachability (now traced):** the in-game flow never exercises the hole —
  `roblox/src/server/main.server.luau` `SetDecorationPlacement`/`SetDecorationRemove`
  handlers (from line 1741) build the new list server-side from the player's own stash
  before calling `net:setDecorations`. So this is an API-surface hole reachable by any
  `X-API-Key` holder, not by players.
- **Fix sketch:** accept only lists whose ids were minted by `/purchase`
  (`nextDecorationId`/`appendDecoration`), or reject additions of unowned props.
- Verified present 2026-08-15.

## (c) `RESOLVE_FAILED` returns 500 (minor)

Thirteen sites in `apiV1.ts` (lines 118–391) answer a `resolveUser` miss with
`res.status(500).json({ error: 'RESOLVE_FAILED' })`. It is a client condition and will
bury real 500s in logs. Fix: a 4xx. Verified present 2026-08-15.

## (d) Onboarding empty-card layout defect — CONFIRM FIRST

- **Symptom** (owner, 2026-08-05, published place, Android, fresh device account): large,
  mostly-empty toast/card windows repeatedly opening, sometimes with a glyph.
- **Diagnosis (plausible, unconfirmed):** `OnboardingController.client.luau` builds
  `card.Size = UDim2.fromOffset(220, 0)` with `AutomaticSize` for height and
  `copyLabel.Size = UDim2.fromScale(1, 0)` likewise; `MIN_CARD_H = 90` (line 242) is by
  its own comment the floor "before AutomaticSize has laid out even once". If the copy
  label never lays out, the result is a 220×90 empty box — exactly the report. Code state
  verified 2026-08-15.
- **Why never seen before:** beats fire off a SERVER-side has-seen flag, so any account
  that has played has them all marked seen; a fresh account makes every beat eligible at
  once.
- **Confirm first, then fix:** open the published place on an account that HAS played —
  the cards should not appear. Do not fix before confirming.
- **Weight:** every F&F guest is a first-time player on a fresh account, so every guest
  would hit this. The content/pacing design pass is separate — see [[backlog]].

## (e) TEST_MODE world-throw phase is seeded from a document count

- **Where:** `server/src/index.ts:68` — `TEST_MODE ? THROWS[roundCount % 3] : random`;
  `roundCount` is in-memory on `RoundEngine`, seeded at boot from
  `await Round.countDocuments()` (`index.ts:92-93`, "legacy roundCount continuity").
  Verified present 2026-08-15.
- **Effect:** the cycle's phase is a function of how many round documents exist, not of
  where the previous process left off; the two drift (rounds tick regardless, documents
  only exist once persisted). Every deploy restarts the process and re-seeds the phase —
  a shift of 3 (or 0) lands the same face twice. Observed 2026-08-03 on dev (two Papers
  in a row), most plausibly a 21:43 auto-deploy under the owner mid-play.
- **Check first:** restart `roshambo_server_dev` cleanly with nobody playing and watch
  several cycles; if R→P→S holds, the duplicate was the redeploy.
- **Fix sketch:** derive the phase from a wall-clock epoch or a genuinely persisted
  counter. TEST_MODE/demo-only — but every push to the working branch auto-deploys dev,
  so warn the owner before pushing while they are in Studio.

## (f) Ledger did not open on a synthetic plate click — cause undetermined

From the play-HUD round-three Studio gate (2026-08-05): the ledger panel failed to open
on a synthetic plate click and the cause was NOT determined. **Do not fix on a guess** —
reproduce and diagnose first. (Precedent from the same feature: an earlier ledger defect
was an *absent caller* — `EventBus.OpenLedger` had two listeners and zero firing sites —
which no test can see.)

## (g) Round structure: the offset-by-one diagnosis, and the accepted reveal-timing residual

- **The diagnosis (fixed 2026-08-05, `830d2b8..00bf8f8` — now OPEN 51 / LOCK 2 /
  REVEAL 7), kept so it is never re-derived:** the old phase names were offset by one
  from the events. `ACTIVE` was 18s of throwing + 2s lockout with the world throw chosen
  at its end; `TALLY` tallied nothing (`countThrows()` is a sync loop — microseconds);
  `REVEAL` was shorter than the drum's 3.45s settle, so the drum never finished inside
  its own phase. The jitter is in settlement (Mongo), not scheduling — two independent
  clocks.
- **The parked residual, accepted ship-and-watch:** the world throw is decided at the end
  of LOCK, so the payload lands 0–1.25s AFTER the bell against the drum's 1.45s commit
  deadline. `DrumStep.STALL_MAX` covers the overrun; worst case the drum lands on the
  WRONG FACE (`lastLandedThrow or "R"`). The tell is the glyph disagreeing with the tape
  tile or result toast — a stall alone just looks like a longer spin. Stage 2
  (MessagingService push) is the designed fix; its unresolved blocker: Open Cloud
  MessagingService generally does NOT deliver to Studio sessions — spike that before
  estimating.
- **Adjacent live hazard, verified still present 2026-08-15:** `pollOnce()` runs in a
  bare `task.spawn` loop with no `pcall` (`roblox/src/server/main.server.luau:2038-2043`)
  — one throw kills the round loop until restart, and a server/place duration-shape
  mismatch throws on the FIRST poll. Server and place must move together: push → wait for
  App Runner → re-sync Rojo → start a FRESH Studio session.
- spec: `docs/superpowers/specs/2026-08-04-round-structure-design.md`

## (h) The World Throw is picked at random, not by majority — PREMISE-BREAKING

- **Where:** `server/src/engine/RoundEngine.ts` picks the World Throw randomly;
  `TEST_MODE=true` substitutes a deterministic R→P→S cycle (dev, and the
  playroshambo.com demo).
- **Why it matters:** the product premise is "you against the world" — the World Throw
  is meant to be the MAJORITY of player throws (see [[world-throw]]). Random play makes
  the last-five-rounds HUD information-free, turns crowd-reading from skill into
  fortune, and invalidates any leaderboard built on the assumption that outcomes
  reflect judgement. This is not a cosmetic defect; it is the game.
- **Fix sketch:** the data is already there — `Round.distribution` persists the per-round
  R/P/S split. Settlement should derive the World Throw as the argmax of that
  distribution, with an explicit, documented tie-break rule and a decision about the
  degenerate low-population case (a round with 1–2 players). Note this SUPERSEDES (e):
  once the majority rule lands, the TEST_MODE cycle it describes is dead code.
- **Owner, 2026-08-16:** *"in production the world throw is the majority choice… we have
  to successfully embody 'the majority' as a worthwhile opponent or we'll fail
  entirely."*
- ⚠ Not yet scheduled against a program item.
