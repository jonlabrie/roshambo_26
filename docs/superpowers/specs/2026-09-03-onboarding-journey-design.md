# The Onboarding Journey — design

**Date:** 2026-09-03
**Status:** approved in brainstorm (owner + Claude); copy explicitly still to be
workshopped (see §3 note)
**Driver:** a friends & family demo this week, mixed format — some guests join
cold with nobody narrating. The journey must carry a first-timer alone; the
owner's live narration is a bonus, not a dependency.
**Owner's brief (backlog, verbatim intent):** answer *what is this place? How
does it work? What can I do? What makes it special?* — kid-legible throughout,
no gambling vocabulary, "so smooth that even an 8-year old can do it."

## 1. Shape of the journey

The existing beat machinery survives: event-fired cards, each teaching the
moment it appears in, never queued ahead (`OnboardingBeats.luau` +
`OnboardingController.client.luau`, `seenBeats` persisted via `OnboardShown`
acks). It grows from 4 beats to 8 and gains a **guided tour** with a
**beam waypoint**: after a guest banks their first points, a single beam marks
the one next stop, and the journey walks them

> arena → play → first bank → **hanabiya** (buy a firecracker, 1 pt) →
> **riverside launch** (fire it) → **model teahouse** (the close: "this can be
> yours").

Design rulings folded in:

- **Mixed demo ⇒ design for the cold join.**
- **Days, not weeks ⇒ extend what exists**; no new subsystems beyond the beam
  controller and one pure module.
- **The tour is earned by banking** — a guest who never wins stays on beats
  1–2 and never gets dragged away from the game; narration covers the unlucky.
- **Waypoint = classic beam marker** (owner's pick over chōchin beacon / lit
  path): unmissable beats beautiful for a demo week.
- **Model home = the first step, not the dream**: a stock S teahouse — exactly
  what the starter bundle (§5) buys. Aspiration a kid can hold.
- **Economy check (verified in code):** the firecracker costs 1 point and
  needs no mortar (`server/src/fireworks.ts` — priced deliberately at "about
  one banked win"), so the arc has no gear wall and no grind.

## 2. The beat chain

| # | id | Fires on | Draft copy | Points at |
|---|----|----------|------------|-----------|
| 1 | `welcome` | join | three tap-through pages, §3 | screen (pages) |
| 2 | `throw` | throwsUnlocked | "Pick your throw — tap one." | throw row |
| 3 | `win` | first win | "You won! Every win triples your pile — or BANK THESE keeps it forever." | pot indicator |
| 4 | `bank` | first bank | "Yours forever! Tap the clock to see your points. Tap again for everything." | clock ring |
| 5 | `shopDoor` | bank card dismissed | "Points buy fireworks. Follow the light!" | beam → hanabiya |
| 6 | `launchDoor` | first shell bought | "A firecracker! Follow the light to the river." | beam → launch site |
| 7 | `modelDoor` | first launch | "Beautiful. One more stop — follow the light." | beam → model pad |
| 8 | `modelHome` | arrival at model pad | "A teahouse of your very own — 20 points. Every win gets you closer." | the model itself |

- Two beats never share one event; the tour starts on **dismissal of the bank
  card** (a new event fired by OnboardingController itself) — the moment the
  guest stands there holding spendable points. The no-queue principle
  survives.
- Beat 3's "pile" is the pot replacement — concrete, countable, no casino
  smell. The 2026-08-02/05 no-wager-language ruling governs every string here.
- The movement-beat prohibition stands amended: the original rule ("no beat
  points at the thumbstick") was about de-emphasising movement *during play*.
  The tour beats direct travel between stops, which is the point of a tour;
  none of them teach the thumbstick itself.

## 3. The welcome sequence (beat 1)

One card cannot carry the core-context dump the owner wants at join, so beat 1
is **three short tap-through pages**, shown once; `seenBeats` marks `welcome`
after the last page. This is the one deliberate exception to "never read
ahead" — owner-ruled: the context matters more.

Draft pages (copy workshop pending — the owner explicitly wants to work these,
**especially join**; content each page must carry is fixed, wording is not):

1. *"This is Roshambo — Rock, Paper, Scissors, but you're playing against the
   whole world at once."* — the new kind of RPS.
2. *"Every minute the big drum throws what most of the world picked. Beat it
   and your pile grows — every win in a row triples it. Read the crowd."* —
   the world-throw's source, streaks, tripling.
3. *"Bank your points and they're yours — for fireworks, and one day a
   teahouse of your own. The drum's about to throw."* — points → status and
   spending; hands back to the game.

## 4. The tour machinery

- **`TourGuide.luau`** (new, `src/shared`, pure, Lune-tested): derives the
  tour step `NONE → SHOP → LAUNCH → MODEL → DONE` and the beam's target name
  from the persisted `seenBeats` list. Because it derives from state that
  already round-trips, **the tour survives a rejoin for free** — a guest who
  quits mid-tour returns with the beam over the right stop; no new
  persistence.
- **`TourBeamController.client.luau`** (new client file): renders the single
  beam — a tall client-only Neon column over the current target — resolves
  targets by CollectionService tag, fades within ~30 studs, and fires the
  arrival event. **Not in HudController**: that file sits at the 200-register
  ceiling; a new file keeps clear, and `tests/Compiles.spec.luau` guards it
  automatically.
- **Tags (hand-tagged in Studio, place-only):** `TourStop_Shop` on the
  hanabiya, `TourStop_Launch` on the owner's chosen riverside
  `FireworkLaunchSite`, `TourStop_Model` on the model pad's site.
- **New events** on the onboarding channel, wired in `main.client.luau`:
  `bankCardDismissed` (OnboardingController), `shellBought` (purchase echo),
  **amended after the owner's cold walk (2026-09-03): the inventory-edge fires are
  gated on the tour's current step** — a rising shell count only fires `shellBought`
  at step SHOP, a falling one only fires `shellLaunched` at step LAUNCH — because
  every WIN grants a firecracker server-side (Settlement.ts's grant pathway), and the
  first win's drop otherwise spoofs a purchase and jumps the tour past the win/bank
  beats (exactly what the walk found),
  `shellLaunched` (launch confirm), `tourArrival` (beam controller).
- Old hands and finished guests never see the beam: it exists only while a
  tour step is open.

## 5. The starter bundle

Today a first home costs 80 points (deck S 50 + teahouse S 30) — hours of
play. Owner ruling: the beginner's deck and teahouse should cost **an hour's
play**, and banking runs ~1 point per 3 minutes (per the shell-ledger comment),
so:

- **`starter` SKU, 20 points**, in `server/src/economy.ts` `PRICES` +
  `validatePurchase`/apply: valid **only when `maxDeckSize === null`** (first
  property ever); grants deck S + teahouse S (default loadout) in one atomic
  spend. The S/M/L tier ladder is untouched for existing owners; upgrades
  price normally.
- **`EconomyController.client.luau`**: the non-owner vacant-site prompt swaps
  from "Buy S deck & claim — 50 pts" to the bundle ("Starter teahouse —
  20 pts"), keeping the existing shortfall label ("earn N more pts") — a
  first-timer's dead-end moves 60 points closer.
- The catalog echo carries the starter price; the client never hardcodes it.
- Beat 8's copy names the bundle price. The model S **is** what the bundle
  buys — the tour's close, the price, and the product are one thing.
- TDD on the server (Vitest): first-property-only, atomicity, ladder
  untouched, insufficient-points copy.

## 6. The model pad

- At server start, `main.server.luau` claims the `TourStop_Model` site in
  `PadRegistry` with a sentinel owner and materializes a **stock S teahouse
  loadout**; `SiteCoordinator` never assigns that site to a joining player.
- Visitors may slide its shoji — visitor slides are already live-only and
  reset at next materialize, so the model tidies itself.
- No world signage this week (YAGNI): beat 8's card carries the pitch.

## 7. The sky (demo ruling)

The journey's climax is a firework; the live place is locked at permanent noon
(`DayNightLockT = 1.19`). Owner ruling for the demo: **dusk lock** — dark
enough that the firecracker pops, light enough that the canyon, paths and
model teahouse still read; chōchin and yamadoro glow. Even clearing the lock
would only half-fix it (on the 10-minute cycle, half of first launches land in
daylight).

- Set `DayNightLockT = 0.40` before publish — the documented dusk test knob
  (`docs/wiki/world/day-night.md`: dawn 0.00–0.10, day 0.10–0.28, dusk
  0.28–0.53, night 0.53–1.00; 0.40 is the sanctioned dusk value, and the owner
  has already judged the falls "looks great at dusk" there).
- Amend `docs/wiki/world/place-state.md` publish-checklist item 1: the
  dusk/night-lock ban gains a demo exception, recorded as an owner ruling with
  this spec as the why. This also closes the ⚠ OPEN QUESTION logged there
  2026-09-03 — for the demo period; the post-demo default remains open.

## 8. Degradation & failure

- Missing tour tag → no beam, but the beat card still shows (guests can still
  be told where to go); a warn in the log.
- Failed model-site claim → warn; beat 8 anchors to the HUD like any card.
- Purchase failures reuse existing error copy (`INSUFFICIENT_POINTS` etc.).
- A guest who dismisses a tour card keeps the beam — the card is the words,
  the beam is the state, and only arrival advances it.

## 9. Testing

- **Lune:** `OnboardingBeats.spec` grows to cover pages, the 8-beat chain and
  the no-queue contract; new `TourGuide.spec` (step derivation, resume
  mid-tour, DONE end-state). `Compiles.spec` covers the new client files.
- **Vitest (server):** starter bundle validate/apply per §5.
- **House gates:** stylua, selene, `lune run tests/run`, `rojo build`.
- **The real gate:** owner's cold phone walk of the entire journey on the
  published place — join to model pad, portrait, nobody narrating.

## 10. Build order (the week)

1. Server starter bundle (TDD; push → dev backend deploys itself).
2. `OnboardingBeats` rewrite + `TourGuide` + specs.
3. `TourBeamController` + new event wiring.
4. Model-pad claim in `main.server.luau`.
5. Studio: tag the three stops; dusk `DayNightLockT`.
6. **Copy workshop with the owner** (especially the welcome pages).
7. Owner publish; cold phone walk; fix what the walk finds.

## Out of scope (named so they stay out)

- Status/leaderboard teaching beyond the welcome pages' one clause.
- World signage at the model pad.
- The lit-path wayfinding variant; chōchin beacon styling.
- Any change to the fireworks catalog, mortar ladder, or deck tier prices.
- Onboarding for the back-door editor, decorations, shoji variants, familiars.
- The post-demo day/night default (open question stays open).
