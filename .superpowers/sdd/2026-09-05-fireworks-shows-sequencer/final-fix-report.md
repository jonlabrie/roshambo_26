# Final whole-branch review — fix wave

Branch `thread/shows`, from `c1dfebe`. Two commits: `daded6d` (code), `6676bdb` (docs). Pushed.

## Per finding

**#1 origins snapshotted after the reserve; unresolvable slot skipped after the debit.**
`roblox/src/server/main.server.luau:1737-1834`. `Launch.RequestShowGo`'s handler now, in order:
validates the deck/stand, denses + validates the cues, captures `handFrame` (`:1789`) and the
per-distinct-slot `muzzles` snapshot (`:1790-1806`), and **returns before `net:postShowReserve`**
(`:1811`) when any slot resolves to no muzzle —
`warn(\`[SHOW] {uid} refused: slot {slot} has no muzzle on this deck\`)` at `:1802`, nothing
debited. The block comment at `:1737-1742` now says origins are resolved and checked before
anything is paid for. `originFor` (`:1826`) keeps its nil branch as an unreachable guard;
`Launch.playShow`'s warn-and-skip is untouched, because the proving path's slots can legitimately
resolve to nothing.

**#2 `denseCues` did not guarantee density.** Moved to the pure module as
`ShowPlan.dense` (`roblox/src/shared/ShowPlan.luau:111-143`): `pairs`, every key a positive
integer, `maxKey` tracked and compared against `count` (`#t` is a border, not the largest key —
that was the hole), every value required to be a table, and each entry PROJECTED to exactly
`{ t_ms, slot, shellId }` so extra fields never reach validation, the wire or playback.
`Launch.denseCues` deleted; the call site is `ShowPlan.dense(show.cues)` at
`main.server.luau:1769`. Empty input still yields an empty array so `validate` reports `EMPTY`
rather than "not a dense array", preserving the prior error.

**#3 the per-cue fire-time re-check does not exist (docs only).** Fixture case name
`shared-fixtures/shows.json:13`; spec bullet
`docs/superpowers/specs/2026-09-05-fireworks-show-system-design.md:63-65`; wiki sentence in
`docs/wiki/world/fireworks.md` § "Shows and the sequencer". No validator code touched; the case
still expects `ok`.

**#4 inconsistent mid-script fetches.** All three now timed at 10 s with a nil guard:
`Launch.RequestShowGo = remotes:WaitForChild("RequestShowGo", 10)` (`main.server.luau:1743`,
whole connect skipped with a warn when nil), `Launch.FireworkShowsModule =
shared:WaitForChild("FireworkShows", 10)` (`:1907`, a Launch field — no new top-level local — with
the `require` moved inside the else branch at `:1923`), and the pre-existing
`RequestProvingShow` fetch, now sharing one guard with the module. Top-of-file remotes untouched.

**Minor — `show.title` unbounded.** `main.server.luau:1809-1810`: forwarded only when
`typeof(show.title) == "string" and #show.title <= 80`, else nil.

**Minor — TS twin edge tests.** `server/src/shows.test.ts:43-55`.

## RED / GREEN

- Lune, `ShowPlan.dense` (5 new tests in `roblox/tests/ShowPlan.spec.luau:100-134`):
  RED before the module function existed — 5 failed, "attempt to call a nil value"
  (`1887 passed, 5 failed`). GREEN after: `1892 passed, 0 failed, 1892 total`.
- Vitest, the two new `shows.test.ts` cases: they assert behaviour `shows.ts` already had, so RED
  was shown by mutation — dropping `Number.isFinite` from `isCue` and flipping `TOO_LONG`'s `>` to
  `>=` failed exactly those two (`2 failed | 23 passed`); the implementation was restored and all
  25 pass.

## Gates

```
cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run
  -> stylua clean; selene: 0 errors, 0 warnings, 0 parse errors
  -> 1892 passed, 0 failed, 1892 total
cd server && npm test && npx tsc --noEmit
  -> Test Files 29 passed (29); Tests 614 passed (614); tsc clean
```

`tests/Compiles.spec.luau` passes: nothing added a top-level local to `main.server.luau` (both
new bindings are `Launch` fields, and `Launch.denseCues` was freed).

After the fixture rename, both twins that iterate case names were re-run:
`npx vitest run src/shows.test.ts` → 25 passed; `lune run tests/run` → 1892 passed.

## Wiki lint

`node tools/wiki/lint.mjs | tail -1` → `36 error(s), 7 warning(s) across 58 pages` — unchanged.

## Push

`c1dfebe..6676bdb  thread/shows -> thread/shows`.

## Concerns

- The A13 camera-hunt note is a hypothesis parked in the gate paragraph, not a measurement — the
  own-launch look does fire for every `by = owner` cue, but whether it reads as hunting is for the
  gate run to say.
- `ShowPlan.dense` projects with `v.t_ms` etc. on an untyped value; a cue missing a field arrives
  at `validate` as a nil field and is refused `BAD_CUE`, which is the intended path.
