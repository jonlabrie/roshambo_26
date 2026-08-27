# B3 Polish Wave Report

Branch: `m4b-zendojo-art-pass`. All changes are in the Roblox/Luau client+shared+server for the
B3 teahouse management panel.

## Files touched

- `roblox/src/shared/TeahouseMenuModel.luau` — view-model changes for items A and B.
- `roblox/tests/TeahouseMenuModel.spec.luau` — TDD tests for items A and B (added, none removed).
- `roblox/src/client/TeahouseController.client.luau` — panel UI for items A, B, C, D, E, F, G.
- `roblox/src/server/main.server.luau` — item C (`names` map on `PreferenceState` echoes) and
  item H (comment rewrite).

## Per-item change sites

**A. Claimless-owner gating**
- `roblox/src/shared/TeahouseMenuModel.luau:29-34` — `needsClaim = ownsDeck and state.claimed == false`.
- Same file, deck ladder `isNext` (line ~42), teahouse ladder `buyable` (line ~65), deck/teahouse
  display option `enabled` (lines ~80-93) all gated by `not needsClaim`.
- Same file, return table adds `needsClaim = needsClaim` (~line 118).
- `roblox/src/client/TeahouseController.client.luau:49` — `econ.claimed` field added.
- Same file, `EconomyState.OnClientEvent` handler (~line 573) sets `econ.claimed = p.claimedPadId ~= nil`.
- Same file, new `needsClaimHint` TextLabel (~line 175-186), toggled in `render()`
  (`needsClaimHint.Visible = vm.needsClaim`, ~line 533).
- Tests: `roblox/tests/TeahouseMenuModel.spec.luau`, describe block "claimless-owner gating (item A)"
  (owner+unclaimed, owner+claimed, non-owner).

**B. Shown-smaller flags**
- `roblox/src/shared/TeahouseMenuModel.luau` — `deckShownSmaller` / `teahouseShownSmaller`
  computed (~lines 103-113), returned in the view-model table.
- `roblox/src/client/TeahouseController.client.luau` — new `shownSmallerHint` TextLabel
  (~line 339-351), toggled in `render()`:
  `shownSmallerHint.Visible = vm.deckShownSmaller or vm.teahouseShownSmaller` (~line 543).
- Tests: `roblox/tests/TeahouseMenuModel.spec.luau`, describe block "shown-smaller hints (item B)"
  (deck below/equal/nil, teahouse 'none'-with-owned/below/equal/nil).

**C. Favorites show real names**
- `roblox/src/server/main.server.luau:388-397` — new `namesFor(siteIds)` helper builds
  `siteId -> PadSites[siteId].displayName or siteId`.
- Same file, all three `PreferenceState:FireClient` sites now include `names = namesFor(...)`:
  join-sync (~line 543-546), setPreferences-persist-failure revert (~line 578-580), and the
  normal toggle echo (~line 585).
- `roblox/src/client/TeahouseController.client.luau:56` — `favoriteNames` module var; set in
  `PreferenceState.OnClientEvent` (~line 575); `renderFavorites` (~line 448) takes a `names`
  param and renders `names[siteId] or siteId` (~line 483) instead of `"Perch " .. siteId`.
- Verified `roblox/src/client/PerchPreferenceController.client.luau` reads only
  `payload.padPreferences`, `payload.changed`, `payload.name`, `payload.favorited` — confirmed by
  `git diff` showing zero changes to that file; the added `names` field is inert to it.

**D. Favorites list scrolls**
- `roblox/src/client/TeahouseController.client.luau:353-371` — `favoritesContainer` converted
  from `Frame` (unbounded `AutomaticSize.Y`) to `ScrollingFrame`: fixed viewport
  `Size = UDim2.new(1, 0, 0, 140)`, `CanvasSize = UDim2.new()`,
  `AutomaticCanvasSize = Enum.AutomaticSize.Y`, `ScrollBarThickness = 6`. The existing
  `UIListLayout` inside is unchanged. 140px was sized against the panel's own fixed layout math
  (header + both ladders + both display rows + backDoorLabel + paddings/gaps ≈ 378px of the
  520px panel, leaving ~140px for the favorites viewport before it scrolls internally).

**E. Pre-echo loading state**
- `roblox/src/client/TeahouseController.client.luau:67` — `local ready = false`, set true on
  first `EconomyState` echo (~line 555). `catalogReady()` (~line 68) now requires both
  `ready` and a populated `catalog.deck` (kept the catalog-populated check as a belt-and-braces
  guard — see "Deliberate interpretations" below).
- New `loadingLabel` (~line 190-201) plus `deckSection`/`deckRow`/`teaSection`/`teaRow` handles
  returned from `buildLadderRow` (~line 208-256) so `render()` can hide just the ladder rows
  pre-ready and show one "Loading…" line (~lines 507-523).

**F. No-op display click guard**
- `roblox/src/client/TeahouseController.client.luau:314-328` — `pickDeckDisplay` /
  `pickTeahouseDisplay` each `return` immediately when the clicked value equals
  `desired.deckDisplay` / `desired.teahouseDisplay` before firing `SetDisplay`.

**G. Lost-update on rapid cross-dimension clicks**
- `roblox/src/client/TeahouseController.client.luau:61` — `local desired = { deckDisplay = nil,
  teahouseDisplay = nil }`.
