---
shelf: systems
updated: 2026-09-04
---

# Deploy

Where Roshambo code runs and how it gets there. Full topology + step-by-step AWS
setup: `README_DEPLOY.md`; day-to-day commands: CLAUDE.md "Commands"/"Deployment".


## ⚠ PROD IS PAUSED (2026-08-18)

`roshambo_server` (`fiuuwhrqgi`) is **PAUSED**, not deleted. It was `RUNNING` at 1 vCPU / 2 GB —
four times the dev service — and serving nothing: Amplify's `VITE_SOCKET_URL` points at
`zzaw22ugpq`, which is dev, so no traffic has reached prod at all.

App Runner bills **provisioned memory 24/7 whether or not anything calls the service**, adding
vCPU only when requests arrive. So an idle 2 GB instance is a standing monthly charge — larger,
by several times, than every build a heavy day of pushing produces.

**To bring it back:**

```
aws apprunner resume-service --region us-east-1 \
  --service-arn arn:aws:apprunner:us-east-1:198886313292:service/roshambo_server/0c7a58eea5624ebb843b7a4a05dc54d9
```

The service, its URL and its configuration all survive a pause; only compute stops. Auto-deploy
was already **off** on prod, so nothing about the push flow changes.

⚠ **Anything that assumed prod was reachable is now wrong.** Nothing does today, but a future
cutover must resume it BEFORE repointing `VITE_SOCKET_URL`.

⚠ **Cost Explorer is not enabled on this account**, which is why the numbers above are reasoned
from instance sizes rather than read off a bill. Enabling it takes a day to backfill and would
replace the estimate with the fact.

## ⚠ NOTHING AUTO-DEPLOYS ANY MORE (2026-08-25)

Owner ruling. **A push to `main` now builds nothing on AWS.** Both auto-deploys are off:

| | was | now | how |
|---|---|---|---|
| App Runner `roshambo_server_dev` | auto-deploy ON, branch `main` | **OFF** | `update-service`, full `SourceConfiguration` round-tripped |
| Amplify `roshambo_26` (`dnlwlh7md4i46`) | auto-build ON, branch `main` | **OFF** | `update-branch --no-enable-auto-build` |

**Why.** Neither service supports path filters, so both rebuilt on every push regardless of what
changed. The push that prompted this was 15 `roblox/` files and 7 `docs/` — **zero** frontend,
**zero** server — and it redeployed the backend and rebuilt the frontend anyway. Worse than
waste: the App Runner redeploy bounces the dev backend *that Studio is talking to*, so pushing
during a session disturbs the thing being tested.

GitHub Actions are unaffected and stay on — they are already path-filtered and run in 20–60s.
⚠ **The filters are wider than "one directory each", and `shared-fixtures/**` is in TWO of them**
(`roblox-ci` and `server-ci`), because it gates both GameRules mirrors — so a rules change
correctly runs both. Each workflow also watches its own file. Read the `paths:` keys in
`.github/workflows/*.yml` rather than a list here; this line said `src/**` and missed
`public/**` and `shared-fixtures/**`. ⚠ Their filter applies to the **whole push range**, not
per commit, so a batch containing one `roblox/` commit runs `roblox-ci` once even if the rest are
docs. That is correct: it tests the tree actually pushed.

**To deploy the dev backend** (after any `server/` change):

```bash
aws apprunner start-deployment --region us-east-1 \
  --service-arn arn:aws:apprunner:us-east-1:198886313292:service/roshambo_server_dev/a90bf91c601c4ef2910d7d48aa318398
```

**To deploy the frontend** (after any `src/` or `public/` change):

```bash
aws amplify start-job --region us-east-1 --app-id dnlwlh7md4i46 \
  --branch-name main --job-type RELEASE
```

⚠ **THE TRADE THIS BUYS, AND ITS COST.** Pushing server code no longer makes it live. Anyone
testing a server change against Studio must deploy explicitly and wait a few minutes, or they will
test the previous build and believe it is the new one. That failure is silent and looks exactly
like "my change did nothing".

## As built

- **Cloud dev backend is the default.** App Runner service `roshambo_server_dev`
  (`https://zzaw22ugpq.us-east-1.awsapprunner.com`), source GitHub branch **`main`**
  (repointed 2026-08-16 from the retired `m4b-zendojo-art-pass`; service id
  `a90bf91c601c4ef2910d7d48aa318398`, region `us-east-1`), auto-deploy **OFF as of
  2026-08-25** (see below). `roblox/src/server/SecretsLocal.luau` (gitignored) points at it.
  **Studio/PWA dev needs no local server** — `docker-compose up` / `server: npm run
  dev` are only for testing un-pushed server code before it reaches the dev service.
- Dev is configured via the App Runner **API**, not `apprunner.yaml`, so it can't
  inherit prod's `/roshambo/*` SSM secrets tree; its own secrets live at
  `/roshambo/dev/*`, reusing the same instance role's wildcard grant. See
  [[data]] for the database each side talks to.
  ⚠ **THAT SPLIT HAS A COST, PAID 2026-08-27:** `/roshambo/dev/JWT_SECRET` was the `.env`
  placeholder while prod's was properly generated — nothing propagates prod's discipline to a
  tree that cannot inherit from it. ⚠ **And "dev" is the PUBLIC-FACING service**: Amplify points
  at it while prod is paused, so a secret hygiene problem here is not a development problem.
  See [[parked-defects]] (k).
  ⚠ **`update-service` REPLACES `SourceConfiguration` wholesale, it does not merge.**
  A repoint that omits `RuntimeEnvironmentSecrets` silently drops all three secrets and
  the service comes back unable to reach Mongo. Always `describe-service` first and
  round-trip every field; the 2026-08-16 repoint did exactly that.
