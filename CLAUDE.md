# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Roshambo: a massively multiplayer rock-paper-scissors PWA where players compete against the "World Throw" (server-decided each round). Wins triple a staked pot (3^n progression); players choose to Bank (cash out) or Stake (keep riding the streak). Two independent codebases in one repo: a React frontend (root) and an Express/Socket.io backend (`server/`), each with its own `package.json` and tsconfig.

`requirements.md` is the original spec — the implementation has since diverged from it (e.g., the spec says matching the World Throw is a LOSS; the code treats a match as SAFE with pot preserved). The code is the source of truth.

## Commands

Frontend (repo root):
```bash
npm run dev        # vite --host (LAN-accessible for mobile testing)
npm run build      # tsc && vite build
npm run lint       # eslint, --max-warnings 0
```

Backend (`server/`):
```bash
npm run dev        # ts-node src/index.ts
npm run build      # tsc → dist/
npm start          # node dist/index.js
```

Full local stack (MongoDB + server + frontend on :8080):
```bash
docker-compose up --build
```

There are no tests in either package. Node version is pinned via `.nvmrc` (24.x).

The server requires `MONGODB_URI` (exits immediately without it; `server/.env` holds local config). The frontend needs `VITE_SOCKET_URL` pointing at the backend (defaults to same-origin if unset). Set `TEST_MODE=true` on the server for a deterministic World Throw cycle (R→P→S) instead of random.

## Architecture

### Server is authoritative (`server/src/index.ts`, single file)

The entire game loop lives in one `setInterval(1000)` tick:
- 20-second rounds (`ROUND_TIME`). Every tick broadcasts a `sync` heartbeat (timeLeft, roundCount, playerCount) — the client has **no local timer**; it renders only what `sync` says.
- At round end: World Throw is chosen (random, or deterministic in TEST_MODE — **not** derived from player votes despite the spec), each participant's result is computed and persisted, per-player `player-data` is emitted to their device room, then `reveal` broadcasts the round to everyone.

Game rules (`calculateResult`, duplicated client-side in `useGameLoop.ts` — keep in sync):
- Player beats world → **WIN**: pot goes 0→1, then ×3 per win; streak +1
- Player matches world → **SAFE**: pot preserved, streaks reset to 0
- World beats player → **LOSS**: pot forfeited, streaks reset

### Identity: deviceId + optional JWT

Guests are identified by a random `deviceId` in localStorage; logging in (email/password via `/auth` REST routes) adds a JWT passed in the socket handshake (`auth.token`). `resolveUser()` in `server/src/index.ts` merges the two — authenticated user wins, with cleanup logic that re-tags stale duplicate device records (`stale_<ts>_<id>`). Sockets join a room named after their deviceId so the server can emit targeted `player-data`.

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
