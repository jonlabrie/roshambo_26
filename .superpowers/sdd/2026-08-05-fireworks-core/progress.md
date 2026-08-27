# SDD ledger — plan: docs/superpowers/plans/2026-08-05-fireworks-core.md

Branch: m4b-zendojo-art-pass
Base at start: 83d8c64

Task 1: MEASURED 2026-08-05, PARTIALLY. Samsung A13 (Helio G80), published place, manual quality 5
  and Automatic: the bench ramped to its 10 shells/sec floor — "impacted but not unusable". So the
  device gate is discharged and Tasks 2-9 need no hardware.
  WHAT WE DO NOT HAVE: the knee, and the no-shells baseline. The bench never dropped below its own
  threshold, and a `table.insert(steps, nil)` no-op dropped the baseline row (fixed in f263d87).
  So this is a LOWER BOUND, not a curve.
  WHAT IT IMPLIES FOR TASK 6: at 10 shells/sec with ~2-4s bursts, roughly 30 shells were alive at
  once at ~700 particles each — call it ~21k particles. The spec's provisional 14 x 400 = 5.6k.
  That is ~4x headroom. ARITHMETIC, NOT MEASURED — the bench never reported concurrency.
  RULING: Task 6 still ships the provisional 14 / 400. They are now known-conservative rather than
  unknown, which is the right direction for a number that also has to survive a 50-player battle the
  bench never tested. Do NOT raise them without a multi-player measurement.
  The Studio gate should still note the knee is uncaptured; it no longer needs to flag the whole
  measurement as missing.
Task 2: shell ledger (ids, prices, evaluator)
Task 3: inventory, purchase, conditional-$inc spend
Task 4: win grant
Task 5: the referee (sites, remotes, spend)
Task 6: the director
Task 7: catalog + schedule compiler
Task 8: the phase player
Task 9: the picker


Task 2: complete — a25f0c7. server/src/fireworks.ts + fireworks.test.ts. 15 tests, 239 server
  suite, tsc clean. Fixture gate verified BY MUTATION (drop an id = 1 fail; remove a price = 2).
  NOTE: shared-fixtures/firework-shells.json was already on disk — swept into 2af7a0a by a
  `git add -A` during the bench work, not by an earlier Task 2 attempt. Content matched the plan.
  Produced for downstream tasks:
    SHELL_IDS, SHELL_PRICES, MORTAR_PRICES, MORTAR_IDS, MortarId
    LaunchContext = { mortars: string[]; lastWorldThrow: Throw | null }
    ShellState    = { count: number; launchable: boolean; reason: string | null }
    evaluateShell(shellId, count, ctx) / shellStates(held, ctx)
  Reasons emitted (Task 9's picker renders these): BAD_SHELL, NONE_HELD, NEEDS_MORTAR_S/M/L,
  WAITING_FOR_R.

Task 3: complete — b95e0bb. Conditional $inc verified BY MUTATION (drop $gte:1 = concurrency AND
  never-negative tests fail). PLAN DEFECT FIXED: plan seeded users with `robloxUserId`, but the
  model field is `robloxId` and resolveUser UPSERTS on it — tests would have passed for the wrong
  reason against a second, empty user.
Task 4: complete — f0a0884. Grant rides settlement's existing $inc (no second write, no window).
  Added a SAFE case beyond the plan's WIN/LOSS pair — a `result ~= 'LOSS'` impl would pass both.
Task 5: complete — 44ec58f. LaunchSites + NetworkClient.getFireworks/postFireworkSpend + 3 remotes
  + referee in main.server.luau. Reuses lastTape[1].worldThrow and PadSites deckPlacements.
  pushFireworkState is FORWARD-DECLARED (reveal fan-out sits above playerEconomy/PadSites).
  Nested handlerQueue:run on the same lane verified safe — appends to a draining lane, no deadlock.
  OPEN: no part is tagged FireworkLaunchSite, so only deck owners have a site. Studio step.
Task 6: complete — 6bfef2c. Constants stay 14/400. Added a STAGGER CLAMP the plan lacked: without
  it delay scales with overflow and a 50-player volley defers a shell arbitrarily far.
  Wrote docs/superpowers/canyon/fireworks-mobile-floor-2026-08-05.md (the cited provenance).
Task 7: complete — f898aab. DEPARTURE: tests/fixtures/fireworkShells.luau READS the JSON via
  @lune/fs + @lune/serde instead of transcribing it (the plan believed Lune could not). Proven by
  mutation: adding an id to the JSON now fails; a hand-copy would have passed silently.
Task 8: complete — 436f902. Phase player. 3 fixes over the plan: reuse any existing BloomEffect
  (the plan would have re-shipped the v1 bench's stacked-bloom bug), nil-safe colorOf, shellId
  type-guard. Pool parts CastShadow=false.
Task 9: complete — 743665d. Picker + EventBus.HudFireworkLaunch + FireworkState relay on aux.
  Leak grep clean. Fixed a `corner` local that shadowed the file's helper (selene fails on warnings).

PLAN COMPLETE. Gates: 1048 Luau, 249 server, stylua/selene/tsc clean.
REMAINS: the Studio gate (plan lines 2055-2070). Tasks 5, 8, 9 are untested by construction.
  FIRST STEP: tag parts FireworkLaunchSite at the falls dock, clearing edge, mid-canyon bridge.
  Push server + Roblox TOGETHER — the poll loop is still not pcall-wrapped.
