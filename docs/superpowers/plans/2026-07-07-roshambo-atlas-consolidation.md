# Atlas Consolidation — Eliminate Local Mongo Implementation Plan

> **For agentic workers:** This is an infrastructure/ops runbook, not a code feature. Most steps are sequential and gated on manual verification or user-performed Atlas/AWS console actions; there is almost no unit-testable code. Recommended execution: **inline (executing-plans)**, not subagent-driven — the tasks are ops-ordered and share a single machine/console state. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the local MongoDB container entirely and point every environment (local server, Roblox Studio dev, production) at MongoDB Atlas — `roshambo` for prod, `roshambo-dev` for all local work.

**Architecture:** One Atlas cluster, two databases selected by the connection-string path (`/roshambo` vs `/roshambo-dev`). The local server reads `server/.env` (gitignored) instead of a compose-hardcoded local URI; the Roblox client reaches the Atlas-backed local server via a new gitignored `SecretsLocal.luau`. No database runs on the developer's machine.

**Tech Stack:** Docker Compose, MongoDB Atlas, AWS App Runner + SSM (unchanged), Express/Mongoose (`dotenv` already wired), Roblox/Luau Secrets module.

**Spec:** `docs/superpowers/specs/2026-07-07-roshambo-atlas-consolidation-design.md` (commit `07702ae`).

## Global Constraints

