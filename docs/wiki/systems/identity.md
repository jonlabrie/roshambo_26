---
shelf: systems
updated: 2026-08-27
---

# Identity

How a player is identified across the PWA, Roblox and the REST surface, and the standing
rule that governs every handler on every transport.

## ⚠ THE STANDING RULE: identity comes from the CONNECTION, never from a payload

A message may say what to DO. It may never say WHO. Any handler that reads an account
identifier out of `data` is a bug, whatever else it validates.

**This is the rule the whole page exists for.** It was earned: until 2026-08-18 four socket
handlers resolved an account straight out of `data.deviceId` with no further check —
`sync-player` read it, `submit-throw` threw as it, `update-progress` renamed it, and `bank`
**cashed out its pot**. A deviceId is an identifier: it sits in localStorage, travels in
support screenshots and over shoulders. It was being used as a password, so anyone who
learned one string owned that account outright. The JWT path beside it was already correct,
and that asymmetry was the whole bug.

The same hole existed in REST: `/auth/register` and `/auth/sso` took a bare `deviceId` in
the form body, so a stolen one claimed whatever guest owned it.

**How to apply.** New handler on any transport: read identity off the socket/session, not
the message. If you are adding a field to a payload, the test is whether a stranger sending
that field gains anything. `socketAdapter.test.ts` has a guard test for exactly this — *"banks
the socket's own pot, whatever the payload asks for"* — and it is load-bearing: reinstating
the vulnerability fails three tests.

## As built

- **Guests** get a deviceId **minted by the server** on a `claim-device` event, returned as a
  signed device token (`{ typ: 'device', did }`, same secret as user JWTs). `typ` is checked so
  neither token can be replayed as the other.
- **The token rides the socket handshake** beside the user JWT; middleware sets
  `socket.deviceId` from it; handlers read that and nothing else. Closing it at the connection
  rather than per-handler is what makes it a **class fix** — a future handler cannot be handed
  an account name, because messages no longer carry one.
- `device-required` tells a socket with no device to claim one rather than failing silently.
- **Roblox** players carry `robloxId`; `resolveUser()` merges deviceId, JWT and robloxId, with
  authenticated user winning. See [[data]].
- **The PWA's localStorage holds two things**: `roshambo_device_token` (the credential) and
  `roshambo_device_id` (an identifier, written from what the server sends back, read only by
  the account-migration call).

⚠ **Projections are part of this surface.** A payload that leaks a credential is the same bug
one layer out — `LEADERBOARD_FIELDS` once carried `deviceId` to any socket that asked for
stats. `leaderboards.ts` now carries a second projection rather than a widened shared one, and
says why at the point of use. Add a projection; never widen a shared list.

## Owner ruling — HARD CUT, no migration (2026-08-18)

Guest points and streaks from before the change are **orphaned**. An existing deviceId cannot
be presented for adoption, because a stolen one would be adopted just as readily.
Claim-on-first-sight was offered and declined. See [[owner-rulings]].

**Verified live 2026-08-18**: claim, throw, win and bank confirmed against the demo's backend
by the owner after a hard reload, and by a socket probe that took a pot to 3 over two rounds.
The rollout crutch (a legacy `deviceId` payload sent while the client held no token) is
REMOVED — it existed only for the window where a new client could meet an old server.

## Raw layer

`server/src/identity.ts`, `server/src/transports/socketAdapter.ts` (handshake middleware and
the `claim-device` handler), `server/src/leaderboards.ts` (the projections),
`server/src/routes/auth.ts`. Tests: `server/src/transports/socketAdapter.test.ts`'s
*"identity comes from the CONNECTION, never from a payload"* block.
