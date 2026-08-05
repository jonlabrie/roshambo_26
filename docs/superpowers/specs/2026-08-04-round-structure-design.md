# Round structure — design

**Date:** 2026-08-04
**Supersedes** `2026-08-04-reveal-beat-design.md`, which tried to fit a reveal sequence inside a
phase that was never sized for it.
**Status:** design of record for the round's timing model, across all three codebases.

---

## §0 What is actually wrong

Not a bug. The phase names and the events are offset by one, and every timing problem in the arena
has been a consequence.

| the phase says | what actually happens |
| --- | --- |
| `ACTIVE` (20s) | 18s of throwing, then 2s in which players are locked out and game servers flush. The world throw is chosen at its **end**. |
| `TALLY` (2s) | Nothing is tallied. Throws are rejected (`409 PICKS_CLOSED`). The answer is already decided and already on every client. Its only real job is giving async settlement a head start before the PWA's one-shot reveal push. |
| `REVEAL` (3s, briefly 5s) | `revealStarted` carries only a round id. The bell is struck at its start, and the drum takes 3.45s to settle — so the reveal finishes **after** the phase, on top of the next round. |

Three specific findings behind that table:

**The tally is instantaneous.** `countThrows()` is a synchronous loop over an in-memory Map and
`pickWorldThrow` is synchronous; both run inside the same `tick()` before the phase field is even
reassigned. There is no work to wait for. The world throw exists in microseconds.

**The submission window already exists — inside ACTIVE.** `RoundCoordinator` sets
`_lockoutAtMs = phaseEndsAt - 2000`. Players stop being able to change their throw at T−2s, the
game server flushes, and the API still accepts because the phase is nominally `ACTIVE`. That is a
real, load-bearing phase wearing the name "lockout".

**The jitter is in settlement, not in scheduling.** `phaseEndsAt` is stamped at the transition
(`nowMs() + duration * 1000`) and broadcast with `serverTime` in every `/state`; the coordinator
runs a min-RTT clock sync over it. What varies is `settleRound` — async Mongo writes — which gates
result *availability* (`404 RESULT_NOT_READY`). The schedule is deterministic; only the durability
is not. The code already knows this: the lockout and the bell strike are both **scheduled from the
synced clock**, precisely because they could not tolerate jitter.

---

## §1 The structure

Three phases, named for what happens in them. Total **27s** — unchanged.

### `OPEN` — 18s
Throws accepted and changeable. This is the round as a player experiences it.

### `LOCK` — 2s
Player input closed. Game servers flush their buffers; **the API still accepts submissions.** This
is today's lockout, promoted from a client-side convention to a phase the server knows about.

**The world throw is decided at the end of LOCK**, synchronously, exactly as it is decided at the
end of ACTIVE today.

Consequence for the API: `submitThrow` accepts during `OPEN` **and** `LOCK`, and rejects only in
`REVEAL`. The `/throws` route's `phase !== 'ACTIVE'` check becomes a `phase === 'REVEAL'` check.

### `REVEAL` — 7s
The ceremony, beginning at the instant the answer exists. Every offset below is measured from
REVEAL's first instant, which is also round close and the bell.

| t | |
| --- | --- |
| 0.00 | **bell strikes** — the bell *is* the round closing |
| 0.45 | contact; the drum spins |
| 1.45 | the drum must have the world throw to choose its landing |
| 3.45 | **drum at rest** → the glyph appears in the ring; result toasts appear |
| 6.45 | the glyph fades |
| 6.85 | the tape tile lands; the ring returns to being a clock |
| 7.00 | `OPEN` |

7 seconds is derived, not chosen: 3.45 settle + 3.0 glyph + 0.4 fade = 6.85.

**THE RULE stands unchanged.** The drum is authoritative; nothing reflects the world throw
anywhere — glyph, toast, tape, board, lantern — before the drum is fully at rest.

### `TALLY` is deleted

Its settlement role is already implemented correctly elsewhere. `socketAdapter` carries a
`revealPending` guard so that whichever of settlement-completing and reveal-firing lands *last*
performs the emit. That mechanism works whether the gap is two seconds or zero, which is the proof
that the two seconds were never load-bearing.

So the PWA's reveal broadcast fires **when settlement completes**, not on a phase transition. In
practice that is a few milliseconds after round close.

---

## §2 Transport: push the throw, pull the rest

