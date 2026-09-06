--!strict
-- THE 37 REMOTE HANDLES AS ONE TABLE. Extracted 2026-09-06 (server-file split, phase one, 4.1):
-- each handle used to be a top-level local in main.server.luau, and that file sits at Luau's
-- 200-register ceiling. Binding is unchanged -- a bare WaitForChild per name, at boot, in this
-- order -- so a missing remote still fails loudly at start rather than silently later.
--
-- Runtime adapter: it yields on WaitForChild, so it has no Lune spec of its own; tests/Remotes.spec
-- asserts NAMES against default.project.json's RoshamboRemotes block instead. The three TIMED
-- fetches inside main.server.luau's Launch table (RequestShowGo, RequestProvingShow, the
-- FireworkShows module) are deliberately NOT here: their timeouts are documented in place.
local Remotes = {}

Remotes.NAMES = {
    "SubmitPick",
    "BankRequest",
    "SetHudPreference",
    "RequestLedger",
    "RoundUpdate",
    "RevealResult",
    "ProfileUpdate",
    "RevealTheater",
    "FateResolved",
    "BoardData",
    "FamiliarRoster",
    "SetPadPreference",
    "PreferenceState",
    "SetBackDoor",
    "BackDoorState",
    "SlideShoji",
    "ShojiState",
    "RequestPurchase",
    "EconomyState",
    "RequestSync",
    "SetDisplay",
    "SetPlacement",
    "SetDecorationPlacement",
    "SetMortarPlacement",
    "SetDecorationRemove",
    "DecorationPlaced",
    "SetAccess",
    "InviteUser",
    "RevokeUser",
    "AccessState",
    "AccessBlocked",
    "RequestFireworkLaunch",
    "FireworkLaunched",
    "FireworkState",
    "RequestProvingFire",
    "StatsData",
    "StatsPersonal",
}

function Remotes.bind(folder: Instance): { [string]: RemoteEvent }
    local out: { [string]: RemoteEvent } = {}
    for _, name in Remotes.NAMES do
        out[name] = folder:WaitForChild(name) :: RemoteEvent
    end
    return out
end

return Remotes
