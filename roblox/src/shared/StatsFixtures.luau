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
    board = {
        minThrows = 360,
        worldIsCrowd = true,
        rows = {
            { displayName = "AYAKA", pointsPerThrow = 4.12, winRate = 0.44, throws = 802 },
            { displayName = "KENJI", pointsPerThrow = 2.41, winRate = 0.41, throws = 512 },
            { displayName = "MOMO", pointsPerThrow = 1.98, winRate = 0.38, throws = 480 },
            { displayName = "HARU", pointsPerThrow = 1.20, winRate = 0.31, throws = 431 },
            { displayName = "SORA", pointsPerThrow = 0.64, winRate = 0.29, throws = 366 },
        },
    },
    -- A plausible shape, not a flat one: most players collect early and the tail is thin. A
    -- flat histogram would look fine in Studio and tell us nothing about whether the bars read.
    depths = { 41, 33, 22, 12, 9 },
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
    -- QUALIFIED, unlike the first fixture: an unqualified slip renders four dashes and shows
    -- nothing about the new rows' layout, which is the whole point of looking in Studio.
    week = {
        throws = 412,
        minThrows = 360,
        qualified = true,
        roundsPresent = 560,
        participationRate = 0.74,
        winRate = 0.41,
        pointsPerThrow = 2.41,
        nerve = 3,
        standing = { rank = 14, of = 22 },
    },
}

return StatsFixtures