Milliseconds matter once the bell has rung — the drum needs the world throw within 1.45s of it.
Today the Roblox server discovers results by polling every 1–1.25s, which is a coin flip against
that deadline.

**Three payloads with genuinely different needs:**

| what | when needed | how |
| --- | --- | --- |
| the world throw | bell + 1.45s | **push**, with a deadline-triggered fetch as backstop |
| per-player results | drum rest, 3.45s | REST pull, unchanged — DB-gated anyway, and too large for a push channel |
| clock, schedule, round id, tape | continuously | slow background poll of `/state`, unchanged in kind |

### The push

A Roblox game server cannot be connected to — `HttpService` is outbound-only and there is no
WebSocket client. The push path is **Open Cloud MessagingService**: the AWS server POSTs to
`apis.roblox.com/messaging-service/v1/universes/{universeId}/topics/{topic}`, and every game server
subscribed via `MessagingService:SubscribeAsync` receives it.

Payload is small by design — round id, round count, the world throw, and the round-close instant.
It is published from the `roundClosed` handler **before and independently of** `settleRound`,
because the world throw is decided synchronously and has no database dependency. Nothing the drum
needs waits on Mongo.

**Delivery is best-effort.** MessagingService offers no delivery or latency guarantee and is
rate-limited per universe. So the push is a *fast path*, never the only path.

### The backstop is a deadline, not a poll

Because the bell is scheduled locally from the synced clock, the game server knows in advance the
exact instant it needs the throw. So the fallback is **one request at the moment it matters** — if
the push has not arrived by the drum's commit deadline, ask — rather than a request every second on
the chance something changed.

The coordinator's existing `_resultLogged` / `_fetchRevealIfDue` guards already make whichever
arrives second a no-op.

### What the poll keeps doing

`/state` is doing double duty and the second job must survive: it is the **clock-sync sample
source**.

```lua
d.clock:addSample(state.serverTime, res.rttMs, res.localReceiveMs)
```

Everything in this design — the locally scheduled bell, the commit deadline, the lockout — depends
on that clock being good. So the background poll stays. It stops being the reveal's transport and
goes back to clock discipline, round id, phase, durations and tape, at a slower cadence.

---

## §3 The HUD stops learning the round from the poll

Phase changes currently reach players through poll discovery, which is why a fresh countdown reads
18 instead of 20: up to 1.25s of poll plus RTT plus the hop to clients.

The Roblox server already holds `phaseEndsAt`, `durations` and a synced clock — the three things
needed to *schedule* phase changes rather than discover them. `RoundUpdate` should be fired from
that schedule.

This is independent of §1 and §2 and worth doing regardless of them.

---

## §4 Staging

One design, four stages. Each leaves the game working.

1. **Schedule the HUD from the clock** (§3). Self-contained, no wire changes, immediately visible.
2. **Push the world throw** (§2). Additive — the poll remains the primary until the push is
   trusted, then becomes the backstop.
3. **Restructure the phases** (§1). The breaking change: `phase` is a wire field consumed by the
   Roblox coordinator, the PWA, `Choreo.phaseCues`, and the API's throw gating. Server and both
   clients move together.
4. **Rebuild the ceremony** on the 7-second REVEAL. This is what the previous round attempted
   without the room to do it.

---

## §5 Risks

- **The phase rename is a wire-format change across three codebases.** `phase` is consumed by
  `submitThrow`'s gate, `/throws`'s 409, `_fetchRevealIfDue`, `Choreo.phaseCues` and the PWA. A
  mismatch fails silently as a phase nobody recognises.
- **`LOCK` changes throw-acceptance semantics** from "accept in ACTIVE" to "accept in OPEN and
  LOCK". Getting that backwards closes throws two seconds early for every player.
- **MessagingService is best-effort and quota-limited.** If the push is treated as reliable, a
  dropped message becomes a stalled drum. The deadline fetch is what makes that a latency problem
  rather than a wrong-face problem.
- **The stall must stay a safety net, not a budget.** `DrumController` falls back to
  `lastLandedThrow or "R"` if the throw never arrives — landing the drum on the **wrong face**. Any
  design that routinely relies on the stall has already failed.
- **The PWA's reveal moves** from a fixed phase transition to settlement completion. Its own
  pacing needs checking; it has no drum, so it has nothing to wait for, but it may have been tuned
  to the old beat.
- **Round length is unchanged at 27s but its shape changes** — 18s of play instead of 20s nominal
  (in practice unchanged, since the last 2s were already locked), and a 7s reveal instead of 5.