- **No secrets in git.** `server/.env` and `roblox/src/server/SecretsLocal.luau` are gitignored (`.gitignore:4`, `roblox/.gitignore:3`) and MUST NOT be committed. Only `docker-compose.yml` and the two docs are committed. Any connection string shown in a commit, log, or report must be redacted (`index.ts:28` auto-redacts the password at startup — rely on that, don't paste raw URIs).
- **No production data touched.** Prod stays `roshambo` via SSM. All local/dev writes go to `roshambo-dev`. The only prod-affecting step is the optional App Runner redeploy, which ships already-reviewed code.
- **Ownership tags** on each task: **[USER OPS]** = Atlas/AWS console, user-only (Claude cannot access these); **[LOCAL]** = Claude edits a gitignored file locally, no commit; **[COMMIT]** = committed repo change.
- **`server/.env` must carry all server env** once the compose override is removed: `MONGODB_URI` (Atlas `roshambo-dev`), `API_KEY`, `JWT_SECRET`, `PORT=3001`, `TEST_MODE=true`. The compose `server` service will read this file wholesale via `env_file`.
- **The dev `API_KEY` is whatever `server/.env` holds** after Task 2 — every verification curl and `SecretsLocal.luau` must use that exact value, not the old compose literal `roshambo_local_dev_api_key`.

---

### Task 1: Branch + Atlas provisioning [USER OPS + COMMIT]

**Files:** none yet (branch creation only).

**Interfaces:**
- Produces: a working Atlas `roshambo-dev` connection string (held by the user, pasted back redacted-in-commits), and a `chore/atlas-consolidation` branch.

- [ ] **Step 1: Create the working branch (Claude)**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git checkout -b chore/atlas-consolidation
git rev-parse --abbrev-ref HEAD   # expect: chore/atlas-consolidation
```

- [ ] **Step 2: Confirm Atlas access (USER — in the Atlas console)**

Reuse the **existing `roshambo_app`** user (the one production uses) — no new user needed. The user performs these; Claude cannot reach the Atlas console. Hand the user this checklist:
1. **Role check** (Database Access → `roshambo_app` → role):
   - If **`readWriteAnyDatabase`** / **`atlasAdmin`** (cluster-wide) → reuse as-is; nothing to change. `roshambo-dev` is created implicitly on first write.
   - If **`readWrite` scoped to `roshambo`** specifically → add a second role `readWrite @ roshambo-dev` (or broaden to `readWriteAnyDatabase`). Still no new user.
2. **Network access:** the developer's current IP (or `0.0.0.0/0` for dev convenience) is allow-listed.
3. **Connection string** = the working `roshambo_app` string, with the db in the path switched to **`/roshambo-dev`**:
   `mongodb+srv://roshambo_app:<pw>@roshambocluster0.ckjseml.mongodb.net/roshambo-dev?retryWrites=true&w=majority&appName=RoshamboCluster0`
   (Note: the URI currently in `server/.env` uses a *different*, non-working user `jonlabrie_db_user` — that's the `bad auth`; switching to the `roshambo_app` string fixes it.)

- [ ] **Step 3: Smoke-test the string before wiring anything (Claude, once user provides it)**

Verify the credentials actually authenticate against `roshambo-dev`, using the local Mongo container's `mongosh` as a client (it can dial out; this does not use the local db). Substitute the real string:

```bash
docker exec roshambo-db mongosh "<atlas roshambo-dev uri>" --quiet --eval 'print("ok db=" + db.getName())'
# expect: ok db=roshambo-dev   (NOT "bad auth")
```

Expected: `ok db=roshambo-dev`. If `bad auth`, return to Step 2 — the repo edits are inert without a working string.

- [ ] **Step 4: Commit the branch marker (empty — the spec is already committed)**

No commit needed here; the branch exists and the spec commit (`07702ae`) is its base. Proceed once Step 3 is green.

---

### Task 2: Point the local server at Atlas `roshambo-dev` [LOCAL]

**Files:**
- Modify (gitignored, NOT committed): `server/.env`

**Interfaces:**
- Consumes: the working URI from Task 1.
- Produces: a local server that connects to Atlas `roshambo-dev`; the dev `API_KEY` value that Task 4 and all curls will reuse.

- [ ] **Step 1: Update `server/.env` (Claude, local edit)**

Set `MONGODB_URI` to the working `roshambo-dev` string from Task 1. Confirm the file also contains `API_KEY`, `JWT_SECRET`, `PORT=3001`, `TEST_MODE=true` (all already present per the pre-flight read). Do not commit — `.env` is gitignored.

- [ ] **Step 2: Verify the server connects to Atlas dev (no local Mongo needed)**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/server && npm run dev
```
Expected startup log: `[SYS] Target Database: …roshambo-dev` (password auto-redacted) and no connection error. Leave it running for Step 3, then Ctrl-C.

- [ ] **Step 3: Verify the REST surface against Atlas dev**

In another shell (use the `API_KEY` value from `server/.env`):
```bash
KEY=$(grep -m1 '^API_KEY=' server/.env | cut -d= -f2-)
curl -s localhost:3001/api/v1/players/consolidation-probe/teahouses -H "X-API-Key: $KEY"; echo
# expect: {"teahouses":{},"padPreferences":[]}
```
Expected: the fold response, proving the `roshambo-dev` db is reachable and writable. Record the `API_KEY` value for Task 4.

---

### Task 3: Remove local Mongo from `docker-compose.yml` [COMMIT]

**Files:**
- Modify: `docker-compose.yml`

**Interfaces:**
- Consumes: `server/.env` (Task 2) as the server service's env source.
- Produces: a compose stack of `server` + `frontend` only, no database container/volume.

- [ ] **Step 1: Replace `docker-compose.yml` in full**

Replace the entire file with:

```yaml
services:
  server:
    build:
      context: ./server
      dockerfile: Dockerfile
    container_name: roshambo-server
    env_file:
      - ./server/.env
    ports:
      - "3001:3001"

  frontend:
    build:
      context: .
      dockerfile: frontend.Dockerfile
      args:
        - VITE_SOCKET_URL=http://localhost:3001
    container_name: roshambo-frontend
    ports:
      - "8080:80"
    depends_on:
      - server
```

(Removed: the `mongodb` service, the top-level `mongodb_data` volume, the server's inline `environment:` block and `depends_on: [mongodb]`. The `server` service now reads all env from `server/.env`.)

- [ ] **Step 2: Verify the compose path reaches Atlas dev, no db container**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
docker rm -f roshambo-db 2>/dev/null || true      # ensure the old local db is gone
docker compose up -d --build server
docker logs roshambo-server 2>&1 | grep "Target Database"
# expect: [SYS] Target Database: …roshambo-dev
docker ps --format '{{.Names}}' | grep roshambo    # expect: roshambo-server (NO roshambo-db)
```
Expected: server log shows `roshambo-dev`; no `roshambo-db` container.

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "chore(infra): remove local mongo from docker-compose; server reads server/.env (Atlas)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 4: Wire Roblox to the Atlas-backed local server [LOCAL]

**Files:**
- Create (gitignored, NOT committed): `roblox/src/server/SecretsLocal.luau`

**Interfaces:**
- Consumes: the dev `API_KEY` from Task 2; the running local server from Task 3.
- Produces: a Roblox client that reaches Atlas via the local server, with local Mongo stopped — the acceptance gate for the whole change.

- [ ] **Step 1: Create `SecretsLocal.luau` (Claude, local — NOT committed)**

`main.server.luau:31-33` prefers `SecretsLocal` over `SecretsExample`, and `roblox/.gitignore:3` ignores it. Copy the example and set the dev values (substitute the `API_KEY` from `server/.env`, Task 2):

```lua
--!strict
-- Local-dev connection settings (gitignored). Points Studio at the local server,
-- which is now backed by Atlas roshambo-dev. Production Roblox uses HttpService:GetSecret
-- (milestone 5), never this file.
return {
    baseUrl = "http://localhost:3001",
    apiKey = "<the API_KEY value from server/.env>",
}
```

(Documented alternative, not the default: to test against the *true global server*, set `baseUrl` to the deployed App Runner URL and `apiKey` to the production key — requires Task 6's redeploy and the real key; never commit it.)

- [ ] **Step 2: Acceptance gate — Roblox reaches Atlas with local Mongo stopped**

Ensure the local server (Task 3) is up and **no local Mongo exists** (`docker ps -a | grep roshambo-db` → empty). In Studio, enter Play. Expected server console:
```
[ROSHAMBO] playable loop starting against http://localhost:3001
[D.5] <UserId> claimed <padId> @ <size>
```
(A fresh Atlas-dev player owns nothing, so the `[D.5]` claim line only appears if that player has been seeded; the load-bearing check is simply that the round loop starts and the join fetch succeeds against `http://localhost:3001` with no error — proving Roblox no longer needs local Mongo.)

- [ ] **Step 3: Confirm the write landed in `roshambo-dev`, not `roshambo`**

```bash
KEY=$(grep -m1 '^API_KEY=' server/.env | cut -d= -f2-)
# the player that just joined in Studio (UserId from the console line):
curl -s "localhost:3001/api/v1/players/<UserId>/teahouses" -H "X-API-Key: $KEY"; echo
```
Expected: a `{teahouses,padPreferences}` response served from `roshambo-dev`. (Optional cross-check: query the prod-backed server or Atlas UI to confirm the same doc is absent from `roshambo`.)

- [ ] **Step 4: Stop Play.** One attempt at the gate, then stop (per working preferences — do not iterate visuals unprompted).

---

### Task 5: Documentation [COMMIT]

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README_DEPLOY.md`

**Interfaces:** none (docs only).

- [ ] **Step 1: Update `CLAUDE.md` — the full-local-stack note**

Replace:
```
Full local stack (MongoDB + server + frontend on :8080):
```bash
docker-compose up --build
```
```
with:
```
Full local stack (server + frontend on :8080, backed by MongoDB Atlas — no local database):
```bash
docker-compose up --build
```
The `server` service reads `server/.env` (gitignored) for its Atlas connection; local dev and Studio testing use the `roshambo-dev` database on the shared cluster. There is no local MongoDB container.
```

- [ ] **Step 2: Update `CLAUDE.md` — the `MONGODB_URI` sentence (line ~49)**

Replace:
```
The server requires `MONGODB_URI` (exits immediately without it; `server/.env` holds local config) and `API_KEY` (required for `/api/v1`; PWA works without it).
```
with:
```
The server requires `MONGODB_URI` (exits immediately without it; `server/.env` holds local config — an Atlas `roshambo-dev` connection string, not a local database) and `API_KEY` (required for `/api/v1`; PWA works without it).
```

- [ ] **Step 3: Update `README_DEPLOY.md` — insert a local-dev section**

Insert after line 3 (the intro paragraph), before `## 1. MongoDB Atlas Setup`:

```
## 0. Local Development (against Atlas — no local database)

Local dev and Roblox Studio testing run against a **`roshambo-dev`** database on the same Atlas cluster as production (`roshambo`); there is no local MongoDB container.

1. In Atlas, ensure a Database User has `readWrite` on `roshambo-dev`, and Network Access allows your IP.
2. Put the connection string in `server/.env` (gitignored), with the database in the path: `mongodb+srv://…/roshambo-dev?retryWrites=true&w=majority`. Also set `API_KEY`, `JWT_SECRET`, `PORT=3001`, `TEST_MODE=true`.
3. Run the stack: `docker compose up --build` (server + frontend, no database), or `cd server && npm run dev`.
4. Roblox: copy `roblox/src/server/SecretsExample.luau` to `SecretsLocal.luau` (gitignored) and set `baseUrl = "http://localhost:3001"`, `apiKey` = your dev `API_KEY`.

```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md README_DEPLOY.md
git commit -m "docs(infra): Atlas-backed local dev, no local mongo

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 6: Tear down local Mongo + (recommended) redeploy prod [USER OPS + local]

**Files:** none.

**Interfaces:** none — closing ops.

- [ ] **Step 1: Remove the local Mongo container + volume (Claude)**

```bash
docker rm -f roshambo-db 2>/dev/null || true
docker volume rm roshambo_26_mongodb_data 2>/dev/null || docker volume ls -q | grep mongodb_data | xargs -r docker volume rm
docker volume ls | grep mongodb_data    # expect: no output
docker ps -a | grep roshambo-db         # expect: no output
```
Expected: the local Mongo container and `mongodb_data` volume are gone. (Its data — including this session's D.5.1 gate seed — is intentionally discarded per the spec.)

- [ ] **Step 2 (RECOMMENDED, USER — AWS): redeploy the current server to App Runner**

So the global `roshambo` db is served by current code (teahouses + preferences routes) — required before any Roblox lane points at the deployed URL. The user triggers it (console "Deploy" or):
```bash
aws apprunner start-deployment --service-arn <roshambo-service-arn> --region us-east-1
```
Note: App Runner builds whatever branch/source it's configured for. If that's `main` and this work isn't merged there yet, the deploy won't include the current `/api/v1` surface — confirm the configured source branch first. This step is optional for *local* Roblox dev (which uses `localhost`), and can be deferred to milestone 5.

- [ ] **Step 3: Final state check**

```bash
docker compose up -d --build          # server + frontend only
docker ps --format '{{.Names}}'       # expect: roshambo-server, roshambo-frontend (no db)
```

---

## Self-Review

**1. Spec coverage:** Atlas two-db model (Task 1) ✓; local server → dev (Task 2) ✓; compose mongo removal (Task 3) ✓; Roblox `SecretsLocal` + gate (Task 4) ✓; docs (Task 5) ✓; teardown + recommended redeploy (Task 6) ✓. Economy split correctly absent (out of scope).

**2. Placeholder scan:** the `<devUser>`, `<pw>`, `<UserId>`, `<the API_KEY value from server/.env>`, `<roshambo-service-arn>` markers are intentional user/runtime-supplied values (secrets or per-run ids), not plan gaps — each has an explicit source named.

**3. Consistency:** the dev `API_KEY` is sourced once (Task 2 Step 3) and reused verbatim in Task 4's `SecretsLocal` and every curl; the compose `env_file` change (Task 3) is consistent with `server/.env` carrying all five env keys (Global Constraints). `docker-compose.yml` is the only committed code deliverable; `.env` and `SecretsLocal.luau` are explicitly never committed.

**4. Secret hygiene:** no task prints or commits a raw connection string; `index.ts:28` redaction is relied upon for logs.

## Execution Handoff

This plan is an ops runbook with two gitignored local files, three user-performed console steps, and manual verification gates — it does **not** fit subagent-driven development (nothing to parallelize, shared machine/console state, secrets that can't leave the local shell).

**Recommended: Inline execution** — I run the repo edits and verifications in this session, and pause at the **[USER OPS]** gates (Task 1 Atlas provisioning; Task 6 redeploy) for you to act in the Atlas/AWS consoles and paste results back.

The hard dependency: **Task 1 must produce a working `roshambo-dev` connection string before anything else runs.** Until you provision that in Atlas and I smoke-test it (Task 1 Step 3), Tasks 2–6 are blocked.
