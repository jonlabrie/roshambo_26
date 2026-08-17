---
shelf: program
status: open
updated: 2026-08-16
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
4. **Merchant row** — open, nearly done: the shells are built (Stats front, apparel, 花火屋,
   accessories); only the **riverside chaya (tea vendor)** remains. [[item-4-merchant-row]].
5. **Shoji** — open: open/half/close, ideally grab-slide (fallback prompt-cycled);
   swappable loadout SLOT ships now, better screens earned/bought later.
6. **Rewards & flex** — open: server-side milestone badges from existing per-player stats,
   awarded at settlement; flex via teahouse banner-pole flag + avatar ribbon/sash;
   earn-only. Carries the parked economy-API defects (a)–(c) in [[parked-defects]]. Any badge that claims
   SKILL depends on (h) being ACTIVE, not merely fixed; volume badges do not.
7. **Statistics** — open: personal → maximal HUD; global/social → the 番付 room, now BORED
   west of the apparel shop ([[stats-room]]); the old Overlook siting (73,110,19) is
   superseded. Walls and stats specced in
   `docs/superpowers/specs/2026-08-16-stats-room-design.md`. Defect (h) is FIXED (2026-08-16) — the
   World Throw now derives from the crowd — but is not active while both environments run
   TEST_MODE, so skill-derived stats still cannot be validated against real play. Promote this item if the daughter visit comes
   early.
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
  `.superpowers/sdd/2026-08-05-fireworks-core/`, `.superpowers/sdd/2026-08-05-hanabiya-shop/`
- the round restructure that shipped alongside item 2:
  `docs/superpowers/specs/2026-08-04-round-structure-design.md` (`830d2b8..00bf8f8`)
