--!strict
-- Pure view-model for the B3 teahouse HUD panel: turns an echoed economy state into the display
-- data the GUI renders (owned marks, next-tier price + affordability, teahouse-locked-by-deck,
-- enabled display options, favorites). No Roblox datatypes -> Lune-tested. Mirrors the B1/B2
-- pure-editor pattern; the GUI controller only renders what this returns.
local SizeClasses = require("./SizeClasses")

local TeahouseMenuModel = {}
local SIZES = { "S", "M", "L" } -- smallest-first for ladder rendering

local function rankOf(size: string?): number
    return if size ~= nil then SizeClasses.rank[size] else 0
end

local function ownedMax(list: { string }): string?
    local m: string? = nil
    for _, s in list do
        if m == nil or SizeClasses.rank[s] > SizeClasses.rank[m] then
            m = s
        end
    end
    return m
end

function TeahouseMenuModel.viewModel(state: any): any
    local points = state.totalPoints or 0
    local deckRank = rankOf(state.maxDeckSize)
    local owns = {} -- teahouse size -> owned
    for _, s in state.teahouseSizes or {} do
        owns[s] = true
    end
    local teaMax = ownedMax(state.teahouseSizes or {})

    -- deck ladder: owned up to maxDeckSize; the NEXT rung (rank == deckRank+1) is buyable
    local deckLadder = {}
    for _, size in SIZES do
        local r = SizeClasses.rank[size]
        local isNext = r == deckRank + 1
        table.insert(deckLadder, {
            size = size,
            owned = r <= deckRank,
            isNext = isNext,
            price = if isNext then state.catalog.deck[size] else nil,
            affordable = if isNext then points >= state.catalog.deck[size] else nil,
            locked = false,
        })
    end

    -- teahouse ladder: owned per the set; next = one rung above the highest owned rank
    -- (which is always contiguous). Locked if its rank exceeds the owned deck (teahouse <= deck).
    -- Buyable rungs carry price and affordability; locked rungs do not.
    local teaLadder = {}
    local teaMaxRank = rankOf(teaMax)
    for _, size in SIZES do
        local r = SizeClasses.rank[size]
        local isNext = r == teaMaxRank + 1
        local locked = r > deckRank -- needs a >= deck
        local buyable = isNext and not locked
        table.insert(teaLadder, {
            size = size,
            owned = owns[size] == true,
            isNext = buyable,
            price = if buyable then state.catalog.teahouse[size] else nil,
            affordable = if buyable then points >= state.catalog.teahouse[size] else nil,
            locked = locked,
        })
    end

    -- display options: deck S..maxDeckSize; teahouse none + S..teaMax
    local deckOpts = {}
    for _, size in SIZES do
        table.insert(deckOpts, {
            value = size,
            enabled = SizeClasses.rank[size] <= deckRank,
            selected = state.deckDisplay == size,
        })
    end
    local teaOpts = { { value = "none", enabled = true, selected = state.teahouseDisplay == "none" } }
    for _, size in SIZES do
        table.insert(teaOpts, {
            value = size,
            enabled = SizeClasses.rank[size] <= teaMaxRank,
            selected = state.teahouseDisplay == size,
        })
    end

    local favorites = {}
    for _, id in state.padPreferences or {} do
        table.insert(favorites, id)
    end

    return {
        points = points,
        ownsDeck = deckRank > 0,
        ownsTeahouse = teaMax ~= nil,
        deckLadder = deckLadder,
        teahouseLadder = teaLadder,
        deckDisplayOptions = deckOpts,
        teahouseDisplayOptions = teaOpts,
        favorites = favorites,
    }
end

return TeahouseMenuModel
