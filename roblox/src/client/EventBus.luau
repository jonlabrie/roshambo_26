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
    -- The picker asking the SERVER to launch. It carries a shellId and nothing else: whether that
    -- shell may fly is the server's answer, never this client's.
    "HudFireworkLaunch",
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
    -- The result splash (SplashController). Fired from main.client.luau's `maybeShowReveal`, on the
    -- SAME `drumRest` gate as the tape tile — never from RevealResult directly, which would spoil
    -- the wheel ~3s early. The drum is authoritative: nothing may reflect the world's throw
    -- anywhere else until it is fully at rest. Payload: { result, streak, pot, forfeited }.
    "Splash",
}
for _, name in NAMES do
    local e = Instance.new("BindableEvent")
    e.Name = name
    bus[name] = e
end
return bus
