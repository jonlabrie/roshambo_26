# Task 1 report: extract the shop spec

**Status: DONE**

## What moved where

- New `roblox/tools/builders/MachiyaShops.luau`: the `Shop` type and `MachiyaShops.hanabiya`
  registry entry, exactly per the brief's Step 3 template (envelope, yaw, frontage, interior).
- `roblox/tools/builders/Machiya.luau`:
  - Signature changed to `function Machiya.build(palette: any, _layout: any, shop: any): any`.
  - New first statement: `assert(shop.frontage == "open" and shop.interior == "full" and shop.yaw == 0, "only the hanabiya configuration is implemented until Task 3")`.
  - The five literal declarations became shop-derived bindings, **in place**, so every comment
    that already sat next to (above/below) each of these lines needed no relocation — only the
    right-hand side of the line itself changed:
    - `local X0, X1 = shop.envelope.x0, shop.envelope.x1 -- west, east`
    - `local Z0, Z1 = shop.envelope.z0, shop.envelope.z1 -- frontage (north, onto the promenade), back (south, into the cut)`
    - `local FLOOR = shop.envelope.floorY -- finished floor, = the karesansui datum`
    - `local STOREY_H = (shop.storeys and shop.storeys.ground) or 9.0 -- ground storey (owner's gate: +3; ...)`
    - `local UPPER_H = (shop.storeys and shop.storeys.upper) or 5.0 -- the closed lattice storey`
  - Everything that used to be module-level code between those five declarations and the old
    `function Machiya.build(...)` line (`SHORO_TOP`, `MIN_SHORO_GAP`, `W`/`D`/`CX`/`CZ`, all the
    roof/stucco/stair/etc. derived constants, `flushX`, `rotX`) is now lexically inside the
    function — this was mechanically necessary, not optional, because all of it consumes `X0`
    etc., which only exist once `shop` is bound as a parameter. The old duplicate
    `function Machiya.build(palette: any, _layout: any): any` line (previously the split point)
    was deleted since the function now opens once, at the top.
  - `stylua` reformatted the newly-nested block's indentation (4 spaces) — no textual/logic
    changes, purely whitespace.
  - Root model naming: `Machiya.build` itself calls `Spec.model("Hanabiya", children)` at the
    very end (not genmodels — genmodels only keys its `OUTPUTS` table with `"Hanabiya"`, a
    separate, unrelated naming). Per rule 1 ("the root model must be built with `shop.name`"),
    changed this call to `Spec.model(shop.name, children)`. Since `MachiyaShops.hanabiya.name ==
    "Hanabiya"`, this is a no-op for the byte gate.
  - The file's top header comment (lines 1–12, "EVERY DIMENSION BELOW IS THE OWNER'S...") was
    left untouched. It is not one of the five relocated literals — it's a general framing comment
    for the file, and plenty of still-file-local owner's-gate numbers remain in `Machiya.luau`
    (`POST_W`, `COUNTER_STANDOFF`, etc.), so the claim still holds for what's left in this file.
    `MachiyaShops.luau` carries its own, separate ownership comment (from the brief's exact
    template) for the envelope specifically.
- `roblox/tools/genmodels.luau:55`: `Machiya.build(ZenDojo.palette, ArenaLayout,
  MachiyaShops.hanabiya)`, with `local MachiyaShops = require("./builders/MachiyaShops")` added
  alongside the existing `Machiya` require.
- `roblox/tests/Machiya.spec.luau:8`: `Machiya.build(ZenDojo.palette, ArenaLayout,
  MachiyaShops.hanabiya)`, with `local MachiyaShops = require("../tools/builders/MachiyaShops")`
  added. No other lines in this spec file changed — it keeps its own separately-declared
  `X0`/`Z0`/`FLOOR`/etc. literals for its assertions, per the brief's "call sites only" scope.
- New `roblox/tests/MachiyaShops.spec.luau`: the registry test from the brief's Step 1, verbatim.

## RED/GREEN evidence

**Step 2 — RED** (`cd roblox && ~/.rokit/bin/lune run tests/run`, before creating
`MachiyaShops.luau`):

```
error requiring module "../tools/builders/MachiyaShops": could not resolve child component "MachiyaShops"
[Stack Begin]
    Script '[C]' - function 'proxyrequire'
    Script '__mlua_require', Line 13
    Script '/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/MachiyaShops.spec', Line 4
[Stack End]
...
```

**GREEN** (same command, after creating `MachiyaShops.luau`, before touching `Machiya.luau`):

```
1110 passed, 0 failed, 1110 total
```

(1109 pre-existing tests + the 1 new `MachiyaShops` test. The `[WARN] [QUEUE] dropping request
for u: queue full (8)` / `handler error for u: ...HandlerQueue.spec:80: boom` lines are
pre-existing intentional-failure noise from `HandlerQueue.spec.luau`, unrelated to this task —
present in both runs.)

**Step 6 — final suite** (after the full `Machiya.luau` refactor and both call-site updates):

```
1110 passed, 0 failed, 1110 total
```

## Byte-gate output

```
$ ~/.rokit/bin/lune run tools/genmodels
wrote assets/BonshoRig.model.json
... (all 17 outputs) ...
wrote assets/Hanabiya.model.json
...

$ git status --porcelain assets/
(empty)

$ git diff --exit-code assets/Hanabiya.model.json
(exit 0, no diff)
```

`genmodels` regenerates every `assets/*.model.json`; `git status --porcelain assets/` came back
empty, confirming not just `Hanabiya.model.json` but every other generated asset was untouched
too.

## Suite / lint output

```
$ ~/.rokit/bin/stylua --check src tests tools
(exit 0, no output)

$ ~/.rokit/bin/selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

## How the root gets named

`Machiya.build` itself names the root model (`Spec.model(shop.name, children)`, formerly the
literal `"Hanabiya"`), not `genmodels` — `genmodels`'s `OUTPUTS` table key (`["Hanabiya"] =
...`) is a separate, incidental naming of the same string for the *output table*, unrelated to
the model's own `Name` property. Both now happen to read `"Hanabiya"` via `shop.name` /
`MachiyaShops.hanabiya.name` respectively, but they're independent — genmodels' key would keep
working even if it disagreed with the model's internal name.

## Self-review findings

- Read the full `git diff` for all five changed/new files. No comment was orphaned or discarded;
  every comment block that existed adjacent to one of the five relocated literals stayed
  adjacent to it (the diff shows only the literal's right-hand side changing, not the comment
  lines).
- Confirmed no other line in the 1000+-line body was touched besides the mechanical `stylua`
  reindentation and the single `Spec.model("Hanabiya", ...)` → `Spec.model(shop.name, ...)`
  change.
- Confirmed `tests/Machiya.spec.luau`'s diff is exactly the two lines the brief scoped ("call
  sites only") — its own duplicate envelope literals (used for its assertions) were left as-is,
  matching "the existing test suite ... must stay green untouched except for its one build()
  call site."
- Verified no unused locals were stranded by the refactor (selene 0 warnings confirms this —
  selene fails on warnings and the run was clean).
- Confirmed `roblox/tests/MachiyaShops.spec.luau` and `roblox/tools/builders/MachiyaShops.luau`
  match the brief's templates verbatim (Steps 1 and 3).
