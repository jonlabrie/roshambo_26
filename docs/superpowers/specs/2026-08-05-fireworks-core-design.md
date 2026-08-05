# Fireworks core — design

**Date:** 2026-08-05
**Item 3** of `2026-07-30-friends-family-baseline-design.md`.
**Status:** design of record for the fireworks feature across all three codebases.

Builds on the `roshambo-fireworks` research: the VFX are already proven on a Studio bench (rising
Trail comet → flash core → radial burst → glitter → willow droop), and the perf architecture was
settled in 2026-06. This spec turns that into a feature.

---

## §0 What this is, and what it is not

**Ships:** four shells, three mortar tubes, a real consumable inventory, purchase with points,
a grant on winning a round, launching from your own deck or a public site, and the director that
keeps a busy sky inside the mobile budget.

**Does not ship, by decision not omission:** Robux and premium tiers (the monetisation lens is
decided but is item 6's work), the shared-show SKU, fireworks combat, aiming, multi-day loyalty
grants, and a large shell catalog. Every one of those is a call site or a data row against the
shape below, not a redesign — that is the point of the shape.

**The governing constraint, from the monetisation decision:** fireworks are cosmetic and
consumable and **must never touch the RPS loop.** A shell may *read* the round's outcome (§3) and
must never influence it. That is what makes fireworks the lowest-risk first paid item; the moment
it stops being true, the whole monetisation rationale goes with it.

---

## §1 Three surfaces

**The AWS server owns the ledger** — which shells exist, what they cost, what you hold, and
whether you may launch one. It is authoritative for every number.

**The Roblox game server is the referee** — it validates where you are standing, spends the shell
against AWS, and only then broadcasts. A client never announces its own firework. This is
simultaneously the anti-cheat property and the perf rule: the server emits a tiny event and every
client renders locally.

**The Roblox client is the show** — a catalog of recipes and a director that decides what renders
now, what waits, and at what detail.

**One shell's journey:**

```
tap a shell in the picker
  → RequestFireworkLaunch(shellId)              client → Roblox server
  → validate site + POST /fireworks/spend       Roblox server → AWS  (authoritative decrement)
  → FireworkLaunched{shellId, origin, seed, by} Roblox server → ALL clients
  → director admits / staggers / drops          each client, locally
  → pooled emitters render the recipe
```

Nothing about particles crosses the network.

---

## §2 The catalog, and the contract between the halves

Following the split already used for decorations — `DecorationCatalog.luau`'s header says *"prices
live TS-side"* — each side owns what it is actually good at:

| | owns |
| --- | --- |
| `server/src/economy.ts` | shell ids, prices, tiers, requirements, grant rules |
| `roblox/src/shared/FireworkCatalog.luau` | how each id looks: emitters, curves, colours, timing |

They meet at one string. Adding a re-skinned shell is a Luau recipe plus a price line; adding a
tier or a grant source is server-only.

**`shared-fixtures/firework-shells.json` is the contract, and it holds the id list and nothing
else.** Not prices, not requirements — those are server policy and stay in `economy.ts`, because
the client is never told a requirement (§3) and never shown a price it did not receive. The
server's tests assert every id has a price; the Luau tests assert every id has a recipe. That turns "the shop sells a shell the client cannot draw" from an invisible blank
sky into a CI failure. It is the same gate that now covers the game rules in three places
(`game-rules.json`), and it exists because this repo has repeatedly shipped two copies of one fact
with nothing holding them together.

### The four shells

| id | requires | points | note |
| --- | --- | --- | --- |
| `firecracker` | nothing — hand-launched | 1 | the everyday shell; reachable in one banked win |
| `peony` | `mortar:S` | 3 | proven on the bench |
| `willow` | `mortar:M` | 4 | proven on the bench; the drooping break |
| `ishibana` | `afterWorldThrow: R` | 6 | 石花, "stone flower" — the Rock shell (§3) |

`ishibana` is the only new art. The names sit in the canyon's existing register (ishidoro,
ishigumi, tsukubai, shu-moku), and tying the Rock condition to a *stone* flower is the mechanic
saying itself.

