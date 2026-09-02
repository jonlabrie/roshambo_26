---
shelf: practice
updated: 2026-08-28
checked: 2026-09-04
---

# Parallel Threads

Claude sessions run against this repo in git worktrees under `.worktrees/` (gitignored). This
page is the contract between them. **Read it before starting work in any thread.**

## The threads

| thread | worktree | branch | owns |
|---|---|---|---|
| **main** | the repo root | `main` | ⚠ the PLACE FILE and Studio. All implementation. All gating. |
| **design** | `.worktrees/design` | `thread/design` | `docs/superpowers/specs/`, `docs/superpowers/plans/`. **No code, ever.** |
| ~~assets~~ | — | — | ⚠ **RETIRED 2026-08-26** — folded back into main, see below |

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

1. **Never work in a thread that does not own the file.** If a thread needs a change outside what
   it owns, it writes the request into its branch's notes and main makes it.
2. **Rebase on `main` before merging**, and merge to `main` through the main thread — so one place
   holds the integration.
3. ⚠ **`docs/wiki/log.md` WILL conflict every time.** It is append-only and every thread writes to
   it. Resolve by keeping BOTH sides in date order; there is never a real disagreement, only two
   appends at the same offset. Do not "fix" it by rewriting history.
4. **The wiki is the shared brain.** `docs/wiki/index.md` first, in every thread, every session —
   the standing rule, and it is what stops two threads inventing two answers to one question.
5. **Statuses only under `program/`** — see [schema.md](../schema.md). ⚠ Cite it as a markdown
   link, never as a double-bracket wikilink: it sits at the wiki ROOT rather than in a shelf, and
   the resolver only walks shelves, so the wikilink form is dead. A thread reporting its own
   progress writes to `log.md` and its own spec, not to a `world/` page.

## The design thread specifically

Produces **specs and plans only**. It never edits `roblox/`, `src/` or `server/`, so it can never
conflict with anything.

⚠ **This is deliberately the highest-value thread, and the reason is counter-intuitive.** The
expensive failures in this project have not been slow implementation — they have been *building the
wrong thing and finding out at the gate*. The familiar's status display was designed four times
(plumage → worn sashimono → HUD sashimono → unlocks) before a shape survived contact, and each
rejection cost implementation work. Deciding earlier is worth more than typing faster.

⚠ **THE IDENTITY ITEM CAME OFF THIS QUEUE WITHOUT THE THREAD, and that is worth recording rather
than deleting.** It was queued here on 2026-08-27 as the highest-value item; the owner declined
to run it separately — *"I don't want to run a separate design thread, it's too much hassle for
me. Let's get into it here."* It was then traced, decided and written up in the main thread the
same day ([[identity]]). **A queue is not a claim on the work.** The cost of handing an item to
another session is the owner's attention, and for one afternoon's question that cost exceeded
the parallelism — the same arithmetic that retired the asset thread below.

Its queue, in order:
- **juice vs seniority** — the aura shows `currentStreak`; `bestStreak` already exists in the
  profile and in Mongo, so seniority is a display question, not a data one. It may belong with
  grade rather than getting its own glow.
- **grade has no public display** — the deliberate cost of the unlock model, and the thing item 6
  needs before it can close ([[friends-family-baseline]]).
- **onboarding** — deferred from item 2, carries a layout defect in [[parked-defects]].
- **fireworks catalog** — the data half is code; the look half is main's.
- **HUD stats pages.**

## ⚠ The asset thread was retired on its first task, and the reason generalises

It ran once, built the karasu ([[familiars]]), and was folded back into main the same day at the
owner's call: *"let's collapse this thread back to the main one."* Blender work now happens in the
main thread like everything else. Nothing about the pipeline is lost — it lives in
`roblox/tools/blender/karasu_retarget.py`, which is re-runnable end to end, plus the traps on
[[blender-pipeline]].

It looked like the best parallel candidate in the project, and on paper it was: a different tool, a
different directory, no Studio, no place file. **The paper argument was wrong for a reason worth
keeping.**

⚠ **A SPLIT ONLY PAYS WHILE THE OWNER IS DOING SOMETHING ELSE.** This page already said the
constraint is the place file and the owner, and that more threads "do not widen the gate" — but it
stopped one step short. When a feature's two halves BOTH have to land before anything ships, the
owner stops being a gate and becomes the **message bus** between two sessions: relaying a merge,
relaying an import, carrying context from one to the other by hand. The karasu ended with a
four-step hand-off, of which the owner could execute none directly. Parallel wall-clock is worth
nothing if it is spent on the one person who has to be present for both halves.

⚠ **AND THE THREAD BUILT AHEAD OF THE CONSTRAINT.** Nothing selects a bird per player. The unlock
model was decided 2026-08-25 and is unbuilt, so a second bird is *inventory*, not progress on item
6 — which needs roster selection and a public display of grade, both code. An isolated thread is
structurally prone to this: it cannot see the queue it is not blocking on, so "what can this thread
do independently" quietly replaces "what is next". **The independence that makes a thread
parallelisable is the same property that lets it work on the wrong thing.**

**The test before splitting again:** can the split half SHIP without the other half? The design
thread passes — a spec is finished when it is written, and deciding earlier is worth more than
typing faster. The asset thread did not: a mesh nobody can select is not a deliverable.

⚠ **Do not re-create an asset thread for "the rest of the roster."** That was its queue and it is
not a reason. A crane is a different silhouette, not a palette edit — and the crow itself, sold
internally as nearly a data edit, still needed a folded wing, a solid tail, a split bill and a full
rig rename ([[familiars]]). Build birds when a bird is the thing blocking something, in whichever
thread is holding the work.

## Cleanup

```bash
git worktree remove .worktrees/assets      # ⚠ STILL REGISTERED — see below
git worktree remove .worktrees/design      # only when the thread is finished for good
git worktree list                          # what exists right now
```

⚠ **`.worktrees/assets` IS STILL REGISTERED, and this page claimed otherwise for two days.** The
line above read `# done 2026-08-26`; `git worktree list` says otherwise. The branch IS merged into
`main` and the worktree is clean, so the removal is safe and outstanding — run the command, do not
trust this sentence. ⚠ **`git worktree list` is the authority here, never this page**: a prose
claim about live state is wrong the moment the state moves, with nothing positioned to notice.

⚠ **Merge before removing, and merge from the main worktree.** A branch cannot be checked out in
two worktrees at once, so the retiring thread physically cannot merge itself — `git checkout main`
fails inside its own worktree. Commit, then let main do the merge, then remove.

A worktree with uncommitted work refuses to be removed. That refusal is information — look at
what is in it before forcing anything.
