---
shelf: practice
updated: 2026-08-28
---

# Owner Rulings

The owner's standing taste, copy, and process rulings, one line each — the fuller
write-ups live on the cited pages. These override any default instinct; do not
re-litigate them without new instructions.

## Copy & theme

- **"Sports book" is BARRED as product usage** (2026-08-15). The room is called **Stats**;
  its shopfront reads 番付 (banzuke, the Edo ranking list — literally a leaderboard, no
  wagering sense). The term may be used when DISCUSSING the design of the space, never in
  shipped names, UI, player-visible identifiers or signage. Same family as the RISK/BANK
  ruling below: gambling register does not belong in a kid-first experience.
  **Why:** Roblox proscribes simulated gambling, and the mechanic is deliberately not a wager.
  **How to apply:** if a name implies betting, rename it before it reaches an asset, a test
  name, or a sign. See [[item-4-merchant-row]] and [[round-and-hud]].
- **No wager language near points.** "RISK IT" was struck: the pot mechanic is
  deliberately not a wager, and Roblox proscribes simulated gambling in a kid-first
  experience — the shipped-green RISK/BANK gate was withdrawn over it. See
  [[round-and-hud]] (Gates) and the play-HUD specs/ledgers in its raw layer.
- **The drum caret asymmetry is intentional lore, currently dormant.** ∧/∨ are the
  mascot's "sad/happy" sides; unified on upright ∧ since 2026-07-21 — don't force the
  drum symmetric AND don't revive ∨ without asking. See [[arena-square]] (Gates).
- **Water features stay "simple and tranquil".** The engineered kakehi flume was cut
  for a natural creek + ONE scoop wheel; favour fewer/simpler elements over mechanism.
  See [[canyon]] (Gates).
- **Organic imperfection is wanted** in carved spaces — lumpy tunnel walls, oblique
  junctions, tight squeezes are character, not defects to sanitize. See
  [[misc-engine-traps]].

- **The uguisu is DELIBERATELY oversized; do not correct it toward life-size** (2026-08-27).
  Measured, it is ~65% over a real bush warbler while the karasu is life-size, so the pair reads
  at ~2x where nature is ~3.2x. Owner: *"I deliberately chose to upscale it because it was hard
  to see; we might revisit that decision in the future."*
  **Why:** legibility at arena distance beat realism, on purpose.
  **How to apply:** a future session WILL measure this and be tempted to fix it — do not. Size
  the next bird against reality, not against the uguisu. See [[familiars]].

## Priorities

- **Polish-where-visible beats tutorialization** — the F&F bar: a harsh-critic
  serious-gamer viewer soon; spend effort on what is seen, not on onboarding copy. See
  [[friends-family-baseline]].
- **Composition first: scatter is background fill only** — hand-composed arrangements
  and hero placements govern; a scatter rule must never bury a composition someone
  hand-placed. See [[foliage]].

- **Guest accounts from before 2026-08-18 are a HARD CUT — no migration.** Points and streaks
  tied to a pre-change deviceId are orphaned and stay orphaned. Claim-on-first-sight was offered
  and declined, because a stolen deviceId would be adopted just as readily.
  **Why:** the deviceId was being used as a password; adoption would preserve the hole it closed.
  **How to apply:** never add a "recover my old guest points" path. See [[identity]].
- **Throw keybindings are `1` / `2` / `3`** (2026-08-16), not `R`/`P`/`S` — `S` is Roblox's
  walk-backward default, and `KeyCode`s follow physical position, so letters move under
  AZERTY/QWERTZ while numbers do not. **How to apply:** the HUD teaches the binding by printing
  the numeral on each throw tile. See [[backlog]].

## Process

- **Re-read a page's opening paragraph before committing an update to it.** An event produces
  an append; superseding needs re-reading text the event did not touch. See [[wiki-currency]].
- **The owner approves RESULTS, not algorithms** — a past "go" is never standing
  permission for a later bake, and a bake aimed at one zone must never touch another.
  See [[bake-isolation]] and [[destructive-bake-guard]].
- **One attempt, then the owner looks.** Make ONE visual attempt, describe it in
  words, and wait — never self-judge and iterate unprompted. See the process notes on
  [[build-recipes]] and [[placement-discipline]].
- **Fix only the thing that is broken** — shipping a second "also works" mechanism
  ships an unasked-for side effect. See [[modal-cursor-grip]].
- **Never launder an invented threshold as an owner gate** — when a gated number is
  retired and you substitute a proxy, say the new number is yours. See
  [[one-model-is-not-a-building]].
- ⚠ **MODEL IN BLENDER, APPROVE IN STUDIO** (2026-08-28). Standing ruling for birds, teahouse
  items and anything else modelled: **build and conditionally approve in Blender, then play and
  give final approval in Studio.** Owner: *"It doesn't bother me if I have to import things
  manually."* Manual imports are NOT a cost worth designing around, and the corollary is the part
  that was actually being got wrong — **do not trade authoring control for iteration speed.**
  ⚠ It was earned: a session built the karasu's eyeball as a runtime Roblox `Part` specifically
  so it could be retuned in Studio without a Blender round trip, and justified it with a trade
  that **does not exist** — measured in Studio, a MeshPart keeps `Color`, `Material` AND
  `Reflectance` at runtime, every dial the Part was supposed to buy, plus `TextureID`, which a
  Part does not have. The Part gave up the iris, gave up being visible while authoring, and
  bought nothing. See [[familiars]] and [[blender-pipeline]].
- **Judge visuals in Play at eye level, side by side** — not Edit stills, not scattered
  across the map, and not from hex values. See [[foliage]] (Gates) and
  [[texturing-pack-meshes]].