### A recipe is a list of phases

A real firework is not two events. It is a **launch report** at the tube, an **ascent**, a
**burst**, and — for anything beyond the simplest shell — **sub-bursts**: the secondary breaks that
make a crossette a crossette. Each of those carries its own sound.

So a recipe is `{ phases: { Phase } }`, where a phase declares *when* it happens, *where* it
happens, what it looks like, and what it sounds like. The controller is a **phase player**: it
walks the list and schedules each entry. It knows nothing about any particular shell.

```
Phase = {
  at      : seconds from launch
  kind    : "report" | "ascent" | "burst"
  anchor  : "origin" | "apex"       -- the tube, or where the shell broke
  points  : how many break points (1 = a simple break; 6 = a nested one)
  scatter : how far those points spread from the anchor
  sound   : asset id, or none
  ...visual parameters
}
```

**This is the decision that sets the cost of shell #12.** With a fixed ascent-then-burst chain, a
multi-break shell is a controller rewrite. With a phase list it is a data row, which is what the
"many distinct shells matter financially" requirement actually demands.

The four launch shells use `report → ascent → burst` and nothing more. **Sub-bursts ship as a
capability, not as content** — the player executes them and a test proves it, so the first nested
shell is authored rather than engineered.

### THE PARTICLE BUDGET IS PER SHELL, NOT PER BURST

A nested shell with six break points must **divide** the measured budget across them, never
multiply it. Six points at the full near-budget is six times the fill-rate the mobile floor was
measured against, and it would be authored by someone reasonably assuming each break looks like a
normal break. The player divides; the recipe cannot opt out.

### The three tubes

Durable purchases, in `PRICES` beside decks and teahouses. Bigger tube, bigger shells.

| id | points |
| --- | --- |
| `mortar:S` | 40 |
| `mortar:M` | 250 |
| `mortar:L` | 1000 |

Deliberately below the deck ladder (50 / 500 / 3000): a tube is gear, not real estate, and it
should be the cheaper of the two aspirations.

---

## §3 Requirements: one evaluator, three kinds

A shell declares what it needs. The evaluator is one function, not three special cases, so a
fourth kind later is a branch rather than a redesign.

| kind | example | evaluated against |
| --- | --- | --- |
| `none` | `firecracker` | always true |
| `gear` | `peony` needs `mortar:S` | the player's owned tubes |
| `condition` | `ishibana` needs `afterWorldThrow: R` | the **last closed round's** world throw |

**The condition shells create a sixty-second window.** When a round closes on `R`, the round that
follows is the only one in which `ishibana` can fly. This makes the World Throw tape a *forecast*
as well as a record — a public, shared fact everyone can see coming, which is exactly the kind of
thing an ambient hangout game wants more of.

### THE CLIENT NEVER EVALUATES A REQUIREMENT

The server sends, per shell: `{ count, launchable, reason }`, where `reason` is a symbol like
`NEEDS_MORTAR_M` or `WAITING_FOR_R`. The client renders the reason and greys the tile. It does not
know what a mortar is, and it does not look at the tape.

