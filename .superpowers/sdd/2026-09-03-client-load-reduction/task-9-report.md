# Task 9 report — teahouse `ModelStreamingMode.Persistent`

**Outcome chosen: 3 — change nothing. Comment recorded at `roblox/src/server/TreatmentApplier.luau:154-156`.**

No behavioural change was made. The deliverable is the recorded finding, both in the file and
in the table below.

---

## Provenance of the line

`model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent` has been in this file since its
**first commit — `0566689` "feat(roblox): TreatmentApplier — build support + shutter (sub-project
D.2)"** — with no comment. `git log -S ModelStreamingMode -- roblox/src/server/TreatmentApplier.luau`
returns that commit and nothing else; `38fd35e` only relocated it when the deck/building compose
landed. Neither commit message mentions streaming, persistence, or a symptom it was fixing.

So: **no recorded reason exists.** It is not the documented stage reason
(`main.server.luau:123-127` — spawn-watchers ~200 studs out plus controllers that capture parts once
at startup); teahouses are built at runtime, after those controllers have started.

## Scale of the cost (larger than the brief assumed)

The brief says the cost scales with *occupied* pads. It does not — it scales with **all** pads.
All 14 entries in `roblox/src/server/PadSites.luau` carry `vacantForm = "dormant-structure"`, and
`VacantState.resolve` returns `{ kind = "structure", loadout = dormant(), lit = false }` for a
vacant pad. So a Structure is built for every pad whether claimed or not, and all 14 are Persistent
for every client, forever.

Two qualifiers on the size of the win:

- **Only the Structure is persistent.** The deck (loose `BasePart`s from `PadOps`), decorations,
  mortars, the nobori and the `PortalControl` all sit in the same site folder as ordinary streaming
  content and already stream out today. So a distant site today is a persistent building over a
  streamed-out deck.
- **`StreamingTargetRadius` is 512** (`main.server.luau:154`). The 14 pads span roughly
  x ∈ [-380, 114], z ∈ [-138, 127] — a max pairwise separation of about **496 studs**. The whole pad
  cluster fits inside one target radius, so on a machine that is not memory-pressured, most
  teahouses would be resident anyway. The win is specifically on a low-end phone, where the engine
  reclaims beyond `StreamingMinRadius` (64) under pressure — which is the target device for this
  plan, so the win is real, just narrower than "uncapped by distance" suggests.

## Step 1 — every client reach into a structure's parts

