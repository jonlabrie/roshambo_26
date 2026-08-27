# Task 1 Report: RingTimer

## Status: DONE

## Commit
`cfaf79448e51610d02299b06640fb43addabf88b` — "feat(roblox): the round's remaining time, as arithmetic"

## TDD sequence
1. Wrote `roblox/tests/RingTimer.spec.luau` verbatim from the brief (12 test cases across 4 `describe` blocks: `lit`, `angleAt`, `isWarning`, `segmentWidth`).
2. Ran `lune run tests/run` — failed with `error requiring module "../src/shared/RingTimer": could not resolve child component "RingTimer"` — the expected failure (module missing), not a logic error.
3. Wrote `roblox/src/shared/RingTimer.luau` verbatim from the brief (`SEGMENTS = 36`, `lit`, `angleAt`, `isWarning`, `segmentWidth`). Pure Luau — no Roblox globals, no `require` of sibling shared modules.
4. Ran `lune run tests/run` — 936 passed, 0 failed (baseline 924 + 12 new).

## Mutation check
Changed `math.ceil` → `math.floor` in `RingTimer.lit`. Re-ran suite:
- **935 passed, 1 failed** — failure was exactly the targeted test: `RingTimer.lit ... > any time remaining leaves at least one segment lit`, `expected 0 to be 1`.

Reverted `math.floor` back to `math.ceil`. Re-ran suite:
- **936 passed, 0 failed** — back to green.

The mutation was caught cleanly by the intended test; no other tests were affected by the mutation (confirming the other 11 RingTimer tests don't depend on the ceil/floor distinction, as expected).

## Gates
- `lune run tests/run`: 936 passed, 0 failed, 936 total (up from 924 baseline; the two pre-existing `[WARN]` lines about `HandlerQueue.spec` queue/handler-error are expected fixture noise unrelated to this change, present before and after).
- `stylua --check src tests tools`: clean, exit 0.
- `selene src tools`: `0 errors, 0 warnings, 0 parse errors`.

## Scope discipline
Only created `roblox/src/shared/RingTimer.luau` and `roblox/tests/RingTimer.spec.luau`. Did not touch `HudController`, `HudLayout`, or any other file, per the brief's explicit instruction (Tasks 3/4 consume this module).

## Concerns
None. Implementation matches the brief's reference code exactly; all interfaces (`SEGMENTS`, `lit`, `angleAt`, `isWarning`, `segmentWidth`) present and tested.
