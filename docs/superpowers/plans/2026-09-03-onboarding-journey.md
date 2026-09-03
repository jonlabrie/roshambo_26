# The Onboarding Journey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A cold-joining friends & family guest is carried, alone, from first join through the round loop, a firecracker purchase and launch, to the model teahouse and a 20-point starter bundle — 8 event-fired beats, a beam waypoint, a model pad, and a `starter` SKU.

**Architecture:** The existing beat machinery (`OnboardingBeats` + `OnboardingController`, event-fired cards, never queued, `seenBeats` persisted via `OnboardShown` acks) grows to 8 beats with a 3-page welcome. A new pure `TourGuide` derives the tour step from `seenBeats`; a new `TourBeamController` renders one client-side beam over the tagged next stop. The server gains a `starter` SKU (S deck + S teahouse, 20 pts, first property only) and a boot-time model-pad claim by a sentinel owner.

**Tech Stack:** Luau (Lune-tested pure modules, Roblox client/server entries), TypeScript (Express + Mongo, Vitest), Rojo.

**Spec:** `docs/superpowers/specs/2026-09-03-onboarding-journey-design.md`

## Global Constraints

- **No gambling vocabulary in any player-facing string**: never "pot", "ride", "stake", "wager", "bet" (owner ruling 2026-08-02/05, extended to onboarding 2026-09-05). "Pile" is the sanctioned pot replacement.
- **Beats never queue**: a second event while a card is up is dropped (or, new here, tour-advanced) — never stacked.
- **The landscape HUD is untouched** (owner: "players need to be able to reach it with their right thumbs to throw"). Nothing in this plan repositions HUD elements.
- **`src/shared` holds no Roblox globals** — pure modules only, Lune-testable; services arrive by injection or stay in `*.client.luau` / `*.server.luau`.
- **Client never hardcodes a price** — prices ride the echoed catalog.
- Roblox gates (run from `roblox/`): `stylua src tests tools && selene src tools && lune run tests/run` and `rojo build -o /tmp/build-check.rbxl`. Server gates (from `server/`): `npm test`. `tests/Compiles.spec.luau` automatically covers every new/edited `src/**/*.luau` — new client files need no manual registration.
- Commit messages end with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01Vw3EoAN2H4ZcRXNtu2mFco`

---

### Task 1: `starter` SKU — pure economy rules

**Files:**
- Modify: `server/src/economy.ts` (PRICES at :5-10, `validatePurchase` at :42, `applyPurchase` at :101)
- Test: `server/src/economy.test.ts`

**Interfaces:**
- Consumes: existing `EconomyState`, `validatePurchase(state, item)`, `applyPurchase(state, item)`.
- Produces: `PRICES.starter === 20`; `validatePurchase(state, 'starter')` → `{ ok: true, cost: 20 }` only when `state.maxDeckSize === null`; `applyPurchase(state, 'starter')` → `maxDeckSize: 'S'`, `teahouseSizes: ['S']`, points −20. Tasks 2–4 rely on the item string `'starter'` exactly.

- [ ] **Step 1: Write the failing tests**

Append to `server/src/economy.test.ts`:

```typescript
describe('validatePurchase — the starter bundle', () => {
    it('starter needs no property and costs 20', () => {
        expect(validatePurchase(fresh(), 'starter')).toEqual({ ok: true, cost: PRICES.starter });
        expect(PRICES.starter).toBe(20);
    });
    it('rejects starter for anyone who already owns a deck', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'starter')).toEqual({ ok: false, error: 'ALREADY_OWNED' });
        expect(validatePurchase(fresh({ maxDeckSize: 'L' }), 'starter')).toEqual({ ok: false, error: 'ALREADY_OWNED' });
    });
    it('rejects starter when unaffordable', () => {
        expect(validatePurchase(fresh({ totalPoints: 19 }), 'starter')).toEqual({ ok: false, error: 'INSUFFICIENT_POINTS' });
    });
    it('applyPurchase grants deck S + teahouse S atomically and deducts 20', () => {
        const next = applyPurchase(fresh({ totalPoints: 25 }), 'starter');
        expect(next.maxDeckSize).toBe('S');
        expect(next.teahouseSizes).toEqual(['S']);
        expect(next.totalPoints).toBe(5);
    });
    it('the ladder is untouched: an owner still upgrades at full price', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'deck:M')).toEqual({ ok: true, cost: PRICES.deck.M });
    });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: FAIL — `PRICES.starter` is undefined / `'starter'` returns `BAD_ITEM`.

- [ ] **Step 3: Implement**

In `server/src/economy.ts`, add `starter` to `PRICES` (the spread at `apiV1.ts:337` then carries it to the client catalog for free):

```typescript
export const PRICES = {
    deck: { S: 50, M: 500, L: 3000 },
    teahouse: { S: 30, M: 300, L: 2000 },
    // The beginner's bundle (owner, 2026-09-03): S deck + S teahouse together for "an hour's
    // play" (~1 banked pt / 3 min), first property only. 80 pts of ladder for 20 — the ladder
    // itself is untouched; upgrades from S price normally.
    starter: 20,
    portal: 500,
    decoration: { ishidoro: 40, tsukubai: 60, bonsai: 25, bench: 35 },
} as const;
```

In `validatePurchase`, add a branch BEFORE the `firework:`/`mortar:` prefix checks (order is safe — `'starter'` has no colon, but keep it with the other exact-match item, next to `portal`):

```typescript
    if (item === 'starter') {
        // First property only: owning any deck means the bundle's moment has passed.
        if (state.maxDeckSize !== null) return { ok: false, error: 'ALREADY_OWNED' };
        if (state.totalPoints < PRICES.starter) return { ok: false, error: 'INSUFFICIENT_POINTS' };
        return { ok: true, cost: PRICES.starter };
    }
```

In `applyPurchase`, add after the `mortar:` branch, before the final `[kind, size]` split:

