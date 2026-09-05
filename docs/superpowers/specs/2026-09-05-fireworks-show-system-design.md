# Fireworks Show System — Design

**Date:** 2026-09-05
**Status:** Approved in conversation (owner, 2026-09-05: "yes, start with B, write the plan"). Ten decisions were taken in conversation and are recorded on
[[backlog]] § "Fireworks show system — decisions taken in conversation"; this spec argues from
them. One economy question is left open (§9) and does not block the first two sub-projects.
**Program context:** The fireworks program's remaining steps (range → vocabulary → **handheld →
distribution**) and the social-loop thread (owner, 2026-09-04): the reveal as spectacle, gifting,
gathering. This is the distribution step, widened by the owner into shows, consoles and a second
economy. Related: `2026-08-05-fireworks-core-design.md`, `2026-09-01-proving-range-design.md`,
`2026-09-04-deck-mortars-design.md`, [[fireworks]], [[hanabiya]].

**Question** (owner, 2026-09-05): fireworks gifting, exchange, crafting, pooling, mystery shells,
a console on the Hanabiya roof, whale consoles on teahouse decks — and "a danger of fireworks
everywhere, all the time, diminishing their value."

**Short answers:**

1. **A show is data and the server plays it.** Cues of time, mortar and shell; server-authoritative
   playback so every phone sees one program; the director guards the sky.
