---
shelf: program
status: open
updated: 2026-08-25
---

# Friends & Family Baseline

The governing program since 2026-07-30: eight ordered items bringing every system/area to
a showable bare minimum for a family-and-friends audience — NOT an official demo. Each
item gets its own brainstorm → spec → plan. Spec:
`docs/superpowers/specs/2026-07-30-friends-family-baseline-design.md`.

**The bar:** kid-first, phones/tablets (touch-first, chunky targets); owner present and
guiding, but a harsh-critic serious-gamer daughter views soon — polish-where-visible >
tutorialization. **Roblox only.** Never require deft avatar control (the stock mobile
joystick is bad and not ours to fix). Roshambo is an **ambient game** (~1 throw/min,
rounds skippable, no penalty) — hangout is the product.

## Board

1. **Foliage finish** — closed 2026-08-05 (arrangements sweep `82313a4`, as-built
   `a294e59`/`687ccab`/`5357c2b`, text manifest `6473252`, pad keep-out fix
   `2b07380`/`4a82491`).
2. **HUD minimal+maximal + onboarding bones** — closed (HUD half) 2026-08-05; onboarding
   half deferred to [[backlog]] and carries a layout defect in [[parked-defects]].
3. **Fireworks core** — closed 2026-08-13: loop verified in-game end to end (owner bought
   shells, consumed them at the Overlook, `ishibana` available/unavailable at the right
   moments); the fireworks shop owner-gated the same day (fixes `322d948`, `22bcf2e`).
4. **Merchant row** — closed 2026-08-17: every shell built and gated (Stats front, apparel,
   花火屋, accessories, and the riverside chaya + its dock — [[chaya]]).
   [[item-4-merchant-row]].
5. **Shoji** — closed 2026-08-18: hold-to-slide (grab-slide, not the prompt-cycle
   fallback), N−1-bay travel, owner-persists/visitor-does-not. Both owner gates passed
   the same day — channel geometry ("sills on L teahouse look fine", place saved) and
   the play loop ("looks good"). The swappable loadout slot was found already wired
   end to end (placeholder art only); see [[teahouses]].
6. **Rewards & flex** — open, MOBILE HALF BUILT 2026-08-18. Milestones, the 15-grade ladder and
   the familiar all ship ([[familiars]]); the round-result legibility defect that prompted it is
   fixed. **Cannot close on this alone**: the static half — nobori, crest on the noren, scrolls in
   the alcove — is unbuilt, and it is the piece that gives a visitor a reason to enter someone
   else's teahouse. Also thin: plumage is band colour only, and the progression is invisible to
   the player who earned it. Carries the parked economy-API defects (a)–(c) in [[parked-defects]].
   Any badge that claims SKILL depends on (h) being ACTIVE, not merely fixed; volume badges do
   not — which is exactly why grade is built on milestones rather than on a rate.
   **2026-08-25: the worn sashimono is DROPPED** — owner: *"a bit on the nose for an
   experience meant to be social as much as anything else."* The objection is the martial
   framing, not the size, so shrinking it was never the fix. Grade therefore still has
   nowhere to live: not on the bird (too small), not worn. A HUD treatment beside or above
   the avatar is the owner's next proposal and is unbuilt.
   **2026-08-22: the familiar flies, folds, sings and looks around** — two-part skinned mesh,
   three-phase flight with non-beeline paths, a snap-and-hold idle with check moves, and a
   weight-shift victory hop. Wired into play and owner-gated ("looking good enough for now").
   ⚠ Grade bands are SET ASIDE, not solved — a 7-inch bird cannot carry status at arena
   distance, and the owner's answer is a larger bird (raven/crow) rather than a colour scheme.
   That leaves item 6's REWARD half unproven even though its display half now works.
   **2026-08-20: the familiar is now a real bird.** A skinned, textured, rigged uguisu is in the
   place and verified — owner: *"it looks right, and it looks good"* ([[familiars]]). NOT yet
   wired: `BirdController` still builds four parts, so nothing in play uses it. Three changes
   stand between the asset and the game — clone the MeshPart instead of building parts, drive
   `bill_lower`/`wing_R`/`wing_L` from `BirdFlight.wingAngle`, and replace `BAND_COLOR` (a
   textured MeshPart does not tint via `p.Color`), which is a DESIGN decision and not a port.
