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
3. **Update triggers** — touch the wiki in the same commit/session as: an owner gate,
   a drop ("do not re-raise"), a program item opening/closing, a defect found or
   parked, a standing-rule correction, a place save/publish.
4. **Cite, don't duplicate.** `docs/superpowers/` specs/plans/SDD ledgers and git
   history are the immutable raw layer. Link to them; carry only synthesis and what
   they cannot record (owner decisions, place state).
   ⚠ **The SDD tooling silently un-tracks the ledgers it creates, and it does so
   repeatedly.** `superpowers/skills/subagent-driven-development/scripts/sdd-workspace`
   ends with `printf '*\n' > "$base/.gitignore"`, overwriting `.superpowers/sdd/.gitignore`
   with a bare `*` — the exact state that once left 11 citations across 7 pages pointing at
   content no clone could resolve, and which the committed file's own header warns against.
   It is not once per run: `review-package` and `task-brief` both invoke `sdd-workspace`
   internally, so it is clobbered on every brief and every review package, dozens of times
   in a single execution. **Check `git status` on that file before finishing any SDD run**,
   restore it with `git checkout -- .superpowers/sdd/.gitignore`, and commit the ledger
   markdown rather than deleting the workspace as the skill directs — this repo cites those
   ledgers, so here they are a deliverable, not scratch. Found 2026-09-04 during the client
   load-reduction run; the same regression had been repaired blind at least twice before
   (`8aeef2a` rescued stranded ledgers) without anyone finding the cause.
5. **`⚠ unverified`** marks any claim not checked against git or the live place.
   Never launder a memory into a fact.
6. **Frontmatter**: every page has `shelf:` and `updated:` (absolute date, bumped on every edit
   to the page's BODY); `status:` only on `program/` pages. Optional `checked:` (same format)
   means "re-read on this date and still true" — see rule 10.
   ⚠ **Adding or bumping `checked:` is NOT a body edit and must not bump `updated:`.** This rule
   used to say "bumped on every edit", which made the two fields contradict: writing `checked:`
   commits the file, and if that counted as an edit the only way to satisfy the lint was to bump
   `updated:` — asserting a change nobody made, the exact lie `checked:` exists to avoid. It cost
   seven pages on the day rule 10 shipped. The lint now reads the two apart from the diff, so a
   commit touching body AND `checked:` still demands an `updated:` bump.
7. **Links** are `[[wikilinks]]` between pages; `index.md` uses markdown links.
8. **`log.md`** entries: `## [YYYY-MM-DD] <kind> | <title>`, kind ∈
   gate | ship | decision | drop | defect | migrate | lint | audit. Append-only.
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
10. ⚠ **Staleness BLOCKS, and "re-read" means the WHOLE PAGE.** A cited file that changed more
   than three days after the page was last verified is an ERROR, not a warning. Read the page end
   to end — not the cited line — then bump `updated:` if you changed it, or add
   `checked: YYYY-MM-DD` if it was already right: two different claims, two different fields.
   ⚠ **`checked:` asserts you read ALL of it.** The lint fires on a citation because that is what
   it can see; the citation is a prompt, not the scope. Measured 2026-08-27 over three long pages:
   reading 545 lines costs about 7k tokens, which is nothing — **the expense is never the reading,
   it is the four or five VERIFICATIONS a full read turns up**, and every one of those changed the
   verdict. A pass that stamps the cited line and moves on is the cheap move that made this rule
   necessary in the first place. Warnings were what this used to be, and fifteen had accumulated unactioned, eight of
   them eleven days old. Detection was never the gap; consequence was.

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

- **`updated:` must not lag the page's own last BODY commit** (error). Editing a page and
  forgetting to bump the date is how `world/arena-square.md` carried a 2026-08-17 addition under a
  2026-08-15 stamp. "Body" is measured from the diff: a commit that only writes `checked:` does
  not count, or the hatch in rule 6 would trip the check it exists to satisfy.
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

⚠ **The hatch is `checked:`, and it is still only as honest as the hand that writes it.** Either
field silences the prompt without reading anything, so a stamp with no re-read is a lie the lint
will believe — the two fields exist to make the lie *distinguishable*, not impossible: `updated:`
claims "I changed this", `checked:` claims "I re-read this and it was right". Turning invisible rot
into a visible prompt is the whole value, and it survives being seen every session.
