--!strict
-- The clerestory band's single line (spec section 6.3). Pure, so the drum rule below is pinned by
-- a test rather than by a reviewer's attention.
--
-- THE DRUM RULE LIVES HERE (owner, 2026-08-04): the world throw is named only when
-- `worldRested` is true. Every previous display that reflected the throw off the wire instead of
-- off `drumRest` — the result splash, the ring glyph, the points plate, BoardController's dead
-- row — spoiled it by about three seconds and had to be corrected. Making it a parameter of a
-- pure function is how this one cannot.
local StatsBoardModel = require("./StatsBoardModel")

local RoundBandModel = {}

-- One definition of the R/P/S glyph mapping, in StatsBoardModel. Re-exported here so this
-- module's public surface is unchanged and callers need not know where it lives.
RoundBandModel.GLYPH = StatsBoardModel.GLYPH
RoundBandModel.NO_THROW = "-"

export type State = {
    phase: string?,
    secondsLeft: number?,
    worldThrow: string?,
    worldRested: boolean?,
    ownThrow: string?,
}

local function padRight(s: string, n: number): string
    local w = 0
    for _ in utf8.codes(s) do
        w += 1
    end
    if w >= n then
        local out, i = {}, 0
        for _, code in utf8.codes(s) do
            i += 1
            if i > n then
                break
            end
            table.insert(out, utf8.char(code))
        end
        return table.concat(out)
    end
    return s .. string.rep(" ", n - w)
end

function RoundBandModel.line(state: State, cols: number): string
    local own = RoundBandModel.GLYPH[state.ownThrow or ""] or RoundBandModel.NO_THROW
    local right = `YOU {own}` -- 5 columns
    local leftW = math.max(1, cols - 1 - 5)

    local left: string
    local phase = state.phase
    if phase == "REVEAL" then
        -- The gate. `worldRested` is set from EventBus.Cue kind == "drumRest" and from nothing else.
        if state.worldRested and state.worldThrow then
            left = `WORLD {RoundBandModel.GLYPH[state.worldThrow] or "?"}`
        else
            left = "REVEAL"
        end
    elseif phase == "OPEN" or phase == "LOCK" then
        local secs = math.clamp(math.floor(state.secondsLeft or 0), 0, 99)
        left = `{phase} {secs}S`
    else
        -- No schedule replicated yet, or a phase this build does not know. Saying so beats
        -- printing a countdown the room would be right to trust.
        left = "WAITING"
    end

    return padRight(left, leftW) .. " " .. right
end

return RoundBandModel
