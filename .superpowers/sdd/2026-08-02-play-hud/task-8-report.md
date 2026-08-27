# Task 8 report: `OnboardingBeats` — the beat machine

## Summary

Neither `roblox/src/shared/OnboardingBeats.luau` nor `roblox/tests/OnboardingBeats.spec.luau`
existed before this task (checked per the brief's "things the brief cannot tell you" note —
unlike Task 1's `Glyphs.spec.luau`, there was no pre-existing coverage to extend). Implemented
exactly as specified in the task brief: a pure module exporting `BEATS` (four beats) and `next`
(seen-set lookup by event), with no Roblox globals and no `require` of sibling `src/shared`
modules.

## Files

- Created: `roblox/src/shared/OnboardingBeats.luau`
- Created: `roblox/tests/OnboardingBeats.spec.luau`

## TDD evidence

### RED — test written first, module missing

```
$ cd roblox && lune run tests/run
```

```
error requiring module "../src/shared/OnboardingBeats": could not resolve child component "OnboardingBeats"
[Stack Begin]
    Script '[C]' - function 'proxyrequire'
    Script '__mlua_require', Line 13
    Script '/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/OnboardingBeats.spec', Line 4
[Stack End]
...
```

Expected failure: the test file `require`s `../src/shared/OnboardingBeats`, which did not yet
exist, so the whole harness run aborts on module resolution before any assertion executes.

### GREEN — module implemented, full suite passing

```
$ cd roblox && lune run tests/run
```

```
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom

859 passed, 0 failed, 859 total
```

The two `[WARN]` lines are expected console output from a pre-existing, unrelated test
(`HandlerQueue.spec.luau`, exercising queue-full and handler-error paths) — not failures; the
final line confirms 0 failed across the whole suite including the 7 new `OnboardingBeats` tests.

### Gates

```
$ cd roblox && stylua --check src tests tools && selene src tools
```

```
Results:
0 errors
0 warnings
0 parse errors
```

Both `stylua --check` and `selene` (warnings-as-failures scope) pass clean.

## Commit

```
e07373c feat(roblox): OnboardingBeats — four event-triggered first-run beats
```

`git status` after commit is clean relative to these two files (no other working-tree changes
touched).

## Self-review (fresh eyes)

- **Constraint compliance**: grepped the new module for `Instance`, `game`, `Enum`, `task` —
  none present. It does not `require` any other `src/shared` module (no dependency-injection
  violation). `shared-fixtures/game-rules.json` and both `GameRules` implementations were not
  touched.
- **Scope discipline (YAGNI)**: the module exports exactly `BEATS` and `next`, matching the
  brief's stated interface — nothing speculative (no beat-consumption tracking, no persistence,
  no event bus wiring). Task 13 owns rendering; this task deliberately stops at the pure
  view-model boundary, consistent with `HudModel`/`LedgerModel`.
- **The movement guard**: `BEATS` ids are `drum`, `throw`, `win`, `bank` — no `move` id exists,
  and the dedicated test (`"no beat teaches movement — that is deliberate"`) asserts this
  directly, not just implicitly by omission.
- **Out-of-order correctness**: `next` filters `BEATS` by `event == event and not seen[id]` with
  no ordering or sequencing assumption between different beats' events — a `win` beat fires from
  an empty `seen` set exactly the same as any other, satisfying "beats are independent, not a
  sequence."
- **Test honesty**: the spec file is the brief's own test block, copied verbatim (no test
  weakened, softened, or marked pending). All 7 assertions run and pass; none are vacuous (e.g.
  the "distinct ids" test fails loudly via `expect(ids[b.id]).toBe(nil)` before overwriting,
  rather than silently deduplicating).
- **Style consistency**: matches `HudModel.luau`'s established conventions — `--!strict` header,
  a design-rationale comment block above the table, `export type`, module table returned at the
  end.
- **Nothing left half-done**: no TODOs, no dead code paths, no unused locals that selene would
  flag (confirmed by the clean gate run).

No concerns to flag.
