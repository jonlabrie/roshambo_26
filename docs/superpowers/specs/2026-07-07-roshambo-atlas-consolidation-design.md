# Roshambo Atlas Consolidation — Eliminate the Local Mongo Dependency (Design)

**Status:** design approved in brainstorm (2026-07-07); pre-planning. Infrastructure/ops cleanup — mostly config + Atlas/AWS ops, minimal application code.
**Branch:** `m4b-zendojo-art-pass` (or a dedicated `chore/atlas-consolidation` branch — decide at plan time).
**Relation to prior work:** The Roblox game server, the local Docker stack, and the deployed PWA backend currently disagree about where data lives. During early Roblox development a local MongoDB container (`roshambo-db`) crept in as the default store; the Roblox client (`SecretsExample.luau` → `http://localhost:3001`) is now welded to it and cannot reach the Atlas-backed "global" server that playroshambo.com depends on unless the local containers are running. This spec removes local Mongo entirely and points every environment at MongoDB Atlas.

## Context: the three lanes today

1. **playroshambo.com (live PWA):** Amplify frontend → **App Runner** backend → **Atlas** (`roshambo` db, via SSM `/roshambo/MONGODB_URI`). Backend **auto-deploy is OFF** (manual deploys only), so the deployed server is likely *behind* the repo — pre-teahouses (C.1) and pre-`padPreferences` (D.5.1).
2. **Local Docker stack (`docker-compose`):** `roshambo-frontend` (:8080) → `roshambo-server` (:3001) → `roshambo-db` (**local Mongo**). `docker-compose.yml` hard-codes `MONGODB_URI=mongodb://mongodb:27017/roshambo` on the server service, overriding `server/.env`.
3. **Roblox client:** no `SecretsLocal.luau` exists, so `main.server.luau` falls through to `SecretsExample.luau` → `http://localhost:3001` → lane 2's server → local Mongo.

