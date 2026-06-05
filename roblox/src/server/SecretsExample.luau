--!strict
-- Local-dev connection settings. For your own values, copy this file to
-- SecretsLocal.luau (gitignored) and edit. Production uses Roblox's secrets
-- store via HttpService:GetSecret (milestone 5), never files.
return {
    baseUrl = "http://localhost:3001",
    apiKey = "roshambo_local_dev_api_key",
}
