--!strict
-- Seeded payloads shaped EXACTLY like the StatsData / StatsPersonal remotes carry, so a Studio
-- session can judge board layout before any real play exists (plan ruling R2). Names are
-- deliberately awkward — long, short, mixed-case, off-drum characters — because the point of a
-- fixture is to exercise the formatting, not to look tidy.
local StatsFixtures = {}

local function streak(name: string, length: number)
    return { displayName = name, length = length, endedBy = "LOSS" }
end

StatsFixtures.STATS = {
    leaders = {
        { displayName = "Ayaka", lifetimeBanked = 12480 },
        { displayName = "kenshin_the_unbanked", lifetimeBanked = 9310 },
        { displayName = "Mo", lifetimeBanked = 4005 },
        { displayName = "\u{7530}\u{4E2D}", lifetimeBanked = 812 },
        { displayName = "zero", lifetimeBanked = 0 },
    },
    recordsWeek = {
        window = "week",
        windowKind = "calendar",
        longestStreaks = { streak("Ayaka", 9), streak("Mo", 7), streak("kenshin_the_unbanked", 5) },
        biggestBanks = {
            { displayName = "Ayaka", amount = 6561, streakAtBank = 8 },
            { displayName = "Mo", amount = 2187, streakAtBank = 7 },
        },
        biggestRounds = { { displayName = "Ayaka", points = 4374 }, { displayName = "Mo", points = 1458 } },
    },
    recordsAll = {
        window = "all",
        windowKind = "rolling",
        longestStreaks = { streak("Mo", 12), streak("Ayaka", 11), streak("\u{7530}\u{4E2D}", 9) },
        biggestBanks = {},
        biggestRounds = {},
    },
    heat = {
        kind = "heat",
        qualified = false,
        window = "day",
        windowKind = "rolling",
        scope = "global",
        leaders = { { displayName = "Mo", earned = 810 }, { displayName = "Ayaka", earned = 486 } },
    },
    tape = {
        { worldThrow = "R" },
        { worldThrow = "S" },
        { worldThrow = "S" },
        { worldThrow = "P" },
        { worldThrow = "R" },
        { worldThrow = "P" },
        { worldThrow = "S" },
        { worldThrow = "R" },
        { worldThrow = "R" },
        { worldThrow = "P" },
    },
}

StatsFixtures.PERSONAL = {
    displayName = "Ayaka",
    career = { banked = 12480, bestStreak = 11 },
    currentStreak = 3,
    week = { throws = 142, minThrows = 350, qualified = false, roundsPresent = 210, participationRate = 0.68 },
}

return StatsFixtures