```typescript
    if (item === 'starter') {
        next.maxDeckSize = 'S';
        next.teahouseSizes.push('S');
        return next;
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: PASS (all, including the pre-existing suites).

- [ ] **Step 5: Full server suite + commit**

Run: `cd server && npm test`
Expected: PASS.

```bash
git add server/src/economy.ts server/src/economy.test.ts
git commit -m "feat(economy): the starter bundle -- S deck + S teahouse for 20 pts, first property only"
```

---

### Task 2: `starter` purchase route — atomic grant

**Files:**
- Modify: `server/src/routes/apiV1.ts` (the purchase route at :394-457; catalog line :337 needs NO change — `{ ...PRICES }` already carries `starter`)
- Test: `server/src/routes/apiV1.test.ts`

**Interfaces:**
- Consumes: Task 1's `validatePurchase(state, 'starter')`; existing route scaffolding (`resolveUser`, `readEconomy`, `User.findOneAndUpdate` filter/update pattern, `DEFAULT_TEAHOUSE_LOADOUT`).
- Produces: `POST /players/:id/purchase {item:'starter'}` → 200 `{ item, totalPoints, maxDeckSize:'S', teahouseSizes:['S'], portalOwned }`; 400 `ALREADY_OWNED`/`INSUFFICIENT_POINTS`; 409 on race. `GET .../economy` `catalog.starter === 20`. Task 3 relies on this response shape (same as deck/teahouse purchases).

- [ ] **Step 1: Write the failing tests**

Append inside the existing purchase-route `describe` in `server/src/routes/apiV1.test.ts` (same `makeApp`/`makeEngine`/`API_KEY` helpers the neighboring tests use):

```typescript
        it('POST purchase starter grants deck S + teahouse S and deducts 20', async () => {
            await User.create({ robloxId: '900060', totalPoints: 25 });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .post('/api/v1/players/900060/purchase').set('X-API-Key', API_KEY).send({ item: 'starter' }).expect(200);
            expect(res.body.maxDeckSize).toBe('S');
            expect(res.body.teahouseSizes).toEqual(['S']);
            expect(res.body.totalPoints).toBe(5);
        });

        it('POST purchase starter rejects an existing owner with ALREADY_OWNED', async () => {
            await User.create({ robloxId: '900061', totalPoints: 1000, maxDeckSize: 'S' });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/900061/purchase').set('X-API-Key', API_KEY).send({ item: 'starter' }).expect(400);
            expect(res.body.error).toBe('ALREADY_OWNED');
        });

        it('two concurrent starter purchases resolve to exactly one sale', async () => {
            await User.create({ robloxId: '900062', totalPoints: 40 });
            const app = makeApp(makeEngine(), new ResultsStore());
            const fire = () => request(app)
                .post('/api/v1/players/900062/purchase').set('X-API-Key', API_KEY).send({ item: 'starter' });
            const [a, b] = await Promise.all([fire(), fire()]);
            const statuses = [a.status, b.status].sort();
            expect(statuses[0]).toBe(200);
            expect(statuses[1]).toBeGreaterThanOrEqual(400);
            const after = await User.findOne({ robloxId: '900062' });
            expect(after!.totalPoints).toBe(20); // one deduction, never two
            expect(after!.maxDeckSize).toBe('S');
        });

        it('GET economy catalog carries the starter price', async () => {
            await User.create({ robloxId: '900063', totalPoints: 0 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/900063/economy').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.catalog.starter).toBe(20);
        });
```

- [ ] **Step 2: Run to verify failure**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: the four new tests FAIL (starter → `BAD_ITEM` 400 from the route's final else; catalog one may already PASS thanks to the PRICES spread — that is fine, it is a pin).

- [ ] **Step 3: Implement the route branch**

In `server/src/routes/apiV1.ts`, in the purchase route, add a branch after the `item === 'portal'` branch and before the final `else` (the `[kind, size]` split):

```typescript
            } else if (item === 'starter') {
                // First-property-only, atomically: {maxDeckSize: null} matches absent too, so a
                // racing second starter (or a racing deck:S) matches no document and 409s.
                filter.maxDeckSize = null;
                update.$set = { maxDeckSize: 'S', 'teahouses.S': { ...DEFAULT_TEAHOUSE_LOADOUT } };
                respond = (u) => {
                    const e = readEconomy(u);
                    res.json({ item, totalPoints: e.totalPoints, maxDeckSize: e.maxDeckSize, teahouseSizes: e.teahouseSizes, portalOwned: e.portalOwned ?? false });
                };
            } else {
```

- [ ] **Step 4: Run to verify pass**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: PASS.

- [ ] **Step 5: Full suite + commit**

Run: `cd server && npm test`
Expected: PASS.

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(api): starter bundle purchase -- atomic first-property grant, catalog rides the PRICES spread"
```

---

### Task 3: Roblox server accepts `starter` as buy-to-claim

**Files:**
- Modify: `roblox/src/server/main.server.luau` (the `RequestPurchase.OnServerEvent` handler at :2510-2640)

**Interfaces:**
- Consumes: Task 2's response shape; existing `isBuyToClaim` / `claimPadId` / `siteCoordinator:onJoin` flow in the same handler.
- Produces: a `RequestPurchase:FireServer({ item = "starter", padId = siteId })` from a propertyless player claims that pad and materializes the S deck + S teahouse. Task 4 fires exactly that payload.

There is no Lune harness for `main.server.luau` (Roblox-runtime entry); the gates are selene/stylua/Compiles.spec plus Task 12's live walk.

- [ ] **Step 1: Extend the buy-to-claim guard**

At the line `local isBuyToClaim = e.claimedPadId == nil and kindPre == "deck"` change to:

```lua
        -- "starter" is deck:S + teahouse:S in one purchase (owner, 2026-09-03) — it claims a pad
        -- exactly the way a bare deck:S does.
        local isBuyToClaim = e.claimedPadId == nil and (kindPre == "deck" or item == "starter")
```

- [ ] **Step 2: Adopt the teahouse half of the grant**

In the same handler, the adopt block reads `local kind, size = string.match(item, "^(%a+):(%a+)$")` and only populates `e.teahouses` for `kind == "teahouse"`. Immediately after that `if kind == "teahouse" and size then ... end` block, add:

```lua
        if item == "starter" then
            -- the /purchase response carries teahouseSizes = {"S"} but the adopt above keys off
            -- the item string; without this the claim below builds a bare deck and the guest's
            -- bundle looks like half of what they paid for until next join.
            e.teahouses.S = { baseStyle = "teahouse-1story" }
        end
```

- [ ] **Step 3: Gates**

Run from `roblox/`: `stylua src tests tools && selene src tools && lune run tests/run`
Expected: clean format/lint, all tests pass (Compiles.spec re-compiles the edited entry).

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(server): starter bundle claims a pad like deck:S and adopts its teahouse grant"
```

---

### Task 4: The vacant-site prompt sells the bundle

**Files:**
- Modify: `roblox/src/client/EconomyController.client.luau` (`priceOf` at :25, `offerFor` at :35-46, the ticker message at :100-102)

**Interfaces:**
- Consumes: `catalog.starter` from the economy echo (Task 2); Task 3's `{ item = "starter", padId }` server handling.
- Produces: non-owners see `Starter teahouse — 20 pts` (or the shortfall) on vacant sites.

- [ ] **Step 1: Teach `priceOf` the colon-less item**

```lua
local function priceOf(item: string): any
    if item == "starter" and state.catalog then
        return state.catalog.starter
    end
    local kind, size = string.match(item, "^(%a+):(%a+)$")
    if state.catalog and kind and size and state.catalog[kind] then
        return state.catalog[kind][size]
    end
    return "?"
end
```

- [ ] **Step 2: Swap the offer**

Replace the body of the non-owner branch in `offerFor`:

```lua
local function offerFor(_siteId: string, occupied: boolean): (string?, string?)
    if state.maxDeckSize == nil and not occupied then
        -- non-owner on a vacant site: the starter bundle (deck S + teahouse S in one purchase,
        -- owner 2026-09-03 — "an hour's play"). Show the shortfall when unaffordable, so a new
        -- player (starts at 0 pts) sees the goal instead of a silent dead-end.
        local price = priceOf("starter")
        if typeof(price) == "number" and state.totalPoints < price then
            return "starter", `Starter teahouse — earn {price - state.totalPoints} more pts`
        end
        return "starter", `Starter teahouse — {price} pts`
    end
    return nil, nil
end
```

- [ ] **Step 3: Kid-voice the unaffordable ticker**

The existing ticker line says "bank your pot" — gambling vocabulary the copy ruling bans. Replace it:

```lua
                EventBus.TickerMessage:Fire(
                    `Earn {price - state.totalPoints} more pts for your own teahouse — win a round and bank your points`
                )
```

- [ ] **Step 4: Gates + commit**

Run from `roblox/`: `stylua src tests tools && selene src tools && lune run tests/run`
Expected: PASS.

```bash
git add roblox/src/client/EconomyController.client.luau
git commit -m "feat(client): vacant-site prompt sells the starter bundle, shortfall counts to 20"
```

---

### Task 5: OnboardingBeats — 8 beats, welcome pages, tour advance

**Files:**
- Modify: `roblox/src/shared/OnboardingBeats.luau`
- Test: `roblox/tests/OnboardingBeats.spec.luau`

**Interfaces:**
- Consumes: nothing new.
- Produces (Tasks 7–9 rely on these exact strings): `Beat = { id, event, copy, anchor, pages: { string }?, advanceOn: string? }`. Ids in order: `welcome, throw, win, bank, shopDoor, launchDoor, modelDoor, modelHome`. Events: `join, throwsUnlocked, win, bank, bankDismissed, shellBought, shellLaunched, modelArrival`. Anchors: existing four plus `tour`. `next(seen, event)` unchanged in contract.

Copy below is the spec's draft — the owner workshops wording before publish (Task 12), but every string already obeys the vocabulary rule so a workshop slip cannot un-gate the tests.

- [ ] **Step 1: Rewrite the spec file**

Replace `roblox/tests/OnboardingBeats.spec.luau` wholesale:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Beats = require("../src/shared/OnboardingBeats")

describe("OnboardingBeats — the journey's chain", function()
    test("eight beats, in journey order, with distinct ids", function()
        expect(#Beats.BEATS).toBe(8)
        local order = { "welcome", "throw", "win", "bank", "shopDoor", "launchDoor", "modelDoor", "modelHome" }
        for i, b in Beats.BEATS do
            expect(b.id).toBe(order[i])
            expect(#b.copy > 0).toBe(true)
            expect(#b.anchor > 0).toBe(true)
        end
    end)

    test("each tour beat fires on the event the previous one advances on", function()
        -- the chain: bank card dismissed -> shop -> shell bought -> launch -> shell launched ->
        -- model -> arrival. advanceOn is the controller's advance-through hook (a tour event
        -- arriving while its predecessor's card is still up dismisses it rather than dropping).
        local byId = {}
        for _, b in Beats.BEATS do
            byId[b.id] = b
        end
        expect(byId.shopDoor.event).toBe("bankDismissed")
        expect(byId.shopDoor.advanceOn).toBe("shellBought")
        expect(byId.launchDoor.event).toBe("shellBought")
        expect(byId.launchDoor.advanceOn).toBe("shellLaunched")
        expect(byId.modelDoor.event).toBe("shellLaunched")
        expect(byId.modelDoor.advanceOn).toBe("modelArrival")
        expect(byId.modelHome.event).toBe("modelArrival")
        expect(byId.modelHome.advanceOn).toBe(nil)
    end)

    test("the welcome carries three pages and copy is page one", function()
        local welcome = Beats.BEATS[1]
        expect(welcome.event).toBe("join")
        expect(welcome.pages ~= nil).toBe(true)
        expect(#welcome.pages).toBe(3)
        for _, page in welcome.pages do
            expect(#page > 0).toBe(true)
        end
        expect(welcome.copy).toBe(welcome.pages[1])
    end)

    test("only the welcome has pages — every other beat is one card", function()
        for i, b in Beats.BEATS do
            if i > 1 then
                expect(b.pages).toBe(nil)
            end
        end
    end)

    test("no beat teaches movement — that is deliberate", function()
        -- the HUD de-emphasises movement DURING PLAY; tour beats direct travel between stops,
        -- which is a tour's job, but none of them may point at the thumbstick itself.
        for _, b in Beats.BEATS do
            expect(b.id ~= "move").toBe(true)
        end
    end)

    test("no copy uses gambling vocabulary (owner ruling)", function()
        -- 'pot', 'ride', 'stake', 'wager', 'bet' are banned near points; 'pile' is the
        -- sanctioned replacement. Checked on WORD BOUNDARIES ('%f[%a]bet%f[%A]') so 'better'
        -- or a future 'bets' can't slip past on a substring technicality.
        for _, b in Beats.BEATS do
            local pages = b.pages or { b.copy }
            for _, text in pages do
                local lower = text:lower()
                for _, banned in { "pot", "ride", "stake", "wager", "bet" } do
                    expect(lower:find("%f[%a]" .. banned .. "%f[%A]")).toBe(nil)
                end
            end
        end
    end)

    test("an event returns its beat when unseen", function()
        local b = Beats.next({}, "join")
        expect(b ~= nil).toBe(true)
        expect(b.event).toBe("join")
    end)

    test("a seen beat never returns again", function()
        local b = Beats.next({}, "join")
        expect(Beats.next({ b.id }, "join")).toBe(nil)
    end)

    test("an unknown event returns nothing", function()
        expect(Beats.next({}, "sneezed")).toBe(nil)
    end)

    test("beats are independent — seeing one does not consume another", function()
        local first = Beats.next({}, "join")
        local second = Beats.next({ first.id }, "win")
        expect(second ~= nil).toBe(true)
        expect(second.event).toBe("win")
    end)

    test("events may arrive out of order", function()
        local b = Beats.next({}, "win")
        expect(b ~= nil).toBe(true)
        expect(b.event).toBe("win")
    end)

    test("the bank beat teaches the ring gesture, not just the bank itself", function()
        -- The ring replaced the hamburger but looks like a readout — this beat is the only thing
        -- left to teach the tap. The copy must name the clock/ring itself AND describe what the
        -- second tap reaches (the ledger's full detail), not just "tap...again".
        local b = Beats.next({}, "bank")
        expect(b ~= nil).toBe(true)
        expect(b.anchor).toBe("wallet")
        local lower = b.copy:lower()
        expect(lower:find("clock") ~= nil or lower:find("ring") ~= nil).toBe(true)
        expect(lower:find("everything") ~= nil or lower:find("ledger") ~= nil).toBe(true)
    end)
end)

describe("OnboardingBeats — anchors match what the controller builds", function()
    test("no beat anchors to a plate that has left the top band", function()
        for _, beat in Beats.BEATS do
            expect(beat.anchor ~= "plate").toBe(true)
        end
    end)

    test("every anchor is one the controller knows", function()
        local known = { drum = true, throwArea = true, potIndicator = true, wallet = true, tour = true }
        for _, beat in Beats.BEATS do
            expect(known[beat.anchor] == true).toBe(true)
        end
    end)

    test("all four tour beats share the tour anchor", function()
        for i, beat in Beats.BEATS do
            if i >= 5 then
                expect(beat.anchor).toBe("tour")
            end
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run from `roblox/`: `lune run tests/run`
Expected: OnboardingBeats.spec FAILS (`#Beats.BEATS` is 4, no pages, no advanceOn).

- [ ] **Step 3: Rewrite the module**

Replace the `BEATS` table (and the `Beat` type) in `roblox/src/shared/OnboardingBeats.luau`; `next()` is unchanged:

```lua
export type Beat = {
    id: string,
    event: string,
    copy: string,
    anchor: string,
    -- The welcome's tap-through pages (copy == pages[1]); nil for every single-card beat.
    pages: { string }?,
    -- The tour's advance-through hook: an event arriving while THIS beat's card is still up
    -- normally drops (never stack) — but if it equals advanceOn, the controller dismisses this
    -- card (the guest has plainly done the thing) and shows the next. Without it a guest who
    -- launched before dismissing "follow the light to the river" would strand the tour: the
    -- modelDoor beat would report "dropped" and shellLaunched may never fire again.
    advanceOn: string?,
}

-- The welcome sequence (owner, 2026-09-03): the one deliberate exception to "never read
-- ahead" — a cold F&F guest needs the core context at join. Three pages, one tap each:
-- the new kind of RPS / the world throw's source + streaks / what points are for.
local WELCOME_PAGES = {
    "This is Roshambo — Rock, Paper, Scissors, but you're playing against the whole world at once.",
    "Every minute the big drum throws what most of the world picked. Beat it and your pile grows — every win in a row triples it. Read the crowd.",
    "Bank your points and they're yours — for fireworks, and one day a teahouse of your own. The drum's about to throw.",
}

OnboardingBeats.BEATS = {
    { id = "welcome", event = "join", copy = WELCOME_PAGES[1], pages = WELCOME_PAGES, anchor = "drum" },
    { id = "throw", event = "throwsUnlocked", copy = "Pick your throw — tap one.", anchor = "throwArea" },
    {
        id = "win",
        event = "win",
        copy = "You won! Every win triples your pile — or BANK THESE keeps it forever.",
        anchor = "potIndicator",
    },
    {
        id = "bank",
        event = "bank",
        copy = "Yours forever! Tap the clock to see your points. Tap again for everything.",
        anchor = "wallet",
    },
    -- ===== The tour (spec §2/§4): earned by banking, walked by the beam =====
    {
        id = "shopDoor",
        event = "bankDismissed",
        copy = "Points buy fireworks. Follow the light!",
        anchor = "tour",
        advanceOn = "shellBought",
    },
    {
        id = "launchDoor",
        event = "shellBought",
        copy = "A firecracker! Follow the light to the river.",
        anchor = "tour",
        advanceOn = "shellLaunched",
    },
    {
        id = "modelDoor",
        event = "shellLaunched",
        copy = "Beautiful. One more stop — follow the light.",
        anchor = "tour",
        advanceOn = "modelArrival",
    },
    {
        id = "modelHome",
        event = "modelArrival",
        copy = "A teahouse of your very own — 20 points. Every win gets you closer.",
        anchor = "tour",
    },
} :: { Beat }
```

Keep the module's header comment but update its second paragraph: the "no movement/exploration beat" rationale gains the amendment from the spec (tour beats direct travel between stops; none teach the thumbstick).

- [ ] **Step 4: Run to verify pass**

Run from `roblox/`: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Format, lint, commit**

Run from `roblox/`: `stylua src tests tools && selene src tools`

```bash
git add roblox/src/shared/OnboardingBeats.luau roblox/tests/OnboardingBeats.spec.luau
git commit -m "feat(onboarding): 8-beat journey -- welcome pages, tour chain with advance-through"
```

---

### Task 6: TourGuide — the pure step machine

**Files:**
- Create: `roblox/src/shared/TourGuide.luau`
- Test: `roblox/tests/TourGuide.spec.luau`

**Interfaces:**
- Consumes: Task 5's beat ids (`bank`, `launchDoor`, `modelDoor`, `modelHome`) as members of a seen list.
- Produces (Tasks 7 and 9 rely on these exact strings): `TourGuide.step(seen: { string }): string` → one of `"NONE" | "SHOP" | "LAUNCH" | "MODEL" | "DONE"`; `TourGuide.beamTag(step: string): string?` → `"TourStop_Shop" | "TourStop_Launch" | "TourStop_Model"` or nil.

- [ ] **Step 1: Write the failing spec**

Create `roblox/tests/TourGuide.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local TourGuide = require("../src/shared/TourGuide")

describe("TourGuide — the step derived from what has been seen", function()
    test("a fresh player is on no tour", function()
        expect(TourGuide.step({})).toBe("NONE")
        expect(TourGuide.beamTag(TourGuide.step({}))).toBe(nil)
    end)

    test("dismissing the bank card starts the tour at the shop", function()
        -- seen ids are marked at DISMISSAL, so 'bank' in seen means the bank card was tapped
        -- away — exactly the moment the tour begins (spec §2).
        expect(TourGuide.step({ "welcome", "throw", "win", "bank" })).toBe("SHOP")
        expect(TourGuide.beamTag("SHOP")).toBe("TourStop_Shop")
    end)

    test("each tour card seen moves the beam one stop on", function()
        expect(TourGuide.step({ "bank", "shopDoor" })).toBe("SHOP") -- card read, shell not yet bought
        expect(TourGuide.step({ "bank", "shopDoor", "launchDoor" })).toBe("LAUNCH")
        expect(TourGuide.beamTag("LAUNCH")).toBe("TourStop_Launch")
        expect(TourGuide.step({ "bank", "shopDoor", "launchDoor", "modelDoor" })).toBe("MODEL")
        expect(TourGuide.beamTag("MODEL")).toBe("TourStop_Model")
    end)

    test("the model-home card seen ends the tour for good", function()
        expect(TourGuide.step({ "bank", "shopDoor", "launchDoor", "modelDoor", "modelHome" })).toBe("DONE")
        expect(TourGuide.beamTag("DONE")).toBe(nil)
    end)

    test("derivation survives a rejoin with holes — later ids dominate", function()
        -- a card can be marked seen while an earlier one was dropped; the FURTHEST id wins,
        -- so a resumed session never walks the guest backwards.
        expect(TourGuide.step({ "modelDoor" })).toBe("MODEL")
        expect(TourGuide.step({ "modelHome" })).toBe("DONE")
        expect(TourGuide.step({ "launchDoor", "bank" })).toBe("LAUNCH")
    end)

    test("order in the seen list is irrelevant", function()
        expect(TourGuide.step({ "modelDoor", "bank", "launchDoor", "shopDoor" })).toBe("MODEL")
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run from `roblox/`: `lune run tests/run`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `roblox/src/shared/TourGuide.luau`:

```lua
--!strict
-- The tour's step machine, derived ENTIRELY from the persisted seenBeats list — no state of
-- its own, which is what makes the tour survive a rejoin for free (spec §4): the same acks
-- that stop a card re-firing also place the beam. Pure; no Roblox globals (Lune-tested).
--
-- Seen ids are marked at card DISMISSAL, so each id below means "the guest has read the card
-- for this leg". The FURTHEST milestone dominates: dropped cards can leave holes in the list,
-- and a resumed session must never walk the guest backwards.
local TourGuide = {}

-- milestone id -> the step the tour is on once that card has been seen, in rank order.
local MILESTONES: { { id: string, step: string } } = {
    { id = "bank", step = "SHOP" },
    { id = "shopDoor", step = "SHOP" },
    { id = "launchDoor", step = "LAUNCH" },
    { id = "modelDoor", step = "MODEL" },
    { id = "modelHome", step = "DONE" },
}

local BEAM_TAGS: { [string]: string } = {
    SHOP = "TourStop_Shop",
    LAUNCH = "TourStop_Launch",
    MODEL = "TourStop_Model",
}

function TourGuide.step(seen: { string }): string
    local seenSet: { [string]: boolean } = {}
    for _, id in seen do
        seenSet[id] = true
    end
    local step = "NONE"
    for _, m in MILESTONES do
        if seenSet[m.id] then
            step = m.step
        end
    end
    return step
end

function TourGuide.beamTag(step: string): string?
    return BEAM_TAGS[step]
end

return TourGuide
```

- [ ] **Step 4: Run to verify pass**

Run from `roblox/`: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Format, lint, commit**

Run from `roblox/`: `stylua src tests tools && selene src tools`

```bash
git add roblox/src/shared/TourGuide.luau roblox/tests/TourGuide.spec.luau
git commit -m "feat(onboarding): TourGuide -- tour step derived purely from seenBeats"
```

---

### Task 7: OnboardingController — pages, tour anchor, advance-through, TourStep

**Files:**
- Modify: `roblox/src/client/EventBus.luau` (add `"TourStep"` to `NAMES`)
- Modify: `roblox/src/client/OnboardingController.client.luau` (STATIC_ANCHORS at :203-229, show/dismiss at :403-456, the Onboard handler at :458-478)

**Interfaces:**
- Consumes: Task 5's `Beat.pages`/`Beat.advanceOn`; Task 6's `TourGuide.step`.
- Produces: `EventBus.TourStep:Fire(step: string)` after every seen-list change (Task 9 listens); `EventBus.Onboard:Fire("bankDismissed", nil)` when the bank card is dismissed. The `OnboardShown` echo contract (`"shown" | "dropped" | "alreadySeen"`) is UNCHANGED — `main.client.luau`'s bank-toast logic depends on it.

- [ ] **Step 1: EventBus name**

Add to `NAMES` in `roblox/src/client/EventBus.luau`, after `"OnboardShown"`:

```lua
    -- The tour's derived step (TourGuide.step over seenLocal), fired by OnboardingController
    -- after every seen-list change. TourBeamController renders the beam from it; nothing else
    -- may derive the step a second way.
    "TourStep",
```

- [ ] **Step 2: The tour anchor**

In `OnboardingController.client.luau`, add to `STATIC_ANCHORS` (all entries deliberately share one offset — none are ever shown at once):

```lua
    tour = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(CLUSTER_TOP_FROM_BOTTOM + BANK_GAP)),
        width = CARD_W,
    },
