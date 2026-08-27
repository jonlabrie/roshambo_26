### Task 8: Close item 4's build pass

**Files:**
- Modify: `docs/wiki/program/item-4-merchant-row.md`, `docs/wiki/world/arena-square.md` (street one-liner), `docs/wiki/log.md`; create `docs/wiki/world/merchant-row.md` ONLY if the item-4 page's as-built section has outgrown a status page (implementer's judgment, schema rules apply)

- [ ] **Step 1:** After the last gate: update item-4 (shells shipped + gates listed; remaining = commerce hookup at items 6/7, cavern at item 7, NPC later), append `## [date] ship | merchant row shells + chaya shipped` to log.
- [ ] **Step 2:** Wiki lint (repo root, nvm-prefixed) → 0 errors; full Luau suite + stylua/selene once more.
- [ ] **Step 3:** Commit `docs(wiki): item 4 build pass closed` and push (`git push` — the branch auto-deploys the dev server; these are client/builder assets, safe).
- [ ] **Step 4:** Remind the controller: the place needs a Studio SAVE by the owner (Rojo-synced stage children live in the place file too), and `place-state.md`'s inventory should gain the new stage children.