**Key freedom:** there are **no current players** on either platform, so we can make the correct architectural decision now with zero migration risk. The stale local-Mongo test data (including this session's D.5.1 gate seed) is disposable.

## Problem

The local Mongo container is the default data store for local development and for the Roblox client, which (a) forces `docker compose up` (with Mongo) as a precondition for any Roblox testing, and (b) means Roblox development never exercises the same Atlas-backed path the shipped product uses. We want one source of truth (Atlas) across every environment and no local database.

## Goals

- **Remove local MongoDB completely:** delete the `mongodb` service, its `mongodb_data` volume, the `depends_on`, and the hard-coded `MONGODB_URI` override from `docker-compose.yml`.
- **One Atlas cluster, two databases:** `roshambo` (production, unchanged) and **`roshambo-dev`** (all local/dev + Studio testing). Same cluster; separation is by database name in the connection-string path.
- **Local server → Atlas `roshambo-dev`,** via `server/.env` (gitignored), with a *working* connection string (the one currently there fails auth and must be fixed).
- **Roblox client → an Atlas-backed server,** via a new gitignored `SecretsLocal.luau`. Default dev target is the local server (`http://localhost:3001`, now Atlas-backed); the deployed App Runner URL is documented as the "true global server" target.
- **Keep the deployed backend current** (recommended, adjacent): manually deploy the repo's current server to App Runner so the global server actually has the `/api/v1` teahouses + preferences surface.

## Non-goals (explicitly out of scope)

- **The economy split (wallet partition).** The split-economy policy is enforced *logically* in the schema (separate spendable balances per platform), not by a separate database — a metagame-track concern with its own brainstorm. This spec keeps **one Atlas database per environment**; it does not touch the `User` wallet fields. See the split-economy design (`2026-07-04-roshambo-metagame-design.md`).
- **Milestone-5 production Roblox secret wiring** (`HttpService:GetSecret` for the shipped game server's `API_KEY`/URL). We only wire *dev* Roblox here and note the production path.
- **Rotating/redesigning the PWA's SSM secrets** beyond confirming the prod URI still resolves to `roshambo`.
- **Any application logic change.** `server/src/index.ts` already reads `process.env.MONGODB_URI` via `dotenv` and needs no edit.

## Target architecture (after this change)

| Lane | Frontend/client | Server | Database |
|---|---|---|---|
| **Production PWA** | Amplify | App Runner (SSM secrets) | Atlas **`roshambo`** |
| **Local dev (PWA + backend)** | Vite / compose frontend :8080 | local server :3001 (reads `server/.env`) | Atlas **`roshambo-dev`** |
| **Roblox dev (Studio)** | `main.client.luau` | via `SecretsLocal.luau` → local server :3001 | Atlas **`roshambo-dev`** |
| **Roblox shipped (milestone 5)** | Roblox game server | via Roblox secret → App Runner URL | Atlas **`roshambo`** |

No MongoDB runs on the developer's machine in any lane.

## Changes

### A. Ops prerequisites (user-performed — Claude cannot access the Atlas or AWS consoles)

These gate the repo changes; the plan will list them as manual steps for the user to complete and paste back the results (a *working* connection string, redacted in any commit).

1. **Atlas database user:** provision (or rotate) a DB user with `readWrite` on **`roshambo-dev`**. Confirm the existing production user still has `readWrite` on `roshambo`. (The URI currently in `server/.env` returns `bad auth` — it must be replaced with working credentials regardless.) A single user with access to both dbs is acceptable; a dev-scoped user is tidier.
2. **Working dev connection string:** `mongodb+srv://<devUser>:<pw>@roshambocluster0.ckjseml.mongodb.net/roshambo-dev?retryWrites=true&w=majority&appName=RoshamboCluster0`. Note the **`/roshambo-dev`** path segment — that selects the database.
3. **Atlas network access:** ensure the developer's IP (or `0.0.0.0/0` for dev convenience) is allow-listed, so both `npm run dev` and the compose server container can reach the cluster.
4. **(Recommended) App Runner redeploy:** trigger a manual deploy (console "Deploy" or `aws apprunner start-deployment`) so the `roshambo` prod db is served by the current code (teahouses + preferences routes). Required before any Roblox lane points at the deployed URL.

### B. `server/.env` (gitignored — not committed)

- Replace `MONGODB_URI` with the working **`roshambo-dev`** connection string from A.2.
- Keep `API_KEY`, `JWT_SECRET`, `PORT=3001`, `TEST_MODE=true` for local dev (unchanged).

### C. `docker-compose.yml` (repo edit)

- **Delete** the `mongodb` service block.
- **Delete** the top-level `mongodb_data` volume.
- On the `server` service: **remove** the inline `environment:` block's `MONGODB_URI` override and the `depends_on: [mongodb]`. Replace the inline env with `env_file: ./server/.env` so the container reads the same Atlas-dev config as `npm run dev`. (Keep `ports: ["3001:3001"]`.)
- Leave the `frontend` service untouched (`VITE_SOCKET_URL=http://localhost:3001` is baked at build; the local server still listens there).

Result: `docker compose up --build` brings up frontend + server against Atlas `roshambo-dev`, with no database container.

### D. Roblox `SecretsLocal.luau` (new, gitignored)

- Create `roblox/src/server/SecretsLocal.luau` by copying `SecretsExample.luau` (already the resolution fallback in `main.server.luau:31-33`; `SecretsLocal` is preferred when present and is gitignored per `roblox/.gitignore:3`).
- **Dev default:** `baseUrl = "http://localhost:3001"`, `apiKey = "<the dev API_KEY from server/.env>"`. This reaches the local server, now Atlas-`roshambo-dev`-backed — breaking the local-Mongo dependency while still letting you run unreleased server code.
- **Documented alternative (true global server):** set `baseUrl` to the deployed App Runner URL and `apiKey` to the **production** `API_KEY`; requires A.4 (prod redeployed) and the real key. Do **not** commit that key.

### E. Documentation (repo edit)

- **`CLAUDE.md`:** update the "Full local stack (MongoDB + server + frontend)" command note and the `MONGODB_URI` sentence to reflect Atlas-backed local dev (no local Mongo). Note `roshambo-dev` as the dev database.
- **`README_DEPLOY.md`:** add a short "Local development against Atlas" note (dev db, `server/.env`, no Mongo container) and reiterate that backend auto-deploy is OFF.

## Verification (manual — this is infra, not unit-testable)

Perform after A–D, with **no local Mongo running** (`docker rm -f roshambo-db` first if it exists):

1. **Server connects to Atlas dev:** `cd server && npm run dev` (or `docker compose up --build server`) → startup log shows `[SYS] Target Database: …roshambo-dev` (password auto-redacted by `index.ts:28`) and no connection error.
2. **REST surface works against Atlas:** `curl -s localhost:3001/api/v1/players/consolidation-probe/teahouses -H "X-API-Key: <dev key>"` → `{"teahouses":{},"padPreferences":[]}` (confirms the fold *and* the dev db is writable).
3. **Roblox reaches Atlas via the local server:** with `SecretsLocal.luau` in place and local Mongo **stopped**, enter Studio Play → server console logs `[ROSHAMBO] playable loop starting against http://localhost:3001` and a `[D.5] … claimed …` line; confirm the claim persisted by reading the same player's doc from Atlas `roshambo-dev` (curl the teahouses GET, or Atlas UI). This is the acceptance gate — it proves Roblox no longer needs local Mongo.
4. **Data isolation holds:** the write from step 2/3 appears in `roshambo-dev`, **not** `roshambo` (spot-check via Atlas UI or two curls against dev-backed vs prod-backed servers).
5. **Local Mongo is gone:** `docker compose down -v` removes containers + volumes; `docker volume ls | grep mongodb_data` returns nothing; `docker ps -a | grep roshambo-db` returns nothing.

## Rollback

Purely reversible and low-risk (no production data touched): revert the `docker-compose.yml` / doc commits and restore the previous `server/.env` `MONGODB_URI` to spin the local Mongo stack back up. `SecretsLocal.luau` is gitignored and can simply be deleted to fall back to `SecretsExample`. Nothing in this change alters the `roshambo` production database or the App Runner service config (the A.4 redeploy only ships already-reviewed code).

## Deliverables

1. `docker-compose.yml` — remove `mongodb` service + `mongodb_data` volume + `depends_on` + `MONGODB_URI` override; add `env_file: ./server/.env` to the `server` service.
2. `roblox/src/server/SecretsLocal.luau` — new gitignored file (dev target). *Not committed; created locally.*
3. `server/.env` — working Atlas `roshambo-dev` URI. *Not committed; edited locally.*
4. `CLAUDE.md`, `README_DEPLOY.md` — doc updates for Atlas-backed local dev.
5. (Recommended, ops) App Runner manual redeploy of current server code.

## Build order

Ops first, because the repo edits are inert without a working Atlas target:
**A (Atlas user + dev URI + network access)** → **B (`server/.env`)** → verify server connects (Verification 1–2) → **C (`docker-compose.yml`)** → re-verify compose path → **D (`SecretsLocal.luau`)** → Roblox acceptance gate (Verification 3–4) → **E (docs)** → tear down local Mongo (Verification 5) → **A.4 (App Runner redeploy)** as the closing ops step so the global server is current.

## Open items for the plan/review

- **Branch:** land on `m4b-zendojo-art-pass` alongside the D work, or a dedicated `chore/atlas-consolidation`? (Recommend a dedicated branch — this is orthogonal to sub-project D and easy to review in isolation.)
- **Single vs. dev-scoped Atlas user** (A.1) — cosmetic; either works.
- **Whether to also point the deployed Roblox lane at prod now** or defer entirely to milestone 5 (recommend defer; only wire dev here).
