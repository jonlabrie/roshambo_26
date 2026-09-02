# Fireworks Proving Range — Design

**Date:** 2026-09-01
**Status:** Approved in conversation (owner, 2026-09-01); site = FallsLanding
**Program context:** First of four fireworks sub-projects (range → vocabulary → handheld → distribution). The range exists so every shell after it iterates at the speed of the owner's eye.

## Purpose

Roshambo's financial design depends on a large number of DIFFERENT firework types
(owner emphasis, [[fireworks]]). Authoring them today has no iteration loop: firing a
candidate shell means the full buy-and-spend loop in Play, and there is no way to see
a draft that isn't already shipped and priced. The proving range is the collaboration
machinery: Claude authors draft recipes as data, the owner judges them in Play, in the
real render path, several variants per restart.

**The loop this buys:** Claude writes a variant ladder → Rojo syncs → owner presses
Play, walks to the yard, fires the ladder, says "B, but softer" → stop Play, edit,
repeat. One Play restart per round of judgment, up to five judgments per restart.

**Decided against** (owner, 2026-09-01): an edit-mode/MCP proofing tier. In-Play only
— always the true runtime path. This matches the standing lesson: nothing protects
visuals but pressing Play ([[hanabiya]]).

## 1. The yard

A hanabi-maker's test yard at **FallsLanding** (the behind-falls observation deck,
`CanyonWorld.Arena.FallsLanding`, high at the canyon's western end — [[paths]],
[[viewing-platform]]).

- **Five mortar racks** in a row, named `Rack_A` … `Rack_E`, spaced ~12 studs apart so
  simultaneous ladder bursts read side-by-side without merging. Each rack is a small
  wooden mortar-tube cluster (same grey-cypress treatment as the landing timber:
  `Wood` + `CypressWeathered` + Color 216/214/206, [[falls-dock]]).
- **Physical labels, never BillboardGuis** (owner ruling, 2026-09-01: floating labels
  "always floating strangely in screen space"). Each rack carries a wooden plaque part
  with a `SurfaceGui` letter (A–E) as part of the rack geometry, world-space, lit by
  the scene like everything else.
- **A firing post** — a marked standing spot facing the racks, where the panel's
  proximity prompt lives.
- Built by `roblox/tools/builders/ProvingGround.luau` (builder-script pattern like
  `FallsDock.luau`); output is Rojo-managed under `RoshamboStage` via
  `assets/ProvingGround.model.json`, following the standing convention that Rojo owns
  exactly what `default.project.json` names. Exact placement on the landing is the
  owner's call at build time; the builder takes an origin CFrame.
- Racks are NOT tagged `FireworkLaunchSite` — players must never be offered the
  proving racks as spend sites.

## 2. Drafts

`roblox/src/shared/FireworkDrafts.luau` — pure data, same recipe format as
`FireworkCatalog.RECIPES`, no Roblox globals, runs under Lune.

- Organized as **families of variants**:
  `FireworkDrafts.FAMILIES = { kiku = { v1 = <recipe>, v2 = <recipe> } }`.
- A draft's resolvable id is `"draft:" .. family .. "/" .. variant`
  (e.g. `draft:kiku/v2`). The `draft:` prefix is the namespace that keeps drafts and
  shipped shell ids from ever colliding.
- Committed to git, so draft history and the owner's verdicts survive in the record.
- Deliberately **absent from `shared-fixtures/firework-shells.json`** — the CI
  contract (server sells ⇔ client draws) never demands a price for a draft.

## 3. Firing path and gating

**Everything Studio-gated, nothing allowlisted.** The panel only opens when
`RunService:IsStudio()` is true on the client, and the server handler rejects any
request when `RunService:IsStudio()` is false. Published-place clients can neither see
the panel nor forge a useful request. No userId list to maintain, nothing shippable to
devices by accident.

- New RemoteEvent `RequestProvingFire` added to the `RoshamboRemotes` contract in
  `default.project.json` (edited as text, not a JSON round-trip — the round-trip
  reformats the whole file).
- Client sends `RequestProvingFire(shellOrDraftId, rackName)`. The server handler
  (in `main.server.luau`, beside the `RequestFireworkLaunch` handler) validates
  IsStudio + rack name, resolves the rack's world position, and broadcasts the
  existing **`FireworkLaunched`** event with the same payload shape the spend path
  uses. It performs **no inventory spend and no backend call**.
