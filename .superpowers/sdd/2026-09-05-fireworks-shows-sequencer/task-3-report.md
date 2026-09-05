# Task 3 report — `ShowPlayer.luau`, the pure timeline and per-stage scheduling

**Status:** complete. Commit `8beae7a` — `feat(shows): ShowPlayer.luau -- pure timeline and one-show-per-stage scheduling`, branch `thread/shows`.

## Implemented

`roblox/src/shared/ShowPlayer.luau` (`--!strict`, no Roblox globals, no requires — runs under Lune):

- `ShowPlayer.TAIL_MS = 6000` — how long after the last cue a stage stays busy.
- `ShowPlayer.durationMs(cues) -> number` — the largest `t_ms` plus the tail (max, not `cues[#cues]`, so an unsorted plan still yields the true end).
- `ShowPlayer.schedule(busyUntilMs: number?, nowMs, cues) -> { startAtMs, endAtMs }` — starts at `nowMs` when the stage is free (`busyUntilMs` nil, or in the past, or exactly now), otherwise at `busyUntilMs`; `endAtMs = startAtMs + durationMs(cues)`. This is spec §2.5's one-show-per-stage rule: a second show queues behind the first's end plus the tail, on that stage only.
- `ShowPlayer.timeline(cues, startAtMs) -> { { atMs, index, cue } }` — one entry per cue in input order, `index` one-based (Luau side; only used to name a cue in logs).
- `ShowPlayer.delaysFrom(nowMs, timeline) -> { number }` — seconds to wait from now per entry, floored at 0.

Types exported: `Cue` (structurally identical to `ShowPlan.Cue`, declared locally so the module requires nothing) and `Entry`.

`roblox/tests/ShowPlayer.spec.luau` — the brief's seven tests verbatim, in Task 2's house style (`harness.describe/test/expect`).

## RED

```
$ cd roblox && lune run tests/run 2>&1 | head -3
error requiring module "../src/shared/ShowPlayer": could not resolve child component "ShowPlayer"
[Stack Begin]
    Script '[C]' - function 'proxyrequire'
```

Failed on the missing module, as the brief predicted.

## GREEN

```
$ cd roblox && lune run tests/run 2>&1 | tail -3
[QUEUE] handler error for u: .../tests/HandlerQueue.spec:80: boom

1879 passed, 0 failed, 1879 total
$ stylua --check src tests tools
(clean)
$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

(The `[QUEUE] handler error` line is `HandlerQueue.spec`'s own deliberate print, pre-existing and unrelated.)

Proof the seven new tests actually execute — suite count with the spec moved aside vs. in place:

```
1872 passed, 0 failed, 1872 total   # spec removed
1879 passed, 0 failed, 1879 total   # spec present
```

## Files changed

- `roblox/src/shared/ShowPlayer.luau` (new, 51 lines)
- `roblox/tests/ShowPlayer.spec.luau` (new, 54 lines)

Only those two were staged; `git status` afterwards shows nothing else touched.

## Self-review

- **`durationMs({})` returns `TAIL_MS`, untested.** An empty cue list is rejected upstream by `ShowPlan.validate` (`EMPTY`), so the module never sees one in the real path. I left it undefined-by-tests rather than adding behaviour the brief did not specify.
- **`timeline` does not sort.** Entries come out in input order, so with an unsorted plan `atMs` would not be monotonic. This is harmless for Task 5's use (each entry becomes an independent `task.delay`, and `delaysFrom` computes each offset independently), and `index` is documented as a log label, not a firing order. Worth remembering if a later consumer assumes chronological entries — sorting belongs in the console or the validator, not here.
- **`schedule` boundary is a strict `>`.** `busyUntilMs == nowMs` counts as free. That is the right reading of "busy *until*" and matches the "busy in the past is free" test's intent.
- **Non-finite `t_ms`** would propagate into `atMs`/delays, but `ShowPlan.validate` already classifies NaN and both infinities as `BAD_CUE` before a plan reaches the player, so no defence is duplicated here.
- No Luau type-check step exists in CI (`stylua`, `selene`, and the Lune suite are the gates); the annotations are for readers and luau-lsp.

## Concerns

None blocking. One thing for Task 5 to own: `schedule` is pure and takes `busyUntilMs` as an argument — the per-stage busy map (and clearing it when a show ends or a stage is torn down) lives in the caller, and nothing here prevents a caller from queuing an unbounded backlog on one stage. If a queue depth cap is wanted, it is a Task 5 decision.
