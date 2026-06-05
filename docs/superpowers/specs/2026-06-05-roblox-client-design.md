# Roblox Roshambo Client — Design

**Date:** 2026-06-05
**Status:** Approved pending final review

## 1. Goals & Non-Goals

**Goals**

- A Roblox experience where players join the **same global rounds** as PWA players. The existing Node server remains the single authority for round lifecycle, World Throw, and all scoring.
- A **social 3D arena**, scoped small: one room where avatars hang out, chat, and plot between rounds, with theatrical win/loss feedback. Dwell time is the monetization (Roblox Creator Rewards pays on engagement time of Active Spenders) — no Robux products at launch, **no gambling mechanics of any kind**.
- A dev/deploy environment supporting **TDD and git end-to-end** (the developer is new to Roblox; setup is greenfield on macOS).

**Non-goals (deferred, but designed-for)**

- "Sign in with Roblox" web OAuth linking — schema is ready; web flow built later.
- Vote-derived World Throw (the patented mechanic) — protocol supports it from day one; the tally function stays random/TEST_MODE until flipped.
- Robux cosmetics/merch — researched later; Creator Rewards accrues passively meanwhile.
- 10k-server scale infrastructure — the protocol is herd-safe now; state externalization (Redis, CDN, horizontal API tier) is flagged future work, deferred not foreclosed.
- PWA visual refresh ("shared theater" + Roblox avatars for linked players) — future milestone after OAuth linking.

## 2. System Architecture — one brain

```
PWA clients ──Socket.io──┐
                         ├──► Node server (App Runner) ──► MongoDB Atlas
Roblox game servers ─HTTPS┘         ▲
   ▲ RemoteEvents                   │ one RoundEngine drives both transports
Roblox players
```

- **Node = sole authority**: round lifecycle, World Throw, every player's points/streaks/pots, both platforms. There is deliberately **no second brain** on the Roblox side — Roblox-native cross-server services (MemoryStore, MessagingService) are reserved as *future traffic optimizations*, never as a source of truth. (Rationale: scoring requires per-player throws anyway; splitting authority duplicates the points engine in Luau and has already failed once in this codebase as client/server rule drift.)
- **Roblox game servers = trusted reporters/renderers.** They collect picks via RemoteEvents, batch-submit per-player throws to Node, and render reveals. They compute WIN/SAFE/LOSS locally (mirrored `GameRules`) for instant theater, but treat Node's numbers as truth via deferred reconciliation.
- **Roblox clients never talk to Node** — only to their own game server. The API key never reaches clients.
- **Round phase machine** (replaces the current instantaneous flip inside one `setInterval` tick):

  `ACTIVE (20s) → TALLY (~2s) → REVEAL (~3s) → next ACTIVE`

  TALLY is the slack that makes a future vote-derived World Throw feasible across platforms; REVEAL is the drumroll. The PWA receives the same phases over Socket.io (its reveal animation already takes ~3s, so this formalizes existing behavior).

## 3. Identity & Sybil Posture

- Roblox players are keyed by **Roblox UserId**, arriving server-to-server — a high-friction, platform-policed identity. New `User` fields: `robloxId` (unique, sparse — same pattern as `googleId`), `identityTier: 'guest' | 'email' | 'roblox'`, and `PlayerRound.platform`.
- `identityTier` is the hook for the future vote-derived World Throw: vote eligibility/weight by tier (`guest deviceId < email < roblox`), since PWA guest deviceIds are trivially Sybil-able.
- **Portability later, compliantly**: "Sign in with Roblox" (Open Cloud OAuth 2.0, GA) on playroshambo.com merges identities web-side. It is additive — PWA players never need Roblox accounts. The experience itself never references the website (Roblox off-platform-link rules). Account-merge rules (pre-link play on both surfaces) are specified with the OAuth milestone, not now.

## 4. REST Protocol (v1)

All under `/api/v1`. Auth: `X-API-Key` header; the key lives in Roblox's secrets store (`HttpService:GetSecret`), never in scripts. Designed herd-safe: global reads cacheable, writes batched + jittered + idempotent.

| Endpoint | Purpose | Cadence per Roblox server |
|---|---|---|
| `GET /state` | `{roundId, phase, phaseEndsAt, serverTime, roundCount, tape}` (tape = recent World Throw history, as in the PWA) — cacheable ~1s | ~1/round + drift checks |
| `POST /throws` | Delta batch (see below) → `202` | 1–4/round |
| `GET /rounds/:id/result` | `{worldThrow, distribution, totalPlayers}` — identical for all callers, CDN-cacheable | 1/round at reveal |
| `GET /instances/:id/rounds/:rid/results` | Authoritative per-player outcomes `{userId, result, delta, totalPoints, pot, streak}[]` — **deferred reconciliation**, fetched with jitter during the *next* ACTIVE window, not at reveal | 1/round, spread |
| `POST /bank` | `{robloxUserId}` — server-mediated Bank decision | on demand |
| `GET /players/:robloxUserId` | Profile sync on join (points, pot, streaks) | on join |
| `GET /leaderboards?scope=world\|country` | World Record + country leaders — cacheable ~30s | ~2/min |

