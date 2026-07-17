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
    local ownsDeck = deckRank > 0
    -- item A: an owner whose auto-claim failed (pad scarcity) has claimedPadId == nil server-side.
    -- The server dead-drops both a claimless deck purchase (misclassified as buy-to-claim, no
    -- padId) and SetDisplay (gated on claim), so nothing here should look buyable/settable until
    -- claimed. Non-owners are unaffected -- their existing greyed "claim a free perch" preview
    -- already covers them.
    local needsClaim = ownsDeck and state.claimed == false
    local owns = {} -- teahouse size -> owned
    for _, s in state.teahouseSizes or {} do
        owns[s] = true
    end
    local teaMax = ownedMax(state.teahouseSizes or {})
    local teaMaxRank = rankOf(teaMax)

    -- deck ladder: owned up to maxDeckSize; the NEXT rung (rank == deckRank+1) is buyable
    -- (forced false when needsClaim -- nothing is buyable for a claimless owner).
    local deckLadder = {}
    for _, size in SIZES do
        local r = SizeClasses.rank[size]
        local isNext = not needsClaim and r == deckRank + 1
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
    -- Buyable rungs carry price and affordability; locked rungs do not. Forced unbuyable when
    -- needsClaim, same rationale as the deck ladder above.
    local teaLadder = {}
    for _, size in SIZES do
        local r = SizeClasses.rank[size]
        local locked = r > deckRank -- needs a >= deck
        local buyable = not needsClaim and r == teaMaxRank + 1 and not locked
        table.insert(teaLadder, {
            size = size,
            owned = owns[size] == true,
            isNext = buyable,
            price = if buyable then state.catalog.teahouse[size] else nil,
            affordable = if buyable then points >= state.catalog.teahouse[size] else nil,
            locked = locked,
        })
    end

    -- display options: deck S..maxDeckSize; teahouse none + S..teaMax (all disabled when
    -- needsClaim -- SetDisplay is gated server-side on claimedPadId, so nothing is settable).
    local deckOpts = {}
    for _, size in SIZES do
        table.insert(deckOpts, {
            value = size,
            enabled = not needsClaim and SizeClasses.rank[size] <= deckRank,
            selected = state.deckDisplay == size,
        })
    end
    local teaOpts =
        { { value = "none", enabled = not needsClaim, selected = state.teahouseDisplay == "none" } }
    for _, size in SIZES do
        table.insert(teaOpts, {
            value = size,
            enabled = not needsClaim and SizeClasses.rank[size] <= teaMaxRank,
            selected = state.teahouseDisplay == size,
        })
    end

    local favorites = {}
    for _, id in state.padPreferences or {} do
        table.insert(favorites, id)
    end

    -- item B: true when the displayed cap is strictly smaller than the biggest owned, so the
    -- world is quietly showing less than the player just bought. 'none' with any teahouse owned
    -- counts too (it hides the whole teahouse, the most extreme case of "shown smaller").
    local deckShownSmaller = state.deckDisplay ~= nil and rankOf(state.deckDisplay) < deckRank
    local teahouseShownSmaller = false
    if teaMax ~= nil then
        if state.teahouseDisplay == "none" then
            teahouseShownSmaller = true
        elseif state.teahouseDisplay ~= nil then
            teahouseShownSmaller = rankOf(state.teahouseDisplay) < teaMaxRank
        end
    end

    -- B4: the Move-teahouse mode needs a standing building on a claimed perch. Perch caps only
    -- shrink the built SIZE, never remove the building, so presence = owns one + not hidden.
    local canMove = state.claimed == true and teaMax ~= nil and state.teahouseDisplay ~= "none"

    return {
        points = points,
        ownsDeck = ownsDeck,
        ownsTeahouse = teaMax ~= nil,
        needsClaim = needsClaim,
        deckLadder = deckLadder,
        teahouseLadder = teaLadder,
        deckDisplayOptions = deckOpts,
        teahouseDisplayOptions = teaOpts,
        deckShownSmaller = deckShownSmaller,
        teahouseShownSmaller = teahouseShownSmaller,
        canMove = canMove,
        favorites = favorites,
    }
end

return TeahouseMenuModel
