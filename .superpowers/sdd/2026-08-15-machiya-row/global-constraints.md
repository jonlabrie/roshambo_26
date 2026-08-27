## Global Constraints

- Work from `roblox/` for all Luau commands: tests `~/.rokit/bin/lune run tests/run`; regenerate models `~/.rokit/bin/lune run tools/genmodels`; lint `~/.rokit/bin/stylua --check src tests tools && ~/.rokit/bin/selene src tools` (selene FAILS on warnings — CI scope, match it).
- **The snapshot gate:** after ANY change to `Machiya.luau`/`MachiyaShops.luau` that should not move 花火屋, run genmodels then `git diff --exit-code roblox/assets/Hanabiya.model.json`. A non-empty diff fails the task.
- Committed `assets/*.model.json` are generated — never hand-edit. They must be byte-stable across arm64/x86_64 (no trig-derived floats in specs except through `Spec.rotY`/`Spec.yaw`, which are JsonEmit-rounded and CI-proven).
- New stage models need BOTH: an entry in `roblox/default.project.json` under `RoshamboStage` (`"<Name>": { "$path": "assets/<Name>.model.json" }`) AND the name + comment in `roblox/src/shared/WorkspaceConvention.luau`'s `DECLARED_STAGE_CHILDREN`. Rojo re-reads project.json only on plugin reconnect.
- Spec §1 guards run per shell: top ≤ `ArenaLayout.towerTopY − 9.0`; kamoi 6.8; eave encroachment aerial-only; timber faces exactly on the frontage plane, stucco set back (flush-outside-edges + derive-from-what-it-touches, `docs/wiki/practice/`).
- Owner-surveyed envelopes are literals, never derived. 1 stud ≈ 1 foot for dressing scale sanity (a counter is ~3.0, a shelf ~5–6, a teacup ~0.25).
- **OWNER GATE protocol** (tasks 4–7): after genmodels + tests pass, STOP. Report to the controller that the shell is ready to view (owner reconnects Rojo / syncs, looks in Studio). ONE visual attempt — never self-judge and iterate ([[stop-and-ask-after-each-attempt]] is a standing rule). The controller relays corrections; treat them as new requirements.
- No toolbox imports, ever. No signage copy for the sports book (wager-language ruling). Kanban textures only via the existing glyph pipeline and only if a task explicitly says so — otherwise geometry/blank boards.
- Wiki (`docs/wiki/`): each owner gate and each shipped shell updates `program/item-4-merchant-row.md` and appends a `log.md` entry (`## [YYYY-MM-DD] gate | ...` / `ship | ...`), same commit. Wiki lint must stay clean: `source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs` (repo root).
- Commits end with:

  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  ```
- Never commit `.rbxl`/`.rbxlx`. Studio MCP calls need `studio_id` from `list_roblox_studios` and `datamodel_type: "Edit"`.

---