2. **Three console tiers, one object, two fuels.** Rooftop (public, golden-ticket access, three
   minutes, fires the arena stage), teahouse (owner-bought, fires its own deck), primo (the same
   console with a tap on the owner's powder). Teahouse shows are local by construction.
3. **Two economies, one seal.** Points last; powder burns. Powder buys only things that burn.
   The Hanabiya melts shells back to powder. Nothing ever flows from powder or shells to points.
4. **Gathering replaces scarcity rules.** Firing is always free within reach and budget; a party
   is impromptu or scheduled; the calendar exists so people come and nobody steps on anyone.
5. **Decompose into four sub-projects** (§10), each its own plan; the second is testable on the
   A13 with a hand-authored show before any console exists.

---

## 0. Vocabulary

| word | meaning |
|---|---|
| **shell** | a catalogued firework (`server/src/fireworks.ts` `SHELL_IDS`; recipe in `FireworkCatalog.luau`) |
| **powder** | the consumable currency of the fireworks economy; priced in the same units as shells; a bottle rocket is one powder |
| **stage** | somewhere a show can be launched from: a teahouse deck, the Hanabiya rooftop, a proving station |
| **show** | an ordered list of cues, owned by a player, bound to a stage |
| **cue** | `{ t_ms, slot, shellId }` — when, from which tube, what |
| **console** | the object a show is composed on; three tiers (§4) |
| **golden ticket** | the token that admits a player to the rooftop stage (§5) |
| **party** | any show, impromptu or scheduled; a scheduled one is a calendar entry (§6) |

## 1. A show is data

```
Show {
  id, ownerUserId, stageId,
  fuel: 'inventory' | 'powder',
  cues: [{ t_ms: number, slot: string, shellId: string }],   // slot: 'hand' | 'mortar:S' | 'mortar:M' | 'mortar:L' | a battery tube id
  title?: string
}
```

- **Limits are config, not design**: `SHOW_MAX_CUES` (default 120) and `SHOW_MAX_DURATION_S`
  (default 300). They bound payload size, not spectacle — decision 6 says quantity is the
  director's business.
- **Validation is pure and shared**: a `ShowPlan.luau` module (Lune-tested) and a TypeScript twin
  in `server/src/shows.ts`, both held to a fixture (`shared-fixtures/shows.json`) the way the
  game rules are: cue ordering, slot ∈ the stage's slots, shell's gear requirement matches the
  slot's tier (`MortarPlacement.SHELL_MORTAR`), condition shells (`ishibana`) are allowed; today
  their condition is a client-side launchable gate on every launch path, and the per-cue
  fire-time check is sub-project C's (amended 2026-09-05 after the final review).
- **Fire-now is a one-cue show** on the same path. There is no second launch path.

## 2. The sequencer (server-authoritative playback)

Lives in the Roblox game server (`main.server.luau` is the only launch authority today, and
`RequestFireworkLaunch` already does spend-first, broadcast-second). A show adds a reservation
step in front of that pattern:

1. **Reserve.** `POST /api/v1/players/:id/shows/reserve { show }` on the backend validates the
   show against the player's inventory (fuel `inventory`) or powder balance (fuel `powder`), debits
   **everything up front** in one atomic update, and returns a `reservationId`. A show that cannot
   be fully paid does not start. Once lit, lit: there are no partial refunds after go (decision 6's
   party framing; a finale that stops halfway is the failure mode).
2. **Play.** The game server walks the cues on its own clock and emits each as the existing
   `FireworkLaunched` broadcast, with `origin`/`heading`/`apexHeight` derived exactly as the
   single-shell path derives them (deck mortar muzzle; battery tube; hand). `by` carries the
   show's owner and a `showId` so clients can render credits.
3. **Director unchanged.** Every client admits bursts through `FireworkDirector.admit` as today.
   The sequencer does not throttle: a dense show is authored dense and the director staggers it.
   ⚠ This is the load-bearing performance assumption and it is UNMEASURED at scale ([[fireworks]]
   § Performance rules). Sub-project B ends with the measurement (§10).
4. **Owner leaves mid-show:** playback continues (it is reserved and server-owned).
5. **One show per stage at a time.** A second go on a busy stage queues behind the current show
   on the same stage only; stages are independent.

A pure `ShowPlayer.luau` (Lune-tested) turns a show plus a start time into the timeline the
server ticks, so the timing rule is testable without Roblox.

## 3. Stages and access policies

Every show has a stage; every stage has an access policy. **The arena is a stage in the same
model, not a special case** (decision 5): booking data exists from day one even though only the
rooftop enforces it at first.

| stageId | slots | policy | who |
|---|---|---|---|
| `deck:<userId>` | the owner's placed mortars (`mortarPlacements`) + `hand` | **owner** | the teahouse owner, on their deck |
| `rooftop` | the three battery tubes (tagged `FireworkTubeMount`, tiers from the mount) + `hand` | **ticket** | holder of an active booking, or a ticket holder on an empty roof |
| `station:<name>` (north arena, bridge, upper north, mid pool, hi west) | that station's tube | **booked** | nobody yet — data only; "jukebox play queueing" is banked |

Access is re-evaluated server-side on every go (the `LaunchSites.isValid` posture: a gate, not a
hint). A teahouse console never targets any stage but its own deck (decision 4).

## 4. Consoles

One object, three tiers, differing in stage and fuel:

| tier | where | stage | fuel | how acquired |
|---|---|---|---|---|
| **rooftop** | the Hanabiya roof platform (`HanabiyaRooftop`) | `rooftop` | inventory | golden ticket (§5) |
| **teahouse** | a loadout item on the deck (new `console` entry in `StructureCatalog`/`LOADOUT_KEYS`, priced under `CONSOLE_PRICES` like `MORTAR_PRICES`) | `deck:<owner>` | inventory | bought with points (or Robux — §9) |
| **primo** | the same teahouse console with the powder tap unlocked | `deck:<owner>` | inventory **or** powder | a one-time upgrade purchase, then powder top-ups |

**Programmer first, fire-now second** (decision 1). The console UI is the proving panel's
descendant (Fire / Ladder / Seq / Boost are the seed): pick a slot, pick a shell, place it on a
beat timeline, see the total cost, press **Go**; a **Fire now** button launches the selected shell
immediately as a one-cue show. **Instrument mode** (live firing as performance) is a later unlock
and out of scope here.

**Fuel resolution on a primo console:** a cue draws an owned shell if the owner has one, else
powder at list price; the composer shows the split before go. Shells not flagged
`powderEligible` (special / secret / rare — a new catalogue flag) can be fired only from
inventory.

## 5. Golden tickets and the rooftop turn

- **A turn is three minutes** (`ROOFTOP_TURN_S = 180`; decision 7). It starts when the ticket
  holder arrives on the roof with an active booking, or steps onto an empty roof holding a
  ticket. It ends on the clock or when they leave; a show in flight finishes; no new cues after.
- **No queue.** Time on the roof is a perk, not a rota (decision 7).
- **A ticket unlocks booking** (decision 8): the holder books a start time on the calendar (§6),
  which announces the show and guarantees the roof, or spends the ticket on the spot if the roof
  is free. Booked time is visible, so impromptu use only ever happens on an empty roof.
- **Transferable once, in person** (decision 9): a proximity gift (the game server verifies both
  players are present and within reach, then calls the backend); a gifted ticket carries
  `giftedFrom` and cannot be gifted again. Never exchangeable for anything. Only the holder can
  book with it.
- **Daily cap on roof time per player** (`ROOFTOP_DAILY_TURNS = 1`, env-tunable), regardless of
  where the tickets came from — the anti-hog rule.
- **Credits name both**: "MC: Kai · ticket from Jon" on whatever surface renders show credits.
- **Supply is sized to capacity.** The roof holds twenty turns an hour; a ticket should be
  redeemed perhaps every ten to fifteen minutes on a busy server. Tickets come from the streak-tier
  drop table (§7); the tier is the dial. ⚠ At the current crowd's win rate a four-streak arrives
  about hourly per active player — too generous; start at six and tune from redemption logs.
- **Data**: `goldenTickets: [{ id, earnedAt, giftedFrom? }]` on the user; `rooftopTurnsToday`
  derived from bookings, not stored.
- **The hatch is the gate.** Access to the platform is deliberately unbuilt (back-rail gap
  reserved); the ladder/hatch admits only a player whose turn is active.

## 6. The party calendar

A booking is `{ id, stageId, ownerUserId, startAt, durationS, title, kind }` with
`kind ∈ 'rooftop' | 'party'`.

- **`rooftop` bookings are enforced** (they consume a ticket and grant the turn).
- **`party` bookings are voluntary listings** for teahouse shows (decision 6): they enforce
  nothing — anyone may fire at any time — and exist so people can come and so nobody unknowingly
  steps on another's evening. Overlap is allowed; the calendar just shows it.
- **Announcement carrier — PLACEHOLDER.** A `ShowAnnounced` remote fires when a booking is
  created and when its show goes live. What renders it (the lantern telegraph, the bell, the
  reveal card, a board at the arena) is a world-thread question and is NOT decided here. Nothing
  in this spec depends on the answer.
- Endpoints: list upcoming bookings (all stages), create, cancel (owner only; a rooftop
  cancellation refunds the ticket only before the start).

## 7. Powder: the second economy

Decision 10, in full. Points are the durable economy (score, standings, things that last).
Powder is the consumable economy. **Powder buys only things that burn.**

| from | to | rule |
|---|---|---|
| points | powder / shells | one way, the existing sink (`POST …/powder/topup { points }` moves wallet points into powder; `/purchase` unchanged for shells) |
| Robux | powder / shells | Developer Products, granted only in the server's receipt handler with PurchaseId idempotency; product ids are out of scope |
| shells | powder | **melt at the Hanabiya** (`POST …/fireworks/melt { shellId, count }`) at list price; only `powderEligible` shells |
| powder | shells / firing | buy at list price, or fire directly from a primo console |
| shells / powder | points | **never** |
| powder | anything durable | **never** |

- **Why melting is safe:** every input to powder is either paid (points, Robux) or earned by a
  win, and every output burns. Gifting a shell is gifting powder once melting exists; that is
  acceptable because nothing durable can come of it, and the roof cap and the director bound
  the spectacle. The only leak would be powder buying a durable, and the seal forbids it.
- **Outside the powder economy in both directions:** `powderEligible: false` shells (special /
  secret / rare) and golden tickets — not buyable with powder, not meltable (or a token melt).
  Their value is prestige, and prestige that converts stops being prestige.
- **Powder never expires and is never refunded** (a kid's balance vanishing is a bad feeling; a
  show that fires is spent).
- **Data**: `powder: number` on the user; the existing `fireworks` map stays as the shell
  inventory. `evaluateShell`/`shellStates` gain the powder-eligible flag.

### Drops by streak tier

Settlement today grants one `firecracker` on every WIN. Replace the flat grant with a
fixture-held tier table keyed to the streak *after* the win, awarded on the WIN event (so it is
neutral to Bank vs Stake — banking never resets `currentStreak`):

```
streak 1–2 → firecracker
streak 3   → a small shell (peony)
streak 5   → a better shell (wa)
streak N   → golden ticket   (N = 6 to start; tuned to roof capacity)
```

Drops are **items, not powder amounts**: "you got a peony" is legible to an eight-year-old; a
number ticking up is not. A dropped gear shell a player cannot fire yet is not a dead item — it
melts. Exact shells and thresholds live in `shared-fixtures/firework-drops.json`; the table must
draw only from the mystery pool's "never a disappointment" set.

## 8. What players see (and the fireworks-everywhere danger)

Decision 6 removed every scarcity *rule*: anyone fires what they own, any time, in any quantity
within mortar reach and the director's budget. What bounds the sky is structure:

- **Place**: shells launch from stages, not from where you stand (unchanged).
- **Rate**: the director's budget staggers volleys; a per-player launch cooldown
  (`LAUNCH_COOLDOWN_MS`, small) stops button-mashing without touching shows.
- **Economy**: melting and the exchange ladder pull small shells out of circulation into fewer,
  bigger ones; a pooled show turns forty contributions into one event.
- **Gathering**: a scheduled party draws players to the vantage that sees it, which is the social
  dynamic the owner wants and the reason big shows are worth announcing.
- **Credits** on the reveal/board surface: whose show it is, and for the rooftop, whose ticket.

## 9. Open question (owner's call; does not block A or B)

The meta-game spec says the Robux catalogue "never overlaps point items" — its words: *"a
purchased pagoda proves nothing"*, i.e. a bought teahouse must never pass for an earned one; the
2026-09-05 fireworks ruling says everything sells for Robux. For
consumables there is no conflict. For the **teahouse console and other durables** the two pull
apart. Recommended: consumables sell for both currencies; durables split into an earned catalogue
and a non-overlapping Robux cosmetic catalogue. Sub-project C needs the answer before the
console's price list is written.

## 10. Decomposition — four sub-projects, four plans

| | sub-project | delivers | testable by |
|---|---|---|---|
| **A** | **Powder and drops** (backend) | `powder` balance, top-up from points, melt endpoint, `powderEligible` flag, streak-tier drop table with fixture, Robux grant seam (no product ids) | Vitest; the Hanabiya shop shows the melt |
| **B** | **Shows and the sequencer** | `Show` format + shared validation + fixture, `ShowPlayer.luau`, backend reserve, game-server playback over `FireworkLaunched`, a Studio-only "play this show file" verb on the proving panel | **the A13 test**: a large hand-authored show with the newer shells, watched on phones; this is where the director's scale assumption is finally measured |
| **C** | **Consoles, tickets, rooftop turn** | rooftop hatch gate, three-minute turn, golden tickets (earn / gift-once / redeem), daily cap, teahouse console as a loadout item, primo powder tap, the composer UI | two accounts on dev; a ticket gifted and booked |
| **D** | **Calendar and stages** | bookings (rooftop enforced, party voluntary), stage registry including the five stations as data, `ShowAnnounced` placeholder, credits | a booked rooftop show and a listed party |

A before B only for the `powder` fuel path; B can ship on `inventory` fuel alone. C depends on B
and D. Each sub-project gets its own brainstorm-check, spec amendment if needed, and plan.

## 11. Explicitly out of scope

- **Fireworks combat** (bottle-rocket wars) — its own spec; banked on [[backlog]].
- **Audience handhelds** (sparklers, whistlers) — the program's handheld step; banked.
- **Instrument mode** on any console.
- **Public access to the five stations** — data model only (§3).
- **The announcement's visual carrier** (§6 placeholder).
- **Robux product ids and pricing**; the catalogue-overlap ruling (§9).
- **Any change to the RPS loop.** Fireworks read the round (`ishibana`) and never influence it.

## 12. Testing posture

TDD throughout. Server: Vitest for powder flows (the seal as tests: no endpoint moves powder to
points or durables), melt eligibility, drop table against its fixture, reserve atomicity, ticket
gift-once, daily cap, booking overlap rules. Luau under Lune: `ShowPlan` validation against the
shared fixture, `ShowPlayer` timelines, stage slot resolution. The one thing no harness can
measure — the sky at scale — is sub-project B's exit gate on the A13, with the bench hygiene
rule ([[fireworks]]: park the bench the instant its reading is taken).

## Raw layer

- Decisions 1–10: [[backlog]] § "Fireworks show system — decisions taken in conversation".
- Launch path: `roblox/src/server/main.server.luau` (`RequestFireworkLaunch`, `FireworkLaunched`,
  battery tube selection, pity ramp), `roblox/src/shared/{LaunchSites,MortarPlacement,FireworkDirector,FireworkSchedule,FireworkCatalog}.luau`.
- Economy: `server/src/fireworks.ts` (`SHELL_IDS`, `SHELL_PRICES`, `REQUIREMENTS`, `MORTAR_PRICES`),
  `server/src/routes/apiV1.ts` (`/fireworks`, `/fireworks/spend`, `/purchase`, `/mortar-placements`),
  `server/src/engine/Settlement.ts:159` (the flat firecracker grant this spec replaces),
  `server/src/loadout.ts` (`LOADOUT_KEYS`), `server/src/models/User.ts` (`fireworks`, `mortarPlacements`).
- Rulings this spec stands on: Lens B (2026-07-20), Robux-buys-points ruled out
  (`2026-07-04-roshambo-metagame-design.md`), the status-display neutrality rule ([[status-display]]),
  the mystery-pool "never a disappointment" rule and "a drop is a gift, not a jackpot" ([[backlog]]).