```

- [ ] **Step 3: Require TourGuide and broadcast the step**

Next to the existing `OnboardingBeats` require, add `local TourGuide = require(script.Parent.Parent:WaitForChild("shared"):WaitForChild("TourGuide"))` — match the exact require style the file already uses for `OnboardingBeats` (read the top of the file; it is the pattern to copy). Then add a helper near `adoptServerSeen` and call it from every place `seenLocal` changes (`adoptServerSeen`'s end, and `dismiss` after the insert):

```lua
local function broadcastTourStep()
    EventBus.TourStep:Fire(TourGuide.step(seenLocal))
end
```

Also call `broadcastTourStep()` once at startup (after the controller finishes wiring), so TourBeamController hears an initial step even before the first Onboard fire.

- [ ] **Step 4: Pages in show/dismiss**

Replace `showCard` and `dismiss`:

```lua
local currentPage = 1

local function showCard(beat: any)
    currentBeat = beat
    currentPage = 1
    copyLabel.Text = if beat.pages then beat.pages[1] else beat.copy
    positionCard(beat)
    card.Visible = true
end

local function dismiss()
    local beat = currentBeat
    if not beat then
        return
    end
    -- The welcome's pages: a tap turns the page; only the LAST page's tap dismisses. seenLocal
    -- is marked once, after the last page, so a guest who quits mid-welcome sees it again.
    if beat.pages and currentPage < #beat.pages then
        currentPage += 1
        copyLabel.Text = beat.pages[currentPage]
        return
    end
    -- Optimistic: stops a re-fire before the round trip lands. The write rides the SAME remote
    -- Task 12's preference switch uses — SetHudPreference — never a second one.
    table.insert(seenLocal, beat.id)
    EventBus.HudPreference:Fire({ seenBeat = beat.id })
    hideCard()
    broadcastTourStep()
    if beat.id == "bank" then
        -- The tour's front door (spec §2): dismissing the bank card is the moment the guest
        -- stands there holding spendable points. BindableEvents are deferred, so this fires
        -- AFTER currentBeat is nil — the handler below can show shopDoor immediately.
        EventBus.Onboard:Fire("bankDismissed", nil)
    end
