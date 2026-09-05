# Task 7 report — Docs, the branch push, and the A13 gate (owner-run)

## What was done

Two wiki files edited on `thread/shows` (worktree `.worktrees/shows`), committed, pushed.
Nothing was merged: the terminal session owns `main` for code (`docs/wiki/practice/parallel-threads.md`).

### `docs/wiki/world/fireworks.md`

`updated:` bumped 2026-09-04 → 2026-09-05 (`checked:` left at 2026-08-27 — no full re-read
was claimed). New section **"Shows and the sequencer (sub-project B, built 2026-09-05)"**,
placed before `## Raw layer` so the page's raw-layer pointers stay last (the brief said
"append"; this is the same text, one section earlier). It records:

- the show format, the shared fixture and the two validators;
- limits as config (`SHOW_LIMITS` / `ShowPlan.LIMITS`) with an explicit "read them, do not
  quote them" — schema rule 9;
- **a hostile cue table with holes is refused before validation** (`Launch.denseCues`),
  with the reason (`ipairs` stops at the first gap, so only a prefix would have been checked);
- reserve-then-play, one conditional update or nothing, inventory fuel, deck stage only;
- server-owned playback on its own clock, one show per stage, second queued behind;
- **origins snapshotted at go** — one muzzle resolve per distinct mortar slot plus the hand
  frame — so a show outlives its owner leaving (this replaces the brief's "resolved per cue
  at fire time", which was true of an earlier draft and is no longer);
- ⚠ **the live constraint**: `main.server.luau` is at Luau's 200-local-register ceiling, every
  server-side addition hangs off a single `Launch` namespace table, `roblox/tests/Compiles.spec.luau`
  is the gate, exactly one top-level slot remained after this work, and the file needs real
  module extraction before further server work;
- the Studio-only proving verb: `warmup` (5 cues) and `finale_v1` (109 cues as authored
  2026-09-05, last at 71.3 s, densest window six cues inside 300 ms) — written with the file
  and the spec test named as the way to re-measure rather than as bare transcribed numbers;
- **the A13 gate procedure**, ending "Result: **not yet run** at merge — this line is the live fact."

### `docs/wiki/log.md`

One appended entry: `## [2026-09-05] ship | Fireworks shows + sequencer (sub-project B): shows
are data, reserved atomically, played by the server`. Amended from the brief with the origin
snapshot and the hole-refusal, plus a closing paragraph on the register ceiling and the need for
module extraction.

## Wiki lint

`node tools/wiki/lint.mjs | tail -1`, from the worktree root:

- **before**: `36 error(s), 7 warning(s) across 58 pages`
- **after**:  `36 error(s), 7 warning(s) across 58 pages`

Unchanged. Every pre-existing error is `log.md: malformed entry` for historical entries whose
kind is outside the schema's set (`fix`, `shipped`, `correction`, `perf`, …) — none of them from
this task; the new entry uses `ship` and passes. No new dead citations, symbols or stale-page
warnings: every path and symbol the new section names resolves in the tree.

## Commit and push

- commit `f2f0b2f` — `docs(wiki): fireworks shows + sequencer as-built; the A13 gate as a live fact`
  (only the two wiki files staged; `.superpowers/` deliberately not staged)
- `git fetch origin && git push -u origin thread/shows` → `* [new branch] thread/shows -> thread/shows`,
  tracking set. PR link offered by the remote:
  https://github.com/jonlabrie/roshambo_26/pull/new/thread/shows

## CI (head `f2f0b2f`)

Both workflows triggered, as expected — `server/` and `roblox/` both changed on the branch.

| workflow | conclusion | run |
| --- | --- | --- |
| `roblox-ci` | **success** | https://github.com/jonlabrie/roshambo_26/actions/runs/33991784924 |
| `server-ci` | **success** | https://github.com/jonlabrie/roshambo_26/actions/runs/33991784970 |

(`gh run list` returns nothing on this machine's ancient `gh`; read via
`gh api repos/jonlabrie/roshambo_26/actions/runs?branch=thread/shows`.)

## The A13 gate — where the procedure lives

`docs/wiki/world/fireworks.md`, § "Shows and the sequencer (sub-project B, built 2026-09-05)",
final paragraph ("**The A13 gate — measure, don't assume.**"). It is owner-run, in Play, with the
A13 joined to the same server: play `finale_v1` from the proving panel's *Shows* section, standing
at the arena square and again at a west teahouse, and record frame-rate behaviour through the 15 s,
32–33 s and 62–65 s volleys; whether bursts are visibly staggered (expected, by a few hundred ms)
or dropped (never expected); and audio reach. Park the bench immediately after per the standing
rule. The wiki line currently reads "not yet run" and is the live fact until the owner replaces it.

## Stopped here, deliberately

No merge, no rebase, no push to `main`. The `finishing-a-development-branch` skill presents the
merge options once the owner has run the gate.

## Note for the caller

`.superpowers/sdd/2026-09-05-fireworks-shows-sequencer/` shows as untracked in `git status` —
consistent with the schema's standing warning (rule 4) that the SDD tooling clobbers
`.superpowers/sdd/.gitignore` with a bare `*` on every brief and review package. Not touched here
(the task forbids staging `.superpowers/`), but the ledger is a cited deliverable in this repo, so
someone should restore that file and commit the ledger markdown before the branch is finished.

## Task 7 review-fix: unmerged status stated in the log entry

Review finding: the `## [2026-09-05] ship | Fireworks shows + sequencer …` entry never said the
work was unmerged, unlike comparable in-flight entries (e.g. the 2026-09-01 proving-range entry's
"NOT merged; comments pending"). Fixed by appending one sentence to the end of the entry's first
paragraph (after "`[[fireworks]] when it happens.`", before the closing paragraph about the
register-ceiling namespace hack, which is a separate technical note): "Still on `thread/shows`,
NOT merged to `main` — the merge goes through the main thread once the A13 gate has run (owner's
call)." Applied via a small Python replace asserting the anchor text occurred exactly once in
`docs/wiki/log.md` before editing, so the file could not be silently truncated.

`node tools/wiki/lint.mjs | tail -1` — unchanged: `36 error(s), 7 warning(s) across 58 pages`.

Commit `c1dfebe` — `docs(wiki): the shows ship entry says it is unmerged on thread/shows` (only
`docs/wiki/log.md` staged; `.superpowers/` left untouched). Pushed: `f2f0b2f..c1dfebe
thread/shows -> thread/shows`. No merge, no rebase, nothing touched on `main`.
