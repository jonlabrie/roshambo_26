# ZenDojo Canyon — Destinations Programme + Falls-Pool Dock

**Date:** 2026-07-28
**Supersedes:** the implicit "fill the canyon with trees" approach. Complements
`2026-07-27-forest-preserve-foliage-design.md`, which reserved these sites and planted
around them at reduced density precisely so this build removes almost nothing.

---

## 1. Why the canyon exists

The game needs almost no world. Rock-paper-scissors against the majority, 60-second
rounds, one point a win, and a stake-or-bank layer that turns a streak into a 3ⁿ faucet —
all of that runs in the Arena, the Square, the Bell and a community display.

**Everything beyond that exists to make a pad worth buying and a friend worth inviting.**
Teahouses are the product: a private, elevated, curated view, a place to launch fireworks
from and be seen doing it. The canyon is the thing that view looks at. Its primary
function is **beauty** — a beautiful place to gather, and a beautiful place to own.

Two consequences follow, and they govern every decision below:

**Compose for the view DOWN from the pads first.** That is the real estate. What reads
from up there is silhouette, light, water and motion — the lit path threading the gorge,
lantern clusters, falls catching light, fireworks bursting at or below eye level. Ground
detail is invisible from a pad. The floor gets richness only where players actually stand.

**Destinations are vantages, not attractions.** Nobody needs a mechanic at a destination,
because the game is playable from anywhere. What is being sold is the quality of the place
you happen to be standing while you play and talk. That produces an exclusivity gradient:

| tier | example | access |
| --- | --- | --- |
| public, busy | the Square | free, and where you spawn |
| public, intimate | the falls-pool dock | free, but you have to walk there |
| private, owned | a teahouse pad | bought |

## 2. The Square is the festival venue, not the canyon

Japanese villages have no European-style plaza; the functional equivalent is the shrine
precinct (*keidai*) — an open court before the worship hall where stalls, performances and
bon-odori happen, with the sacred grove (*chinju no mori*) around it and the approach
(*sandō*) lined with stalls on festival days.

**The Square takes that role.** It already has the bell, the karesansui, merchant row in
planning, and it is where players spawn. With 50 players to a server, a second hub would
split a small crowd across two half-empty places. Any yagura, any festival, any event with
an audience belongs there.

**The canyon takes the opposite register: intimate vantages for two to four people.** This
also keeps destinations small, cheap and precious, which suits both the perf ceiling and
the "privately managed exclusive resort" brief.

## 3. The destination set — two, plus what already exists

Both sites already have bones. The programme is to *finish* them, not invent new ones.

**West end — falls, pool, dock.** `FallsLanding.Deck` at (−433, 245, −26) already looks
down on pool 1 from 33 studs up. Pool 2, 22 studs lower and three times the surface area,
is the ground-level destination. Detailed in §4.

**East end — the Overlook + Statistics room.** `RoshamboStage.Overlook` at (73, 110, 19) is
built (upper and lower decks, kōran railing, newel lanterns, barriers), looking downcanyon
over the cascade chain. The Statistics room goes into the hillside beneath it. This is the
strongest idea in the programme because it gives the meta-game a *place*: you walk out to
read the leaderboards and are paid in the best public view in the canyon. **Not designed
here — it gets its own spec.**

**The suspension bridge stays as-is.** Built, and already the best fireworks vantage.

**Mid-canyon `FallsClearing` stays reserved and empty** as future room.

## 4. The falls-pool dock

### Site

Pool 2 surfaces at **y = 188.7** and runs **x −371…−347 by z −29…15** — 24 studs across,
44 long, its long axis north–south across the canyon. It sits below and clear of the
60-stud hero falls, so it is not in the spray.

The dock projects from the **north-east shore**, running **WSW toward the `TopToOutfall`
falls** — the 21-stud cascade from pool 1 (y 208 → 187) whose mist emitter sits at
(−367, 190, −4). From the NE corner that fall is ~30 studs away and dead ahead: close
enough to hear, far enough to read as a shape. You walk out along the dock *toward* it
rather than arriving and turning.

From a pad above, the composition is a long dark pool with one warm point of light at its
north end and white water beside it — legible at distance, which is what the pad view needs.

### Structure

A smaller sibling of `SwitchbackDeck`, following recipe §2
(`docs/superpowers/references/zendojo-canyon-build-recipes.md`):

| element | spec |
| --- | --- |
| Slab | **6 wide × 8 long**, `WoodPlanks`, 0.6 thick, Earth orange `{0.42, 0.31, 0.20}` |
| Deck height | ~1.5 studs above the water surface (top ≈ y 190.2) |
| Posts | `Wood` 1.125 square, **outer faces flush with the slab edges**, feet surveyed to the pool bed |
| Girders | `Wood` 1.2 × 0.825 — two long edges plus one cross, tops at the slab underside |
| Railing | **none** |

No railing is a deliberate departure from §2, which puts kōran on open-air edges. Those are
*drop* edges; this is a 1.5-stud step into shallow water. Railings would also clutter the
silhouette from above, which is the view being composed for.

Outer faces flush with the slab edge is the standing rule for every canyon build.

### The lantern

**One block-style result-lantern at the water end**, per recipe §2: `Neon` body, warm
`0.635/0.49/0.28`, dark `palette.ink` cap, warm `PointLight` (1.0/0.76/0.46, brightness
0.68, range 9).

It **is** a round display. Its name must end in `Lantern` and it must live under
`Workspace.RoshamboStage`, so `LanternController` finds it and paints the four-face result
SurfaceGui. That is why it is the block hanji form and not a round paper chōchin: a
cylinder cannot carry a four-sided display cleanly.

This makes the dock somewhere you can stand *through* a round and see the result, rather
than scenery you visit between them. It is also the socket the fireflies will later circle.

### Placement

Exact position and bearing are **baked from an in-Studio marker the user places**, per the
recipe's standing workflow ("Rojo serve is one-way; read their move, bake it"). The survey
above fixes the site; the marker fixes the seat.

### Build form

A pure, Lune-tested builder emitting a genmodel through Rojo, like `SwitchbackDeck` — so
the dock is committed to git, unlike most canyon content, which is place-only.

## 5. Out of scope

Fireflies (the lantern is only the socket). A deck or dock at pool 1. Enlarging any pool.
The path connection down to the dock. Everything at the Overlook end, including the
Statistics room. Ground cover and the bare waterline, which remain open from the foliage
spec. Performance reduction — the standing decision is to build what we want and cut later.
