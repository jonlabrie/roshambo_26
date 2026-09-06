# Task 7 report: `NetworkClient.postPowderTopup` and `postFireworkMelt`

**Status:** complete. Commit `8f558e0`.

## What was implemented

Two thin HTTP client methods in `roblox/src/server/NetworkClient.luau`, placed immediately
after `postShowReserve` as the brief specifies:

- `postPowderTopup(self, robloxUserId: string, points: number): Result`
  → `POST /api/v1/players/{id}/powder/topup { points }`
- `postFireworkMelt(self, robloxUserId: string, shellId: string, count: number): Result`
  → `POST /api/v1/players/{id}/fireworks/melt { shellId, count }`

Both are one-line delegations to `_request`, so retry/auth/JSON handling and the
`Result { ok, data?, status?, error? }` shape all come from the existing transport — 409
`INSUFFICIENT` / 400 `BAD_REQUEST` arrive as ordinary failed Results, no special casing.

No caller was added; the shop's melt verb waits for the server-file split, and
`main.server.luau` was not touched.

## RED / GREEN

RED — spec added first, run before any implementation existed:

```
FAIL  NetworkClient powder calls > postPowderTopup POSTs { points }
      tests/NetworkClient.spec:536: attempt to call missing method 'postPowderTopup' of table
FAIL  NetworkClient powder calls > postFireworkMelt POSTs { shellId, count }
      tests/NetworkClient.spec:546: attempt to call missing method 'postFireworkMelt' of table

1892 passed, 2 failed, 1894 total
```

Only the two new tests failed, and each on the missing method — the test bodies (URL, method,
decoded body) were therefore genuinely exercised once the methods appeared.

GREEN — after implementing: `1894 passed, 0 failed, 1894 total`.

## Gates

`cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`

```
1894 passed, 0 failed, 1894 total
--- stylua ---
stylua clean
--- selene ---
Results:
0 errors
0 warnings
0 parse errors
```

(The `[QUEUE] handler error ... boom` line above the totals is the pre-existing
`HandlerQueue.spec` fixture logging a deliberate error, not a failure.)

`stylua --check` initially flagged both files for line width only. Running
`stylua src tests tools` wrapped `postFireworkMelt`'s signature and `_request` call across
lines, and wrapped the second test's `makeDeps` table literal; behaviour is unchanged and
the implementation is otherwise verbatim from the brief. `git status` confirmed the format
run touched no files outside the two this task owns.

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/roblox/src/server/NetworkClient.luau` (+17)
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/powder/roblox/tests/NetworkClient.spec.luau` (+25)

Commit staged exactly those two paths, per the brief.

## Self-review

Verified the client routes against the Task 4 server rather than trusting the brief alone —
`server/src/routes/apiV1.ts:400` registers `/players/:robloxUserId/powder/topup` and
`:447` registers `/players/:robloxUserId/fireworks/melt`, and `apiV1.test.ts` posts
`{ points }` and `{ shellId, count }` respectively. Paths and body shapes match.

## Concerns

1. **The tests assert the wire, not the server's contract.** They use a fake HTTP dep, so
   they would still pass if the server route were renamed. The route-name coupling is
   currently guarded only by the manual check above — nothing fails CI on drift, unlike the
   `shared-fixtures/game-rules.json` arrangement.
2. **`count` is unvalidated client-side.** A non-integer or negative `count` is sent
   straight through and rejected by the server as 400 `BAD_REQUEST`. That matches the thin
   style of every neighbouring method, and the eventual caller should surface the failed
   Result rather than assume success.
3. **`postFireworkMelt`'s formatted shape differs cosmetically from the brief's snippet**
   (stylua wrapping). Worth noting only so a reviewer diffing against the brief is not
   surprised.
