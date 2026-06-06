--!strict
-- Picks an effect variant for a slot. LOSS is deterministic (the doom IS the
-- world throw); other slots use the injected selection policy (random now;
-- pot-tier escalation is a future policy — spec §2).
local EffectSelector = {}
EffectSelector.__index = EffectSelector

function EffectSelector.new(registry: any, deps: { random: () -> number })
    return setmetatable({ _registry = registry, _random = deps.random }, EffectSelector)
end

function EffectSelector.select(self: any, slot: string, ctx: any): string?
    local entry = self._registry[slot]
    if entry == nil then
        return nil
    end
    if entry.byThrow then
        return entry.byThrow[ctx.worldThrow]
    end
    local n = #entry
    if n == 0 then
        return nil
    end
    return entry[1 + math.floor(self._random() * n) % n]
end

return EffectSelector
