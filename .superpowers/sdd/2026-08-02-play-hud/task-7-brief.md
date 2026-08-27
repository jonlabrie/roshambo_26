### Task 7: `LedgerModel` — derived statistics for maximal

Pure arithmetic over the counters. The one subtlety is percentage rounding: three independently
rounded percentages do not sum to 100, which leaves a visible gap in the distribution bar.

**Files:**
- Create: `roblox/src/shared/LedgerModel.luau`
- Test: `roblox/tests/LedgerModel.spec.luau`

**Interfaces:**
- Consumes: `GameRules.nextPot` is injected — the "pays next" figure must come from the same
  progression the server settles with, never a duplicated `×3`.
- Produces: `LedgerModel.view(counters: Counters, live: Live, rules: any): View` where
  `Counters = { roundsPlayed, wins, safes, losses, lifetimeBanked, bestPot, throwsR, throwsP, throwsS }` (all numbers),
  `Live = { pot: number, streak: number, points: number }`,
  and an **exported** `View = { paysNext: number, winRatePct: number, bar: { win: number, safe: number, loss: number }, mix: { R: number, P: number, S: number }, lifetime: Counters, live: Live }`
  so Task 12's renderer has something to annotate against.
- **`winRatePct` is defined as `bar.win`**, not computed separately. They describe the same
  quantity — the share of rounds won — so computing them two different ways lets them disagree.
  See Step 3.

- [ ] **Step 1: Write the failing test**

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local LedgerModel = require("../src/shared/LedgerModel")
local GameRules = require("../src/shared/GameRules")

local function counters(over: any): any
    local base = {
        roundsPlayed = 0, wins = 0, safes = 0, losses = 0,
        lifetimeBanked = 0, bestPot = 0, throwsR = 0, throwsP = 0, throwsS = 0,
    }
    for k, v in over or {} do
        base[k] = v
    end
    return base
end

