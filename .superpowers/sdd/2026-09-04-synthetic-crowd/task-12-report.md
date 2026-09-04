# Task 12 report — Documentation: as-built, env vars, the flip procedure, the log

Commit: `3de3bb1` docs(wiki): synthetic crowd as-built, env vars, the dev flip procedure, ship entry
Branch: `thread/crowd` (worktree `.worktrees/crowd`). No `aws` command was run; dev was not touched.

## What each file now says

- **`docs/wiki/world/world-throw.md`** (`updated:` bumped 2026-08-16 → 2026-09-04; `checked: 2026-08-27`
  left alone, since the lint takes `max(checked, updated)` and bumping it would assert a re-read date
  older than the edit). The old "⚠ Not active in any deployed environment" paragraph is DELETED and
  replaced by the "as of the date at the top of this page / whether dev has been flipped is a live
  fact — query the service" version. A new final section **§ Synthetic crowd (built 2026-09-04)**
  records: the tally-crowd design (merge before `pickWorldThrow`, humans-only `throws` map,
  `Round.synthetic`, `totalPlayers` = humans + bots per the owner decision); the archetypes with the
  ⚠ "hypothesis, not a measurement" flag and the recalibration path; the three env vars, pointing at
  `DEFAULT_MIX` / `DEFAULT_STRENGTH` in `server/src/engine/SyntheticCrowd.ts` rather than naming
  values (schema rule 9); the sim invocation with "re-run it rather than quoting"; and all three
  Task 11 outputs pasted verbatim in fenced blocks. Then "How the mix was settled, and against which
  targets": pre-registered ≥45% / ≤~60% / blind-near-chance, all three holding at seeds 1–3 with the
  best teachable rule (`second`) at 51.4–52.4%; the **widened 29–34% blind band** with its structural
  reason (a blind human's own throw is inside the tally it is judged against, so the rate sits near
  29.5% whatever the mix — ~40 cells probed; the `random` row is a null hypothesis, not a target);
  the **wsls-clockwise-lands-on-the-counter-throw mechanism** that made the pre-tuning default too
  readable and why raising `conform` (not `random`) was the fix; and the expected consequence that
  `conform` is now a near-dead rule at ~6%. Ends with pre-registered **Q1 at ≥45% BEAT WORLD over
  ~20 owner rounds — not yet run**.

- **`docs/wiki/systems/deploy.md`** (`updated:` 2026-08-27 → 2026-09-04). The "Both environments run
  `TEST_MODE=true`" bullet is replaced by the past-tense "ran … as of 2026-08-16" version that points
  at [[world-throw]] § Synthetic crowd and says whether dev has been flipped is a live fact. A new
  section **"Flipping dev to the real World Throw with a synthetic crowd"** carries the owner-gated
  five-step procedure: describe-service round-trip, the ⚠ `ConfigurationSource` REPOSITORY/API check
  that stops the procedure if the service takes its env from `apprunner.yaml`, the env edits
  (`TEST_MODE=false`, `CROWD_SIZE=30`, optional `CROWD_SEED`, secrets left untouched), `update-service`,
  CloudWatch verification of the `[CROWD]` boot lines, and "record the flip and update the live-fact
  lines". Plus the turn-it-back-off note. It states **not done as of 2026-09-04** while pointing at
  step 1's query as the actual answer.

- **`CLAUDE.md`** — one sentence appended to the server-env paragraph under "## Commands": with
  `TEST_MODE` off, `CROWD_SIZE=<n>` adds the synthetic crowd (`CROWD_MIX`, `CROWD_SEED` optional,
  pointer to the wiki section), and `cd server && npm run sim` runs the offline simulator.

- **`docs/wiki/log.md`** — appended `## [2026-09-04] ship | Synthetic crowd -- the World Throw rule
  can be played without a human crowd`, adjusted from the brief to name the settled mix
  `wsls:30,counter:10,conform:30,rocky:10,random:20` at strength 0.7 and to say the numbers, targets
  and widened blind band live on [[world-throw]].

- **`docs/superpowers/plans/2026-09-04-synthetic-crowd.md`** — Task 7 Step 6's expected banner fixed
  from `mix wsls:35,counter:20,conform:15,rocky:10,random:20` to `mix
  random:20,wsls:30,counter:10,conform:30,rocky:10` (formatMix prints in POLICY_IDS order at the
  settled mix). The two other `wsls:35` occurrences in that file (lines 432, 453) are `parseMix` /
  allocation test fixtures, not claims about the default, and were left alone.

