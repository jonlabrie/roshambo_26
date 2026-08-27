# Task 1 report: The bank row gives back 6px

## Status: DONE

Commit: `f0eee55` — "fix(roblox): BANK_GAP finally is the gap, and the bank row gives back 6px"

## What changed and why

Followed the brief's 9 steps in order, verbatim on code/comments where given.

1. **`roblox/tests/HudLayout.spec.luau`** — changed the three `ROW_GAP`-based derivations of
   `CLUSTER_TOP_FROM_BOTTOM`/`CLUSTER_TOP_FROM_BOTTOM_TOUCH` to `BANK_GAP`, and added the two new
   tests (`BANK_GAP ~= ROW_GAP`, `BANK_H == 36`), exactly as specified.
2. Ran `lune run tests/run` — confirmed 3 expected failures (`182` vs `180` twice, `40` vs `36`
   once). 961 passed / 3 failed.
3. **`roblox/src/shared/HudLayout.luau`** — `BANK_H` dropped 40 → 36 with the owner's-gate
   comment; `BANK_GAP` kept at 8 but got the "now actually the gap" comment; both
   `CLUSTER_TOP_FROM_BOTTOM` and `CLUSTER_TOP_FROM_BOTTOM_TOUCH` now add `BANK_GAP` instead of
   `ROW_GAP`.
4. Ran `lune run tests/run` — 964 passed / 0 failed.
5. **`roblox/src/client/HudController.client.luau`** — added `local BANK_GAP = HudLayout.BANK_GAP`
   next to `RING_GAP` (line ~114), and changed the bank button's `Position` line (was `:805`, now
   `:806` after the insert) from `ROW_GAP` to `BANK_GAP`. Confirmed `ROW_GAP` still has a live code
   use at `local ESCALATION_MARGIN = ROW_GAP` (~line 1171), so it was not deleted.
6. **`roblox/src/client/OnboardingController.client.luau`** — moved the `CLUSTER_TOP_FROM_BOTTOM`
   declaration and its explanatory comment up from their old spot (below `STATIC_ANCHORS`) to sit
   with the other layout locals, right after the `BANK_GAP` local and before `CARD_W`. This was
   the trap flagged in the task instructions: `STATIC_ANCHORS` is now built as a table literal that
   reads `CLUSTER_TOP_FROM_BOTTOM`, so the declaration had to precede it or the reference would
   have resolved to a nil global at runtime (a failure no automated gate would have caught, since
   nothing loads `.client.luau` files). Replaced all three `STATIC_ANCHORS` offsets
   (`throwArea`, `potIndicator`, `wallet`) with
   `UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(CLUSTER_TOP_FROM_BOTTOM + BANK_GAP))`. Updated the stale
   comment above `STATIC_ANCHORS` (originally citing `EDGE/AREA_H/ROW_GAP/BANK_H/BANK_GAP`) to cite
   `CLUSTER_TOP_FROM_BOTTOM + BANK_GAP` instead.
7. Deleted the now-dead locals `EDGE`, `AREA_H`, `ROW_GAP`, `BANK_H` in `OnboardingController`.
   Kept `BANK_GAP` and `JUMP_CLEARANCE` as directed. Verified with
   `grep -n "\bEDGE\b\|\bAREA_H\b\|\bROW_GAP\b\|\bBANK_H\b" OnboardingController.client.luau` —
   the three remaining hits are all inside comments (module-header comment at line 58, the moved
   `CLUSTER_TOP_FROM_BOTTOM` comment at line 74, and the toast-band comment at line 236).
8. Ran all three gates from `roblox/`: `lune run tests/run` (964 passed / 0 failed),
   `stylua --check src tests tools` (clean, exit 0), `selene src tools` (0 errors, 0 warnings, 0
   parse errors).
9. Committed the four files with the exact message from the brief.

## Exact gate output (final run, after all edits)

```
$ lune run tests/run
[WARN] [QUEUE] dropping request for u: queue full (8)
[WARN] [QUEUE] handler error for u: .../tests/HandlerQueue.spec:80: boom
964 passed, 0 failed, 964 total

$ stylua --check src tests tools
(no output, exit 0)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

The two `[WARN]` lines are pre-existing, unrelated `HandlerQueue.spec` test-harness noise (that
spec deliberately induces a queue-full/handler-error condition as part of its own test); they
appeared identically in the "watch them fail" run before any of my edits and are not part of this
task's surface.

## Decisions the brief left open

- **The stale comment above `STATIC_ANCHORS`** (originally: "offset clears its full footprint via
  EDGE/AREA_H/ROW_GAP/BANK_H/BANK_GAP, the same numbers HudController's own stack is built from").
  The brief's Step 7 only explicitly named the `:176` comment (which drifted to line ~236, the
  `CLUSTER_TOP_FROM_BOTTOM`-band comment near `TOAST_BAND`) for updating. I additionally updated
  this second, separate stale comment at the top of `STATIC_ANCHORS` (~line 185) since it also
  named the now-deleted constants and would otherwise have been exactly the kind of
  no-longer-true derivation comment the brief calls out as the failure mode to avoid. Changed it
  to reference `CLUSTER_TOP_FROM_BOTTOM + BANK_GAP`.
- **The `BANK_GAP` local's comment in `OnboardingController`** ("The bank button's row, directly
  above the throw cluster... Declared here, above STATIC_ANCHORS, because that table reads them.")
  previously sat directly above `BANK_H = HudLayout.BANK_H`. Since `BANK_H` is deleted and the
  comment's claim ("that table reads them") still holds true for `BANK_GAP` (and now also for
  `CLUSTER_TOP_FROM_BOTTOM`, declared just below it), I left the comment in place rather than
  rewriting or deleting it — it isn't stale, just slightly less specific than before.
- **Placement of the moved `CLUSTER_TOP_FROM_BOTTOM` block**: the brief said to move it "up to sit
  with the other layout locals after `:75`" (i.e., after the old `BANK_GAP` line). I placed it
  immediately after the `BANK_GAP` local and before `CARD_W`, which is the natural reading of that
  instruction and keeps all `HudLayout`-derived locals grouped together before the first non-layout
  constant.

## Concerns

None outstanding. All three gates (`lune run tests/run`, `stylua --check`, `selene`) are green,
the trap called out in the task instructions (forward reference to `CLUSTER_TOP_FROM_BOTTOM`) was
identified and fixed by moving the declaration ahead of `STATIC_ANCHORS`, and a full grep confirmed
no remaining code (non-comment) references to the four deleted `OnboardingController` locals or to
any `HudLayout` field that doesn't actually exist on the module.