**Throw submission semantics**

- Each `POST /throws` carries `{instanceId, roundId, idempotencyKey, throws: [{robloxUserId, throw}]}` and is **delta-only**: only picks not yet acknowledged by a prior 2xx. Retries are safe (idempotency key = `instanceId:roundId:seq`).
- Flush triggers: every 5s during ACTIVE, **or** when 10 unflushed picks accumulate, **plus** a final delta flush dispatched immediately after pick lockout. A dropped final packet whiffs only the stragglers in that delta, never the whole instance.
- Roblox-side pick lockout is **T₀−2s**; the final delta flush goes out right after lockout (jittered within ~500ms), leaving ≥1s of network headroom before the tally closes at T₀. Late batches are rejected; affected players get a "throw didn't count" whiff animation — the server never invents results.
- **Timing**: all Roblox-side countdowns derive from `serverTime` offset (rolling average over the first 3 pings to filter handshake latency), never local clocks.

**Why reveal traffic doesn't melt the origin**: the only synchronized instant is the reveal, which is read-side and identical for everyone → CDN absorbs it. Per-instance reads are deferred and jittered; per-instance writes are spread across the whole ACTIVE window because players lock early.

## 5. Node Server Changes

This work doubles as the "add tests to the codebase" roadmap item, done TDD:

1. **Extract pure modules** from the 540-line `server/src/index.ts`: `GameRules` (calculateResult + 3ⁿ pot math) and `RoundEngine` (phase machine, tally accumulation, round events). Written test-first with **Vitest**; existing behavior is captured as characterization tests before refactor.
2. **Transports become thin adapters** over the same `RoundEngine`: the existing Socket.io handlers (wire format unchanged — the PWA notices nothing) and the new Express `/api/v1` routes (TDD with Supertest + in-memory Mongo).
3. **Schema additions** per §3. Existing `resolveUser()` gains the `robloxId` path.
4. `RoundEngine` accumulates throw tallies incrementally as batches arrive (closing a round = stop accepting), so the future vote-derived flip is a tally-function change, not a protocol migration.

## 6. The Roblox Experience

One arena place:

- **Arena**: central holographic display — countdown, tape of recent World Throws, and the reveal. Avatars roam freely; native Roblox chat carries the between-round plotting/banter.
- **Picking**: 3-button screen UI (R/P/S) during ACTIVE. Locking plays a "wind-up" emote visible to others — social signal without revealing the pick.
- **Reveal theater**: TALLY = lights dim/drumroll. REVEAL = World Throw materializes center-stage, then:
  - **WIN** — avatar grows, decaying back over ~10s. Implementation: tween the Humanoid R15 scale `NumberValue`s (`BodyHeightScale`, `BodyWidthScale`, `BodyDepthScale`, `HeadScale`) on every client, driven by the replicated reveal event. **Do not** use `HumanoidDescription:ApplyDescription` mid-game (forces clothing re-stream; hitches when many players win at once).
  - **LOSS** — anvil falls, comedic flatten, respring.
  - **SAFE** — shield shimmer.
- **Pedestals**: podium row for *this server* and *country* leaders — real Roblox avatars, physically knocked off when surpassed. Country via `LocalizationService:GetCountryRegionForPlayerAsync`.
- **World Record hologram**: the cross-platform global champion. A Roblox (or linked) champion's holo shows their real avatar; an unlinked web champion appears as a filtered-name "outsider" glow — no dummy avatars. **All externally-sourced display names must pass `TextService` filtering before display** (Roblox text-safety requirement). The same World Record motif later appears in the PWA.

## 7. Roblox Code Architecture

`roblox/` directory in this repo (monorepo keeps protocol producer/consumer evolving together):

```
roblox/
  default.project.json   # Rojo mapping
  rokit.toml             # pinned tools
  wally.toml             # packages (Jest-Lua)
  src/
    shared/   GameRules (Luau mirror of server math), RoundClock (offset sync,
              3-ping rolling average), Types, Config
    server/   NetworkClient (HttpService wrapper: retry, exponential backoff,
              jitter, idempotency, delta tracking),
              RoundCoordinator (poll loop, flush triggers, local reveal calc,
              deferred reconciliation, resync),
              PlayerRegistry (join/leave, profile sync, lockout enforcement)
    client/   PickUI, CountdownDisplay, Effects (grow/anvil/shimmer),
              Pedestals, WorldRecordHolo
  tests/      Jest-Lua specs (run headless via Lune): shared/ fully,
              server logic against a fake NetworkClient
```

