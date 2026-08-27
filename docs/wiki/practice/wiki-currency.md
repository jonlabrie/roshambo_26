---
shelf: practice
updated: 2026-08-26
---

# Why Wiki Pages Go Stale (and what the lint cannot catch)

The wiki was built 2026-08-15. By 2026-08-16 a program page had already produced confident
wrong advice. This records the mechanism, because "be more careful" is not a fix.

## What actually happened

[[item-4-merchant-row]] opened with *"Remaining scope is the row itself — the façade shells
around it."* True when written; four shells were built after it. The page ALSO said the machiya
brainstorm was DONE and then, three bullets later, that a step deferred "to the machiya
brainstorm" was "now the next step." It argued with itself, and it understated the item by four
buildings. A session read it, concluded the project had drifted off item 4, and put that to the
owner as a reason to change what to work on. The owner corrected it from memory.

## The mechanism — appends land, prose rots

Every update WAS made. Each shell's gate was recorded in the Gates section. What nobody did was
re-read the page's own opening paragraph and ask whether it was still true.

That is the failure mode, and it is structural: **an update trigger fires on an event, and an
event naturally produces an APPEND. Superseding requires re-reading text the event did not
touch.** Schema rule 2 says supersede, don't append — but the rule describes the outcome, not
the moment, so it is obeyed where the new fact lands and skipped everywhere else on the page.

Three more instances from the same 48 hours, same shape:
- `CLAUDE.md` asserted the World Throw was "**not** derived from player votes" long after that
  became the design's central claim. Loaded every session, so it re-taught the error each time.
- A parked defect was appended as "(f)" when an (f) and a (g) already existed — the list was
  appended to without being read.
- An SDD ledger still listed a minor as deferred after it had been fixed; the final reviewer
  caught it with "ledger is stale — strike this."

## What the lint can and cannot do

`tools/wiki/lint.mjs` checks STRUCTURE: index completeness, dead wikilinks, orphans, status
language outside `program/`, log format, frontmatter — plus currency, below. It ran clean through
every one of the failures above, because none of them are structural. **A page can be internally
contradictory, four buildings out of date, and lint-clean.**

⚠ **AND ONE WHOLE CLASS REMAINS INVISIBLE TO IT: a page that was NEVER TRUE.** Currency compares
the page against the moment its cited code last moved, so it can only catch a page that has fallen
behind. `familiars.md` recorded the uguisu at 0.552 studs — its size in Blender, not the size that
shipped — and a MeshId two imports stale. The page and the artifact never agreed, so there was no
*change* to detect and no date to compare. The only defence is not to transcribe the number at all:
record how to measure it (schema rule 9).

The schema already prescribes a manual pass for exactly this (contradictions, superseded claims,
`⚠ unverified` gone checkable). That pass requires reading and therefore is the part that gets
skipped — which is why it caught none of these.

## The rule that would have caught it

**When an event updates a page, re-read that page's FIRST paragraph and any "remaining /
next / still to do" sentence before committing.** Those are claims with an expiry date, and they
are never where the new fact lands.

## The mechanical assist — built 2026-08-18, and not the one proposed

The proposal here was to flag forward-looking PHRASES ("next step", "remaining scope"). What was
built instead flags **moved GROUND**, because the phrase scan turned out to be the weaker signal:
grepping the program shelf for those phrases returned five hits, of which four were prose about
something else. The rot is not reliably announced in the wording.

What is: a page's claims cite files, and those files have commit dates. `tools/wiki/lint.mjs`
errors when a page's `updated:` lags its own last commit, and errors on a cited repo path that
does not exist.

⚠ **AND `re-read —` NOW BLOCKS (2026-08-26).** It shipped as a WARNING, and the warning was the
mistake: **warnings do not get cleared.** Fifteen accumulated over eleven days — eight of them on
pages untouched since 2026-08-15 — while 60 of the 77 wiki commits in that window were corrections
of things already written. The signal was firing the whole time and nobody was downstream of it.

It is an error past a **three-day grace**, which is wide enough for "edited the code Friday, wrote
the page Monday" and far too narrow for the gaps that were actually sitting there. Inside the
grace it is still a warning. Clear it by re-reading and then either bumping `updated:` (you changed
the page) or adding `checked: YYYY-MM-DD` (it was already right) — two different claims, two
different fields, and silencing one with the other would be a small lie in the frontmatter.

⚠ **The escape hatch is also a trap worth naming:** `checked:` older than the code change does not
clear anything, or one stale acknowledgement would silence a page forever. Tested.
Details and the `<!-- lint-ok -->` exemption are in [schema.md](../schema.md).

First run: **5 errors, 13 warnings across 50 pages** — a usable volume rather than noise. It
found every one of the failures this page was written about, and one it was not: `program/backlog.md`
had spent two days describing the digits-drum defect as open and its `Opts` blocker as unplumbed,
when both had been fixed the following day. That entry was again *appended to* — a "BUILT" note
was added beneath a heading still reading "NEXT, not yet specced" — which is this page's exact
mechanism, surviving the page that documented it.

**The generalisation that adds:** a deferred-work note rots differently from an as-built page.
The `world/` shelf stayed current because superseding is natural when the thing itself changes —
you rewrite the page because you are looking at it. A backlog entry is written ONCE, at merge, as
a dump of what was not done, and the event that expires it happens somewhere else entirely: a
later session fixes the deferred thing and has no reason to know the note exists. **The note and
its expiry live in different files, so no trigger can fire.** The citation check is what bridges
them — the fix touches the code, the code's date moves, the page that cites it gets flagged.

⚠ Bumping `updated:` clears a warning without reading anything. The check converts invisible rot
into a visible prompt; it cannot make anyone read.
