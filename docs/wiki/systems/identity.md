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

## ⚠ The two platforms are DIFFERENT PEOPLE to this server, and that is what splits the economy

Traced 2026-08-27. `resolveUser` returns on its first branch for a `robloxUserId`, before any
merge logic; `robloxId` is written in exactly one place in the whole server; nothing links it to
a `deviceId` or an auth account. So a Roblox player and a PWA player are always two documents,
and a Roblox-earned point cannot reach the PWA store because that store operates on a document
the Roblox player does not have. **The economy split is enforced HERE, not in the schema** —
`data.md` claimed per-platform wallet fields that do not exist ([[data]]).

⚠ **This is contingent, not structural.** It holds only because no linking flow exists, and
`/auth/sso` is already a linking route for four providers. Adding a fifth would collide with the
`unique, sparse` index on `robloxId` — see [[parked-defects]] (i) for the trap and the repair
that makes it worse.

## ⚠ THE WORLD THROW IS A VOTE, AND PWA IDENTITY IS FREE

Traced 2026-08-27, and it is the most consequential thing on this page.

**Both platforms feed ONE tally.** `socketAdapter` submits `pwa:<deviceId>`, `apiV1` submits
`roblox:<robloxUserId>`, into a single `Map` on `RoundEngine`; `countThrows()` iterates it
without regard to platform; `GameRules.deriveWorldThrow` takes the argmax of that. So a PWA
throw is a vote in the World Throw that every Roblox player is then scored against.

**And a PWA identity costs nothing.** `claim-device` mints a `randomUUID()` and upserts a durable
User document — unauthenticated, and until 2026-08-27 unlimited. ⚠ **It is NOT a device id:** no
hardware binding, no fingerprint, just `localStorage` plus a server-signed token. Clearing site
data mints another; so does a `socket.io-client` loop, with no browser involved at all.

⚠ **THE PLURALITY MATH INVERTS THE USUAL ASSUMPTION.** The World Throw is an argmax, not a
majority. With honest players splitting roughly evenly across R/P/S, a farm needs only about
**N/3** of the round to own the outcome — ~2 bots at the 5-participant floor, ~10 at thirty,
~300 at nine hundred. **The attack is cheapest when the population is smallest, which is
launch.** Sybil defence cannot be deferred until the game is big; big is when it gets harder.

**Not live, and the gate is why.** Both environments run `TEST_MODE`, so the World Throw is the
R→P→S cycle and the plurality rule has never run ([[world-throw]]). The exposure opens when
TEST_MODE goes off AND a PWA population exists. Owner, 2026-08-27: Roblox launches first and the
PWA is not enabled at launch, so this is a **gate on enabling the PWA**, not on launching.

**Done 2026-08-27:** a per-connection `CLAIM_LIMIT` of 3. ⚠ **That is a floor, not a defence** —
an attacker opens more sockets. It is there because each claim writes to Atlas unauthenticated
and its absence was indefensible, NOT because it solves anything.

**Designed and deliberately NOT built** (see [[parked-defects]] (j)): earned enfranchisement — an
identity throws, wins, banks and ranks immediately, but does not count toward the World Throw
until it has played across N rounds. ⚠ Its weakness, stated so nobody rests on it: a farm runs
identities in PARALLEL, so a cohort enfranchises together after one wait, not per identity. What
it actually buys is SHAPE — identities born together, throwing in lockstep, never idling, never
banking — which is the loudest possible pattern in `PlayerRound`. **Detection gates the vote;
the account need never be blocked.** Proof-of-work was considered and rejected: it taxes the
weakest device hardest, and this is a kid-first game gated on a Samsung A13.

## ⚠ Roblox OAuth is a named gate, and it has a hard external constraint

Raised by the owner 2026-08-27: lean on Roblox's identity, since their anti-bot, anti-sybil and
age-verification machinery is far beyond what this project could build. **The reasoning is
sound** — every measurement surface in [[stats-room]] is worthless against a sybil farm, and
identity is the only real defence.

⚠ **But Roblox's own OAuth docs state: "You must have a 13+ account to authorize OAuth 2.0
apps."** Roshambo is kid-first — it is why the gambling register is barred ([[owner-rulings]])
and why onboarding is measured against a child who has never played. **Requiring Roblox sign-in
would lock under-13s out of the PWA entirely.** Registering the app also requires the developer
to be ID-verified.

⚠ **Verify this against Roblox's current terms before designing on it** — read from
`create.roblox.com/docs/cloud/auth/oauth2-overview` on 2026-08-27, and platform policy moves.

**Offered rather than required is the shape that survives the constraint**: linked accounts get
a verified badge, or leaderboard ELIGIBILITY requires a link while anyone may play. That puts
sybil resistance where it actually matters — the standings — without an age wall on the door.
Either way the wallet must be ruled first.

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