7. **Statistics** — closed 2026-08-18 ("let's close Item 7 for now; we'll revisit in the
   future with clearer thoughts"). The 番付 room is built, measured and saved: READ / YIELD /
   NERVE from rows the server already wrote, qualification at 360 throws over a rolling week,
   and the south wall inverted to lead with LIVE pots and runs rather than a ranking that is
   empty almost always ([[stats-room]]). Spec
   `docs/superpowers/specs/2026-08-18-player-measurement-design.md`, plan
   `docs/superpowers/plans/2026-08-18-player-measurement.md`.
   **Closed with loose ends, all on [[backlog]], none blocking:**
   - ⚠ **The standings board still ranks on points-per-throw behind a floor derived for win
     rate.** Raised 2026-08-18 by the owner ("~356 throws... not simply READ?") and never
     settled — the conversation moved to the form inversion instead. At 360 throws yield
     discriminates a +5-point player at 71–82% against READ's 90%, and twenty *identical* blind
     players over 360 throws produce a winner earning 2.5× the median by chance alone. **This is
     the first thing to pick up on revisit.**
   - The READ column ships blank in every environment: gate 1 (TEST_MODE off) is closed.
   - Spec §6.2's printed 番付 sheet and the top-three avatar plinths remain deferred; the
     rotating avatar display has a home (the cavern's freed north-east wall) and no assets.
   - The ticker-vs-flapper question for the remaining wall boards (owner: "probably") is
     undecided.
   - A records display (lifetime / month / week / day / hour) is captured, and the room has no
     free wall left to put one on.
8. **World finish/hygiene** — open: perch teahouse at the stair summit, access/portal art
   pass, clear `DayNightStartT`/`DayNightLockT`, materials cleanup (duplicate
   MaterialVariant names), run `verifyWorkspaceConvention`, save/publish.

Interloper item 2.5 (A13 performance) — closed 2026-08-05: the Samsung A13 runs the place
at graphics quality 5 and on Automatic. Root cause was a perf bench left enabled in the
published place, not the world; bench v2 also discharged fireworks Task 1's device gate
(10 shells/sec usable on the A13). The global concurrent-shell director for a 50-player
battle remains untested.

## Out of scope

PWA (showable as-is; parked idea in [[backlog]]: a working throw-drum replica), Android
perf floor, full store economy, guest passes / teahouse floors, bridge sway, Water Striker
nits (owner: "I would put it into production today").

## Gates & decisions

- 2026-08-05 owner gate: items 1 and 2 closed. Onboarding deferral verbatim: *"I'm happy
  to close out HUD for now, though I want it noted that onboarding needs work. It's just
  not needed for the friends/family demo."*
- 2026-08-02/05 owner ruling (mid-item-2): the blocking RISK/BANK gate was withdrawn —
  "RISK IT" is wager language on a mechanic that is deliberately not a wager, and Roblox
  proscribes simulated gambling in a kid-first experience. Replaced by pot indicator +
  BANK THESE. This ruling governs copy anywhere near points.
- 2026-08-13 owner gate: the fireworks shop (hanabiya) done for now, place saved. Two
  DROPS, do not re-raise: the terrain cut behind the shop, and the ishigaki that would
  have dressed its exposed face.

## Raw layer

- spec: `docs/superpowers/specs/2026-07-30-friends-family-baseline-design.md`
- item ledgers: `.superpowers/sdd/2026-07-30-foliage-finish/`,
  `.superpowers/sdd/2026-08-02-play-hud/` (+ revision/round-two/three/four),
  `.superpowers/sdd/2026-08-05-fireworks-core/`, `.superpowers/sdd/2026-08-05-hanabiya-shop/`,
  `.superpowers/sdd/2026-08-18-shoji-screens/`
- the round restructure that shipped alongside item 2:
  `docs/superpowers/specs/2026-08-04-round-structure-design.md` (`830d2b8..00bf8f8`)