describe("LedgerModel.view", function()
    test("pays-next comes from GameRules, not a hardcoded multiplier", function()
        -- if the pot progression ever changes, the ledger must change with it automatically
        local v = LedgerModel.view(counters({}), { pot = 27, streak = 3, points = 1240 }, GameRules)
        expect(v.paysNext).toBe(GameRules.nextPot(27, "WIN"))
    end)

    test("a zero pot still shows what a first win pays", function()
        local v = LedgerModel.view(counters({}), { pot = 0, streak = 0, points = 0 }, GameRules)
        expect(v.paysNext).toBe(GameRules.nextPot(0, "WIN"))
        expect(v.paysNext > 0).toBe(true)
    end)

    test("win rate is a whole percentage of rounds played", function()
        local v = LedgerModel.view(
            counters({ roundsPlayed = 386, wins = 131, safes = 92, losses = 163 }),
            { pot = 0, streak = 0, points = 0 }, GameRules
        )
        expect(v.winRatePct).toBe(34)
    end)

    test("win rate NEVER disagrees with the bar's win segment", function()
        -- They are the same quantity. Computed separately, a three-way tie makes the headline
        -- read 33% while the bar segment reads 34% — round-to-nearest says 33, largest-remainder
        -- hands the leftover unit to wins. A player looking at both sees a contradiction.
        local cases = {
            { roundsPlayed = 3, wins = 1, safes = 1, losses = 1 },
            { roundsPlayed = 300, wins = 100, safes = 100, losses = 100 },
            { roundsPlayed = 386, wins = 131, safes = 92, losses = 163 },
            { roundsPlayed = 7, wins = 2, safes = 2, losses = 3 },
            { roundsPlayed = 1, wins = 0, safes = 0, losses = 1 },
            { roundsPlayed = 9, wins = 3, safes = 3, losses = 3 },
        }
        for _, c in cases do
            local v = LedgerModel.view(counters(c), { pot = 0, streak = 0, points = 0 }, GameRules)
            expect(v.winRatePct).toBe(v.bar.win)
        end
    end)

    test("a player who has never thrown does not divide by zero", function()
        local v = LedgerModel.view(counters({}), { pot = 0, streak = 0, points = 0 }, GameRules)
        expect(v.winRatePct).toBe(0)
        expect(v.bar.win).toBe(0)
        expect(v.mix.R).toBe(0)
    end)

    test("the result bar always sums to exactly 100", function()
        -- three independently rounded percentages leave a gap in the bar; largest-remainder fixes it
        local cases = {
            { roundsPlayed = 3, wins = 1, safes = 1, losses = 1 },
            { roundsPlayed = 7, wins = 2, safes = 2, losses = 3 },
            { roundsPlayed = 386, wins = 131, safes = 92, losses = 163 },
            { roundsPlayed = 1, wins = 0, safes = 0, losses = 1 },
        }
        for _, c in cases do
            local v = LedgerModel.view(counters(c), { pot = 0, streak = 0, points = 0 }, GameRules)
            expect(v.bar.win + v.bar.safe + v.bar.loss).toBe(100)
        end
    end)

    test("the throw mix always sums to exactly 100", function()
        local v = LedgerModel.view(
            counters({ throwsR = 1, throwsP = 1, throwsS = 1 }),
            { pot = 0, streak = 0, points = 0 }, GameRules
        )
        expect(v.mix.R + v.mix.P + v.mix.S).toBe(100)
    end)

    test("the mix is proportional and preserves order", function()
        local v = LedgerModel.view(
            counters({ throwsR = 181, throwsP = 120, throwsS = 85 }),
            { pot = 0, streak = 0, points = 0 }, GameRules
        )
        expect(v.mix.R > v.mix.P).toBe(true)
        expect(v.mix.P > v.mix.S).toBe(true)
    end)

    test("live values pass through untouched", function()
        local v = LedgerModel.view(counters({}), { pot = 27, streak = 3, points = 1240 }, GameRules)
        expect(v.live.pot).toBe(27)
        expect(v.live.streak).toBe(3)
        expect(v.live.points).toBe(1240)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — `LedgerModel` does not exist.

- [ ] **Step 3: Write the module**

```luau
--!strict
-- Maximal-panel ("the ledger") view model. Pure arithmetic over the persisted counters.
--
-- GameRules is INJECTED rather than required, both because shared modules never require each
-- other and because the "a win here pays N" figure must track the real pot progression. A
-- hardcoded ×3 here would silently lie the day the progression changes.
local LedgerModel = {}

export type Counters = {
    roundsPlayed: number, wins: number, safes: number, losses: number,
    lifetimeBanked: number, bestPot: number,
    throwsR: number, throwsP: number, throwsS: number,
}
export type Live = { pot: number, streak: number, points: number }
export type View = {
    paysNext: number,
    winRatePct: number,
    bar: { win: number, safe: number, loss: number },
    mix: { R: number, P: number, S: number },
    lifetime: Counters,
    live: Live,
}

-- Largest-remainder apportionment. Rounding three shares independently leaves them summing to
-- 99 or 101, which shows as a gap or an overrun in a segmented bar. This distributes the
-- rounding error to the largest fractional parts so the total is exactly 100 -- except for an
-- all-zero input, which returns all zeros: there is nothing to apportion and nothing to render.
local function shares(parts: { number }): { number }
    local total = 0
    for _, p in parts do
        total += p
    end
    local out = {}
    if total <= 0 then
        for i = 1, #parts do
            out[i] = 0
        end
        return out
    end
    local floors, remainders, sum = {}, {}, 0
    for i, p in parts do
        local exact = p / total * 100
        floors[i] = math.floor(exact)
        remainders[i] = { i = i, r = exact - floors[i] }
        sum += floors[i]
    end
    table.sort(remainders, function(a, b)
        if a.r == b.r then
            return a.i < b.i -- stable: never let equal remainders reorder run to run
        end
        return a.r > b.r
    end)
    local leftover = 100 - sum
    for k = 1, leftover do
        floors[remainders[k].i] += 1
    end
    for i = 1, #parts do
        out[i] = floors[i]
    end
    return out
end

function LedgerModel.view(counters: Counters, live: Live, rules: any): View
    local bar = shares({ counters.wins, counters.safes, counters.losses })
    local mix = shares({ counters.throwsR, counters.throwsP, counters.throwsS })
    return {
        paysNext = rules.nextPot(live.pot, "WIN"),
        -- The headline win rate IS the bar's win segment, by definition rather than by a second
        -- calculation. Round-to-nearest and largest-remainder do not agree: at wins=safes=losses
        -- the former gives 33 and the latter 34, because the leftover unit is allocated by
        -- comparing remainders ACROSS categories, not by rounding a value on its own. Two numbers
        -- for one quantity that disagree on screen is simply a bug, so there is only one number.
        winRatePct = bar[1],
        bar = { win = bar[1], safe = bar[2], loss = bar[3] },
        mix = { R = mix[1], P = mix[2], S = mix[3] },
        lifetime = counters,
        live = live,
    }
end

return LedgerModel
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lune run tests/run` → PASS.

- [ ] **Step 5: Run the gates and commit**

```bash
stylua --check src tests tools && selene src tools
git add roblox/src/shared/LedgerModel.luau roblox/tests/LedgerModel.spec.luau
git commit -m "feat(roblox): LedgerModel — derived stats for the maximal panel"
```

---

