### Task 7: Docs, the merge, and the A13 gate (owner-run)

**Files:**
- Modify: `docs/wiki/world/fireworks.md` (append an as-built section; bump `updated:`)
- Modify: `docs/wiki/log.md` (append a `ship` entry)

- [ ] **Step 1: `docs/wiki/world/fireworks.md`** — append:

```markdown
## Shows and the sequencer (sub-project B, built 2026-09)

Spec `docs/superpowers/specs/2026-09-05-fireworks-show-system-design.md` §1–§3; plan
`docs/superpowers/plans/2026-09-05-fireworks-shows-sequencer.md`.

**A show is data**: cues of `{ t_ms, slot, shellId }`, validated by twins held to
`shared-fixtures/shows.json` (`server/src/shows.ts`, `roblox/src/shared/ShowPlan.luau`). Limits
are config (`SHOW_LIMITS` / `ShowPlan.LIMITS`: read them, do not quote them). **Reserve, then
play**: `POST /api/v1/players/:id/shows/reserve` debits every shell in ONE conditional update or
nothing (inventory fuel only — powder is sub-project A; deck stage only — the rooftop and stations
arrive with consoles in C). The game server plays a reserved show on its own clock
(`ShowPlayer.luau` timing; one show per stage, a second queues behind), emitting each cue through
the same `FireworkLaunched` broadcast as a hand launch, with `showId` added and the pity ramp
applied per cue. Playback outlives the owner leaving.

**Studio-only proving verb**: the proving panel's *Shows* section plays `FireworkShows.DRAFTS`
(`warmup`, `finale_v1`) from the five stations and the rooftop battery. `finale_v1` is the stress
program — volleys of six inside 300 ms and stacked heavies — authored to exercise the director's
concurrent-shell budget at scale for the first time.

**The A13 gate — measure, don't assume.** Run `finale_v1` from the panel with the A13 joined to the
same server, standing at the arena square and again at a west teahouse. Record: frame-rate
behaviour during the 15 s, 32–33 s and 62–65 s volleys; whether bursts are visibly staggered
(expected: yes, by a few hundred ms) or dropped (never expected); audio reach. Park the bench per
the standing rule. Result: **not yet run** at merge — this line is the live fact.
```

- [ ] **Step 2: `docs/wiki/log.md`** — append:

```markdown
## [2026-09-0X] ship | Fireworks shows + sequencer (sub-project B): shows are data, reserved atomically, played by the server

Plan `docs/superpowers/plans/2026-09-05-fireworks-shows-sequencer.md`. Shared fixture
`shared-fixtures/shows.json` with TS/Luau twins; `POST /shows/reserve` (all-or-nothing, inventory
fuel, own deck only); `ShowPlayer.luau`; `RequestShowGo` playback through `FireworkLaunched` with
`showId`; boost roll, broadcast and proving origin resolution extracted and shared; `FireworkShows`
drafts and the panel's Studio-only Play verb. The A13 stress run (`finale_v1`) is the exit gate and
is owner-run; result recorded on [[fireworks]] when it happens.
```

(Replace `0X` with the actual day.)

- [ ] **Step 3: Lint, commit, push the branch, CI**

Run from the repo root: `node tools/wiki/lint.mjs | tail -1` (count must not rise).

```bash
git add docs/wiki/world/fireworks.md docs/wiki/log.md
git commit -m "docs(wiki): fireworks shows + sequencer as-built; the A13 gate as a live fact

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git fetch origin && git push -u origin thread/shows
```

Confirm `server-ci` and `roblox-ci` are green on the branch before reporting.

- [ ] **Step 4: STOP — the owner's part**

Report to the owner: the branch, the CI links, the Studio check from Task 5 Step 6 (done or not), and the A13 procedure above. The owner runs the gate in Play with the A13; the finishing-a-development-branch skill presents the merge options. Do not merge `thread/shows` yourself; the terminal session owns `main` for code ([[parallel-threads]]).

---

## Self-review against the spec

- §1 show format, limits as config, shared validation with a fixture, fire-now as a one-cue show on the same path: Tasks 1–2 (format, fixture, twins); Task 5 (a one-cue show is just a show — no second path). ✔
- §2 reserve everything up front / once lit lit: Task 4 (single conditional update, 409 debits nothing); playback on the server's clock through `FireworkLaunched` with `by` + `showId`: Task 5; director untouched: Task 5 adds no throttling; owner leaves → continues: `task.delay` closures capture the deck frame, not the player; one show per stage, queued behind: Task 3 `schedule` + Task 5 `stageBusyUntilMs`. ✔
- §3 deck stage owner-only, rooftop/stations not reachable by players yet: Task 4 `BAD_STAGE`, Task 5 deck-only; proving slots only via the Studio gate: Task 6. ✔
- §10 row B deliverables: format+fixture (T1–2), `ShowPlayer` (T3), reserve (T4), playback (T5), proving verb + drafts (T6), the A13 test (T7 gate). ✔
- §12 testing: seal-type tests are sub-project A (no powder here); reserve atomicity, concurrency, validator cases both sides, timeline, drafts validity: present. ✔
- Type consistency: `Cue { t_ms, slot, shellId }` identical in TS and Luau; validator error codes identical; `cue` index zero-based on both sides (Task 2 note); `ShowPlayer.schedule(busyUntilMs?, nowMs, cues)` used the same way in Task 5; `broadcastLaunch` field names match the client's checks (`origin: Vector3`, `seed: number`, `shellId: string`). ✔
- Placeholders: none. Two "read the file for the exact name" instructions remain (the shared-module `require` form and `Result` field names in Task 5, the rack lookup in Task 6) because the file is 1700+ lines and the names must be copied, not guessed; each says exactly what to look for.
