### Task 8: Docs, push, CI, STOP

**Files:**
- Modify: `docs/wiki/world/fireworks.md`, `docs/wiki/world/core-loop.md`, `docs/wiki/world/hanabiya.md`, `docs/wiki/program/backlog.md`, `docs/wiki/log.md`

Per `docs/wiki/schema.md`: supersede, don't contradict; measurable facts carry their re-measure path; `log.md` kinds ∈ gate|ship|decision|drop|defect|migrate|lint|audit; `node tools/wiki/lint.mjs` count must not rise.

- [ ] **Step 1: `core-loop.md`** — in "The economy, and which number means what", add a fifth bullet after `bestPot`:

```markdown
- `powder` — **the second economy, and not points** (spec 2026-09-05 §7, decision 10). Points and
  Robux flow in, melted shells flow in, and only fireworks flow out. Never rank by it, never sum it
  into earnings, never let a route move it to `totalPoints` or a durable. Golden tickets
  (`goldenTickets[]`) are minted beside it by the drop table and belong to sub-project C.
```

- [ ] **Step 2: `fireworks.md`** — append a section:

```markdown
## Powder and drops (sub-project A, built 2026-09-06)

Spec §7; plan `docs/superpowers/plans/2026-09-06-powder-and-drops.md`. **Powder buys only things
that burn.** Flows: `POST …/powder/topup` (points → powder, one way, positive integers only);
`POST …/fireworks/melt` (shells → powder at list price, `powderEligible` shells only — the list of
ineligible shells is `firework-shells.json` `powderIneligible`, EMPTY today); `POST …/powder/grant`
(external: Robux receipts, gifts, ops — idempotent by `receiptId` via the `PowderGrant` collection);
`shows/reserve` accepts `fuel: "powder"` (summed list price, one conditional update). Every move is a
conditional `$inc`. `powder` rides on `/economy` and `/fireworks`; `ShellState` carries
`powderEligible`.

**Drops by streak tier** replace the flat firecracker-per-WIN: `shared-fixtures/firework-drops.json`
(default `firecracker`, tiers at 3 → `peony`, 5 → `wa`, a golden ticket at 6 with the default shell
beside it; one ticket per crossing) — starting values, re-read the fixture rather than this line.
Awarded on the WIN event inside settlement's single atomic write, so neutral to Bank vs Stake.

**Not here:** the Hanabiya's melt UI (a client change once `main.server.luau` is split — the
`NetworkClient` calls exist), ticket redemption/gifting/booking (C), Robux product ids.
```

- [ ] **Step 3: `hanabiya.md`** — one sentence under the roof section or a new short "Melting" line: the shop will melt shells back to powder; the backend route exists (2026-09-06); the counter verb waits for the server split.

- [ ] **Step 4: `backlog.md`** — append under the show-system decisions:

```markdown
## Hanabiya melt verb (banked 2026-09-06, after the server-file split)

Sub-project A shipped the backend (`fireworks/melt`) and `NetworkClient.postFireworkMelt`; the shop
row's "Melt" button and its `RequestMelt` remote handler were deliberately NOT added because
`main.server.luau` sits at the register ceiling and is being split. First client task after the
split: a Melt affordance per held, powder-eligible shell in `ShopController`, and a handler on the
extracted fireworks controller.
```

- [ ] **Step 5: `log.md`** — append:

```markdown
## [2026-09-06] ship | Powder + drops (sub-project A): the second economy, sealed; wins drop by streak tier

Plan `docs/superpowers/plans/2026-09-06-powder-and-drops.md`. `powder` and `goldenTickets` on the
user; topup (one way), melt (list price, eligible only), external grant (idempotent by receipt),
powder fuel on `shows/reserve`; drop table as a fixture contract replacing the flat firecracker
grant inside settlement's one atomic write. Backend + two NetworkClient calls only — no
`main.server.luau` change (the split is in flight); the shop's melt verb is banked. Dev needs a
`start-deployment` to pick this up (auto-deploy is off). Still on `thread/powder`, NOT merged.
```

- [ ] **Step 6: Lint, commit, push, CI**

`node tools/wiki/lint.mjs | tail -1` (baseline first, then after). Commit the five files; `git fetch origin && git push -u origin thread/powder`; confirm `server-ci` and `roblox-ci` green on the branch.

- [ ] **Step 7: STOP.** Report the branch, CI links, and that dev needs a redeploy after merge. The merge goes through the main thread; no self-merge.

---

## Self-review against the spec

- §7 flow table: points → powder (T4 topup), Robux → powder (T5 grant seam), shells → powder (T4 melt), powder → firing (T6 reserve), shells/powder → points NEVER (no route; T4 tests assert `totalPoints` untouched by melt and topup refuses reverse), powder → durable NEVER (no route accepts it; `/purchase` untouched). ✔
- §7 ineligible shells outside powder both ways: T1 flag, T4 melt 400, T6 reserve 409. ✔ (list empty; skip-test documents the branch)
- §7 powder never expires / no refunds: nothing decays it; no refund route. ✔
- §7 drops by tier, items not amounts, on the WIN event, neutral to banking: T2 + T3. ✔
- §10 row A: powder balance, top-up, melt, flag, drop table with fixture, Robux seam (no ids): T1–T5. ✔ Powder fuel path for B: T6. ✔
- §12: seal tests, melt eligibility, drop fixture, reserve atomicity, concurrency: present. ✔
- Type consistency: `Drop { shellId, ticket }` used identically in T2 and T3; `isPowderEligible` name identical in T1/T4/T6; response shapes match between routes and tests.
- No `main.server.luau` edit anywhere. ✔
