---
shelf: systems
updated: 2026-08-27
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
  ⚠ **`update-service` REPLACES `SourceConfiguration` wholesale, it does not merge.**
  A repoint that omits `RuntimeEnvironmentSecrets` silently drops all three secrets and
  the service comes back unable to reach Mongo. Always `describe-service` first and
  round-trip every field; the 2026-08-16 repoint did exactly that.
- **Both environments run `TEST_MODE=true`** — verified 2026-08-16 against the live
  service config for dev, and set in `apprunner.yaml` for prod. So the World Throw is
  the deterministic R→P→S cycle in BOTH, and the majority rule shipped in
  [[world-throw]] is not exercised anywhere. Nothing in either environment has ever run
  the random branch either.
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

## Raw layer

- `README_DEPLOY.md` §0a-0c (dev/local/Roblox-place deploy steps)
- `apprunner.yaml`, `docker-compose.yml`
- migration plan: [[backlog]] § App Runner → ECS Express migration
