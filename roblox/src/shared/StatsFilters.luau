--!strict
-- THE STATS ROOM'S NAME FILTERS. Extracted verbatim out of main.server.luau 2026-09-06
-- (server-file split, phase one, task 3) -- the four shape-walkers that ran over every stats
-- payload before it went on the wire. Nothing about the behaviour changed; the only edit was
-- taking the name filter itself by injection instead of closing over the entry file's
-- `cachedFilterName`.
--
-- PURE, so it is specced: the four functions only clone tables and rename a field. Everything
-- that yields or touches Roblox (TextService, the memo of its results, the polling) stays in
-- StatsFeed, which builds one of these with its cached filter.
local StatsFilters = {}

-- Filter only what is RENDERED: no board in the Stats room shows more than 10 rows, so rows
-- past the 10th are left as-is rather than spent on a filter call nothing will ever display.
local STATS_BOARD_ROWS = 10

export type Filters = {
    top: ({ any }?) -> { any },
    records: (any?) -> any?,
    board: (any?) -> any?,
    heat: (any?) -> any?,
}

function StatsFilters.new(filterName: (string) -> string): Filters
    local function filterTop(list: { any }?): { any }
        local out = {}
        for i, row in list or {} do
            if i <= STATS_BOARD_ROWS then
                local copy = table.clone(row)
                copy.displayName = filterName(row.displayName or "?")
                table.insert(out, copy)
            else
                table.insert(out, row)
            end
        end
        return out
    end

    local function filterRecords(records: any?): any?
        if not records then
            return records
        end
        local copy = table.clone(records)
        copy.longestStreaks = filterTop(records.longestStreaks)
        copy.biggestBanks = filterTop(records.biggestBanks)
        copy.biggestRounds = filterTop(records.biggestRounds)
        return copy
    end

    -- The board arrives already named and already gated by the server; the only thing left to
    -- strip is anything a client has no business holding. Its own filter rather than folded into
    -- filterRecords so a future field on either cannot silently ride along on the other.
    local function filterBoard(board: any?): any?
        if not board then
            return board
        end
        local copy = table.clone(board)
        copy.rows = filterTop(board.rows)
        return copy
    end

    local function filterHeat(heat: any?): any?
        if not heat then
            return heat
        end
        local copy = table.clone(heat)
        copy.leaders = filterTop(heat.leaders)
        return copy
    end

    return {
        top = filterTop,
        records = filterRecords,
        board = filterBoard,
        heat = filterHeat,
    }
end

return StatsFilters
