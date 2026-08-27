# Task 4 report: the ring, built and driven

**Status:** complete. **Commit:** `01bfc42` on `m4b-zendojo-art-pass`.

**Gates:** `lune run tests/run` → 948 passed, 0 failed (baseline held). `stylua --check src tests
tools` → clean. `selene src tools` → 0 errors, 0 warnings.

**Correction applied:** ring built in the hamburger's slot (`ring.Position = UDim2.new(1 -
JUMP_CLEARANCE, -(AREA_W + RING_GAP), 1, -(EDGE + AREA_H - BTN_H))`), not the plate's. **Plate was
NOT moved** — `plate.Position` is untouched, still registered off the tape's left edge.

**Placement:** Ring section (`HudController.client.luau`) built between the ledger-door section
and the old hairline section, so it sits textually beside `ledgerButton`, the element whose slot
and gesture it inherits. All ring instance construction (segments, disc, count label, glyph boxes,
UIScale) happens there. **Both `ring.MouseButton1Down` and `ring.MouseButton1Click` handlers are
declared in that same section — after `plateVisible` (declared ~line 314) — so neither reads a nil
global.** Paint logic added inside `render()` immediately after the existing hairline block, reusing
`span`/`ringKnown`/`ringFrac` derived the same way the hairline's `frac` is. `main.client.luau`:
`revealedWorldThrow` declared beside `revealedRoundId`; set in `maybeShowReveal` in the same `if
p.roundId then` block; cleared alongside `pendingReveal`/`drumAtRest` when ACTIVE reopens; added to
`publish()`'s `aux` table as `worldThrow`. `pendingReveal`'s type and the `RevealResult` assignment
both carry the new `worldThrow: string` field.

## Reconciliation 1: every `HudLayout.X` read vs `grep "^HudLayout\.[A-Za-z_]* ="`

Declared: JUMP_CLEARANCE, EDGE, TILE, ROW_GAP, BTN_H, THROW_TOUCH_SCALE, TAPE_TOUCH_SCALE,
BTN_H_TOUCH, TILE_TOUCH, RING_D, RING_D_TOUCH, RING_THICKNESS, RING_THICKNESS_TOUCH, RING_GAP,
BANK_H, BANK_GAP, AREA_H, AREA_H_TOUCH, CLUSTER_TOP_FROM_BOTTOM, CLUSTER_TOP_FROM_BOTTOM_TOUCH.

Read in `HudController.client.luau`: JUMP_CLEARANCE, EDGE, BTN_H_TOUCH, BTN_H, TILE_TOUCH, TILE,
ROW_GAP, AREA_H_TOUCH, AREA_H, CLUSTER_TOP_FROM_BOTTOM_TOUCH, CLUSTER_TOP_FROM_BOTTOM, BANK_H,
RING_D_TOUCH, RING_D, RING_GAP, RING_THICKNESS_TOUCH, RING_THICKNESS. All present above — clean,
no orphan reads.

## Reconciliation 2: every `view.X` / `aux.X` read vs `HudModel.View` / `publish()`'s aux table

`HudModel.View` fields: `plate{streak,points}`, `throwsEnabled`, `bankVisible`, `pot`,
`potPulses`, `escalate`, `secondsLeft`, `chosen`, `switchPrompt`.
`view.X` reads in `HudController.client.luau`: `throwsEnabled`, `chosen`, `plate.points`,
`plate.streak`, `pot`, `potPulses`, `escalate`, `secondsLeft`, `switchPrompt` — all present.

`publish()`'s aux table: `session`, `tape`, `timerKnown`, `worldThrow`.
`aux.X` reads: `aux.session`, `aux.tape`, `aux.timerKnown`, `aux.worldThrow` — all present, no
orphans.

## Clearance arithmetic (no overlaps; H = viewport height)

**Desktop:** AREA_W=248, AREA_H=120, RING_D=76, RING_THICKNESS=6, RING_GAP=8. Ring x-range
`[0.85W-332, 0.85W-256]`; throw cluster left edge `0.85W-248` → **8px gap** (=RING_GAP). Ring
y-range `[H-132, H-56]`, exactly matching the button row's own top/bottom — bottom-aligned as
required. Plate y-range `[H-46, H-12]` (unchanged, tape row) — **10px vertical gap** to ring's
bottom (=ROW_GAP), different row, no overlap regardless of x. Bank button y-range `[H-182,H-142]`
→ **10px gap** to ring's top (=ROW_GAP). Tape unaffected (ring never entered its row).

**Touch:** AREA_W=148, AREA_H_TOUCH=78, RING_D_TOUCH=44, RING_THICKNESS_TOUCH=3. Ring x-range
`[0.85W-156,0.85W-112]`... encoded as `-(148+8)=-156` from the right edge; cluster left edge
`0.85W-148` → **8px gap**. Ring y-range `[H-90,H-46]`, matching the touch button row exactly.
Plate y-range `[H-36,H-12]` → **10px gap**. Bank button y-range `[H-140,H-100]` → **10px gap**.

Ring and `ledgerButton` occupy the identical Position formula at both tiers (RING_GAP==LEDGER_GAP==8,
RING_D==LEDGER_SIZE at both tiers), confirming the "hamburger's slot, exactly" requirement.

**Concerns:** none. `ledgerButton` intentionally still present (Task 5 removes it); two ledger doors
coexist this task by design.