end
```

- [ ] **Step 5: Advance-through in the Onboard handler**

Replace the `if currentBeat then ... return end` block inside the `EventBus.Onboard.Event:Connect` handler:

```lua
    if currentBeat then
        if currentBeat.advanceOn == event then
            -- A tour event arriving while its predecessor's card is still up: the guest has
            -- plainly DONE the thing the card was asking, so the card's job is over. Dismiss it
            -- (marking it seen, exactly as a tap would) and fall through to show this event's
            -- own beat. Without this, the event would report "dropped" and — for one-shot
            -- events like the only shell's launch — never come again, stranding the tour.
            table.insert(seenLocal, currentBeat.id)
            EventBus.HudPreference:Fire({ seenBeat = currentBeat.id })
            hideCard()
            broadcastTourStep()
        else
            -- NEVER STACK. A second event while a card is up is dropped, not queued — these
            -- are bones, and a stack of cards is a tutorial.
            EventBus.OnboardShown:Fire(event, "dropped")
            return
        end
    end
```

(`adoptServerSeen(serverSeenBeats)` at the handler's top already tolerates the `nil` second argument that `bankDismissed`/`modelArrival` fires carry — `type(list) ~= "table"` returns early.)

- [ ] **Step 6: Gates**

Run from `roblox/`: `stylua src tests tools && selene src tools && lune run tests/run`
Expected: PASS (Compiles.spec recompiles both edited files — watch for the 200-register ceiling; if OnboardingController trips it, do-block the additions per the standing rule from `docs/wiki/log.md` 2026-09-03).

- [ ] **Step 7: Commit**

```bash
git add roblox/src/client/EventBus.luau roblox/src/client/OnboardingController.client.luau
git commit -m "feat(onboarding): welcome pages, tour advance-through, TourStep broadcast"
```

---

### Task 8: main.client fires the tour's inventory events

**Files:**
- Modify: `roblox/src/client/main.client.luau` (the `FireworkState.OnClientEvent` handler at :807)

**Interfaces:**
- Consumes: the existing handler's `state.shells` table (`{ [shellId]: { count, launchable, reason } }`) and the file's `knownSeenBeats` variable (kept current by the existing Onboard plumbing).
- Produces: `EventBus.Onboard:Fire("shellBought", knownSeenBeats)` on a rising total-count edge; `EventBus.Onboard:Fire("shellLaunched", knownSeenBeats)` on a falling edge.

- [ ] **Step 1: Add the edge detector**

Above the `FireworkState.OnClientEvent:Connect` handler, add:

```lua
-- Tour events derived from inventory EDGES, not requests: RequestFireworkLaunch can be
-- refused (site, gear, condition), and the shop's ShopPurchase fire can fail server-side —
-- but a total count that ROSE is a completed purchase, and one that FELL is a shell the
-- server actually consumed (a refused launch echoes an unchanged count). nil until the first
-- echo lands: the first FireworkState is a BASELINE, never an edge, so a returning player
-- holding shells does not get a spurious "shellBought" at join.
local knownShellTotal: number? = nil