This is stated as a rule because the alternative is the defect class this repo produced three
times in a single day (`revealMs`, `totalTime`, the ring's span): a fact authoritative on the
server, re-derived on the client, and silently stale. A requirement that depends on round history
is far more prone to it than a duration was. **Each fact lives on one side.**

### Gear is personal

Owning `mortar:M` lets *you* fire a willow. Public launch sites do **not** provide communal tubes:
the tube is the thing you bought.

*Consequence to accept deliberately:* a guest at the friends-and-family demo who owns nothing can
fire `firecracker`, and `ishibana` when the world throws Rock, but not the peony or the willow.
The owner, who has points, can. **If that reads as too thin at the demo, the one-line alternative
is to let public sites supply a tube up to `M`** — it preserves the sink (your own deck becomes
self-sufficient) at the cost of weakening the gear gate. Recorded here so the choice is made at a
gate rather than discovered on the night.

---

## §4 Acquisition and spending

**Acquisition is one pathway with many sources.** Every source resolves to *give player N of shell
X, from source S*. Two sources ship:

- `purchase` — through the **existing** `/purchase` route as `firework:peony`, exactly as
  decorations go through it as `decoration:ishidoro`, reusing `validatePurchase` / `applyPurchase`
  rather than growing a parallel path.
- `win` — settlement grants one `firecracker` on a WIN.

Later sources (multi-day streak, N rounds in a row, Robux packs, the shared-show SKU) are call
sites against the same grant, which is why it is a pathway and not a purchase feature.

**Spending is authoritative and separate.** `POST /players/:id/fireworks/spend` decrements and
returns the new count. The Roblox server calls it *before* broadcasting, so a shell that failed to
spend never appears in the sky.

**Inventory lives on the user:** `User.fireworks: Map<string, number>`. This is the first
**consumable** in an economy where every purchase so far — deck, teahouse, portal, decoration — has
been permanent, and it is the first thing that makes points a genuine sink rather than a ladder.

### The income reality, and why shells are priced at 1–6

`totalPoints` changes **only on bank** (`wallet.ts`, and `Settlement.ts:24` says so). Each round is
win / safe / loss at one in three; a win takes the pot 0→1 then ×3, a safe preserves the pot, a
loss forfeits it. Banking every win yields roughly **one point per three rounds — one point every
three minutes at a 60-second round.**

So a shell must cost about one banked win, or nobody fires one. The 50-point deck is already hours
of play; pricing shells like decorations (25–60) would put the entire feature out of reach. The
`win` grant matters for the same reason: a new player should see their own firework in their first
few minutes without buying anything.

**This spec does not rebalance the economy.** The income arithmetic is recorded because it
constrains the prices above, and because a 50-point entry rung deserves its own look — but that is
not this item's work.

---

## §5 Launching

**Sites are tagged parts.** `CollectionService` tag `FireworkLaunchSite`, matching the existing
convention (`AccessKeepOut`, `PortalControl`). A player's own deck is a site for that player; the
tagged parts are sites for everyone. Siting them in the canyon — the falls dock, the clearing edge,
the high mid-canyon bridge, which the world was *designed* around as viewing perches — is Studio
work against the built place, not something to bake into code.

**The affordance appears where it works.** Step onto a site and a fireworks button joins the HUD
cluster; step off and it goes. Tap it for a picker of four chunky tiles, each showing its count
and, when it cannot fly, the server's reason.

Location-triggered rather than always-present, for two reasons. It leaves the play HUD untouched
when you are not at a site — that cluster was tuned across six rounds of work and fireworks should
cost it nothing. And it is **self-teaching**: the button appearing as you walk onto the dock
answers "where do I launch?" without a word of copy, which matters more than usual now that
onboarding is explicitly deferred.

**The launch payload carries no aim direction.** Fireworks combat will need one, but a Roblox event
table takes a new key without breaking anything, so building it now would be speculation with no
payoff. The shape admits it; nothing pre-builds it.

---

## §6 The director

**Policy and instances are separate**, the way `DrumStep`, `ReelStep` and `RingTimer` are:

- `roblox/src/shared/FireworkDirector.luau` — pure. Given the active burst count and a distance,
  answers *render now / stagger by N ms / drop*, and *at what detail*. Testable under Lune.
- `roblox/src/client/FireworkController.client.luau` — the **phase player**: owns pooled emitters
  and pooled sounds, walks a recipe's phase list, and does what the director tells it. It knows
  nothing about any particular shell.

No harness in this repo loads a `.client.luau`, so this split is the only way any of the perf logic
gets a test at all.

**The rules, from the 2026-06 research:**

- **Client-side VFX only.** The server sends a tiny event; each client emits locally.
- **Concurrent budget of 12–16 bursts**, the rest staggered 100–300 ms. Visually indistinguishable
  from "all at once", and it decouples cost from player count — a full server firing together
  cannot exceed the budget.
- **Distance LOD** — far bursts get fewer particles, no sound.
- **No per-shell dynamic lights.** The single biggest killer. Glow is `LightEmission` plus one
  global Bloom.
- **Pooled emitters and pooled sounds.** Instance churn per shell means GC hitches, and a shell now
  makes up to four sounds (report, ascent, burst, sub-bursts) rather than one.
- **Particle counts bounded** — roughly 150–400 per shell, **divided across its burst phases**.
  Mobile is fill-rate bound.
- **Sound is distance-culled**, and a sub-burst volley plays ONE sound, not one per break point —
  six simultaneous voices of the same clip is noise and six times the mixer cost.

**Three lessons the bench already paid for, carried into the build:** `ParticleEmitter:Emit()` does
not replicate server→client; an emitter with an empty `Texture` renders nothing; and a launch must
be positioned relative to something real, not the world origin.

**The seed.** The server sends one per launch so every client renders the same variation of the
same shell. Without it, two people watching one firework see different shows and cannot talk about
what they saw.

---

## §7 Testing, and what cannot be tested

**Gated:**
- TS — requirement evaluation (all three kinds), purchase, spend, the grant pathway, and the
  win-grant at settlement.
- TS — every id in `firework-shells.json` has a price.
- Luau — the director's admit/stagger/drop policy and its LOD thresholds.
- Luau — every id in `firework-shells.json` has a recipe in `FireworkCatalog`.
- Luau — **the phase schedule**: a recipe compiles to an ordered list of timed events, sub-bursts
  included, and the particle budget divides across burst phases rather than multiplying.

**Not gated, and this must be said plainly:** the VFX themselves, the picker, the site affordance,
and every frame of the director's actual output. No harness loads a `.client.luau`. The Studio gate
is the only thing that sees any of it, and a green suite is not evidence about any of it.

---

## §8 Staging

Each stage leaves the game working.

1. **Measure the mobile floor.** Republish the bench (`roblox/tools/studio/buildFireworkBench.luau`)
   and run it on the low-end Android. *Before* any number in §6 is trusted.
2. **The ledger** — `User.fireworks`, the fixture, the requirement evaluator, purchase, spend, the
   grant pathway. Server only; testable end to end.
3. **The referee** — Roblox server: sites, validation, the spend call, the three remotes.
4. **The show** — catalog, director, controller. First thing anyone can look at.
5. **The picker** — HUD tiles, counts, greyed reasons.
6. **The loop** — win-grant, and the cue that `ishibana`'s window is open.

---

## §9 Risks

- **The mobile floor is unmeasured.** An iPhone 15 Pro handled ~2 shells/sec; the three-year-old
  Android has never been tried. Every number in §6 is provisional until stage 1, which is why
  stage 1 is first and not last.
- **`ishibana`'s window is narrow.** Sixty seconds, once every three rounds on average. If the cue
  is missed the shell feels broken rather than special — the HUD cue in stage 6 is doing real work,
  not decoration.
- **Consumables are new to this economy.** Every existing purchase is permanent and idempotent-ish;
  a decrement is not. **The parked purchase race at item 6 becomes materially worse here** — a
  read-modify-write on a *count* loses launches, not just points. Spend must be a conditional
  `findOneAndUpdate` with `$inc` from the start, not the `readEconomy → save()` pattern the
  existing purchase route uses.
- **Gear may make the demo thin** (§3). Decide at a gate.
- **The catalog is the financial engine.** The memory is explicit that many distinct shells matter
  to the game's economics. Four is the demo, not the target; if adding shell twelve is not cheap
  after this ships, the architecture failed regardless of how the demo went.

---

## §10 Out of scope, explicitly

Robux and premium tiers · the shared-show SKU · fireworks combat and aiming · multi-day and
round-streak grants · shell counts beyond four · rebalancing the points economy · the two parked
economy-API defects at item 6, except that §4's spend must not repeat the race.