| Call site | What it reaches | Scope | Classification |
|---|---|---|---|
| `TeahouseController.client.luau` | nothing — HUD panel only; its two `GetChildren()` calls are over its own GUI containers | n/a | **Not a blocker.** No workspace reach at all. |
| `BackDoorController.client.luau:138-176` | `sitesFolder:WaitForChild("MaterializedSite_"..padId, 15)` then folder `ChildAdded` → `Structure` → `Bay_back_<i>` prompts | own pad only (`BackDoorState` carries the player's padId) | **Not a blocker.** The `WaitForChild` is **timed (15s)** and targets the *Folder*, which `ModelStreamingMode` does not govern; the Structure itself is bound via `ChildAdded` + a `structure.ChildAdded` late-descendant catcher. |
| `MoveController.client.luau:408-500` | `FindFirstChild("MaterializedSite_"..padId)` → `Structure`, folder attributes `MountCF`/`DeckSize`/`TeahouseSize` | own pad only, entered from a Move prompt while the player is standing on the deck | **Not a blocker.** Proximity implies streamed in; all lookups are `FindFirstChild` with nil-guards, no waits. |
| `DecorationController.client.luau` | `Decoration` / `Mortar` tagged Models | own pad only (`padId` attribute must equal `myPadId`), tag added/removed signals **plus a 3s `rescanAll` heartbeat** | **Not a blocker.** Already the most stream-tolerant binder in the client, and its targets are already non-persistent. |
| `EconomyController.client.luau:52-140` | `folder:FindFirstChild("PadDeck", true)` as prompt anchor, per site | **all sites** | **Not a blocker, and already exposed.** `PadDeck` is a loose `BasePart` and has *never* been persistent, so this path already lives through stream-out today. It re-checks `b.anchor.Parent == nil` and rebinds on folder `ChildAdded` / `Occupied` change / `EconomyState` echo. |
| `ShojiController.client.luau` (+ `shared/ShojiRun.luau`) | walks **every** `MaterializedSite_*`, binds every `Bay_<side>_<n>` of every Structure, creates a `ProximityPrompt` per slidable bay, and caches `homePivot` / `worldDir` / a `leaf` Model reference per bay | **all sites**, by explicit design (its header: "ANY player can slide a screen on ANY teahouse") | **Partial blocker.** Folder-level lifecycle is sound: `ChildAdded`/`ChildRemoved` on the folder plus `structure.ChildAdded` for late descendants, so a whole-Structure stream cycle should rebind. But there is **no `ChildRemoved` at the BAY level** — a condition only streaming introduces, since a rebuild always replaces the whole Structure. A bay that streams out leaves a stale `BayWatch`/`BayEntry` holding a removed leaf and a destroyed prompt; its return creates a second watch and **overwrites `padState.entries[key]`**, orphaning the first. Consequence is a bounded leak and a `ShojiState` refusal that retargets the wrong entry, not a hang. `shared/ShojiRun.luau` itself is pure math over numbers and attributes — it holds no instance references. |
| `PerchPreferenceController.client.luau:94-129` | `anchorPart(structure)` → `structure.PrimaryPart` → `FindFirstChild("Deck", true)` → `FindFirstChildWhichIsA("BasePart", true)`, per site | **all sites** | **⚠ THIS IS THE BLOCKER-SHAPED ONE.** It captures the anchor **once per Structure arrival** and early-returns when no `BasePart` is reachable yet — with **no `structure.ChildAdded`, no `ChildRemoved`, and no heartbeat** to try again. Under `Persistent` the model and its parts arrive together, so this never bites. Under `Default` a Model can replicate ahead of its own parts — the exact race that `BackDoorController` and `ShojiController` each guard against *explicitly and by name* — and this controller does not. The Favorite prompt on that teahouse would then be silently missing for the rest of the session. `StructureBuilder`/`StructureOps` never assign `PrimaryPart`, so the fallback chain also depends on at least one part having arrived. |
| server: `main.server.luau:2284` (`SetBackDoor`), `:2522` (`SlideShoji`), `:2040` (tour tagging) | `sitesFolder:FindFirstChild(...)` → `Structure` | all sites | **Not a blocker.** The server holds the full DataModel; `ModelStreamingMode` does not affect it. Both handlers already `return` on a nil Structure and label it a "streaming / rebuild race" (F2/F4). |
| `BirdController.client.luau:463-480` (`FamiliarPerch`) | `Attachment`s on the deck rail cap (`PadOps.luau:167-172`) | all sites | **Not a blocker, and already exposed.** Rail caps are already non-persistent, and `perchIsGone` re-checks `a.Parent == nil` on every pick, with an explicit "never cache a perch CFrame" rule. |
| `ChochinSway` / `NorenSway` / `LanternController` / `GlyphDayNight` | tagged parts, some of them inside the teahouse prefab (`ChochinSwing`) | all sites | **Not blockers.** All are `GetTagged` + `GetInstanceAddedSignal` driven, so a stream-in re-registers; `ChochinSway` and `NorenSway` also handle `GetInstanceRemovedSignal`. |

### Long-lived references to a part inside a teahouse the client does not own

Two, both in the all-sites controllers:

- `ShojiController` — `BayEntry.bay` / `.leaf` / `.prompt` / `.value` and `BayWatch.bay`, per bay of
  every teahouse in the world.
- `PerchPreferenceController` — `boundStructure[siteId]` (the Structure) and `prompts[siteId]` (a
  prompt parented into it), per site.

Both are cleaned on the rebuild path. Neither has a bay-level or removal-level path that streaming
would exercise.

## Step 2 — the decision

**Outcome 3.** Neither outcome 1 nor outcome 2 can be established with confidence:

- **Not outcome 1.** `PerchPreferenceController` is exactly the shape the rule names as a blocker —
  it captures parts of *every* structure once, regardless of distance, with no retry. That is a
  real hazard, not a hypothetical one.
- **Not outcome 2 either, and this is the part worth carrying forward.** The narrowing the brief
  prescribes — keep `Persistent` for the claiming player's own structure, drop it for everyone
  else's — **protects the wrong set**. Every dependency found is on *other players'* distant
  teahouses (the all-sites prompt controllers); the owner's own structure is the one they are
  standing on and was never at risk. That narrowing would drop persistence precisely where the risk
  lives. It is also not a narrowing in implementation terms: `ModelStreamingMode` is one property on
  one server-built model, so a per-player variant needs `PersistentPerPlayer` plus
  `Model:AddPersistentPlayer`, plus owner/claim/`PlayerRemoving` plumbing — a feature, not an edit.
- **What is genuinely unknown**, and needs Studio rather than reading: whether a Structure Model can
  in practice replicate to a client ahead of its own parts *here*, i.e. whether the
  `PerchPreferenceController` race actually fires. The codebase asserts that ordering hazard in two
  places in its own words, but asserting it is not observing it.

So the honest state is: there **is** an all-sites dependency with no retry path; its failure is
plausible but unproven; and the prescribed narrowing would not cover it. That is outcome 3.

## The path that would clear this later

Not part of this task, recorded so the next attempt is cheap:

1. Give `PerchPreferenceController` a retry — a `structure.ChildAdded` rebind, or
   `DecorationController`'s 3-second `rescanAll` heartbeat, whichever fits the file.
2. Give `ShojiController` a bay-level `ChildRemoved` (or a `bay.Destroying` hook) so a streamed-out
   bay tears its own watch down.
3. *Then* delete the three lines and run the two-client walk test from Step 3 of the brief.

Steps 1 and 2 are cheap, independently correct hardening — both controllers are already trying to be
resilient to arrival ordering and each is one guard short — and they are worth doing whether or not
the persistence ever comes off.

Also worth noting for phase 2: if the goal is memory on a low-end phone, the *dormant* teahouses are
the fatter target. 13 of the 14 structures on a lightly-populated server are unlit dormant shells
nobody will ever walk into, and they are persistent for the same unexplained reason. A cheaper
dormant form (or streaming only the dormant ones) would take most of the win without touching a
structure any player owns.

## Step 3 — runtime verification

**Not applicable.** No behavioural change was made, so there is nothing to verify at runtime. The
`.rbxl` build and the Lune suite are the whole gate for a comment-only change.

## Gates

From `roblox/`:

- `stylua src tests tools` — clean
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors
- `lune run tests/run` — **1844 passed, 0 failed, 1844 total**
- `rojo build -o /tmp/build.rbxl` — built (no stray `.rbxl` in the repo)

Only `roblox/src/server/TreatmentApplier.luau` was staged. The concurrently-modified
`art/birds/uguisu/*` files and `.superpowers/sdd/.gitignore` were left untouched and unstaged.