- **Dev was FLIPPED 2026-09-04**: `TEST_MODE=false`, `CROWD_SIZE=30`, no seed (the boot log
  names the generated one). Verified in the application log: `[CROWD] on: size 30 …` and one
  `[CROWD] round …` line per minute with 30 crowd votes. **Prod still runs `TEST_MODE=true`**
  (set in `apprunner.yaml`). Both are live facts — run the query below, do not trust this line.
- Prod is a separate App Runner service (via `apprunner.yaml`) + Amplify frontend.
  Prod auto-deploy is **OFF** — a push to GitHub does not redeploy prod; trigger it
  manually (console "Deploy" or `aws apprunner start-deployment`) after the branch
  reaches App Runner's source branch.
- App Runner → Amazon ECS Express Mode migration (both backends; App Runner is
  closed to new customers, no EOL deadline) is parked — see [[backlog]].

## Gates & decisions

- 2026-08-25 owner ruling: **both AWS auto-deploys off** — a push to `main` builds
  nothing on AWS. See the section above for why and for the two deploy commands.
- 2026-07-23 correction: never tell the user to start a local server for
  Studio/PWA testing — the cloud dev backend already covers it. ⚠ SUPERSEDED IN PART
  2026-08-25: it no longer auto-deploys, so reaching it now takes an explicit
  `start-deployment`. The rule against local servers stands; the "on push" part does not.

## Flipping dev to the real World Throw with a synthetic crowd

⚠ Owner-run or owner-approved, announced first: it bounces the dev backend under any live
Studio session. Prod is not touched by this procedure. **Done 2026-09-04** (see the bullet
above) — a live fact, so step 1's query is the answer, not this line. The procedure stays
here for the next flip in either direction.

1. Read the current config and keep every field — `update-service` replaces
   `SourceConfiguration` wholesale (see the secrets warning above):
   ```bash
   ARN=$(aws apprunner list-services --region us-east-1 \
     --query "ServiceSummaryList[?ServiceName=='roshambo_server_dev'].ServiceArn" --output text)
   aws apprunner describe-service --region us-east-1 --service-arn "$ARN" \
     --query 'Service.SourceConfiguration' > /tmp/dev-source.json
   ```
2. ⚠ First check `CodeRepository.CodeConfiguration.ConfigurationSource` in that file. If it is
   **REPOSITORY**, the service takes its env from `apprunner.yaml` in the tracked branch and this
   procedure does not apply — stop and raise it with the owner (a yaml edit would also change
   prod's template). If it is **API**, edit `/tmp/dev-source.json`: under
   `CodeRepository.CodeConfiguration.CodeConfigurationValues.RuntimeEnvironmentVariables`
   set `TEST_MODE` to `"false"` and add `CROWD_SIZE: "30"`. Add `CROWD_SEED` only for a
   reproducible demo. Leave `RuntimeEnvironmentSecrets` exactly as read.
3. Apply, round-tripping the whole object:
   ```bash
   aws apprunner update-service --region us-east-1 --service-arn "$ARN" \
     --source-configuration file:///tmp/dev-source.json
   ```
   ⚠ **An env-only `update-service` does NOT rebuild the source.** Learned 2026-09-04: with
   auto-deploy off, this step redeployed the previously built image with the new env — `TEST_MODE`
   took effect, but the crowd code pushed minutes earlier was not in it, and the boot log had no
   `[CROWD]` line. If the branch head has moved since the last build (check the service log group
   for `[Build]`/`[PostBuild]` lines under the new deployment id), follow with an explicit source
   deployment, which pulls the branch head:
   ```bash
   aws apprunner start-deployment --region us-east-1 --service-arn "$ARN"
   ```
4. Verify from the service logs (CloudWatch, application log group for the service): the boot
   prints `[CROWD] on: size 30, seed …, mix …` and `world throw: crowd plurality, min 5
   participants`, then one `[CROWD] round …` line per minute.
5. Record the flip on `docs/wiki/log.md`, then correct every page that says the rule is not live
   — there are **four**, and all four are true until this step and false the moment the flip lands:
   the "live fact" lines on this page and on [[world-throw]], the closing paragraph of item (h) on
   [[parked-defects]] ("deliberately NOT active in any deployed environment yet"), and the
   Architecture paragraph in `CLAUDE.md` ("BOTH prod and dev run `TEST_MODE`…").

To turn it back off, set `CROWD_SIZE` to `"0"` (and `TEST_MODE` back to `"true"` if the
deterministic demo is wanted) by the same round-trip.

## Raw layer

- `README_DEPLOY.md` §0a-0c (dev/local/Roblox-place deploy steps)
- `apprunner.yaml`, `docker-compose.yml`
- migration plan: [[backlog]] § App Runner → ECS Express migration
