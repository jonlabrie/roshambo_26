# Roshambo — Roblox client (`roblox/`)

The ZenDojo arena: the Roblox front-end of Roshambo. Luau modules are dependency-injected
and never `require` each other, so the same files run under Lune (tests) and Roblox (runtime).
See the repo-root `CLAUDE.md` for the architecture overview.

## Toolchain

Requires [Rokit](https://github.com/rojo-rbx/rokit) — run `rokit install` once from `roblox/`.

```bash
lune run tests/run          # headless Luau tests (bespoke harness)
lune run tools/genmodels    # regenerate assets/*.model.json from the Luau builders
rojo serve                  # live-sync src/ + assets/ into an open Studio place
rojo build -o build.rbxl    # build a THROWAWAY place from disk (NOT the shipping artifact — see below)
stylua --check src tests && selene src   # format + lint (canonical scope)
```

## Source of truth: what's in Rojo vs. what's in the place

This is the single most important thing to understand before editing. The place is a **mix**
of Rojo-managed nodes and place-only state, and they have **opposite** source-of-truth rules.

Rojo is a **one-way** sync: files on disk → a running Studio place. It only manages the subtree
declared in `default.project.json`. Everything else in the place it never reads, writes, or deletes.

### Rojo-managed (disk is the source of truth)

`default.project.json` maps exactly these. Edit them on disk; Rojo pushes them into the place.
Hand-edits to these nodes in Studio are **disposable** — the next sync overwrites them.

| Place node | On-disk source |
|---|---|
| `ReplicatedStorage.RoshamboShared` | `src/shared/` (Luau) |
| `ReplicatedStorage.RoshamboRemotes` | declared inline in `default.project.json` |
| `StarterPlayerScripts.RoshamboClient` | `src/client/` (Luau) |
| `ServerScriptService.Roshambo` | `src/server/` (Luau) |
| `Workspace.RoshamboStage.{BonshoRig, Shoro, Waterwheel, BellDrive, ThrowDrum, Overlook, SwitchbackDeck, ArenaSpawn}` | `assets/*.model.json` (baked from `tools/builders/` via `lune run tools/genmodels`) |

To change a baked model (e.g. the SwitchbackDeck): edit the builder in `tools/builders/`,
run `lune run tools/genmodels` to regenerate the `.model.json`, then let Rojo sync it.
**Do not hand-edit the model in Studio** — it will reappear from disk on the next sync.

### Place-only (the saved `.rbxl` is the source of truth)

Everything NOT in the table above lives only inside the saved place file. Rojo never touches it.
**It has no on-disk home — if you don't save the place, it's gone.**

- All hand-built canyon geometry: `CanyonPaths`, `PathSteps` / `PathExtension` / `DescentPath`,
  `RetainingWalls`, `PathRailings` / `PathLanterns`, `CanyonTeahouses`, `TeahousePrototype`,
  `PathDraft` markers, `TempBridgeAbutments`, etc.
- **Terrain** — all voxels, carved tunnels, sculpted pools. Terrain is not in Rojo at all.
- Lighting / Atmosphere settings, `ClockTime`.
- Published mesh assets (`rbxassetid://…`) live on Roblox's servers; the place holds only references.

Most canyon work is authored directly in Studio (by hand or via the Studio MCP `execute_luau`),
which writes straight into place-state and **does not involve Rojo**.

## Workflow rules

1. **Start Rojo (`rojo serve` + Connect in the Studio plugin) before editing `src/` code or
   running the builder pipeline.** Otherwise the live place keeps the old code/models until you
   connect (recoverable — disk wins on reconnect — but confusing).
2. **Geometry-only sessions don't need Rojo.** Hand-built / MCP-built canyon geometry goes
   straight into place-state regardless.
3. **Always save the place** after ad-hoc geometry work — it has no on-disk backup.
4. Keep `GameRules.luau` in sync with `server/src/engine/GameRules.ts` (both run
   `shared-fixtures/game-rules.json`; drift fails CI).

## Deploying

**Ship by publishing the saved place from Studio** (File → Publish to Roblox).
That captures everything — Rojo-managed nodes *and* all place-only geometry/terrain.

**Do NOT ship via `rojo build`.** It builds a place from disk containing *only* the
`default.project.json` tree — every hand-built path, teahouse, wall, and all terrain would be
**missing** (~95% of the canyon lives only in the saved place). `rojo build` is fine for a
throwaway test build; it is not the shipping artifact.

Pre-publish checklist: Rojo connected so `src/` + `assets/` are current in the place → save the
place → `lune run tests/run` green → publish from Studio.
