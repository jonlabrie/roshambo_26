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
}
for _, name in NAMES do
    local e = Instance.new("BindableEvent")
    e.Name = name
    bus[name] = e
end
return bus
