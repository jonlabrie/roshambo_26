# Roshambo 26 AWS Deployment Guide

This guide covers the steps to move from your local Docker environment to a live AWS production environment.

## 1. MongoDB Atlas Setup
1. Create a free cluster at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas).
2. Go to **Network Access** and add your IP (for initial setup) and `0.0.0.0/0` (for App Runner connectivity).
3. Create a **Database User** with read/write access.
4. Copy your **Connection String**. It should look like: `mongodb+srv://<user>:<password>@cluster.abc.mongodb.net/roshambo?retryWrites=true&w=majority`

## 2. Backend: AWS App Runner
1. **Source**: Select **"Source code repository"** and link your GitHub repo.
2. **Directory Settings**: 
   > [!IMPORTANT]
   > You **MUST** set the **"Source directory"** to **`server`**.  
   > This is the only way for the build to find the correct `package.json`.
3. **Configuration**: Choose **"Use a configuration file"**.
   - AWS will now look for `server/apprunner.yaml`.
4. **Security (Instance Role)**:
   - This role gives your code permissions to talk to *other* AWS services (like S3 or Secrets Manager).
   - **Since we are using MongoDB Atlas, you don't need any special permissions.** 
   - You can leave this as the **Default** or **None** if it allows you. If forced, select "Create new" and give it a name like `RoshamboAppRunnerInstanceRole`.
5. **Service Configuration**:
   - In the "Configure service" step, add these **Environment Variables**:
     - `MONGODB_URI`: (Your Atlas connection string)
     - `JWT_SECRET`: (A long, random string)
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
