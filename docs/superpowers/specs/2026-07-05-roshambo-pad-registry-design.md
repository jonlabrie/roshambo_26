# Roshambo Pad Registry — Design (per-server occupancy model)

**Status:** design approved in brainstorm (2026-07-05); pre-planning. Implementation-architecture spec for a B increment — the pad occupancy model. Pure, Lune-tested.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** consumes the `PadSpec` from the [pad-system spec](2026-07-05-roshambo-pad-system-design.md) (sub-project B increment 1). This increment is the state model behind "the server finds an empty pad on spawn" — sub-project D's runtime assignment and a later vacant/claimed-visuals increment both read it.

## Problem

The [meta-game](2026-07-04-roshambo-metagame-design.md) has the server assign an empty **pad** to a player's structure on spawn, and release it on leave. That requires a per-server-instance model of which pads exist and which are vacant vs claimed. This increment builds that model, pure and testable, decoupled from the runtime (D) and from persistence (C).

## Goals

- A `PadRegistry` that tracks a set of pads and their occupancy, with a deterministic "find/claim first vacant" — the core spawn-assignment operation.
- Pure Luau (Lune-tested), no Roblox datatypes, no `math.random` — no Studio needed.

## Non-goals (later increments / other sub-projects)

- Persistence of occupancy — the registry is **in-memory per server**; who-owns-what across sessions is C/D.
- Assignment policies beyond first-vacant (nearest-to-spawn, premium-tier gating).
- The vacant/claimed **visuals** (dark base shell / pocket garden) — a following increment reads this state.
- Registering pads from a live source or wiring to spawns — that is D; here a caller registers pads explicitly.

## Architecture

A stateful object (`.new()` + methods), matching the repo's stateful modules (`ThrowBuffer`, `PlayerProfiles`). D creates one `PadRegistry` per Roblox server and registers that server's pads at startup.

**Pad record:** `{ id: string, spec: any, occupant: string? }` — `spec` is the `PadSpec` (opaque to the registry); `occupant` is `nil` (vacant) or an opaque `ownerId` string.

**API:**

```
PadRegistry.new() -> Registry

Registry:register(id: string, spec: any) -> boolean
  -- add a vacant pad; false (ignored) if id already registered.

Registry:findVacant() -> string?
  -- id of the first vacant pad in REGISTRATION order (a stable ordered id list,
  -- since Luau hash maps are unordered); nil if none vacant.

Registry:claim(id: string, owner: string) -> boolean
  -- mark claimed by owner; false if id unknown or already claimed.

Registry:claimVacant(owner: string) -> { id: string, spec: any }?
  -- the spawn op: find first vacant + claim atomically; returns the pad record
  -- (id + spec, so the caller can build/materialize on it); nil if full.

Registry:release(id: string) -> boolean
  -- mark vacant; false if id unknown. (Releasing an already-vacant pad returns true, a no-op.)

Registry:get(id: string) -> { id: string, spec: any, occupant: string? }?
  -- the pad record, or nil if unknown.
```

**Determinism:** the registry keeps an insertion-ordered array of ids alongside the id→record map. `findVacant` / `claimVacant` iterate that array and return the first vacant, so repeated claims hand out pads in registration order — testable and reproducible.

## Testing

Lune unit tests only (precedent: `PadPlanner.spec`, `PlayerProfiles.spec`): construct a registry, register a few pads, and assert:
- `register` adds vacant pads; duplicate id returns `false` and does not overwrite.
- `findVacant` returns the first-registered vacant id; `nil` when full.
- `claim` succeeds on a vacant pad, returns `false` on unknown id and on already-claimed.
- `claimVacant` returns `{id, spec}` of the first vacant, marks it claimed, and hands out pads in registration order across repeated calls; `nil` when full.
- `release` frees a claimed pad (then `findVacant` returns it again); `false` on unknown id; no-op `true` on an already-vacant pad.
- `get` returns the record with the correct `occupant`; `nil` on unknown id.

## v1 deliverables

1. `roblox/src/shared/PadRegistry.luau` — the module.
2. `roblox/tests/PadRegistry.spec.luau` — the Lune tests above.

## Build order

Define the record + API shapes → TDD the lifecycle (register → findVacant → claim/claimVacant → release → get) with all edge cases → commit.
