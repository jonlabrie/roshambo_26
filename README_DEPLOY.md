# Roshambo 26 AWS Deployment Guide

This guide covers the steps to move from your local Docker environment to a live AWS production environment.

## 1. MongoDB Atlas Setup
1. Create a free cluster at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas).
2. Go to **Network Access** and add your IP (for initial setup) and `0.0.0.0/0` (for App Runner connectivity).
3. Create a **Database User** with read/write access.
4. Copy your **Connection String**. It should look like: `mongodb+srv://<user>:<password>@cluster.abc.mongodb.net/roshambo?retryWrites=true&w=majority`

## 2. Backend: AWS App Runner
1. **Source**: Select "Container registry" or link your GitHub repo if you want App Runner to build the image (recommended).
2. **Build Configuration**:
   - If using GitHub: Select "Source code repo", choose the `server` directory, and use the existing `Dockerfile`.
3. **Service Configuration**:
   - **Port**: `3001`
   - **Environment Variables**:
     - `MONGODB_URI`: (Your Atlas connection string)
     - `JWT_SECRET`: (A long, random string)
     - `PORT`: `3001`
4. **Networking**: Ensure it is public so the frontend can connect.

## 3. Frontend: AWS Amplify
1. Connect your GitHub repository to [AWS Amplify](https://console.aws.amazon.com/amplify).
2. Amplify will detect the `amplify.yml` in your root.
3. **Environment Variables**:
   - Add `VITE_SOCKET_URL`: (The URL provided by App Runner, e.g., `https://abcdef.us-east-1.awsapprunner.com`)
4. **Deploy**: Trigger the build.

## 4. Environment Variables Checklist
| Variable | AWS Service | Purpose |
| :--- | :--- | :--- |
| `MONGODB_URI` | App Runner | Connection to database |
| `JWT_SECRET` | App Runner | Token signing |
| `VITE_SOCKET_URL` | Amplify | Points frontend to the backend |

---
**Verification**: Once both are live, open your Amplify URL. The "Network" tab in DevTools should show a successful WebSocket connection to your App Runner URL.
