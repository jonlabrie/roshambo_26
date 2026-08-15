# Project Wiki — Design

**Date:** 2026-08-15
**Status:** Approved
**Pattern source:** Karpathy's "LLM Wiki" gist (https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), adapted.

## Problem

Project memory lives in 81 append-narrative files (~5,300 lines) in the Claude
auto-memory directory, outside git. Memories accrete session stories; superseded
paragraphs are never retired. Observed failure: `zendojo-arena-amplified` carried both
"THE SQUARE AS OF 2026-08-14 — DONE" and an untouched 2026-07-23 plan still listing the
falls dock as future work, after the dock was built and closed. Statuses, as-built
records, and standing rules are interleaved in the same files, so nothing can be trusted
anywhere in particular. There is no lint operation and no version history.

## Solution shape

A maintained, interlinked wiki in the repo — Karpathy's operations (integrate-don't-
append, index/log split, periodic lint) with a page taxonomy purpose-built for this
project instead of his entities/concepts/sources split. The wiki is the single
authority for project knowledge AND work tracking. The auto-memory dir shrinks to
user/feedback memories plus a pointer.

Adaptations from the gist, and why:

1. **Sources are sessions, not documents.** There is no ingest folder. The wiki updates
   at the moment decisions happen (owner gates, drops, rule corrections), enforced by
   update triggers in the schema, in the same commit/session as the event.
2. **Work tracking is first-class.** The gist's wiki is knowledge-only; our primary rot
   is status. A dedicated `program/` shelf is the only place statuses may live.
3. **Most truth is already recorded** in git, specs, plans, and SDD ledgers. The wiki
   holds only the non-derivable layer: decisions, gates, place state, current status,
   standing rules. It cites the raw layer, never duplicates it.
4. **The Roblox place is the strongest justification**: a large mutable state store
   invisible to git (place-only content, saved/published state, owner gates). Wiki
   pages are the only record of it.
5. **YAGNI on tooling**: ~60 pages at steady state; index-file navigation, no search
   engine, no embeddings.

## 1. Layout & page format

```
docs/wiki/
  index.md      # catalog: one line per page per shelf — name + coverage, never status
  log.md        # append-only chronology
  schema.md     # the wiki's own rules (contract below) + lint checklist
  program/      # STATUS shelf — the only home of statuses
    friends-family-baseline.md   # the board: items 1–8, one line + link each
    item-<n>-<name>.md           # per-item: scope, gates, decisions, drops
    parked-defects.md            # economy race, decorations ownership, onboarding cards…
  world/        # AS-BUILT shelf — one page per structure/zone/system-in-the-place
    bell-tower.md, hanabiya.md, torii.md, falls-dock.md, foliage.md, …
    place-state.md               # place-only content, saved/published, publish checklist
  practice/     # HOW-WE-WORK shelf — standing rules, recipes, traps
  systems/      # thin pointers into code/deploy truth (deploy topology, DB topology…)
```

- Pages are Obsidian-compatible markdown; `[[wikilinks]]` are the link style (existing
  house style). `docs/wiki/` works directly as an Obsidian vault.
- Frontmatter is minimal: `shelf`, `updated` (absolute date), and `status` **only** on
  program pages.
- `log.md` entry format: `## [YYYY-MM-DD] <kind> | <title>` with kinds
  `gate`, `ship`, `decision`, `drop`, `defect`, `migrate`, `lint`, `audit`.
  Greppable (`grep "^## \[" log.md | tail -5`); append-only; allowed to be "stale"
  because it is explicitly history.
- Expected size: ~10 program, ~25 world, ~20 practice, ~5 systems pages.

## 2. The schema contract (schema.md)

1. **Statuses live only on `program/` pages.** World pages state what is built, gated,
   and place-only — never "next is…". Exactly one shelf can carry status rot, and its
   whole job is status.
2. **Supersede, don't append.** New truth replaces the old sentence on the page; the
   chronology goes to `log.md`. A page always reads as current truth.
