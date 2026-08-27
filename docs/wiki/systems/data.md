---
shelf: systems
updated: 2026-08-27
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
- ⚠ **The Roblox/PWA economy split is enforced by IDENTITY, not by the schema — and this
  line used to say the opposite.** It claimed "per-platform wallet fields on one shared
  collection set". There are no such fields: `User` has one `totalPoints` and one
  `pointsAtStake`. Traced 2026-08-27.

  What actually enforces it: `resolveUser` returns on its FIRST branch for a
  `robloxUserId`, before any merge logic, and `robloxId` is written in exactly one place in
  the whole server. Nothing links a `robloxId` to a `deviceId` or an auth account — `auth.ts`
  and `store.ts` never mention it. So the two platforms always resolve to DIFFERENT User
  documents, and a Roblox-earned point cannot reach the PWA store because that store operates
  on a document the Roblox player does not have. Both id fields carry `unique, sparse`
  indexes. Shared wallet was ruled non-viable under Roblox policy (`ef6ced9`); never a
  separate database. See [[backlog]] § Meta-game spec.

  ⚠ **THE ENFORCEMENT IS CONTINGENT, NOT STRUCTURAL — it holds only because no linking flow
  exists, and it is one provider string from not holding.** `/auth/sso` is already a linking
  route (google/apple/facebook/instagram): it finds a user by email or deviceId and writes the
  provider id onto THAT document. Add `roblox` as a fifth provider and it would write
  `robloxId` onto the PWA's document while the game server's document already holds it.
  The unique index turns that into an unhandled **E11000** at login rather than a silent
  merge — an accidental guard, and the reason this is a gate rather than a disaster. ⚠ **The
  obvious repair for that error — "resolve to the existing Roblox document instead" — IS the
  silent merge, and would ship as a bugfix.** See [[identity]] and [[parked-defects]] (i).

  `identityTier` is the seam where genuine per-platform balances would go if one human is ever
  meant to mean one document.

## Raw layer

- `README_DEPLOY.md` §0/§1 (Atlas setup)
- spec/plan: `docs/superpowers/specs/2026-07-07-roshambo-atlas-consolidation*`
- key commits: `ea8ddf6` (docker-compose mongo removal), `b9185ce` (docs)
