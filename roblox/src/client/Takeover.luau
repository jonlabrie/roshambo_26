--!strict
-- Movement suspension for the takeover panels (the ledger and the teahouse).
--
-- WHY THIS IS A MODULE AND NOT A COPY IN EACH PANEL. What is below is hardened rather than
-- obvious: it prefers PlayerModule's control stack, falls back to WalkSpeed when that is
-- absent or refuses, and LATCHES which mechanism it used so a late-resolving PlayerModule
-- cannot restore a freeze the other path applied — which is what leaves someone at WalkSpeed 0
-- for good. A second copy would be a second place for that to go wrong, and with two panels
-- that hand off to each other it would also let one restore what the other suspended.
--
-- REFERENCE-COUNTED. The freeze applies on the first acquire and lifts on the last release, so
-- the two panels' call order relative to each other doesn't matter -- neither can thaw a player
-- who is still inside the other one, whatever sequence opens and closes them.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local DEFAULT_WALK_SPEED = 16

local Takeover = {}

local depth = 0

-- ===== Movement suspension =====
-- The canyon is cliff edges and switchbacks. Reading statistics while a thumb drifts on the stick is
-- how someone walks off the FW11 deck. The header says so in plain text — it is a promise, not an
-- apology, and it is the clearest signal that this is a mode.
--
-- PlayerModule is Roblox's default control stack, and this place declares no replacement (see
-- default.project.json: StarterPlayerScripts holds only RoshamboClient). It is still resolved
-- defensively, because a control stack that turns out not to be there must degrade to a working
-- freeze rather than to no freeze at all.
--
-- EVERY WaitForChild HERE IS TIMED. This block runs at require time, before the
-- `EventBus.OpenLedger` connection in LedgerController (not this file — extracting Takeover out of
-- LedgerController left that connection behind at LedgerController.client.luau:782) exists — so an
-- untimed wait that never resolved would not merely lose the freeze, it would leave the ledger's
-- doors (the round-timer ring, and the wallet plate whenever it is showing) dead buttons for the
-- rest of the session, with nothing on screen to say why.
local controls: any = nil
do
    local playerScripts = player:WaitForChild("PlayerScripts", 10)
    local playerModule = playerScripts and playerScripts:WaitForChild("PlayerModule", 5)
    if playerModule then
        local ok, result = pcall(function()
            return (require(playerModule :: any) :: any):GetControls()
        end)
        if ok then
            controls = result
        else
            warn(`[TAKEOVER] PlayerModule:GetControls() failed ({result}) — falling back to WalkSpeed`)
        end
    elseif playerScripts then
        warn("[TAKEOVER] PlayerModule not found — falling back to WalkSpeed")
    else
        warn("[TAKEOVER] PlayerScripts never arrived — falling back to WalkSpeed")
    end
end

-- LATCHED at suspend and read at restore. Without the latch, a mechanism that resolved late could
-- be used to restore a freeze that was applied by the other one — and that leaves a player at
-- WalkSpeed 0 for good.
local suspendedVia: string? = nil
local savedWalk: number? = nil

local function currentHumanoid(): Humanoid?
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- pcall'd, and the result is REPORTED rather than swallowed. `close()` has already hidden the panel
-- by the time restore runs, so an error thrown out of here would leave a frozen player with the
-- panel gone — no ✕ to press and no way to try again. It also means the latch below is only ever set
-- to "controls" when Disable actually took.
local function setControlsEnabled(on: boolean): boolean
    if not controls then
        return false
    end
    local ok, err = pcall(function()
        if on then
            controls:Enable()
        else
            controls:Disable()
        end
    end)
    if not ok then
        warn(`[TAKEOVER] PlayerModule controls {if on then "Enable" else "Disable"} failed: {err}`)
    end
    return ok
end

-- WalkSpeed is the FALLBACK path only. Jumping is deliberately left alone: a player who cannot walk
-- cannot travel, and hopping in place has never walked anyone off a deck. Fewer properties touched
-- is fewer ways to hand back a broken character.
local function suspend()
    if suspendedVia ~= "walkspeed" and setControlsEnabled(false) then
        suspendedVia = "controls"
        return
    end
    suspendedVia = "walkspeed"
    local h = currentHumanoid()
    if h then
        if savedWalk == nil then
            savedWalk = h.WalkSpeed
        end
        h.WalkSpeed = 0
    end
end

local function restore()
    local via = suspendedVia
    suspendedVia = nil
    if via == "controls" then
        if not setControlsEnabled(true) then
            -- Nothing else here can un-disable a control stack. Reopening and closing a takeover
            -- panel retries this, which is why `close()`/`setOpen()` are idempotent rather than
            -- one-shot. Named generically -- the ledger and the teahouse are both holders now, and
            -- this warning would otherwise send a teahouse-stranded player to the wrong panel.
            warn("[TAKEOVER] control stack refused Enable — reopen a takeover panel and close it to retry")
        end
    elseif via == "walkspeed" then
        local h = currentHumanoid()
        if h then
            -- NEVER restore a zero. If something else had already frozen this character when we
            -- captured, handing that value back would strand the player on our exit — the exact
            -- failure this whole mechanism exists to prevent.
            h.WalkSpeed = if savedWalk and savedWalk > 0 then savedWalk else DEFAULT_WALK_SPEED
        end
        savedWalk = nil
    end
end

-- A respawn while a takeover is active hands us a brand-new Humanoid carrying its authored
-- WalkSpeed — un-frozen, on the fallback path. Re-apply, re-capturing from the fresh humanoid.
--
-- Gated on `depth > 0` rather than a single panel's own open flag, because this module now serves
-- more than one panel: whichever one is currently holding the takeover open, a respawn during it
-- must not hand the player their legs back early.
--
-- `depth` is tested TWICE, and the second test is the one that matters: WaitForChild yields for up
-- to 10 seconds, and the last release can land inside that window. Checking only before the yield
-- lets this resume after the takeover has already restored control and freeze the player again with
-- no panel on screen — the exact failure the suspension exists to prevent, and one the player has no
-- way to diagnose.
player.CharacterAdded:Connect(function(char)
    if depth == 0 then
        return
    end
    char:WaitForChild("Humanoid", 10)
    if depth == 0 then
        return
    end
    savedWalk = nil
    suspend()
end)

function Takeover.acquire()
    depth += 1
    if depth == 1 then
        suspend()
    end
end

function Takeover.release()
    if depth == 0 then
        return
    end
    depth -= 1
    if depth == 0 then
        restore()
    end
end

return Takeover