- `FireworkController.client.luau` resolves the id: first in `FireworkCatalog.RECIPES`,
  then (ids with the `draft:` prefix) in `FireworkDrafts`. Unknown id → silently
  ignored, as today. Everything downstream — director budget, distance LOD, pooled
  slots, sounds — is the production path, untouched.
- The director's concurrent-shell budget stays engaged for proving fires. A ladder
  salvo of five is well inside the ~12–16 cap; if a proving session ever hits the cap,
  that is signal, not noise.

## 4. The panel

A dev panel following the `ShopController.client.luau` interaction pattern
(ProximityPrompt at the firing post; while open, the same `MouseBehavior = Default`
render-step grip that `322d948` proved — do not reinvent the cursor handling).

- Lists every draft family (with its variants) and every shipped catalog shell.
- **Three fire modes:**
  - **Single** — one id at one chosen rack.
  - **Ladder** — all variants of a family, one per rack A→E in variant order,
    requests sent the same frame, bursting side by side for comparison.
  - **Sequence** — all variants of a family from `Rack_C`, one every 2 s, for shells
    whose read needs clean air.
  - Both multi-modes are client-side sequencing over the same single-fire remote —
    the server never learns about modes.
- **Night toggle** — while on, the panel controller locally overrides
  `Lighting.ClockTime` to show-time night (22:00) and restores the prior value when
  toggled off or the panel closes. Client-side only, so it cannot fight the shipped
  day-night cycle ([[day-night]]) — the override is the local player's view alone.

## 5. Promotion (draft → shipped)

When the owner approves a variant:

1. Recipe moves from `FireworkDrafts` into `FireworkCatalog.RECIPES` under its real
   shell id (the `draft:` prefix dies at promotion).
2. The id joins `shared-fixtures/firework-shells.json`.
3. `server/src/fireworks.ts` gets the id's price and requirements.

The existing CI contract already guards this: both sides' tests assert coverage of
every fixture id, so a half-promoted shell fails CI. ~~No new machinery.~~
**Corrected 2026-09-04, by the first real promotion:** there was a FOURTH, unguarded
step — the shop panel's display name/order tables, hardcoded in `ShopController`.
The kiku shipped server-side and silently missed the counter. Display metadata now
lives in `src/shared/ShellDisplay.luau`, fixture-tested, so the pipeline is truly
three-files-plus-nothing again.
**Amended 2026-09-04 (deck mortars):** a gear-requiring shell adds a FIFTH entry —
its required mortar tier in `MortarPlacement.SHELL_MORTAR`
(`roblox/src/shared/MortarPlacement.luau`), which decides which deck tube the shell
launches from. This one IS CI-guarded from day one: `shared-fixtures/firework-shells.json`
carries a `mortars` map and both suites assert their tables against it
(`server/src/fireworks.test.ts` for `REQUIREMENTS`, `MortarPlacement.spec.luau` for
`SHELL_MORTAR`), so a half-promoted gear shell fails CI rather than silently
launching from the eye-level fallback.

Rejected variants are deleted from `FireworkDrafts` in the same commit as the
promotion (or a pruning commit), with the verdict in the commit message — the git
history is the archive, the working file stays short.

## 6. Tests (Lune, `roblox/tests/`)

- `FireworkDrafts.spec.luau` — every draft in every family passes recipe validation:
  phase `kind` is one the controller knows, every burst phase names a non-empty
  `texture` (the documented blank-sky trap), colors are 3-element 0–255 arrays,
  `at` times are non-negative and non-decreasing. A typo'd draft fails
  `lune run tests/run`, not silently renders nothing in the owner's Play session.
- The validation function lives in a shared module,
  `roblox/src/shared/FireworkRecipes.luau`, so the same rules can later validate
  catalog entries and promoted shells — one schema, not two.
- Rack/ladder assignment logic (variant order → rack mapping, sequence timing) is
  pure and spec'd under Lune.
- The panel UI and the yard geometry are NOT unit-tested — geometry is protected only
  by pressing Play ([[hanabiya]] lesson), and the owner's eye is the gate.

## Non-goals (separate sub-projects, in program order)

- **Vocabulary** — new phase kinds (multi-break, ring, crossette, strobe, kamuro,
  palm, timed sub-bursts). The range fires what the controller can already draw;
  vocabulary grows as shells demand it.
- **Handheld** — items held in the hand (sparkler, roman candle), avatar attachment.
- **Distribution** — taxonomy, pricing tiers, Robux Developer Products, the
  shared-show SKU (Lens B, [[fireworks]]).
- Perf benching — the parked `FireworkBench` stays parked; the range is a visual
  proofing tool, not a measurement harness, and must never self-ramp.