**Anti-drift contract**: `GameRules` exists twice (TS + Luau) by necessity. Both test suites consume **one shared JSON fixture file** (e.g. `shared-fixtures/game-rules.json`: throw matchups, pot progressions, SAFE/LOSS streak rules). Divergence = CI failure, not a production surprise.

## 8. Dev Environment & Toolchain (greenfield macOS)

- **Accounts/places**: Roblox account → Creator Hub; two places: `Roshambo [DEV]` (private) and `Roshambo` (production). Open Cloud API key + OAuth app registration require ID verification.
- **Tools, pinned via Rokit**: **Rojo** (repo ↔ Studio live file sync; edit in any editor, Studio plugin syncs), **Lune** (headless Luau runtime — Jest-Lua tests in CI without Studio, sub-10s), **Wally** (package manager), **StyLua + Selene** (format/lint).
- **Local loop**: `docker-compose up` (Node + Mongo) → Studio playtest against `http://localhost:3001` (HttpService calls from Studio originate on the dev machine, so localhost works) → `lune test` + `npm test` as the TDD cycle.
- **CI (GitHub Actions)**: Vitest + Supertest; Jest-Lua via Lune; Selene/StyLua; `rojo build` → `.rbxl` artifact; auto-publish to DEV place via Open Cloud Publish API on main; production publish is a manual workflow dispatch.

## 9. Error Handling

| Failure | Behavior |
|---|---|
| Node unreachable | Arena enters "signal lost": picks disabled, social space still alive; NetworkClient retries with backoff + jitter; `/state` resync on recovery |
| Final flush missed cutoff | Only that delta's players whiff (animation, "didn't count" message); no invented results |
| Roblox server crash | Nothing lost — Node holds all flushed throws; players rejoin anywhere, `/players/:id` restores wallets |
| Local mirror drift (concurrent PWA play, partial batch failure, bank race) | Deferred per-instance reconciliation corrects within one round |
| Clock skew | All timing from `serverTime` offset; no local clock trust |
| Mid-round join | Spectate until next ACTIVE (matches PWA) |

## 10. Scale Path (flagged, deferred)

Launch posture: one App Runner instance + proper `Cache-Control` headers handles hundreds of Roblox servers. When growth demands:

1. CDN (CloudFront) in front of `/state`, `/rounds/:id/result`, `/leaderboards`
2. Externalize round state (Redis/Mongo) → horizontal stateless API tier
3. MemoryStore/MessagingService as a Roblox-side fan-out tier (e.g. leader server broadcasts reveal, poll fallback) — traffic optimization only, never authority

At 10k servers (~300k concurrent): reads collapse into CDN; writes ≈ 500 req/s spread across the round window — handled by step 2.

## 11. Milestones

1. **Node refactor + `/api/v1`** — GameRules/RoundEngine extraction with full test suite; PWA regression-verified; schema additions
2. **Toolchain + walking skeleton** — accounts, Rokit/Rojo/Lune/Wally, CI; a Studio place that polls the local server and prints round flow
3. **Playable loop** — pick UI, delta-batched submits, local reveal, reconciliation, points
4. **Arena theater** — grow/anvil/shimmer, pedestals, World Record holo, polish
5. **DEV place live** against production backend; publish pipeline proven
6. **Production place, soft launch**

Future (separate specs): web OAuth linking + account merge; PWA shared-theater refresh; vote-derived World Throw flip; merch research.

## 12. Decisions Log

| Decision | Choice | Why |
|---|---|---|
| Toolchain | Luau + Rojo (not roblox-ts, not Studio-only) | Native ecosystem for a greenfield Roblox dev; real TDD via Lune; git-first |
| Authority | One brain (Node) | Scoring needs per-player throws regardless; avoids dual wallets/engines; portable identity stays easy |
| Transport | REST polling (WebSockets are Studio-only on Roblox as of mid-2026) | Platform constraint |
| Identity | Roblox-native now, OAuth linking later | Less up-front work, same end state; additive for PWA users |
| Monetization | Engagement only (Creator Rewards); no Robux at launch | Zero gambling-policy risk; social dwell time is the model |
| Pedestals | Roblox-only podiums + cross-platform World Record holo | Real presence for social drama; no dummy avatars; filtered names for web champions |
| Reveal results | Computed locally for theater; reconciled deferred | Kills the reveal-instant origin spike; prevents silent wallet drift |
