# Task 3 Report: `ShopThreshold` — the inside test

## Summary

TDD implementation completed: spec → failing test → implementation → passing test → lint → commit.

## Step 1: Test File Created

`roblox/tests/ShopThreshold.spec.luau` written with 8 test cases covering:
- Inside detection (center of shop)
- Promenade exclusion (volume starts at z45, not z44 frontage)
- Front inset constant verification (FRONT_INSET = 1)
- Boundary exits (X and Z edges)
- Height bounds (not on roof or below)
- Inclusive face membership
- Degenerate box (zero-volume box admits nothing)

## Step 2: Failing Run (Expected)

```
error requiring module "../src/shared/ShopThreshold": could not resolve child component "ShopThreshold"
```

Module did not exist; test correctly failed to load.

## Step 3: Implementation Created

`roblox/src/shared/ShopThreshold.luau` written with:
- Type exports: `Vec`, `Box`
- Constant: `FRONT_INSET = 1`
- Function: `isInside(pos: Vec, box: Box): boolean`

Pure Luau module, Roblox-free (positions as plain tables), Lune-testable.

## Step 4: Passing Run

```
1056 passed, 0 failed, 1056 total
```

All tests pass, including the 8 new ShopThreshold test cases. Warnings from existing tests (HandlerQueue.spec) are pre-existing.

## Step 5: Linting

```
Results:
0 errors
0 warnings
0 parse errors
```

Both `stylua --check` and `selene` pass with zero issues.

## Step 6: Commit

```
[m4b-zendojo-art-pass e33e8bf] feat(roblox): the shop threshold, and the one stud that keeps it off the promenade
 2 files changed, 80 insertions(+)
 create mode 100644 roblox/src/shared/ShopThreshold.luau
 create mode 100644 roblox/tests/ShopThreshold.spec.luau
```

Commit SHA: `e33e8bf`

---

## Verification

- [x] Test file created and failed (module missing)
- [x] Implementation created and tests pass (1056/1056)
- [x] Linting clean (0 errors, 0 warnings)
- [x] Committed to branch `m4b-zendojo-art-pass`
