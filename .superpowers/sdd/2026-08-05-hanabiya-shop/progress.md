# SDD ledger — plan: docs/superpowers/plans/2026-08-05-hanabiya-shop.md

Branch: m4b-zendojo-art-pass (NOT a worktree — deliberate: Rojo/Studio is connected to this
  checkout, so an isolated worktree would detach the live Studio session from the code under test.
  The branch is not main/master.)
Base at start: dd572bb

Pre-flight scan (no conflicts found; two things a reviewer should know rather than flag):
  - Task 4 patches tools/builders/Spec.luau to honour an explicit `className` (the gable ends need
    WedgePart). Shared file. No existing builder passes `className`, so nothing else changes shape.
  - Task 5 edits the Kanban part Task 4 created and extends Task 4's spec file. Sequential by
    design, not a conflict.
  - The gable WedgePart rotation matrices are REASONED, not run. The plan's tests assert size and
    position only; orientation is a Studio-gate item and is called out as such.

Task 1: catalog carries shell + mortar prices (server TS)
Task 2: purchase pushes FireworkState (roblox server)
Task 3: ShopThreshold pure module
Task 4: the Machiya builder + genmodels + project.json
Task 5: the kanban (SurfaceGui, small canvas)
Task 6: ShopController panel + EventBus + server-side tagging
Task 7: terrain cut, ishigaki, chōchin, Studio gate — OWNER-RUN, not dispatchable

Task 1: complete — 2fd502d. Spec ✅ / quality ✅, no findings. catalog gains
  {fireworks: SHELL_PRICES, mortars: MORTAR_PRICES}; PRICES keys verified un-shadowed (deck,
  teahouse, portal, decoration all survive the spread). Mutation genuine: deleting ishibana's
  price failed both new tests, restored (fireworks.ts zero diff). 251 server tests, tsc clean.
  Produces for Task 6: EconomyState.catalog.fireworks / .catalog.mortars.

Task 2: complete — ba0ddaf. Spec ✅ / quality ✅, no findings. One guarded call after the
  RequestPurchase handler's TERMINAL echoEconomy (line ~1519); the handler's three other
  echoEconomy calls are early-return paths, so a FAILED purchase cannot push state. Prefix
  offsets verified by count (firework:=9, mortar:=7) and cross-checked against economy.ts's
  startsWith. Queue nesting is the SAME pattern RequestFireworkLaunch already ships.
  BEHAVIOUR UNVERIFIED — no harness loads main.server.luau. Studio-gate item.

Task 3: complete — e33e8bf. Reviewed BY THE CONTROLLER inline (30-line pure module; a mutation
  check beats a second read). Verified independently: 1056 tests, stylua+selene clean. MUTATION:
  widening the z-bound by 2 studs fails exactly "THE PROMENADE IS NOT THE SHOP" — the one-stud
  inset is genuinely guarded, restored after.
  Produces for Task 6: ShopThreshold.isInside(pos, box), ShopThreshold.FRONT_INSET = 1,
  Box = { x0, x1, y0, y1, z0, z1 }.

Task 4: complete — bf7c7eb. The implementer DIED mid-run (API connection closed) with everything
  written but uncommitted; the controller verified and committed rather than re-dispatching.
  Verified: 1069 tests, stylua+selene clean, regeneration idempotent, and ONLY Hanabiya.model.json
  changed after the Spec.part patch (the other 7 assets byte-identical => behaviour-preserving).
  MUTATION: TOP=137 fails "NOTHING RISES ABOVE THE OWNER'S TOP". Restored.
  TWO THINGS THE IMPLEMENTER FOUND THAT THE PLAN MISSED, both accepted:
   - WorkspaceConvention.DECLARED_STAGE_CHILDREN needed "Hanabiya" or the convention check fails.
   - THE PLAN CONTRADICTED ITSELF: its noren sat at z41.9 (2.1 studs into the reserved promenade,
     at head height) while its own promenade test forbids anything north of z44 below FLOOR+6.
     Noren and kanban moved just inside the frontage. The test was right, the prose was wrong.
  UNVERIFIED BY ANYTHING: gable WedgePart orientation. Reasoned, not run. Studio-gate item.
  Produces for Task 5: the Kanban part. For Task 6: the Threshold part (inset 1 stud, z45..52).

