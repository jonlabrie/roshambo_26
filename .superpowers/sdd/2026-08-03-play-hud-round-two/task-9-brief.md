### Task 9: The ledger's LAST ROUND band

**Files:** Modify `roblox/src/client/LedgerController.client.luau`,
`roblox/src/client/main.client.luau`.

- [ ] **Step 1: Send the round detail**

`main.client.luau` already receives `worldThrow`, `pick`, `result`, `distribution` and
`totalPlayers` on `RevealResult`. Stash them and include them in `publishLedger`'s payload as
`lastRound`. It must be **nil until a round has been revealed**, so the band can hide rather than
show zeros to someone who just joined.

- [ ] **Step 2: The band**

Above the hero band, below the header — `HERO_H` currently starts at `HEADER_H`, so the band goes
in between and everything below shifts by its height plus a gap. `BODY_TOP` re-derives.

Contents: the world's throw and the player's throw as glyphs, the result, the crowd split as a
three-way bar, and the player count. Reuse the ledger's existing `stroke`/`corner` helpers and its
card treatment.

**The three-way bar must sum to exactly 100%.** Use largest-remainder apportionment — the same
rule the ledger's existing win-rate bar uses; read it and reuse it rather than writing a second.

Hide the whole band when `lastRound` is nil.

- [ ] **Step 3: Verify and commit**

Confirm the band hides for a fresh join; confirm `BODY_TOP` and the scroll canvas re-derive
rather than carrying the old literal; confirm the bar sums to 100 for a 1/1/1 split (the case
naive rounding gets wrong).

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the ledger remembers the round you just played"
```

---

## Final verification

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools
cd ../server && npm test
cd .. && git status --porcelain
```

## The owner's Studio gate

Nothing here can verify: whether the ring reads as a ring at 36 segments; whether the splash is
big enough to celebrate and short enough not to intrude; whether the halved escalation still
commands attention; whether the ring's digits are legible at the touch tier; and whether the
bottom row still breathes now that it holds a plate, a ring and a tape.
