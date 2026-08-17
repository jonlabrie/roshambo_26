---
shelf: practice
updated: 2026-08-16
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
language outside `program/`, log format, frontmatter. It ran clean through every one of the
failures above, because none of them are structural. **A page can be internally contradictory,
four buildings out of date, and lint-clean.**

The schema already prescribes a manual pass for exactly this (contradictions, superseded claims,
`⚠ unverified` gone checkable). That pass requires reading and therefore is the part that gets
skipped — which is why it caught none of these.

## The rule that would have caught it

**When an event updates a page, re-read that page's FIRST paragraph and any "remaining /
next / still to do" sentence before committing.** Those are claims with an expiry date, and they
are never where the new fact lands.

Cheap mechanical assist, not yet built: have the lint flag any `program/` page whose body
contains a forward-looking phrase — "next step", "remaining scope", "is now", "still to" — and
require the editing session to confirm it is still true. Noisy by design; these pages are few,
and this is the exact class the structural checks miss.

⚠ That lint rule is PROPOSED, not implemented.