3. **Update triggers** — the wiki is touched in the same commit / same session as: an
   owner gate, a drop ("do not re-raise"), a program item opening/closing, a defect
   found or parked, a standing-rule correction, a place save/publish.
4. **Cite, don't duplicate.** `docs/superpowers/` specs/plans/SDD ledgers and git
   history are the immutable raw layer; wiki pages link to them and carry only
   synthesis plus what the raw layer cannot record.
5. **Unverified marker.** Any claim not checked against git or the live place is
   written `⚠ unverified`. The wiki never launders a memory into a fact.
6. The lint checklist (§6) lives in schema.md as a recurring operation.

## 3. Harness integration

- **CLAUDE.md** gains a short section: project knowledge lives in `docs/wiki/`; read
  `index.md` before relying on memory; project facts are recorded there, not in the
  auto-memory dir; follow `schema.md`. (CLAUDE.md overrides default memory behavior.)
- **MEMORY.md** shrinks to (a) a mandatory first line — "Project state →
  `docs/wiki/index.md`. Do not write project facts here." — and (b) surviving
  `user`/`feedback` memories (working preferences, cross-project habits: stop-and-ask,
  feet/inches, local-env quirks…). Roughly 15–20 of the 81 files stay.

## 4. Migration (shelf-by-shelf, verify-as-you-go)

Representative mapping (full 81-file disposition table is produced during migration and
committed alongside it):

| Today (memory dir) | Becomes |
|---|---|
| `friends-family-baseline` | `program/` board + per-item pages + `parked-defects.md`; history → log |
| `zendojo-arena-amplified`, `zendojo-bell-engine`, `zendojo-fw11-switchback-deck`, … | `world/` pages per structure; superseded plan paragraphs die |
| STANDING RULE files (`roblox-flush-outside-edges`, `roblox-derive-from-what-it-touches`, …) | `practice/` pages, near-verbatim |
| `roshambo-deploy-topology`, `roshambo-db-topology`, `roshambo-apprunner-migration` | `systems/` |
| `stop-and-ask-after-each-attempt`, `roblox-user-units-feet-inches`, `roshambo-local-env-quirks` | stay in memory dir (user/feedback) |

Rules:

- Every status/as-built claim is checked against git before being written as fact.
- Place-state claims are checked via Studio MCP when Studio is open; otherwise written
  `⚠ unverified`.
- **Each memory file is deleted in the same commit its content lands.** The
  two-truth-store window closes file by file, not at the end. No archive folder — the
  wiki commits are the archive.

## 5. Repo audit (after migration)

Sweep: dormant tools (`roblox/tools/`), `Sandbox_PARKED` / ServerStorage inventory,
TODO/FIXME census, stale doc claims (README-class), config/CI drift,
committed-but-retired assets. Findings are **filed, not fixed**: world/practice pages
updated, actionable items onto `program/` pages; only trivial-and-safe fixes (e.g. a
stale README sentence) applied directly. Anything touching the place follows the
standing gates (one attempt, owner looks). Audit runs after migration because findings
need the wiki to be filed into.

## 6. Lint — the recurring operation

Checklist in `schema.md`, runnable on request and cheap enough for any session close:

- contradictions between pages
- statuses found outside `program/`
- dead wikilinks; orphan pages; index/page mismatch
- `⚠ unverified` claims that have since become checkable

Mechanical subset automated as `tools/wiki/lint.mjs` (~60 lines, TDD'd): dead links,
orphans, index completeness, status-words-outside-program grep. Wired into CI only if
manual runs prove annoying.

## 7. Done means

- Memory dir ≤ 20 files, all user/feedback, MEMORY.md pointing at the wiki.
- `docs/wiki/program/` alone answers "what's next?", correctly.
- The dock reads as built-and-closed on `world/falls-dock.md`.
- `tools/wiki/lint.mjs` runs clean; `log.md` records the migration itself.

## Out of scope

- Search tooling (qmd, embeddings), Marp/Dataview outputs, CI wiring for lint (deferred
  until manual runs annoy), any restructuring of `docs/superpowers/` raw documents, and
  any code fixes beyond trivial-and-safe during the audit.
