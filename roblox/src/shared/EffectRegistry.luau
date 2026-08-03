--!strict
-- Effect slot → variant pools (spec §2). Adding a variant is a data change.
return {
    REVEAL = { "waterHammer" },
    WIN = { "growPetals" },
    SAFE = { "umbrellaPop" },
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
