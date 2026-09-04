--!strict
-- HOW EACH SHELL PRESENTS: display name and counter order. Split out of ShopController
-- on 2026-09-04, the day the kiku shipped server-side and silently missed the counter --
-- the shop only renders shells it can name, and nothing failed. The spec test holds this
-- table to shared-fixtures/firework-shells.json, so a promoted shell that skips its
-- display row is a CI failure instead of an empty space on the menu.
-- Pure data; runs under Lune.
local ShellDisplay = {}

ShellDisplay.ORDER = {
    "firecracker",
    "peony",
    "willow",
    "ishibana",
    "kiku",
    "wa",
    "yashi",
    "kamuro",
    "hotaru",
    "janken",
    "rai",
    "banrai",
}

ShellDisplay.NAME = {
    -- Renamed from "Firecracker" (owner, 2026-09-03: "what we currently call a 'Firecracker'
    -- is actually a 'Bottle Rocket'"). The ID stays `firecracker` on purpose: it keys every
    -- user document's inventory map, the fixtures, the recipes and the win-drop grant —
    -- renaming the id is a data migration; renaming the SHELL is this one line.
    firecracker = "Bottle Rocket",
    peony = "Peony",
    willow = "Willow",
    ishibana = "Ishibana",
    kiku = "Kiku",
    wa = "Wa",
    yashi = "Yashi",
    kamuro = "Kamuro",
    hotaru = "Hotaru",
    janken = "Janken",
    rai = "Rai",
    banrai = "Banrai",
} :: { [string]: string }

return ShellDisplay
