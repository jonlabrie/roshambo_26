--!strict
-- AUTO-LOOK, v2 (owner's phone gates, 2026-09-03). v1 took the camera (Scriptable), swept,
-- held, and handed it back — and the hand-back was the whole problem: the default camera's
-- stored orientation never moves while Scriptable, so restoring Custom SNAPPED the view to
-- where it was before the sweep. That is both gates in one: "tilts back down sharply...
-- a bit aggressively" and "doesn't allow the player to take control of the view".
--
-- v2 never takes the camera. It renders a BLEND on top of the normal camera, one priority
-- step after the camera writes its frame: view = base:Lerp(lookAt(base.Position, apex), w).
-- The default camera keeps processing input underneath the whole time, so control is never
-- somewhere the player can't reach. The owner's spec, verbatim ruleset:
--   * launch -> goto apex ("the current goto apex behavior on launch is perfect"): w 0->1
--     over the same 0.7s ease;
--   * untouched -> "it should start drifting back to normal view slowly": after the burst
--     hold, w drifts 1->0 over DRIFT_SECONDS, gentle ease both ends;
--   * touched -> "I now have control": any camera input eases w out fast — the player's
--     drag is moving the base under the fading blend, so the view follows their finger
--     from WHERE IT IS (keep looking up by simply aiming up), never snapping;
--   * fire again -> "goto should assert again", even mid-drift: a new OwnLaunch re-sweeps
--     from the current blend, whatever phase it was in.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))

local SWEEP_SECONDS = 0.7 -- unchanged: the goto the owner called perfect
local HOLD_AFTER_BURST = 1.0 -- linger past the first break so the bloom registers
local DRIFT_SECONDS = 4.5 -- the untouched return: a slow settle, not a countermove
local TAKEOVER_SECONDS = 1.2 -- blend fade once the player takes the wheel
local ON_SCREEN_MARGIN = 0.15 -- apex already in the central 70% from idle: no sweep needed

local mode: "idle" | "sweep" | "hold" | "drift" | "takeover" = "idle"
local w = 0 -- current blend weight
local wFrom = 0 -- sweep/drift/takeover interpolate from this...
local phaseAt = 0 -- ...starting at this clock
local apex = Vector3.zero
local burstAt = 3
local sweptAt = 0 -- when the current launch's sweep began (the hold is timed from it)

local function easeOut(a: number): number
    return 1 - (1 - a) ^ 2
end

local function easeInOut(a: number): number
    return if a < 0.5 then 2 * a * a else 1 - (2 * (1 - a)) ^ 2 / 2
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
    if mode == "idle" then
        -- Already comfortably watching the right patch of sky? Then the assist would be
        -- motion for its own sake. Only an IDLE camera earns this skip: mid-drift or
        -- mid-takeover, a new launch always re-asserts (the owner's rule).
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
    end
    apex = data.apex
    burstAt = if typeof(data.burstAt) == "number" then data.burstAt else 3
    mode = "sweep"
    wFrom = w -- a re-assert mid-drift sweeps from the blend it still has, no jump
    phaseAt = os.clock()
    sweptAt = phaseAt
end)

-- One step AFTER the camera writes its frame: the default camera has already applied the
-- player's input to `cam.CFrame`; this composes the apex blend on top of that result.
RunService:BindToRenderStep("LaunchLookBlend", Enum.RenderPriority.Camera.Value + 1, function()
    if mode == "idle" then
        return
    end
    local now = os.clock()
    if mode == "sweep" then
        local a = math.clamp((now - phaseAt) / SWEEP_SECONDS, 0, 1)
        w = wFrom + (1 - wFrom) * easeOut(a)
        if a >= 1 then
            mode = "hold"
        end
    elseif mode == "hold" then
        w = 1
        if now - sweptAt >= burstAt + HOLD_AFTER_BURST then
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
    local desired = CFrame.lookAt(base.Position, apex)
    cam.CFrame = base:Lerp(desired, w)
end)
