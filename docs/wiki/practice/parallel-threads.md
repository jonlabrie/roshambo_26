---
shelf: practice
updated: 2026-08-26
---

# Parallel Threads

Three Claude sessions run against this repo at once, in git worktrees under `.worktrees/`
(gitignored). This page is the contract between them. **Read it before starting work in any
thread.**

## The threads

| thread | worktree | branch | owns |
|---|---|---|---|
| **main** | the repo root | `main` | ⚠ the PLACE FILE and Studio. All implementation. All gating. |
| **design** | `.worktrees/design` | `thread/design` | `docs/superpowers/specs/`, `docs/superpowers/plans/`. **No code, ever.** |
| **assets** | `.worktrees/assets` | `thread/assets` | `roblox/tools/blender/`, `roblox/assets/` |

## ⚠ Why the split is by HALF, not by feature

Every piece of work here divides into a **code half** and a **look half**, and only the code half
parallelises. The look half needs the owner's eyes and a running Studio, of which there is exactly
one. Measured over the last 60 commits, code collision is NOT the constraint — `main.server.luau`
appeared in 5, `apiV1.ts` in 2. What serialises is:

1. **The place file.** `CanyonWorld`, `Sandbox`, teahouse content and every other place-only thing
   lives in the `.rbxl`, which is **not in git and cannot be merged** — CI fails if one is
   committed ([[rojo-and-place]]). Two threads editing the place is a conflict with no resolution.
2. **The owner.** Nearly every step of the familiar's build ended at "owner looks at it in Studio".
   More threads produce more work for the same single gate; they do not widen it.

**So: only the main thread touches Studio or the place.** If another thread needs something looked
at, it stops and hands over. That is the whole rule.

## Rules

1. **Never work in a thread that does not own the file.** If the asset thread needs a change in
   `src/`, it writes the request into its branch's notes and main makes it.
2. **Rebase on `main` before merging**, and merge to `main` through the main thread — so one place
   holds the integration.
3. ⚠ **`docs/wiki/log.md` WILL conflict every time.** It is append-only and every thread writes to
   it. Resolve by keeping BOTH sides in date order; there is never a real disagreement, only two
   appends at the same offset. Do not "fix" it by rewriting history.
4. **The wiki is the shared brain.** `docs/wiki/index.md` first, in every thread, every session —
   the standing rule, and it is what stops two threads inventing two answers to one question.
5. **Statuses only under `program/`** ([[schema]]). A thread reporting its own progress writes to
   `log.md` and its own spec, not to a `world/` page.

## The design thread specifically

Produces **specs and plans only**. It never edits `roblox/`, `src/` or `server/`, so it can never
conflict with anything.

⚠ **This is deliberately the highest-value thread, and the reason is counter-intuitive.** The
expensive failures in this project have not been slow implementation — they have been *building the
wrong thing and finding out at the gate*. The familiar's status display was designed four times
(plumage → worn sashimono → HUD sashimono → unlocks) before a shape survived contact, and each
rejection cost implementation work. Deciding earlier is worth more than typing faster.

Its queue, in order:
- **juice vs seniority** — the aura shows `currentStreak`; `bestStreak` already exists in the
  profile and in Mongo, so seniority is a display question, not a data one. It may belong with
  grade rather than getting its own glow.
- **grade has no public display** — the deliberate cost of the unlock model, and the thing item 6
  needs before it can close ([[friends-family-baseline]]).
- **onboarding** — deferred from item 2, carries a layout defect in [[parked-defects]].
- **fireworks catalog** — the data half is code; the look half is main's.
- **HUD stats pages.**

## The asset thread specifically

Owns the Blender pipeline and the committed `.rbxm` assets. **The best parallel candidate in the
project**: a different tool, a different directory, no Studio, no place file — the uguisu took three
days without touching anything another thread wanted.

⚠ It still needs main for **import and gating**, which is the one hand-off. Recipe and traps:
[[blender-pipeline]]; as-built: [[familiars]].

Its queue: **the karasu first** — the crow's own purchased model already has the wing bones the
sparrow lacked, the generator keeps species as a data dict and the bake keeps palette as named
colours, so it is much closer to a data edit than the uguisu was. Then the rest of the roster,
which grade unlocks. ⚠ A crane is a different silhouette, not a palette edit — do not price it like
the crow.

## Cleanup

```bash
git worktree remove .worktrees/design      # only when the thread is finished for good
git worktree list                          # what exists right now
```

A worktree with uncommitted work refuses to be removed. That refusal is information — look at
what is in it before forcing anything.
