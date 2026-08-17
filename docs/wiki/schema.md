# Wiki Schema

This wiki is the single authority for Roshambo project knowledge and work tracking.
Sessions read `index.md` first. The pattern is Karpathy's LLM-wiki
(spec: `docs/superpowers/specs/2026-08-15-project-wiki-design.md`), adapted.

## Shelves

- `program/` — STATUS. The only shelf where statuses live (frontmatter `status:`,
  words like "next", "open", "parked"). Boards, per-item pages, parked defects, backlog.
- `world/` — AS-BUILT. One page per structure/zone/in-game system. States what is
  built, gated, and place-only. Never says what is next.
- `practice/` — HOW WE WORK. Standing rules, recipes, traps, owner rulings.
- `systems/` — thin pointers into code/deploy/data truth the repo already records.

## Rules

1. **Statuses only on `program/` pages.**
2. **Supersede, don't append.** New truth replaces old text; chronology goes to
   `log.md`. A page must never read as an argument with its past self.
3. **Update triggers** — touch the wiki in the same commit/session as: an owner gate,
   a drop ("do not re-raise"), a program item opening/closing, a defect found or
   parked, a standing-rule correction, a place save/publish.
4. **Cite, don't duplicate.** `docs/superpowers/` specs/plans/SDD ledgers and git
   history are the immutable raw layer. Link to them; carry only synthesis and what
   they cannot record (owner decisions, place state).
5. **`⚠ unverified`** marks any claim not checked against git or the live place.
   Never launder a memory into a fact.
6. **Frontmatter**: every page has `shelf:` and `updated:` (absolute date, bumped on
   every edit); `status:` only on `program/` pages.
7. **Links** are `[[wikilinks]]` between pages; `index.md` uses markdown links.
8. **`log.md`** entries: `## [YYYY-MM-DD] <kind> | <title>`, kind ∈
   gate | ship | decision | drop | defect | migrate | lint | audit. Append-only.

## Lint (recurring)

Run `source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs` —
mechanical checks (index completeness, dead wikilinks, orphans, status language
outside program/, log format, frontmatter). Then the manual pass:

- contradictions between pages
- claims superseded by newer gates/commits
- `⚠ unverified` claims that have since become checkable
- important topics mentioned on 3+ pages but lacking their own page

Run on request, and cheaply at any session close.

**The lint checks STRUCTURE, not CURRENCY.** A page can be internally contradictory and years
out of date while passing every mechanical check. The manual pass above is the only thing that
catches that, and it is the part that gets skipped — see [[wiki-currency]] for the mechanism and
the one rule that would have caught the failures of 2026-08-16.
