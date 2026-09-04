--!strict
-- AUTO-LOOK, v3 (owner's phone gates, 2026-09-03). History in two lessons:
--   v1 took the camera (Scriptable) — handing it back snapped, because the orbit camera's
--   stored orientation never moves while Scriptable.
--   v2 blended over the live camera — right idea, but writing the blend where the
--   PlayerModule could see it fed the up-look back into the orbit camera's own state
--   (it ADOPTS external CFrame writes) and it dove under the avatar. Hence the bracket:
--   a restore binding hands the camera module back its own clean frame at Camera-1, the
--   blend re-applies at Camera+1. Only the blend renders; only the base is adopted.
--
-- v3 adds the second-shell rules (owner: firing again mid-watch "snaps to watch the new
-- firework... I wasn't really finished watching the first one"):
--   * launch from idle -> goto the apex (0.7s ease — "perfect", unchanged);
--   * launch while WATCHING, new burst already in view -> don't move at all; just extend
--     the hold so the view doesn't drift away before the new shell breaks;
--   * launch while watching, new burst off-view -> PAN: the aim point itself travels from
--     where the view is pointing to the new apex, so the camera slides between bursts
--     instead of snapping (the snap was retargeting at full blend weight);
--   * untouched after the last hold -> slow drift home (4.5s);
--   * any camera input -> the blend fades under the player's own drag — they own the view,
--     and a further launch they can already see leaves them alone.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))

local SWEEP_SECONDS = 0.7 -- goto AND pan share the ease the owner called perfect
local HOLD_AFTER_BURST = 1.0 -- linger past a break so the bloom registers
local DRIFT_SECONDS = 4.5 -- the untouched return: a slow settle, not a countermove
local TAKEOVER_SECONDS = 1.2 -- blend fade once the player takes the wheel
local ON_SCREEN_MARGIN = 0.15 -- "in view" = inside the central 70% both axes

local mode: "idle" | "sweep" | "hold" | "drift" | "takeover" = "idle"
local w = 0 -- current blend weight
local wFrom = 0 -- sweep/takeover interpolate w from this...
local wHold = 1 -- ...hold pins it here (1 normally; a frozen drift holds lower)
local phaseAt = 0 -- when the current phase began
local aim = Vector3.zero -- where the blend is currently pointing the view
local aimFrom = Vector3.zero -- the pan's start point; sweep slides aimFrom -> aimTo
local aimTo = Vector3.zero
local holdUntil = 0 -- absolute clock: the watch ends here (extended per launch)

local function easeOut(a: number): number
    return 1 - (1 - a) ^ 2
end

local function easeInOut(a: number): number
    return if a < 0.5 then 2 * a * a else 1 - (2 * (1 - a)) ^ 2 / 2
end

local function inView(cam: Camera, point: Vector3): boolean
    local vp, onScreen = cam:WorldToViewportPoint(point)
    local size = cam.ViewportSize
    return onScreen
        and vp.X > size.X * ON_SCREEN_MARGIN
        and vp.X < size.X * (1 - ON_SCREEN_MARGIN)
        and vp.Y > size.Y * ON_SCREEN_MARGIN
        and vp.Y < size.Y * (1 - ON_SCREEN_MARGIN)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if mode == "idle" or mode == "takeover" or gameProcessed then
        return
    end
    local t = input.UserInputType
    local isCameraGesture = t == Enum.UserInputType.Touch
        or t == Enum.UserInputType.MouseButton2
        or t == Enum.UserInputType.MouseWheel
        or (t == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2)
    if isCameraGesture then
        mode = "takeover"
        wFrom = w
        phaseAt = os.clock()
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
    local newApex: Vector3 = data.apex
    local newBurst = if typeof(data.burstAt) == "number" then data.burstAt else 3
    local now = os.clock()

    if mode == "idle" then
        -- Already comfortably watching the right patch of sky? The assist would be motion
        -- for its own sake.
        if inView(cam, newApex) then
            return
        end
        aim = newApex
        aimFrom = newApex
        aimTo = newApex
        wFrom = 0
        mode = "sweep"
        phaseAt = now
        holdUntil = now + newBurst + HOLD_AFTER_BURST
        return
    end

    -- Active. The camera holds the blended frame between steps, so this measures what the
    -- player actually sees right now.
    if inView(cam, newApex) then
        if mode == "takeover" then
            return -- their view already covers it; leave them entirely alone
        end
        -- Don't move at all — just don't leave early either.
        holdUntil = math.max(holdUntil, now + newBurst + HOLD_AFTER_BURST)
        if mode == "drift" then
            -- freeze the drift where it stands until the new shell has had its moment
            mode = "hold"
            wHold = w
        end
        return
    end

    -- Off-view: PAN from where the view is pointing to the new apex — never a retarget at
    -- full weight, which is exactly the snap the owner flagged. The pan starts from the
    -- current view RAY (not the old aim), so it also composes correctly out of takeover
    -- and drift, where the blend has partially faded.
    local look = cam.CFrame
    aimFrom = look.Position + look.LookVector * (newApex - look.Position).Magnitude
    aimTo = newApex
    wFrom = w
    mode = "sweep"
    phaseAt = now
    holdUntil = math.max(holdUntil, now + newBurst + HOLD_AFTER_BURST)
end)

-- ⚠ THE BLEND MUST BE INVISIBLE TO THE DEFAULT CAMERA (see the header's v2 lesson). The
-- restore below hands the camera module back the exact frame it wrote last time, it
-- computes a clean base from the player's own input, and the blend re-applies after.
local savedBase: CFrame? = nil
local blendedFrame: CFrame? = nil

RunService:BindToRenderStep("LaunchLookRestore", Enum.RenderPriority.Camera.Value - 1, function()
    local cam = workspace.CurrentCamera
    -- restore only if the frame is still ours — a cutscene or respawn that moved the
    -- camera since must not be stomped with a stale base
    if cam and savedBase and blendedFrame and cam.CFrame == blendedFrame then
        cam.CFrame = savedBase
    end
    savedBase = nil
    blendedFrame = nil
end)

RunService:BindToRenderStep("LaunchLookBlend", Enum.RenderPriority.Camera.Value + 1, function()
    if mode == "idle" then
        return
    end
    local now = os.clock()
    if mode == "sweep" then
        local a = math.clamp((now - phaseAt) / SWEEP_SECONDS, 0, 1)
        w = wFrom + (1 - wFrom) * easeOut(a)
        aim = aimFrom:Lerp(aimTo, easeInOut(a))
        if a >= 1 then
            mode = "hold"
            wHold = 1
            aim = aimTo
        end
    elseif mode == "hold" then
        w = wHold
        if now >= holdUntil then
            mode = "drift"
            wFrom = w
            phaseAt = now
        end
    elseif mode == "drift" then
        local a = math.clamp((now - phaseAt) / DRIFT_SECONDS, 0, 1)
        w = wFrom * (1 - easeInOut(a))
        if a >= 1 then
            mode = "idle"
            w = 0
            return
        end
    elseif mode == "takeover" then
        local a = math.clamp((now - phaseAt) / TAKEOVER_SECONDS, 0, 1)
        w = wFrom * (1 - easeOut(a))
        if a >= 1 then
            mode = "idle"
            w = 0
            return
        end
    end
    local cam = workspace.CurrentCamera
    if cam == nil or Players.LocalPlayer.Character == nil then
        return
    end
    local base = cam.CFrame
    local desired = CFrame.lookAt(base.Position, aim)
    savedBase = base
    local blended = base:Lerp(desired, w)
    blendedFrame = blended
    cam.CFrame = blended
end)
