--!strict
-- Effect slot → variant pools (spec §2). Adding a variant is a data change.
return {
    REVEAL = { "waterHammer" },
    WIN = { "growPetals" },
    -- SAFE IS THE BIRD'S PERCH NOW. `umbrellaPop` drew one flat cylinder above the head with no
    -- ribs, shaft or canopy curve, and the owner read it as a cloud -- which is the correct
    -- reading of a featureless disc. The bangasa was a good idea that was never actually drawn;
    -- a bird settling on a shoulder says "nothing changed, you are fine" without any art at all.
    SAFE = {},
    -- PARKED 2026-08-03. LOSS used to select fateBoulder/fatePaper/fateShears, which
    -- FateController turned into a rock chasing the player. The owner withdrew the idea; the
    -- machinery stays because celebration effects will be built on it.
    --
    -- THIS EMPTY POOL IS THE WHOLE PARK for the client visuals: EffectSelector returns nil for
    -- an empty pool, so no `fate*` effect ever reaches FateController's cue guard and that file
    -- needs no edit at all. Re-enabling fates means putting the byThrow table back — a
    -- deliberate act that breaks the test in tests/EffectSelector.spec.luau rather than a silent one.
    LOSS = {},
    BANK = { "coinToss" },
}
