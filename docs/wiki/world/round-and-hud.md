---
shelf: world
updated: 2026-08-15
---

# Round & HUD

The round's timing model and the Roblox play HUD, as shipped for F&F items 2 and the
round restructure (2026-08-02..05, owner Studio-gated). Server truth lives in
`server/src/engine/RoundEngine.ts`; HUD rules live in pure `src/shared` modules
(`HudModel`, `HudLayout`, `RingTimer`, `HudPrefs`, `LedgerModel`, `RevealBeat`,
`RollingNumber`, `ReelStep`, `DrumStep`) driven by `HudController` /
`LedgerController` / `SplashController` and `main.client.luau`.

## The round: OPEN 51 / LOCK 2 / REVEAL 7

A 60 s round (`830d2b8..00bf8f8`), env-driven via `ROUND_OPEN_SECONDS` /
`ROUND_LOCK_SECONDS` / `ROUND_REVEAL_SECONDS` (defaults verified in
`server/src/index.ts:59`). The old phase names were **offset by one** from the
events (ACTIVE ended with 2 s of lockout; nothing was ever tallied in TALLY; the
drum's 3.45 s settle never fit inside a 3 s REVEAL) — that diagnosis is the part not
to re-derive. REVEAL's 7 is derived (3.45 settle + 3.0 glyph + 0.4 fade) and does
not scale with round length; lengthen a round by lengthening OPEN only. The
asymmetry that makes LOCK work: the HTTP API accepts throws during OPEN *and* LOCK;
Roblox `submitPick` accepts during OPEN only — reversing either strands buffered
picks or lets players throw late. Owner gate 2026-08-05: a pick at ~1 s counts; the
cam still sells the mechanism at 1 rpm — no re-gearing, do not revisit. The
offset-by-one record, the deploy-lockstep hazard and the accepted
world-throw-after-strike residual are catalogued on [[parked-defects]] (g).

## THE RULE: the drum is authoritative

Owner, verbatim: *"IN EXPERIENCE, THE DRUM IS AUTHORITATIVE, AND SHOULD ALWAYS BE
FULLY AT REST BEFORE THE WORLD THROW IS REFLECTED ANYWHERE ELSE."* The gap between a
round closing and the drum resting is not latency to optimise. `maybeShowReveal` in
`main.client.luau` is the ONE drum-rest gate; the recurring defect is a new display
wired past it (the result splash, the ring glyph, and the points/streak plate have
each done it — a raised streak names the World Throw exactly). Behind the gate: tape
tile + badge, ring glyph, result splash, onboarding WIN beat, `lastRound`, and the
plate/pot/streak via a `shownWallet` copy refreshed only at the gate. Deliberately
not behind it: the ledger panel. Sub-rules: hold only the reveal's own
`ProfileUpdate` (`source == "local"`); release immediately if it arrives after the
rest; release outside the `pendingReveal` block (spectators get no reveal). A timer
protecting a choreography must be derived from that choreography — the old
`REVEAL_SAFETY = 3` beat the drum on every instrumented round.

**The reveal beat outlives the round boundary** (the owner's own proposal): rest →
glyph + splash → hold → fade → tape tile, running over the start of the next round;
the only ceiling is the next reveal. Do not try to make the ceremony fit inside
REVEAL — three separate attempts did, all fighting the fact that the drum has never
finished inside its own phase.

## The HUD

Bottom-right cluster (`EDGE_BOTTOM` 6 is already the floor); phone stack 128 px. The
**ring** is the round clock and the ledger's door: a gradient-pie built from circular
Frames + `UIGradient.Transparency` hard-stepped at 0.4999/0.5 (two keypoints, never
one), `Rotation = arcStart + 180`, opaque centre disc, load-bearing ZIndex order,
`MIN_SWEEP_DEGREES` 6. Throw interaction: one tap chooses; tapping another glyph
raises `UNDO?` (2 s fuse) — answering it *clears* the choice (it never switches);
the pick goes on the wire once at the lockout, and `throwsEnabledFor` carries
`and not inputs.sent`. `undoPill` must stay `Active = false` — the tap that answers
the prompt is delivered to the button underneath. The **payoff count**
(`RollingNumber`): duration scales logarithmically (0.4→2.5 s), smoothstep easing,
counters repaint on `RenderStepped` (a 10 Hz heartbeat renders a long count as
lurches); the driver checks `countersAnimating()` before painting; celebrations key
on the balance RISING; seed counters on the profile arriving, never first render.
Splash timing triggers on the drum's residual angle (`DrumStep.glideResidual`,
half a facet) — not a time constant. The glyph reel is `ReelStep.luau`.

## Gates & decisions

- **RISK/BANK copy ruling (owner, item 2 round one — governs all copy near
  points):** "RISK IT" is wager language on a mechanic that is deliberately not a
  wager (a player may collect or keep playing, never stake what they own), and
  Roblox proscribes simulated gambling in a kid-first experience. The blocking
  RISK/BANK gate was withdrawn even though three tasks had shipped it green;
  replaced by a pot indicator + BANK THESE, with riding expressed by throwing again.
- Owner gate 2026-08-05 on the HUD: closed ("I'm happy to close out HUD for now…"),
  onboarding content deferred — that thread and its layout defect live on
  [[backlog]] and [[parked-defects]] (d); the synthetic plate-click ledger question
  is [[parked-defects]] (f).
- Standing check for any client-file dispatch: no gate can see the Roblox UI —
  reconcile every `HudLayout.X` read against real exports; 970 green tests say
  nothing about rendering.

## Raw layer

- specs: `2026-08-04-round-structure-design.md`, the four play-HUD specs
  (2026-08-02..04); ledgers under `.superpowers/sdd/`
- key commits: `830d2b8..00bf8f8` round restructure · `1964b73..9a18224` HUD round
  three · env defaults `server/src/index.ts:59`
