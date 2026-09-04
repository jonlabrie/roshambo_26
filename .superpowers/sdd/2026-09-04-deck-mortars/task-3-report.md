# Task 3: NetworkClient — placements out and back — Report

## What I implemented

Added `NetworkClient.putMortarPlacements(self, robloxUserId, placements)` to
`roblox/src/server/NetworkClient.luau`, placed directly after `setDecorations`
(the method it mirrors):

```lua
function NetworkClient.putMortarPlacements(
    self: any,
    robloxUserId: string,
    placements: { [string]: any }
): Result
    return self:_request(
        "PUT",
        `/api/v1/players/{robloxUserId}/mortar-placements`,
        { placements = placements }
    )
end
```

Same idiom as `setDecorations`/`setAccess`: a one-line delegation to `_request`
with method `"PUT"`, an interpolated path carrying `robloxUserId`, and a body
table wrapping the argument under its field name. No new retry/error logic —
it rides `_request`'s existing retry (transport failures + 5xx), fail-fast
(4xx surfaces `decoded.error`), 404→`notReady`, and decode-failure handling
verbatim, same as every other method in the file. Signature wraps across
multiple lines only because stylua reformatted it that way (line length) —
functionally identical to a single-line declaration.

Named `putMortarPlacements` (not `setMortarPlacements`) per the brief's
required interface, matching the file's other `put*` method, `putHudPreference`.

## getFireworks passthrough finding (required)

**Verified: no change needed.** `getFireworks` (line ~212) is:

```lua
function NetworkClient.getFireworks(self: any, robloxUserId: string, lastWorldThrow: string?): Result
    local q = if lastWorldThrow then `?lastWorldThrow={lastWorldThrow}` else ""
    return self:_request("GET", `/api/v1/players/{robloxUserId}/fireworks{q}`)
end
```

It returns `_request`'s `Result` directly with no field-picking. Inside
`_request`, a 2xx response sets `data = decoded` where `decoded` is the full
`jsonDecode`'d response body — the whole object, not a projection. So once
the backend's fireworks GET response includes `mortarPlacements` in its JSON
body, callers reading `result.data.mortarPlacements` get it automatically.
This is the "returns the decoded body as-is" case the brief anticipated;
no `getFireworks` change was made or needed.

## Test/lint results

Existing Lune coverage for NetworkClient (`roblox/tests/NetworkClient.spec.luau`)
has tests for most PUT-style methods (`setPreferences`, `setTeahouse`,
`putHudPreference`) but none for `setDecorations`, `setAccess`, or
`getFireworks` — those three are exercised only via DI at runtime, not under
Lune. Since the method being mirrored (`setDecorations`) has no test to
extend, I instead followed the idiom used by the file's *other* PUT-method
tests (`setPreferences`/`setTeahouse`/`putHudPreference`) and added two tests
for `putMortarPlacements`: a happy-path PUT-and-echo test and a 400
fail-fast test. No test was added for `getFireworks`'s passthrough since none
existed to extend and the brief frames it as a read/verify step, not a new
test obligation.

```
$ lune run tests/run
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/.../roblox/tests/HandlerQueue.spec:80: boom
1640 passed, 0 failed, 1640 total
```
(The two WARN lines are expected output from an unrelated pre-existing spec,
`HandlerQueue.spec`, exercising its own queue-overflow/handler-error paths —
not a failure, and unrelated to this change. Confirmed same output before and
after this change.)

```
$ stylua --check src tests tools
```
First run flagged the new function's signature formatting (stylua wanted the
3-argument signature wrapped across lines); ran `stylua src/server/NetworkClient.luau
tests/NetworkClient.spec.luau` to apply its formatting, then `--check` passed
clean with no diff.

```
$ selene src tools
0 errors
0 warnings
0 parse errors
```

Full suite re-run after the stylua reformat: still `1640 passed, 0 failed, 1640 total`.

## Files changed

- `roblox/src/server/NetworkClient.luau` — added `putMortarPlacements` (+12 lines)
- `roblox/tests/NetworkClient.spec.luau` — added `describe("NetworkClient.putMortarPlacements", ...)` block, 2 tests (+25 lines)

Two unrelated pre-existing working-tree modifications (`.superpowers/sdd/.gitignore`,
`art/birds/uguisu/uguisu_authored.blend`) were present before this task started and
were deliberately left unstaged/uncommitted — not part of this task's scope.

## Self-review

- Read the committed diff (`git diff src/server/NetworkClient.luau` before commit,
  and `git show` after): the new method is a faithful mirror of `setDecorations` —
  same `self: any` typing style, same interpolated-path pattern, same body-wrapping
  convention (`{ placements = placements }` matching `{ decorations = decorations }`).
- Placement: inserted immediately after `setDecorations` (the method it mirrors),
  before `setAccess` — keeps decoration/placement-adjacent PUT methods grouped.
- No `_request` changes, no changes to retry/backoff/error logic — exactly as scoped.
- Type annotation `{ [string]: any }` for `placements` matches the brief's specified
  produce-interface signature verbatim.
- Confirmed only the two intended files are staged in the commit (`git status`
  showed the pre-existing unrelated modified files remained unstaged).

## Concerns

None. The change is a mechanical, low-risk mirror of an existing well-tested
pattern; both the backend contract (from Task 1, already merged) and this
client method use the same field name (`placements`) and path shape as the
brief specifies.
