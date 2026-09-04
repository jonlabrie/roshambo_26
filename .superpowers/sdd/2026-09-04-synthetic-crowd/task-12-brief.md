### Task 12: Documentation — as-built, env vars, the flip procedure, the log

**Files:**
- Modify: `docs/wiki/world/world-throw.md` (append a section; update the ⚠ "Not active in any deployed environment" paragraph)
- Modify: `docs/wiki/systems/deploy.md` (the "Both environments run TEST_MODE=true" bullet; append the flip procedure)
- Modify: `CLAUDE.md` (the server env paragraph under "## Commands")
- Modify: `docs/wiki/log.md` (append a `ship` entry)

Per `docs/wiki/schema.md`: supersede text, don't append contradictions; never transcribe a measurable fact without saying how to re-measure it.

- [ ] **Step 1: `docs/wiki/world/world-throw.md`**

Replace the final ⚠ paragraph ("⚠ **Not active in any deployed environment.** …") with:

```markdown
⚠ **Not active in any deployed environment as of the date at the top of this page** — both
services run `TEST_MODE=true`, which keeps the deterministic R→P→S cycle. Since 2026-09-04 the
rule no longer needs a human crowd to be exercised: see § Synthetic crowd below. Whether dev
has been flipped is a live fact — query the service ([[deploy]]), do not trust this line.
```

Append:

```markdown
## Synthetic crowd (built 2026-09-04)

Spec `docs/superpowers/specs/2026-09-04-synthetic-crowd-design.md`; plan
`docs/superpowers/plans/2026-09-04-synthetic-crowd.md`.

**What it is.** A tally crowd — bot throws that count toward the World Throw and appear in the
reveal's distribution, with no avatars. `RoundEngine` merges the bots' counts into the tally at
LOCK→REVEAL **before** `pickWorldThrow`, so the distribution on the card and the throw it
produced always agree; the per-participant `throws` map stays human-only, which is why bots
never reach settlement, `PlayerRound`, presence or any board. `Round.synthetic` records the
bot count; **`totalPlayers` is the size of the world (humans + bots)** — owner decision
2026-09-04, and the PLAYERS figure on the ledger and the stats board now means exactly that.

**Archetypes** (`server/src/engine/CrowdPolicies.ts`): `wsls` (win-stay / lose-shift-clockwise,
Wang–Xu–Zhou 2014), `counter`, `conform`, `rocky`, `random`, and the sim-only `second`. Each
is a distribution given a small memory, blended with uniform at a strength; the mix across
archetypes is the other dial. ⚠ **A hypothesis about a Roblox crowd, not a measurement.** The
recalibration path is the persisted `Round.distribution` minus the synthetic share (spec §8).

**Config** — `CROWD_SIZE` (0 = off), `CROWD_MIX` (`id:weight,…`), `CROWD_SEED`. Malformed
values refuse to boot. `CROWD_SIZE` under `TEST_MODE=true` is ignored with a warning. Read the
defaults from `DEFAULT_MIX` / `DEFAULT_STRENGTH` in `server/src/engine/SyntheticCrowd.ts`
rather than from here.

**The simulator** — `cd server && npm run sim -- --experiment readability|blind-spread|effective-n`.
Re-run it rather than quoting the numbers below; they are one seed on one day.

Readability at the settled default mix (`--rounds 20000 --seed 1`):

<paste /tmp/readability.txt here>

Blind-field spread (`--experiment blind-spread --rounds 360 --seed 1`):

<paste /tmp/blind.txt here>

Effective N (`--experiment effective-n --rounds 5000 --seed 1`):

<paste /tmp/effn.txt here>

**Pre-registered Q1** (owner decision 2026-09-04): one person, ~20 rounds on dev against the
default crowd with the last-five HUD; **≥ 45% BEAT WORLD** reads as "crowd-reading is a skill
here", ≈33% means the crowd is too noisy or the HUD shows the wrong thing. Result: not yet run.
```

(Replace each `<paste …>` with the actual output from Task 11 Step 4 inside a fenced code block.)

- [ ] **Step 2: `docs/wiki/systems/deploy.md`**

Replace the bullet beginning "**Both environments run `TEST_MODE=true`**" with:

