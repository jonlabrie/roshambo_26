---
shelf: systems
updated: 2026-08-15
---

# Deploy

Where Roshambo code runs and how it gets there. Full topology + step-by-step AWS
setup: `README_DEPLOY.md`; day-to-day commands: CLAUDE.md "Commands"/"Deployment".

## As built

- **Cloud dev backend is the default.** App Runner service `roshambo_server_dev`
  (`https://zzaw22ugpq.us-east-1.awsapprunner.com`), source GitHub branch
  `m4b-zendojo-art-pass`, auto-deploy **ON** — every push to that branch redeploys
  the dev backend within a few minutes and changes what Studio/PWA dev talks to
  immediately (`roblox/src/server/SecretsLocal.luau`, gitignored, points at it).
  **Studio/PWA dev needs no local server** — `docker-compose up` / `server: npm run
  dev` are only for testing un-pushed server code before it reaches the dev service.
- Dev is configured via the App Runner **API**, not `apprunner.yaml`, so it can't
  inherit prod's `/roshambo/*` SSM secrets tree; its own secrets live at
  `/roshambo/dev/*`, reusing the same instance role's wildcard grant. See
  [[data]] for the database each side talks to.
- Prod is a separate App Runner service (via `apprunner.yaml`) + Amplify frontend.
  Prod auto-deploy is **OFF** — a push to GitHub does not redeploy prod; trigger it
  manually (console "Deploy" or `aws apprunner start-deployment`) after the branch
  reaches App Runner's source branch.
- App Runner → Amazon ECS Express Mode migration (both backends; App Runner is
  closed to new customers, no EOL deadline) is parked — see [[backlog]].

## Gates & decisions

- 2026-07-23 correction: never tell the user to start a local server for
  Studio/PWA testing — the cloud dev backend already covers it and auto-deploys on
  push.

## Raw layer

- `README_DEPLOY.md` §0a-0c (dev/local/Roblox-place deploy steps)
- `apprunner.yaml`, `docker-compose.yml`
- migration plan: [[backlog]] § App Runner → ECS Express migration