local function totalShellCount(shells: any): number
    local total = 0
    if typeof(shells) == "table" then
        for _, st in shells do
            if typeof(st) == "table" and typeof(st.count) == "number" then
                total += st.count
            end
        end
    end
    return total
end
```

- [ ] **Step 2: Fire on edges inside the handler**

Inside the `FireworkState.OnClientEvent:Connect(function(state)` handler, immediately after the line `fireworkShells = state.shells` (keep every existing line), add:

```lua
        local total = totalShellCount(state.shells)
        if knownShellTotal ~= nil then
            if total > knownShellTotal then
                EventBus.Onboard:Fire("shellBought", knownSeenBeats)
            elseif total < knownShellTotal then
                EventBus.Onboard:Fire("shellLaunched", knownSeenBeats)
            end
        end
        knownShellTotal = total
```

- [ ] **Step 3: Gates + commit**

Run from `roblox/`: `stylua src tests tools && selene src tools && lune run tests/run`
Expected: PASS.

```bash
git add roblox/src/client/main.client.luau
git commit -m "feat(onboarding): shellBought/shellLaunched fired from FireworkState inventory edges"
```

---

### Task 9: TourBeamController — the one beam

**Files:**
- Create: `roblox/src/client/TourBeamController.client.luau`

**Interfaces:**
- Consumes: `EventBus.TourStep` (Task 7), `TourGuide.beamTag` (Task 6), place parts tagged `TourStop_Shop`/`TourStop_Launch`/`TourStop_Model` (owner tags them in Task 12).
- Produces: `EventBus.Onboard:Fire("modelArrival", nil)` once, on proximity to the MODEL stop.

- [ ] **Step 1: Write the controller**

Create `roblox/src/client/TourBeamController.client.luau`:

```lua
--!strict
-- The tour's waypoint: ONE tall client-side beam over the current stop (spec §4 — owner
-- picked the classic beam over diegetic lanterns: unmissable beats beautiful for a demo
-- week). Client-only because each guest is on their own step; old hands (step NONE/DONE)
-- never see it. Degradation (spec §8): a missing tag means no beam but the beat cards still
-- show — warn once per step, never error.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TourGuide = require(script.Parent.Parent:WaitForChild("shared"):WaitForChild("TourGuide"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local ARRIVE_STUDS = 30 -- inside this range the beam dims; at the MODEL stop it also fires arrival
local POLL_SECONDS = 0.25
local BEAM_HEIGHT = 220
local BEAM_GIRTH = 4

local beam: BasePart? = nil
local currentStep = "NONE"
local target: BasePart? = nil
local arrivalFired = false
local warnedStep: { [string]: boolean } = {}

local function clearBeam()
    if beam then
        beam:Destroy()
        beam = nil
    end
    target = nil
end

local function buildBeam(at: BasePart)
    clearBeam()
    local p = Instance.new("Part")
    p.Name = "TourBeam"
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(255, 214, 120) -- chōchin gold, not alarm red
    p.Transparency = 0.35
    p.Size = Vector3.new(BEAM_GIRTH, BEAM_HEIGHT, BEAM_GIRTH)
    p.CFrame = CFrame.new(at.Position + Vector3.new(0, BEAM_HEIGHT / 2, 0))
    p.Parent = workspace
    beam = p
    target = at
end

local function retarget(step: string)
    currentStep = step
    arrivalFired = false
    local tag = TourGuide.beamTag(step)
    if tag == nil then
        clearBeam()
        return
    end
    local tagged = CollectionService:GetTagged(tag)
    local part: BasePart? = nil
    for _, inst in tagged do
        if inst:IsA("BasePart") then
            part = inst
            break
        end
    end
    if part == nil then
        clearBeam()
        if not warnedStep[step] then
            warnedStep[step] = true
            warn(`[Tour] no part tagged {tag} — beam skipped, cards still carry the words`)
        end
        return
    end
    buildBeam(part)
end

EventBus.TourStep.Event:Connect(retarget)

-- Proximity: dim the beam when the guest is basically there, and at the MODEL stop fire the
-- arrival beat exactly once per step activation. Throttled — this is a walkstate check, not
-- a per-frame effect.
local sincePoll = 0
RunService.Heartbeat:Connect(function(dt: number)
    sincePoll += dt
    if sincePoll < POLL_SECONDS then
        return
    end
    sincePoll = 0
    local at = target
    local b = beam
    if at == nil or b == nil then
        return
    end
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root == nil or not root:IsA("BasePart") then
        return
    end
    local flat = at.Position - root.Position
    local near = Vector3.new(flat.X, 0, flat.Z).Magnitude <= ARRIVE_STUDS
    b.Transparency = if near then 0.85 else 0.35
    if near and currentStep == "MODEL" and not arrivalFired then
        arrivalFired = true
        EventBus.Onboard:Fire("modelArrival", nil)
    end
end)
```

- [ ] **Step 2: Gates**

Run from `roblox/`: `stylua src tests tools && selene src tools && lune run tests/run`
Expected: PASS — Compiles.spec picks the new file up automatically. (selene: the file uses every variable it declares; if it flags the `b.Transparency` write pattern, assign through a local.)

- [ ] **Step 3: Commit**

```bash
git add roblox/src/client/TourBeamController.client.luau
git commit -m "feat(onboarding): TourBeamController -- one client beam over the tour's next stop"
```

---

### Task 10: The model pad — SiteCoordinator claim + server boot wiring

**Files:**
- Modify: `roblox/src/shared/SiteCoordinator.luau`
- Modify: `roblox/src/server/main.server.luau` (after the T01–T14 `registerPad` loop, BEFORE the `vacantActions()` sweep at :1966)
- Test: `roblox/tests/SiteCoordinator.spec.luau` (exists — extend it; read its helper setup first and reuse its fake-registry pattern)

**Interfaces:**
- Consumes: existing `PadRegistry` (`register/claim/release/get`), `VacantState.resolve`, the `Action` type.
- Produces: `SiteCoordinator:claimModel(ownerId: string, padId: string): Action?` — claims that exact pad for a sentinel owner and returns a lit S-deck + S-teahouse structure action; nil if the pad is unknown, occupied, or the owner already holds a site. `main.server.luau` applies it at boot when `Workspace` attribute `TourModelPadId` names a registered pad.

- [ ] **Step 1: Write the failing spec cases**

Append to the existing describe blocks in `roblox/tests/SiteCoordinator.spec.luau`, reusing the file's own construction helpers (read them first — the fake registry/spec setup at the top of the file is the pattern to copy; the snippet below assumes a `SiteCoordinator.new(PadRegistry.new())` with pads registered exactly as the neighboring tests do):

```lua
describe("SiteCoordinator — the model pad (claimModel)", function()
    local function coordinatorWithPads()
        local PadRegistry = require("../src/shared/PadRegistry")
        local c = SiteCoordinator.new(PadRegistry.new())
        c:registerPad("T01", { maxSize = "L", vacantForm = "dormant-structure" })
        c:registerPad("T02", { maxSize = "M", vacantForm = "dormant-structure" })
        return c
    end

    test("claims the named pad, lit, with the stock S bundle", function()
        local c = coordinatorWithPads()
        local action = c:claimModel("TOUR_MODEL", "T02")
        expect(action ~= nil).toBe(true)
        expect(action.padId).toBe("T02")
        expect(action.deckSize).toBe("S")
        expect(action.teahouse.size).toBe("S")
        expect(action.treatment.kind).toBe("structure")
        expect(action.treatment.lit).toBe(true)
        expect(c:isVacant("T02")).toBe(false)
    end)

    test("a joining owner is never assigned the model pad", function()
        local c = coordinatorWithPads()
        c:claimModel("TOUR_MODEL", "T01")
        local action = c:onJoin("player9", { maxDeckSize = "S", teahouses = {} })
        expect(action ~= nil).toBe(true)
        expect(action.padId).toBe("T02")
    end)

    test("nil for an unknown or already-claimed pad, or a second model claim", function()
        local c = coordinatorWithPads()
        expect(c:claimModel("TOUR_MODEL", "T99")).toBe(nil)
        expect(c:claimModel("TOUR_MODEL", "T01") ~= nil).toBe(true)
        expect(c:claimModel("TOUR_MODEL_2", "T01")).toBe(nil) -- occupied
        expect(c:claimModel("TOUR_MODEL", "T02")).toBe(nil) -- sentinel already holds a site
    end)
end)
```

(If the spec file's real registration helper differs, adapt the setup lines to it — the assertions are the contract. `isVacant` already exists; it is called at `main.server.luau:2531`.)

- [ ] **Step 2: Run to verify failure**

Run from `roblox/`: `lune run tests/run`
Expected: FAIL — `claimModel` is nil.

- [ ] **Step 3: Implement `claimModel`**

Add to `roblox/src/shared/SiteCoordinator.luau` (after `vacantActions`, using the file's existing `CENTERED` local and `VacantState`):

```lua
-- The model teahouse (onboarding journey, owner 2026-09-03): one named pad claimed at boot
-- by a sentinel "owner" and materialized as the lit stock S bundle — exactly what the
-- starter SKU buys, standing built so a guest can walk its deck and slide its shoji
-- (visitor slides are live-only, so the model tidies itself). Claimed through the SAME
-- registry as every player claim, which is the whole trick: onJoin and buy-to-claim skip it
-- because it is simply occupied.
function SiteCoordinator:claimModel(ownerId: string, padId: string): Action?
    if self._held[ownerId] ~= nil then
        return nil
    end
    local rec = self._registry:get(padId)
    if rec == nil or rec.occupant ~= nil then
        return nil
    end
    local loadout = { baseStyle = "teahouse-1story" }
    self._registry:claim(padId, ownerId)
    self._held[ownerId] = padId
    return {
        padId = padId,
        spec = rec.spec,
        treatment = VacantState.resolve(ownerId, loadout, rec.spec and rec.spec.vacantForm),
        deckSize = "S",
        teahouse = { size = "S", loadout = loadout, placement = CENTERED },
    }
end
```

- [ ] **Step 4: Run to verify pass**

Run from `roblox/`: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Boot wiring in main.server.luau**

Between the `registerPad` loop and the `vacantActions()` sweep (order matters — the sweep must see the model pad as occupied, or it double-applies a dormant treatment over the lit one):

```lua
-- The model teahouse (onboarding journey): the place names its pad via the Workspace
-- attribute TourModelPadId (owner sets it in Studio next to the TourStop_* tags). Absent
-- attribute = no model pad — a warn, not an error, so an untagged place still boots.
do
    local modelPadId = workspace:GetAttribute("TourModelPadId")
    if typeof(modelPadId) == "string" and modelPadId ~= "" then
        local action = siteCoordinator:claimModel("TOUR_MODEL", modelPadId)
        if action ~= nil then
            applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
        else
            warn(`[Tour] TourModelPadId={modelPadId} could not be claimed — unknown or occupied pad`)
        end
    else
        warn("[Tour] TourModelPadId attribute unset — no model teahouse this server")
    end
end
```

- [ ] **Step 6: Gates + commit**

Run from `roblox/`: `stylua src tests tools && selene src tools && lune run tests/run`
Expected: PASS.

```bash
git add roblox/src/shared/SiteCoordinator.luau roblox/tests/SiteCoordinator.spec.luau roblox/src/server/main.server.luau
git commit -m "feat(onboarding): the model pad -- sentinel claimModel + TourModelPadId boot wiring"
```

---

### Task 11: Build check + wiki records

**Files:**
- Modify: `docs/wiki/world/place-state.md` (publish checklist item 1)
- Modify: `docs/wiki/program/backlog.md` (the onboarding JOURNEY section)
- Modify: `docs/wiki/log.md` (append an entry)

- [ ] **Step 1: Full gates, everything together**

Run from `roblox/`: `stylua --check src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/journey-build-check.rbxl`
Run from `server/`: `npm test`
Expected: all green. Fix anything that is not before touching the wiki.

- [ ] **Step 2: Amend the publish checklist**

In `docs/wiki/world/place-state.md` item 1, supersede the dusk/night ban with the demo exception (keep the history visible, per the wiki's supersede style):

- The rule "never publish a dusk/night lock" gains: **F&F-demo exception (owner ruling 2026-09-03, spec `docs/superpowers/specs/2026-09-03-onboarding-journey-design.md` §7): publish with `DayNightLockT = 0.40` (the documented dusk knob) for the demo window** — the journey ends on a firework and a noon sky kills the payoff. This resolves the ⚠ OPEN QUESTION logged 2026-09-03 **for the demo period only**; the post-demo default remains open.
- Add to the checklist (as new items): tag `TourStop_Shop` (hanabiya), `TourStop_Launch` (the chosen riverside `FireworkLaunchSite`), `TourStop_Model` (the model pad's anchor part); set Workspace attribute `TourModelPadId` to the model pad's `T##` id.

- [ ] **Step 3: Backlog + log**

In `docs/wiki/program/backlog.md`, supersede the "onboarding JOURNEY" section's status line: in execution as of 2026-09-03 — spec `docs/superpowers/specs/2026-09-03-onboarding-journey-design.md`, plan `docs/superpowers/plans/2026-09-03-onboarding-journey.md`; the copy workshop and the owner's cold phone walk remain the open gates. Append a `docs/wiki/log.md` entry (newest-first per the file's convention) summarizing: journey spec'd + built (8 beats, welcome pages, tour beam, model pad, starter SKU 20 pts), owner rulings folded (mixed demo / route / model-as-first-step / beam / dusk lock).

- [ ] **Step 4: Commit**

```bash
git add docs/wiki/world/place-state.md docs/wiki/program/backlog.md docs/wiki/log.md
git commit -m "docs(wiki): onboarding journey in execution; dusk-lock demo exception recorded"
```

---

### Task 12: Owner gates — copy workshop, Studio setup, publish, cold walk

Nothing in this task is delegable to a subagent; it is the session's closing checklist with the owner.

- [ ] **Step 1: Copy workshop.** Walk the owner through every player-facing string this plan shipped (the three welcome pages FIRST — they flagged join specifically — then beats 2–8, the starter prompt labels, the ticker line). Apply their edits in `OnboardingBeats.luau` / `EconomyController.client.luau`; the vocabulary spec test guards the ruling; re-run `lune run tests/run`; commit.
- [ ] **Step 2: Studio setup (owner, with Studio MCP assistance).** In the live place: tag the three `TourStop_*` parts (shop, chosen launch site, model pad anchor), set Workspace attribute `TourModelPadId`, set `DayNightLockT = 0.40`, run `tools/studio/verifyWorkspaceConvention.luau`, then the full pre-publish checklist on `docs/wiki/world/place-state.md` (including the toolbox-backdoor scan status).
- [ ] **Step 3: Push + publish.** Push main (dev backend picks up the starter SKU); owner publishes the place.
- [ ] **Step 4: The real gate — the cold walk.** Owner walks the entire journey on their iPhone, portrait, on the published place, narrating nothing: join → welcome pages → throw → win → bank → beam → hanabiya → firecracker → beam → launch (against a dusk sky) → beam → model teahouse → beat 8 → starter prompt shows "Starter teahouse — earn N more pts". Fix what the walk finds; log the gate in the wiki.

---

## Self-review notes

- **Spec coverage:** §2 chain → Task 5; §3 welcome → Tasks 5+7; §4 TourGuide/beam/tags/events → Tasks 6, 7, 8, 9; §5 bundle → Tasks 1–4; §6 model pad → Task 10; §7 sky → Tasks 11–12; §8 degradation → Tasks 9 (missing tag), 10 (failed claim warn), 7 (beam-independent cards); §9 testing → per-task + Task 12's walk; §10 order → task order.
- **One deliberate deviation from spec §8:** "a guest who dismisses a tour card keeps the beam" holds (beam derives from step, not card visibility), and the advance-through rule (Task 5/7) strengthens the spec — it prevents the stranded-tour edge (launching before dismissing the launch card) that the spec's "dropped" semantics would have left open. Recorded in the OnboardingBeats comment.
- **Known accepted edge:** a mid-tour rejoiner at SHOP who already holds a shell must buy another 1-pt firecracker to advance (inventory edges are session-local). F&F guests are new accounts; not worth machinery this week.
