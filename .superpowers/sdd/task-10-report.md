# Task 10 report: tunnel-mouth access-gate survey tool

**Status:** Complete (tool only). PadSites authoring deferred to the user's Studio survey session, as scoped.

**Commit:** `be7621249337305267d3aea1b210ab8d6c470db9` on branch `m4b-zendojo-art-pass`
`feat(roblox): tunnel-mouth access-gate survey tool`

## Files changed

- Created: `roblox/tools/studio/surveyAccessGates.luau` (124 lines, new file only — nothing else staged or modified)

`roblox/src/server/PadSites.luau` was **not** touched, per scope.

## PadSites-load reconciliation applied

The brief's Step 1 code required PadSites via a hardcoded path that doesn't exist in this repo:
```lua
require(ServerScriptService:WaitForChild("Server"):WaitForChild("PadSites"))
```
`default.project.json` maps `src/server` to `ServerScriptService.Roshambo`, not `.Server`. I replaced this with the exact datamodel-scan helper used by the working sibling tool `surveyDeckPlacements.luau`:
```lua
local function findPadSites(): { [string]: any }
    for _, d in game:GetDescendants() do
        if d:IsA("ModuleScript") and d.Name == "PadSites" then
            return require(d) :: any
        end
    end
    error("PadSites ModuleScript not found in the datamodel (is Rojo synced?)")
end
```
`place()` calls `findPadSites()` directly; `bake()` does not need PadSites at all (it only reads geometry back from the placed slabs), matching the brief's own `bake()` which also never touches PadSites.

## Other deviations from the brief's literal code (bugs found and fixed)

1. **CFrame rotation was being dropped.** The brief's `place()` built the slab's CFrame from only the position components (`CFrame.new(place12[1], place12[2] + 4, place12[3])`), discarding the deck placement's orientation even though `deckPlacements` entries are full 12-number CFrame arrays. Since a tunnel-mouth gate's orientation matters (it should start out facing the same way as the deck), I instead reconstruct the full CFrame via `CFrame.new(table.unpack(place12))` and raise it in world space with `P + Vector3.new(0, 4, 0)` (position-only offset, preserving rotation) — the same `table.unpack(...)` pattern the sibling tool uses to rebuild CFrames from stored arrays.

2. **Invalid Luau string-interpolation syntax in `bake()`.** The brief's print line used JS/TS-style `${slab.Name}` (`` `["${slab.Name}"] accessGates = ...` ``) inside a Luau interpolated string — `$` is not part of Luau's `{expr}` interpolation syntax, so this would print a stray literal `$` at best. Worse, the same line also nested literal `{ {` / `} }` braces directly inside the interpolated string without escaping (Luau interpolated strings treat any `{` as starting an expression), which would have been a parse error. I rewrote the line using plain string concatenation instead of interpolation to sidestep both bugs:
   ```lua
   local line = '["' .. slab.Name .. '"] accessGates = { { cframe = ' .. cf .. ", size = " .. sz .. " } },"
   ```

3. **Number formatting.** Rather than the brief's fixed `%.4f` (which pads trailing zeros, e.g. `1.0000`), I copied the sibling's `fmt`/`arr` helpers (trim trailing zeros, collapse `-0` to `0`) so baked output matches the style already used for `deckPlacements` literals in `PadSites.luau`.

4. **Return-value convention.** Matched the sibling's pattern exactly: `place()`/`bake()` return status strings, and the file ends with `if MODE == "place" then return place() elseif MODE == "bake" then return bake() else error(...) end` — works both via MCP `execute_luau` (needs a `return`) and pasted into the command bar.

5. **No `--!strict` pragma**, matching `surveyDeckPlacements.luau` (which also omits it), even though the brief's snippet included one and roughly half the other `tools/studio/*.luau` files do use it. Chose to mirror the direct sibling rather than the brief.

Kept per the brief/instructions: `PAD_IDS = { "T03", "T14" }` remains an editable placeholder at the top with a comment telling the user to set it to their actual tunnel-accessed pads; `MODE` toggle between `"place"`/`"bake"`; folder name `AccessGateSurvey` under `workspace`; slab is a red translucent `Part` (`Color3.fromRGB(200, 60, 60)`, `Transparency = 0.4`, `Size = Vector3.new(8, 8, 1)`), draggable (`Anchored = true`, `CanCollide = false`).

## Verification run (all from `roblox/`)

1. `stylua --check tools/studio/surveyAccessGates.luau` — initially failed (one long concatenation line needed multi-line wrap); ran `stylua tools/studio/surveyAccessGates.luau` to auto-format, then re-ran `--check` → **clean, exit 0**.
2. `selene tools/studio/surveyAccessGates.luau` (repo `selene.toml` has `std = "roblox"` at the root, so plain invocation already picks it up) → **0 errors, 0 warnings, 0 parse errors**.
3. `selene --config selene.toml tools/studio/surveyAccessGates.luau` (explicit form, as requested) → **0 errors, 0 warnings, 0 parse errors** (identical result to #2).
4. `stylua --check src tests && selene src` (repo-standard lint scope) → **clean, 0 errors/0 warnings** — confirms no collateral damage since only a new `tools/studio/` file was added.
5. `lune run tests/run` → **472 passed, 0 failed, 472 total** (unaffected, as expected — this is a pure-module test harness and the new tool is a place-only Studio script that isn't required/tested by it).

## Concerns / notes for the user

- `PAD_IDS` currently holds the brief's guessed placeholder `{"T03", "T14"}` — before running `MODE="place"` in Studio, set it to the real tunnel-accessed pad IDs. If a listed pad doesn't exist in `PadSites`, `place()` warns and skips it (doesn't error), so a stale/wrong ID is safe but silently produces fewer slabs than expected — check the Studio output console for `[survey] unknown pad ...` warnings.
- The tool intentionally does not clamp/validate slab size or orientation during `bake()` — it prints back exactly whatever the human dragged, including any non-uniform Studio-editor scaling. If the user resizes a slab via the Studio Scale tool in a way that skews its `CFrame` rotation component (rare, only happens with negative/mirrored scale operations), the baked rotation numbers would reflect that; worth a visual sanity check of the printed values against the tunnel geometry before pasting into `PadSites.luau`.
- `PadSites.luau` remains fully unmodified, so the feature currently ships with `accessGates` absent for every pad; `gatesForPad` already tolerates this (per Task 5), so nothing is broken — tunnel gates are simply not yet enforced until a human runs this tool and someone pastes the results into `PadSites.luau` in a follow-up change.
