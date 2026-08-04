--!strict
-- Client-local BindableEvents so controllers stay decoupled.
local bus: { [string]: BindableEvent } = {}
local NAMES = {
    "Cue",
    "TickerMessage",
    "MoveTeahouse",
    "MoveDecoration",
    "DayNight",
    "HudState",
    "HudPick",
    "HudBank",
    "Toast",
    "OpenLedger",
    -- The ledger is the door to the teahouse panel. It had a persistent bottom-right toggle of its
    -- own, which crossed under the scissors button on a narrow viewport and cost a permanent hole in
    -- the camera-drag surface for a panel most players open rarely.
    "OpenTeahouse",
    "LedgerState",
    "HudPreference",
    "Onboard",
    "OnboardShown",
    -- Fired by the escalation overlay's own tap (the one sinking element on the minimal HUD).
    -- main.client.luau folds it into `declinedThisRound` — dismissing and backing out mean the
    -- same thing to the escalation rule, so this does not carry a payload of its own.
    "DismissEscalation",
    -- The result splash (SplashController). Fired from main.client.luau's `maybeShowSplash`, on the
    -- `drumSettling` cue — ~0.7s ahead of the drumRest gate the TAPE TILE still waits on, because by
    -- then the drum is committed to its detent and the face is readable. Never from RevealResult
    -- directly, which would spoil the wheel ~3s early. Payload: { result, streak, pot, forfeited }.
    "Splash",
}
for _, name in NAMES do
    local e = Instance.new("BindableEvent")
    e.Name = name
    bus[name] = e
end
return bus
