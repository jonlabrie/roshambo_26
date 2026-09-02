---
shelf: program
status: parked
updated: 2026-09-04
checked: 2026-09-04
---

# Parked Defects

Defects known and deliberately parked rather than fixed. (a)–(c) are parked at item 6 of
[[friends-family-baseline]] by owner direction (2026-08-02: "log them for item 6").
Every code claim below was re-verified against the working tree on **2026-08-27**, and every
one is still present.
⚠ **LINE NUMBERS HAVE BEEN REMOVED — they were wrong in 8 of 9 citations** while the page
carried a `checked:` stamp asserting a re-read. Symbol names survive a refactor; line numbers do
not, and a stale one sends a reader to unrelated code and quietly costs their trust in the page
(schema rule 9). Grep for the named route or symbol.

## (a) `POST /players/:id/purchase` is a read-modify-write race

- **Where:** `server/src/routes/apiV1.ts`, `POST /players/:robloxUserId/purchase`: `resolveUser` →
  `readEconomy` → `validatePurchase` → `applyPurchase` → `user.save()`. No
  `optimisticConcurrency`, `$inc`, or conditional `findOneAndUpdate`.
- **Repro:** a retry or double-tap lets two purchases both read the pre-purchase balance;
  the second `save()` overwrites — two items for one item's points.