## Lint

`tools/wiki/lint.mjs` exists (no wiki job in `.github/workflows/` — `grep -rl wiki` there returns
nothing). Baseline before my edits: **35 errors, 1 warning**, none of them mine (pre-existing
`re-read —` staleness on six other pages, ~29 malformed `log.md` entries using non-schema kinds like
`fixed`/`shipped`/`ruling`, and one orphan warning). My first draft added **2 new errors**, both fixed:

- `systems/deploy.md: dead wikilink [[log]]` — `log.md` sits at the wiki root, not in a shelf, so the
  lint's page set does not contain it. Changed to a `docs/wiki/log.md` citation, matching how
  `practice/parallel-threads.md` and `world/canyon.md` refer to it.
- `systems/deploy.md: cited symbol \`REPOSITORY\` exists nowhere in the repo` — the lint checks every
  backticked SHOUTY_CONSTANT against the source tree, and `REPOSITORY` is an AWS App Runner API enum
  value. Un-backticked to **REPOSITORY** / **API** rather than adding a `lint-ok` comment inside the
  numbered procedure.

Final: **35 errors, 1 warning — exactly the baseline**, with no error or warning on
`world/world-throw.md` or `systems/deploy.md`.

## Self-review findings (each fixed before the commit)

1. **A self-contradiction I introduced.** The Q1 paragraph carried the brief's "≈33% means the crowd
   is too noisy", which fights the widened 29–34% blind band four paragraphs above it — 33% is
   *inside* the band. Rewritten to "a rate down in the blind band (29–34%, above)".
2. **A duplicated clause** ("A blind human's / A blind human's own throw…") left by an in-place
   `python3` replace; the whole bullet was rewritten.
3. **Over-claiming on the targets.** The first draft said the settled mix "satisfies all three"
   targets and then immediately qualified the blind one — reading as an argument with itself. Now it
   states the three results plainly and handles the band widening as its own ⚠ bullet.
4. **Checked for standing contradictions elsewhere and found none needing this commit:**
   `CLAUDE.md`'s Architecture line ("BOTH prod and dev run TEST_MODE, so the rule is … not yet
   exercised anywhere") and `docs/wiki/program/parked-defects.md` (h) ("deliberately NOT active in
   any deployed environment yet") are both still true — dev has not been flipped. They become wrong
   the moment it is, which is why deploy.md step 5 names the pages to update.

## Concerns

- **`.superpowers/sdd/.gitignore` is dirty in this worktree** (clobbered to a bare `*` by the SDD
  scripts — schema rule 4). It was already modified at session start and is outside my file list, so
  I deliberately did not stage or restore it. Whoever closes this run needs
  `git checkout -- .superpowers/sdd/.gitignore` and must commit the ledger markdown, or the wiki's
  citations to this plan's ledgers will not resolve in a clone.
- The pre-existing 35 lint errors are untouched and unrelated (other threads' pages and log entries);
  fixing them was not in scope.

---

## Review fix (2026-09-04) — commit `a38c6d3`

One Important review finding, ruled must-fix: step 5 of "Flipping dev to the real World Throw
with a synthetic crowd" named only two pages to update after a flip, while four carry the
soon-to-be-false claim.

**Changed:** `docs/wiki/systems/deploy.md` only — step 5 of that procedure, still one numbered
step. It now says four pages, and names them: the "live fact" lines on this page and on
[[world-throw]], the closing paragraph of item (h) on [[parked-defects]] ("deliberately NOT
active in any deployed environment yet"), and the `CLAUDE.md` Architecture paragraph ("BOTH prod
and dev run `TEST_MODE`…"), with the note that all four are true until the flip and false the
moment it lands. The two currently-true statements themselves were not touched.

**Lint:** `node tools/wiki/lint.mjs` → `35 error(s), 1 warning(s) across 58 pages` — the same
baseline, with nothing reported on `systems/deploy.md`. `[[parked-defects]]` resolves (it is a
real page under `docs/wiki/program/`), and `` `CLAUDE.md` `` is not read as a code symbol because
`md` is in the lint's EXTENSIONS set.