```markdown
- **Both environments ran `TEST_MODE=true` as of 2026-08-16** (dev verified against the live
  service config, prod set in `apprunner.yaml`). Since 2026-09-04 the crowd-plurality rule can
  run without humans: the synthetic crowd ([[world-throw]] § Synthetic crowd) is three env vars
  on the service. **Whether dev has been flipped is a live fact — run the query below.**
```

Append a section:

```markdown
## Flipping dev to the real World Throw with a synthetic crowd

⚠ Owner-run or owner-approved, announced first: it bounces the dev backend under any live
Studio session. Prod is not touched by this procedure.

1. Read the current config and keep every field — `update-service` replaces
   `SourceConfiguration` wholesale (see the secrets warning above):
   ```bash
   ARN=$(aws apprunner list-services --region us-east-1 \
     --query "ServiceSummaryList[?ServiceName=='roshambo_server_dev'].ServiceArn" --output text)
   aws apprunner describe-service --region us-east-1 --service-arn "$ARN" \
     --query 'Service.SourceConfiguration' > /tmp/dev-source.json
   ```
2. ⚠ First check `CodeRepository.CodeConfiguration.ConfigurationSource` in that file. If it is
   `REPOSITORY`, the service takes its env from `apprunner.yaml` in the tracked branch and this
   procedure does not apply — stop and raise it with the owner (a yaml edit would also change
   prod's template). If it is `API`, edit `/tmp/dev-source.json`: under
   `CodeRepository.CodeConfiguration.CodeConfigurationValues.RuntimeEnvironmentVariables`
   set `TEST_MODE` to `"false"` and add `CROWD_SIZE: "30"`. Add `CROWD_SEED` only for a
   reproducible demo. Leave `RuntimeEnvironmentSecrets` exactly as read.
3. Apply, round-tripping the whole object:
   ```bash
   aws apprunner update-service --region us-east-1 --service-arn "$ARN" \
     --source-configuration file:///tmp/dev-source.json
   ```
4. Verify from the service logs (CloudWatch, application log group for the service): the boot
   prints `[CROWD] on: size 30, seed …, mix …` and `world throw: crowd plurality, min 5
   participants`, then one `[CROWD] round …` line per minute.
5. Record the flip on [[log]] and update the "live fact" lines on this page and on
   [[world-throw]].

To turn it back off, set `CROWD_SIZE` to `"0"` (and `TEST_MODE` back to `"true"` if the
deterministic demo is wanted) by the same round-trip.
```

- [ ] **Step 3: `CLAUDE.md`**

In the "## Commands" section, after the sentence ending "Set `TEST_MODE=true` on the server for a deterministic World Throw cycle (R→P→S) instead of random.", add:

```markdown
With `TEST_MODE` off, `CROWD_SIZE=<n>` adds a synthetic bot crowd to every round's tally (`CROWD_MIX`, `CROWD_SEED` optional; see `docs/wiki/world/world-throw.md` § Synthetic crowd). `cd server && npm run sim` runs the offline simulator over the same crowd.
```

- [ ] **Step 4: `docs/wiki/log.md`** — append:

```markdown
## [2026-09-04] ship | Synthetic crowd -- the World Throw rule can be played without a human crowd

Spec `docs/superpowers/specs/2026-09-04-synthetic-crowd-design.md`, plan
`docs/superpowers/plans/2026-09-04-synthetic-crowd.md`. `RoundEngine` merges a seeded,
archetyped bot crowd into the tally at LOCK→REVEAL before `pickWorldThrow`; bots never enter
the throws map, so settlement and presence stay human-only by construction. `Round.synthetic`
added; `totalPlayers` now counts the world. Three env vars, refused when malformed, ignored
under TEST_MODE. `npm run sim` runs readability / blind-spread / effective-n over the same
module. Default mix settled by the readability experiment (numbers on [[world-throw]]).
Dev NOT yet flipped — procedure on [[deploy]], owner-gated. Q1 (is crowd-reading fun?) not
yet run.
```

- [ ] **Step 5: Wiki lint, if the repo has one**

Run from the repo root: `ls tools/wiki* docs/wiki/*.sh 2>/dev/null; grep -rl "wiki" .github/workflows/ | head`. If a lint exists, run it and fix what it reports.

- [ ] **Step 6: Commit**

From the repo root:

```bash
git add docs/wiki/world/world-throw.md docs/wiki/systems/deploy.md CLAUDE.md docs/wiki/log.md
git commit -m "docs(wiki): synthetic crowd as-built, env vars, the dev flip procedure, ship entry

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

