---
shelf: systems
updated: 2026-08-15
---

# Data

Where Roshambo's data lives. One MongoDB Atlas cluster
(`roshambocluster0.ckjseml.mongodb.net`) backs everything — there is no local
MongoDB, no container, no per-environment cluster. Full setup steps:
`README_DEPLOY.md` §0/§1.

## As built

- **Production** → Atlas db `roshambo`, read via SSM `/roshambo/MONGODB_URI` (App
  Runner reads secrets at deploy time — a config change needs
  `aws apprunner start-deployment` to take effect).
- **Dev / Roblox Studio** → Atlas db `roshambo-dev`, used by the cloud dev backend
  ([[deploy]]) and by the local fallback (`docker compose up` / `server: npm run
  dev`, reading `server/.env`, gitignored).
- `roshambo_app` Atlas user has `readWriteAnyDatabase`; its password was rotated
  2026-07-07 (current value lives only in `server/.env` / SSM, never in git).
- Closed legacy gotcha: before the 2026-07-07 consolidation, connection strings
  omitted the db path and the driver defaulted to db `test` — 87 users / ~586k junk
  TEST_MODE rounds landed there. `test` is orphaned, static, and droppable; nothing
  writes to it now.
- The Roblox/PWA economy split (shared wallet ruled non-viable under Roblox policy)
  is enforced in the **schema** — per-platform wallet fields on one shared
  rounds/throws/stats collection set — never as a separate database. See
  [[backlog]] § Meta-game spec.

## Raw layer

- `README_DEPLOY.md` §0/§1 (Atlas setup)
- spec/plan: `docs/superpowers/specs/2026-07-07-roshambo-atlas-consolidation*`
- key commits: `ea8ddf6` (docker-compose mongo removal), `b9185ce` (docs)