Task 5: complete — 66b71df. DONE_WITH_CONCERNS, all three concerns are correct and accepted.
  Verified: 1070 tests, stylua+selene clean, Kanban z=44.2 (inside the frontage, as corrected).
  PLAN DEFECT FOUND AND FIXED BY THE IMPLEMENTER: my UDim2 encoding `{1,0,1,0}` DOES NOT BUILD —
  proven against real `rojo build` 7.7.0 ("Expected UDim2, got an array of four numbers"). Correct
  form is the tagged `{ UDim2 = { { 1, 0 }, { 1, 0 } } }`, verified round-trip with asymmetric
  values. Nothing else in the repo encodes a UDim2, so the plan's guess had no precedent to copy.
  UNVERIFIED: whether Roblox's built-in fonts render 花火屋 without tofu. Studio-gate item; the
  fallback is an uploaded PNG.

Task 6: complete — aa5dec8. Verified: 1070 tests, stylua+selene clean. Precise leak check clean —
  the only "mortar:" hits are the id list and display names; every price reads from state.catalog.
  Implementer deviation ACCEPTED: dropped an unused `INK` local the brief carried, which tripped
  selene's unused_variable and would have failed the zero-warning gate.
  Implementer was RIGHT that my Step-5 grep is imprecise (fires on any `= 1`); re-run precisely by
  the controller instead.
  UNVERIFIED: panel opening, tag replication, purchase round-trip. All Studio-gate.

Task 7: NOT DISPATCHABLE — owner-run in Studio (terrain cut, ishigaki, chōchin, the gate).

WHOLE-BRANCH REVIEW (opus, dd572bb..aa5dec8): 1 Critical, 2 Important, 6 Minor.
  THE CRITICAL IS WHY THIS STEP EXISTS. Buying a shell wiped the Roblox server's in-memory
  maxDeckSize/portalOwned for the session: apiV1's firework: branch returns early WITHOUT those
  fields, and main.server.luau then assigned them unconditionally. Consequences: buy-to-claim
  prompts on owned perches, home portal stops opening, and recomputeAllAccess() dropped the pad
  from `occupied` so a FRIENDS-ONLY DECK OPENED TO EVERYONE — an access check failing OPEN.
  Invisible to all 6 per-task reviews: task 1 owned the response shape, task 2 the push, task 6
  made the path reachable. The decoration branch already had an early return for this exact
  hazard, with a comment saying so.

Fix round 1 — 9479209 (opus). All 6 fixed in one commit; scoped re-review confirmed each and found
  no new defects. Verified e.totalPoints is NOT skipped by the new early return. Also fixed for
  free: mortar: was falling into the pad-rebuild branch, demolishing the owner's deck for a
  purchase that changes neither deck nor teahouse.
Residual adjudicated + 29aed69: MORTAR_BELOW decides `live`, duplicating economy.ts's tier
  predicate. PARKED, not fixed — it fails CLOSED and the server re-validates. The COMMENT was
  fixed, because it claimed the opposite; a comment that makes a duplication read as innocent is
  how the last three instances of this defect class survived. Clean fix noted: server-computed
  mortarStates on the wire, mirroring shellStates.

PLAN COMPLETE through Task 6. Pushed c195d64..29aed69.
REMAINS: Task 7 — OWNER-RUN in Studio. Rojo sync, terrain cut (tools/studio/cutHanabiyaSite.luau),
  finish-smooth, ishigaki, chōchin, then the 10-item gate. Three things NOTHING has verified:
  gable WedgePart orientation, whether Roblox's fonts render 花火屋 without tofu (and the kanban's
  90px text on a 52px-tall canvas), and whether the panel opens at all.
