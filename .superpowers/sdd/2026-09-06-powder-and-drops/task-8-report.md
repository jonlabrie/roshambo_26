# Task 8 report — docs, push, CI, STOP

## Wiki lint

- **Before:** `37 error(s), 9 warning(s) across 58 pages`
- **After:** `36 error(s), 8 warning(s) across 58 pages`

Did not rise; it fell by one error and one warning, because the `updated:` bumps on
`backlog.md` and `hanabiya.md` cleared a currency-check lag. The residual 36 errors are
all pre-existing `log.md: malformed entry` lines (historic non-schema kinds such as
`shipped`/`fixed`/`reverted`); the new entry uses `ship` and is not among them.

Command: `node tools/wiki/lint.mjs` from the worktree root.

## Files edited

- `docs/wiki/world/core-loop.md` — fifth economy field `powder` after `bestPot`; the
  list's lead-in changed "Four fields" → "Five" so the page does not contradict itself.
  `updated:` 2026-08-27 → 2026-09-06.
- `docs/wiki/world/fireworks.md` — new `## Powder and drops (sub-project A, built
  2026-09-06)` inserted before `## Raw layer` (mirroring where sub-project B sits).
  Includes the ticket-idempotence note for sub-project C. `updated:` already 2026-09-06.
- `docs/wiki/world/hanabiya.md` — new `## Melting (backend only, 2026-09-06)`: route
  exists, counter verb waits for the `main.server.luau` split. `updated:` → 2026-09-06.
- `docs/wiki/program/backlog.md` — two new sections after the show-system decisions:
  `## Hanabiya melt verb` and `## Powder grant must be exactly-once before ProcessReceipt
  calls it`. `updated:` → 2026-09-06.
- `docs/wiki/log.md` — `## [2026-09-06] ship | Powder + drops (sub-project A): the second
  economy, sealed; wins drop by streak tier`. Test counts carried as at-plan-time with
  their re-run commands, per schema rule 9.

Cited paths verified to exist before writing: the plan, `shared-fixtures/firework-drops.json`,
`shared-fixtures/firework-shells.json` (`powderIneligible` empty), the three routes in
`server/src/routes/apiV1.ts`, the `$push` in `server/src/engine/Settlement.ts`.

`.superpowers/sdd/.gitignore` checked per schema rule 4 — intact (not clobbered), unchanged.

## Commit

`d484d8e` — `docs(wiki): powder is the second economy and not points; drops by streak tier;
the melt verb and the exactly-once grant are banked` (5 files, +74 / −4). Only the five wiki
files staged; `.superpowers/` left untracked.

## Push

`git fetch origin && git push -u origin thread/powder` — new branch created on origin,
upstream set. Nine commits on the branch (Tasks 1–7 + this one + the plan commit).

## CI (head `d484d8e`)

| workflow | status | conclusion | URL |
|---|---|---|---|
| `roblox-ci` | completed | **success** | https://github.com/jonlabrie/roshambo_26/actions/runs/34054718987 |
| `server-ci` | completed | **success** | https://github.com/jonlabrie/roshambo_26/actions/runs/34054718998 |

Both triggered, both green. No failures to capture.

## STOP

Branch `thread/powder` is pushed and green. **Not merged** — the merge goes through the main
thread. After the merge, dev needs a manual App Runner `start-deployment` to pick this up
(auto-deploy is off on `roshambo_server_dev`; verify with the query in `CLAUDE.md` before
repeating that).
