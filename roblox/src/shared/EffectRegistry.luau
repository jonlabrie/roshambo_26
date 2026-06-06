--!strict
-- Effect slot → variant pools (spec §2). Adding a variant is a data change.
return {
    REVEAL = { "waterHammer" },
    WIN = { "growPetals" },
    SAFE = { "umbrellaPop" },
    LOSS = { byThrow = { R = "fateBoulder", P = "fatePaper", S = "fateShears" } },
    BANK = { "coinToss" },
}
