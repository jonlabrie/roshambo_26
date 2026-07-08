# Roshambo 26 AWS Deployment Guide

This guide covers the steps to move from your local Docker environment to a live AWS production environment.

## 0. Development environments (against Atlas — no local database)

Everything runs on **one Atlas cluster**: production uses the **`roshambo`** database, all dev/testing uses **`roshambo-dev`**. There is no local MongoDB. Atlas prerequisites: the `roshambo_app` user has `readWriteAnyDatabase` and Network Access allows `0.0.0.0/0`.

### 0a. Cloud dev backend — `roshambo_server_dev` (App Runner, the default)

A second App Runner service runs the dev backend so Studio/PWA dev needs no local server at all:
- **Service:** `roshambo_server_dev` → `https://zzaw22ugpq.us-east-1.awsapprunner.com`
- **Source:** GitHub `m4b-zendojo-art-pass`, **auto-deploy ON** (pushes redeploy dev automatically), configured via the **API** (not `apprunner.yaml`, so it can't inherit prod's `/roshambo/*` secrets).
- **Secrets:** `/roshambo/dev/*` SSM SecureStrings (`MONGODB_URI` → `roshambo-dev`, `API_KEY`, `JWT_SECRET`). The prod instance role `RoshamboAppRunnerInstanceRole` already grants these (its `/roshambo/*` wildcard covers `/roshambo/dev/*`).
- **Env:** `TEST_MODE=true`, `PORT=3001`. Size `0.25 vCPU / 0.5 GB` (pause the service when idle to cut cost).
- **Roblox:** set `roblox/src/server/SecretsLocal.luau` (gitignored) `baseUrl` to the dev URL above, `apiKey` = the dev `API_KEY`.

### 0b. Local backend (optional fallback)

To run the server on your own machine instead (e.g. to test un-pushed code before it reaches the dev service):
1. Put the `roshambo-dev` connection string in `server/.env` (gitignored) — `mongodb+srv://…/roshambo-dev?retryWrites=true&w=majority` — plus `API_KEY`, `JWT_SECRET`, `PORT=3001`, `TEST_MODE=true`.
2. `docker compose up --build` (server + frontend, no database) or `cd server && npm run dev`.
3. Point `SecretsLocal.luau` `baseUrl` at `http://localhost:3001`.

## 1. MongoDB Atlas Setup
1. Create a free cluster at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas).
2. Go to **Network Access** and add your IP (for initial setup) and `0.0.0.0/0` (for App Runner connectivity).
3. Create a **Database User** with read/write access.
4. Copy your **Connection String**. It should look like: `mongodb+srv://<user>:<password>@cluster.abc.mongodb.net/roshambo?retryWrites=true&w=majority`

## 2. Backend: AWS App Runner
1. **Source**: Select **"Source code repository"** and link your GitHub repo.
2. **Directory Settings**: 
   - **LEAVE IT EMPTY** (Default). This is crucial!
3. **Configuration**: Choose **"Use a configuration file"**.
   - AWS will automatically find the `apprunner.yaml` in your root.
4. **Security (Instance Role)**:
   - The service uses the instance role `RoshamboAppRunnerInstanceRole`, which grants `ssm:GetParameters` on `arn:aws:ssm:us-east-1:<account>:parameter/roshambo/*`.
   - This is required: all secrets are read from SSM at deploy time (see step 5).
5. **Secrets (SSM Parameter Store, us-east-1)**:
   - Secrets are NOT committed to the repo or set in the console. `apprunner.yaml` references them via `secrets:`/`value-from`:
     - `/roshambo/MONGODB_URI` (SecureString): Atlas connection string
     - `/roshambo/JWT_SECRET` (SecureString): token-signing secret
     - `/roshambo/API_KEY` (SecureString): server-to-server auth for `/api/v1`
   - To rotate one: `aws ssm put-parameter --region us-east-1 --name /roshambo/<NAME> --type SecureString --overwrite --value '<new>'`, then trigger a deployment.
6. **Networking**: Ensure it is public so the frontend can connect.
7. **Deploys**: Auto-deploy is OFF — pushing to GitHub does not deploy the backend. Trigger manually (console "Deploy" button or `aws apprunner start-deployment`).

## 3. Frontend: AWS Amplify
1. Connect your GitHub repository to [AWS Amplify](https://console.aws.amazon.com/amplify).
2. Amplify will detect the `amplify.yml` in your root.
3. **Environment Variables**:
   - Add `VITE_SOCKET_URL`: (The URL provided by App Runner, e.g., `https://abcdef.us-east-1.awsapprunner.com`)
4. **Deploy**: Trigger the build.

## 4. Environment Variables Checklist
| Variable | Source | Purpose |
| :--- | :--- | :--- |
| `MONGODB_URI` | SSM `/roshambo/MONGODB_URI` | Connection to database |
| `JWT_SECRET` | SSM `/roshambo/JWT_SECRET` | Token signing |
| `API_KEY` | SSM `/roshambo/API_KEY` | Server-to-server auth for /api/v1 (Roblox game servers) |
| `TEST_MODE` | `apprunner.yaml` (plain env) | Set 'true' for deterministic testing (R->P->S) |
| `PORT` | `apprunner.yaml` (plain env) | Server port (3001) |
| `VITE_SOCKET_URL` | Amplify | Points frontend to the backend |

---
**Verification**: Once both are live, open your Amplify URL. The "Network" tab in DevTools should show a successful WebSocket connection to your App Runner URL.
