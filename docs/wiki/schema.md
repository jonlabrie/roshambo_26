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

### Currency checks (added 2026-08-18)

Three checks put a floor under the manual pass, by noticing when the GROUND under a page moved
after the page last claimed to be current:

- **`updated:` must not lag the page's own last commit** (error). Editing a page and forgetting
  to bump the date is how `world/arena-square.md` carried a 2026-08-17 addition under a
  2026-08-15 stamp.
- **A cited repo path must exist** (error) — the same defect as a dead wikilink, pointed at the
  code. `program/backlog.md` cited `BoardController.client.luau` for two days after it was
  retired. Where a page names a path in order to say it is GONE, put `<!-- lint-ok: why -->` on
  that line.
- **Cited code committed after the page's `updated:`** (warning, reading `re-read —`). Not
  "wrong": *go look*. Roughly half of these want only a refreshed line number.

**These are a floor, not a substitute.** They cannot read prose, they flag PAGES rather than
paragraphs, and they only see claims that cite a path. A page can still be internally
contradictory and years out of date while passing every mechanical check — the manual pass above
remains the only thing that catches that, and it is the part that gets skipped. See
[[wiki-currency]] for the mechanism.

⚠ Bumping `updated:` silences a warning without reading anything. That escape hatch is
deliberate — the value is turning invisible rot into a visible prompt — but it means a date bump
with no re-read is a lie the lint will believe.
