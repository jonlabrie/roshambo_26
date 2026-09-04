--!strict
-- AUTO-LOOK (owner, 2026-09-03, from the cold walk): "new players, especially, will miss the
-- detonation of their firework because they don't know to look up." When the LOCAL player's
-- own shell launches (EventBus.OwnLaunch, fired by FireworkController with the true seeded
-- apex), this sweeps the camera up to the burst point, holds through the break, and sweeps
-- back. No first-person needed: the camera's POSITION never moves — a pure rotation from
-- where it stands, so there is no swoop to feel sick about.
--
-- THE PLAYER ALWAYS WINS. Any raw camera/world input (touch pan, right-mouse) or movement
-- releases the camera instantly, mid-sweep or mid-hold — a guest already looking up, or one
-- who fights the sweep, never loses control for more than a frame. UI taps (gameProcessed)
-- do NOT cancel: tapping the fireworks rail is not a camera gesture.
--
-- Other players' launches never grab the camera (OwnLaunch only carries the local player's).
-- Default on; the per-player toggle belongs to the future config screen (backlog:
-- "Onboarding: replayable journey" — same surface).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))

local SWEEP_SECONDS = 0.7 -- rotation out to the apex
local RETURN_SECONDS = 0.5 -- rotation back after the hold (a snap reads as a glitch)
local HOLD_AFTER_BURST = 1.0 -- linger past the first break so the bloom registers
local ON_SCREEN_MARGIN = 0.15 -- apex already inside the central 70% of the view: do nothing

local active = false
local conn: RBXScriptConnection? = nil
local restoreType: Enum.CameraType? = nil

-- Hands the camera back wherever it is. On a player takeover that means no return sweep —
-- their next input drives the camera anyway; on natural expiry the return sweep has already
-- landed the camera back on startCF, so restoring Custom is seamless either way.
local function release()
    if not active then
        return
    end
    active = false
    if conn then
        conn:Disconnect()
        conn = nil
    end
    local cam = workspace.CurrentCamera
    if cam and restoreType then
        cam.CameraType = restoreType
    end
    restoreType = nil
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if not active or gameProcessed then
        return
    end
    local t = input.UserInputType
    if
        t == Enum.UserInputType.Touch
        or t == Enum.UserInputType.MouseButton2
        or t == Enum.UserInputType.MouseWheel
    then
        release()
    end
end)

EventBus.OwnLaunch.Event:Connect(function(data: any)
    if typeof(data) ~= "table" or typeof(data.apex) ~= "Vector3" then
        return
    end
    local cam = workspace.CurrentCamera
    if cam == nil then
        return
    end
    -- Already comfortably in view? Then the guest is watching and the assist would only be
    -- motion for its own sake.
    local vp, onScreen = cam:WorldToViewportPoint(data.apex)
    local size = cam.ViewportSize
    if
        onScreen
        and vp.X > size.X * ON_SCREEN_MARGIN
        and vp.X < size.X * (1 - ON_SCREEN_MARGIN)
        and vp.Y > size.Y * ON_SCREEN_MARGIN
        and vp.Y < size.Y * (1 - ON_SCREEN_MARGIN)
    then
        return
    end

    release() -- a second launch retargets cleanly
    local startCF = cam.CFrame
    local goal = CFrame.lookAt(startCF.Position, data.apex)
    restoreType = cam.CameraType
    cam.CameraType = Enum.CameraType.Scriptable
    active = true

    local burstAt = if typeof(data.burstAt) == "number" then data.burstAt else 3
    local holdUntil = math.max(burstAt + HOLD_AFTER_BURST, SWEEP_SECONDS)
    local t0 = os.clock()
    conn = RunService.RenderStepped:Connect(function()
        local cam2 = workspace.CurrentCamera
        if cam2 == nil then
            release()
            return
        end
        local plr = Players.LocalPlayer
        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0.05 then
            release() -- walking away: the player wins, immediately
            return
        end
        local dt = os.clock() - t0
        if dt >= holdUntil + RETURN_SECONDS then
            -- the return sweep below has already landed on startCF; restoring Custom here is
            -- seamless because the camera is exactly where the orbit rig left it.
            release()
            return
        end
        local target: CFrame
        if dt < SWEEP_SECONDS then
            local a = dt / SWEEP_SECONDS
            target = startCF:Lerp(goal, 1 - (1 - a) ^ 2) -- ease-out up
        elseif dt < holdUntil then
            target = goal
        else
            local a = (dt - holdUntil) / RETURN_SECONDS
            target = goal:Lerp(startCF, a * a) -- ease-in back down
        end
        cam2.CFrame = target
    end)
end)
