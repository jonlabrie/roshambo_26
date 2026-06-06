--!strict
-- Client-local BindableEvents so controllers stay decoupled.
local bus: { [string]: BindableEvent } = {}
local NAMES = { "Cue", "TickerMessage" }
for _, name in NAMES do
    local e = Instance.new("BindableEvent")
    e.Name = name
    bus[name] = e
end
return bus
