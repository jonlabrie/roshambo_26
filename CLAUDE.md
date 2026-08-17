# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Working Preferences

- **TDD**: Write a failing test first, then the implementation. Both TypeScript codebases have Vitest suites (`server/`: `npm test`; repo root: `npm test`, scoped to `src/` by `vite.config.ts` so it does not pick up the server's).

## Project Wiki (docs/wiki/) — read before relying on memory

`docs/wiki/` is the single authority for project knowledge and work tracking. Read
`docs/wiki/index.md` at session start before relying on auto-memory. For the game itself —
outcomes, pot math, Bank vs Stake, what each points field means — read
`docs/wiki/world/core-loop.md` and `docs/wiki/world/world-throw.md`; those are the
foundations, and this file only summarises them. Record project
facts (gates, decisions, statuses, as-built state, standing rules) THERE, following
`docs/wiki/schema.md` — not in the auto-memory directory. The auto-memory dir holds
only user/feedback memories about how we work together. Statuses live only under
`docs/wiki/program/`; supersede text rather than appending; log events in
`docs/wiki/log.md`.

## What This Is

Roshambo: a massively multiplayer rock-paper-scissors PWA where players compete against the "World Throw" (server-decided each round). Wins triple a staked pot (3^n progression); players choose to Bank (cash out) or Stake (keep riding the streak). Two independent codebases in one repo: a React frontend (root) and an Express/Socket.io backend (`server/`), each with its own `package.json` and tsconfig.

A demo is live at **playroshambo.com**, running in TEST_MODE (deterministic R→P→S World Throw cycle). The app was originally built with Google's Antigravity IDE and is unfinished.

`requirements.md` is the original spec — the implementation has since diverged from it (e.g., the spec says matching the World Throw is a LOSS; the code treats a match as SAFE with pot preserved). The code is generally the source of truth, **except on the World Throw rule** (see Architecture below). The game implements **US 8,025,570 B2, a patent owned by Jon Labrie**.

## Commands

Frontend (repo root):
```bash
npm run dev        # vite --host (LAN-accessible for mobile testing)
npm run build      # tsc && vite build
npm test           # vitest, scoped to src/ (see vite.config.ts)
npm run lint       # eslint, --max-warnings 0
```

Backend (`server/`):
```bash
npm run dev        # ts-node src/index.ts
npm run build      # tsc → dist/
npm start          # node dist/index.js
npm test           # vitest (also: npm run test:watch)
```

**Studio/PWA dev needs no local server**: the cloud dev backend (App Runner service `roshambo_server_dev`, see `README_DEPLOY.md` §0a) **auto-deploys every push** to the working branch (`m4b-zendojo-art-pass`) and is what `roblox/src/server/SecretsLocal.luau` points at — a push takes a few minutes to go live, and it changes the running dev backend immediately.

Full local stack (server + frontend on :8080, backed by MongoDB Atlas — no local database), only for testing un-pushed server code:
```bash
docker-compose up --build
```
The `server` service reads `server/.env` (gitignored) for its Atlas connection; local dev and Studio testing use the `roshambo-dev` database on the shared cluster (prod uses `roshambo`). There is no local MongoDB container.

Roblox client (`roblox/`, requires [Rokit](https://github.com/rojo-rbx/rokit) — run `rokit install` once from `roblox/`):
```bash
lune run tests/run          # headless Luau tests (bespoke harness; Jest-Lua can't run under Lune)
rojo serve                  # live-sync into an open Studio place (Rojo plugin -> Connect)
rojo build -o build.rbxl    # build a place file
stylua --check src tests tools && selene src tools   # format + lint (MATCH CI's scope — selene fails on warnings)
```

Node version is pinned via `.nvmrc` (24.x).

The server requires `MONGODB_URI` (exits immediately without it; `server/.env` holds local config — an Atlas `roshambo-dev` connection string, not a local database) and `API_KEY` (required for `/api/v1`; PWA works without it). The frontend needs `VITE_SOCKET_URL` pointing at the backend (defaults to same-origin if unset). Set `TEST_MODE=true` on the server for a deterministic World Throw cycle (R→P→S) instead of random.

## Architecture

### Server is authoritative (`server/src/`, modular since the 2026-06 refactor)

`index.ts` is an ~80-line composition root. The pieces:
- `engine/GameRules.ts` — pure result/pot/streak math, fixture-tested against `shared-fixtures/game-rules.json` (repo root; the Roblox Luau mirror `roblox/src/shared/GameRules.luau` runs the same fixtures — keep them in sync)
- `engine/RoundEngine.ts` — timer-less phase machine (`OPEN 51s → LOCK 2s → REVEAL 7s`, durations env-overridable via `ROUND_OPEN_SECONDS` / `ROUND_LOCK_SECONDS` / `ROUND_REVEAL_SECONDS`), ticked by a `setInterval` in the composition root; collects throws with per-player seq-guarded upserts
- `engine/Settlement.ts` — persists rounds, scores all participants (PWA + Roblox) via `identity.resolveUser`
- `engine/ResultsStore.ts` — in-memory recent results (global, per-instance, tape)
- `transports/socketAdapter.ts` — the PWA's Socket.io wire format, unchanged from the legacy server
- `routes/apiV1.ts` — REST surface for Roblox game servers (`X-API-Key` auth via `API_KEY` env var)

Game rules live in THREE implementations, and all three are held to `shared-fixtures/game-rules.json` so drift fails CI rather than "keep in sync" being a hope: `server/src/engine/GameRules.ts` (authoritative), `roblox/src/shared/GameRules.luau`, and `src/lib/gameRules.ts` (the PWA's fallback for a result the server has not sent yet). The rules:
- Player beats world → **WIN**: pot goes 0→1, then ×3 per win; streak +1
- Player matches world → **SAFE**: pot preserved, streaks reset to 0
- World beats player → **LOSS**: pot forfeited, streaks reset

- At round end: the World Throw is chosen and each participant's result is computed and persisted. **The World Throw is DESIGNED to be the MAJORITY of player throws** — "you against the world" is the product premise, and it makes crowd-reading a skill (hence the last-five-rounds HUD). Implemented 2026-08-16 as `GameRules.deriveWorldThrow` — **plurality** (argmax of the round's tally), ties broken randomly among the tied, falling back to random below `WORLD_THROW_MIN_PARTICIPANTS` (5). **`TEST_MODE` still cycles R→P→S**, and BOTH prod and dev run TEST_MODE, so the rule is fixed but not yet exercised anywhere. Per-player `player-data` is then emitted to each device room, and `reveal` broadcasts the round to everyone. See `docs/wiki/world/world-throw.md`.

### Roblox client (`roblox/`, milestone 2+)

Luau modules take their **Roblox services and side effects by dependency injection** — no `game:GetService`, no globals — so the same files run under Lune (tests) and Roblox (runtime). They **may `require` each other by relative path** and nine of them do (`AccessGates`→`SizeClasses`, `PadBuilder`→`PadPlanner`, `RoundBandModel`→`StatsBoardModel`, …); Luau string requires resolve under both runtimes. (Corrected 2026-08-16: this line previously said modules never require each other, which had been untrue for months and made a reviewer flag correct code as a violation.) `main.server.luau` and `main.client.luau` are the only Roblox-runtime files — the server entry wires HttpService/task/DateTime into NetworkClient/RoundCoordinator/RoundClock/ThrowBuffer/PlayerProfiles; the client entry owns the pick UI. Local connection settings come from `SecretsLocal.luau` (gitignored; copy `SecretsExample.luau`). `GameRules.luau` mirrors `server/src/engine/GameRules.ts` — both are tested against `shared-fixtures/game-rules.json`, so drift fails CI.

Milestone 3 adds the playable loop: picks flow client→`SubmitPick` RemoteEvent→`RoundCoordinator:submitPick`→`ThrowBuffer`→delta-flushed to `POST /api/v1/throws` (5s cadence / 10 picks / final flush at the T₀−2s lockout). Reveals are computed locally from the mirrored GameRules and reconciled next round via `GET /instances/.../results` (authoritative overwrite in `PlayerProfiles`). RemoteEvents contract lives in `default.project.json` (`RoshamboRemotes`).

Milestone 4a adds the arena machinery: pure modules (`FlapScheduler`, `DoomEscalation`, `ChoreographyMachine`, `FateRegistry`, `ThemeManifest`+`themes/ZenDojo`, `EffectRegistry`/`EffectSelector`) drive client controllers (`BoardController`, `HammerController`, `TheaterController`, `FateController`) over a client-side `EventBus`. New remotes: `RevealTheater` (arena-wide results), `FateResolved` (victim-authority catch/accept), `BoardData`. Fate-bound players cannot throw until their fate resolves (server gate in `main.server.luau`). All visuals are placeholders pending milestone 4b's art pass.

### Workspace organization (Rojo vs place-only)

Rojo manages **exactly what `default.project.json` names** — all of it lives under
`Workspace.RoshamboStage` (7 hero-prop models from `assets/*.model.json` + `ArenaSpawn`).
`RoshamboStage` holds nothing else; never hand-add children to it in Studio.

Everything else in Workspace is **place-only** (saved in the place, not in git) and
organized by lifecycle:
- `Workspace.CanyonWorld` — shipped hand-built geometry/VFX: `Arena` (river/falls VFX +
  rocks near the arena, kept `Persistent` for distant spawn-watchers via
  `StagePersistence`), `Paths`, `Structures`, `Legacy` (empty in the live place — the
  14 legacy `CanyonTeahouses` were retired to `ServerStorage.RetiredLegacyTeahouses`;
  see `docs/wiki/world/place-state.md`).
- `Workspace.Sandbox` — throwaway prototypes/drafts.

Ship by **publishing/saving the place, never `rojo build`** (that emits only the declared
RoshamboStage children and drops all place-only content). CI fails if a `.rbxl(x)` is
committed; before publishing, run `tools/studio/verifyWorkspaceConvention.luau` in Studio.

### Identity: deviceId + optional JWT

Guests are identified by a random `deviceId` in localStorage; logging in (email/password via `/auth` REST routes) adds a JWT passed in the socket handshake (`auth.token`). `resolveUser()` in `server/src/identity.ts` merges the two (plus `robloxId` for Roblox players) — authenticated user wins, with cleanup logic that re-tags stale duplicate device records (`stale_<ts>_<id>`). Sockets join a room named after their deviceId so the server can emit targeted `player-data`.

### Socket protocol

Client → server: `sync-player`, `submit-throw`, `bank`, `get-stats`, `update-progress`
Server → client: `init`, `sync` (1s heartbeat), `reveal`, `player-data`, `stats-data`

REST (Express): `/auth` (register/login, bcrypt + JWT) and `/store` (catalog/purchase/equip, JWT-gated).

### Frontend: one hook owns everything

`src/hooks/useGameLoop.ts` (~500 lines) is the entire client state layer: socket lifecycle, game state, auth/login, store purchases, audio settings (localStorage-persisted), and WebAudio gong synthesis on reveal. Socket event handlers read mutable refs (`playerThrowRef`, `isLockedRef`, etc.) that mirror state, because the handlers are bound once. The server's authoritative result arrives via `player-data` (`serverResultRef`) and takes precedence over the client's local fallback calculation in `handleServerReveal`.

`src/App.tsx` does view switching with a state enum (`GAME` / `USER_STATS` / `GLOBAL_STATS` / `AUTH` / `STORE`) — no router.

### Visual tiers

Three swappable arena renderers selected by `visualTier` in App.tsx:
- **LITE**: `ArenaVisuals.tsx` — CSS/SVG only (the "Data Thrift" mode)
- **FULL**: `RiveArena.tsx` — Rive state-machine animations
- **ULTRA** (default): `VideoArena.tsx` — mp4 clips from `public/videos/{idle,selection,rock,paper,scissors}/`

`server/src/constants/characters.ts` defines the character catalog with per-tier assets (`lite` colors, `full` Rive src, `ultra` video filenames). The frontend fetches it via `GET /store/catalog`. Adding a character means updating that file and supplying matching video assets in `public/videos/`.

### Mobile/iOS caveats

Recent work centers on iOS Safari: video playback persistence, audio unlock/mute, and viewport scrolling (see recent commits). Be careful with changes to `VideoArena.tsx` and the AudioContext handling in `useGameLoop.ts` — they contain Safari-specific workarounds.

## Deployment

Local Docker → AWS: backend on App Runner (`apprunner.yaml`, builds from `server/`), frontend on Amplify (`amplify.yml`). See `README_DEPLOY.md` for the full setup. `dist/` is committed build output — don't hand-edit it.
