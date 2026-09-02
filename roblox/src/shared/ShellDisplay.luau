--!strict
-- HOW EACH SHELL PRESENTS: display name and counter order. Split out of ShopController
-- on 2026-09-04, the day the kiku shipped server-side and silently missed the counter --
-- the shop only renders shells it can name, and nothing failed. The spec test holds this
-- table to shared-fixtures/firework-shells.json, so a promoted shell that skips its
-- display row is a CI failure instead of an empty space on the menu.
-- Pure data; runs under Lune.
local ShellDisplay = {}

ShellDisplay.ORDER = { "firecracker", "peony", "willow", "ishibana", "kiku" }

ShellDisplay.NAME = {
    firecracker = "Firecracker",
    peony = "Peony",
    willow = "Willow",
    ishibana = "Ishibana",
    kiku = "Kiku",
} :: { [string]: string }

return ShellDisplay
