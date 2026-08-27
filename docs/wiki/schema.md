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
2. ⚠ **Supersede, don't append — DELETE THE OLD CLAIM.** New truth REPLACES old text; the old
   value goes to `log.md`, which is append-only by design and is where chronology belongs. A page
   must never read as an argument with its past self.
   **This rule was being broken, measurably.** Over the eleven days to 2026-08-26, `familiars.md`
   grew +482 lines against 43 deleted and `blender-pipeline.md` +244 against 10, while **60 of 77
   wiki commits were corrections of things already written**. Corrections were landing BESIDE the
   wrong text rather than on top of it, leaving a reader free to believe either — and at 439 lines
   nobody re-reads far enough to notice the contradiction.
9. ⚠ **Never transcribe a measurable fact — record how to MEASURE it.** Sizes, counts, IDs, angles,
   service URLs, branch names: a number copied into prose has no source, cannot be re-derived, and
   is wrong the moment the artifact moves, with nothing positioned to notice.
   The failure this prevents: `familiars.md` recorded the uguisu at **0.552 studs** for a week. That
   was its size in Blender; the shipped asset is **0.828**, and nothing rescales it. A DESIGN figure
   carried as an AS-BUILT, and no currency check can ever catch it, because the page and the
   artifact never agreed in the first place — there is no "change" to detect.
   Write the query instead. `CLAUDE.md`'s deploy note carries the `aws` command that returns the
   service's branch and URL rather than naming them; `familiars.md` carries
   `tools/studio/measureBirds.luau` rather than a table of dimensions. A command cannot go stale
   without failing loudly.
10. ⚠ **Staleness BLOCKS.** A cited file that changed more than three days after the page was last
   verified is an ERROR, not a warning. Re-read the page, then bump `updated:` if you changed it,
   or add `checked: YYYY-MM-DD` if it was already right — two different claims, two different
   fields. Warnings were what this used to be, and fifteen had accumulated unactioned, eight of
   them eleven days old. Detection was never the gap; consequence was.
3. **Update triggers** — touch the wiki in the same commit/session as: an owner gate,
   a drop ("do not re-raise"), a program item opening/closing, a defect found or
   parked, a standing-rule correction, a place save/publish.
4. **Cite, don't duplicate.** `docs/superpowers/` specs/plans/SDD ledgers and git
   history are the immutable raw layer. Link to them; carry only synthesis and what
   they cannot record (owner decisions, place state).
5. **`⚠ unverified`** marks any claim not checked against git or the live place.
   Never launder a memory into a fact.
6. **Frontmatter**: every page has `shelf:` and `updated:` (absolute date, bumped on
   every edit); `status:` only on `program/` pages. Optional `checked:` (same format) means
   "re-read on this date and still true" — see rule 10.
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