- Reconciled from every `EconomyState` echo (~lines 563-566).
- `pickDeckDisplay`/`pickTeahouseDisplay` (~line 314-328) update only their own dimension in
  `desired` and always fire `SetDisplay` from the full `desired` pair. The F guard compares
  against `desired`, not the echo, per the spec.
- `buildDisplayRow` call sites (~line 330-332) now pass `pickDeckDisplay` / `pickTeahouseDisplay`
  instead of inline lambdas that read `econ.*`.

**H. Comment fix (server)**
- `roblox/src/server/main.server.luau:697-706` (buy-to-claim `playerHouse` sync) — comment
  rewritten to describe the true reachable case (a returning owner whose auto-claim failed on
  pad scarcity, later buying a deck upgrade once a pad frees, whose already-owned teahouse gets
  built by this claim) and explicitly notes the old scenario is unreachable because
  `validatePurchase` enforces teahouse size ≤ owned deck size. No code changes, comment only.

## TDD evidence (items A, B)

1. Added `claimed = true` default to the spec's `state()` helper, then appended the two new
   `describe` blocks (10 new test cases) to
   `roblox/tests/TeahouseMenuModel.spec.luau` — no implementation changes yet.
2. Red run:
   ```
   $ lune run tests/run
   FAIL  ...claimless-owner gating (item A) > owner+unclaimed...  expected nil to be true
   FAIL  ...claimless-owner gating (item A) > owner+claimed...    expected nil to be false
   FAIL  ...claimless-owner gating (item A) > non-owner...        expected nil to be false
   FAIL  ...shown-smaller hints (item B) > deck display cap below owned -> true   expected nil to be true
   FAIL  ...shown-smaller hints (item B) > deck display cap equal to owned -> false expected nil to be false
   FAIL  ...shown-smaller hints (item B) > deck display nil -> false              expected nil to be false
   FAIL  ...shown-smaller hints (item B) > teahouse display 'none' with an owned teahouse -> true  expected nil to be true
   FAIL  ...shown-smaller hints (item B) > teahouse display cap below owned -> true expected nil to be true
   FAIL  ...shown-smaller hints (item B) > teahouse display cap equal to owned -> false expected nil to be false
   FAIL  ...shown-smaller hints (item B) > teahouse display nil -> false          expected nil to be false

   407 passed, 10 failed, 417 total
   ```
   (All 10 new tests failed as expected — `vm.needsClaim`/`vm.deckShownSmaller`/
   `vm.teahouseShownSmaller` didn't exist yet, so `expect(nil).toBe(...)` failed on every one.
   The pre-existing 407 stayed green throughout.)
3. Implemented `needsClaim`, `deckShownSmaller`, `teahouseShownSmaller` in
   `TeahouseMenuModel.viewModel`.
4. Green run:
   ```
   $ lune run tests/run
   417 passed, 0 failed, 417 total
   ```

## Full verification (final)

```
$ lune run tests/run
417 passed, 0 failed, 417 total

$ stylua --check src tests
(no diff after running `stylua src tests` once to reformat one wrapped call site)

$ selene src
Results:
0 errors
0 warnings
0 parse errors
```

## Deliberate interpretations

- **Item A default `claimed`**: the spec's `state()` test helper didn't have a `claimed` field
  before. I defaulted it to `true` in the helper so all pre-existing owner-focused tests
  (written before this item existed) continue to exercise the "claimed" (unchanged) path without
  being touched, and only the new item-A tests override it to `false`. This matches "owner+claimed
  → unchanged from today."
- **Item E "ready" vs. catalog-populated**: the pre-existing `catalogReady()` helper served two
  purposes at once — gating the loading UI *and* preventing a crash (`points >= nil` when a
  `catalog.deck[size]` lookup misses) if a client ever received an `EconomyState` echo with an
  empty catalog (only reachable if this player's initial `getEconomy` HTTP call failed
  server-side before any catalog was ever fetched for anyone — an existing, unrelated edge case).
  I added the literal `ready` flag the spec asked for (true after the first echo) but kept
  `catalogReady()` requiring *both* `ready` and a non-empty `catalog.deck`, so the pre-existing
  crash guard isn't weakened. This is a superset of "set by the first EconomyState," not a
  deviation from it in the normal path (the two conditions become true at the same instant for
  every ordinary echo).
- **Item D viewport height (140px)**: the spec said "fixed viewport height that fits the current
  panel layout" without a number. I derived 140px from the panel's own fixed-size budget: 340×520
  panel, 24px paddings, and the other always-visible rows/gaps sum to ~378px, leaving ~140px
  (~5 favorite rows before scrolling kicks in).
- **Item E scope**: "hide the rows/ladders" was read narrowly as the deck+teahouse ladder
  section-labels and rows specifically (the literal bug reported — "bare S/M/L buttons"). The
  display rows were already hidden by default pre-echo (unaffected by this bug), and the
  favorites/back-door sections have reasonable empty-state text already, so I left those alone
  to keep the change minimal per the spec's own instruction.
- **Item C helper placement**: added a single `namesFor(siteIds)` local helper in
  `main.server.luau` rather than inlining the map-building three times, per the spec's own
  suggestion ("small helper local function").

## Commit

One commit was created covering all four files (see final report message for SHA/subject).