- **Fix sketch:** conditional atomic update,
  `findOneAndUpdate({_id, totalPoints:{$gte:price}}, {$inc:{totalPoints:-price}})`. The
  pattern already exists in this file: `POST /players/:robloxUserId/fireworks/spend` does exactly
  this, and its own comment indicts `/purchase` ("The existing /purchase route's
  read-then-save pattern would let both read 1 and both write 0").
- Verified present 2026-08-27. Behind `requireApiKey`.

## (b) `PUT /players/:id/decorations` never checks ownership

- **Where:** `apiV1.ts`, `PUT /players/:robloxUserId/decorations` — `validateDecorations`
  (`server/src/loadout.ts`) checks
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
- Verified present 2026-08-27.

## (c) `RESOLVE_FAILED` returns 500 (minor)

Thirteen sites in `apiV1.ts` answer a `resolveUser` miss with
`res.status(500).json({ error: 'RESOLVE_FAILED' })`. It is a client condition and will
bury real 500s in logs. Fix: a 4xx. Verified present 2026-08-27.

## (d) Onboarding empty-card layout defect — CONFIRM FIRST

- **Symptom** (owner, 2026-08-05, published place, Android, fresh device account): large,
  mostly-empty toast/card windows repeatedly opening, sometimes with a glyph.
- **Diagnosis (plausible, unconfirmed):** `OnboardingController.client.luau` builds
  `card.Size = UDim2.fromOffset(220, 0)` with `AutomaticSize` for height and
  `copyLabel.Size = UDim2.fromScale(1, 0)` likewise; `MIN_CARD_H = 90` is by
  its own comment the floor "before AutomaticSize has laid out even once". If the copy
  label never lays out, the result is a 220×90 empty box — exactly the report. Code state verified 2026-08-27.
- **Why never seen before:** beats fire off a SERVER-side has-seen flag, so any account
  that has played has them all marked seen; a fresh account makes every beat eligible at
  once.
- **Confirm first, then fix:** open the published place on an account that HAS played —
  the cards should not appear. Do not fix before confirming.
- **Weight:** every F&F guest is a first-time player on a fresh account, so every guest
  would hit this. The content/pacing design pass is separate — see [[backlog]].

## (e) TEST_MODE world-throw phase is seeded from a document count

- **Where:** `server/src/index.ts`, `pickWorldThrow` — `TEST_MODE ? THROWS[roundCount % 3] : random`;
  `roundCount` is in-memory on `RoundEngine`, seeded at boot from
  `await Round.countDocuments()` (`makeEngine(totalRounds)`, "legacy roundCount continuity").
  Verified present 2026-08-27.
- **Effect:** the cycle's phase is a function of how many round documents exist, not of
  where the previous process left off; the two drift (rounds tick regardless, documents
  only exist once persisted). Every deploy restarts the process and re-seeds the phase —
  a shift of 3 (or 0) lands the same face twice. Observed 2026-08-03 on dev (two Papers
  in a row), most plausibly a 21:43 auto-deploy under the owner mid-play.
- **Check first:** restart `roshambo_server_dev` cleanly with nobody playing and watch
  several cycles; if R→P→S holds, the duplicate was the redeploy.
- **Fix sketch:** derive the phase from a wall-clock epoch or a genuinely persisted
  counter. TEST_MODE/demo-only.
  ⚠ **The warning that used to sit here — "every push auto-deploys dev, so warn the owner before
  pushing while they are in Studio" — is FALSE since 2026-08-25**, when both AWS auto-deploys were
  switched off by owner ruling ([[deploy]], verified live 2026-08-27). A push now disturbs nothing.
  The hazard inverted: reaching dev takes an explicit `start-deployment`, so the new way to lose an
  hour is testing the PREVIOUS build and believing it is the new one.

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
- **Adjacent live hazard, verified still present 2026-08-27:** `pollOnce()` runs in a
  bare `task.spawn` loop with no `pcall` (`roblox/src/server/main.server.luau`, the `coordinator:pollOnce()` loop)
  — one throw kills the round loop until restart, and a server/place duration-shape
  mismatch throws on the FIRST poll. Server and place must move together: push → wait for
  App Runner → re-sync Rojo → start a FRESH Studio session.
- spec: `docs/superpowers/specs/2026-08-04-round-structure-design.md`

## (i) Adding `roblox` to `/auth/sso` would E11000 at login — and the obvious fix merges the wallets

- **Where:** `server/src/routes/auth.ts`, the `/sso` link path. It finds a user by email or
  deviceId and writes the provider id onto THAT document. `robloxId` carries a
  `unique, sparse` index and the game server's document already holds it, so linking a PWA
  guest to their Roblox account throws **E11000 duplicate key**, uncaught, as a 500 at login —
  hitting exactly the players who use both platforms.
- ⚠ **The severity is not the 500. It is the repair.** "Resolve to the existing Roblox document
  instead" clears the error and silently merges the two wallets — the thing `ef6ced9` ruled
  non-viable under Roblox policy, shipped as a bugfix. Merging is a one-way door: afterwards
  there is no honest answer to whose points are whose.
- **Not a live defect.** `/auth/sso` is stubbed, has no `roblox` provider, and its own comment
  says the client has never called it. This is a **GATE on future work**, recorded because the
  trap is invisible at the moment someone adds a fifth provider. See [[identity]], [[data]].
- **Before any of it:** rule the wallet. Either per-platform balances on one document
  (`identityTier` is the seam), or a standing decision that one human means one wallet and
  Robux therefore never buys points.

## (j) PWA identities can vote in the World Throw — GATE on enabling the PWA

- **What:** both platforms feed one tally and a PWA identity is free, so a farm holding ~N/3 of a
  round decides the World Throw for everyone in it. Full trace on [[identity]].
- **Why parked, not fixed:** it is inert until TEST_MODE goes off AND a PWA population exists.
  Owner 2026-08-27: **Roblox launches first, PWA not enabled at launch.** Designing a defence now
  would be building ahead of the constraint.
- **⚠ THE GATE, so it cannot be forgotten:** do not enable the PWA against a non-TEST_MODE
  backend until this is answered. Either condition alone is safe; together they are not.
- **Partial mitigation shipped 2026-08-27:** per-connection `CLAIM_LIMIT` of 3 — a floor against
  unauthenticated Atlas writes, not a sybil defence.
- **The shape of the answer**, if it helps whoever picks this up: earned enfranchisement plus
  cohort detection, gating the VOTE rather than the account. Proof-of-work rejected — regressive
  on the weakest device, and this is kid-first on phones.

## ~~(k) `JWT_SECRET` was a project-named placeholder in SSM~~ ROTATED 2026-08-27

- **Found 2026-08-27** by length: `/roshambo/dev/JWT_SECRET` was 26 characters, matching the
  placeholder in `server/.env` exactly.
- **Blast radius:** that key signs BOTH device tokens and user JWTs. A guessable key means forging
  `{ typ: 'device', did: <any victim> }`, which the handshake trusts completely — read the
  account, throw as it, rename it, bank its pot. ⚠ **This is the vulnerability the 2026-08-18
  hard cut closed, reopened by a weak key.** The mechanism was right; a signature is only worth
  its secret.
- ⚠ **PROD WAS FINE — 64 characters, properly generated. ONLY DEV CARRIED THE PLACEHOLDER, AND
  DEV IS THE SERVICE THAT SERVES THE PUBLIC.** Amplify's `VITE_SOCKET_URL` points at
  `roshambo_server_dev`; `roshambo_server` has been PAUSED since 2026-08-18 and serves nothing
  ([[deploy]]). So the weak key was on the internet-facing backend behind playroshambo.com and
  the strong key was on the service nobody can reach. ⚠ **An initial severity call of "it is only
  dev" was reasoning from the NAME rather than from where traffic goes** — corrected the same day.
- **Why only dev:** prod's `/roshambo/*` tree was created from `README_DEPLOY.md`; dev cannot inherit
  it (configured through the App Runner API rather than `apprunner.yaml`) so `/roshambo/dev/*` was
  created by hand, and the `.env` placeholder went in with it. **The deliberate split of the
  secret trees is exactly why prod's discipline never reached dev.**
- **Measured, not alarmist:** the key is not published, so it needs a targeted guess rather than a
  brute force, and both environments run TEST_MODE.
- **CLOSED 2026-08-27.** Owner rotated `/roshambo/dev/JWT_SECRET` and ran `start-deployment`;
  the service reached RUNNING and was verified live — socket.io handshake 200, and
  `/api/v1/stats/records` returning real rows. The same deploy carried the `CLAIM_LIMIT` cap.
  Prod needed nothing: its key was 64 characters and properly generated.
- ⚠ **Rotation degraded gracefully, which was NOT obvious and was checked rather than assumed.**
  The handshake middleware `catch`es an unverifiable device token, logs it, and calls `next()` —
  so the socket connects without a deviceId instead of being rejected; the server then emits
  `device-required` and `useGameLoop` re-emits `claim-device`. A returning player sees a working
  app, not an error. **The cost is the intended one and only that:** their old identity is
  orphaned, so guest points and streaks are gone — the same hard cut as 2026-08-18.

_(h) — the World Throw picked at random — was FIXED 2026-08-16, see [[world-throw]] and
`log.md`. It is deliberately NOT active in any deployed environment yet: both prod and dev
run `TEST_MODE`, which keeps the R→P→S cycle. Defect (e) therefore still stands._

## (l) tsukubai renders lying on its side — rolled-PrimaryPart PivotTo bug (2026-09-04)

- **Where:** `roblox/src/shared/DecorationCatalog.luau`, the `tsukubai` builder: `basin` is a
  cylinder stood up with `CFrame.Angles(0, 0, rad(90))` AND set as `PrimaryPart`;
  `TreatmentApplier._buildDecorations` places via `model:PivotTo(...)`, which aligns by the
  PrimaryPart's rolled frame — un-rotating the whole prop flat, exactly the mortar-tube bug
  fixed at the 2026-09-04 gate (`9d3cd3c`). The ishidoro escapes it (unrotated Block PrimaryPart).
- **Fix sketch:** one line, same shape as the mortar fix: `basin.PivotOffset =
  basin.CFrame:Inverse()` in the builder. Owner was offered the fix mid-gate and deferred.

## (m) proving-range tube bores a hair undersized under the bore-is-inner ruling (2026-09-04)

- **Where:** `roblox/tools/builders/ProvingGround.luau` `TUBE*_SIZE` — outer diameter = bore.
  The 2026-09-04 owner ruling (deck mortars): 2"/4"/6" are INNER diameters; the deck tubes
  hollow at true bore with a 0.06 wall AROUND it. The proving racks' solid tubes read ~11%
  thin by comparison. Cosmetic; fixing means re-running the model bake.

## (n) bootstrap PlayerAdded handlers have no catch-up for players already present (2026-09-04)

- **Where:** `roblox/src/server/main.server.luau` — none of the `Players.PlayerAdded:Connect`
  sites iterate `Players:GetPlayers()` after connecting. Any yield added to top-level bootstrap
  ABOVE a connect re-opens the window where a fast join is silently missed (dead session: no
  claim, no economy). The mortar CSG build was the first to hit it (fixed by deferring the
  yield, `d510c69`); the structural fragility remains.
- **Fix sketch:** after each connect, loop existing players through the same handler (idempotent
  guards where needed), the standard Roblox join-race idiom.
